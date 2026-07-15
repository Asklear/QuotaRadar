# Dashboard Reauthentication Recapture Design

## Problem

All providers that use `DashboardReauthSheet` share one automatic credential capture lifecycle. The coordinator marks the first structurally complete credential as emitted before provider validation finishes. If that credential is stale, validation resets the sheet's auto-save flag but does not re-arm the coordinator. Manual save can also reuse the cached credential instead of reading the current WebView. Storage-backed login material can arrive after the finite initial retry window.

## Scope

The fix applies to all providers where `supportsDashboardReauthentication` is true: Querit, XFYun Coding Plan, Volcengine Coding Plan, OpenCode Go, Aliyun Coding Plan, Tencent Cloud Coding Plan, Claude Subscription, Anthropic Credits, Codex Subscription, Kimi Subscription, and LongCat.

Provider quota parsers and authentication cookie requirements remain unchanged.

## Design

`DashboardReauthSheet` owns a monotonically increasing automatic-capture reset request ID. Any provider-validation failure increments it after the in-flight validation ends. `DashboardWebView.Coordinator` consumes each reset request once, clears its emitted state, and immediately attempts a fresh capture.

Manual save never submits `latestCapturedCredential`. It always increments the existing manual-capture request ID, causing the coordinator to capture the current WebView cookie and storage state. Automatic and manual callbacks enter one testable validation lifecycle; while one validation is in flight, neither callback can start another.

The capture lifecycle is represented by a small pure value type in `DashboardReauth.swift`, so re-arm and duplicate-suppression behavior can be tested without constructing a `WKWebView`. Kimi and LongCat receive bounded-frequency continued automatic polling after the initial retry sequence because their login material may be written only to WebStorage without a cookie-change callback.

No credential values are logged. Existing diagnostics remain limited to localized captured/missing field names and validation results.

## Persistence and failure behavior

Credentials are persisted only when the validation lifecycle returns a successful persistence disposition. Unauthorized, schema, and transport failures return a recapture disposition, leave the stored credential untouched, clear the in-flight state, display the validation error, and request a fresh capture. A manual capture with no usable material reports the existing missing-credential message.

Opening or retrying the sheet must not clear, replace, or delete WebKit cookies or website data. The existing logged-in browser state is an input to fresh capture and must be preserved.

## Verification

Behavior tests must prove:

- one automatic credential is emitted at a time;
- validation failure re-arms capture and permits a second credential;
- duplicate reset request IDs do not cause duplicate capture;
- automatic and manual submissions share one in-flight validation gate;
- validation success permits persistence, while unauthorized, schema, and transport failures do not;
- a manual save with stale cached state waits for and submits the newer WebView callback credential;
- source inspection confirms that manual save does not persist `latestCapturedCredential` and that no cookie/website-data clearing call is introduced;
- all eleven providers are present in the first-save matrix;
- Kimi and LongCat continue delayed storage-only capture, while cookie-only providers retain finite retries;
- the full behavior suite and macOS build succeed.
