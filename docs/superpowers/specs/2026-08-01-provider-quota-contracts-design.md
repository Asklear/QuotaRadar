# Provider Quota Contract Repair Design

Date: 2026-08-01
Status: Approved in conversation; pending written-spec review

## Objective

Repair four provider contract and presentation problems without changing unrelated providers:

1. AnySearch authentication saved from the logged-in `www.anysearch.com` console must validate and immediately refresh the daily quota.
2. SerpAPI must use the account's official renewal date instead of inventing a next-month boundary.
3. Every provider with verified exhausted quota, package, credit, or monitored balance must use one shared Key Quota message.
4. LongCat Token Pack must expose the package expiry returned by the current billing API.

The change will be developed from `origin/main` in the isolated `fix/provider-quota-contracts` worktree. The dirty `qa/windows-web-auth-deferred-navigation` worktree is out of scope.

## Verified Current Contracts

### AnySearch

The live console is now served from `https://www.anysearch.com/console/overview`. Its current public frontend bundle confirms:

- persisted storage key: `search-template-auth-state`;
- refresh path: `/ssuser/auth/refresh` under the site's `/api` request base;
- quota overview path: `/api/user/billing/overview` under the site's `/api` request base;
- overview fields: `tier_code`, `tier_name`, `remaining`, `used`, `total`, `reset_period`, and optional `next_reset_at`.

The existing app still calls the legacy usage-summary contract and constructs requests against the apex origin. Because browser storage is origin-scoped, a session captured on `www.anysearch.com` cannot be assumed to exist on `anysearch.com`.

### SerpAPI

The live official `account.json` response reports a Free Plan with `250 / 250` searches used, zero remaining, and `plan_renewal_date = 2026-08-10`. The current parser ignores the renewal date and sets `resetAt` to the first day of the next UTC month.

### Provider-wide exhaustion presentation

Provider-specific parser results currently reach the shared UI with different exhausted descriptors such as `Exhausted`, `Usage limit exceeded`, numeric zero labels, balance/credit labels, and reset-appended primary text. This makes the Key Quota column inconsistent even though the business state is the same. Brave HTTP 402 and verified long-window HTTP 429 must retain their distinct HTTP and diagnostic evidence, and balance, credit, request-count, token-count, and percentage-window providers must retain their original detail units.

### LongCat

The live Token Pack endpoint returned HTTP 200 with:

- remaining: `14,494,119`;
- total: `50,000,000`;
- `expireTime = "2026-08-08 12:07:16"`;
- `remainSeconds = 586503` at observation time.

The browser displayed `有效期至 2026-08-08`. The parser already searches for `expireTime`, but its generic date parser does not accept the provider's timezone-less `yyyy-MM-dd HH:mm:ss` format, so `planEndsAt` remains empty.

## Invariants

- Authentication success means the saved credential can call the provider's real quota endpoint; a logged-in page alone is insufficient.
- Provider reset time, plan expiry, and quota exhaustion remain separate concepts.
- Shared UI wording must not erase provider HTTP status, raw numeric evidence, or diagnostic detail.
- Exhaustion must come from structured provider evidence, never from a bare persisted zero.
- A fallback must never invent a provider reset or expiry date.
- LongCat Pay-as-you-go balance must not inherit Token Pack expiry semantics.
- No live verification may reveal API keys, cookies, access tokens, or refresh tokens.

## Design

### 1. AnySearch origin, capture, refresh, and quota request

Update the AnySearch dashboard configuration so the primary console and request origin are `https://www.anysearch.com`. Continue accepting both apex and `www` hosts during capture so an existing redirect or older session does not break credential discovery, but serialize the captured tokens independently of their browser origin.

Keep `search-template-auth-state` as the captured storage key because the current bundle still publishes it. Normalize the persisted Zustand envelope into the existing credential model using only `accessToken`, `refreshToken`, and millisecond `expiresAt`. User identity is not needed for quota refresh and is out of scope.

Use these current requests:

- `POST https://www.anysearch.com/api/ssuser/auth/refresh` with `refresh_token`;
- `GET https://www.anysearch.com/api/api/user/billing/overview` with the bearer access token.

The duplicated `/api/api` is intentional: the frontend request helper owns the first `/api` base and the endpoint constant starts with `/api/user/...`. Tests must lock the final URL rather than reconstructing it informally.

Parse `remaining`, `used`, and `total` directly. Preserve `tier_name` as `planDisplayName`. Accept `reset_period` values `daily`, `monthly`, and `none`. Parse `next_reset_at` only when it is a valid ISO 8601 timestamp; if it is absent or invalid, leave `resetAt` empty. The provider's `daily` label alone does not prove a UTC boundary.

Quota fields must follow these rules:

- `total > 0`, `used >= 0`, and `0 <= remaining <= total`;
- when `used <= total`, `used + remaining == total`;
- overage is valid only when `used > total` and `remaining == 0`.

Missing fields, unsupported reset periods, or contradictory values are schema drift. Do not fall back to a local hard-coded 1,000 limit.

Save validation calls the real overview endpoint after an optional token refresh. If refresh rotates credentials, persist the rotated pair even when the subsequent quota request fails, while still reporting the quota failure.

### 2. SerpAPI renewal and account evidence

Extend the account parser with optional `plan_renewal_date`, `plan_name`, and `status` fields observed from the official response. Parse `plan_renewal_date` as a UTC calendar date and store it in `resetAt`; map nonempty `plan_name` to `planDisplayName`. Preserve nonempty `status` as diagnostic evidence without treating an exhaustion message as an authentication failure. If the renewal field is absent or invalid, leave `resetAt` empty; do not fall back to `nextMonthStartUTC()`.

Continue preferring `total_searches_left`, then `plan_searches_left`, then the derived difference. Keep extra credits in the displayed total. Preserve an exact remaining-over-total quota descriptor so a zero balance remains numerically explainable in credential details. Construct the account URL with `URLComponents` and `URLQueryItem` so reserved characters in the API key are encoded rather than interpolated into the URL.

### 3. Provider-wide exhausted Key Quota presentation

Add a persisted structured quota availability state shared by `QuotaResult`, `APIKey`, and `APIKeyStore`:

- `available`: the provider confirmed a usable positive quota, credit, balance, or percentage window;
- `exhausted`: the provider confirmed zero usable quota, credit, balance, or percentage, or returned an authenticated exhaustion response;
- `unavailable`: the provider explicitly reports that quota/service access is unavailable, such as DeepSeek `is_available = false`;
- `unknown`: the provider is usable but does not expose a remaining amount;
- absent: legacy records have no structured evidence and retain their existing presentation until refreshed.

Provider parsers must assign this state from their response contract. Shared helpers may derive `available` versus `exhausted` only inside a parser that has already validated that its numeric fields represent a real quota or balance. A generic HTTP-200-plus-zero rule is forbidden. Brave HTTP 402 and a verified long-window HTTP 429 explicitly produce `exhausted`. DeepSeek `is_available = false` explicitly produces `unavailable`, not `exhausted`.

The parser audit covers every currently visible quota-monitoring shape:

| Shape | Representative providers | State rule |
| --- | --- | --- |
| Request/count quota | Tavily, Brave, SerpAPI, AnySearch, coding plans | Valid positive remaining is `available`; validated zero is `exhausted`. |
| Token/percentage windows | Claude, Codex, Kimi, LongCat, percentage coding plans | Any usable positive monitored window is `available`; a provider-confirmed zero across its usable monitored resource is `exhausted`. |
| Prepaid credits | Serper, Anthropic Credits | Positive credit is `available`; validated zero credit is `exhausted`. |
| Monetary balance | DeepSeek, Bocha, WeChat Search, LongCat Pay-as-you-go | Positive balance is `available`; validated zero balance is `exhausted`; explicit service/balance unavailability is `unavailable`. |
| Usage without a limit | Exa, Querit, Brave without exposed monthly headers | `unknown`; never inferred as exhausted. |
| No subscription / unsupported monitoring | Providers returning an explicit missing-plan state or copy-only/business keys | Existing no-subscription/unsupported state; no exhaustion evidence. |

