# Provider Capability Matrix

<p align="right">
  <a href="./provider-capabilities.md">简体中文</a> |
  <strong>English</strong>
</p>

This matrix is the entry point for adding providers: define credential type, usage source, reset cycle, and whether checks consume real quota before wiring UI, automatic refresh, and connection tests.

The Swift macOS app remains the stable release track. The Tauri app under `apps/desktop-tauri` is the cross-platform preview implementation and must follow the same provider admission, credential-display, and safety boundaries in this matrix. Tauri tests, screenshots, and documentation examples must use redacted or fixture data only, never real API keys, bearer tokens, or cookies.

## AI Search

| Provider | Category | Credential Type | Usage Source | Reset / Window | Check Consumes Quota | Diagnostic Endpoint | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Tavily | AI Search | API Key | Official Usage API | Monthly day 1 | No | `GET /usage` | Free monthly quota resets and does not roll over. |
| Brave Search | AI Search | API Key | Search response header | Not exposed | Yes | `GET /res/v1/web/search` | Each check issues a real search request. |
| SerpAPI | AI Search | API Key | Account API | Monthly | No | `GET /account.json` | Returns search balance. |
| Serper | AI Search | API Key | Account API | Not exposed | No | `GET /account` | Returns balance and `rateLimit`; reset/end fields are not exposed. |
| Exa | AI Search | API key | Admin API | Not exposed | No | Team Management usage API | Plain search keys cannot query usage; requires service key + API key id. |
| Bocha | AI Search | API Key | Official balance API | No fixed cycle | No | Remaining fund API | Displayed as CNY balance. |
| AnySearch | AI Search | API Key | Local policy | No fixed cycle | No | None | Currently free, shown as unlimited. |
| Querit | AI Search | Web login authorization; optional API key for storing/copying only | Dashboard Account API | Not exposed | No | `/api/v1/user/account` | Monthly usage is readable; the current account endpoint does not expose a plan limit, reset time, or end date. `QUERIT_API_KEY` can be stored and copied, but cannot query dashboard usage. |
| WeChat Search | AI Search | API Key | Official balance API | No fixed cycle | No | Remaining money API | Displayed as CNY balance. |

## LLM / Plans

