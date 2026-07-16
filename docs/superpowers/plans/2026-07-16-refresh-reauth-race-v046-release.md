# Refresh/Reauthentication Race Repair And v0.4.6 Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent stale in-flight refresh results and side effects from overwriting newer credential changes, then prepare and fully validate Quota Radar v0.4.6 Build 20.

**Architecture:** Replace QuotaMonitor's whole-array refresh commit with a pure per-credential optimistic reconciliation step. Provider calls produce deferred result records; reconciliation accepts only results whose credential or derived source mutation signature is unchanged, and only accepted records may update credentials, history, notifications, or failure UI. Release metadata and notes are then updated together before running every standard and white-label release gate.

**Tech Stack:** Swift 5.9, Foundation, Combine, shell-driven Swift behavior tests, SwiftPM, AppKit visual QA, hdiutil, codesign, GitHub Actions YAML.

---

### Task 1: Add failing optimistic-reconciliation behavior tests

**Files:**
- Modify: `Tests/run_behavior_tests.sh` in the `Quota monitor behavior` Swift fixture
- Reference: `QuotaRadar/Models/APIKey.swift`
- Reference: `QuotaRadar/Models/QuotaHistory.swift`
- Reference: `QuotaRadar/Models/QuotaMonitor.swift`

- [ ] **Step 1: Add fixture builders for refresh-owned and user-owned changes**

Add small Swift helpers inside the quota-monitor fixture:

```swift
func refreshKey(
    id: UUID,
    provider: Provider = .volcengineCodingPlan,
    secret: String = "old-secret",
    isActive: Bool = true,
    lastUpdated: Date = Date(timeIntervalSince1970: 100),
    remaining: Int? = 100
) -> APIKey {
    APIKey(
        id: id,
        name: provider.defaultCredentialName,
        key: secret,
        provider: provider,
        isActive: isActive,
        remaining: remaining,
        limit: 1000,
        lastUpdated: lastUpdated,
        quotaLabel: "old"
    )
}
```

- [ ] **Step 2: Add red tests for ordinary and concurrent credential reconciliation**

Specify the intended internal API:

```swift
let reconciliation = QuotaMonitor.reconcileRefreshResults(
    startedWith: [original],
    results: [.init(key: refreshed, outcome: .success, countsAsFailure: false)],
    current: [current]
)
```

Assert:

- unchanged credentials receive every refresh-owned field: `remaining`, `limit`, `resetAt`, `planEndsAt`, `planDisplayName`, both Codex reset-credit fields, quota label/text, HTTP/diagnostic fields, failure count, and refresh timestamp;
- current `usageCount` and `lastUsed` survive an accepted refresh;
- a current credential rejects the stale refresh result when any mutation-signature field changes: secret, name, provider, active state, note, linked authorization ID, or last-updated timestamp;
- edit, disable, delete, and add-during-refresh states remain current;
- rejected results are absent from `acceptedResults` so they cannot write history or failure banners;
- accepted success and failure results appear exactly once with their original outcome/failure flag.

- [ ] **Step 3: Add red tests for derived shared-dashboard credentials**

Construct Anthropic Credits candidates linked to Claude Subscription authorizations. Assert derived results append only when each source remains active and its mutation signature is unchanged. Define a direct credential as a same-provider, non-copy-only row whose `linkedAuthorizationID == nil`; linked derived rows are not direct credentials. Assert derived results are rejected when any source signature field changes, the source is deleted, or a direct Anthropic Credits credential is concurrently added. Add two-source tests proving eligible derived results append independently in result order and are not suppressed by the first appended derived row.

- [ ] **Step 4: Run the full behavior suite and verify the new tests fail for the missing API**

Run:

```bash
bash Tests/run_behavior_tests.sh
```

Expected: non-zero exit with a compile failure stating that `QuotaMonitor.reconcileRefreshResults` or its deferred result type does not exist. Fix only fixture syntax if necessary; do not add production code until the failure is about the missing behavior.

### Task 2: Implement the pure refresh reconciliation policy

