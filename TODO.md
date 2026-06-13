# Quota Radar TODO / Roadmap

<p align="right">
  语言：
  <strong>简体中文</strong> |
  <a href="./TODO.en.md">English</a>
</p>

Quota Radar 的核心目标是降低“额度焦虑”：不用反复登录各家后台，也能快速知道哪些 key 还能用、什么时候重置、哪些凭据已经失效、哪些检查会消耗真实额度。

## 产品原则

- 优先接入官方 usage / billing API；没有官方 API 时，再考虑网页登录授权。
- 明确区分 API Key 和网页登录授权；部分服务商的额度查询 API Key 不等同于模型调用 key，需要在说明里写清楚。
- 对用户已有业务 key 和账号的 provider，允许保存业务 key、通过登录流程获取网页登录授权、进入验证接入流程；完全没有账号/接口证据的 provider 才作为隐藏扩展桩。
- 自动刷新默认避免消耗真实搜索额度；例如 Brave 这类检查会产生真实 search request 的 provider，只允许手动刷新或明确确认后刷新。
- 所有真实凭据只保存在本机 secret store；源码、测试、README、Release 都不能包含真实 key、登录授权或 Cookie。
- 每个 provider 都要有清楚的诊断状态：可用、额度未知、凭据过期、连接失败、接口不支持、检查会消耗额度。

## v0.2.0 已完成

- 状态栏改为数值优先的 provider 额度概览，按 `AI Search` 和 `LLM` 分组。
- 状态栏扩大尺寸，减少滚动和遮挡，并修复顶部/底部被裁切的问题。
- 状态栏右上角操作按钮改为稳定的 AppKit 点击目标，避免弹窗里第一次点击无响应。
- 主窗口和配置页统一按 `AI Search` 在前、`LLM` 在后的顺序展示。
- 配置页明确区分 API 密钥和网页登录授权，避免把火山引擎、讯飞星火、OpenCode Go 误导成普通 API Key。
- 支持开机自启动、自动刷新间隔和关闭自动刷新；自动刷新会跳过 Brave 这类会消耗真实搜索请求的 provider。
- 支持状态栏透明度设置，并把透明度传递到状态栏内部卡片。
- 网页登录授权服务商支持重新认证自动保存，并在保存前调用 provider 额度接口验证。
- 修复重新认证后刷新又回退到旧登录授权的问题：`~/.claude/settings.json` 只在首次初始化导入，不在刷新时再次覆盖本地 secret。
- 继续使用本地 secret 文件作为默认凭据存储，避免反复触发登录钥匙串密码弹窗。
- 更新 README、Quickstart、Release workflow 和 unsigned DMG / Gatekeeper 说明。
- 补齐 README 主窗口与状态栏截图，使用真实运行画面。
- Deepseek、Bocha、微信搜索按人民币余额展示，不再误显示为 credit 或百分比。

## P0: 当前版本收尾与稳定性

- [x] 更新 QUICKSTART 中过时的设置页表述，统一为“设置”。
- [x] 检查中英文文档是否都覆盖：未签名 DMG、自动刷新关闭、Brave 自动刷新跳过、网页登录授权 provider 使用方式。
- [x] 为 Release workflow 增加更清楚的 release notes 模板，提示 unsigned DMG 的 Gatekeeper 处理方式。
- [x] 保留现有未签名 DMG 发布路径；Apple Developer ID 签名和 notarization 只作为可选未来项。
- [x] 继续避免 Keychain 依赖作为默认路径，减少“登录钥匙串密码”弹窗。
- [x] 为 v0.2.2 的状态栏透明度和不同桌面背景做一轮截图 QA，并让中英文 README 使用各自语言的截图。
- [x] 把 provider capability matrix 文档补齐，作为后续新增 provider 的入口。

## v0.3.3 已处理问题

