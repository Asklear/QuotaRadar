# Quota Trends And Menu Prioritization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add lightweight quota history, infer the most-used providers from recent quota consumption, and surface that signal in the menu bar without making Quota Radar feel like a heavy reporting dashboard.

**Architecture:** Keep status first. Persist bounded, non-secret quota snapshots after refreshes, compute trend and recent-consumption summaries from those snapshots, then attach compact cues to existing provider/account rows and menu-bar sections. Existing reset-time and plan-expiry presentation stays as-is.

**Tech Stack:** Swift 5.9, SwiftUI, local JSON persistence under Application Support, existing `UserDefaults` metadata, existing bash behavior tests.

---

## Product Direction

The next useful information is not another static account field. Quota Radar already shows account-level quota reset timing and account-level package expiry. The missing pieces are:

- Whether quota is moving: recent remaining quota decreased, recovered, stayed stable, or cannot be compared yet.
- Which providers are actually being consumed most recently.
- Whether a refresh changed anything, without requiring the user to remember the prior value.
- A menu-bar view that remains decision-oriented: urgent/risky providers first, recent/common providers second.

Non-goals for this round:

- Do not add a full trend dashboard.
- Do not add large charts or a permanent trend column.
- Do not reintroduce diagnostics-only metadata into the normal UI.
- Do not use provider-level banners for account-level plan names, reset times, or expiry.

## File Structure

- Create `QuotaRadar/Models/QuotaHistory.swift`
  - Own `QuotaSnapshot`, `QuotaSnapshotOutcome`, `QuotaTrendDirection`, `QuotaTrendSummary`, and recent-consumption ranking helpers.
  - Keep the model secret-free: no API key, cookie, token, authorization header, or raw request payload.
- Create `QuotaRadar/Services/QuotaHistoryStore.swift`
  - Persist snapshots to `~/Library/Application Support/QuotaRadar/quota-history.json`.
  - Bound retention by key and age.
  - Expose load, append, prune, and delete-by-key APIs.
- Modify `QuotaRadar/Models/QuotaMonitor.swift`
  - Inject and load `QuotaHistoryStore`.
  - Record snapshots after each attempted quota refresh.
  - Expose computed trend summaries and menu common-provider items.
  - Delete history when a credential is removed.
- Modify `QuotaRadar/Models/APIKey.swift`
  - Keep existing `usageCount` and `lastUsed`.
  - Add presentation hooks for trend badges only if they are pure derived state.
  - Add `MenuQuotaItem` helpers for recent/common provider ranking.
- Modify `QuotaRadar/Views/MenuContentView.swift`
  - Add a compact "recent consumption/common providers" section after risk sections.
  - Reuse existing row density and avoid duplicate rows already shown in attention/low/expiring sections.
- Modify `QuotaRadar/Views/SettingsView.swift`
  - Add compact per-account trend text or icon in the existing account row.
  - Remove the quota-page "Test Connection" button if it remains functionally identical to refresh.
- Modify `QuotaRadar/Models/AppLanguage.swift`
  - Add localized strings for trend direction, recent consumption, unchanged quota, replenished quota, and refresh history copy.
- Modify `Tests/run_behavior_tests.sh`
  - Add structural and algorithm checks for snapshot persistence, pruning, trend calculation, menu ranking, and compact UI placement.
- Optionally modify `TODO.md` and `TODO.en.md` after implementation
  - Mark snapshot/trend/menu items complete and leave recovery notifications as a follow-up.

## Task 1: Remove Redundant Quota-Page Test Connection

**Why first:** In the quota monitor row, `testConnectionForProvider(_:)` currently calls `refreshProvider(provider, mode: .manual)`. If both buttons do the same thing, the row is noisier than it needs to be.

**Files:**
- Modify: `QuotaRadar/Views/SettingsView.swift`
- Modify: `QuotaRadar/Models/QuotaMonitor.swift`
- Test: `Tests/run_behavior_tests.sh`

