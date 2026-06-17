# QuotaRadar Monitoring Model Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework QuotaRadar into an iStat/Stats-style monitoring utility: correct provider quota semantics, replace ambiguous trend lines with activity signals, connect menu bar triage to the main app, and consolidate English-first documentation.

**Architecture:** Build one provider signal model from existing API key metadata and quota snapshots. UI surfaces consume that model differently: menu bar shows the smallest actionable signal, the popover triages reasons, and the main app explains current quota, activity, timing, status, and actions. Documentation is reorganized after behavior stabilizes.

**Tech Stack:** Swift 5.9, SwiftUI, local JSON quota history, existing behavior tests in `Tests/run_behavior_tests.sh`, macOS menu bar app bundle via `install.sh`.

---

## File Structure

- Modify `QuotaRadar/Services/QuotaService.swift`
  - Correct parser semantics for providers where used/remaining fields differ.
  - Start with XFYun because current tests and UI prove `usage` fields are displayed as remaining.
- Modify `QuotaRadar/Models/QuotaHistory.swift`
  - Add activity-oriented summaries derived from snapshots.
  - Preserve existing snapshot storage; do not store secrets.
- Modify `QuotaRadar/Models/APIKey.swift`
  - Add provider-family presentation helpers for current/activity/timing.
  - Avoid persisted UI-only fields.
- Modify `QuotaRadar/Models/QuotaMonitor.swift`
  - Expose provider signal summaries and menu signal reasons.
  - Add selected/target provider state if needed for popover-to-main-app navigation.
- Modify `QuotaRadar/Views/SettingsView.swift`
  - Replace sparkline trend column with activity/current/time/status layout.
  - Make expanded account rows consume available width instead of using a left-anchored fixed table.
- Modify `QuotaRadar/Views/MenuContentView.swift`
  - Rework popover sections around Needs Attention, Active Usage, and Recently Updated.
  - Add row actions for opening and focusing a provider in the main app.
- Modify `QuotaRadar/Models/AppLanguage.swift`
  - Rename user-visible `Trend` concepts to `Activity` where appropriate.
  - Add strings for menu signal reasons and provider activity summaries.
- Modify `Tests/run_behavior_tests.sh`
  - Add parser assertions, model assertions, and structural UI assertions before implementation.
- Modify docs:
  - `README.md`, `README.en.md`, `README.zh-Hans.md`
  - `QUICKSTART*.md`, `TODO*.md`
  - `docs/provider-capabilities*.md`
  - new `docs/providers*.md` and `docs/roadmap*.md` as needed.

## Task 1: Correct XFYun Quota Semantics

**Files:**
- Modify: `Tests/run_behavior_tests.sh`
- Modify: `QuotaRadar/Services/QuotaService.swift`

- [x] **Step 1: Write failing parser expectations**

Update the XFYun parser test so `rp5hUsage`, `rpwUsage`, and `packageUsage` are treated as used counts:

```swift
require(xfyun.remaining == 7934, "XFYun should use the tightest remaining coding-plan window")
require(xfyun.quotaLabel == "5h 99% · week 79.3% · month 89.7%", "XFYun should display remaining percentages")
require(xfyun.quotaText?.quotaWindows.first(where: { $0.name == "5h" })?.remainingText == "5940 / 6000", "XFYun should preserve five-hour remaining and maximum request counts")
require(xfyun.quotaText?.quotaWindows.first(where: { $0.name == "week" })?.remainingText == "35704 / 45000", "XFYun should preserve weekly remaining and maximum request counts")
require(xfyun.quotaText?.quotaWindows.first(where: { $0.name == "month" })?.remainingText == "80704 / 90000", "XFYun should preserve monthly remaining and maximum request counts")
```

- [x] **Step 2: Run behavior tests and confirm failure**

Run:

```bash
bash Tests/run_behavior_tests.sh
```

Expected: FAIL on XFYun remaining/label/window assertions.

- [x] **Step 3: Implement minimal parser fix**

In `parseXFYunCodingPlanList`, compute:

```swift
let fiveHourRemaining = limit - usage.rp5hUsage
let weekRemaining = limit - usage.rpwUsage
let monthRemaining = usage.packageLeft ?? (limit - usage.packageUsage)
```

Clamp each value into `0...limit`.

- [x] **Step 4: Verify**

Run:

```bash
bash Tests/run_behavior_tests.sh
git diff --check
```

Expected: PASS.

## Task 2: Audit Other Provider Parser Semantics

**Files:**
- Modify: `Tests/run_behavior_tests.sh`
- Modify: `QuotaRadar/Services/QuotaService.swift`

- [ ] **Step 1: Add semantic guard comments/tests**

Add behavior assertions for windowed providers:

- Volcengine `Percent` is used percent, so remaining percent must be `100 - Percent`.
- Aliyun/Tencent `Used` plus `Total` should produce remaining `Total - Used`.
- Claude/Codex/Kimi percentage endpoints should continue producing remaining percentage.
- Money-balance providers should continue storing cents as remaining balance.