- [x] 增加 GitHub Release 更新入口：左侧栏底部显示版本号、更新状态和手动检查按钮。
- [x] 支持启动后自动检查更新，但只检查新版并展示 release notes，不静默下载、不自动覆盖安装。
- [x] 用户点击 `下载并安装` 后，应用会下载 `QuotaRadar.dmg`、替换 `/Applications/Quota Radar.app`、清除 quarantine 并重新启动。
- [x] 更新检查复用应用内网络代理设置；GitHub API 未认证 rate limit 时，会降级通过 latest-release 重定向解析版本和下载地址。
- [x] 更新中英文 README 状态栏截图和 Quickstart / Roadmap 说明，明确未签名 release 的信任边界和应用内更新行为。

## Tauri 多平台预览收尾

当前 `feat/tauri-multiplatform` 分支已经完成基础 shell、mock UI、provider/credential 合约、i18n、provider 图标资产、状态栏弹窗和 macOS app bundle 构建。下一步要把它从“可预览”推进到“可长期试用”。

- [x] 将 Tauri 主窗口左上角、状态栏弹窗左上角和 provider 列表切换到 Swift 版同源图标资产，避免首字母占位和多套图标风格混用。
- [x] 将 Tauri macOS menu bar 图标改成 template artwork，并增加 click debounce，避免鼠标 down/up 连续事件导致弹窗闪开闪关。
- [x] 用 Playwright 和真实 macOS 截图 QA 检查 Tauri 主窗口、状态栏弹窗、provider 图标和 560 x 500 弹窗尺寸。
- [x] 修复 Tauri 主窗口首次启动 / Dock 重新打开时可能出现在外接屏或负坐标屏幕的问题：主窗口优先跟随当前交互屏幕，用户移动后保存位置，保存位置离屏时自动修复。
- [x] 把 Tauri dev server 的文件监听范围排除 `src-tauri/target`、`dist`、`node_modules` 和 Playwright artifacts，避免 Rust 构建目录里的 symlink 触发 Vite watcher `ELOOP`。
- [x] 为 Tauri app bundle 增加稳定的本地 ad-hoc 签名 / package step，构建后可用 `pnpm sign:mac` 执行 `codesign --verify --deep --strict`。
- [x] 增加真实 macOS bundle 截图 QA 脚本，输出到 `/tmp/quotaradar-tauri-qa...`；深色模式、透明菜单栏、外接屏和缩放比例作为 checklist 项记录，按当前硬件环境复核。
- [ ] 增加 Windows / Linux 首轮截图 QA：主窗口、tray / system tray 入口、字体、窗口阴影、最小尺寸和 provider 图标渲染。
- [x] 把 Tauri provider icon 资产同步流程脚本化，避免 Swift 资产更新后 Tauri public 目录遗忘同步。
- [x] 为 Tauri 增加 `~/.claude/settings.json` 导入后端和配置页入口：复用 Swift 版环境变量识别规则，按 provider/name 合并更新，原始 secret 只进入 secret vault，不写入 metadata。
- [ ] 在 Tauri 版本进入正式 preview 前，补齐剩余真实凭据迁移回归：旧 Swift 本地配置、通用 `.env` 文件选择导入、Stronghold / store 元数据兼容和 secret 不入库扫描。

## v0.3.2 已处理问题

