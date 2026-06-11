# Provider Capability Matrix

<p align="right">
  <strong>简体中文</strong> |
  <a href="./provider-capabilities.en.md">English</a>
</p>

这张表是新增 provider 的准入入口：先明确凭据类型、额度来源、重置周期和是否会消耗真实额度，再决定是否接入 UI、自动刷新和连通性测试。

当前 Swift macOS App 仍是稳定发布线；`apps/desktop-tauri` 中的 Tauri 版本是跨平台预览实现，也必须沿用这张矩阵的 provider 准入、凭据展示和安全边界。所有 Tauri 测试、截图和文档示例都只能使用脱敏或 fixture 数据，不能保存真实 API Key、Bearer token 或 Cookie。

## AI Search

| Provider | Category | 凭据类型 | 额度来源 | 重置/窗口 | 检查消耗额度 | 诊断端点 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Tavily | AI Search | API 密钥 | 官方 Usage API | 每月 1 日 | 否 | `GET /usage` | 免费额度按月重置，不累积。 |
| Brave Search | AI Search | API 密钥 | 搜索响应 Header | 未公开 | 是 | `GET /res/v1/web/search` | 每次检查会产生真实搜索请求。 |
| SerpAPI | AI Search | API 密钥 | Account API | 月度 | 否 | `GET /account.json` | 返回搜索余额。 |
| Serper | AI Search | API 密钥 | Account API | 未公开 | 否 | `GET /account` | 返回账户余额和 `rateLimit`；不暴露 reset/end 字段。 |
| Exa | AI Search | API 密钥 | Admin API | 未公开 | 否 | Team Management usage API | 普通 search key 不能查用量，需要 service key + api key id。 |
| Bocha | AI Search | API 密钥 | 官方余额 API | 无固定周期 | 否 | Remaining fund API | 以人民币余额显示。 |
| AnySearch | AI Search | API 密钥 | 本地规则 | 无固定周期 | 否 | 无 | 当前免费，按无限额度显示。 |
| Querit | AI Search | 网页登录授权；可选 API Key 仅用于保存/复制 | 控制台 Account API | 未公开 | 否 | `/api/v1/user/account` | 可读月度已用量；当前账号接口未暴露套餐上限、重置时间或结束日期。`QUERIT_API_KEY` 可保存和复制，但不能查 dashboard 用量。 |
| 微信搜索 | AI Search | API 密钥 | 官方余额 API | 无固定周期 | 否 | Remaining money API | 以人民币余额显示。 |

## LLM / Plans

