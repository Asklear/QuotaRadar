# Provider Quota Contract Repair Design

Date: 2026-08-01
Status: Approved in conversation; pending written-spec review

## Objective

Repair four provider contract and presentation problems without changing unrelated providers:

1. AnySearch authentication saved from the logged-in `www.anysearch.com` console must validate and immediately refresh the daily quota.
2. SerpAPI must use the account's official renewal date instead of inventing a next-month boundary.
3. Exhausted finite plans must use one shared Key Quota message across Tavily, Brave, SerpAPI, and other providers with the same state.
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

### Tavily and Brave

Provider-specific parser results currently reach the shared UI with different exhausted descriptors such as `Exhausted`, `Usage limit exceeded`, numeric zero labels, and reset-appended primary text. This makes the Key Quota column inconsistent even though the business state is the same. Brave HTTP 402 and verified long-window HTTP 429 must retain their distinct HTTP and diagnostic evidence.

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
- A fallback must never invent a provider reset or expiry date.
- LongCat Pay-as-you-go balance must not inherit Token Pack expiry semantics.
- No live verification may reveal API keys, cookies, access tokens, or refresh tokens.

## Design

### 1. AnySearch origin, capture, refresh, and quota request

Update the AnySearch dashboard configuration so the primary console and request origin are `https://www.anysearch.com`. Continue accepting both apex and `www` hosts during capture so an existing redirect or older session does not break credential discovery, but serialize the captured tokens independently of their browser origin.

Keep `search-template-auth-state` as the captured storage key because the current bundle still publishes it. Normalize the persisted Zustand envelope into the existing credential model, including access token, refresh token, expiry, and user identity metadata when present.

Use these current requests:

- `POST https://www.anysearch.com/api/ssuser/auth/refresh` with `refresh_token`;
- `GET https://www.anysearch.com/api/api/user/billing/overview` with the bearer access token.

The duplicated `/api/api` is intentional: the frontend request helper owns the first `/api` base and the endpoint constant starts with `/api/user/...`. Tests must lock the final URL rather than reconstructing it informally.

Parse `remaining`, `used`, and `total` directly. Preserve `tier_name` as `planDisplayName`. Map `reset_period = daily` to the next UTC day only when `next_reset_at` is absent; prefer a valid `next_reset_at` when the API supplies it. Reject missing or contradictory quota fields as schema drift instead of falling back to a local hard-coded 1,000 limit.

Save validation calls the real overview endpoint after an optional token refresh. If refresh rotates credentials, persist the rotated pair even when the subsequent quota request fails, while still reporting the quota failure.

### 2. SerpAPI renewal and account evidence

Extend the account parser with optional `plan_renewal_date`, plan name, and status fields observed from the official response. Parse the renewal date as a UTC calendar date and store it in `resetAt`. If the field is absent or invalid, leave `resetAt` empty; do not fall back to `nextMonthStartUTC()`.

Continue preferring `total_searches_left`, then `plan_searches_left`, then the derived difference. Keep extra credits in the displayed total. Preserve an exact remaining-over-total quota descriptor so a zero balance remains numerically explainable in credential details.

### 3. Shared exhausted Key Quota presentation

Normalize the provider-overview Key Quota column at the shared `APIKey` / `ProviderStats` presentation boundary, not in individual parsers.

When a finite monitored credential or provider pool has no usable remaining quota and its state is verified as exhausted or usage-limit-exceeded, Key Quota displays the localized `Usage limit exceeded` message (`额度已用尽` in Simplified Chinese). This rule applies consistently to Tavily, Brave, SerpAPI, and equivalent finite-plan providers.

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

- AnySearch 401/403 after refresh remains an expired-credential error.
- AnySearch 404 or schema mismatch on the new endpoint is schema drift and must not silently call the retired endpoint.
- SerpAPI invalid renewal dates leave reset unknown while valid quota fields still refresh successfully.
- Brave HTTP 402 and verified monthly HTTP 429 both present the shared exhausted Key Quota text but retain their original HTTP status and diagnostics.
- LongCat valid quota with an invalid expiry still updates quota, leaves expiry unknown, and records parser diagnostics only if the response contract requires expiry for the current package.

## Test Strategy

Use focused RED/GREEN tests before production changes.

### AnySearch

- capture accepts `www.anysearch.com` and the current storage key;
- final refresh and overview URLs match the current bundle contract;
- current overview fields parse plan, used, remaining, total, and reset;
- rotated credentials persist through a later quota failure;
- legacy usage-summary responses do not produce false success.

### SerpAPI

- official renewal date becomes `resetAt`;
- exhausted `250 / 250` produces zero remaining and an exact total;
- extra credits remain included;
- missing or invalid renewal date produces no invented reset.

### Shared presentation

- exhausted Tavily, Brave HTTP 402, Brave verified monthly 429, and SerpAPI produce the same localized Key Quota text;
- detail values and diagnostics remain provider-specific;
- mixed usable/exhausted key pools still show usable quota.

### LongCat

- live timestamp fixture parses to 2026-08-08 12:07:16 Asia/Shanghai;
- combined result preserves Token Pack expiry;
- Pay-as-you-go remains non-expiring;
- ISO and numeric expiry fixtures remain supported.

Run the focused behavior suite, the full behavior suite, build verification, and final dirty-tree review on the final SHA.

## Live Acceptance

After automated tests pass:

1. Reauthenticate or reuse the current AnySearch logged-in session, save it, and verify HTTP 200 plus the current plan/used/remaining/total values immediately in local state.
2. Refresh SerpAPI and verify zero remaining with the official 2026-08-10 renewal date rather than September 1.
3. Verify exhausted Tavily/Brave/SerpAPI examples use the same Key Quota copy while their detailed evidence differs.
4. Refresh LongCat with the current saved session and verify HTTP 200 plus `planEndsAt = 2026-08-08 12:07:16 +08:00`.
5. Recheck Codex Subscription as a non-regression: Pro 20x remains HTTP 200, the weekly window remains available, and omission of a fully recovered five-hour window is not treated as exhaustion.

## Out of Scope

- Restoring or purchasing exhausted external SerpAPI quota.
- Attributing historical SerpAPI calls without dashboard archive evidence.
- Changing Codex quota-window semantics; the latest successful refresh already showed the five-hour restriction recovered.
- Releasing, tagging, or pushing a new version unless separately requested after the fix passes QA.