| Provider | Category | Credential Type | Usage Source | Reset / Window | Check Consumes Quota | Diagnostic Endpoint | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Claude API Usage | LLM | API Key | Official Admin API | Not exposed | No | Admin usage report | Hidden from the main UI/import flow for now; organization-level usage reports require Anthropic Admin access and are not the Claude subscription five-hour/weekly/monthly windows. |
| Claude Subscription | LLM | Web login authorization; optional `ANTHROPIC_API_KEY` for storing/copying only | `claude.ai` Organization Usage API | 5-hour / weekly; no monthly window observed | No | `/api/organizations` + `/api/organizations/{org_uuid}/usage` + `/api/organizations/{org_uuid}/subscription_details` | Subscription quota is wired: Quota Radar discovers the active organization, parses `five_hour` and `seven_day` `utilization` plus `resets_at`, and uses `next_charge_at` or `next_charge_date` as the subscription-cycle end date. Model-specific windows are not shown in the compact UI yet. API keys are not used for subscription quota checks. |
| Codex API Usage | LLM | API Key | Official Admin API | Not exposed | No | OpenAI usage/costs API | Hidden from the main UI/import flow for now; platform usage/costs APIs usually require an Admin API key and are separate from ChatGPT/Codex subscription windows. |
| Codex Subscription | LLM | Web login authorization; optional `OPENAI_API_KEY` for storing/copying only | ChatGPT Codex Cloud Usage API | 5-hour / weekly; no monthly window observed | No | `/api/auth/session` + `/backend-api/wham/usage` + `/backend-api/subscriptions?account_id=...` | Wired to resolve the ChatGPT session access token and then call `/backend-api/wham/usage`, showing five-hour/weekly windows and reset times. It uses `/api/auth/session` `account.id` to query the subscription lifecycle endpoint and persist plan expiry. API keys are not used for subscription quota checks. |
| Kimi | LLM | Web login authorization / Bearer access token; optional `KIMI_API_KEY` for storing/copying only | Kimi BillingService + MembershipService | 5-hour / weekly; no independent monthly rate-limit window confirmed | No | `BillingService/GetUsages` + `GetSubscription` | `BillingService/GetUsages` with `scope:["FEATURE_CODING"]` returns Kimi Code weekly `detail` plus five-hour `limits[]`, including `remaining/limit/resetTime`; `GetSubscription` returns subscription balance, `next_billing_time`, or balance `expire_time`. Monthly balance is shown only when `amount/amount_left` or `amountUsedRatio` fields are exposed; Quota Radar does not invent monthly quota. API keys are not used for subscription quota checks. |
| DeepSeek | LLM | API Key | Official balance API | No fixed cycle | No | `/user/balance` | Displayed as CNY balance. |
| XFYun Spark Coding Plan | LLM | Web login authorization | Dashboard Coding Plan API | 5-hour/weekly/monthly windows; reset not exposed | No | `/api/v1/gpt-finetune/coding-plan/list` | Request-count based. Shows remaining percentage plus remaining/total counts for 5-hour, weekly, and monthly windows. |
| XFYun Spark Token Plan | LLM | Hidden extension stub | Dashboard Token Plan seat/quota endpoints confirmed, not wired | Needs a purchased-seat sample | No | `/api/v1/gpt-finetune/token-plan/seats` + `/api/v1/gpt-finetune/token-plan/quota` | The current account has no seats; the quota endpoint returns seat-type `remainingCount/totalCount`, which looks like seat/count quota, not business API-key token consumption. Hidden until non-empty package fields are confirmed. |
| Volcengine Coding Plan | LLM | Web login authorization | Dashboard Coding Plan API | 5-hour/weekly/monthly windows; returns reset | No | `GetCodingPlanUsage` + `ListSubscribeTrade` | `GetCodingPlanUsage` shows five-hour, weekly, and monthly remaining percentages plus resets; `ListSubscribeTrade` returns package start/end times. Direct replay requires login cookie, CSRF, and project name. |
| Volcengine Token Plan | LLM | Hidden extension stub | Not confirmed | Not confirmed | No | To confirm | Resource-package / Token Plan entry points were checked, but no independent stable replayable usage endpoint is confirmed. Hidden until confirmed. |
| OpenCode Go | LLM | Web login authorization; optional `OPENCODE_GO_API_KEY` for storing/copying only | Dashboard Server Function | 5-hour/weekly/monthly windows; returns reset | No | `/_server` | Requires cookie, workspace id, server id, and server instance. API keys are not used for subscription quota checks. |
| Aliyun Coding Plan | LLM | Web login authorization | Dashboard Coding Plan subscription-instance API | 5-hour/weekly/monthly windows; returns reset and package expiry | No | `BroadScopeAspnGateway` / `codingPlan.queryCodingPlanInstanceInfoV2` | Official docs describe Coding Plan as fixed monthly fee with monthly request quota. Empty `codingPlanInstanceInfos` is shown as no subscription; valid instances parse `codingPlanQuotaInfo` request-count windows, window reset times, and `instanceEndTime`. Business invocation keys can be stored but are not used for quota monitoring. |
| Aliyun Token Plan | LLM | Hidden extension stub | Dashboard Token Plan subscription-list endpoint confirmed, not wired | Needs a purchased-plan sample | No | `BroadScopeAspnGateway` / `bailian-commerce.tokenPlan.queryTokenPlanInstanceInfo` | The current account returns supported models and an empty `tokenPlanInstanceInfos`; Token Plan is expected to be credits-based, but non-empty quota/reset/end fields still need a real purchased-plan sample. |
| Tencent Cloud Coding Plan | LLM | Web login authorization | Dashboard Coding Plan API | 5-hour/weekly/monthly windows; returns reset when subscribed | No | `cgi/capi?cmd=DescribePkg&serviceType=hunyuan` | Request-count based. Shows remaining percentage plus remaining/total counts for five-hour, weekly, and monthly windows; no subscription is shown as "No subscribed plan". Business invocation keys can be stored but are not used for quota monitoring. |
| Tencent Cloud Token Plan | LLM | Hidden extension stub | Official TokenHub API parser retained; dashboard subscription-list API confirmed | Needs a real key / non-empty package sample | No | `DescribeTokenPlanApiKey`; dashboard page uses `cgi/capi?cmd=ListUserTokenPlans&serviceType=hunyuan` | Code keeps token-quota parsing for `Balance.*Quota/*Remain`, but there is no real user key sample yet. Hidden from UI, import, and refresh until verified. |

