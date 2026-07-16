# AnySearch Daily Quota Design

## Problem

QuotaRadar currently treats AnySearch as locally unlimited and stores only `ANYSEARCH_API_KEY`. That behavior conflicts with AnySearch's current free plan of 1,000 requests per UTC day. The public search API accepts the saved API key but does not expose proactive usage in successful responses or through a public API-key usage endpoint.

The logged-in AnySearch console exposes authenticated usage through `GET https://anysearch.com/api/api/user/usage/summary`. Without explicit `from` and `to` query parameters, the endpoint defaults to a rolling range rather than today's quota period. Console authentication is stored in localStorage under `search-template-auth-state`. The observed JSON root has `state` and `version`; `state.accessToken` and `state.refreshToken` are strings, while `state.expiresAt` is an integer Unix timestamp in milliseconds.

## Scope

This change updates only AnySearch provider capture, storage, request construction, parsing, migration, presentation, documentation, and tests. Other providers' capture requirements, request construction, and parsers must remain unchanged.

The existing AnySearch API key remains a copyable invocation credential. QuotaRadar adds a separate dashboard authorization record for quota monitoring. No remote push or release publication is part of this work.

## Credential model

AnySearch adopts the existing dashboard-authorization plus companion-API-key model used by providers such as Querit:

- `ANYSEARCH_SESSION` is the primary quota-monitoring authorization record.
- `ANYSEARCH_API_KEY` remains a separate copyable API-key record.
- The API-key record may link to its authorization through `linkedAuthorizationID`.
- Dashboard authorization is never copyable or shown as raw text.
- Deleting either record does not implicitly delete the other.
- Repeated capture or migration must not create duplicate records.
- Deleting an authorization clears any companion API key's `linkedAuthorizationID` before removing the authorization. A later capture reclaims that unlinked API key instead of creating a duplicate.

Existing API-key-only users keep their record unchanged. After upgrading, quota monitoring remains unavailable until the user saves the already logged-in AnySearch console authorization once. Saving authorization links an existing unlinked AnySearch API-key record where possible. Adding the API key later links it to the existing authorization.

## Authorization capture

AnySearch dashboard reauthentication opens `https://anysearch.com/console/overview`. The WebView capture reads and parses the `search-template-auth-state` localStorage value and extracts only the normalized fields needed for requests:

- access token;
- refresh token, retained for forward compatibility but not used in this iteration;
- access-token expiry, normalized from the observed Unix-millisecond integer.

The serialized authorization uses the existing protected dashboard-credential storage path. Raw tokens, API keys, cookies, and user identity values must not be logged, placed in diagnostics, or exposed through copy actions.

Capture is considered structurally complete only when an access token is present. A refresh token and expiry are retained when available. The provider uses its own Web Storage capture configuration so no other provider's cookie or storage requirements change.

## Usage request and parsing

Quota refresh requests:

`GET https://anysearch.com/api/api/user/usage/summary?from=<utc-day-start>&to=<now>`

The request sends the saved access token as a Bearer authorization header. Both query values are percent-encoded ISO-8601 UTC strings with millisecond precision, matching the observed console wire format. For example, `from=2026-07-16T00%3A00%3A00.000Z`; `to` uses the current instant in the same `.SSSZ` form. `from` is the current UTC day's `00:00:00.000Z`. Explicit bounds are mandatory because an unbounded request returns a non-daily range. Fixtures and request-construction tests assert the exact decoded timestamps and encoded URL form.

The parser reads `data.total_requests` as today's used count and validates the response envelope and numeric value. The free-plan limit is the provider-specific constant 1,000 requests per UTC day:

- `used = total_requests`, which must be a non-negative integer or the response is rejected as invalid;
- `limit = 1000`;
- `remaining = max(0, limit - used)`;
- `resetAt = next UTC midnight`.