- [ ] **Step 1: Write failing behavior assertions**

Update `Tests/run_behavior_tests.sh` so the quota monitoring action group no longer requires a separate test action:

```bash
assert_not_match 'onTestConnection' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota monitor rows should not expose a duplicate Test Connection action"
assert_not_match 'TestConnectionButton\(size: size, action: onTestConnection\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "The quota page provider action group should use refresh as the single quota-check action"
```

If connection testing is still needed in credential setup later, add that as a separate scoped task instead of keeping a duplicate provider-row action.

- [ ] **Step 2: Run the behavior script and confirm failure**

Run:

```bash
bash Tests/run_behavior_tests.sh
```

Expected: FAIL on the new duplicate-button assertions.

- [ ] **Step 3: Remove the duplicate UI path**

In `ProviderQuotaActionGroup`, remove:

- `let onTestConnection: () -> Void`
- the `TestConnectionButton` slot
- call sites passing `onTestConnection`

Then remove `TestConnectionButton` and `QuotaMonitor.testConnectionForProvider(_:)` if no other source file uses them.

- [ ] **Step 4: Verify and commit**

Run:

```bash
bash Tests/run_behavior_tests.sh
git diff --check
```

Expected: PASS. Commit:

```bash
git add QuotaRadar/Views/SettingsView.swift QuotaRadar/Models/QuotaMonitor.swift Tests/run_behavior_tests.sh
git commit -m "ui: remove duplicate quota test action"
```

## Task 2: Add Bounded Quota Snapshot Persistence

**Why:** Trend and "most-used provider" need evidence across refreshes. The current `APIKey` metadata only stores the latest state.

**Files:**
- Create: `QuotaRadar/Models/QuotaHistory.swift`
- Create: `QuotaRadar/Services/QuotaHistoryStore.swift`
- Modify: `QuotaRadar/Models/QuotaMonitor.swift`
- Test: `Tests/run_behavior_tests.sh`

- [ ] **Step 1: Write failing model/store assertions**

Add assertions:

```bash
assert_match 'struct QuotaSnapshot' \
  "QuotaRadar/Models/QuotaHistory.swift" \
  "Quota history should persist refresh snapshots"
assert_match 'enum QuotaSnapshotOutcome' \
  "QuotaRadar/Models/QuotaHistory.swift" \
  "Quota history should record refresh outcome without raw secrets"
assert_match 'struct QuotaHistoryStore' \
  "QuotaRadar/Services/QuotaHistoryStore.swift" \
  "Quota history should use a dedicated store"
assert_match 'quota-history\.json' \
  "QuotaRadar/Services/QuotaHistoryStore.swift" \
  "Quota history should persist outside API key metadata"
```

- [ ] **Step 2: Run test to verify failure**

Run:

```bash
bash Tests/run_behavior_tests.sh
```

Expected: FAIL because the new files do not exist.

- [ ] **Step 3: Implement `QuotaSnapshot`**

Create a model with these fields:

```swift
struct QuotaSnapshot: Codable, Identifiable, Equatable {
    var id: UUID
    var keyID: UUID
    var provider: Provider
    var credentialName: String
    var recordedAt: Date
    var outcome: QuotaSnapshotOutcome
    var remaining: Int?
    var limit: Int?
    var resetAt: Date?
    var planEndsAt: Date?
    var planDisplayName: String?
    var quotaLabel: String?
    var httpStatus: Int?
}
```

Add helpers:

```swift
var percentRemaining: Double?
var consumed: Int?
var isComparableQuotaSnapshot: Bool
```

The model must not include raw credential strings or raw response bodies.

- [ ] **Step 4: Implement `QuotaHistoryStore`**

Use Application Support, similar to `FileSecretStore`, but write to `quota-history.json`.

Required API:

```swift
struct QuotaHistoryStore {
    func load() -> [QuotaSnapshot]
    func append(_ snapshot: QuotaSnapshot, existing: [QuotaSnapshot]) -> [QuotaSnapshot]
    func save(_ snapshots: [QuotaSnapshot])
    func deleteSnapshots(for keyID: UUID, existing: [QuotaSnapshot]) -> [QuotaSnapshot]
}
```

Retention rules:

- Keep at most 60 snapshots per key.
- Drop snapshots older than 45 days.
- Sort newest last after pruning.

- [ ] **Step 5: Wire store into `QuotaMonitor`**

Add:

```swift
@Published private(set) var quotaSnapshots: [QuotaSnapshot] = []
private let historyStore: QuotaHistoryStore
```

Load history in `init`. After each quota check attempt, append a snapshot:

- `.success` for successful quota checks.
- `.unsupported`, `.unauthorized`, `.noSubscription`, or `.failed` for handled errors.
- Preserve `remaining`, `limit`, reset, plan, label, and HTTP status when available.

Call `historyStore.deleteSnapshots(for:)` from `removeKey(id:)`.

- [ ] **Step 6: Verify and commit**

Run:

```bash
bash Tests/run_behavior_tests.sh
git diff --check
```

Expected: PASS. Commit:

```bash
git add QuotaRadar/Models/QuotaHistory.swift QuotaRadar/Services/QuotaHistoryStore.swift QuotaRadar/Models/QuotaMonitor.swift Tests/run_behavior_tests.sh
git commit -m "feat: persist quota refresh snapshots"
```

## Task 3: Compute Trend And Most-Used Provider Ranking

**Why:** `usageCount` and `lastUsed` already persist, but they should be fallback signals. The primary signal for "most used" should be observed quota depletion between snapshots.

**Files:**
- Modify: `QuotaRadar/Models/QuotaHistory.swift`
- Modify: `QuotaRadar/Models/APIKey.swift`
- Modify: `QuotaRadar/Models/QuotaMonitor.swift`
- Test: `Tests/run_behavior_tests.sh`

- [ ] **Step 1: Write failing algorithm checks**

Add a Swift snippet to `Tests/run_behavior_tests.sh` that creates snapshots and verifies:

- Remaining quota drop produces `.decreasing`.
- Remaining quota increase or reset-window change produces `.replenished`.
- Tiny changes below 1 percentage point produce `.stable`.
- Provider ranking prefers larger recent depletion.
- Ranking falls back to `usageCount` and `lastUsed` only when snapshot data is unavailable.
- Risk/attention items are not displaced by recent-use items in menu ordering.

- [ ] **Step 2: Run test to verify failure**

Run:

```bash
bash Tests/run_behavior_tests.sh
```

Expected: FAIL on missing trend/ranking APIs.

- [ ] **Step 3: Add trend model**

Add:

```swift
enum QuotaTrendDirection: String, Codable, Equatable {
    case unknown
    case stable
    case decreasing
    case replenished
}

struct QuotaTrendSummary: Equatable {
    var keyID: UUID
    var provider: Provider
    var direction: QuotaTrendDirection
    var consumedPercentPoints: Double
    var consumedUnits: Int?
    var observationCount: Int
    var windowStart: Date?
    var windowEnd: Date?
}
```

Comparison rules:

- Use successful, comparable snapshots only.
- Prefer snapshots from the last 7 days; fall back to the latest 5 comparable snapshots.
- Treat `resetAt` changes plus increased remaining as replenishment, not consumption.
- Treat decreases below 1 percentage point as stable.
- Aggregate provider usage by summed consumed percent points across accounts.

- [ ] **Step 4: Add ranking helpers**

Add APIs such as:

```swift
static func trendSummary(for key: APIKey, snapshots: [QuotaSnapshot], now: Date) -> QuotaTrendSummary
static func recentProviderUsageItems(from stats: [ProviderStats], snapshots: [QuotaSnapshot], limit: Int, providerOrder: [Provider]) -> [MenuQuotaItem]
```