- [x] Claude、Codex、Kimi 和 OpenCode Go 订阅类 provider 支持保存配套 API Key，API Key 只用于复制和管理，额度查询仍使用网页登录授权。
- [x] 新增网络代理设置：跟随系统、直连、自定义 HTTP/SOCKS 代理，并在设置页使用居中菜单控件展示当前选项。
- [x] 新增或编辑凭据后会立即刷新对应 provider，不再必须等自动刷新或手动再点一次。
- [x] 多个网页登录授权同时存在时，重新认证窗口会要求选择保存目标，避免覆盖错误账号。
- [x] 状态栏弹窗改为风险摘要优先：`今日额度风险` + `需要关注`，不再把完整 provider 网格塞进小弹窗。
- [x] 主程序额度监控表头改成 `关键额度 / 凭据池 / 关键时间 / 状态`，兼容单 provider 多 key、订阅账号和多周期额度窗口。
- [x] `额度监控`、`配置凭据` 和 `诊断` 页面只展示已保存凭据的 provider，未配置 provider 不再显示空占位。
- [x] 多周期订阅额度在凭据行不再重复显示 5 小时/周/月文本，只在周期明细里展示；套餐到期日期会带年份，避免一年期套餐只显示月日。
- [x] 发布前行为测试覆盖凭据配对、代理设置、立即刷新、provider 过滤、多周期去重、套餐年份和 release 安全扫描。

## v0.3.0 已处理问题

- [x] 用真实浏览器登录态和本地脱敏检查更新 provider capability matrix，覆盖每个 provider 的 `quota`、`resetAt`、`planEndsAt` 结论。
- [x] 修正 Querit 监控口径：账户接口只能读月度已用量，当前不暴露套餐上限、重置时间或结束日期，普通 `QUERIT_API_KEY` 不能查询 dashboard 用量。
- [x] 修正 Serper 监控口径：Account API 返回余额和 `rateLimit`，不暴露 reset/end 字段。
- [x] 明确阿里云 coding plan 目前可通过 `aliclaw.coding-plan` 判断订阅状态；有套餐时可读 `codingPlanInfo.endTime`，如果接口暴露 5 小时/周/月请求次数字段，代码会按讯飞星火同口径显示剩余次数/总次数。
- [x] 明确腾讯云 coding plan 使用控制台 `cgi/capi?cmd=DescribePkg&serviceType=hunyuan`；有套餐时可读请求次数、周期重置和套餐结束时间。
- [x] 明确腾讯云 Token plan 保留官方 `DescribeTokenPlanApiKey` parser，但当前缺少真实用户 key 样本；控制台页面发现套餐使用 `ListUserTokenPlans`，确认前不对外展示。
- [x] 补充 Token plan 计量口径：腾讯云当前是 token 额度，讯飞星火更像座席/次数额度，阿里云预期为积分/credits 类额度，火山引擎待确认。
- [x] README、Quickstart 和 Roadmap 同步这些已验证边界，避免把业务 API Key 误写成额度查询凭据。
- [x] 修复多屏幕下主窗口反复跳到另一个屏幕的问题：窗口会记住用户最后放置的位置，只在保存位置失效或窗口离屏时才按当前交互屏幕修复。
- [x] 主窗口额度监控改成 provider 汇总优先，减少 API Key 细节重复；同一 provider 内仍保留可排序、可展开的 key 级细节。
- [x] 诊断页不再为“仅用于保存/复制”的配套 API Key 生成重复额度行；这类 API Key 复用对应网页登录授权的健康状态和 HTTP 状态。
- [x] 支持在配置凭据时同时保存 provider 的 API Key 和网页登录授权：API Key 方便复制和管理，网页登录授权只用于额度查询，不作为可复制密钥展示。
- [x] 更新中英文 README 截图，使用 v0.3.0 真实运行画面，并确保截图里的密钥由应用打码。
- [x] 发布前安全加固：忽略 `.playwright-mcp/`、`test-results/` 等临时截图目录，并把密钥扫描纳入 release 前检查。

## v0.2.2 已处理问题

- [x] 状态栏图标改为白色实底、雷达和指针镂空的余量雷达 glyph，避免和 macOS 系统电源/电池图标混淆。
- [x] 主程序左上角、状态栏弹窗左上角和 Dock 图标统一使用同一个 App icon 视觉；内页标题不再重复放图标。
- [x] README 截图拆成简体中文和英文两套，避免英文文档继续展示中文界面。
- [x] Quickstart / README 中的入口说明从“电池图标”改为“余量雷达图标”。

