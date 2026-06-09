# Quota Radar

<p align="right">
  语言：
  <strong>简体中文</strong> |
  <a href="./README.en.md">English</a>
</p>

Quota Radar 是一个 macOS 状态栏应用，用来观察搜索 API 与 LLM coding plan 的额度状态，减少反复登录各家后台查询额度的成本。

当前支持 macOS，最低版本为 macOS 14.0。

命名约定：GitHub 仓库、Swift package 和 DMG 使用 `QuotaRadar`；macOS App 显示名和 bundle 名使用 `Quota Radar`。

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

当前版本：`v0.3.0`。

下一阶段计划见 [TODO / Roadmap](./TODO.md)。

服务商凭据类型、额度来源和自动刷新限制见 [Provider Capability Matrix](./docs/provider-capabilities.md)。

## v0.3.0 新特性

- 更像一个“额度雷达”：主窗口和状态栏都先按 provider 汇总，直接看到哪些还能用、哪些快用完、哪些检查失败。
- API Key 和网页登录授权分开管理：API Key 可以保存和复制；网页登录授权只用于查询额度，不会当成 API Key 展示。
- 支持把“业务调用 key”和“额度监控授权”配对展示。比如阿里云、腾讯云、Querit 可以保存 API Key 方便管理，但额度查询仍使用已验证的网页登录授权。
- Codex、Claude、阿里云 coding plan、腾讯云 coding plan、讯飞星火、火山引擎等 provider 的接口边界重新梳理，文档里写清楚哪些能查额度、哪些能查重置时间、哪些只能确认订阅状态。
- 更新中英文截图、provider capability matrix 和未签名 DMG 发布说明，发布前会做测试和密钥扫描。

## 界面预览

<p align="center">
  <img src="./docs/assets/screenshots/zh-Hans/quota-overview.png" alt="Quota Radar 主程序额度监控概览" width="920">
</p>

<p align="center">
  <em>主窗口以 provider 为单位展示剩余额度、总量和健康状态；截图来自真实运行画面，密钥由应用自动打码。</em>
</p>

<p align="center">
  <img src="./docs/assets/screenshots/zh-Hans/menu-bar-popover.png" alt="Quota Radar 状态栏弹窗" width="620">
</p>

<p align="center">
  <em>状态栏弹窗保留最重要的额度信号，适合随手查看而不打断当前工作。</em>
</p>

## 功能

- 状态栏磨砂玻璃弹窗，按 `AI Search` 和 `LLM` 分组展示额度。
- 支持多个 provider、多个凭据，并按 provider 内剩余额度排序。
- 支持 API 密钥与网页登录授权两类凭据。
- 可从 `.env` 或 `~/.claude/settings.json` 导入支持的凭据。
- 支持开机自启动、自动刷新间隔配置，也可以完全关闭自动刷新。
- 真实凭据存储在 `~/Library/Application Support/QuotaRadar/secrets.json`，权限为 `0600`；偏好设置只保存 metadata。

## 支持的服务商

### AI Search

| Provider | 说明 |
| --- | --- |
| Tavily | 月度 credits，通常每月 1 日重置 |
| Brave Search | 搜索响应 header 额度 |
| SerpAPI | Account API |
| Serper | Account API，返回余额和 rateLimit；不暴露重置/结束时间 |
| Exa | Team Management 用量 API 查询已用成本；普通 search key 不直接暴露用量 |
| Bocha | 人民币余额 API |
| AnySearch | 当前按免费无限处理 |
| Querit | 网页登录授权，可读月度已用量；不暴露套餐上限、重置/结束时间 |
| 微信搜索 | 账户剩余人民币金额 |

### LLM / Plans

| Provider | 凭据类型 |
| --- | --- |
| Claude | 订阅网页登录授权可保存；API Usage 暂不展示，额度接口待确认 |
| Codex | 订阅网页登录授权可保存；Codex Cloud 已接入 5 小时/周窗口刷新与套餐到期日期 |
| DeepSeek | API Key，展示人民币账户余额 |
| 讯飞星火 coding plan | 网页登录授权，按 5 小时/周/月请求次数展示额度周期 |
| 火山引擎 coding plan | 网页登录授权，已接入额度周期 |
| OpenCode Go | 网页登录授权 |
| 阿里云 coding plan | 网页登录授权，已接入订阅状态检查；若接口暴露 5 小时/周/月请求次数则按同口径展示 |
| 腾讯云 coding plan | 网页登录授权，已接入控制台 `cgi/capi?cmd=DescribePkg&serviceType=hunyuan` 订阅/请求次数周期 |

