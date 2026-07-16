# Provider Authentication Contract Repairs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Correct Aliyun, Volcengine, OpenCode Go, and Tencent Cloud authentication/response contracts without changing shared reauthentication behavior.

**Architecture:** Keep each change inside its provider URL, credential aliases, parser, request builder, or retry policy branch. Reuse the existing validation-before-persistence lifecycle and add provider-shaped regression fixtures before production edits.

**Tech Stack:** Swift, Foundation URLSession, SwiftUI/WebKit capture policy, shell-driven Swift behavior tests.

---

### Task 1: Provider contract red tests

**Files:**
- Modify: `Tests/run_behavior_tests.sh`

- [ ] Assert Aliyun Coding Plan opens the protected subscription route and still requires the login ticket.
- [ ] Add a concrete Aliyun visitor-state negative case: `_bl_uid` alone is not ready and cannot be persisted.
- [ ] Add OpenCode fixtures for exact null/no-subscription, auth redirect, and malformed non-null response.
- [ ] Add Tencent fixtures for code 9, code 50, login/CSRF messages, and `uin + p_skey` readiness.
- [ ] Add a Tencent retry-policy test proving passive capture continues after the initial window, unchanged rejected material stays suppressed, and unrelated providers retain finite retry behavior.
- [ ] Add Volcengine fixtures for `InvalidCSRFToken`, `x-need-token` extraction, legacy/new web-ID aliases, and bounded retry behavior.
- [ ] Add provider-shaped lifecycle assertions that Aliyun visitor state, repeated Volcengine CSRF failure, and Tencent unauthorized envelopes never permit persistence or replace an existing credential.
- [ ] Run `bash Tests/run_behavior_tests.sh` and verify the new contract assertions fail for the intended missing behavior.

### Task 2: Parser and configuration fixes

**Files:**
- Modify: `QuotaRadar/Models/APIKey.swift`
- Modify: `QuotaRadar/Services/CurlCredentialParser.swift`
- Modify: `QuotaRadar/Services/QuotaService.swift`
- Modify: `QuotaRadar/Services/DashboardReauth.swift`
- Test: `Tests/run_behavior_tests.sh`

- [ ] Change only Aliyun Coding Plan's dashboard URL to the protected Coding Plan route.
- [ ] Map the exact OpenCode null envelope to `QuotaError.noSubscription`.
- [ ] Expand Tencent unauthorized classification and readiness to `skey|p_skey`.
- [ ] Add Tencent only to the existing low-frequency continued automatic capture policy; do not change duplicate-credential suppression.
- [ ] Normalize Volcengine `x-web-id` import and replay aliases.
- [ ] Add a pure Volcengine response classifier/token replacement helper.
- [ ] Run focused behavior tests until all parser/configuration cases pass.

### Task 3: Volcengine bounded CSRF retry

**Files:**
- Modify: `QuotaRadar/Services/QuotaService.swift`
- Test: `Tests/run_behavior_tests.sh`

- [ ] On the first HTTP-200 `InvalidCSRFToken`, read `x-need-token` without logging it.
- [ ] Replace only the outgoing `csrfToken` Cookie and `x-csrf-token` header, then retry once.
- [ ] Map missing-token or repeated CSRF failure to unauthorized.
- [ ] Preserve all successful quota and lifecycle parser behavior.
- [ ] Run the complete behavior suite.

### Task 4: Build, review, and live acceptance

**Files:**
- Review: `QuotaRadar/Models/APIKey.swift`
- Review: `QuotaRadar/Services/CurlCredentialParser.swift`
- Review: `QuotaRadar/Services/DashboardReauth.swift`
- Review: `QuotaRadar/Services/QuotaService.swift`
- Review: `Tests/run_behavior_tests.sh`

- [ ] Run `git diff --check`.
- [ ] Scan the diff and runtime diagnostics to confirm Cookie, token, `x-need-token`, and CSRF values are never logged or rendered.
- [ ] Run `bash Tests/run_behavior_tests.sh`, including SwiftPM release build and signing verification.
- [ ] Request independent code review and resolve Critical/Important findings.
- [ ] Re-run Aliyun, Volcengine, OpenCode, and Tencent authentication pages with current login state.
- [ ] Capture sanitized before/after metadata for each provider: HTTP, plan, quota, diagnostic, and update time, never credential values.
- [ ] Confirm failed validation retains the previous stored credential and OpenCode null stores HTTP 200/no-subscription while clearing stale quota.