| Provider | Category | 凭据类型 | 额度来源 | 重置/窗口 | 检查消耗额度 | 诊断端点 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Claude API Usage | LLM | API Key | 官方 Admin API | 未公开 | 否 | Admin usage report | 暂不在主界面/导入中展示；组织级用量报表需要 Anthropic Admin 权限，不等同于 Claude 订阅 5 小时/周/月额度。 |
| Claude Subscription | LLM | 网页登录授权；可选 `ANTHROPIC_API_KEY` 仅用于保存/复制 | `claude.ai` Organization Usage API | 5 小时 / 周；未见月窗口 | 否 | `/api/organizations` + `/api/organizations/{org_uuid}/usage` + `/api/organizations/{org_uuid}/subscription_details` | 已接入订阅额度统计：先发现 active organization，再解析 `five_hour`、`seven_day` 的 `utilization` 和 `resets_at`，并用 `next_charge_at` 或 `next_charge_date` 作为订阅周期结束日期。模型专属窗口暂不在紧凑 UI 中展示；API Key 不参与订阅额度查询。 |
| Codex API Usage | LLM | API Key | 官方 Admin API | 未公开 | 否 | OpenAI usage/costs API | 暂不在主界面/导入中展示；平台 usage/costs API 通常需要 Admin API Key，不等同于 ChatGPT/Codex 订阅窗口额度。 |
| Codex Subscription | LLM | 网页登录授权；可选 `OPENAI_API_KEY` 仅用于保存/复制 | ChatGPT Codex Cloud Usage API | 5 小时 / 周；未见月窗口 | 否 | `/api/auth/session` + `/backend-api/wham/usage` + `/backend-api/subscriptions?account_id=...` | 已接入 ChatGPT session access token + `/backend-api/wham/usage` 刷新，显示 5 小时/周窗口和 reset；使用 `/api/auth/session` 的 `account.id` 查询订阅生命周期并写入套餐到期日期。API Key 不参与订阅额度查询。 |
| Kimi | LLM | 网页登录授权 / Bearer access token；可选 `KIMI_API_KEY` 仅用于保存/复制 | Kimi BillingService + MembershipService | 5 小时 / 周；未确认独立月限流窗口 | 否 | `BillingService/GetUsages` + `GetSubscription` | `BillingService/GetUsages` 传入 `scope:["FEATURE_CODING"]` 后返回 Kimi Code 周额度 `detail` 和 5 小时 `limits[]`，包含 `remaining/limit/resetTime`；`GetSubscription` 返回订阅余额、`next_billing_time` 或余额 `expire_time`。只有当订阅余额字段暴露 `amount/amount_left` 或 `amountUsedRatio` 时才显示月度余额，不凭空生成月额度。API Key 不参与订阅额度查询。 |
| DeepSeek | LLM | API Key | 官方余额 API | 无固定周期 | 否 | `/user/balance` | 以人民币余额显示。 |
| 讯飞星火 coding plan | LLM | 网页登录授权 | 控制台 Coding Plan API | 5 小时/周/月窗口；reset 未公开 | 否 | `/api/v1/gpt-finetune/coding-plan/list` | 按请求次数统计，展示 5 小时、周、月三个周期的剩余百分比和剩余次数/总次数。 |
| 讯飞星火 Token plan | LLM | 隐藏扩展桩 | 控制台 Token Plan 座席/额度接口已确认，未接入 UI | 待购买样本确认 | 否 | `/api/v1/gpt-finetune/token-plan/seats` + `/api/v1/gpt-finetune/token-plan/quota` | 当前账号无座席；接口返回 seat type 的 `remainingCount/totalCount`，计量像座席次数额度，不是业务 API key 的 token 消耗。确认非空套餐字段前不展示、不导入、不刷新。 |
| 火山引擎 coding plan | LLM | 网页登录授权 | 控制台 Coding Plan API | 5 小时/周/月窗口；返回 reset | 否 | `GetCodingPlanUsage` + `ListSubscribeTrade` | `GetCodingPlanUsage` 展示 5 小时、周、月三个周期的剩余百分比和 reset；`ListSubscribeTrade` 返回套餐开始/结束时间。直接请求需要登录 Cookie、CSRF 和项目名。 |
| 火山引擎 Token plan | LLM | 隐藏扩展桩 | 暂未确认 | 暂未确认 | 否 | 待确认 | 已检查资源包/Token Plan 相关入口，未确认独立、稳定、可复放的用量接口；确认前不展示、不导入、不刷新。 |
| OpenCode Go | LLM | 网页登录授权；可选 `OPENCODE_GO_API_KEY` 仅用于保存/复制 | 控制台 Server Function | 5 小时/周/月窗口；返回 reset | 否 | `/_server` | 需要 cookie、workspace id、server id 和 server instance；API Key 不参与订阅额度查询。 |
| 阿里云 coding plan | LLM | 网页登录授权 | 控制台 Coding Plan 订阅实例 API | 5 小时/周/月窗口；返回 reset 和套餐到期 | 否 | `BroadScopeAspnGateway` / `codingPlan.queryCodingPlanInstanceInfoV2` | Coding Plan 官方定位为固定月费、月度请求额度；`codingPlanInstanceInfos` 为空时显示未发现订阅套餐，有有效实例时解析 `codingPlanQuotaInfo` 的三周期请求次数、三周期 reset 和 `instanceEndTime`。业务调用 key 可保存但不用于额度监控。 |
| 阿里云 Token plan | LLM | 隐藏扩展桩 | 控制台 Token Plan 订阅列表接口已确认，未接入 UI | 待购买样本确认 | 否 | `BroadScopeAspnGateway` / `bailian-commerce.tokenPlan.queryTokenPlanInstanceInfo` | 当前账号 `tokenPlanInstanceInfos` 为空；Token Plan 预期按积分/credits 类额度统计，但非空套餐的可用字段、reset 和 end 仍需真实样本确认。 |
| 腾讯云 coding plan | LLM | 网页登录授权 | 控制台 Coding Plan API | 5 小时/周/月窗口；有套餐时返回 reset | 否 | `cgi/capi?cmd=DescribePkg&serviceType=hunyuan` | 按请求次数统计，展示 5 小时、周、月三个周期的剩余百分比和剩余次数/总次数；未订阅时显示“未发现订阅套餐”。业务调用 key 可保存但不用于额度监控。 |
| 腾讯云 Token plan | LLM | 隐藏扩展桩 | 官方 TokenHub API parser 已保留；控制台订阅列表 API 已确认 | 待真实 key/非空套餐样本确认 | 否 | `DescribeTokenPlanApiKey`；控制台页面为 `cgi/capi?cmd=ListUserTokenPlans&serviceType=hunyuan` | 代码保留 `Balance.*Quota/*Remain` 的 token 额度解析，但当前没有真实用户 key 可验证；确认前不展示、不导入、不刷新。 |

