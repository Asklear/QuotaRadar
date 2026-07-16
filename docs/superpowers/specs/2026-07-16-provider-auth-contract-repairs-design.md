# Provider Authentication Contract Repairs Design

## Scope

Repair four independent provider contracts without changing the shared dashboard reauthentication lifecycle introduced after v0.4.5. Each provider retains strict server validation before persistence.

## Aliyun Coding Plan

The observed Bailian home page is publicly renderable while logged out. Its user-info endpoint returned HTTP 200 with `ConsoleNeedLogin`, and `_bl_uid` is only visitor state. The login URL will point directly at the protected Coding Plan subscription route, while `login_aliyunid_ticket` remains required. Visitor cookies will not be accepted as authentication.

## Volcengine Coding Plan

Volcengine returns authentication errors inside HTTP 200 JSON envelopes. `InvalidCSRFToken` also rotates the token through response header `x-need-token` and `Set-Cookie: csrfToken=...`.

QuotaRadar will classify the error envelope before parsing quota data. On `InvalidCSRFToken`, it will perform exactly one provider-local retry using `x-need-token`: replace the `csrfToken` cookie in the outgoing Cookie header and set the same value as `x-csrf-token`. A second failure becomes unauthorized. The cURL-imported `x-web-id` alias will be normalized to `xWebId`, with the legacy `webID` alias still accepted during replay.

No general WebStorage enumeration or request interception is added. The existing quota-window parser remains unchanged.

## OpenCode Go

The live authenticated server function returned HTTP 200 with the exact Solid server-function null result, and the workspace page also reported no lite subscription. That means no subscription, not an invalid response.

The parser will recognize only the exact null result envelope and throw `QuotaError.noSubscription`. Auth redirects remain unauthorized, and malformed non-null envelopes remain invalid responses. Existing monitor behavior will clear stale quota and store HTTP 200/no-plan state.

## Tencent Cloud Coding Plan

Tencent returns auth failures inside HTTP 200 response envelopes. Codes 9 and 50, and normalized messages containing login-expiry or CSRF markers, will map to unauthorized. Existing `hash(skey)` CSRF construction remains unchanged. Credential readiness will accept `uin` plus either `skey` or `p_skey`, matching request construction.

Tencent receives continued low-frequency automatic capture after the initial retry window so QQ login handoff has time to replace stale console cookies. Unchanged rejected credentials remain suppressed and are never repeatedly validated.

## Safety and persistence

- No Cookie or token values are logged.
- Failed validation never replaces the stored credential.
- Provider-specific branches do not relax other providers' readiness or error classification.
- Retries are bounded for network requests; only passive WebView capture polling continues for Tencent.

## Verification

Tests cover Aliyun protected navigation, Volcengine HTTP-200 error envelopes and one retry, OpenCode null/no-plan semantics, Tencent code/message classification and `p_skey`, plus the full existing behavior suite and signed app build. Live acceptance repeats all four provider flows and compares database status without exposing credential values.
