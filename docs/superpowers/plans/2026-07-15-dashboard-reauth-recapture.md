# Dashboard Reauthentication Recapture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure every dashboard-authenticated provider can replace stale browser credentials after validation failure and refresh subscription data.

**Architecture:** Add a pure capture lifecycle shared by the WebView coordinator, signal validation failures through a reset request ID, and make manual save always capture current browser state. Keep provider-specific credential parsing unchanged; only storage-backed providers receive continued low-frequency polling.

**Tech Stack:** SwiftUI, WebKit, Swift value types, shell-driven Swift behavior tests, Xcode.

---

### Task 1: Capture lifecycle regression tests

**Files:**
- Modify: `Tests/run_behavior_tests.sh`
- Test: `Tests/run_behavior_tests.sh`

- [ ] Add a Swift behavior test that emits candidate one, rejects duplicate emission, consumes a new reset request, and emits candidate two.
- [ ] Add assertions that duplicate reset IDs do not re-arm the lifecycle.
- [ ] Add a validation-lifecycle test proving automatic and manual submissions cannot overlap.
- [ ] Add validation-completion tests proving success permits persistence and unauthorized/schema/transport failure requests recapture without persistence.
- [ ] Add a manual-capture sequence test with stale cached credential A and fresh callback credential B, proving only B reaches validation and persistence.
- [ ] Add retry-policy assertions proving Kimi and LongCat continue polling after their initial delays while Codex stops.
- [ ] Extend the explicit first-save matrix with Anthropic Credits, Aliyun Coding Plan, and Tencent Cloud Coding Plan.
- [ ] Add structural assertions that manual save always increments `manualCaptureRequestID` and never persists `latestCapturedCredential` directly.
- [ ] Add source assertions that the reauthentication flow does not call WebKit cookie or website-data removal APIs.
- [ ] Run `bash Tests/run_behavior_tests.sh` and confirm the new assertions fail for the missing lifecycle behavior.

### Task 2: Shared re-arm and fresh manual capture

**Files:**
- Modify: `QuotaRadar/Services/DashboardReauth.swift`
- Modify: `QuotaRadar/Views/DashboardReauthView.swift`
- Test: `Tests/run_behavior_tests.sh`

- [ ] Implement `DashboardCredentialCaptureLifecycle` with one-shot emission and reset-request consumption, plus a shared validation lifecycle that returns persist or recapture dispositions.
- [ ] Add `automaticCaptureResetRequestID` to the sheet/WebView boundary and consume it in the coordinator.
- [ ] Route automatic/manual callbacks through the shared validation gate and increment the reset request after every validation failure, including LongCat's custom validation path.
- [ ] Remove the cached-credential shortcut from manual save.
- [ ] Keep persistence behind the successful validation disposition and preserve the WebKit data store unchanged.
- [ ] Add a retry-policy helper that continues low-frequency capture for Kimi and LongCat only.
- [ ] Run `bash Tests/run_behavior_tests.sh` and confirm the regression tests and full behavior suite pass.

### Task 3: Build and review

**Files:**
- Review: `QuotaRadar/Services/DashboardReauth.swift`
- Review: `QuotaRadar/Views/DashboardReauthView.swift`
- Review: `Tests/run_behavior_tests.sh`

- [ ] Run the repository's macOS build verification command and confirm exit status 0.
- [ ] Inspect `git diff --check` and the complete diff for credential-value exposure or provider-specific duplication.
- [ ] Request code review against commit `6e17c18` and resolve all critical or important findings.
- [ ] Re-run the behavior suite and build after review changes.
- [ ] Report exact verification evidence and any remaining live-browser acceptance limitation.
