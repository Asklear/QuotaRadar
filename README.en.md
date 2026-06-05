# QuotaBar

<p align="right">
  Language:
  <a href="./README.md">简体中文</a> |
  <strong>English</strong>
</p>

QuotaBar is a macOS menu bar app for monitoring search API and LLM coding-plan quota status without repeatedly logging in to provider dashboards.

QuotaBar currently supports macOS, with macOS 14.0 as the minimum supported version.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

Current version: `v0.1.3`.

See [TODO / Roadmap](./TODO.en.md) for the next development plan.

## Screenshots

<p align="center">
  <img src="./docs/assets/screenshots/quota-overview.png" alt="QuotaBar quota overview window" width="920">
</p>

<p align="center">
  <em>The main window summarizes remaining quota, total quota, and health status by provider. Screenshots are captured from the running app, with credentials masked by QuotaBar.</em>
</p>

<p align="center">
  <img src="./docs/assets/screenshots/menu-bar-popover.png" alt="QuotaBar menu bar popover" width="620">
</p>

<p align="center">
  <em>The menu bar popover keeps the most important quota signals visible without interrupting your current work.</em>
</p>

## Features

- Frosted-glass menu bar popover grouped by `AI Search` and `LLM`.
- Supports multiple providers and credentials, with credentials sorted by remaining quota inside each provider.
- Supports both API keys and dashboard-session cookies.
- Imports supported credentials from `.env` or `~/.claude/settings.json`.
- Supports launch at login, configurable automatic refresh intervals, and fully disabling automatic refresh.
- Stores secrets in `~/Library/Application Support/QuotaBar/secrets.json` with `0600` permissions; preferences store metadata only.

## Supported Providers

### AI Search

| Provider | Notes |
| --- | --- |
| Tavily | Monthly credits, normally reset on day 1 |
| Brave Search | Quota from search response headers |
| SerpAPI | Account API |
| Serper | Account API |
| Exa | Admin API usage cost; search keys do not expose usage directly |
| Bocha | Balance API |
| AnySearch | Treated as free unlimited usage |
| Querit | Manual dashboard check |
| WeChat Search | Remaining account balance |

### LLM / Coding Plan

| Provider | Credential Type |
| --- | --- |
| DeepSeek | API Key |
| XFYun Spark | Dashboard session cookie |
| Volcengine | Dashboard session cookie |
| OpenCode Go | Dashboard session cookie |

## Requirements

- macOS 14.0 or newer
- Xcode or Command Line Tools
- Swift 5.9

## Build And Install

```bash
./install.sh --bundle-only --rebuild
open build/QuotaBar.app
```

Install into `/Applications`:

```bash
./install.sh
```

`./install.sh` reuses the existing `build/QuotaBar.app` by default. Use `--rebuild` when you need a fresh build.

See [Quickstart](./QUICKSTART.en.md) for the full flow.

## DMG Packaging And Gatekeeper

Local, self-use, or no-fee unsigned DMG:

```bash
scripts/package_dmg.sh --rebuild
open build/QuotaBar.dmg
```

Manual GitHub Release upload:

```bash
gh release create v0.1.3 build/QuotaBar.dmg \
  --title "QuotaBar v0.1.3" \
  --notes "Unsigned DMG for trusted users. macOS may require removing quarantine on first launch."
```

You can also push a tag and let GitHub Actions build the unsigned DMG and upload it to the Release:

```bash
git tag v0.1.3
git push origin v0.1.3
```

An unsigned DMG does not require Apple Developer Program membership, but macOS Gatekeeper may block the downloaded app. Install it only if you trust this source repository and release. If macOS says the app is damaged or cannot be opened, move the app into `/Applications` and run:

```bash
xattr -dr com.apple.quarantine /Applications/QuotaBar.app
open /Applications/QuotaBar.app
```

For broader distribution to other Macs, the reliable way to avoid "damaged app" Gatekeeper warnings is still Developer ID signing plus Apple notarization:

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
NOTARYTOOL_PROFILE="notary-profile" \
scripts/package_dmg.sh --rebuild --notarize
```

Without Developer ID signing and notarization, the DMG is suitable only for local, source-auditable GitHub, or otherwise trusted environments; downloaded copies may still be blocked by Gatekeeper.

## Usage

1. Click the menu bar battery icon to open the quota panel.
2. Open `Credentials` to add credentials or import from `.env`.
3. Use API keys for normal providers; use dashboard-session cookies for XFYun, Volcengine, and OpenCode Go.
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
QUERIT_COOKIE=...
WX_MP_SEARCH_API_KEY=...
WECHAT_API_KEY=...
DEEPSEEK_API_KEY=...
XFYUN_CODING_PLAN_COOKIE=...
VOLCENGINE_CODING_PLAN_COOKIE=...
OPENCODE_GO_COOKIE=...
```

For dashboard-session providers, paste only the Cookie header value or use a JSON placeholder shape. Never commit real cookies to Git.

Exa search API keys cannot query usage. To monitor Exa, use a Team Management Admin API service key plus the target API key id; QuotaBar displays the selected key's usage cost for the configured period.
Querit requires a dashboard-session Cookie; a plain `QUERIT_API_KEY` cannot query dashboard account usage.

```env
VOLCENGINE_CODING_PLAN_COOKIE='{"cookie":"<cookie-header-value>","csrfToken":"<csrf-token>","projectName":"default"}'
OPENCODE_GO_COOKIE='{"cookie":"<cookie-header-value>","workspaceID":"wrk_example","serverID":"server-example","serverInstance":"server-fn:11"}'
```

## Claude Code Import

On first launch, if no credentials are configured, QuotaBar reads the `env` section from `~/.claude/settings.json` and imports supported variables.

Imported secret values go into QuotaBar's local secret file; source code and preferences do not store real keys.

## Architecture

```text
QuotaBar/
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
└── QuotaBarApp.swift
```

## Adding A Provider

Adding a provider usually requires changes in:

- `QuotaBar/Models/APIKey.swift`: provider case, category, icon, credential type, dashboard URL, reset summary.
- `QuotaBar/Services/EnvImporter.swift`: environment-variable detection.
- `QuotaBar/Services/QuotaService.swift`: quota check and parser.
- `QuotaBar/Assets.xcassets/ProviderIcons/`: provider icon assets.
- `Tests/run_behavior_tests.sh`: behavior and parser coverage.

## Tests

```bash
bash Tests/run_behavior_tests.sh
```

The script runs source safety checks, provider icon checks, importer/parser behavior tests, SwiftPM build, and bundle creation.

## Privacy

- No real API keys, cookies, or tokens are embedded.
- Real credentials are stored only under the user's local `Application Support/QuotaBar`.
- All requests go directly to the provider; there is no proxy server.

## License

MIT