Every successful result also carries a structured, localized daily-usage descriptor with the observed `used`, computed `remaining`, and `limit`, rendered as the equivalent of `356 used · 644 remaining / 1,000 daily`. This descriptor is persisted in `APIKey.quotaText` and the raw fallback in `quotaLabel`, so the exact observed used count survives restart. AnySearch's primary quota text uses this descriptor even when `remaining == 0`; exhausted status and badge logic still use the numeric remaining value.

Usage above 1,000 therefore remains visible as exact evidence, for example `1,200 used · 0 remaining / 1,000 daily`, while remaining is clamped to zero. The UI must no longer use the unlimited sentinel, infinity badge, or "Unlimited free usage" label for AnySearch.

## API-key account verification boundary

The live investigation used `GET https://anysearch.com/api/api/user/keys` to confirm that the logged-in console account owns the API key already saved in QuotaRadar. That was acceptance evidence only. This iteration does not call the keys endpoint from the application and does not add runtime key/account mismatch diagnostics. Keeping account verification outside the quota request avoids passing companion secrets into `QuotaService` and keeps the change focused on daily usage.

The cumulative `quota_used` value returned by the keys endpoint must not be interpreted as today's usage. The daily used count comes only from the explicitly bounded usage-summary request.

## Expiry and failure behavior

The AnySearch refresh-token HTTP contract has not been observed and is deliberately out of scope. QuotaRadar stores the captured refresh token for forward compatibility but does not send it. If `state.expiresAt` is already past or the usage request returns 401 or 403, QuotaRadar marks the authorization expired and asks the user to save dashboard authorization again. It must not guess a refresh URL or mutate the stored secret from `QuotaService`.

Failure behavior is remaining-data-safe:

- An expired timestamp or HTTP 401/403 marks the dashboard authorization expired and requests reauthentication.
- Missing or malformed response fields produce an invalid-response diagnostic.
- Transport and server failures leave `remaining`, `limit`, `resetAt`, and the last-successful `lastUpdated` value unchanged. Only failure diagnostics and failure counters may change.
- An API-key-only record reports that dashboard authorization is required instead of claiming unlimited quota.

## UI behavior

The AnySearch credential editor presents dashboard reauthentication and optional companion API-key storage. Existing API-key-only records remain manageable and copyable. Authorization records use the standard "quota monitoring authorization" identity and never expose a credential value.

The provider capability and presentation data source are both dashboard API, replacing the previous local-policy classification and trust calibration.

After a successful save, QuotaRadar immediately refreshes AnySearch and displays the daily remaining-first quota together with the last successful update time. The dashboard link points to `https://anysearch.com/console/overview`.

## Verification

Behavior and parser tests must cover:

- parsing valid daily usage and the response envelope;
- missing, malformed, negative, equal-to-limit, and above-limit usage values;
- exact observed used count in the localized primary text, including an above-limit fixture such as 1,200 / 1,000;
- UTC day-start and next-midnight calculation, including the Asia/Shanghai 08:00 boundary;
- mandatory `from` and `to` query parameters;
- 200, 401, 403, server-error, and transport-error behavior;
- expired-token and 401/403 reauthentication behavior without an invented refresh request;
- preservation and linking of existing `ANYSEARCH_API_KEY` records;
- delete-authorization, clear-link, recapture, relink, and duplicate-free repeated migration/capture behavior;
- API-key copy behavior and non-copyable authorization behavior;
- persistence and restart restoration of the exact used/remaining/limit descriptor;
- removal of AnySearch unlimited presentation and stale `.ai` dashboard URL;
- isolation from all other provider capture configuration, requests, and parsers.
- transport and server failures preserving `remaining`, `limit`, `resetAt`, and last-successful `lastUpdated` exactly.

Live acceptance uses the current logged-in AnySearch console state:

1. Save dashboard authorization while already logged in.
2. Confirm an immediate successful refresh shows the console's current UTC-day usage, a 1,000 limit, and the computed remainder.
3. Execute one real AnySearch search request, refresh again, and confirm used increases while remaining decreases.
4. Restart QuotaRadar and confirm the API key, authorization, quota, and last-success timestamp are restored.
5. Run the full behavior suite, macOS build, and release QA guards without pushing the branch.
