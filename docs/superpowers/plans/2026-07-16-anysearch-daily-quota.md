# AnySearch Daily Quota Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace AnySearch's false unlimited state with authenticated UTC-daily usage monitoring while preserving the existing copyable API key.

**Architecture:** Model AnySearch as a dashboard authorization plus companion API key. Capture and normalize the console's localStorage auth state, construct an explicitly bounded UTC-day request, parse `data.total_requests` against the provider-specific 1,000/day limit, and persist a localized used/remaining/limit descriptor. Keep token refresh and `/user/keys` runtime verification out of scope because only the usage contract was verified.

**Tech Stack:** Swift 5, SwiftUI, WebKit, Foundation `URLSession`/`JSONDecoder`, existing shell-based behavior harness, macOS `xcodebuild`.

---

## File map

- `QuotaRadar/Models/APIKey.swift`: AnySearch provider capabilities, credential names, dashboard URL, copy/authorization identity, and quota presentation.
- `QuotaRadar/Services/DashboardReauth.swift`: provider-specific normalization of captured AnySearch Web Storage fields.
- `QuotaRadar/Views/DashboardReauthView.swift`: safe extraction of the `search-template-auth-state` localStorage object.
- `QuotaRadar/Services/QuotaService.swift`: AnySearch credential parsing, UTC request construction, response parser, and HTTP refresh.
- `QuotaRadar/Models/AppLanguage.swift`: localized daily used/remaining/limit descriptor and legacy-label restoration.
- `QuotaRadar/Models/QuotaMonitor.swift`: preserve last-success timestamps on transient failures and repair companion links when authorization is deleted.
- `QuotaRadar/Views/SettingsView.swift`: reuse and relink an existing AnySearch API-key record after authorization capture.
- `Tests/run_behavior_tests.sh`: parser, credential, migration, request, presentation, failure, and provider-isolation regression coverage.
- `docs/providers.md`, `docs/providers.zh-Hans.md`, `docs/roadmap.md`, `docs/roadmap.zh-Hans.md`, `docs/quickstart.md`, `docs/quickstart.zh-Hans.md`, `docs/tauri-provider-migration-checklist.md`: synchronize AnySearch capability and setup documentation.

### Task 1: Make AnySearch a dual-credential dashboard provider

**Files:**
- Modify: `Tests/run_behavior_tests.sh`
- Modify: `QuotaRadar/Models/APIKey.swift`

- [ ] **Step 1: Add failing provider-contract tests**

Add assertions equivalent to:

```swift
require(Provider.anysearch.supportsDashboardReauthentication, "AnySearch should capture dashboard authorization")
require(Provider.anysearch.supportsCompanionAPIKeyStorage, "AnySearch should preserve a copyable API key")
require(Provider.anysearch.defaultCredentialName == "ANYSEARCH_SESSION", "AnySearch monitoring uses a session record")
require(Provider.anysearch.copyableAPIKeyCredentialName == "ANYSEARCH_API_KEY", "AnySearch invocation key stays separate")
require(Provider.anysearch.dashboardURL == "https://anysearch.com/console/overview", "AnySearch should open the current console")
require(Provider.anysearch.cookieDomains == ["anysearch.com"], "AnySearch capture must stay provider-scoped")
require(Provider.anysearch.dashboardAuthenticationCookieNames == ["accessToken"], "AnySearch requires captured access token material")
```

Also assert that `ANYSEARCH_API_KEY` is copyable and classed as `isStoredAPIKeyOnlyCredential`, while `ANYSEARCH_SESSION` is a non-copyable quota-monitoring authorization.

- [ ] **Step 2: Run the behavior suite and verify the new assertions fail**

Run: `bash Tests/run_behavior_tests.sh`

Expected: FAIL on AnySearch dashboard reauthentication/companion storage/default name/dashboard URL assertions.

- [ ] **Step 3: Implement the minimal provider capability changes**

In `Provider`, move `.anysearch` into the same capability branches as dual-credential dashboard providers and set:

```swift
case .anysearch: return "ANYSEARCH_SESSION"
case .anysearch: return "ANYSEARCH_API_KEY"
case .anysearch: return ["anysearch.com"]
case .anysearch: return ["accessToken"]
case .anysearch: return "https://anysearch.com/console/overview"
```

Remove `.anysearch` from mutually exclusive API-key-only branches. Do not change another provider's values.

- [ ] **Step 4: Run the focused provider assertions**

Run: `bash Tests/run_behavior_tests.sh`

Expected: new provider-contract assertions pass; later legacy unlimited assertions may still fail until Task 4.

- [ ] **Step 5: Commit**

```bash
git add QuotaRadar/Models/APIKey.swift Tests/run_behavior_tests.sh
git commit -m "feat: model AnySearch dashboard authorization"
```

