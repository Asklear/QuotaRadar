# Quota Radar TODO / Roadmap

<p align="right">
  语言：
  <strong>简体中文</strong> |
  <a href="./TODO.en.md">English</a>
</p>

Quota Radar 的核心目标是降低“额度焦虑”：不用反复登录各家后台，也能快速知道哪些 key 还能用、什么时候重置、哪些凭据已经失效、哪些检查会消耗真实额度。

## 产品原则

- 优先接入官方 usage / billing API；没有官方 API 时，再考虑 dashboard session Cookie。
- 明确区分 API Key、Admin Credential、Dashboard Cookie，不让用户误把模型调用 key 填成 Cookie。
- 自动刷新默认避免消耗真实搜索额度；例如 Brave 这类检查会产生真实 search request 的 provider，只允许手动刷新或明确确认后刷新。
- 所有真实凭据只保存在本机 secret store；源码、测试、README、Release 都不能包含真实 key 或 Cookie。
- 每个 provider 都要有清楚的诊断状态：可用、额度未知、凭据过期、连接失败、接口不支持、检查会消耗额度。

## v0.2.0 已完成

- 状态栏改为数值优先的 provider 额度概览，按 `AI Search` 和 `LLM` 分组。
- 状态栏扩大尺寸，减少滚动和遮挡，并修复顶部/底部被裁切的问题。
- 状态栏右上角操作按钮改为稳定的 AppKit 点击目标，避免弹窗里第一次点击无响应。
- 主窗口和配置页统一按 `AI Search` 在前、`LLM` 在后的顺序展示。
- 配置页明确区分 API Key、Admin Credential、Dashboard Cookie，避免把火山引擎、讯飞星火、OpenCode Go 误导成普通 API Key。
- 支持开机自启动、自动刷新间隔和关闭自动刷新；自动刷新会跳过 Brave 这类会消耗真实搜索请求的 provider。
- 支持状态栏透明度设置，并把透明度传递到状态栏内部卡片。
- Dashboard Cookie provider 支持重新认证自动保存，并在保存前调用 provider 额度接口验证。
- 修复重新认证后刷新又回退到旧 Cookie 的问题：`~/.claude/settings.json` 只在首次初始化导入，不在刷新时再次覆盖本地 secret。
- 继续使用本地 secret 文件作为默认凭据存储，避免反复触发登录钥匙串密码弹窗。
- 更新 README、Quickstart、Release workflow 和 unsigned DMG / Gatekeeper 说明。
- 更新 README 主窗口与状态栏截图，使用 v0.2.0 真实运行画面。
- Deepseek、Bocha、微信搜索按人民币余额展示，不再误显示为 credit 或百分比。

## P0: 当前版本收尾与稳定性

- [x] 更新 QUICKSTART 中过时的设置页表述，统一为“设置”。
- [x] 检查中英文文档是否都覆盖：未签名 DMG、自动刷新关闭、Brave 自动刷新跳过、Cookie provider 使用方式。
- [x] 为 Release workflow 增加更清楚的 release notes 模板，提示 unsigned DMG 的 Gatekeeper 处理方式。
- [x] 保留现有未签名 DMG 发布路径；Apple Developer ID 签名和 notarization 只作为可选未来项。
- [x] 继续避免 Keychain 依赖作为默认路径，减少“登录钥匙串密码”弹窗。
- [x] 为 v0.2.0 的状态栏透明度和不同桌面背景做一轮截图 QA，更新 README 截图。
- [ ] 把 provider capability matrix 文档补齐，作为后续新增 provider 的入口。

## v0.2.0 待修复队列