**Files:**
- Modify: `QuotaRadar/Models/QuotaMonitor.swift` near `refreshCandidateKeys` and refresh persistence helpers
- Test: `Tests/run_behavior_tests.sh`

- [ ] **Step 1: Add internal deferred result and reconciliation value types**

Add internal nested types on `QuotaMonitor`:

```swift
struct DeferredRefreshResult {
    var key: APIKey
    var outcome: QuotaSnapshotOutcome?
    var countsAsFailure: Bool
}

struct RefreshReconciliation {
    var keys: [APIKey]
    var acceptedResults: [DeferredRefreshResult]
}

private struct RefreshMutationSignature: Equatable {
    let key: String
    let name: String
    let provider: Provider
    let isActive: Bool
    let note: String?
    let linkedAuthorizationID: UUID?
    let lastUpdated: Date?

    init(_ key: APIKey) {
        self.key = key.key
        name = key.name
        provider = key.provider
        isActive = key.isActive
        note = key.note
        linkedAuthorizationID = key.linkedAuthorizationID
        lastUpdated = key.lastUpdated
    }
}
```

- [ ] **Step 2: Add a focused refresh-metadata copier**

Create a helper that starts with the current credential and copies only refresh-owned fields from the accepted result:

```swift
private static func applyingRefreshMetadata(from refreshed: APIKey, to current: APIKey) -> APIKey {
    var merged = current
    merged.remaining = refreshed.remaining
    merged.limit = refreshed.limit
    merged.resetAt = refreshed.resetAt
    merged.planEndsAt = refreshed.planEndsAt
    merged.planDisplayName = refreshed.planDisplayName
    merged.codexResetCreditsRemaining = refreshed.codexResetCreditsRemaining
    merged.codexResetCreditsEarliestExpiresAt = refreshed.codexResetCreditsEarliestExpiresAt
    merged.quotaLabel = refreshed.quotaLabel
    merged.quotaText = refreshed.quotaText
    merged.lastHTTPStatus = refreshed.lastHTTPStatus
    merged.lastDiagnosticMessage = refreshed.lastDiagnosticMessage
    merged.lastDiagnosticText = refreshed.lastDiagnosticText
    merged.consecutiveFailureCount = refreshed.consecutiveFailureCount
    merged.lastUpdated = refreshed.lastUpdated
    return merged
}
```

- [ ] **Step 3: Implement per-credential reconciliation**

Implement `nonisolated static func reconcileRefreshResults(startedWith:results:current:) -> RefreshReconciliation` with these exact rules:

1. Preserve current order and start from `current`.
2. For a result whose ID existed at start: reject if the key was deleted or if the current mutation signature differs from the start signature; otherwise apply refresh metadata to the current row and accept the merged result.
3. Capture `let completionKeys = current` before merging. For a derived result not present at start: require `linkedAuthorizationID`, an unchanged start/completion source signature, a completion-time active source, and no completion-time direct credential for the derived provider. A direct credential has the same provider, `linkedAuthorizationID == nil`, and is not copy-only. Never compare derived eligibility against the progressively merged output.
4. Append eligible derived rows once, in result order.
5. Return only accepted results in `acceptedResults`, replacing each accepted record's key with the merged/appended key.

- [ ] **Step 4: Run the behavior suite and verify the reconciliation tests pass**

Run:

```bash
bash Tests/run_behavior_tests.sh
```

Expected: exit 0 and `All behavior tests passed`.

- [ ] **Step 5: Commit the pure policy and tests**

```bash
git add QuotaRadar/Models/QuotaMonitor.swift Tests/run_behavior_tests.sh
git commit -m "fix: reconcile concurrent quota refresh results"
```

### Task 3: Integrate deferred side effects into the live refresh loop

**Files:**
- Modify: `QuotaRadar/Models/QuotaMonitor.swift` in `refresh(targetProviders:mode:)`
- Modify: `QuotaRadar/Services/QuotaNotificationService.swift`
- Test: `Tests/run_behavior_tests.sh`

- [ ] **Step 1: Add failing integration and notification-scope tests before implementation**

