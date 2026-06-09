# Quota Radar

<p align="right">
  Language:
  <a href="./README.md">简体中文</a> |
  <strong>English</strong>
</p>

Quota Radar is a macOS menu bar app for monitoring search API and LLM coding-plan quota status without repeatedly logging in to provider dashboards.

Quota Radar currently supports macOS, with macOS 14.0 as the minimum supported version.

Naming convention: the GitHub repository, Swift package, and DMG use `QuotaRadar`; the macOS app display name and app bundle use `Quota Radar`.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

Current version: `v0.3.0`.

See [TODO / Roadmap](./TODO.en.md) for the next development plan.

For credential type, usage source, and automatic-refresh constraints by provider, see the [Provider Capability Matrix](./docs/provider-capabilities.en.md).

## What's New In v0.3.0

- Quota Radar now behaves more like a quota radar: the main window and menu bar summarize providers first, so it is easier to see what still works, what is low, and what failed.
- API keys and web login authorizations are managed separately. API keys can be stored and copied; web login authorization is used only for quota checks and is not displayed as an API key.
- Business invocation keys can be paired with quota-monitoring authorization. For example, Aliyun, Tencent Cloud, and Querit API keys can be stored for management, while quota checks still use the verified web login authorization path.
- Codex, Claude, Aliyun Coding Plan, Tencent Cloud Coding Plan, XFYun Spark, Volcengine, and related providers now have clearer documentation for what exposes quota, reset times, plan end times, or subscription state only.
- Chinese and English screenshots, the provider capability matrix, and unsigned-DMG release notes were refreshed. Release preparation includes behavior tests and a secret scan.

## Screenshots

<p align="center">
  <img src="./docs/assets/screenshots/en/quota-overview.png" alt="Quota Radar quota overview window" width="920">
</p>

<p align="center">
  <em>The main window summarizes remaining quota, total quota, and health status by provider. Screenshots are captured from the running app, with credentials masked by Quota Radar.</em>
</p>

<p align="center">
  <img src="./docs/assets/screenshots/en/menu-bar-popover.png" alt="Quota Radar menu bar popover" width="620">
</p>

<p align="center">
  <em>The menu bar popover keeps the most important quota signals visible without interrupting your current work.</em>
</p>

## Features

- Frosted-glass menu bar popover grouped by `AI Search` and `LLM`.
- Supports multiple providers and credentials, with credentials sorted by remaining quota inside each provider.
- Supports API keys and web login authorizations.
- Imports supported credentials from `.env` or `~/.claude/settings.json`.
- Supports launch at login, configurable automatic refresh intervals, and fully disabling automatic refresh.
- Stores secrets in `~/Library/Application Support/QuotaRadar/secrets.json` with `0600` permissions; preferences store metadata only.

## Supported Providers

### AI Search

| Provider | Notes |
| --- | --- |
| Tavily | Monthly credits, normally reset on day 1 |
| Brave Search | Quota from search response headers |
| SerpAPI | Account API |
| Serper | Account API returns balance and rateLimit; reset/end times are not exposed |
| Exa | Admin API usage cost; search keys do not expose usage directly |
| Bocha | CNY balance API |
| AnySearch | Treated as free unlimited usage |
| Querit | Web login authorization; monthly usage is readable, but plan limit/reset/end are not exposed |
| WeChat Search | Remaining CNY account balance |

### LLM / Plans

| Provider | Credential Type |
| --- | --- |
| Claude | Subscription web login authorization can be stored; API Usage is hidden until an admin usage monitor is configured |
| Codex | Subscription web login authorization can be stored; Codex Cloud five-hour/weekly refresh and plan expiry are wired |
| DeepSeek | API key, shown as CNY account balance |
| XFYun Spark Coding Plan | Web login authorization, 5-hour/weekly/monthly request-count windows implemented |
| Volcengine Coding Plan | Web login authorization, quota cycles implemented |
| OpenCode Go | Web login authorization |
| Aliyun Coding Plan | Web login authorization, subscription-state checks implemented; if the dashboard exposes 5-hour/weekly/monthly request counts, Quota Radar renders them with the shared model |
| Tencent Cloud Coding Plan | Web login authorization, dashboard `cgi/capi?cmd=DescribePkg&serviceType=hunyuan` subscription/request-count cycles implemented |

XFYun Spark Token Plan currently looks like seat/count quota, Aliyun Token Plan is expected to be credits-based, Tencent Cloud Token Plan keeps an official API parser but lacks a real user key sample, and Volcengine Token Plan still needs a stable usage endpoint. These Token Plan integrations remain modeled as code extension points, but they are hidden from the main UI and credential imports until usable quota fields and real credential samples are confirmed. See the [Provider Capability Matrix](./docs/provider-capabilities.en.md) for browser/API-verified `quota`, `resetAt`, and `planEndsAt` conclusions.

## Requirements

- macOS 14.0 or newer
- Xcode or Command Line Tools
- Swift 5.9

## Build And Install

```bash
./install.sh --bundle-only --rebuild
open 'build/Quota Radar.app'
```

Install into `/Applications`:

```bash
./install.sh
```

`./install.sh` reuses the existing `build/Quota Radar.app` by default. Use `--rebuild` when you need a fresh build.

See [Quickstart](./QUICKSTART.en.md) for the full flow.

## DMG Packaging And Gatekeeper

Local, self-use, or no-fee unsigned DMG:

```bash
scripts/package_dmg.sh --rebuild
open build/QuotaRadar.dmg
```

Manual GitHub Release upload:

```bash
gh release create v0.3.0 build/QuotaRadar.dmg \
  --title "Quota Radar v0.3.0" \
  --notes "Unsigned DMG for trusted users. macOS may require removing quarantine on first launch."
```

