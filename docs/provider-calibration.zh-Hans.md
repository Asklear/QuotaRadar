# Provider 校准台账

这份文档跟踪需要先校准、再补 parser 映射的 provider / 套餐样本。它和 [Providers](./providers.zh-Hans.md) 分工不同：Providers 记录当前可信口径，这里记录仍需证据的长尾样本。

## 先观察再加 fixture

不要凭猜测新增 parser fixture 或套餐本地化映射。

- [ ] 先捕获脱敏响应形态，或保存脱敏 live acceptance 行。
- [ ] 明确 quota、balance、reset time、plan end、plan display name 分别来自哪些字段。
- [ ] 确认检查是否会消耗真实额度。
- [ ] 确认字段含义是剩余额度、已用额度、余额，还是 usage-only metadata。
- [ ] 只有实际观察到字段边界后，才新增 parser fixture。
- [ ] API credits 和订阅额度描述的是不同产品时，必须拆成不同 provider 类型。

常用命令：

```bash
scripts/live_acceptance.sh --json
```

live acceptance 输出是脱敏矩阵。它会包含 provider 校准状态、最近验证时间、校准证据和降级口径，但不会打印 secret、Cookie、token、凭据标签或 provider 原始响应。

## 长尾校准队列

| 领域 | 候选项 | 当前状态 | 需要的证据 | 下一步 |
| --- | --- | --- | --- | --- |
| Claude Subscription OAuth usage/limits | Claude Code 类 OAuth 额度接口 | 待确认 | 确认 OAuth 是否比网页登录 organization 接口更稳定地返回 5 小时、周、reset、套餐层级和订阅周期字段。 | 捕获脱敏响应形态，再决定 OAuth 是否成为主来源，网页登录 organization usage 是否降级为 fallback。 |
| OpenAI prepaid credits | OpenAI platform billing / credit grant / prepaid balance | 待确认 | 确认 account/project scope、是否需要 Admin key 或网页登录，以及字段是否是 API credits，而不是 Codex 订阅窗口。 | 和 Codex Subscription 分开；只有观察到稳定余额字段后再接入。 |
| Anthropic Credits | Claude web prepaid credits | 已实测 | 2026-06-23 15:56 CST 用已有 Claude Subscription 网页登录授权复放，返回 HTTP 200，并成功解析 credits 余额；直接 `Anthropic Credits` live acceptance 也已通过并确认有 quota 证据。数值是 API / prepaid credits，不是 Claude Subscription 限额。 | 和 Claude Subscription 分开；没有直接凭据行时，刷新 Anthropic Credits 会从已保存 Claude 授权派生独立监控行，不要求用户重复认证。 |
| LongCat billing | Token 资源包和 API 按量余额 | 观察中 | 前端 bundle 暴露 `token-packs/summary` 和 `api-usage/summary` 控制台 billing endpoints，未登录复放返回需要登录。仍需要保存 LongCat 网页登录授权后，用真实账号跑 live acceptance。 | LongCat 保持一个 provider，在账号下展示 Token 资源包和 API 按量余额两个计费指标。API key 只作为配套可复制调用 key。 |
| Cloud coding plans | 阿里云 / 腾讯云 / 火山引擎 / 讯飞星火更多套餐名 | 观察中 | 观察真实套餐名、内部枚举、到期字段，以及 usage 是剩余还是已用。 | 只有观察到脱敏字段形态后，再加本地化显示映射和 parser fixture。 |
| Codex rare tiers | Codex 少见订阅 plan 字符串 | 观察中 | 观察当前 `Pro 5x` / `Pro 20x` 之外的 plan identifier 和 lifecycle 来源。 | 捕获 raw value 后再扩展 `codexPlanDisplayName`。 |
| Claude rare tiers | Claude Max / team / enterprise 少见 tier 字符串 | 观察中 | 观察 organization 或 subscription details 的 raw tier 字段和 capability flags。 | 捕获 raw value 后再扩展 Claude tier 归一化。 |

## 文档和浏览器观察记录