## v0.2.0 已处理问题

- [x] LLM coding plan 在状态栏里不能只显示 `5 小时` 周期；需要比较 5 小时、周、月等多个周期，并显示剩余比例最低的周期，避免周额度为 0 时仍展示 5 小时满额。
- [x] 修复 Querit 重新认证流程里点击 Google 登录后无法弹出验证窗口的问题。
- [x] 在设置里新增“允许自动刷新会消耗检索额度的 provider”选项，并为这类刷新提供更长的周期选择，避免高频消耗免费额度。
- [x] 重新排查状态栏透明度设置没有实际效果的问题，确认外层 popover、内部卡片和 macOS material 都受设置影响。
- [x] 扩展语言选项，至少覆盖简体中文、繁体中文、日语、韩语，并完整补齐所有说明、按钮、诊断、日期、周期单位和 provider 配置文案。
- [x] 精简 `配置凭据` 页面标题层级，避免大标题和小标题都重复显示“配置凭据”。

前端整体继续向原生、高密度、低干扰的 macOS 监控面板风格收敛，剩余工作统一放在 P4，不再混在 v0.2.0 修复队列里。

## P1: 凭据配置体验

- [x] 把 `配置凭据` 做成 provider-aware 基础表单，而不是一个完全通用表单。
- [x] 精简配置页标题层级，页面主标题和局部标题不要重复同一文案。
- [x] 每个 provider 在配置页展示基础凭据类型：
  - API 密钥: Tavily、SerpAPI、Serper、Bocha、DeepSeek、Exa Team Management service key + target API key id 等。
  - 网页登录授权: Querit、Claude 订阅、Codex 订阅、Kimi 订阅、讯飞星火 coding plan、火山引擎 coding plan、OpenCode Go、阿里云 coding plan、腾讯云 coding plan。
  - 已验证接入: 阿里云 coding plan 可通过 `aliclaw.coding-plan` 判断订阅状态，若接口返回 5 小时/周/月请求次数字段会解析为剩余次数/总次数；腾讯云 coding plan 可通过控制台 `cgi/capi?cmd=DescribePkg&serviceType=hunyuan` 解析请求次数额度周期。两者的业务调用 API Key 可保存展示，但不用于额度监控。
  - 待补充样本: 阿里云 coding plan 当前真实账号返回未订阅；已预留用量字段解析，如果订阅账号仍不返回用量明细，则保持“可用 · 额度未知”。
  - 隐藏扩展桩: 讯飞星火 Token plan、火山引擎 Token plan、阿里云 Token plan、腾讯云 Token plan；确认可用额度接口、计量单位和真实凭据样本前不展示、不导入、不刷新。
- [x] 为网页登录授权服务商增加“粘贴 cURL 自动解析”能力：
  - 从 `curl` 中提取必要的网页登录授权信息，包括接口要求的 Cookie header。
  - 从火山引擎 cURL 中提取 `csrfToken`、`ProjectName` 等字段。
  - 从 OpenCode Go cURL 中提取 `workspaceID`、`serverID`、`serverInstance`。
  - 对 Querit，`QUERIT_API_KEY` 只作为可保存、可复制的 API 密钥；额度监控仍保存网页登录授权并使用控制台 Account API。
  - 对 Kimi，从 cURL 中提取 Bearer access token、`x-msh-device-id`、`x-msh-session-id`、`x-traffic-id` 和可选 `kimi-auth` cookie。
- [x] 为需要网页登录授权但用户仍要管理业务 API Key 的 provider 增加配套 API Key 保存：
  - Querit、Claude 订阅、Codex 订阅、Kimi 订阅、讯飞星火 coding plan、火山引擎 coding plan、OpenCode Go、阿里云 coding plan、腾讯云 coding plan。
  - 配套 API Key 可复制、可编辑，但不单独生成额度监控或诊断行。
  - 配套 API Key 会绑定到对应网页登录授权；多个账号时重新认证需明确保存目标。
