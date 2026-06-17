# Quota Diagnostics And Connection Testing Design

Date: 2026-06-16
Status: Draft for review

## Summary

Quota Radar should make each saved credential easy to judge without forcing the user to infer state from raw quota numbers. The next feature slice should add a clear credential state label, a provider-level connection test action, and richer diagnostics that explain the latest check result, request context, reset information, and skipped refresh behavior.

The product direction remains a compact macOS monitoring panel: status decides priority, diagnostics explain why, and trend or history stay secondary.

## Problem

The current app already records useful check outputs such as `lastUpdated`, `lastHTTPStatus`, `lastDiagnosticText`, quota values, reset time, and provider-specific warning text. However, those signals are split across quota rows, credential rows, and diagnostics rows. Users can see that something is wrong, but they still need to answer follow-up questions manually:

- Is this credential configured but never checked?
- Did the provider reject it, or is quota just unavailable?
- Did automatic refresh skip it because the check consumes real quota?
- Which proxy mode was used by the last request?
- What should I do next: refresh, reauthenticate, edit the key, or leave it alone?

## Goals

- Add explicit credential state labels in the credential configuration page.
- Add a provider-level `Test Connection` action that reuses existing refresh/check infrastructure.
- Preserve costly-provider safety: Brave-style checks must require explicit confirmation before consuming a real request.
- Enrich the diagnostics page with last request time, HTTP status, provider diagnostic summary, proxy mode, auto-refresh skip state, and reset information.
- Keep UI compact and native. Add information near existing rows and action groups instead of creating a new dashboard.
- Avoid storing secrets outside the existing local secret store.

## Non-Goals

- Do not add new providers in this feature slice.
- Do not build a detailed history or trend explorer.
- Do not redesign the whole menu bar popover.
- Do not introduce remote telemetry.
- Do not export secrets.

## Current Code Context

- `QuotaRadar/Models/APIKey.swift` already owns quota, health, status, reset, and diagnostic presentation logic.
- `QuotaRadar/Models/QuotaMonitor.swift` already centralizes refresh execution and writes HTTP/diagnostic fields after each provider check.
- `QuotaRadar/Views/SettingsView.swift` already contains credential rows, provider quota rows, and diagnostics rows.
- `QuotaRadar/Models/AppAppearance.swift` owns the network proxy preference and URLSession configuration.
- `Tests/run_behavior_tests.sh` is the current behavior guard script; the repo does not currently have a Swift XCTest target.

## Design

### Credential State

Add a small presentation model that maps existing credential facts into user-facing states:

- `Not Configured`: provider has no saved credential. This is mostly used in add/configuration contexts.
- `Configured, Untested`: credential exists but has no quota, HTTP, diagnostic, or check timestamp.
- `Usable`: latest check indicates healthy quota, usable unknown quota, or unsupported quota for copy-only/business credentials.
- `Credential Expired`: dashboard/web-login authorization is expired or unauthorized.
- `Quota API Unavailable`: provider cannot expose quota for this credential, or the integration intentionally treats quota as unknown.
- `Check Consumes Quota`: provider check consumes a real request and should be manually confirmed.
- `Check Failed`: latest check failed for a non-auth reason.

This should be implemented as a computed presentation property first, not as a persisted database field. The source of truth remains the current quota/diagnostic fields.

### Connection Test

Add a provider-level action next to the existing dashboard, reauthentication, and refresh buttons.

Test modes:

- `No-Cost Ping`: local validation only. It verifies required credential material exists and, for dashboard credentials, required fields/cookies are present. It does not make a provider request.
- `Quota Check`: calls the existing quota-check path and updates quota/diagnostic fields.
- `Costly Check`: same as quota check, but only after a confirmation dialog because it consumes real quota.

Initial behavior should default to:

- Providers with `quotaCheckConsumesSearchQuota == true`: `Costly Check`.
- Providers with normal quota APIs: `Quota Check`.
- Copy-only companion API keys: no network test; inherit the linked authorization state.

### Diagnostics Page

Keep the existing provider-section layout, but expand each credential diagnostic row into a compact two-line diagnostic surface:

- Top row: credential title, credential state, HTTP status, last request/check time.
- Detail row: provider diagnostic summary, reset explanation, proxy mode, auto-refresh skip note if present.

The diagnostics page should remain scannable. Avoid large cards inside cards and avoid long prose blocks. Use small labels/pills and one wrapped diagnostic summary line.

### Credential Configuration Page

The existing credential row already has a status pill and action group. Replace the generic health text with the explicit credential state label and preserve the existing active toggle, copy, and edit buttons.

When practical, add `Test Connection` at the provider section level rather than on every credential row. This matches current provider-first quota monitoring and avoids repeating actions for companion API keys.

### Auto-Refresh Skip State

Automatic refresh already writes `quotaConsumingRefreshWarning` for quota-consuming providers when skipped. The design should make that visible as a diagnostic fact:

- Show `Skipped automatic refresh` or equivalent when the last diagnostic text is the quota-consuming warning and the provider is costly.
- Keep manual refresh/test available behind confirmation.

### Proxy Reporting

The app cannot cheaply prove the provider observed a proxy, but it can report the configured request mode used by Quota Radar:

- `System Proxy`
- `Direct`
- `Custom Proxy`

Diagnostics wording should say "Configured proxy" or "Request proxy mode", not claim the remote service saw that path.

### Error Handling

- Unauthorized dashboard credentials should keep mapping to `Credential Expired`.
- Unsupported quota checks should map to `Quota API Unavailable`, not `Check Failed`.
- Network/parser errors should map to `Check Failed` with the existing diagnostic summary.
- Costly provider confirmation cancel should not modify `lastUpdated` or quota fields.
- No-cost local validation should not overwrite a successful quota result unless it finds a clear local configuration problem.

### Testing

Use the existing behavior script first:

- Assert the new state model and labels exist.
- Assert diagnostics rows render state, HTTP, last checked, proxy mode, reset info, and skip state.
- Assert costly-provider connection tests show a confirmation path before calling refresh.
- Assert no test fixture or docs introduce real secrets.

Manual QA should include:

- Credential never checked.
- Healthy quota.
- Credential expired.
- Quota unavailable/unknown.
- Brave costly check confirmation.
- Proxy modes: system, direct, custom.
- Simplified Chinese and English UI strings at minimum.

## Rollout Plan

1. Add state and diagnostic presentation model.
2. Enrich diagnostics page using existing persisted fields.
3. Add credential page state labels.
4. Add provider-level test action and costly-check confirmation.
5. Add behavior guards and manual QA screenshots if UI changes are visible.
6. Update TODO once behavior is verified.

## Open Questions

- Should `No-Cost Ping` be visible in the first version, or should it remain internal local validation under the `Test Connection` action?
- Should threshold notifications be in this slice or in a follow-up slice after diagnostics are clearer?
- Should provider test results distinguish `lastCheckedAt` and `lastNetworkRequestAt`, or is the existing `lastUpdated` sufficient for now?