| 候选项 | 观察结果 | 边界 |
| --- | --- | --- |
| OpenAI prepaid credits | 文档观察 2026-06-23；浏览器观察时 OpenAI Platform login missing。 | OpenAI API 文档公开的是 organization usage / cost reporting，例如 `GET/organization/costs`；未确认公开 prepaid credit balance API。不要在没有官方接口或登录态 Platform 余额字段前接入 OpenAI prepaid credits。 |
| Claude Subscription OAuth usage/limits | 文档观察 2026-06-23。 | Anthropic Admin API 的 usage / cost reporting 属于组织管理员接口，需要 `org:admin`；它和个人 Claude Subscription 额度不是同一个口径。当前还没有观察到 Claude Code OAuth `usage/limits` 端点，所以 Claude Subscription 继续以 `claude.ai` organization usage 接口作为来源。 |
| Claude web usage/prepaid credits | 浏览器实测 2026-06-23；Anthropic Credits live acceptance 于 2026-06-23 15:56 CST 通过。 | Kimi WebBridge live browser observation 观察到 `GET https://claude.ai/api/organizations/<org>/usage`、`GET https://claude.ai/api/organizations/<org>/prepaid/credits`、`GET https://claude.ai/api/organizations/<org>/overage_credit_grant`。usage 响应包含 `five_hour.utilization`、`seven_day.utilization`、`seven_day.resets_at`、`spend.used` 等字段；prepaid 响应包含 `amount`、`auto_reload_settings`、`last_paid_purchase_cents`、`pending_invoice_amount_cents` 等字段。Quota Radar 将 prepaid credits 作为独立 `Anthropic Credits` provider，使用 Claude 网页登录授权；本次脱敏复放通过已有 Claude Subscription 凭据返回 HTTP 200 并解析余额，直接 Anthropic Credits live acceptance 已确认有 quota 证据。 |
| LongCat billing endpoints | 前端 bundle 观察 2026-07-08；未登录复放返回需要登录。 | `POST https://longcat.chat/api/pay/quota/metering/token-packs/summary` 暴露 token 资源包字段，例如 `currentLot.remainingToken`、`currentLot.totalToken`、`currentLot.consumedToken`、`currentLot.expireTime` 和 `otherLots[]`。`POST https://longcat.chat/api/pay/quota/metering/api-usage/summary` 暴露按量余额字段，例如 `paygoBalance.primary.currency`、`paygoBalance.primary.amount`、`paygoStatus` 和充值 metadata。这些接口需要网页登录授权；只靠 LongCat API key 不能做额度监控。 |
| Kimi WebBridge | 已连接，并完成 Claude 浏览器实测。 | Kimi WebBridge 可用于 Claude 校准；OpenAI prepaid credits 未完成实测，因为浏览器跳转到了 OpenAI Platform 登录页。 |

## 最新脱敏快照

live acceptance 快照：2026-06-23 13:06 CST。

| Provider | 结果 | 脱敏证据 |
| --- | --- | --- |
| Querit | 通过 | 仍是可用、额度未知状态；账号接口只观察到 usage-only evidence，未观察到 limit/reset 字段。 |
| Claude Subscription | 通过 | 观察到套餐、两个额度窗口、reset 字段和套餐到期 metadata。 |
| Anthropic Credits | 通过 | 已基于观察到的 `prepaid/credits` 形态接入 parser fixture 和 provider capability；通过保存的 Claude 网页登录授权脱敏复放返回 HTTP 200 并解析余额。直接 Anthropic Credits live acceptance 已通过，确认有 quota 证据且没有 reset / plan-end / window 字段。 |
| Codex Subscription | 通过 | 观察到套餐、两个额度窗口、reset 字段、套餐到期 metadata、重置次数和单次重置有效期 metadata。 |
| Kimi Subscription | 通过 | 观察到套餐到期 metadata 和可用额度状态；本次保存账号未暴露 reset window。 |
| LongCat | 仅 parser fixture | 已从前端 bundle 观察到 Token 资源包和 API 按量余额 dashboard endpoint 字段名；live acceptance 等待保存 LongCat 网页登录授权后执行。 |
| 讯飞星火 Coding Plan | 通过 | 观察到三个额度窗口、reset 字段、套餐 metadata 和套餐到期 metadata。 |
| 火山引擎 Coding Plan | 通过 | 观察到三个额度窗口、reset 字段、套餐 metadata 和套餐到期 metadata。 |
| OpenCode Go | 通过 | 观察到三个额度窗口和 reset 字段；未观察到 package end metadata。 |
| Aliyun Coding Plan | 缺少已保存账号 | 有保存账号前，不能更新 live 字段边界。 |
| Tencent Cloud Coding Plan | 缺少已保存账号 | 有保存账号前，不能更新 live 字段边界。 |

## 证据记录模板

新增校准记录时使用这个格式：

```text
Provider:
Credential type:
Observed at:
Source endpoint or UI path:
Quota fields:
Reset fields:
Plan fields:
Plan end fields:
Check consumes quota:
Parser fixture added:
Fallback behavior:
Secret handling:
```

## 边界

- 不要把原始 Cookie、bearer token、API key、authorization header 或账号 ID 写入文档或 fixture。
- 优先使用保留真实字段名、数值脱敏/合成的响应形态。
- 如果 provider 只返回 usage、没有 limit，显示“可用，额度未知”；不要自行推算剩余额度。
- 已校准 provider 的字段消失时，显示“需要重新校准”，不要直接把凭据判为失效。
- 余额增加应归类为充值/恢复，不计为负消耗。