Extend the quota-monitor source-safety fixture to require that the live refresh function:

- accumulates deferred records without calling `recordQuotaSnapshot` inside the provider loop;
- calls `reconcileRefreshResults` before any result-specific snapshot or failure aggregation;
- derives snapshot writes, failed-key names, and affected notification key IDs only from `acceptedResults`.

Extend the threshold-notification fixture with a scoped update API:

```swift
store.clearResolvedEvents(
    retainingActive: activeEvents,
    affectedKeyIDs: [acceptedKeyID]
)
```

Assert scoped clearing preserves delivered event IDs for unaffected credentials, clears resolved IDs only for affected credentials, and new notification selection is restricted to affected IDs while the complete active-event set is retained for deduplication.

Run `bash Tests/run_behavior_tests.sh`. Expected: non-zero exit because accepted-result notification scoping and the deferred live integration do not exist yet.

- [ ] **Step 2: Capture stable inputs and accumulate deferred results**

Immediately after `ensureSecretsLoaded()`, capture `let refreshStartKeys = apiKeys` and call `refreshCandidateKeys(from: refreshStartKeys, ...)`. Replace `updatedKeys` and `failedKeys` accumulation with `[DeferredRefreshResult]`.

For every attempted/skipped provider result, preserve the existing mutations to the local `key`, but append a deferred record instead of calling `recordQuotaSnapshot`. Preserve `outcome == nil` for cooldown, which must not create a snapshot. Set `countsAsFailure` only for the same cases that currently append to `failedKeys`.

- [ ] **Step 3: Reconcile before committing any side effect**

At task completion:

```swift
let reconciliation = Self.reconcileRefreshResults(
    startedWith: refreshStartKeys,
    results: deferredResults,
    current: apiKeys
)
apiKeys = reconciliation.keys

for result in reconciliation.acceptedResults {
    if let outcome = result.outcome {
        recordQuotaSnapshot(for: result.key, outcome: outcome)
    }
}
let failedKeys = reconciliation.acceptedResults
    .filter(\.countsAsFailure)
    .map { $0.key.name }
let affectedNotificationKeyIDs = Set(reconciliation.acceptedResults.map { $0.key.id })
```

Then retain the existing refresh message, persistence, and `isRefreshing` cleanup flow. Call threshold notification evaluation only when `affectedNotificationKeyIDs` is non-empty, passing the complete current key/snapshot state plus the accepted ID scope. Stale rejected results must not affect any result-specific side effect.

- [ ] **Step 4: Add accepted-key notification scoping**

Add optional `affectedKeyIDs` scoping to `QuotaThresholdNotificationService.notifyIfNeeded` and `QuotaThresholdNotificationStore.clearResolvedEvents`. Always calculate the complete active-event set from current keys/history so unaffected delivery IDs are retained. Filter fresh delivery and resolved-event clearing to affected credential IDs when a scope is supplied. Keep the existing unscoped behavior for other callers.

- [ ] **Step 5: Run full behavior tests**

```bash
bash Tests/run_behavior_tests.sh
```

Expected: exit 0, Debug/Release builds complete, app bundle signature valid, and `All behavior tests passed`.

- [ ] **Step 6: Commit integration changes**

```bash
git add QuotaRadar/Models/QuotaMonitor.swift QuotaRadar/Services/QuotaNotificationService.swift Tests/run_behavior_tests.sh
git commit -m "fix: defer refresh side effects until reconciliation"
```

### Task 4: Prepare v0.4.6 Build 20 release metadata and notes

**Files:**
- Modify: `QuotaRadar/Info.plist`
- Modify: `Tests/run_behavior_tests.sh:62-64`
- Modify: `README.md:15,127-129`
- Modify: `README.zh-Hans.md:15,122-124`
- Modify: `docs/roadmap.md` near the current release section
- Modify: `docs/roadmap.zh-Hans.md` near the current release section
- Modify: `.github/workflows/release.yml` release body

- [ ] **Step 1: Write red release-version assertions**

Change behavior assertions to require exact plist values:

```bash
assert_match '<string>0\.4\.6</string>' \
  "QuotaRadar/Info.plist" \
  "Quota Radar 0.4.6 should be recorded in Info.plist"
assert_match '<string>20</string>' \
  "QuotaRadar/Info.plist" \
  "Quota Radar Build 20 should be recorded in Info.plist"
```

Run `bash Tests/run_behavior_tests.sh` and expect failure because Info.plist still contains `0.4.5 / 19`.

- [ ] **Step 2: Update bundle version metadata**

Set:

```xml
<key>CFBundleShortVersionString</key>
<string>0.4.6</string>
<key>CFBundleVersion</key>
<string>20</string>
```

- [ ] **Step 3: Update README release surfaces**

Set current version and manual release commands to `v0.4.6`. Use release notes that summarize:

- reliable dashboard credential recapture after rejected/stale authorization;
- Aliyun protected-route capture;
- Volcengine bounded CSRF rotation and exact no-subscription response;
- OpenCode exact null/no-subscription framing;
- Tencent explicit unauthorized classification and passive recapture;
- optimistic refresh reconciliation that prevents newer authentication state from being overwritten.

Keep English and Simplified Chinese wording semantically aligned.

- [ ] **Step 4: Add v0.4.6 roadmap/release-note sections**

Add matching top sections to both roadmap files. Separate provider-specific fixes from the shared refresh reconciliation, and state that credential values remain local and are never included in diagnostics.

- [ ] **Step 5: Update GitHub Release workflow notes**

Replace the v0.4.5 Codex-only release body in `.github/workflows/release.yml` with the same concise v0.4.6 English/Chinese summary. Do not change workflow triggers or upload paths.

- [ ] **Step 6: Run version-focused and full behavior verification**

```bash
plutil -extract CFBundleShortVersionString raw QuotaRadar/Info.plist
plutil -extract CFBundleVersion raw QuotaRadar/Info.plist
bash Tests/run_behavior_tests.sh
```

Expected: `0.4.6`, `20`, then exit 0 with `All behavior tests passed`.

- [ ] **Step 7: Commit release preparation**

```bash
git add QuotaRadar/Info.plist Tests/run_behavior_tests.sh README.md README.zh-Hans.md docs/roadmap.md docs/roadmap.zh-Hans.md .github/workflows/release.yml
git commit -m "release: prepare v0.4.6"
```

### Task 5: Run shared source and visual release gates

**Files:**
- Verify: `docs/release-qa.md`
- Generate: `build/visual-qa/summary.txt`
- Generate: `build/visual-qa/summary.json`
- Generate: `build/visual-qa/*.png`

- [ ] **Step 1: Verify worktree and source formatting**

```bash
git status --short --branch
git diff --check v0.4.5..HEAD
```

Expected: clean worktree and no whitespace errors.

- [ ] **Step 2: Run behavior tests again on the exact release commit**

```bash
bash Tests/run_behavior_tests.sh
```

Expected: exit 0 and `All behavior tests passed`.

- [ ] **Step 3: Run visual QA**

```bash
bash Tests/run_visual_qa.sh
```

Expected: exit 0. Inspect `build/visual-qa/summary.txt`, `build/visual-qa/summary.json`, and every listed screenshot; require no clipping, overlap, credential leakage, desktop-background leakage, or scenario failure.

- [ ] **Step 4: Run both source secret scans exactly as documented**

```bash
rg -n --hidden \
  --glob '!.git/**' \
  --glob '!build/**' \
  --glob '!.build/**' \
  --glob '!.build-white-label/**' \
  'sk-(live|proj|ant|or|svcacct|admin)-[A-Za-z0-9_-]{16,}|sk-[A-Za-z0-9_-]{32,}|AIza[0-9A-Za-z_-]{30,}|AKIA[0-9A-Z]{16}|xox[baprs]-[0-9A-Za-z-]{20,}|gh[pousr]_[0-9A-Za-z_]{30,}' .

rg -n --hidden \
  --glob '!.git/**' \
  --glob '!build/**' \
  --glob '!.build/**' \
  --glob '!.build-white-label/**' \
  --glob '!Tests/run_behavior_tests.sh' \
  --glob '!docs/release-qa.md' \
  --glob '!docs/release-qa.zh-Hans.md' \
  "(authorization: *bearer +[A-Za-z0-9._-]{20,}|cookie: *[\"']?[^\"'<[:space:]]+=[^\"'<]{20,}|sessionKeyLC=[^;[:space:]]{20,}|__Secure-next-auth[^=]*=[^;[:space:]]{20,}|secretAccessKey[\"=: ]+[A-Za-z0-9/+]{20,}|secretKey[\"=: ]+[A-Za-z0-9/+]{20,})" .
```

