# Provider Capability Matrix

<p align="right">
  <strong>简体中文</strong> |
  <a href="./providers.md">English</a>
</p>

这张表是新增 provider 的准入入口：先明确凭据类型、额度来源、重置周期和是否会消耗真实额度，再决定是否接入 UI、自动刷新和连通性测试。

## 校准状态

最近一次本机脱敏校准：2026-06-23 13:06 CST。校准只读取 Quota Radar 的本机 metadata、quota history 和当前刷新结果，不记录真实 API Key、Cookie 或个人额度数值。

| Provider | 校准状态 | 最近验证 | 证据链 | 当前口径 | 降级口径 |
| --- | --- | --- | --- | --- | --- |
| DeepSeek | 已实测 | 2026-06-21 16:53 CST | 官方 `/user/balance` 返回 HTTP 200，metadata 和最近快照均为余额型结果。 | 只展示人民币余额；无 reset/end。余额增加按充值/恢复处理，不参与消耗趋势。顶层 `limit = remaining` 是余额型展示归一化，不代表固定套餐上限。 | 如果余额字段变化，保留凭据可操作状态，并提示需要重新校准，不显示泛化失败。 |
| 讯飞星火 coding plan | 已实测 | 2026-06-23 13:06 CST | `/api/v1/gpt-finetune/coding-plan/list` 返回套餐名、`validFrom/expiresAt` 和三周期 `usage` 字段；live acceptance 通过，保留 quota、reset 和套餐到期字段。 | 官网字段是已用次数；解析层统一换算为剩余次数/总次数。5 小时/周 reset 由 `validFrom` 推断，套餐期窗口使用 `expiresAt`。 | 如果套餐字段变化，按“需要重新校准”拒绝异常响应，并保留历史快照用于趋势上下文。 |
| 火山引擎 coding plan | 已实测 | 2026-06-23 13:06 CST | `GetCodingPlanUsage` 返回三周期百分比和 reset；`ListSubscribeTrade` 返回套餐名和到期时间；live acceptance 通过，保留 quota、reset 和套餐到期字段。 | 当前接口只确认百分比和 reset，不确认具体剩余次数/总次数。套餐名和到期时间属于低频 metadata：每天最多刷新一次，手动刷新会绕过冷却立即更新。 | 如果 usage 或订阅字段变化，显示需要重新校准，不自行推断剩余次数。 |
| Claude Subscription | 已实测 | 2026-06-23 13:06 CST | `/api/organizations`、`/usage`、`/subscription_details` 当前返回套餐名、5 小时/周窗口、reset 和订阅周期结束时间；live acceptance 通过，保留两个 quota window。 | 不展示月窗口；不混入 Anthropic API/prepaid credits。organization 或 subscription details 的 tier 字段暴露倍率时，Max 显示为 `Max 5x` / `Max 20x`。 | 如果 organization 或 usage 字段变化，提示重新校准，而不是直接判定登录失效。 |
| Anthropic Credits | 已实测 | 2026-06-23 15:56 CST | 浏览器实测发现 `/api/organizations/{org_uuid}/prepaid/credits` 返回 `amount` 等余额字段；通过已有 Claude Subscription 网页登录授权脱敏复放返回 HTTP 200，并成功解析余额；直接 Anthropic Credits live acceptance 已通过并确认有 quota 证据。 | 以原始 credits 余额展示 API / prepaid credits，不展示订阅百分比或 reset window。使用 Claude 网页登录授权，并和 Claude Subscription 分开。 | 如果字段变化，提示需要重新校准，不影响 Claude Subscription。没有直接 Anthropic Credits 凭据行时，刷新会从已保存 Claude 授权派生独立监控行。 |
| Codex Subscription | 已实测 | 2026-06-29 CST | `/api/auth/session`、`/backend-api/wham/usage`、`/backend-api/wham/rate-limit-reset-credits`、`/backend-api/subscriptions?account_id=...`、`/backend-api/accounts/check/v4-2023-04-27` 当前返回套餐层级、5 小时/周窗口、reset、订阅周期结束时间、重置次数和单次重置有效期 metadata。 | 不展示月窗口；使用 ChatGPT session `account.id` 查询生命周期，lifecycle 字段、`accounts/check`、RevenueCat offering IDs 和可读字符串都可区分 `Pro 5x` / `Pro 20x`。`/backend-api/wham/usage` 仍然是额度窗口来源，`/backend-api/wham/rate-limit-reset-credits` 补充可用重置次数和未使用重置次数的最早过期时间。 | 如果生命周期字段变化，将 usage 解析和生命周期解析分开处理，并对生命周期部分提示重新校准。如果重置次数详情字段变化，保留额度窗口，并在可用时回退到 `/wham/usage` 返回的次数。 |
| Tavily | 已实测 | 2026-06-21 16:53 CST | 官方 `/usage` 当前返回 key/account 用量，多个 key 的快照独立记录。 | 月初 reset 由产品规则计算；耗尽 key 稳定显示 0，不视为 schema 异常。 | 稳定 0 额度继续作为额度状态；HTTP 或字段异常才进入可行动诊断。 |
| Querit | 观察中 | 2026-06-23 13:06 CST | live acceptance 通过，但账号接口仍然只暴露 usage-only 字段，没有 quota limit。 | 显示可用、额度未知；不自行推算剩余额度或 reset。 | 如果后续出现 limit 字段，先补脱敏 fixture，再改变展示口径。 |
| Kimi Subscription | 观察中 | 2026-06-23 13:06 CST | live acceptance 通过，保留套餐到期 metadata 和可用额度状态；本次保存账号未暴露 reset window。 | 只展示已确认窗口或额度未知；不自行生成月限流窗口。 | 字段漂移时提示重新校准，不直接判定凭据失效。 |
| OpenCode Go | 观察中 | 2026-06-23 13:06 CST | live acceptance 通过，保留 quota 和 reset windows；未观察到 package end 字段。 | 只展示已观察到的 rolling/weekly/monthly windows。 | 字段漂移时提示重新校准，不直接判定凭据失效。 |