讯飞星火 Token plan 当前看起来是座席/次数额度，阿里云 Token plan 预期是积分/credits 类额度；腾讯云 Token plan 已保留官方 API 解析器但缺少真实用户 key 样本；火山引擎 Token plan 仍待确认稳定用量接口。这些 Token plan 已保留代码扩展接口，但在确认可用额度字段和真实凭据样本前不会出现在主界面或配置导入中。各 provider 的 `quota`、`resetAt`、`planEndsAt` 浏览器/API 验证结论见 [Provider Capability Matrix](./docs/provider-capabilities.md)。

## 要求

- macOS 14.0 或更高版本
- Xcode 或 Command Line Tools
- Swift 5.9

## 构建与安装

```bash
./install.sh --bundle-only --rebuild
open 'build/Quota Radar.app'
```

复制到 `/Applications`：

```bash
./install.sh
```

`./install.sh` 默认复用已有 `build/Quota Radar.app`，需要重新构建时使用 `--rebuild`。

更多步骤见 [快速启动](./QUICKSTART.md)。

## DMG 打包与 Gatekeeper

本机自用或不付费发布的未签名 DMG：

```bash
scripts/package_dmg.sh --rebuild
open build/QuotaRadar.dmg
```

手动发布到 GitHub Release：

```bash
gh release create v0.3.0 build/QuotaRadar.dmg \
  --title "Quota Radar v0.3.0" \
  --notes "Unsigned DMG for trusted users. macOS may require removing quarantine on first launch."
```

也可以直接推送 tag，仓库的 GitHub Actions 会自动构建未签名 DMG 并上传到 Release：

```bash
git tag v0.3.0
git push origin v0.3.0
```

未签名 DMG 不需要 Apple Developer Program，但从 GitHub 下载后可能被 macOS Gatekeeper 拦截。只在信任该源码和 release 的情况下安装；如果提示“App 已损坏”或“无法打开”，先把 app 拖到 `/Applications`，再执行：

```bash
xattr -dr com.apple.quarantine '/Applications/Quota Radar.app'
open '/Applications/Quota Radar.app'
```