### Task 2: Capture and normalize AnySearch console auth state

**Files:**
- Modify: `Tests/run_behavior_tests.sh`
- Modify: `QuotaRadar/Services/DashboardReauth.swift`
- Modify: `QuotaRadar/Views/DashboardReauthView.swift`

- [ ] **Step 1: Add failing normalization tests**

Construct a `DashboardCapturedCredential` with sanitized fields and assert normalization produces only the supported values:

```swift
let captured = DashboardCapturedCredential(
    provider: .anysearch,
    cookieHeader: "",
    webStorageFields: [
        "anysearchAccessToken": "Bearer access-redacted",
        "anysearchRefreshToken": "refresh-redacted",
        "anysearchExpiresAt": "1784196000000"
    ]
)
require(captured.fields["accessToken"] == "access-redacted", "Bearer prefix should be stripped")
require(captured.fields["refreshToken"] == "refresh-redacted", "refresh token should be retained")
require(captured.fields["expiresAt"] == "1784196000000", "millisecond expiry should be retained")
require(DashboardCookieBuilder.missingRequiredCredentialNames(cookieHeader: "", fields: captured.fields, requiredNames: ["accessToken"]).isEmpty, "access token should complete capture")
```

Add source guards proving capture reads only localStorage key `search-template-auth-state`, parses `state.accessToken`, `state.refreshToken`, and millisecond `state.expiresAt`, and never logs the raw object.

- [ ] **Step 2: Run tests and verify failure**

Run: `bash Tests/run_behavior_tests.sh`

Expected: FAIL because AnySearch normalization and Web Storage extraction do not exist.

- [ ] **Step 3: Implement provider-specific normalization**

Add `normalizedAnySearchFields(storage:)` to `DashboardCapturedCredential` and route only `.anysearch` to it. Strip an optional Bearer prefix, accept only a positive integer millisecond expiry, and return keys `accessToken`, `refreshToken`, and `expiresAt`.

- [ ] **Step 4: Add safe WebView extraction**

In the existing async Web Storage script, read `localStorage.getItem('search-template-auth-state')` only on `anysearch.com`, parse it in a `try/catch`, and emit normalized temporary keys:

```javascript
const auth = JSON.parse(localStorage.getItem('search-template-auth-state') || '{}');
const state = auth && auth.state;
if (state && typeof state.accessToken === 'string') output.anysearchAccessToken = state.accessToken;
if (state && typeof state.refreshToken === 'string') output.anysearchRefreshToken = state.refreshToken;
if (state && Number.isInteger(state.expiresAt)) output.anysearchExpiresAt = String(state.expiresAt);
```

Do not emit `state.user`, the raw JSON value, or any identity metadata.

- [ ] **Step 5: Run behavior tests**

Run: `bash Tests/run_behavior_tests.sh`

Expected: normalization and source guards pass.

- [ ] **Step 6: Commit**

```bash
git add QuotaRadar/Services/DashboardReauth.swift QuotaRadar/Views/DashboardReauthView.swift Tests/run_behavior_tests.sh
git commit -m "feat: capture AnySearch console authorization"
```

### Task 3: Parse daily usage and construct exact UTC requests

**Files:**
- Modify: `Tests/run_behavior_tests.sh`
- Modify: `QuotaRadar/Services/QuotaService.swift`
- Modify: `QuotaRadar/Models/AppLanguage.swift`

- [ ] **Step 1: Add failing parser fixtures and assertions**

Use inline redacted JSON fixtures matching the verified envelope:

```swift
let result = try! QuotaParsers.parseAnySearchDailyUsage(Data(#"{"code":0,"message":"ok","data":{"period":{"from":"2026-07-16T00:00:00Z","to":"2026-07-16T09:31:17Z"},"scope":"user","total_requests":356,"success_requests":356}}"#.utf8))
require(result.remaining == 644 && result.limit == 1000, "AnySearch should compute daily remaining")
require(result.resetAt == ISO8601DateFormatter().date(from: "2026-07-17T00:00:00Z"), "AnySearch should reset at next UTC midnight")
require(result.quotaText == .localized(.dailyRequestsUsageFormat, "356", "644", "1000"), "AnySearch should retain observed used count")
```

Add fixtures for missing `data`, missing/non-numeric/negative `total_requests`, exactly 1,000, and 1,200. The 1,200 fixture must retain `"1200"` in `quotaText` while returning remaining zero.

- [ ] **Step 2: Add failing request-builder assertions**

For a fixed `Date`, assert `AnySearchDailyUsageRequest.url(now:)` yields exactly:

```text
https://anysearch.com/api/api/user/usage/summary?from=2026-07-16T00%3A00%3A00.000Z&to=2026-07-16T09%3A31%3A17.000Z
```

Also assert next reset at UTC midnight and the Asia/Shanghai visible boundary at 08:00.