You can also push a tag and let GitHub Actions build the unsigned DMG and upload it to the Release:

```bash
git tag v0.3.0
git push origin v0.3.0
```

An unsigned DMG does not require Apple Developer Program membership, but macOS Gatekeeper may block the downloaded app. Install it only if you trust this source repository and release. If macOS says the app is damaged or cannot be opened, move the app into `/Applications` and run:

```bash
xattr -dr com.apple.quarantine '/Applications/Quota Radar.app'
open '/Applications/Quota Radar.app'
```

For broader distribution to other Macs, the reliable way to avoid "damaged app" Gatekeeper warnings is still Developer ID signing plus Apple notarization:

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
NOTARYTOOL_PROFILE="notary-profile" \
scripts/package_dmg.sh --rebuild --notarize
```

Without Developer ID signing and notarization, the DMG is suitable only for local, source-auditable GitHub, or otherwise trusted environments; downloaded copies may still be blocked by Gatekeeper.

## Usage

1. Click the menu bar quota-radar icon to open the quota panel.
2. Open `Credentials` to add credentials or import from `.env`.
3. Use API keys for normal providers. Exa requires a Team Management service key plus the target API key id. Querit API keys can be stored for copying, but quota monitoring still requires web login authorization. XFYun Spark Coding Plan, Volcengine Coding Plan, and OpenCode Go also use web login authorizations. Aliyun/Tencent Cloud Coding Plan business API keys can be stored for display/copying, but quota monitoring still requires reauthentication to capture web login authorization.
4. Click a provider-level refresh button to update that provider.

Use `Settings` to switch language, tune menu bar transparency, configure launch at login, and choose an automatic refresh interval. Automatic refresh can be disabled; providers such as Brave that consume a real search request are skipped by automatic refresh.

## `.env` Import

Supported variable names include:

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

For web-login authorization providers, prefer the in-app re-authentication flow. You can also paste a browser-copied cURL command in the credential form so Quota Radar can extract the required login authorization fields. Never commit real authorization data to Git.

Claude / Codex are split into subscription quota and API Usage. The main UI currently hides Claude/Codex API Usage to avoid dead placeholders when no admin usage monitor is configured; Claude/Codex subscription quota uses web login authorization. Claude currently exposes subscription tier and authorization state, but no stable five-hour/weekly/monthly remaining-quota endpoint is confirmed. Codex Cloud first resolves a ChatGPT session access token through `/api/auth/session`, then calls `/backend-api/wham/usage` for five-hour/weekly windows and reset times, and uses `/backend-api/subscriptions?account_id=...` `active_until` for plan expiry. The current usage response does not expose a monthly window.

Exa search API keys cannot query usage. To monitor Exa, use a Team Management service key plus the target API key id; Quota Radar displays the selected key's usage cost for the configured period.
Querit `QUERIT_API_KEY` values can be stored and copied as API keys, but they cannot query dashboard account usage. Quota monitoring still requires web login authorization. The current Querit account endpoint returns monthly usage, but not the plan limit, reset time, or end date.

```env
VOLCENGINE_CODING_PLAN_COOKIE='{"cookie":"<cookie-header-value>","csrfToken":"<csrf-token>","projectName":"default"}'
OPENCODE_GO_COOKIE='{"cookie":"<cookie-header-value>","workspaceID":"wrk_example","serverID":"server-example","serverInstance":"server-fn:11"}'
```

Aliyun Coding Plan and Tencent Cloud Coding Plan business keys can be stored and shown, but quota monitoring uses web login authorizations. Aliyun Coding Plan checks subscription status through `aliclaw.coding-plan`; no subscription is shown as "No subscribed plan", and active subscriptions show "Usable · quota unknown" when the dashboard does not expose usage details. If Aliyun exposes 5-hour/weekly/monthly request-count windows, Quota Radar renders remaining/total counts with the same model used by XFYun Spark and Tencent Cloud. Tencent Cloud Coding Plan uses dashboard `cgi/capi?cmd=DescribePkg&serviceType=hunyuan`; subscribed packages can expose request counts, quota-window reset times, and the package end time. XFYun Spark Token Plan, Aliyun Token Plan, and Tencent Cloud Token Plan still need non-empty package or real-key samples before quota fields can be trusted; Volcengine Token Plan remains hidden until a stable usage endpoint is confirmed.

## Claude Code Import

On first launch, if no credentials are configured, Quota Radar reads the `env` section from `~/.claude/settings.json` and imports supported variables.

Imported secret values go into Quota Radar's local secret file; source code and preferences do not store real keys.

## Architecture

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

## Adding A Provider

Adding a provider usually requires changes in:

- `QuotaRadar/Models/APIKey.swift`: provider case, category, icon, credential type, dashboard URL, reset summary.
- `QuotaRadar/Services/EnvImporter.swift`: environment-variable detection.
- `QuotaRadar/Services/QuotaService.swift`: quota check and parser.
- `QuotaRadar/Services/CurlCredentialParser.swift`: cURL parsing for web-login providers.
- `QuotaRadar/Assets.xcassets/ProviderIcons/`: provider icon assets.
- `Tests/run_behavior_tests.sh`: behavior and parser coverage.

## Tests

```bash
bash Tests/run_behavior_tests.sh
```

The script runs source safety checks, provider icon checks, importer/parser behavior tests, SwiftPM build, and bundle creation.

## Privacy

- No real API keys, cookies, or tokens are embedded.
- Real credentials are stored only under the user's local `Application Support/QuotaRadar`.
- All requests go directly to the provider; there is no proxy server.

## License

MIT