Ranking order:

1. Larger recent consumed percent.
2. Larger consumed units if percent ties.
3. Newer latest snapshot.
4. Higher `usageCount`.
5. Newer `lastUsed`.
6. Existing provider order.

- [ ] **Step 5: Expose computed properties from `QuotaMonitor`**

Add:

```swift
var menuRecentUsageQuotaItems: [MenuQuotaItem]
func trendSummary(for key: APIKey) -> QuotaTrendSummary
```

Ensure recent-usage items exclude keys already shown in attention, low-quota, or expiring-soon sections.

- [ ] **Step 6: Verify and commit**

Run:

```bash
bash Tests/run_behavior_tests.sh
git diff --check
```

Expected: PASS. Commit:

```bash
git add QuotaRadar/Models/QuotaHistory.swift QuotaRadar/Models/APIKey.swift QuotaRadar/Models/QuotaMonitor.swift Tests/run_behavior_tests.sh
git commit -m "feat: compute quota trends and recent provider usage"
```

## Task 4: Add Compact Trend Cues To Account Rows

**Why:** Users should see that quota is changing without opening a chart.

**Files:**
- Modify: `QuotaRadar/Views/SettingsView.swift`
- Modify: `QuotaRadar/Models/AppLanguage.swift`
- Test: `Tests/run_behavior_tests.sh`

- [ ] **Step 1: Write failing UI assertions**

Add assertions for:

```bash
assert_match 'trendSummary\(for: key\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Account rows should read trend summaries"
assert_match 'quotaTrendDecreasing' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Trend labels should be localized"
```

- [ ] **Step 2: Run test to verify failure**

Run:

```bash
bash Tests/run_behavior_tests.sh
```

Expected: FAIL on missing trend UI strings/calls.

- [ ] **Step 3: Add compact row presentation**

In the existing account timing/metadata area, add only one compact cue:

- `7天 -23%` for decreasing quota.
- `已恢复` for replenished quota.
- `稳定` only when there is enough history and no meaningful change.
- Nothing when trend is unknown.

Use a small SF Symbol and tertiary text. Do not add a new full-width row unless the existing row cannot fit cleanly.

- [ ] **Step 4: Verify and commit**

Run:

```bash
bash Tests/run_behavior_tests.sh
git diff --check
```

Expected: PASS. Commit:

```bash
git add QuotaRadar/Views/SettingsView.swift QuotaRadar/Models/AppLanguage.swift Tests/run_behavior_tests.sh
git commit -m "ui: show compact quota trend cues"
```

## Task 5: Surface Recent/Common Providers In The Menu Bar

**Why:** The menu bar should answer two quick questions: what needs attention, and which providers have been consumed recently.

**Files:**
- Modify: `QuotaRadar/Views/MenuContentView.swift`
- Modify: `QuotaRadar/Models/QuotaMonitor.swift`
- Modify: `QuotaRadar/Models/AppLanguage.swift`
- Test: `Tests/run_behavior_tests.sh`

- [ ] **Step 1: Write failing menu assertions**

Add assertions:

```bash
assert_match 'menuRecentUsageQuotaItems' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should expose recent/common provider items for the menu bar"
assert_match 'MenuRecentUsageItemsView' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Menu bar should include a compact recent usage section"
assert_match 'recentProviderUsage' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Recent/common provider menu label should be localized"
```

- [ ] **Step 2: Run test to verify failure**

Run:

```bash
bash Tests/run_behavior_tests.sh
```

Expected: FAIL on missing menu section.

- [ ] **Step 3: Add menu section**

Place the section after urgent/risk sections and before general summary/top items.

Rules:

- Limit to 2 providers by default.
- Hide the section when there is no meaningful snapshot-derived usage.
- Do not duplicate items already shown in attention, low-quota, or expiring-soon sections.
- Row text should be compact, for example `7天 -23%` or `本周消耗较快`.
- Keep refresh affordance consistent with existing `MenuQuotaItemRow`.

