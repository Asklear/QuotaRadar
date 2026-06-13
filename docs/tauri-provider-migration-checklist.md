# Tauri Provider Migration Checklist

This checklist is the source of truth for moving the Swift provider layer into
the cross-platform Tauri app. It intentionally records provider behavior, not
real credentials. Do not add API keys, cookies, bearer tokens, screenshots with
secrets, or live response payloads that can identify an account.

## Migration Order

1. API-key providers.
2. Cookie/OAuth providers.
3. Configuration and legacy migration.

The existing SwiftUI app remains the behavior reference until each row below is
implemented and verified in `apps/desktop-tauri`.

## Current Tauri Status

| Provider | Category | Swift credential source | Tauri status | Notes |
| --- | --- | --- | --- | --- |
| Tavily | AI Search | API key | Done | `GET https://api.tavily.com/usage`, no quota spent. |
| Brave | AI Search | API key | Done | Search probe consumes one request; automatic refresh must stay opt-in. |
| SerpAPI | AI Search | API key | Done | `GET https://serpapi.com/account.json?api_key=...`. |
| DeepSeek | LLM | API key | Done | Money balance provider, CNY display. |
| Serper | AI Search | API key | Done | Account endpoint returns credits. |
| Bocha | AI Search | API key | Done | Money balance provider, CNY display. |
| AnySearch | AI Search | API key placeholder | Done | No remote quota; current Swift policy is unlimited/free. |
| WeChat Search | AI Search | API key | Done | Money balance provider, CNY display. |
| Exa | AI Search | Admin credential | Done | Plain Exa search key is insufficient; requires service key plus target API key id. |
| Querit | AI Search | Web login plus optional API key | Done | Production HTTP refresh for dashboard account monthly request usage; when plan limit is absent, reports usage without fake quota totals. |
| Claude Subscription | LLM | Web login plus optional API key | Done | Production HTTP refresh discovers organization, usage windows, and subscription details. |
| Codex Subscription | LLM | Web login plus optional API key | Done | Production HTTP refresh resolves ChatGPT session, WHAM usage windows, and subscription lifecycle. |
| Kimi Subscription | LLM | Web login plus optional API key | Done | Production HTTP refresh for membership plus billing usage; parser also covers OAuth usage shape and plan expiry. |
| XFYun Spark Coding Plan | LLM | Web login plus optional API key | Done | Production HTTP refresh for coding plan list usage windows and package expiry. |
| Volcengine Coding Plan | LLM | Web login plus optional API key | Done | Production HTTP refresh for Ark coding plan usage windows and reset timestamps. |
| OpenCode Go | LLM | Web login plus optional API key | Done | Production HTTP refresh replays dashboard server function usage windows. |
| Aliyun Coding Plan | LLM | Web login plus optional API key | Done | Production HTTP refresh for Bailian coding plan instance info and legacy usage-detail shapes. |
| Tencent Cloud Coding Plan | LLM | Web login plus optional API key | Done | Production HTTP refresh for console `DescribePkg` usage windows, reset timestamps, package expiry, empty packages, and login-state failures. |
| Tencent Cloud Token Plan | LLM | Cloud API credential | Hidden or pending | Swift has a parser, but this is not currently part of the visible provider set. |
| XFYun Spark Token Plan | LLM | Unknown | Hidden/pending | Swift intentionally hides it from visible providers. |
| Volcengine Token Plan | LLM | Unknown | Hidden/pending | Swift intentionally hides it from visible providers. |
| Aliyun Token Plan | LLM | Unknown | Hidden/pending | Swift intentionally hides it from visible providers. |
| Anthropic API Usage | LLM | API key | Hidden/unsupported | Roadmap only for prepaid/API usage. |
| Claude API Usage | LLM | API key | Hidden/unsupported | Roadmap only for API usage. |
| Codex API Usage | LLM | API key | Hidden/unsupported | Roadmap only for API usage. |

## Phase 1: API-Key Providers

Migrate these before any browser-login provider. Each provider must have fixture
tests for success, unauthorized/invalid credential, quota unavailable when the
API can return a usable account without quota, and network error mapping.

| Provider | Endpoint or policy | Credential | Quota semantics | Reset/expiry |
| --- | --- | --- | --- | --- |
| Tavily | `GET https://api.tavily.com/usage` | Bearer API key | Monthly credits. | Monthly reset from response or next month fallback. |
| Brave | `GET https://api.search.brave.com/res/v1/web/search?q=test&count=1` | `X-Subscription-Token` | Monthly requests when rate-limit headers expose them. | Header reset if present; known free keys may need configured fallback. |
| SerpAPI | `GET https://serpapi.com/account.json?api_key=...` | Query API key | Monthly searches. | Next month fallback if not exposed. |
| Serper | `GET https://google.serper.dev/account` | `X-API-KEY` | Credit balance. | No reset date exposed by Swift parser. |
| Bocha | `GET https://api.bochaai.com/v1/fund/remaining` | Bearer API key | Remaining RMB balance. | No reset date exposed by Swift parser. |
| AnySearch | Local policy | Stored API key placeholder | Unlimited/free. | No reset date. |
| WeChat Search | `POST https://www.dajiala.com/fbmain/monitor/v3/get_remain_money` | Form `key=...` | Remaining RMB balance. | No reset date exposed by Swift parser. |
| Exa | `GET https://admin-api.exa.ai/team-management/api-keys/{apiKeyID}/usage?numDays=...` | JSON/admin credential with service key and API key id | Team-management usage over a day window. | Window-based, not a monthly subscription reset. |
| DeepSeek | `GET https://api.deepseek.com/user/balance` | Bearer API key | Remaining RMB balance. | No reset date exposed by Swift parser. |