- [ ] **Step 3: Run tests and verify failure**

Run: `bash Tests/run_behavior_tests.sh`

Expected: FAIL because parser, request helper, and localization key do not exist.

- [ ] **Step 4: Implement parser and request helper**

Add an internal `AnySearchDailyUsageRequest` helper in `QuotaService.swift` with a POSIX, Gregorian UTC calendar and a fixed millisecond ISO formatter. Reject negative usage rather than silently clamping malformed evidence. `parseAnySearchDailyUsage` must validate `code`, `data.period`, `scope == "user"`, and `total_requests`, calculate the next UTC midnight from the response period start, and return the structured descriptor.

- [ ] **Step 5: Add localization**

Add `dailyRequestsUsageFormat` to `L10n.Key` and all five language tables, using arguments in used, remaining, limit order. Extend legacy-label conversion only for the canonical English fallback emitted by this parser.

- [ ] **Step 6: Run behavior tests**

Run: `bash Tests/run_behavior_tests.sh`

Expected: all Task 3 parser, request, reset, localization, and above-limit assertions pass.

- [ ] **Step 7: Commit**

```bash
git add QuotaRadar/Services/QuotaService.swift QuotaRadar/Models/AppLanguage.swift Tests/run_behavior_tests.sh
git commit -m "feat: parse AnySearch daily usage"
```

### Task 4: Replace unlimited quota with authenticated HTTP refresh

**Files:**
- Modify: `Tests/run_behavior_tests.sh`
- Modify: `QuotaRadar/Services/QuotaService.swift`
- Modify: `QuotaRadar/Models/APIKey.swift`
- Modify: `QuotaRadar/Models/QuotaMonitor.swift`

- [ ] **Step 1: Add failing integration/source contract tests**

Assert that `checkAnySearchQuota` parses an `AnySearchDashboardCredential`, rejects expired millisecond timestamps before networking, sets `Authorization: Bearer ...`, calls only `/api/api/user/usage/summary` with `from` and `to`, maps 401/403 to `QuotaError.unauthorized`, and never calls `/user/keys` or a guessed refresh endpoint.

Replace legacy source assertions for `Int.max`, infinity, and `"Unlimited free usage"` with assertions for the verified endpoint and `parseAnySearchDailyUsage`.

- [ ] **Step 2: Add transient-failure preservation tests**

Create a key with successful AnySearch `remaining`, `limit`, `resetAt`, `quotaText`, and `lastUpdated`, apply a failed deferred refresh, and assert all success fields including `lastUpdated` remain byte-for-byte unchanged while failure diagnostics/count change.

- [ ] **Step 3: Run tests and verify failure**

Run: `bash Tests/run_behavior_tests.sh`

Expected: FAIL because AnySearch still returns the unlimited sentinel and failure handling updates `lastUpdated`.

- [ ] **Step 4: Implement credential parsing and HTTP request**

Add internal `AnySearchDashboardCredential` parsing the serialized `DashboardCredential` fields. Reject missing/expired `accessToken` as unauthorized. Build the exact request, send Bearer auth and JSON accept headers, handle 401/403 explicitly, require HTTP 200, and parse with `QuotaParsers.parseAnySearchDailyUsage`.

- [ ] **Step 5: Preserve last-success data on transient failure**

In `QuotaMonitor`'s generic failure path, avoid changing success quota fields or `lastUpdated`. Confirm this generic correction matches the intended semantics for all providers; keep unauthorized behavior unchanged because it represents credential state, not a transient server failure.

- [ ] **Step 6: Preserve AnySearch structured text at exhaustion**

In `APIKey.quotaPresentationPrimaryText`, return AnySearch's structured `quotaDisplayText` before the generic exhausted replacement when `quotaText?.key == .dailyRequestsUsageFormat`. Numeric remaining continues to drive percent, badge, health, and notification logic.

- [ ] **Step 7: Run behavior tests**

Run: `bash Tests/run_behavior_tests.sh`

Expected: full behavior suite passes with no AnySearch unlimited assertion remaining.

- [ ] **Step 8: Commit**

```bash
git add QuotaRadar/Services/QuotaService.swift QuotaRadar/Models/APIKey.swift QuotaRadar/Models/QuotaMonitor.swift Tests/run_behavior_tests.sh
git commit -m "fix: query AnySearch daily quota"
```

### Task 5: Link, delete, and migrate credentials without duplication

**Files:**
- Modify: `Tests/run_behavior_tests.sh`
- Modify: `QuotaRadar/Models/QuotaMonitor.swift`
- Modify: `QuotaRadar/Views/SettingsView.swift`

- [ ] **Step 1: Add failing lifecycle tests**

Cover these arrays of in-memory `APIKey` values:

