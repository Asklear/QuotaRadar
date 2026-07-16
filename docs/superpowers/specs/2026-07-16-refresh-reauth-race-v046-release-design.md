# Refresh/Reauthentication Race Repair And v0.4.6 Release Design

## Goal

Prevent an in-flight quota refresh from overwriting credentials or metadata saved by dashboard reauthentication, then prepare and fully validate Quota Radar v0.4.6 without changing provider request contracts that have already passed live acceptance.

## Verified Root Cause

`QuotaMonitor.refresh()` builds an `updatedKeys` array from the credential state visible when the refresh task starts. When all provider requests finish, it assigns that stale snapshot back with `self.apiKeys = updatedKeys` and persists it. Dashboard reauthentication can update the same credential while the refresh is running. The final whole-array assignment then restores the old secret and old quota metadata, even though validation and persistence succeeded earlier.

The live acceptance run reproduced this boundary: Volcengine reauthentication reached HTTP 200/no-subscription and closed successfully, but startup auto-refresh later restored the old HTTP 401 metadata. Disabling startup refresh for the acceptance process allowed the same provider response and reauthentication flow to persist correctly.

## Chosen Design: Per-Credential Optimistic Merge

Refresh remains asynchronous and dashboard reauthentication remains available while it runs. At refresh start, QuotaMonitor captures the source credential array used to build refresh candidates. At completion, a pure merge policy combines refreshed results into the current credential array instead of replacing the array wholesale.

Provider requests produce deferred result records containing the candidate credential, outcome, and whether the result represents a failure. The request loop must not write quota-history snapshots or accumulate the user-facing failure count. Reconciliation first decides which results are accepted. Only accepted results may update credentials, append quota-history snapshots, contribute to threshold notifications, or contribute to the failed-refresh banner. A stale rejected result has no persistence or UI side effects; this also prevents orphan snapshots for rejected derived credentials.

For each credential that existed at refresh start, the policy compares a mutation signature containing fields owned by user or authorization flows:

- credential secret;
- name and provider;
- active state and note;
- linked authorization identifier;
- last-updated timestamp.

If the current signature differs from the start signature, the refresh result is stale and is discarded for that credential. This preserves reauthentication, editing, enable/disable changes, and other newer writes. If the signature is unchanged, only refresh-owned fields are copied onto the current credential:

- remaining, limit, and reset time;
- plan end and plan display name;
- Codex reset-credit metadata;
- quota label and structured quota text;
- HTTP/diagnostic state and failure count;
- refresh timestamp.

Usage counters and last-used state remain sourced from the current credential so unrelated usage tracking is not rolled back.

## Collection Semantics

- Credentials added during refresh remain present.
- Credentials deleted during refresh are not re-created by stale results.
- Credentials edited or reauthenticated during refresh keep all current fields, including their newer quota validation result.
- Unchanged credentials receive their refreshed quota metadata.
- Derived shared-dashboard credentials may be appended only when their source authorization still exists, remains active and eligible, has the same mutation signature captured at refresh start, and no equivalent direct credential was added during the refresh. A reauthenticated, edited, disabled, or deleted source invalidates the derived result so stale copied authorization is never persisted.
- The merge preserves current credential ordering; eligible new derived rows are appended in refresh-result order.

## Scope Boundaries

The repair belongs in `QuotaMonitor` refresh result reconciliation. It does not change DashboardReauth capture, provider readiness, request construction, response parsing, retry policies, or secret-store formats.

No UI is disabled while refreshing. No global refresh cancellation is introduced. No provider-specific exception is added for this shared state-management race.

## Testing

A pure merge-policy test will reproduce and guard these cases:

1. unchanged credentials accept refreshed quota metadata;
2. reauthenticated credentials reject stale refresh results;
3. edited or disabled credentials reject stale refresh results;
4. credentials added during refresh remain present;
5. credentials deleted during refresh stay deleted;
6. current usage counters survive a successful quota merge;
7. eligible derived credentials append once, while a concurrently added direct credential suppresses the derived row;
8. derived results are discarded when their source authorization is reauthenticated, edited, disabled, or deleted during refresh;
9. rejected reauthentication and derived-source results append no quota-history snapshot and do not contribute to the failed-refresh banner;
10. accepted success/failure results still record the existing snapshot outcome and failure UI semantics exactly once.

The new behavior test must fail against the existing whole-array replacement behavior before production code changes are made.

## v0.4.6 Release Preparation

After the race repair passes its focused and full behavior tests:

- set `CFBundleShortVersionString` to `0.4.6`;
- increment `CFBundleVersion` from `19` to `20`;
- update the hard-coded release-version behavior assertions to require both `0.4.6` and Build `20`;
- update English and Simplified Chinese README version text and manual release commands;
- add matching English and Simplified Chinese roadmap/release-note sections describing dashboard credential recapture, the four provider contract repairs, Volcengine no-subscription handling, and refresh/reauth reconciliation;
- keep the settings footer dynamic through bundle metadata, with no hard-coded version label changes.

## Release QA Gate

The release is publishable only after all repository release checks pass on the final v0.4.6 source:

1. behavior tests, including Debug/Release builds and signature checks;
2. visual QA with summary and screenshot inspection;
3. source secret scans;
4. the additional repository consistency gate `bash scripts/check_tauri_sources.sh`;
5. standard updater DMG build, updater URL scan, signature verification, DMG verification, mount-content check;
6. white-label DMG build, updater URL absence scans, signature verification, DMG verification, mount-content check;
7. `git diff --check`, clean worktree, and independent code review with no unresolved Critical or Important findings.

Passing local QA does not authorize merging, tagging, pushing, creating a GitHub Release, or overwriting `/Applications`; those actions remain separate release decisions.