## Credential Shapes

Normal API-key providers accept the key string directly.

Web login authorization providers can be re-authenticated in app, or configured from a copied dashboard cURL command. Quota Radar stores only the required local login authorization data; when the provider endpoint requires it, that data includes the request Cookie header:

```env
VOLCENGINE_CODING_PLAN_COOKIE='{"cookie":"<cookie-header-value>","csrfToken":"<csrf-token>","projectName":"default"}'
OPENCODE_GO_COOKIE='{"cookie":"<cookie-header-value>","workspaceID":"wrk_example","serverID":"server-example","serverInstance":"server-fn:11"}'
KIMI_SUBSCRIPTION_SESSION='{"accessToken":"<redacted-access-token>","cookieHeader":"<redacted-kimi-auth-cookie-header>","deviceID":"<x-msh-device-id>","sessionID":"<x-msh-session-id>"}'
```

Aliyun Coding Plan and Tencent Cloud Coding Plan business invocation keys can be stored and shown, but quota monitoring uses web login authorizations. Aliyun Coding Plan queries the dashboard subscription-instance API; accounts without a package show "No subscribed plan", while valid packages show five-hour/weekly/monthly request-count windows, reset times, and package expiry. Quota Radar renders those remaining/total counts with the same model used for XFYun Spark and Tencent Cloud.

Some providers have both a business API key and quota-monitoring authorization. In that case, the business API key is for management and copying only. It does not create a separate quota-monitoring row or duplicate diagnostic row; quota, health, and HTTP status come from the paired web login authorization. This lets users manage copyable API keys in one place without exposing dashboard cookies as API keys.

The main `Quota Overview`, `Credentials`, and `Diagnostics` surfaces show only providers with saved credentials; hidden extension stubs and unconfigured providers do not appear as empty placeholders. Multi-window subscription quota appears once: the credential row shows credential identity, key quota, and status, while five-hour/weekly/monthly cycle details live in the expanded detail section.

XFYun Spark Token Plan, Aliyun Token Plan, and Tencent Cloud Token Plan now have confirmed dashboard/API entry points, but the current accounts lack non-empty package or real-key samples; Volcengine Token Plan still has no confirmed stable usage endpoint. These Token Plan integrations remain hidden extension stubs for now: provider cases, capability metadata, default credential names, and future parser hooks remain in code, but they are not shown in the UI, imported from `.env`, or refreshed until non-empty quota fields are confirmed.

## Coding Plan Measurement

Coding plans should show numeric request-count windows, not only a health state. The shared model is:

- XFYun Spark Coding Plan: `rp5hLimit/rp5hUsage`, `rpwLimit/rpwUsage`, and `packageLimit/packageUsage/packageLeft` map to 5-hour, weekly, and monthly request counts.
- Tencent Cloud Coding Plan: `DescribePkg` `UsageDetail.PerFiveHour/PerWeek/PerMonth` returns `Used/Total/UsagePercent` for 5-hour, weekly, and monthly request counts.
- Aliyun Coding Plan: official docs describe it as fixed monthly fee with monthly request quota. The current account has no package, so only subscription state is confirmed. Code now has a conservative parser for 5-hour, weekly, and monthly `used/total/left` fields; if fields are absent, it does not invent a percentage and shows quota unknown.

## Token Plan Measurement

Token plans must not be assumed to use the same unit as coding plans. The provider response decides whether the unit is tokens, credits, counts, or time.

