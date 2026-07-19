# Brave 429 Quota Exhaustion Design

## Goal

When Brave Search returns HTTP 429 with rate-limit headers proving that the longest quota window has zero remaining requests, QuotaRadar must replace stale quota metadata with the observed exhausted state and reset time. A valid but exhausted key must not continue to display its last successful remaining count.

## Scope

This change is limited to Brave response parsing, presentation metadata, and regression coverage. It does not change credential storage, proxy configuration, automatic-refresh scheduling, or another provider's failure handling.

## Behavior

Brave exposes parallel rate-limit buckets through comma-separated `x-ratelimit-limit`, `x-ratelimit-remaining`, `x-ratelimit-reset`, and `x-ratelimit-policy` headers. HTTP 429 handling must use stricter evidence than the existing successful-response fallback: `limit`, `remaining`, and `policy` must be non-empty arrays with equal counts, and every limit and remaining value must be non-negative. Every policy item must have the exact form `<positive quota>;w=<positive duration>`, and its quota must equal the limit at the same index. The greatest policy duration must identify one unique longest quota window. Header order may vary only when each policy, limit, remaining, and reset bucket is reordered together. A missing, malformed, mismatched, or ambiguously tied array cannot prove long-window exhaustion.

- If the longest window has a positive limit and zero remaining, return a structured `QuotaResult` with `remaining = 0`, the observed long-window limit, `httpStatus = 429`, `quotaText = .monthlyRequestsFormat("0", limit)`, and a new localized `braveQuotaExhaustedDiagnostic`. The raw fallback label is `0 / <limit> monthly requests`. The selected reset value is interpreted as non-negative seconds from an injected response `now`; an absent, misaligned, non-numeric, or negative reset yields `resetAt = nil` without weakening the exhaustion evidence from the other three aligned arrays.
- This structured result follows the normal success-persistence path: the key becomes exhausted, `consecutiveFailureCount` resets to zero, `lastUpdated` advances, and quota history records a successful observed sample with HTTP 429. It must not reuse the `Search works` label or the HTTP 402-specific Brave diagnostic.
- If the longest window still has remaining quota, keep throwing `QuotaError.rateLimited`. When aligned reset values are available, its reset is the earliest reset among zero-remaining shorter windows, calculated from the same injected `now`. Otherwise its reset is nil. QuotaMonitor preserves the last successful quota because this is a transient rate limit.
- If the 429 limit, remaining, or policy headers are missing, malformed, negative, or count-mismatched, throw `QuotaError.rateLimited(resetAt: nil)`. Do not fall back to the last bucket or infer a long-window reset.
- Existing 401/403, 402, 422, and 2xx behavior remains unchanged.

## Testing

Add parser regression cases for:

1. HTTP 429 with `1, 2000` limits and `0, 0` remaining returns `0 / 2000`, HTTP 429, the dedicated localized diagnostic, and the long-window reset relative to a fixed `now`.
2. Applying that result produces an exhausted key, clears the failure count, advances `lastUpdated`, and records a successful quota sample.
3. HTTP 429 with the short bucket at zero and the long bucket above zero throws `QuotaError.rateLimited` with the short-window reset relative to the same fixed `now`.
4. Fully aligned unordered policy/limit/remaining/reset buckets still select the unique greatest window rather than the last bucket.
5. Missing, malformed, negative, count-mismatched, policy-quota-mismatched, policy-only-reordered, and tied-longest limit/remaining/policy headers throw `rateLimited(resetAt: nil)`; a missing, malformed, negative, or mismatched reset on otherwise proven exhaustion returns an exhausted result with `resetAt = nil`.
6. Explicit 401, 403, 402, 422, and 2xx assertions prove those branches and their diagnostics remain unchanged.

Run the full behavior suite and release build after the focused parser assertions pass.
