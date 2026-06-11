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
| Querit | AI Search | Web login plus optional API key | Pending cookie/OAuth phase | Dashboard account endpoint. |
| Claude Subscription | LLM | Web login plus optional API key | Pending cookie/OAuth phase | Subscription quota via `claude.ai` organization endpoints. |
| Codex Subscription | LLM | Web login plus optional API key | Pending cookie/OAuth phase | Subscription quota via ChatGPT session and WHAM endpoints. |
| Kimi Subscription | LLM | Web login plus optional API key | Pending cookie/OAuth phase | Membership plus billing endpoints. |
| XFYun Spark Coding Plan | LLM | Web login plus optional API key | Pending cookie/OAuth phase | Coding plan list endpoint. |
| Volcengine Coding Plan | LLM | Web login plus optional API key | Pending cookie/OAuth phase | Ark coding plan usage endpoint. |
| OpenCode Go | LLM | Web login plus optional API key | Pending cookie/OAuth phase | Dashboard server function endpoint. |
| Aliyun Coding Plan | LLM | Web login plus optional API key | Pending cookie/OAuth phase | Bailian coding plan gateway endpoint. |
| Tencent Cloud Coding Plan | LLM | Web login plus optional API key | Pending cookie/OAuth phase | `DescribePkg` console endpoint. |
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
| Aliyun Coding Plan | `login_aliyunid_ticket`, `aliyun_lang`, `cna` | Fetch Bailian `secToken`, then BroadScope coding-plan gateway API. | Optional coding plan API key. |
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

## Phase 3: Configuration And Legacy Migration

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

## Verification Checklist

- `cargo test --manifest-path apps/desktop-tauri/src-tauri/Cargo.toml`
- `pnpm test -- --run` from `apps/desktop-tauri`
- `pnpm typecheck` when TypeScript contracts or UI change
- `pnpm build` when frontend or command contracts change
- `pnpm test:e2e` after visible UI changes
- `git diff --check`
- Sensitive scan for API keys, bearer tokens, cookies, and screenshots before
  every commit.