- [ ] **Step 2: Run tests**

Run `bash Tests/run_behavior_tests.sh`.

- [ ] **Step 3: Fix only parsers that fail the semantic guard**

Do not redesign UI in this task.

## Task 3: Add Activity Signal Model

**Files:**
- Modify: `QuotaRadar/Models/QuotaHistory.swift`
- Modify: `QuotaRadar/Models/APIKey.swift`
- Modify: `QuotaRadar/Models/QuotaMonitor.swift`
- Test: `Tests/run_behavior_tests.sh`

- [x] **Step 1: Add failing structural assertions**

Require:

- `struct QuotaActivitySummary`
- `enum QuotaActivityKind`
- `struct MenuSignalReason`
- activity summaries for windowed quota, money balance, fixed credits, and unknown quota.

- [x] **Step 2: Implement model**

The activity model should include:

```swift
struct QuotaActivitySummary: Equatable {
    var kind: QuotaActivityKind
    var periodName: String?
    var currentText: String?
    var activityText: String?
    var deltaText: String?
    var usedFraction: Double?
    var shouldRender: Bool
}
```

Rules:

- Use longest stable window for activity when a provider exposes multiple windows.
- Use snapshot deltas for recent consumption.
- Treat reset/recovery as a separate state, not consumption.
- Return `shouldRender == false` for unknown, unchanged, or insufficient history.

## Task 4: Replace Trend Column With Activity Lane

**Files:**
- Modify: `QuotaRadar/Views/SettingsView.swift`
- Modify: `QuotaRadar/Models/AppLanguage.swift`
- Test: `Tests/run_behavior_tests.sh`

- [x] **Step 1: Add failing UI assertions**

Require `ProviderQuotaActivityColumn` and reject `QuotaTrendSparkline` usage in quota overview rows.

- [x] **Step 2: Implement inline activity meter**

Render:

- period label
- optional thin used/spent meter
- compact activity/delta text

No cards, no sparkline placeholders.

- [x] **Step 3: Make account rows responsive**

Replace fixed left-anchored account table width with a shared geometry/grid calculation using available width.

## Task 5: Add Menu Bar To Main App Linkage

**Files:**
- Modify: `QuotaRadar/Models/QuotaMonitor.swift`
- Modify: `QuotaRadar/Views/MenuContentView.swift`
- Modify: `QuotaRadar/Views/SettingsView.swift`
- Test: `Tests/run_behavior_tests.sh`

- [x] **Step 1: Add menu signal reason model assertions**

Require popover rows to carry a reason: low quota, recent activity, stale, expiring, failed, or credential issue.

- [x] **Step 2: Rework popover sections**

Sections:

- Needs Attention
- Active Usage
- Recently Updated

- [x] **Step 3: Implement row action**

Clicking a menu row opens the main window, selects Quota Overview, scrolls to the provider, and expands the provider.

- [x] **Step 4: Add main-row explanation**

Show weak text such as `Shown because 5h quota is low` when a provider is currently represented in the menu bar.

## Task 6: Consolidate Documentation

**Files:**
- Modify: `README.md`
- Create/Modify: `README.zh-Hans.md`
- Modify/Delete or fold: `README.en.md`, `QUICKSTART.md`, `QUICKSTART.en.md`, `TODO.md`, `TODO.en.md`
- Create/Modify: `docs/providers.md`, `docs/providers.zh-Hans.md`, `docs/roadmap.md`, `docs/roadmap.zh-Hans.md`
- Modify: `.gitignore` if needed for `.superpowers/` and temporary screenshots.

- [x] **Step 1: Add documentation structure tests**

Use `Tests/run_behavior_tests.sh` or a small shell section to assert English README screenshot paths and docs links.

- [x] **Step 2: Rewrite root README**

Keep it concise and English-first:

- summary
- screenshots
- quick start
- supported provider summary
- build/install
- docs links

- [x] **Step 3: Move detailed docs**

Provider matrix into `docs/providers*.md`; roadmap into `docs/roadmap*.md`.

## Task 7: Full Verification And Visual QA

**Files:**
- Generated screenshots under `docs/assets/screenshots/en/` and `docs/assets/screenshots/zh-Hans/`

- [ ] **Step 1: Run automated verification**

```bash
bash Tests/run_behavior_tests.sh
git diff --check
./install.sh --rebuild
```

- [ ] **Step 2: Launch and capture screenshots**

Capture:

- main quota overview
- expanded provider account rows
- menu bar popover

- [ ] **Step 3: Manual acceptance checklist**

Verify:

- XFYun remaining values match official semantics.
- Activity lane does not render misleading upward trends.
- Money-balance providers show balance activity.
- Unknown/unlimited providers avoid fake activity.
- Menu row opens and focuses the corresponding provider.
- README defaults to English and English screenshots.