### API-Key Migration Rules

- Do not perform real network calls in unit tests.
- Keep Brave out of normal automatic refresh because the check spends a search.
- Mark money providers with CNY/RMB labels in UI selectors.
- Do not make Exa look like a normal API-key quota check. The stored secret is
  an admin credential object, not a plain Exa search key.

### API-Key Production Transport Coverage

- Done: shared `ProviderTransport`/`ProviderHttpRequest` path with proxy-aware
  Reqwest transport.
- Done: response headers are available to providers that expose quota through
  rate-limit headers.
- Done: live HTTP refresh implementations for Tavily, Brave, SerpAPI, Serper,
  Exa, Bocha, WeChat Search, and DeepSeek.
- Done: Brave parses monthly request quota from rate-limit headers and remains
  marked as a quota-consuming refresh.
- Done: Exa uses the team-management usage endpoint with the stored service key
  plus target API key id; plain Exa search keys remain unsupported for quota
  monitoring.

## Phase 2: Cookie/OAuth Providers

These providers depend on browser login, dashboard cookies, OAuth-like session
tokens, or private console endpoints. Migrate them after API-key providers so
the shared credential and refresh model is stable.

| Provider | Required login/cookie markers | Endpoint sequence | Companion API key |
| --- | --- | --- | --- |
| Querit | `osduss`, `passOsRefreshTk`, `osfuid` | `GET https://www.querit.ai/api/v1/user/account` | Optional `QUERIT_API_KEY`. |
| Claude Subscription | `sessionKey` | `GET /api/organizations`, then `GET /api/organizations/{org}/usage`, then subscription details. | Optional `ANTHROPIC_API_KEY`. |
| Codex Subscription | `__Secure-next-auth.session-token` or `__search-next-auth` | `GET /api/auth/session`, then `GET /backend-api/wham/usage`, then subscriptions. | Optional `OPENAI_API_KEY`. |
| Kimi Subscription | `kimi-auth`, `accessToken`, or `access_token` | Billing usage plus membership subscription endpoints. | Optional `KIMI_API_KEY`. |
| XFYun Spark Coding Plan | `ssoSessionId`, `tenantToken`, `atp-auth-token`, `account_id` | `GET https://maas.xfyun.cn/api/v1/gpt-finetune/coding-plan/list?page=1&size=6` | Optional coding plan API key. |
| Volcengine Coding Plan | `digest`, `AccountID`, `csrfToken` | `POST https://console.volcengine.com/api/top/ark/cn-beijing/2024-01-01/GetCodingPlanUsage?` | Optional coding plan API key. |
| OpenCode Go | `auth` | `GET https://opencode.ai/_server?id=...&args=...` | Optional OpenCode Go API key. |
| Aliyun Coding Plan | `login_aliyunid_ticket`, `aliyun_lang`, `cna` | Bailian BroadScope coding-plan gateway API. | Optional coding plan API key. |
| Tencent Cloud Coding Plan | `uin`, `skey` | Console `DescribePkg` endpoint with computed CSRF code. | Optional coding plan API key. |

### Cookie/OAuth Migration Rules

- Store quota authorization and copyable API key separately. Users should be
  able to copy invocation API keys, not dashboard cookies.
- Browser reauthentication must target a specific credential when multiple
  accounts exist for the same provider.
- The refresh result must update only the selected provider and must preserve
  provider expansion/order state.
- Private console endpoints need fixtures that represent valid subscription,
  no subscribed plan, expired login, and shape drift.

### Cookie/OAuth Production Transport Coverage

- Done: Kimi Subscription requests `MembershipService/GetSubscription` and
  `BillingService/GetUsages` with the saved access token and optional browser
  session headers, then merges subscription balance, 5-hour quota, weekly quota,
  reset times, and plan expiry through the shared parser.
- Done: Codex Subscription resolves the ChatGPT web session access token, calls
  `backend-api/wham/usage`, and uses the session account id for subscription
  lifecycle expiry.
- Done: Claude Subscription discovers the active organization, calls
  organization usage, and fetches subscription details with the saved Claude web
  login cookie.
- Done: OpenCode Go replays the dashboard `_server` request with saved cookie,
  workspace id, server id, and server instance to parse rolling, weekly, and
  monthly quota windows.
- Done: XFYun Spark Coding Plan calls the coding-plan list endpoint with saved
  console login cookies and parses 5-hour, weekly, and monthly request-count
  windows plus package expiry.
- Done: Volcengine Coding Plan posts `ProjectName` to `GetCodingPlanUsage`
  with saved console login cookie, CSRF token, and optional web id.