Expected: no high-confidence credential matches outside explicitly redacted fixtures and no raw authorization/Cookie values.

- [ ] **Step 5: Run the additional Tauri source consistency gate**

```bash
bash scripts/check_tauri_sources.sh
```

Expected: exit 0.

### Task 6: Build and verify standard and white-label DMGs

**Files:**
- Generate: `build/QuotaRadar.dmg`
- Generate: `build/QuotaRadar-WhiteLabel.dmg`
- Verify: `build/Quota Radar.app`

- [ ] **Step 1: Build the standard updater DMG**

```bash
scripts/package_dmg.sh --rebuild
```

Expected: exit 0 and non-empty `build/QuotaRadar.dmg`.

- [ ] **Step 2: Verify standard updater URLs, DMG, signature, and mounted contents**

```bash
strings 'build/Quota Radar.app/Contents/MacOS/QuotaRadar' | rg -F \
  'https://api.github.com/repos/Asklear/QuotaRadar/releases/latest'
strings 'build/Quota Radar.app/Contents/MacOS/QuotaRadar' | rg -F \
  'https://github.com/Asklear/QuotaRadar/releases/latest'
test -s build/QuotaRadar.dmg
hdiutil verify build/QuotaRadar.dmg
codesign --verify --deep --strict --verbose=2 'build/Quota Radar.app'
test "$(plutil -extract CFBundleShortVersionString raw 'build/Quota Radar.app/Contents/Info.plist')" = '0.4.6'
test "$(plutil -extract CFBundleVersion raw 'build/Quota Radar.app/Contents/Info.plist')" = '20'

STANDARD_MOUNT_DIR="$(mktemp -d)"
hdiutil attach build/QuotaRadar.dmg -mountpoint "$STANDARD_MOUNT_DIR" -nobrowse -quiet
test -d "$STANDARD_MOUNT_DIR/Quota Radar.app"
test -L "$STANDARD_MOUNT_DIR/Applications"
codesign --verify --deep --strict --verbose=2 "$STANDARD_MOUNT_DIR/Quota Radar.app"
test "$(plutil -extract CFBundleShortVersionString raw "$STANDARD_MOUNT_DIR/Quota Radar.app/Contents/Info.plist")" = '0.4.6'
test "$(plutil -extract CFBundleVersion raw "$STANDARD_MOUNT_DIR/Quota Radar.app/Contents/Info.plist")" = '20'
hdiutil detach "$STANDARD_MOUNT_DIR" -quiet
rmdir "$STANDARD_MOUNT_DIR"
```

- [ ] **Step 3: Build the white-label DMG**

```bash
scripts/package_dmg.sh --rebuild --white-label
```

Expected: exit 0 and non-empty `build/QuotaRadar-WhiteLabel.dmg`.

- [ ] **Step 4: Verify white-label URL absence, DMG, signature, and mounted contents**