Persist the state through normal refresh and app restart. A failed later refresh preserves the last successful quota values and availability evidence alongside the new failure diagnostic, following the app's existing stale-value behavior.

Normalize only `ProviderStats.keyQuotaDisplayText`, which owns the provider-overview Key Quota column. Do not change `APIKey.quotaDisplayText`, `APIKey.quotaPresentation`, `APIKey.diagnosticSummary`, parser labels, or credential-detail rendering.

The rule applies to every provider represented by `ProviderStats`, regardless of whether its monitored resource is a request quota, token package, percentage window, prepaid credit, or monetary balance. Key Quota displays the localized `Usage limit exceeded` message (`额度已用尽` in Simplified Chinese) only when no active monitoring credential has structured state `available` and at least one active monitoring credential has structured state `exhausted`.

This includes zero monetary balances and zero prepaid-credit balances: the Key Quota column uses the shared exhausted message while credential details keep the currency or credit amount. Percentage-window providers already project their tightest window into `remaining` / `limit`; a verified zero projection therefore uses the same rule.

If any active monitoring credential has structured state `available`, mixed-pool selection continues to show the tightest usable quota. For percentage-window providers, the tightest window and percentage fallback must be calculated only from active monitoring credentials whose structured state is `available`; exhausted siblings cannot force the provider overview to `0%` while another credential is usable.

Invalid credentials, schema failures, no-subscription states, `unavailable`, `unknown`, unlimited quota, copy-only credentials, business-invocation-only keys, and expired authentication never become quota exhaustion merely because the provider pool has no usable key. A legacy `usageLimitExceeded` descriptor without structured state also retains its old presentation until refreshed; the shared rule does not guess from stale labels or zeros.

The credential detail retains:

- exact remaining and limit values;
- reset or renewal time;
- provider-specific HTTP status;
- provider-specific diagnostic text.

The Critical Time column remains responsible for reset, renewal, or package-expiry timing. This avoids duplicating reset text inside Key Quota. Mixed pools continue to show the tightest usable credential when at least one credential remains usable; an exhausted sibling is surfaced through the attention count rather than hiding the usable quota.

### 4. LongCat Token Pack expiry

Add a LongCat-specific parser for `yyyy-MM-dd HH:mm:ss` using the `Asia/Shanghai` timezone because the live console and `remainSeconds` confirm that the timezone-less timestamp is China local time. Use it after the existing numeric and ISO date forms when parsing LongCat `expireTime` aliases.

Store the parsed value as `planEndsAt` on the Token Pack result and combined LongCat result. Keep `resetAt = nil`. Leave Pay-as-you-go `planEndsAt` empty.

Do not broaden the generic date parser: provider-specific handling prevents a timezone assumption from affecting other providers.

## Error Handling

- AnySearch refresh HTTP 400/401/403 remains an expired-credential error and preserves the actual status.
- AnySearch quota HTTP 401 is expired authentication; quota HTTP 403 preserves status 403 and remains forbidden/invalid authorization; quota HTTP 404 is schema drift with status 404. A schema-invalid HTTP 200 is schema drift with status 200. Implement an error/status carrier if necessary so `lastHTTPStatus` receives the actual response status instead of losing it through the current status-less `schemaDrift` / `invalidResponse` cases.
- AnySearch never silently calls the retired endpoint.
- SerpAPI invalid renewal dates leave reset unknown while valid quota fields still refresh successfully.
- Brave HTTP 402 and verified monthly HTTP 429 both present the shared exhausted Key Quota text but retain their original HTTP status and diagnostics.
- LongCat absent or empty `expireTime` updates quota with unknown expiry and no diagnostic. A present nonempty malformed `expireTime` updates quota, leaves expiry unknown, and attaches schema-drift diagnostic text while keeping HTTP 200. A valid numeric, ISO, or LongCat local timestamp produces `planEndsAt` without a diagnostic.