- Done: Aliyun Coding Plan calls the Bailian BroadScope gateway
  `queryCodingPlanInstanceInfoV2` endpoint with saved console login cookies and
  parses request-count windows, reset times, no-subscription state, and package
  expiry.
- Done: Tencent Cloud Coding Plan calls the console `DescribePkg` endpoint with
  saved console login cookies, numeric UIN values, and computed CSRF code.
- Done: Querit calls the dashboard account endpoint with saved web login
  cookies and parses monthly request usage; if the endpoint omits a plan limit,
  it reports usage without inventing a large quota number.
- Pending: none for the currently visible cookie/OAuth provider set.

## Phase 3: Configuration And Legacy Migration

Status:

- Done: fixture-first migration core for Swift-shaped credential metadata,
  secret maps, key settings, provider order, Swift `Date` numeric values,
  companion API-key links, and QuotaBar one-way migration markers.
- Done: startup IO that reads macOS preference plists for
  `com.gaorongvc.quotaradar` and `com.gaorongvc.quotabar`, reads the Swift
  `secrets.json` files, invokes the migration core during Tauri setup, and
  writes the completion marker.
- Done: `~/.claude/settings.json` import path that reuses Swift-style
  environment detection, imports only visible provider credentials, merges by
  provider/name, and keeps raw secret values out of metadata.

Swift stores metadata and secrets separately:

| Swift source | Meaning | Tauri target |
| --- | --- | --- |
| `UserDefaults.apiKeyMetadata` | Credential metadata, provider id, display name, active flag, saved quota snapshot, linked authorization id. | Tauri metadata store. |
| `Library/Application Support/QuotaRadar/secrets.json` | Secret payloads keyed by credential id. | Tauri secret vault/fallback secret store. |
| `com.gaorongvc.quotabar` defaults | Legacy QuotaBar preferences. | One-time legacy migration. |
| `Library/Application Support/QuotaBar/secrets.json` | Legacy secret file. | One-time migration into QuotaRadar secret store. |

### Settings To Preserve

- Provider order and provider-order lock.
- App language.
- Status bar/tray popover appearance settings.
- Automatic refresh interval.
- Costly automatic refresh interval.
- Network proxy mode and custom proxy URL.
- Last update check state when the updater is migrated.

### Migration Rules

- Preserve credential ids where possible so linked dashboard authorization and
  companion API-key references keep working.
- Never migrate deleted metadata back if the user explicitly cleared it.
- Keep old QuotaBar migration one-way and idempotent.
- Secret files must be created with user-only permissions on platforms that
  expose POSIX permissions.
- Add fixture tests with Swift-shaped metadata and secret records before writing
  migration code.

### Implemented Core Coverage

- `apps/desktop-tauri/src-tauri/src/storage/migration.rs` maps supported Swift
  providers to Tauri provider ids and skips unsupported or hidden providers.
- `apiKeyMetadata` entries preserve credential ids, active state, notes,
  linked authorization ids, last HTTP status, diagnostic text, quota labels,
  remaining/limit snapshots, reset dates, and plan expiry dates.
- Swift `Date` values encoded as seconds since `2001-01-01T00:00:00Z` are
  converted to UTC RFC3339 strings for Tauri.
- Dashboard-login providers migrate as non-copyable quota authorization
  credentials, while companion invocation API keys migrate as copyable
  `storedAPIKeyOnly` credentials linked to the authorization id.
- Swift settings migrate `appLanguage`, `statusBarTransparency`,
  `autoRefreshInterval`, `quotaConsumingAutoRefreshInterval`,
  `networkProxyMode`, `customProxyURL`, `automaticallyCheckForUpdates`, and
  custom `providerOrder`.
- If the QuotaBar migration marker is already present, legacy QuotaBar defaults,
  metadata, and secrets are ignored so old data cannot overwrite newer Tauri
  edits.
- Claude settings import parses the `env` object, ignores placeholders and
  unsupported variables, stores raw values in the secret vault, and returns a
  summary with added/updated counts for the credentials page.

### Startup IO

- MacOS-only reader for `~/Library/Preferences/com.gaorongvc.quotaradar.plist`
  and `~/Library/Preferences/com.gaorongvc.quotabar.plist`.
- Decodes `apiKeyMetadata` data values from those plists and passes their JSON
  bytes to the migration core.
- Reads `~/Library/Application Support/QuotaRadar/secrets.json` and
  `~/Library/Application Support/QuotaBar/secrets.json` without logging secret
  contents.
- Persists a Tauri-side migration marker after successful import so later
  launches do not overwrite user edits in the Tauri app.

## Verification Checklist

- `cargo test --manifest-path apps/desktop-tauri/src-tauri/Cargo.toml`
- `pnpm test -- --run` from `apps/desktop-tauri`
- `pnpm typecheck` when TypeScript contracts or UI change
- `pnpm build` when frontend or command contracts change
- `pnpm test:e2e` after visible UI changes
- `git diff --check`
- Sensitive scan for API keys, bearer tokens, cookies, and screenshots before
  every commit.