- [x] 增加“重新认证”流程的自动保存：
  - 打开 provider dashboard 登录页。
  - 用户登录成功后，自动读取允许域名下的登录授权信息。
  - 检查必需登录字段是否存在。
  - 通过测试后保存到 secret store，并更新凭据状态。
- [x] 修复 Querit 使用 Google 登录时无法弹出验证窗口的问题，必要时为 OAuth/弹窗登录增加外部浏览器或新窗口处理。
- [ ] 增加凭据配置状态标签：
  - `未配置`
  - `已配置，待检测`
  - `可用`
  - `凭据过期`
  - `接口不可查询额度`
  - `检查会消耗额度`
- [ ] 增加凭据导出/备份功能，但默认只导出 metadata，不导出 secret。
- [ ] 扩展网页登录重新认证的 WebView 保存能力：除 cookie store 外，支持读取已确认 provider 的 localStorage token；Kimi 如果未设置 `kimi-auth` cookie 而只写入 `access_token`，需要走这条能力。

## P2: 连通性测试与诊断

- [ ] 为每个 provider 增加独立的 `测试连接` 按钮。
- [ ] 区分三类测试：
  - No-cost ping: 不消耗额度，只验证 key/cookie 格式或账户 endpoint。
  - Quota check: 查询真实额度。
  - Costly check: 会消耗真实额度，必须手动确认。
- [ ] 在诊断页展示更完整的信息：
  - 最近一次请求时间。
  - HTTP status。
  - provider 返回的错误信息摘要。
  - 是否经过代理。
  - 是否被自动刷新跳过。
  - 下次重置时间或“provider 未暴露重置时间”。
- [x] 增加代理设置：
  - 使用系统代理。
  - 手动 HTTP proxy，例如 `http://127.0.0.1:7890`。
  - 手动 SOCKS proxy，例如 `socks5://127.0.0.1:7890`。
  - 不使用代理。
- [x] 增加会消耗检索额度的 provider 自动刷新选项：
  - 默认关闭。
  - 明确提示会消耗真实请求额度。
  - 周期选项要明显长于普通免费刷新，例如 6 小时、12 小时、每天。
  - Brave 等 provider 只有用户开启后才参与自动刷新。
- [ ] 增加 threshold 通知：
  - 额度低于 20%。
  - 额度耗尽。
  - Cookie 过期。
  - provider 连续多次连接失败。

## P3: Provider 扩展

新增 provider 的准入标准：

- [ ] 找到官方 usage API、billing API、dashboard API，或确认只能手动/web login authorization。
- [ ] 确认额度单位、重置周期、是否会消耗查询额度。
- [ ] 确认并展示套餐名称 / plan tier，例如 Claude `Pro` / `Max`，Codex `Plus` / `Pro`，以及各云厂商返回的 `Coding Plan Pro`、资源包名或会员名；如果接口只返回内部枚举，需要做本地映射和多语言展示，不能只显示 provider 名。
- [ ] 增加 parser fixture，不能只依赖手测。
- [x] 为当前已接入 provider 补齐浏览器/API 验证记录，包含 quota、resetAt、planEndsAt 字段边界。
- [x] 增加 provider 图标 fallback、分类、默认凭据名、localized 文案。
- [ ] 增加 `.env` / `~/.claude/settings.json` 导入规则。
- [ ] 增加行为测试，防止真实 secret 进入仓库。

### AI Search 候选

- [ ] Perplexity / Sonar: 先确认官方 usage/billing API 是否可查询。
- [ ] You.com: 确认 API key 用量或 dashboard usage 入口。
- [ ] Jina AI Search / Reader: 确认免费额度、请求额度和 reset 逻辑。
- [ ] Firecrawl: 确认 credits API、团队/项目级用量。
- [ ] Linkup: 确认 API usage endpoint。
- [ ] Kagi Search API: 确认 plan quota 和 usage API。
- [ ] Google Programmable Search: 使用 Google Cloud quota/billing 信息，注意 OAuth 或 service account 复杂度。
- [ ] Azure Bing Search: 使用 Azure quota/usage，注意 subscription 和 resource scope。