如果要发给更广泛的 Mac 用户，避免出现“App 已损坏，无法打开”的可靠方式仍然是使用 Apple Developer ID 签名并完成 notarization：

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
NOTARYTOOL_PROFILE="notary-profile" \
scripts/package_dmg.sh --rebuild --notarize
```

没有 Developer ID 签名和公证的 DMG 只适合本机、GitHub 源码可审计或其他受信任环境使用；跨机器下载后仍可能被 Gatekeeper 拦截。

## 使用

1. 点击状态栏余量雷达图标打开额度面板。
2. 进入 `配置凭据`，添加凭据或从 `.env` 导入。
3. 普通服务商填 API 密钥；Exa 需要 Team Management service key 和目标 API key id；Querit 可保存 API Key 方便复制，但额度监控仍需要网页登录授权；讯飞星火 coding plan、火山引擎 coding plan 和 OpenCode Go 也使用网页登录授权。阿里云/腾讯云 coding plan 可先保存业务 API Key 方便展示和复制，但额度监控仍需要通过重新认证获取网页登录授权。
4. 点击单个 provider 的刷新按钮更新该 provider。

在 `设置` 页面可以切换语言、调节状态栏透明度、配置开机自启动和自动刷新间隔。自动刷新支持关闭；Brave 这类会消耗真实搜索请求的 provider 会跳过自动刷新。

## `.env` 导入

支持的变量名包括：

```env
TAVILY_API_KEY=...
BRAVE_API_KEY=...
SERPAPI_API_KEY=...
SERPER_API_KEY=...
EXA_API_KEY=...
EXA_ADMIN_CREDENTIAL='{"serviceKey":"<exa-admin-service-key>","apiKeyId":"<target-api-key-id>","days":30}'
BOCHA_API_KEY=...
ANYSEARCH_API_KEY=...
QUERIT_API_KEY=...
QUERIT_COOKIE=...
WX_MP_SEARCH_API_KEY=...
WECHAT_API_KEY=...
DEEPSEEK_API_KEY=...
XFYUN_CODING_PLAN_COOKIE=...
VOLCENGINE_CODING_PLAN_COOKIE=...
OPENCODE_GO_COOKIE=...
ALIYUN_CODING_PLAN_API_KEY=...
TENCENT_CLOUD_CODING_PLAN_API_KEY=...
```

网页登录授权类服务商建议使用应用内“重新认证”。也可以在配置页粘贴浏览器复制的 cURL，让 Quota Radar 自动提取所需登录授权字段。不要把真实授权信息提交到 Git。

Claude / Codex 拆成订阅额度和 API Usage 两类。当前主界面先隐藏 Claude/Codex API Usage，避免在没有 Admin 用量监控时显示无效占位；Claude/Codex 订阅额度使用网页登录授权。Claude 当前只确认订阅层级和授权状态，尚未确认稳定的 5 小时/周/月剩余额度接口。Codex Cloud 会先通过 `/api/auth/session` 解析 ChatGPT 会话 access token，再调用 `/backend-api/wham/usage` 显示 5 小时/周窗口与重置时间，并用 `/backend-api/subscriptions?account_id=...` 的 `active_until` 显示套餐到期日期；当前响应未见月窗口。

Exa 的普通 search API key 不能查询用量。若要监控 Exa，请在 Team Management 里使用 service API key 和目标 API key id，Quota Radar 会显示该 key 在指定周期内的已用成本。
Querit 的 `QUERIT_API_KEY` 可以作为 API 密钥保存和复制，但不能查询 dashboard account 用量；额度监控请同时配置网页登录授权。当前 Querit 账户接口只能读到月度已用量，不返回套餐上限、重置时间或结束日期。

```env
VOLCENGINE_CODING_PLAN_COOKIE='{"cookie":"<cookie-header-value>","csrfToken":"<csrf-token>","projectName":"default"}'
OPENCODE_GO_COOKIE='{"cookie":"<cookie-header-value>","workspaceID":"wrk_example","serverID":"server-example","serverInstance":"server-fn:11"}'
```

阿里云 coding plan 和腾讯云 coding plan 的业务 key 可以保存和展示，但额度监控使用网页登录授权。阿里云 coding plan 当前通过 `aliclaw.coding-plan` 判断订阅状态；未订阅显示“未发现订阅套餐”，订阅有效但接口未暴露用量明细时显示“可用 · 额度未知”；如果接口返回 5 小时/周/月请求次数窗口，会按讯飞星火和腾讯云同口径显示剩余次数/总次数。腾讯云 coding plan 使用控制台 `cgi/capi?cmd=DescribePkg&serviceType=hunyuan`，有套餐时可解析多个周期的请求次数、重置时间和套餐结束时间。讯飞星火 Token plan、阿里云 Token plan 和腾讯云 Token plan 仍需要非空套餐/真实 key 样本确认额度字段；火山引擎 Token plan 在确认稳定额度接口前仍保持隐藏。

## Claude Code 初始化

首次启动且尚未配置凭据时，Quota Radar 会读取 `~/.claude/settings.json` 的 `env` 字段并导入支持的变量。

导入后的真实值进入 Quota Radar 的本地 secret 文件；源码和偏好设置不保存真实密钥。

## 架构

```text
QuotaRadar/
├── Models/
│   ├── APIKey.swift
│   ├── AppAppearance.swift
│   ├── AppLanguage.swift
│   └── QuotaMonitor.swift
├── Services/
│   ├── APIKeyStore.swift
│   ├── FileSecretStore.swift
│   ├── QuotaService.swift
│   ├── EnvImporter.swift
│   └── DashboardReauth.swift
├── Views/
│   ├── Components.swift
│   ├── MenuContentView.swift
│   └── SettingsView.swift
├── AppDelegate.swift
└── QuotaRadarApp.swift
```

## 新增 Provider

新增 provider 通常需要修改：

- `QuotaRadar/Models/APIKey.swift`: provider case、category、icon、credential type、dashboard URL、reset summary。
- `QuotaRadar/Services/EnvImporter.swift`: 环境变量识别。
- `QuotaRadar/Services/QuotaService.swift`: 额度检查和解析逻辑。
- `QuotaRadar/Services/CurlCredentialParser.swift`: 网页登录授权 provider 的 cURL 解析。
- `QuotaRadar/Assets.xcassets/ProviderIcons/`: provider 图标资源。
- `Tests/run_behavior_tests.sh`: 行为测试和 parser 覆盖。

## 测试

```bash
bash Tests/run_behavior_tests.sh
```

该脚本会做源码安全检查、图标资源检查、导入/解析行为测试、SwiftPM 编译和 bundle 构建。

## 隐私

- 不内置任何真实 API Key、Cookie 或 token。
- 真实凭据仅存储在用户本机 `Application Support/QuotaRadar`。
- 所有请求直接发送到对应 provider，没有中间服务器。

## License

MIT