- [ ] **Step 4: Verify menu density**

Run the app locally and inspect the menu popover at the current compact size. The section should not push the urgent items below the fold in a normal 560x500 popover.

- [ ] **Step 5: Verify and commit**

Run:

```bash
bash Tests/run_behavior_tests.sh
git diff --check
```

Expected: PASS. Commit:

```bash
git add QuotaRadar/Views/MenuContentView.swift QuotaRadar/Models/QuotaMonitor.swift QuotaRadar/Models/AppLanguage.swift Tests/run_behavior_tests.sh
git commit -m "ui: surface recent provider usage in menu bar"
```

## Task 6: Add Refresh History Copy Without Extra Diagnostics Noise

**Why:** The TODO asks for provider-level refresh history so users can tell whether refresh worked. This should reuse snapshots and stay compact.

**Files:**
- Modify: `QuotaRadar/Models/QuotaHistory.swift`
- Modify: `QuotaRadar/Views/SettingsView.swift`
- Modify: `QuotaRadar/Models/AppLanguage.swift`
- Test: `Tests/run_behavior_tests.sh`

- [ ] **Step 1: Write failing assertions**

Assert that account rows can display a short refresh delta:

```bash
assert_match 'refreshDeltaText' \
  "QuotaRadar/Models/QuotaHistory.swift" \
  "Quota history should explain what changed on the latest refresh"
```

- [ ] **Step 2: Implement compact delta text**

Examples:

- `刚刚更新，无变化`
- `刚刚更新，-120`
- `刚刚恢复`
- `刷新失败`

Use this only where it replaces vague text. Do not add HTTP/proxy/reset debug fields back to the diagnostics page.

- [ ] **Step 3: Verify and commit**

Run:

```bash
bash Tests/run_behavior_tests.sh
git diff --check
```

Expected: PASS. Commit:

```bash
git add QuotaRadar/Models/QuotaHistory.swift QuotaRadar/Views/SettingsView.swift QuotaRadar/Models/AppLanguage.swift Tests/run_behavior_tests.sh
git commit -m "ui: summarize latest quota refresh deltas"
```

## Task 7: Package And Acceptance Check

**Files:**
- Modify only if verification exposes issues.

- [ ] **Step 1: Run behavior and whitespace checks**

```bash
bash Tests/run_behavior_tests.sh
git diff --check
```

Expected: both pass.

- [ ] **Step 2: Rebuild app**

```bash
./build.sh
```

Expected: build succeeds.

- [ ] **Step 3: Package DMG**

```bash
scripts/package_dmg.sh --rebuild
```

Expected: `build/Quota Radar.app` and `build/QuotaRadar.dmg` are updated.

- [ ] **Step 4: Verify signatures/artifacts**

```bash
codesign --verify --deep --strict --verbose=2 "build/Quota Radar.app"
hdiutil verify "build/QuotaRadar.dmg"
```

Expected: both pass.

- [ ] **Step 5: Manual acceptance**

Launch `build/Quota Radar.app` and verify:

- Account rows still show quota reset and package expiry where available.
- Account rows now show only compact trend/delta cues.
- Menu bar still prioritizes urgent/risky providers.
- Recent/common providers appear only when snapshot data supports them.
- Menu bar remains compact and does not become an all-provider report.

## Recommended Order

1. Remove duplicate quota-page Test Connection.
2. Add snapshot persistence.
3. Add trend and recent-usage ranking.
4. Add compact account-row trend cues.
5. Add menu-bar recent/common provider section.
6. Add latest-refresh delta text only if the UI still needs more clarity after trend cues.
7. Rebuild, package, and inspect the app.

This order keeps the data model testable before UI work, and keeps the menu bar aligned with the product rule: status decides priority, trend explains why, recent/common usage is secondary.