- [x] LLM coding plan 在状态栏里不能只显示 `5 小时` 周期；需要比较 5 小时、周、月等多个周期，并显示剩余比例最低的周期，避免周额度为 0 时仍展示 5 小时满额。
- [x] 修复 Querit 重新认证流程里点击 Google 登录后无法弹出验证窗口的问题。
- [x] 在设置里新增“允许自动刷新会消耗检索额度的 provider”选项，并为这类刷新提供更长的周期选择，避免高频消耗免费额度。
- [x] 重新排查状态栏透明度设置没有实际效果的问题，确认外层 popover、内部卡片和 macOS material 都受设置影响。
- [x] 扩展语言选项，至少覆盖简体中文、繁体中文、日语、韩语，并完整补齐所有说明、按钮、诊断、日期、周期单位和 provider 配置文案。
- [x] 精简 `配置凭据` 页面标题层级，避免大标题和小标题都重复显示“配置凭据”。
- [ ] 按 macOS 知名监控工具风格重做前端 UI：状态栏参考 iStat Menus / Stats，主窗口参考 Activity Monitor，诊断与快速操作参考 Little Snitch Control Center。

## P1: 凭据配置体验

- [ ] 把 `配置凭据` 做成 provider-aware wizard，而不是一个通用表单。
- [x] 精简配置页标题层级，页面主标题和局部标题不要重复同一文案。
- [ ] 每个 provider 在配置页展示需要的凭据类型：
  - API Key: Tavily、SerpAPI、Serper、Bocha、DeepSeek 等。
  - Admin Credential: Exa Team Management service key + target API key id。
  - Dashboard Cookie: Querit、讯飞星火、火山引擎、OpenCode Go。
- [ ] 为 Dashboard Cookie provider 增加“粘贴 cURL 自动解析”能力：
  - 从 `curl` 中提取 Cookie header。
  - 从火山引擎 cURL 中提取 `csrfToken`、`ProjectName` 等字段。
  - 从 OpenCode Go cURL 中提取 `workspaceID`、`serverID`、`serverInstance`。
  - 对 Querit 只保存 dashboard session Cookie，不再接受普通 `QUERIT_API_KEY`。
- [x] 增加“重新认证”流程的自动保存：
  - 打开 provider dashboard 登录页。
  - 用户登录成功后，自动读取允许域名下的 Cookie。
  - 检查 required cookie 是否存在。
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
- [ ] 增加代理设置：
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

- [ ] 找到官方 usage API、billing API、dashboard API，或确认只能手动/dashboard Cookie。
- [ ] 确认额度单位、重置周期、是否会消耗查询额度。
- [ ] 增加 parser fixture，不能只依赖手测。
- [ ] 增加 provider 图标、分类、默认凭据名、localized 文案。
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
- [ ] Moonshot / Kimi: 查询余额和资源包。
- [ ] Zhipu / GLM: 查询账户余额和调用额度。
- [ ] MiniMax: 查询余额和 token 用量。
- [ ] Baidu Qianfan: 查询账户资源包。
- [ ] Tencent Hunyuan: 查询账户资源包。
- [ ] SiliconFlow: 查询余额和 API key 使用量。
- [ ] Anthropic: 当前不在主界面显示；只有在确认用户需要并能可靠查询 usage 后再重新评估。

## P4: 前端美学与交互

- [ ] 建立 Quota Radar 的 macOS 监控工具设计基准：
  - iStat Menus: 学习高密度但清晰的状态栏模块、刷新频率和设置分组。
  - Stats: 学习轻量原生、模块化、紧凑指标块和多语言覆盖。
  - Little Snitch Control Center: 学习状态栏里的诊断摘要、最近活动和快速操作。
  - Activity Monitor: 学习主窗口的表格、分组、过滤、摘要区和诊断型信息层级。
- [ ] 把 QuotaRadar 定位成 `iStat Menus for API quota`，不是 SaaS dashboard：
  - 数字优先：剩余量、总量、百分比、重置时间、更新时间优先于装饰。
  - 密度适中：状态栏只放最重要的 provider-level 信息，主窗口承载细节。
  - 原生材质：使用 macOS sidebar、toolbar、popover、分割线和 material，不使用营销页式大卡片和大渐变。
  - 操作就近：刷新、重新认证、测试连接、打开后台都贴近对应 provider。