### LLM / Coding Plan 候选

- [ ] OpenAI: 查询 billing/usage API 可用性、organization/project scope、key 粒度。
- [ ] OpenRouter: 查询 credits 和 usage API。
- [ ] Gemini / Google AI Studio: 查询 quota、billing、project scope。
- [ ] Qwen / DashScope: 查询阿里云用量与资源包。
- [x] Moonshot / Kimi: Kimi 订阅额度已接入；使用网页登录授权 / Bearer access token 调用 `BillingService/GetUsages` 读取 5 小时/周窗口、剩余次数和 reset，并用 `GetSubscription` 读取订阅余额和到期字段；暂未确认独立月限流窗口。
- [ ] Kimi Code OAuth 统一认证：官方 `/coding/v1/usages` 可返回同类 `usage/limits` 结构，但需要 Device Code OAuth token。后续把它做成“认证 Kimi”的备用/高级路径，而不是新增第二个主按钮。
- [ ] 套餐名称识别：为 Claude、Codex、Kimi、讯飞星火、火山引擎、阿里云、腾讯云等订阅 / coding plan provider 增加 `planDisplayName` 字段；在额度监控、状态栏和诊断页展示用户正在使用的具体套餐名，并在测试 fixture 中覆盖 `Pro`、`Max`、`Plus`、`Coding Plan Pro` 等典型返回。
- [ ] Zhipu / GLM: 查询账户余额和调用额度。
- [ ] MiniMax: 查询余额和 token 用量。
- [ ] Baidu Qianfan: 查询账户资源包。
- [ ] Tencent Hunyuan: 查询账户资源包。
- [ ] SiliconFlow: 查询余额和 API key 使用量。
- [ ] Anthropic: 当前不在主界面显示；只有在确认用户需要并能可靠查询 usage 后再重新评估。

### Pay-as-you-go / Prepaid Credits 候选

这部分和 Claude / Codex 订阅额度分开处理。订阅额度关注 5 小时、周、月窗口和套餐到期；prepaid credits 关注 API / Workbench / 平台调用余额，后续即使接入也应作为独立 provider 类型展示，不能冒充订阅剩余额度。

- [ ] Anthropic prepaid credits: 调研 Console prepaid credits 余额接口、组织范围、网页登录授权字段和可复放稳定性；确认后作为 Claude API credits / Anthropic credits 类 provider 进入，而不是 Claude Subscription。
- [ ] OpenAI prepaid credits: 调研 OpenAI platform billing / credit grant / prepaid balance 可读接口、organization/project scope、Admin key 或网页登录授权要求；确认后作为 OpenAI API credits 类 provider 进入，而不是 Codex Subscription。
- [ ] Claude Subscription 后续验证：当前 `claude.ai/api/organizations` 路径可在部分登录态返回 5 小时/周窗口，但 `subscription_details` 与组织选择存在不稳定性；已确认 Claude Code 类工具可走 OAuth 登录，下一轮优先验证 OAuth usage/limits endpoint 是否能稳定返回 5 小时、周窗口、reset 和套餐周期，并把网页组织接口降级为 fallback，而不是最终来源。

## P4: 前端美学与交互

- [ ] 建立 Quota Radar 的 macOS 监控面板设计基准：
  - 高密度但清晰的状态栏模块、刷新频率和设置分组。
  - 轻量原生、模块化、紧凑指标块和多语言覆盖。
  - 状态栏里的诊断摘要、最近活动和快速操作。
  - 主窗口的表格、分组、过滤、摘要区和诊断型信息层级。