## 凭据格式

普通 API Key 直接填写 key 字符串。

网页登录授权类服务商可以在应用内重新认证，也可以在配置页粘贴从控制台复制的 cURL 自动解析。Quota Radar 只保存读取额度接口所需的本地登录授权信息；如果服务商接口要求，其中会包含请求 Cookie header：

```env
VOLCENGINE_CODING_PLAN_COOKIE='{"cookie":"<cookie-header-value>","csrfToken":"<csrf-token>","projectName":"default"}'
OPENCODE_GO_COOKIE='{"cookie":"<cookie-header-value>","workspaceID":"wrk_example","serverID":"server-example","serverInstance":"server-fn:11"}'
KIMI_SUBSCRIPTION_SESSION='{"accessToken":"<redacted-access-token>","cookieHeader":"<redacted-kimi-auth-cookie-header>","deviceID":"<x-msh-device-id>","sessionID":"<x-msh-session-id>"}'
```

阿里云 Coding Plan 和腾讯云 Coding Plan 的业务调用 API Key 可以保存和展示，但额度监控使用网页登录授权。阿里云 Coding Plan 通过控制台订阅实例接口查询套餐；如果账号没有套餐会显示“未发现订阅套餐”，有有效套餐时会显示 5 小时/周/月请求次数窗口、窗口重置时间和套餐到期时间，按讯飞星火和腾讯云同口径显示剩余次数/总次数。

有些 provider 同时支持“业务 API Key”和“额度监控授权”。这时业务 API Key 只承担管理和复制用途，不单独生成额度监控行，也不会重复生成诊断行；额度、健康状态和 HTTP 状态都来自配对的网页登录授权。这样用户可以在一个工具里管理可复制的 API Key，同时避免把 dashboard Cookie 当成 API Key 暴露出来。

主界面的 `额度监控`、`配置凭据` 和 `诊断` 只展示已经保存过凭据的 provider；隐藏扩展桩和未配置 provider 不显示空占位。多周期订阅额度在凭据行只展示一次：主行显示凭据身份、关键额度和状态，5 小时/周/月等周期细节放在展开明细里。

讯飞星火 Token plan、阿里云 Token plan 和腾讯云 Token plan 已确认部分控制台/API 入口，但当前缺少非空套餐或真实 key 样本；火山引擎 Token plan 尚未确认稳定用量接口。这些 Token plan 当前仍保持隐藏扩展桩：代码中保留 provider、capability、默认凭据名和后续 parser 接口，但在非空套餐额度字段和真实凭据样本确认前不会展示在 UI、不会从 `.env` 自动导入，也不会参与刷新。

## Coding plan 计量口径

Coding plan 优先按“请求次数窗口”展示，而不是只展示健康状态。已确认或已预留的统一口径是：

- 讯飞星火 coding plan：接口返回 `rp5hLimit/rp5hUsage`、`rpwLimit/rpwUsage`、`packageLimit/packageUsage/packageLeft`，分别对应 5 小时、周、月请求次数。
- 腾讯云 coding plan：`DescribePkg` 的 `UsageDetail.PerFiveHour/PerWeek/PerMonth` 返回 `Used/Total/UsagePercent`，分别对应 5 小时、周、月请求次数。
- 阿里云 coding plan：官方文档描述为固定月费、月度请求额度；当前账号无套餐，真实接口只确认订阅状态。代码已预留解析 5 小时、周、月的 `used/total/left` 字段，字段出现时按同样的剩余次数/总次数展示；字段不存在时不造百分比，显示“额度未知”。

## Token plan 计量口径

Token plan 不能默认等同于 coding plan，也不能默认都是 token 数量，必须先看服务商接口返回的单位。