- [ ] 主窗口继续向现代 macOS 风格靠拢：
  - 更清晰的 sidebar 层级。
  - 更少的重复信息。
  - provider banner 可点击折叠，不依赖三角图标。
  - 折叠动画保持原位压缩，不从上方飞入。
  - 额度监控页更接近 Activity Monitor：表格/分组 + 右侧或底部摘要，而不是重复卡片堆叠。
- [ ] 状态栏 popover 保持轻量：
  - AI Search 和 LLM 分组可折叠。
  - provider 内 key 按剩余额度排序。
  - key 显示前四位和后四位，不显示变量名。
  - 鼠标离开后自动收起，不激活主窗口。
  - LLM coding plan 显示多个周期中剩余比例最低的周期，而不是固定显示 5 小时周期。
  - 状态栏透明度设置必须在真实桌面背景下有可见效果，同时保留文字可读性。
  - 状态栏布局更接近 iStat Menus / Stats：紧凑指标、细分割、清晰层级，不滚动长 dashboard。
  - 状态栏弹出层整体风格要进一步向 Stats / iStat Menus 类监控工具靠拢：更紧凑的模块、更少大卡片、更清楚的指标层级和操作区。
- [ ] 图标系统继续围绕“额度焦虑”和“电量”隐喻：
  - App icon 更简洁，远看能识别电池/额度。
  - 状态栏 icon 在浅色、深色、透明菜单栏下都清晰。
  - 状态栏 popover 右上角操作图标要更现代、语义明确，避免像无差别的灰色圆形按钮。
  - provider icon 尽量使用官方图标，找不到时才用一致的 fallback。
- [ ] 增加视觉 QA checklist：
  - 13 寸屏幕、宽屏、外接屏。
  - 浅色/深色模式。
  - 中文/英文。
  - 长 provider 名、长错误信息、多个 key。
  - 文本不能遮挡或溢出。

## P5: 多平台与多语言

- [ ] 短期仍以 macOS 为主，保持 SwiftUI 原生状态栏体验。
- [ ] 如果要支持 Windows/Linux，先评估 Tauri 或 Electron，而不是直接把 SwiftUI 逻辑硬迁移。
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

1. [ ] 做一张 provider capability matrix。
   - 文件建议：新增 `docs/provider-capabilities.md` / `docs/provider-capabilities.en.md`。
   - 字段：provider、category、credential type、usage source、reset cycle、does check consume quota、diagnostic endpoint、notes。
2. [ ] 重构配置页为 provider-aware 表单。
   - 重点文件：`QuotaRadar/Models/APIKey.swift`、`QuotaRadar/Views/SettingsView.swift`、`QuotaRadar/Services/EnvImporter.swift`。
   - 目标：用户选择 provider 后，只看到该 provider 需要的字段。
3. [ ] 增加 cURL paste parser。
   - 重点文件：新增 `QuotaRadar/Services/CurlCredentialParser.swift`。
   - 目标：Querit、讯飞星火、火山引擎、OpenCode Go 可从浏览器复制的 cURL 自动提取 Cookie/headers。
4. [ ] 增加 per-provider connectivity test。
   - 重点文件：`QuotaRadar/Services/QuotaService.swift`、`QuotaRadar/Models/QuotaMonitor.swift`、`QuotaRadar/Views/SettingsView.swift`。
   - 目标：每个 provider 可单独检测凭据是否可用，并明确是否消耗额度。
5. [ ] 增加 proxy 设置。
   - 重点文件：`QuotaRadar/Models/AppAppearance.swift`、`QuotaRadar/Services/QuotaService.swift`、`QuotaRadar/Views/SettingsView.swift`。
   - 目标：支持系统代理、手动 HTTP/SOCKS 代理、禁用代理。
6. [ ] 做一轮主界面和状态栏 popover 视觉 QA。
   - 使用截图检查不同窗口大小、语言、深浅色模式。
   - 优先修遮挡、溢出、重复信息和折叠动画。

## 暂不优先

- [ ] 付费 Apple Developer ID 签名和 notarization。
- [ ] Windows/Linux 客户端。
- [ ] 远程同步凭据。
- [ ] 多用户团队看板。