- [ ] 把 QuotaRadar 定位成 API quota monitoring panel，而不是 SaaS dashboard：
  - 数字优先：剩余量、总量、百分比、重置时间、更新时间优先于装饰。
  - 密度适中：状态栏只放最重要的 provider-level 信息，主窗口承载细节。
  - 原生材质：使用 macOS sidebar、toolbar、popover、分割线和 material，不使用营销页式大卡片和大渐变。
  - 操作就近：刷新、重新认证、测试连接、打开后台都贴近对应 provider。
- [ ] 主窗口继续向现代 macOS 风格靠拢：
  - 更清晰的 sidebar 层级。
  - 更少的重复信息。
  - provider banner 可点击折叠，不依赖三角图标。
  - 折叠动画保持原位压缩，不从上方飞入。
  - 额度监控页使用表格/分组 + 右侧或底部摘要，而不是重复卡片堆叠。
- [x] 状态栏 popover 的基础监控交互：
  - AI Search 和 LLM 分组展示。
  - provider 支持折叠。
  - provider 内 key 按剩余额度排序。
  - key 显示前四位和后四位，不显示变量名。
  - 鼠标离开后自动收起，不激活主窗口。
  - LLM coding plan 显示多个周期中剩余比例最低的周期，而不是固定显示 5 小时周期。
  - 状态栏透明度设置已接入，并使用 README 截图做过一轮真实画面 QA。
  - 当前状态栏主视图只保留“今日额度风险”和“需要关注”两块，完整 provider/key 细节移到主程序。
- [x] 主窗口额度监控的信息架构调整：
  - provider 主行从 `剩余/总量` 改为 `关键额度/凭据池/关键时间/状态`。
  - `关键额度` 对订阅/coding plan 显示最紧张额度窗口，对普通 API key 池显示最佳可用 key。
  - `凭据池` 统计真正参与额度监控的凭据，排除仅用于复制的 companion API key。
  - provider 展开后继续显示单个 key/账号细节、重置和套餐到期信息。
- [ ] 状态栏 popover 的下一轮视觉深化：
  - 布局采用紧凑指标、细分割、清晰层级，不滚动长 dashboard。
  - 整体风格进一步向原生监控面板靠拢：更紧凑的模块、更少大卡片、更清楚的指标层级和操作区。
  - 透明效果继续在不同桌面背景下优化，在可读性和玻璃感之间取更稳定的平衡。
- [ ] 图标系统继续围绕“额度焦虑”和“余量雷达”隐喻：
  - App icon 和状态栏 icon 保持同构，远看能识别“监控额度”的雷达语义。
  - 状态栏 icon 在浅色、深色、透明菜单栏下都清晰，并且不能和 macOS 系统电源/电池图标混淆。
  - 状态栏 popover 右上角操作图标要更现代、语义明确，避免像无差别的灰色圆形按钮。
  - provider icon 尽量使用官方图标，找不到时才用一致的 fallback。
- [ ] 增加视觉 QA checklist：
  - 13 寸屏幕、宽屏、外接屏。
  - 浅色/深色模式。
  - 中文/英文。
  - 长 provider 名、长错误信息、多个 key。
  - 多屏幕下窗口打开、Dock 重开、设置按钮打开后都停留在用户手动放置的屏幕。
  - 文本不能遮挡或溢出。

## P5: 多平台与多语言