- 腾讯云 Token plan：代码已保留官方 `DescribeTokenPlanApiKey` parser，可解析 `Balance.ExclusiveQuota/ExclusiveRemain/SharedQuota/SharedRemain`，但当前没有真实用户 key 可验证，继续隐藏。
- 讯飞星火 Token plan：控制台 quota 接口返回 `remainingCount/totalCount` 和 seat type，更像座席/次数额度；待非空样本确认后再接入 UI。
- 阿里云 Token plan：控制台订阅列表已确认，预期为积分/credits 类额度，但当前账号没有非空套餐，具体字段和周期待确认。
- 火山引擎 Token plan：未确认独立稳定的用量接口和计量单位，继续隐藏。

## 额度与结束日期字段验证

以下结论来自截至 2026-06-09 的真实浏览器登录态、本地 QuotaService 脱敏验证和用户提供/源码确认的接口样本。`resetAt` 指当前额度窗口重置时间，`planEndsAt` 指套餐/订阅结束时间。

| Provider | 额度可查 | resetAt | planEndsAt | 已验证字段或结论 |
| --- | --- | --- | --- | --- |
| Tavily | 是 | 是，代码按每月 1 日计算 | 否 | `GET /usage` 返回 `key.usage`、`key.limit`、`account.plan_usage`、`account.plan_limit`；接口未返回显式 reset/end，月初重置来自官方免费额度规则。 |
| Brave Search | 是，但会消耗一次搜索 | 是 | 否 | 搜索响应 header 返回 `x-ratelimit-limit`、`x-ratelimit-remaining`、`x-ratelimit-reset`、`x-ratelimit-policy`；未见套餐结束字段。 |
| SerpAPI | 是 | 是，代码按下月 1 日 UTC 计算 | 否 | `GET /account.json` 返回 `searches_per_month`、`this_month_usage`、`plan_searches_left`、`total_searches_left`、`extra_credits`；接口未返回显式 reset/end。 |
| Serper | 是 | 否 | 否 | `GET /account` 返回 `balance`、`rateLimit`；未见 reset/end 字段。 |
| Exa | 有管理凭据时可查已用成本 | 否 | 否 | Team Management usage API 返回 billing usage；普通 search key 不能查询 usage，当前配置若只有 search key 会显示需要 API 密钥。 |
| Bocha | 是 | 否 | 否 | 余额 API 返回 `data.remaining`，按人民币余额展示；未见 reset/end 字段。 |
| AnySearch | 本地无限额度规则 | 无固定周期 | 否 | 当前免费，不请求远端额度接口。 |
| Querit | 已用量可查，上限未知 | 否 | 否 | `/api/v1/user/account` 返回 `current_plan.free_usage_month`、`paid_usage_month`、`enterprise_usage_month`、`coupon_quota`、`coupon_used`；当前账号未见套餐上限、重置时间或结束日期字段。 |
| 微信搜索 | 是 | 否 | 否 | 余额 API 返回 `remain_money`、`request_time`，按人民币余额展示；未见 reset/end 字段。 |
| Claude API Usage | 未接入 | 待确认 | 待确认 | 暂不展示/导入 API key；组织 usage 需要 Admin 权限模型，未和个人 Claude 订阅额度打通。 |
| Claude Subscription | 是 | 是 | 是 | `/api/organizations` 发现当前组织，`/api/organizations/{org_uuid}/usage` 返回 `five_hour`、`seven_day` 的 `utilization` 和 `resets_at`，Quota Radar 转成剩余百分比和窗口重置时间；`/api/organizations/{org_uuid}/subscription_details` 的 `next_charge_at` 或 `next_charge_date` 作为订阅周期结束日期。暂不展示模型专属窗口，也不把 Anthropic API / prepaid credits 混入 Claude Subscription。 |
| Codex API Usage | 未接入 | 待确认 | 待确认 | 暂不展示/导入 OpenAI API key；平台 usage/costs 与 ChatGPT/Codex 订阅窗口不同，当前未接入刷新。 |
| Codex Subscription | 是 | 是 | 是 | Codex Cloud 页面真实请求 `/backend-api/wham/usage`，返回 `rate_limit.primary_window` 5 小时窗口、`secondary_window` 周窗口、`additional_rate_limits[]` 模型专属窗口及 `reset_at`；该接口需要先从 `/api/auth/session` 取得 ChatGPT session access token，并用 Bearer token 调用。套餐到期需要使用 `/api/auth/session` 的 `account.id` 调 `/backend-api/subscriptions?account_id=...`，读取 `active_until` 写入 `planEndsAt`；使用 `wham/usage` 的 `account_id` 会返回 500。当前响应未见月窗口。 |
| Kimi | 是 | 是 | 有字段时可查 | Kimi Code 网页授权可调用 `kimi.gateway.billing.v1.BillingService/GetUsages` 读取 `FEATURE_CODING` 的 5 小时和周额度、剩余次数和 reset；`MembershipService/GetSubscription` 暴露订阅状态、balances、`next_billing_time` 或 balance `expire_time`。当前未确认独立月限流窗口；订阅余额有 `amount/amount_left` 时按月度余额展示，只有 `amountUsedRatio` 时按百分比展示，否则只显示已确认窗口或“额度未知”。官方 Kimi Code OAuth `/coding/v1/usages` 返回同类 `usage/limits` 结构，但需要独立 OAuth 凭据，暂列后续统一认证改造。 |
| DeepSeek | 是 | 否 | 否 | `/user/balance` 返回 `is_available` 和余额结构，按人民币余额展示；未见 reset/end 字段。 |
| 讯飞星火 coding plan | 是 | 否 | 是 | `/api/v1/gpt-finetune/coding-plan/list` 返回 `codingPlanUsageDTO` 三周期请求次数额度，`expiresAt` 是套餐结束时间。 |
| 讯飞星火 Token plan | 座席额度可查，待接入代码 | 待购买样本确认 | 待购买样本确认 | Token Plan 页面真实请求 `/api/v1/gpt-finetune/token-plan/seats?page=0&size=6` 和 `/api/v1/gpt-finetune/token-plan/quota`；当前账号 `seats.total=0`，`quotas[]` 返回 `seatTypeName`、`remainingCount`、`totalCount`。 |
| 火山引擎 coding plan | 是 | 是 | 是 | 页面真实请求 `GetCodingPlanUsage` 返回 `QuotaUsage[].Percent` 和 `ResetTimestamp`；`ListSubscribeTrade` 返回 `ResourceType="CodingPlan"`、`Status`、`StartTime`、`EndTime`、`Period`、`EnableAutoRenew`。 |
| 火山引擎 Token plan | 未接入 | 待确认 | 待确认 | 资源包/Token Plan 相关入口未确认到独立稳定的用量接口，继续隐藏。 |
| OpenCode Go | 是 | 是 | 否 | 已保存 `_server` 凭据可返回 rolling/weekly/monthly 百分比与窗口 reset；未见套餐结束字段。 |
| 阿里云 coding plan | 有套餐时可查 | 有套餐时可查 | 有套餐时可查 | 页面真实请求 `BroadScopeAspnGateway` / `codingPlan.queryCodingPlanInstanceInfoV2`；`codingPlanInstanceInfos` 为空时显示未发现订阅套餐。有套餐时读取 `codingPlanQuotaInfo.per5Hour/perWeek/perBillMonth` 的 used/total/reset 字段，`instanceEndTime` 是套餐结束时间。 |
| 阿里云 Token plan | 订阅列表可查，待接入代码 | 待购买样本确认 | 待购买样本确认 | Token Plan 页面真实请求 `bailian-commerce.tokenPlan.queryTokenPlanInstanceInfo`，当前账号返回 `supportModels` 和空 `tokenPlanInstanceInfos`；非空套餐的积分/credits 额度、reset、end 字段仍需样本确认。 |
| 腾讯云 coding plan | 有套餐时可查 | 有套餐时可查 | 有套餐时可查 | 页面真实请求 `cgi/capi?cmd=DescribePkg&serviceType=hunyuan`；当前账号 `PkgList` 为空，有套餐时 `UsageDetail.*.Used/Total` 是请求次数，`UsageDetail.*.EndTime` 是窗口重置，`PkgList[].EndTime` 是套餐结束时间。 |
| 腾讯云 Token plan | 隐藏扩展桩；parser 保留，待真实 key 验证 | 待确认 | 待确认 | 代码可解析 `DescribeTokenPlanApiKey` 的 `Balance.*Quota/*Remain`，但当前没有真实用户 key 可验证；浏览器页面真实请求 `cgi/capi?cmd=ListUserTokenPlans&serviceType=hunyuan`，当前账号 `UserTokenPlanList` 为空，非空套餐生命周期字段待样本确认。 |

不要把真实 API Key、Cookie 或腾讯云 Secret 写入源码、测试或文档。