## Test Strategy

Use focused RED/GREEN tests before production changes.

### AnySearch

- capture accepts `www.anysearch.com` and the current storage key;
- final refresh and overview URLs match the current bundle contract;
- current overview fields parse plan, used, remaining, total, and reset;
- daily/monthly/none reset periods are accepted without inventing a boundary; absent and invalid `next_reset_at` leave reset unknown;
- exact-total, exhausted, and overage field combinations follow the stated invariants, while contradictory combinations fail as schema drift;
- rotated credentials persist through a later quota failure;
- legacy usage-summary responses do not produce false success;
- refresh 400/401/403 and quota 401/403/404 preserve their exact status; HTTP 200 schema mismatch preserves status 200.

### SerpAPI

- official renewal date becomes `resetAt`;
- exhausted `250 / 250` produces zero remaining and an exact total;
- extra credits remain included;
- missing or invalid renewal date produces no invented reset;
- `plan_name` becomes the plan display name and `status` remains diagnostic evidence;
- a key containing reserved URL characters is encoded through URL query items;
- `2026-08-10` resolves to the exact expected UTC epoch.

### Shared presentation

- table-driven cases cover all quota shapes: request count, token count, percentage window, prepaid credit, and monetary balance;
- exhausted Tavily, Brave HTTP 402, Brave verified monthly 429, SerpAPI, LongCat Token Pack, subscription/coding-plan windows, prepaid credits, and zero monitored balances produce the same localized `ProviderStats.keyQuotaDisplayText` when their latest response verifies exhaustion;
- parser fixtures assert `available`, `exhausted`, `unavailable`, or `unknown` evidence as appropriate and APIKeyStore round-trips it;
- `APIKey.quotaDisplayText`, exact detail values, Brave 402/429 `lastHTTPStatus`, and their distinct `lastDiagnosticText` remain provider-specific;
- mixed usable/exhausted key pools still show usable quota;
- a mixed exhausted/usable percentage-provider pool derives its displayed window only from the usable credential;
- DeepSeek `is_available = false` is `unavailable`, not exhausted;
- unknown, unavailable, unlimited, expired, failed, no-subscription, copy-only, business-key-only, legacy usage-limit-without-state, and stale zero-without-state fixtures do not become exhausted.

### LongCat

- live timestamp fixture parses to 2026-08-08 12:07:16 Asia/Shanghai;
- combined result preserves Token Pack expiry;
- Pay-as-you-go remains non-expiring;
- ISO and numeric expiry fixtures remain supported;
- absent/empty expiry remains a clean unknown; a present malformed expiry preserves quota and adds schema-drift diagnostics.

Run the focused behavior suite, the full behavior suite, build verification, and final dirty-tree review on the final SHA.

## Live Acceptance

After automated tests pass:

1. Reauthenticate or reuse the current AnySearch logged-in session, save it, and verify HTTP 200 plus the current plan/used/remaining/total values immediately in local state.
2. Refresh SerpAPI and verify zero remaining with the official 2026-08-10 renewal date rather than September 1.
3. Verify representative exhausted providers across request, token, percentage-window, credit, and money-balance shapes use the same Key Quota copy while their detailed evidence differs.
4. Refresh LongCat with the current saved session and verify HTTP 200 plus `planEndsAt = 2026-08-08 12:07:16 +08:00`.
5. Recheck Codex Subscription as a non-regression: Pro 20x remains HTTP 200, the weekly window remains available, and omission of a fully recovered five-hour window is not treated as exhaustion.

## Out of Scope

- Restoring or purchasing exhausted external SerpAPI quota.
- Attributing historical SerpAPI calls without dashboard archive evidence.
- Changing Codex quota-window semantics; the latest successful refresh already showed the five-hour restriction recovered.
- Releasing, tagging, or pushing a new version unless separately requested after the fix passes QA.