- [x] 短期仍以 macOS SwiftUI 版作为稳定发布版本，保持原生状态栏体验。
- [x] 多平台方案选择 Tauri + Rust + TypeScript；跨平台预览代码位于 `apps/desktop-tauri`，后续用于 macOS / Windows / Linux。
- [x] 为 Tauri 预览增加源码安全检查脚本 `scripts/check_tauri_sources.sh`，覆盖真实 secret、登录授权、i18n key、dashboard 授权不可复制和通用 provider placeholder 泄漏。
- [x] 增加 `Desktop Tauri Preview` GitHub Actions：macOS / Windows / Linux 三平台运行安全扫描、前端测试、TypeScript 检查、Rust 测试和 `tauri build --no-bundle --ci`。
- [x] 增加 [Tauri 桌面发布说明](./docs/desktop-tauri-release.md)，明确平台本地 package target、未签名预览边界、GitHub Release asset 命名和后续签名要求。
- [ ] Tauri 预览的正式签名、更新 manifest 和 GitHub Release 上传自动化放到后续 packaging task 中处理。
- [ ] 统一 localization key，避免业务文案直接写在 View 或 parser 中。
- [x] 增加语言选项：
  - 繁体中文
  - 日语
  - 韩语
- [x] 补齐日期和周期单位翻译：
  - 5 小时
  - 周
  - 月
  - 下次重置
  - 无法查询
  - 额度未知
- [x] 扫描所有说明文案、设置文案、按钮、诊断信息、错误信息和 release-facing 文档，确保新增语言没有遗漏。
- [ ] 增加 provider 名称策略：
  - 品牌名通常不翻译，例如 Deepseek、Serper、Exa、Querit。
  - 通用状态和额度单位必须翻译。

## P6: 数据、历史与提醒

- [ ] 保存最近 N 次 quota snapshot，用于展示趋势。
- [ ] 增加“额度消耗速度”提示，例如本周使用过快。
- [ ] 增加本地通知：
  - 即将耗尽。
  - 已耗尽。
  - Cookie 过期。
  - 余额恢复或月初重置。
- [ ] 增加 provider-level refresh history，帮助判断“刷新是否真的生效”。

## 下一步开工计划

建议下一轮继续从 P1 + P2 开始，因为重新认证自动保存已经完成，剩下的主要问题是“配置更少出错”和“诊断更清楚”。

1. [x] 做一张 provider capability matrix。
   - 文件建议：新增 `docs/provider-capabilities.md` / `docs/provider-capabilities.en.md`。
   - 字段：provider、category、credential type、usage source、reset cycle、does check consume quota、diagnostic endpoint、notes。
2. [x] 重构配置页为 provider-aware 表单。
   - 重点文件：`QuotaRadar/Models/APIKey.swift`、`QuotaRadar/Views/SettingsView.swift`、`QuotaRadar/Services/EnvImporter.swift`。
   - 目标：用户选择 provider 后，只看到该 provider 需要的字段。
3. [x] 增加 cURL paste parser。
   - 重点文件：新增 `QuotaRadar/Services/CurlCredentialParser.swift`。
   - 目标：Querit、讯飞星火 coding plan、火山引擎 coding plan、OpenCode Go 可从浏览器复制的 cURL 自动提取 Cookie/headers。
4. [ ] 增加 per-provider connectivity test。
   - 重点文件：`QuotaRadar/Services/QuotaService.swift`、`QuotaRadar/Models/QuotaMonitor.swift`、`QuotaRadar/Views/SettingsView.swift`。
   - 目标：每个 provider 可单独检测凭据是否可用，并明确是否消耗额度。
5. [x] 增加 proxy 设置。
   - 重点文件：`QuotaRadar/Models/AppAppearance.swift`、`QuotaRadar/Services/QuotaService.swift`、`QuotaRadar/Views/SettingsView.swift`。
   - 目标：支持系统代理、手动 HTTP/SOCKS 代理、禁用代理。
6. [ ] 做一轮主界面和状态栏 popover 视觉 QA。
   - 使用截图检查不同窗口大小、语言、深浅色模式。
   - 优先修遮挡、溢出、重复信息和折叠动画。

## 暂不优先

- [ ] 付费 Apple Developer ID 签名和 notarization。
- [ ] Windows/Linux 签名安装包与正式分发；当前只做 Tauri 预览构建和本地 bundle 验证。
- [ ] 远程同步凭据。
- [ ] 多用户团队看板。