1. Existing unlinked `ANYSEARCH_API_KEY` plus newly saved `ANYSEARCH_SESSION` becomes one linked pair.
2. Re-saving authorization updates/reuses the authorization and does not add another API key.
3. Deleting authorization keeps the API key and clears its link.
4. Recapturing authorization reclaims the orphan/unlinked API key.
5. Deleting the API key leaves authorization intact.

Assert no raw session value is returned by `copyableCredentialValue`.

- [ ] **Step 2: Run tests and verify failure**

Run: `bash Tests/run_behavior_tests.sh`

Expected: FAIL on delete-authorization link cleanup and/or recapture relinking.

- [ ] **Step 3: Extract pure link helpers**

Add small internal helpers in `QuotaMonitor` for clearing links that point to a removed authorization and for choosing a reusable companion key whose link is nil or points to a missing authorization. Use these helpers from `removeKey` and the settings save path rather than duplicating conditions.

- [ ] **Step 4: Update save/delete behavior**

Before deleting a non-copy-only dashboard authorization, clear matching companion `linkedAuthorizationID` values and persist the survivors. When saving a companion after authorization capture, prefer a key linked to that authorization, then an unlinked key, then an orphan whose authorization ID no longer exists; create a new record only if none exists.

- [ ] **Step 5: Run behavior tests**

Run: `bash Tests/run_behavior_tests.sh`

Expected: all lifecycle and existing Querit/provider companion tests pass.

- [ ] **Step 6: Commit**

```bash
git add QuotaRadar/Models/QuotaMonitor.swift QuotaRadar/Views/SettingsView.swift Tests/run_behavior_tests.sh
git commit -m "fix: preserve AnySearch companion key links"
```

### Task 6: Synchronize docs and complete live/release QA

**Files:**
- Modify: `docs/providers.md`
- Modify: `docs/providers.zh-Hans.md`
- Modify: `docs/roadmap.md`
- Modify: `docs/roadmap.zh-Hans.md`
- Modify: `docs/quickstart.md`
- Modify: `docs/quickstart.zh-Hans.md`
- Modify: `docs/tauri-provider-migration-checklist.md`
- Verify: `QuotaRadar/Info.plist`
- Verify: `.github/workflows/release.yml`

- [ ] **Step 1: Replace stale AnySearch documentation**

Document the dashboard authorization plus companion API key model, 1,000 requests per UTC day, explicit usage-summary endpoint, UTC reset, API-key-only limitation, and one-time save requirement. Remove all unlimited/no-remote-endpoint claims and the stale `.ai` URL. Do not change unrelated provider calibration statements.

- [ ] **Step 2: Run static and behavior verification**

Run:

```bash
git diff --check
bash Tests/run_behavior_tests.sh
rg -n "Unlimited free usage|app\.anysearch\.ai|AnySearch.*unlimited|AnySearch.*无限" QuotaRadar Tests docs README* TODO*
```

Expected: diff check and behavior suite pass; stale search returns no live capability claims.

- [ ] **Step 3: Build the app**

Run the repository's existing macOS build command used by the release branch (derive the exact scheme/configuration from the current release QA scripts rather than inventing one).

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Perform live logged-in acceptance**

Using the current AnySearch console login, save `ANYSEARCH_SESSION` through QuotaRadar and verify local persisted metadata shows HTTP 200, limit 1,000, today's exact used count, computed remaining, next UTC reset, and a fresh last-success timestamp. Never print the session or API key.

- [ ] **Step 5: Verify one real request delta**

Record the current bounded UTC-day `total_requests`, issue one normal `POST https://api.anysearch.com/v1/search` using the saved API key, refresh quota, and confirm used increases and remaining decreases by the observed delta. Do not expose the query key or raw response content.

- [ ] **Step 6: Verify restart persistence**

Restart the locally built app without clearing defaults/database. Confirm the API-key record, authorization record, structured used/remaining/limit text, reset time, and last-success timestamp restore correctly.

- [ ] **Step 7: Run release guards without publishing**

Run the existing release QA guards, including standard/white-label URL leak checks where safe. Confirm `CFBundleShortVersionString` remains 0.4.6 and both standard/white-label workflow definitions remain intact. Do not push, tag, upload, or create a GitHub Release.

- [ ] **Step 8: Commit docs and QA evidence-safe changes**

```bash
git add docs/providers.md docs/providers.zh-Hans.md docs/roadmap.md docs/roadmap.zh-Hans.md docs/quickstart.md docs/quickstart.zh-Hans.md docs/tauri-provider-migration-checklist.md
git commit -m "docs: calibrate AnySearch daily quota"
```

- [ ] **Step 9: Final verification**

Run:

```bash
git status --short --branch
git log -8 --oneline --decorate
git diff origin/main...HEAD --check
```

Expected: clean local `release/v0.4.6`, all new commits present, no remote push or `v0.4.6` tag created.
