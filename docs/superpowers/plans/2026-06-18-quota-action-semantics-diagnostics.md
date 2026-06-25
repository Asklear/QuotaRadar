# Quota Action Semantics And Diagnostics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make QuotaRadar's connection testing, quota refresh, costly checks, automatic refresh, and diagnostics use one provider capability model.

**Architecture:** Extend `ProviderCapability` into the single source of truth for observable data support and action semantics. `QuotaMonitor` should route refreshes through an explicit `QuotaActionKind`, while Settings and Diagnostics should read capability-derived action labels, warnings, and user-facing diagnostics instead of rechecking provider-specific booleans. Keep provider network parsers unchanged unless a test proves they need action-specific behavior.

**Tech Stack:** Swift 5.9, SwiftUI, local behavior tests in `Tests/run_behavior_tests.sh`, release bundle build through `install.sh`, screenshot QA through `Tests/run_visual_qa.sh`.

---

## File Structure

- Modify `QuotaRadar/Models/APIKey.swift`
  - Extend `ProviderCapability` with observable support flags: `supportsQuota`, `supportsBalance`, `supportsPlan`, `supportsActivity`, `supportsReset`.
  - Add action semantics: `connectionTestKind`, `quotaRefreshKind`, `allowsAutomaticRefresh`, and `requiresCostlyConfirmation`.
  - Keep existing credential and source fields compatible with current UI.
- Modify `QuotaRadar/Models/QuotaMonitor.swift`
  - Add `QuotaActionKind` or equivalent action model for `testConnection`, `refreshQuota`, and `costlyCheck`.
  - Route automatic refresh eligibility through `ProviderCapability` instead of direct `quotaCheckConsumesSearchQuota`.
  - Preserve current refresh persistence and quota snapshot behavior.
- Modify `QuotaRadar/Views/SettingsView.swift`
  - Make provider action labels derive from capability action semantics.
  - Make Diagnostics default to actionable status and hide HTTP/debug details behind a disclosure row.
- Modify `QuotaRadar/Models/AppLanguage.swift`
  - Add localized labels only where new action/debug copy is visible.
- Modify `Tests/run_behavior_tests.sh`
  - Add source-structure checks for the new capability fields and action model.
  - Add behavioral checks for Brave, Tavily, DeepSeek, Claude Subscription, Codex Subscription, and XFYun Coding Plan.

## Task 1: Capability Contract

**Files:**
- Modify: `QuotaRadar/Models/APIKey.swift`
- Test: `Tests/run_behavior_tests.sh`

- [ ] **Step 1: Write failing structure tests**
  - Assert `ProviderCapability` exposes `supportsQuota`, `supportsBalance`, `supportsPlan`, `supportsActivity`, `supportsReset`, `allowsAutomaticRefresh`, `requiresCostlyConfirmation`, and action-kind fields.
  - Assert representative providers expose expected capability values:
    - Brave: quota supported, reset supported when headers expose it, costly confirmation required, automatic refresh disabled by default.
    - Tavily: quota/reset/activity supported, automatic refresh allowed, no costly confirmation.
    - DeepSeek: balance/activity supported, no reset, automatic refresh allowed.
    - Claude/Codex/XFYun: quota/plan/activity/reset supported through dashboard/web-login semantics, automatic refresh allowed when check is no-cost.

- [ ] **Step 2: Run behavior tests and confirm failure**
  - Run: `bash Tests/run_behavior_tests.sh`
  - Expected: FAIL on missing capability/action fields.

- [ ] **Step 3: Extend `ProviderCapability` minimally**
  - Add the fields without changing provider UI layout.
  - Fill provider mappings in the existing `Provider.capability` switch.

- [ ] **Step 4: Run behavior tests**
  - Run: `bash Tests/run_behavior_tests.sh`
  - Expected: PASS through capability assertions; compilation must pass.

## Task 2: Action Semantics

**Files:**
- Modify: `QuotaRadar/Models/QuotaMonitor.swift`
- Modify: `QuotaRadar/Models/APIKey.swift`
- Test: `Tests/run_behavior_tests.sh`

- [ ] **Step 1: Write failing tests for refresh routing**
  - `Test Connection` must not be modeled as quota-consuming.
  - `Refresh Quota` must be allowed for no-cost providers and read real quota.
  - `Costly Check` must be required for Brave-style providers.
  - Automatic refresh eligibility must use `ProviderCapability.allowsAutomaticRefresh`, not direct `quotaCheckConsumesSearchQuota`.

- [ ] **Step 2: Implement action kind**
  - Introduce an enum such as `QuotaActionKind { testConnection, refreshQuota, costlyCheck }`.
  - Add capability helpers that return labels/warnings per action.
  - Update automatic refresh provider selection to use capability.

- [ ] **Step 3: Verify**
  - Run: `bash Tests/run_behavior_tests.sh`
  - Expected: PASS.

## Task 3: Diagnostics Information Hierarchy

**Files:**
- Modify: `QuotaRadar/Views/SettingsView.swift`
- Modify: `QuotaRadar/Models/APIKey.swift`
- Modify: `QuotaRadar/Models/AppLanguage.swift`
- Test: `Tests/run_behavior_tests.sh`

- [ ] **Step 1: Write failing diagnostics tests**
  - Diagnostics rows should keep `Health Status` and actionable message visible.
  - HTTP status / endpoint / raw debug detail should be rendered only inside a disclosure or detail section.
  - Quota-consuming warning should come from capability, not raw provider checks.

- [ ] **Step 2: Implement UI hierarchy**
  - Add a compact debug disclosure under each diagnostic row when technical metadata exists.
  - Keep default row focused on: expired credential, quota unavailable, manual costly check, proxy/connection failure, or unsupported API.

- [ ] **Step 3: Verify UI source checks**
  - Run: `bash Tests/run_behavior_tests.sh`
  - Expected: PASS.

## Task 4: Full Verification And Bundle

**Files:**
- Generated: `build/Quota Radar.app`
- Generated: `build/visual-qa/*`

- [ ] **Step 1: Run whitespace and behavior tests**
  - Run: `git diff --check`
  - Run: `bash Tests/run_behavior_tests.sh`
  - Expected: exit 0; app bundle rebuilt.

- [ ] **Step 2: Run visual QA**
  - Run: `bash Tests/run_visual_qa.sh`
  - Expected: exit 0; `build/visual-qa/summary.txt` says behavior and visual QA passed.

- [ ] **Step 3: Launch rebuilt app**
  - Run: `pkill -x QuotaRadar || true; open "build/Quota Radar.app"; sleep 3; pgrep -fl QuotaRadar`
  - Expected: process path points to `build/Quota Radar.app/Contents/MacOS/QuotaRadar`.

- [ ] **Step 4: Commit**
  - Commit capability/action work separately from any visual-only follow-up if the diff grows.