## AI Search

| Provider | Category | 凭据类型 | 额度来源 | 重置/窗口 | 检查消耗额度 | 诊断端点 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Tavily | AI Search | API 密钥 | 官方 Usage API | 每月 1 日 | 否 | `GET /usage` | 免费额度按月重置，不累积。 |
| Brave Search | AI Search | API 密钥 | 搜索响应 Header | 未公开 | 是 | `GET /res/v1/web/search` | 每次检查会产生真实搜索请求。 |
| SerpAPI | AI Search | API 密钥 | Account API | 月度 | 否 | `GET /account.json` | 返回搜索余额。 |
| Serper | AI Search | API 密钥 | Account API | 未公开 | 否 | `GET /account` | 返回账户余额和 `rateLimit`；不暴露 reset/end 字段。 |
| Exa | AI Search | API 密钥 | Admin API | 未公开 | 否 | Team Management usage API | 普通 search key 不能查询额度证据；Team Management 凭据只能读取账单用量证据。usage-only 原始字段只作为解析证据；主界面仍显示“可用 · 额度未知”，直到接口暴露剩余额度或套餐上限。 |
| Bocha | AI Search | API 密钥 | 官方余额 API | 无固定周期 | 否 | Remaining fund API | 以人民币余额显示。 |
| AnySearch | AI Search | API 密钥 | 本地规则 | 无固定周期 | 否 | 无 | 当前免费，按无限额度显示。 |
| Querit | AI Search | 网页登录授权；可选 API Key 仅用于保存/复制 | 控制台 Account API | 未公开 | 否 | `/api/v1/user/account` | 可读取月度请求使用证据；当前账号接口未暴露套餐上限、重置时间或结束日期。`QUERIT_API_KEY` 可保存和复制，但不能查 dashboard 额度。usage-only 原始字段只作为解析证据；主界面仍显示“可用 · 额度未知”，直到接口暴露剩余额度或套餐上限。 |
| 微信搜索 | AI Search | API 密钥 | 官方余额 API | 无固定周期 | 否 | Remaining money API | 以人民币余额显示。 |

## LLM / Plans

