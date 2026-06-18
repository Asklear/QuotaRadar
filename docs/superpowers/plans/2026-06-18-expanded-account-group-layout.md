# Expanded Account Group Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the provider expanded quota table details with a compact account-group layout that avoids empty last-updated columns.

**Architecture:** Keep the provider overview table unchanged. Replace nested account/window rows with an account group component: left account identity, middle quota-window list, right account metadata containing plan expiry and last updated once.

**Tech Stack:** SwiftUI, existing `SettingsView.swift` quota monitor components, `Tests/run_behavior_tests.sh`, existing visual QA scripts.

---

### Task 1: Source-Level Guardrails

**Files:**
- Modify: `Tests/run_behavior_tests.sh`

- [ ] Add checks that expanded account details render through `ProviderQuotaAccountGroup`.
- [ ] Add checks that quota window rows are not rendered through a four-column row with an empty updated lane.
- [ ] Add checks that account metadata is grouped once through a compact meta panel.
- [ ] Run `bash Tests/run_behavior_tests.sh` and confirm the new check fails before implementation.

### Task 2: SwiftUI Layout

**Files:**
- Modify: `QuotaRadar/Views/SettingsView.swift`

- [ ] Replace per-key `ProviderQuotaKeyTableRow` plus separate `ProviderQuotaAccountWindowDetails` rendering with `ProviderQuotaAccountGroup`.
- [ ] Preserve table header and provider summary rows for the top-level overview.
- [ ] Render account identity, quota window rows, and account meta in one compact background.
- [ ] Keep no-window providers readable by showing the account remaining value in the quota-window area.

### Task 3: Verification

**Files:**
- Use: `Tests/run_behavior_tests.sh`
- Use: `Tests/run_visual_qa.sh`

- [ ] Run `bash Tests/run_behavior_tests.sh`.
- [ ] Run `git diff --check`.
- [ ] Run `bash Tests/run_visual_qa.sh`.
- [ ] Rebuild and launch `build/Quota Radar.app`.
- [ ] Inspect focused main screenshots for expanded account groups.
- [ ] Commit the implementation.