- Tencent Cloud Token Plan: official `DescribeTokenPlanApiKey` parser is retained and can parse `Balance.ExclusiveQuota/ExclusiveRemain/SharedQuota/SharedRemain`, but no real user key sample is available yet, so it stays hidden.
- XFYun Spark Token Plan: dashboard quota returns `remainingCount/totalCount` plus seat type, which looks like seat/count quota. It stays hidden until a non-empty sample is confirmed.
- Aliyun Token Plan: dashboard subscription list is confirmed and expected to be credits-based, but no non-empty package sample is available yet.
- Volcengine Token Plan: no independent stable usage endpoint or unit is confirmed, so it stays hidden.

## Quota And Plan-End Verification

The following conclusions come from real browser login-state checks, local QuotaService redacted checks, and user-provided/source-confirmed endpoint samples through 2026-06-09. `resetAt` means the current quota-window reset time; `planEndsAt` means the package/subscription end time.

| Provider | Quota query | resetAt | planEndsAt | Verified fields or conclusion |
| --- | --- | --- | --- | --- |
| Tavily | Yes | Yes, computed as day 1 of next month | No | `GET /usage` returns `key.usage`, `key.limit`, `account.plan_usage`, and `account.plan_limit`; the endpoint does not return explicit reset/end fields, and day-1 reset comes from the official free-quota rule. |
| Brave Search | Yes, but consumes one search | Yes | No | Search response headers return `x-ratelimit-limit`, `x-ratelimit-remaining`, `x-ratelimit-reset`, and `x-ratelimit-policy`; no package end field observed. |
| SerpAPI | Yes | Yes, computed as day 1 of next month in UTC | No | `GET /account.json` returns `searches_per_month`, `this_month_usage`, `plan_searches_left`, `total_searches_left`, and `extra_credits`; the endpoint does not return explicit reset/end fields. |
| Serper | Yes | No | No | `GET /account` returns `balance` and `rateLimit`; no reset/end fields observed. |
| Exa | Usage cost when management credentials are configured | No | No | Team Management usage API returns billing usage; plain search keys cannot query usage and are shown as requiring an API key configuration for usage checks. |
| Bocha | Yes | No | No | Balance API returns `data.remaining` and is displayed as CNY balance; no reset/end fields observed. |
| AnySearch | Local unlimited policy | No fixed cycle | No | Currently free; no remote quota endpoint is called. |
| Querit | Usage readable, limit unknown | No | No | `/api/v1/user/account` returns `current_plan.free_usage_month`, `paid_usage_month`, `enterprise_usage_month`, `coupon_quota`, and `coupon_used`; no plan limit, reset time, or end-date field observed on the current account. |
| WeChat Search | Yes | No | No | Balance API returns `remain_money` and `request_time`, displayed as CNY balance; no reset/end fields observed. |
| Claude API Usage | Not wired | Pending | Pending | API keys are hidden from the main UI/import flow for now; organization usage requires an Admin permission model and is not connected to personal Claude subscription windows. |
| Claude Subscription | Yes | Yes | Yes | `/api/organizations` discovers the current organization; `/api/organizations/{org_uuid}/usage` returns `five_hour` and `seven_day` `utilization` plus `resets_at`, which Quota Radar converts into remaining percentages and reset times; `/api/organizations/{org_uuid}/subscription_details` `next_charge_at` or `next_charge_date` is stored as the subscription-cycle end date. Model-specific windows are not shown yet, and Anthropic API / prepaid credits remain separate from Claude Subscription. |
| Codex API Usage | Not wired | Pending | Pending | OpenAI API keys are hidden from the main UI/import flow for now; platform usage/costs differ from ChatGPT/Codex subscription windows, so refresh is not wired. |
| Codex Subscription | Yes | Yes | Yes | The Codex Cloud page calls `/backend-api/wham/usage`, which returns `rate_limit.primary_window` for the five-hour window, `secondary_window` for the weekly window, `additional_rate_limits[]` for model-specific windows, and `reset_at`; this endpoint requires a ChatGPT session access token from `/api/auth/session` and a Bearer token request. Plan expiry uses `/api/auth/session` `account.id` with `/backend-api/subscriptions?account_id=...` and stores `active_until` in `planEndsAt`; using the `wham/usage` `account_id` returns 500. No monthly window was observed in the current response. |
| Kimi | Yes | Yes | When exposed | Kimi Code web authorization can call `kimi.gateway.billing.v1.BillingService/GetUsages` for `FEATURE_CODING` five-hour and weekly quota, remaining counts, and reset times; `MembershipService/GetSubscription` exposes subscription state, balances, `next_billing_time`, or balance `expire_time`. No independent monthly rate-limit window is confirmed; monthly balance is shown with `amount/amount_left`, percentage-only when only `amountUsedRatio` exists, otherwise Quota Radar shows confirmed windows or quota unknown. The official Kimi Code OAuth `/coding/v1/usages` path returns a compatible `usage/limits` shape but requires a separate OAuth credential, so it remains a follow-up for unified authentication. |
| DeepSeek | Yes | No | No | `/user/balance` returns `is_available` plus balance structures, displayed as CNY balance; no reset/end fields observed. |
| XFYun Spark Coding Plan | Yes | No | Yes | `/api/v1/gpt-finetune/coding-plan/list` returns three-window request-count `codingPlanUsageDTO`; `expiresAt` is the package end time. |
| XFYun Spark Token Plan | Seat quota readable, not wired yet | Needs a purchased-seat sample | Needs a purchased-seat sample | The Token Plan page calls `/api/v1/gpt-finetune/token-plan/seats?page=0&size=6` and `/api/v1/gpt-finetune/token-plan/quota`; this account has `seats.total=0`, while `quotas[]` returns `seatTypeName`, `remainingCount`, and `totalCount`. |
| Volcengine Coding Plan | Yes | Yes | Yes | The real page calls `GetCodingPlanUsage` for `QuotaUsage[].Percent` and `ResetTimestamp`; `ListSubscribeTrade` returns `ResourceType="CodingPlan"`, `Status`, `StartTime`, `EndTime`, `Period`, and `EnableAutoRenew`. |
| Volcengine Token Plan | Not wired | Pending | Pending | Resource-package / Token Plan entry points did not expose an independently stable usage endpoint, so it remains hidden. |
| OpenCode Go | Yes | Yes | No | Saved `_server` credentials return rolling/weekly/monthly percentages and window resets; no package end field observed. |
| Aliyun Coding Plan | When subscribed | When subscribed | When subscribed | The real page calls `BroadScopeAspnGateway` / `codingPlan.queryCodingPlanInstanceInfoV2`; empty `codingPlanInstanceInfos` is shown as no subscription. When subscribed, Quota Radar reads `codingPlanQuotaInfo.per5Hour/perWeek/perBillMonth` used/total/reset fields, and `instanceEndTime` is the package end time. |
| Aliyun Token Plan | Subscription list readable, not wired yet | Needs a purchased-plan sample | Needs a purchased-plan sample | The Token Plan page calls `bailian-commerce.tokenPlan.queryTokenPlanInstanceInfo`; this account returns `supportModels` and an empty `tokenPlanInstanceInfos`, so non-empty credits quota/reset/end fields still need a sample. |
| Tencent Cloud Coding Plan | When subscribed | When subscribed | When subscribed | The real page calls `cgi/capi?cmd=DescribePkg&serviceType=hunyuan`; this account returns an empty `PkgList`; when subscribed, `UsageDetail.*.Used/Total` are request counts, `UsageDetail.*.EndTime` is the window reset, and `PkgList[].EndTime` is the package end time. |
| Tencent Cloud Token Plan | Hidden extension stub; parser retained pending real-key validation | Pending | Pending | Code can parse `DescribeTokenPlanApiKey` `Balance.*Quota/*Remain`, but there is no real user key sample yet. The browser page calls `cgi/capi?cmd=ListUserTokenPlans&serviceType=hunyuan`, and this account currently has an empty `UserTokenPlanList`, so non-empty lifecycle fields need a sample. |

Never commit real API keys, cookies, or Tencent Cloud secrets to source, tests, or docs.