| Provider | Category | 凭据类型 | 额度来源 | 重置/窗口 | 检查消耗额度 | 诊断端点 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Claude API Usage | LLM | API Key | 官方 Admin API | 未公开 | 否 | Admin usage report | 暂不在主界面/导入中展示；组织级用量报表需要 Anthropic Admin 权限，不等同于 Claude 订阅 5 小时/周/月额度。 |
| Claude Subscription | LLM | 网页登录授权；可选 `ANTHROPIC_API_KEY` 仅用于保存/复制 | `claude.ai` Organization Usage API | 5 小时 / 周；未见月窗口 | 否 | `/api/organizations` + `/api/organizations/{org_uuid}/usage` + `/api/organizations/{org_uuid}/subscription_details` | 已接入订阅额度统计：先发现 active organization，再解析 `five_hour`、`seven_day` 的 `utilization` 和 `resets_at`，并用 `next_charge_at` 或 `next_charge_date` 作为订阅周期结束日期。Max 套餐在组织或 subscription details 的 tier 字段暴露倍率时显示 `Max 5x` 或 `Max 20x`；API Key 不参与订阅额度查询。 |
| Anthropic Credits | LLM | 网页登录授权 | `claude.ai` Prepaid Credits API | 未公开 | 否 | `/api/organizations` + `/api/organizations/{org_uuid}/prepaid/credits` | Anthropic API / prepaid credits provider。它先发现 active Claude organization，再把 `amount` 解析为原始 credits 余额；reset/end 列保持为空，不混入 Claude Subscription 的订阅额度窗口。通过已有 Claude Subscription 授权复放已通过，刷新可从该授权派生独立 Anthropic Credits 监控行。 |
| Codex API Usage | LLM | API Key | 官方 Admin API | 未公开 | 否 | OpenAI usage/costs API | 暂不在主界面/导入中展示；平台 usage/costs API 通常需要 Admin API Key，不等同于 ChatGPT/Codex 订阅窗口额度。 |
| Codex Subscription | LLM | 网页登录授权；可选 `OPENAI_API_KEY` 仅用于保存/复制 | ChatGPT Codex Cloud Usage API | 5 小时 / 周；未见月窗口 | 否 | `/api/auth/session` + `/backend-api/wham/usage` + `/backend-api/wham/rate-limit-reset-credits` + `/backend-api/subscriptions?account_id=...` + `/backend-api/accounts/check/v4-2023-04-27` | 已接入 ChatGPT session access token + `/backend-api/wham/usage` 刷新，显示 5 小时/周窗口和 reset；使用 `/api/auth/session` 的 `account.id` 查询订阅生命周期，并从 lifecycle 字段、`accounts/check`、RevenueCat offering IDs 和可读字符串识别 `Pro 5x` / `Pro 20x`。重置次数 metadata 来自 `/backend-api/wham/rate-limit-reset-credits`：Quota Radar 保存可用次数，并在账号级“使用重置”旁显示未使用重置次数的最早过期时间。API Key 不参与订阅额度查询。 |
| Kimi | LLM | 网页登录授权 / Bearer access token；可选 `KIMI_API_KEY` 仅用于保存/复制 | Kimi BillingService + MembershipService | 5 小时 / 周；未确认独立月限流窗口 | 否 | `BillingService/GetUsages` + `GetSubscription` | `BillingService/GetUsages` 传入 `scope:["FEATURE_CODING"]` 后返回 Kimi Code 周额度 `detail` 和 5 小时 `limits[]`，包含 `remaining/limit/resetTime`；`GetSubscription` 返回订阅余额、`next_billing_time` 或余额 `expire_time`。只有当订阅余额字段暴露 `amount/amount_left` 或 `amountUsedRatio` 时才显示月度余额，不凭空生成月额度。API Key 不参与订阅额度查询。 |
| DeepSeek | LLM | API Key | 官方余额 API | 无固定周期 | 否 | `/user/balance` | 以人民币余额显示。 |
| 讯飞星火 coding plan | LLM | 网页登录授权 | 控制台 Coding Plan API | 5 小时/周/套餐期窗口；reset 从 `validFrom/expiresAt` 推断 | 否 | `/api/v1/gpt-finetune/coding-plan/list` | 按请求次数统计，展示 5 小时、周、套餐期三个周期的剩余百分比、剩余次数/总次数和推断重置时间。接口未直接返回 reset 字段。 |
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
KIMI_SUBSCRIPTION_SESSION='{"accessToken":"<bearer-token>","cookie":"kimi-auth=<cookie-token>","deviceID":"<x-msh-device-id>","sessionID":"<x-msh-session-id>"}'
ANTHROPIC_CREDITS_SESSION='{"cookie":"sessionKey=<claude-session-cookie>"}'
```

阿里云 Coding Plan 和腾讯云 Coding Plan 的业务调用 API Key 可以保存和展示，但额度监控使用网页登录授权。阿里云 Coding Plan 通过控制台订阅实例接口查询套餐；如果账号没有套餐会显示“未发现订阅套餐”，有有效套餐时会显示 5 小时/周/月请求次数窗口、窗口重置时间和套餐到期时间，按讯飞星火和腾讯云同口径显示剩余次数/总次数。

有些 provider 同时支持“业务 API Key”和“额度监控授权”。这时业务 API Key 只承担管理和复制用途，不单独生成额度监控行，也不会重复生成诊断行；额度、健康状态和 HTTP 状态都来自配对的网页登录授权。这样用户可以在一个工具里管理可复制的 API Key，同时避免把 dashboard Cookie 当成 API Key 暴露出来。

主界面的 `额度监控`、`配置凭据` 和 `诊断` 只展示已经保存过凭据的 provider；隐藏扩展桩和未配置 provider 不显示空占位。多周期订阅额度在凭据行只展示一次：主行显示凭据身份、关键额度和状态，5 小时/周/月等周期细节放在展开明细里。近期消耗或余额变化只放在它描述的额度下方；展开账号行的 `上次更新` 面板只表达刷新状态，避免把数据新鲜度和额度变化混在一起。

讯飞星火 Token plan、阿里云 Token plan 和腾讯云 Token plan 已确认部分控制台/API 入口，但当前缺少非空套餐或真实 key 样本；火山引擎 Token plan 尚未确认稳定用量接口。这些 Token plan 当前仍保持隐藏扩展桩：代码中保留 provider、capability、默认凭据名和后续 parser 接口，但在非空套餐额度字段和真实凭据样本确认前不会展示在 UI、不会从 `.env` 自动导入，也不会参与刷新。

## Coding plan 计量口径

Coding plan 优先按“请求次数窗口”展示，而不是只展示健康状态。已确认或已预留的统一口径是：

- 讯飞星火 coding plan：接口返回 `validFrom/expiresAt`、`rp5hLimit/rp5hUsage`、`rpwLimit/rpwUsage`、`packageLimit/packageUsage/packageLeft`；`rp5hUsage`、`rpwUsage`、`packageUsage` 是官网同口径的已用次数。Quota Radar 在解析层统一换算为 `limit - usage`，界面只展示剩余次数/总次数和剩余百分比；当 `packageUsage` 缺失时才使用 `packageLeft` 作为月窗口剩余次数兜底。接口未直接返回 reset 字段，Quota Radar 按 `validFrom` 推断 5 小时/周窗口下一个边界，并把 `expiresAt` 作为套餐期窗口结束/重置时间。
- 腾讯云 coding plan：`DescribePkg` 的 `UsageDetail.PerFiveHour/PerWeek/PerMonth` 返回 `Used/Total/UsagePercent`，分别对应 5 小时、周、月请求次数。
- 阿里云 coding plan：官方文档描述为固定月费、月度请求额度；当前账号无套餐，真实接口只确认订阅状态。代码已预留解析 5 小时、周、月的 `used/total/left` 字段，字段出现时按同样的剩余次数/总次数展示；字段不存在时不造百分比，显示“额度未知”。

## Token plan 计量口径

Token plan 不能默认等同于 coding plan，也不能默认都是 token 数量，必须先看服务商接口返回的单位。

- 腾讯云 Token plan：代码已保留官方 `DescribeTokenPlanApiKey` parser，可解析 `Balance.ExclusiveQuota/ExclusiveRemain/SharedQuota/SharedRemain`，但当前没有真实用户 key 可验证，继续隐藏。
- 讯飞星火 Token plan：控制台 quota 接口返回 `remainingCount/totalCount` 和 seat type，更像座席/次数额度；待非空样本确认后再接入 UI。
- 阿里云 Token plan：控制台订阅列表已确认，预期为积分/credits 类额度，但当前账号没有非空套餐，具体字段和周期待确认。
- 火山引擎 Token plan：未确认独立稳定的用量接口和计量单位，继续隐藏。

## 额度与结束日期字段验证

以下结论来自截至 2026-06-16 的真实浏览器登录态、本地 QuotaService 脱敏验证和用户提供/源码确认的接口样本。`resetAt` 指当前额度窗口重置时间，`planEndsAt` 指套餐/订阅结束时间。

| Provider | 额度可查 | resetAt | planEndsAt | 已验证字段或结论 |
| --- | --- | --- | --- | --- |
| Tavily | 是 | 是，代码按每月 1 日计算 | 否 | `GET /usage` 返回 `key.usage`、`key.limit`、`account.plan_usage`、`account.plan_limit`；接口未返回显式 reset/end，月初重置来自官方免费额度规则。 |
| Brave Search | 是，但会消耗一次搜索 | 是 | 否 | 搜索响应 header 返回 `x-ratelimit-limit`、`x-ratelimit-remaining`、`x-ratelimit-reset`、`x-ratelimit-policy`；未见套餐结束字段。 |
| SerpAPI | 是 | 是，代码按下月 1 日 UTC 计算 | 否 | `GET /account.json` 返回 `searches_per_month`、`this_month_usage`、`plan_searches_left`、`total_searches_left`、`extra_credits`；接口未返回显式 reset/end。 |
| Serper | 是 | 否 | 否 | `GET /account` 返回 `balance`、`rateLimit`；未见 reset/end 字段。 |
| Exa | 可用，额度未知 | 否 | 否 | Team Management usage API 只返回账单用量证据，不暴露剩余额度或套餐上限，所以主界面显示“可用 · 额度未知”。普通 search key 不能查询额度证据，当前配置若只有 search key 会显示需要 API 密钥。 |
| Bocha | 是 | 否 | 否 | 余额 API 返回 `data.remaining`，按人民币余额展示；未见 reset/end 字段。 |
| AnySearch | 本地无限额度规则 | 无固定周期 | 否 | 当前免费，不请求远端额度接口。 |
| Querit | 可用，额度未知 | 否 | 否 | `/api/v1/user/account` 返回 `current_plan.free_usage_month`、`paid_usage_month`、`enterprise_usage_month`、`coupon_quota`、`coupon_used` 等 usage-only 字段；当前账号未见套餐上限、重置时间或结束日期字段，所以主界面显示“可用 · 额度未知”。 |
| 微信搜索 | 是 | 否 | 否 | 余额 API 返回 `remain_money`、`request_time`，按人民币余额展示；未见 reset/end 字段。 |
| Claude API Usage | 未接入 | 待确认 | 待确认 | 暂不展示/导入 API key；组织 usage 需要 Admin 权限模型，未和个人 Claude 订阅额度打通。 |
| Claude Subscription | 是 | 是 | 是 | `/api/organizations` 发现当前组织，`/api/organizations/{org_uuid}/usage` 返回 `five_hour`、`seven_day` 的 `utilization` 和 `resets_at`，Quota Radar 转成剩余百分比和窗口重置时间；`/api/organizations/{org_uuid}/subscription_details` 的 `next_charge_at` 或 `next_charge_date` 作为订阅周期结束日期。组织和 subscription details 的 tier 字段可产生 `Max 5x` / `Max 20x`；不把 Anthropic API / prepaid credits 混入 Claude Subscription。 |
| Anthropic Credits | 是 | 否 | 否 | `/api/organizations` 发现当前组织，`/api/organizations/{org_uuid}/prepaid/credits` 从 `amount` 等字段解析 API / prepaid credits 余额。该接口不暴露 reset 或 plan-end 字段；2026-06-23 通过已有 Claude Subscription 授权脱敏复放返回 HTTP 200 并解析余额，直接 Anthropic Credits live acceptance 已确认有 quota 证据，刷新时可按需派生 Anthropic Credits 监控行。 |
| Codex API Usage | 未接入 | 待确认 | 待确认 | 暂不展示/导入 OpenAI API key；平台 usage/costs 与 ChatGPT/Codex 订阅窗口不同，当前未接入刷新。 |
| Codex Subscription | 是 | 是 | 是 | Codex Cloud 页面真实请求 `/backend-api/wham/usage`，返回 `rate_limit.primary_window` 5 小时窗口、`secondary_window` 周窗口、`additional_rate_limits[]` 模型专属窗口及 `reset_at`；该接口需要先从 `/api/auth/session` 取得 ChatGPT session access token，并用 Bearer token 调用。套餐到期来自 `/backend-api/subscriptions?account_id=...`；lifecycle 字段、`accounts/check`、RevenueCat offering IDs 和可读值会把 `chatgptprolite` / `ChatGPT Pro Lite` 映射为 `Pro 5x`，把 `chatgptpro` / `ChatGPT Pro` 映射为 `Pro 20x`。`/backend-api/wham/rate-limit-reset-credits` 返回 `available_count` 以及每次重置的 `granted_at`、`expires_at` 和兑换状态；Quota Radar 选择最早的未使用有效期展示，并忽略已使用或已过期的重置次数。当前响应未见月窗口。 |
| Kimi | 是 | 是 | 有字段时可查 | Kimi Code 网页授权可调用 `kimi.gateway.billing.v1.BillingService/GetUsages` 读取 `FEATURE_CODING` 的 5 小时和周额度、剩余次数和 reset；`MembershipService/GetSubscription` 暴露订阅状态、balances、`next_billing_time` 或 balance `expire_time`。当前未确认独立月限流窗口；订阅余额有 `amount/amount_left` 时按月度余额展示，只有 `amountUsedRatio` 时按百分比展示，否则只显示已确认窗口或“额度未知”。官方 Kimi Code OAuth `/coding/v1/usages` 返回同类 `usage/limits` 结构，但需要独立 OAuth 凭据，暂列后续统一认证改造。 |
| DeepSeek | 是 | 否 | 否 | `/user/balance` 返回 `is_available` 和余额结构，按人民币余额展示；未见 reset/end 字段。 |
| 讯飞星火 coding plan | 是 | 推断 | 是 | `/api/v1/gpt-finetune/coding-plan/list` 返回 `validFrom`、`expiresAt` 和 `codingPlanUsageDTO` 三周期请求次数额度；接口未返回显式 reset 字段。Quota Radar 用 `validFrom` 推断 5 小时/周窗口下一个重置边界，用 `expiresAt` 作为套餐期窗口结束/重置时间。 |
| 讯飞星火 Token plan | 座席额度可查，待接入代码 | 待购买样本确认 | 待购买样本确认 | Token Plan 页面真实请求 `/api/v1/gpt-finetune/token-plan/seats?page=0&size=6` 和 `/api/v1/gpt-finetune/token-plan/quota`；当前账号 `seats.total=0`，`quotas[]` 返回 `seatTypeName`、`remainingCount`、`totalCount`。 |
| 火山引擎 coding plan | 是 | 是 | 是 | 页面真实请求 `GetCodingPlanUsage` 返回 `QuotaUsage[].Percent` 和 `ResetTimestamp`；`ListSubscribeTrade` 返回 `ResourceType="CodingPlan"`、`Status`、`StartTime`、`EndTime`、`Period`、`EnableAutoRenew`。 |
| 火山引擎 Token plan | 未接入 | 待确认 | 待确认 | 资源包/Token Plan 相关入口未确认到独立稳定的用量接口，继续隐藏。 |
| OpenCode Go | 是 | 是 | 否 | 已保存 `_server` 凭据可返回 rolling/weekly/monthly 百分比与窗口 reset；未见套餐结束字段。 |
| 阿里云 coding plan | 有套餐时可查 | 有套餐时可查 | 有套餐时可查 | 页面真实请求 `BroadScopeAspnGateway` / `codingPlan.queryCodingPlanInstanceInfoV2`；`codingPlanInstanceInfos` 为空时显示未发现订阅套餐。有套餐时读取 `codingPlanQuotaInfo.per5Hour/perWeek/perBillMonth` 的 used/total/reset 字段，`instanceEndTime` 是套餐结束时间。 |
| 阿里云 Token plan | 订阅列表可查，待接入代码 | 待购买样本确认 | 待购买样本确认 | Token Plan 页面真实请求 `bailian-commerce.tokenPlan.queryTokenPlanInstanceInfo`，当前账号返回 `supportModels` 和空 `tokenPlanInstanceInfos`；非空套餐的积分/credits 额度、reset、end 字段仍需样本确认。 |
| 腾讯云 coding plan | 有套餐时可查 | 有套餐时可查 | 有套餐时可查 | 页面真实请求 `cgi/capi?cmd=DescribePkg&serviceType=hunyuan`；当前账号 `PkgList` 为空，有套餐时 `UsageDetail.*.Used/Total` 是请求次数，`UsageDetail.*.EndTime` 是窗口重置，`PkgList[].EndTime` 是套餐结束时间。 |
| 腾讯云 Token plan | 隐藏扩展桩；parser 保留，待真实 key 验证 | 待确认 | 待确认 | 代码可解析 `DescribeTokenPlanApiKey` 的 `Balance.*Quota/*Remain`，但当前没有真实用户 key 可验证；浏览器页面真实请求 `cgi/capi?cmd=ListUserTokenPlans&serviceType=hunyuan`，当前账号 `UserTokenPlanList` 为空，非空套餐生命周期字段待样本确认。 |

不要把真实 API Key、Cookie 或腾讯云 Secret 写入源码、测试或文档。