```bash
rg -n 'QUOTARADAR_DISABLE_GITHUB_UPDATER|-DQUOTARADAR_DISABLE_GITHUB_UPDATER' \
  install.sh scripts/package_dmg.sh QuotaRadar/Services/GitHubReleaseUpdater.swift

if strings 'build/Quota Radar.app/Contents/MacOS/QuotaRadar' | \
  rg 'Asklear/QuotaRadar|api\.github\.com/repos/Asklear/QuotaRadar|github\.com/Asklear/QuotaRadar/releases/latest'; then
  echo 'White-label app leaked an updater URL' >&2
  exit 1
fi
if strings build/QuotaRadar-WhiteLabel.dmg | \
  rg 'Asklear/QuotaRadar|api\.github\.com/repos/Asklear/QuotaRadar|github\.com/Asklear/QuotaRadar/releases/latest'; then
  echo 'White-label DMG leaked an updater URL' >&2
  exit 1
fi

test -s build/QuotaRadar-WhiteLabel.dmg
hdiutil verify build/QuotaRadar-WhiteLabel.dmg
codesign --verify --deep --strict --verbose=2 'build/Quota Radar.app'
test "$(plutil -extract CFBundleShortVersionString raw 'build/Quota Radar.app/Contents/Info.plist')" = '0.4.6'
test "$(plutil -extract CFBundleVersion raw 'build/Quota Radar.app/Contents/Info.plist')" = '20'

WHITE_LABEL_MOUNT_DIR="$(mktemp -d)"
hdiutil attach build/QuotaRadar-WhiteLabel.dmg -mountpoint "$WHITE_LABEL_MOUNT_DIR" -nobrowse -quiet
test -d "$WHITE_LABEL_MOUNT_DIR/Quota Radar.app"
test -L "$WHITE_LABEL_MOUNT_DIR/Applications"
codesign --verify --deep --strict --verbose=2 "$WHITE_LABEL_MOUNT_DIR/Quota Radar.app"
test "$(plutil -extract CFBundleShortVersionString raw "$WHITE_LABEL_MOUNT_DIR/Quota Radar.app/Contents/Info.plist")" = '0.4.6'
test "$(plutil -extract CFBundleVersion raw "$WHITE_LABEL_MOUNT_DIR/Quota Radar.app/Contents/Info.plist")" = '20'
hdiutil detach "$WHITE_LABEL_MOUNT_DIR" -quiet
rmdir "$WHITE_LABEL_MOUNT_DIR"
```

- [ ] **Step 5: Record artifact metadata without exposing credentials**

```bash
shasum -a 256 build/QuotaRadar.dmg build/QuotaRadar-WhiteLabel.dmg
stat -f '%Sm %z %N' -t '%Y-%m-%d %H:%M:%S %z' build/QuotaRadar.dmg build/QuotaRadar-WhiteLabel.dmg
plutil -extract CFBundleShortVersionString raw 'build/Quota Radar.app/Contents/Info.plist'
plutil -extract CFBundleVersion raw 'build/Quota Radar.app/Contents/Info.plist'
```

Expected: two hashes, non-zero sizes, version `0.4.6`, Build `20`.

### Task 7: Independent review and final release-readiness report

**Files:**
- Review: `QuotaRadar/Models/QuotaMonitor.swift`
- Review: `Tests/run_behavior_tests.sh`
- Review: all v0.4.6 release surfaces and QA artifacts

- [ ] **Step 1: Request independent code review**

Use @requesting-code-review with base `069aab5` and final release-preparation HEAD. Require review of optimistic reconciliation, deferred side effects, derived authorization handling, version alignment, secrets, and release QA evidence.

- [ ] **Step 2: Resolve every Critical and Important finding**

Use @receiving-code-review and TDD for behavior changes. Re-run affected focused tests plus the full behavior suite. Re-run packaging gates if source changes affect artifacts.

- [ ] **Step 3: Run final verification on the reviewed HEAD**

```bash
git diff --check v0.4.5..HEAD
git status --short --branch
bash Tests/run_behavior_tests.sh
codesign --verify --deep --strict --verbose=2 'build/Quota Radar.app'
```

If the final behavior run rebuilds only the app bundle after DMG QA, do not claim the existing DMGs match the reviewed HEAD unless source is unchanged from their build commit; otherwise rebuild and reverify both DMGs.

- [ ] **Step 4: Report readiness without publishing**

Report commits, tests, visual QA summary, artifact hashes/sizes, version readback, review findings, and any remaining risk. Do not merge, push, tag, create a GitHub Release, or replace `/Applications` without a separate explicit instruction.
