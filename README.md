# Quota Radar

<p align="right">
  Language:
  <strong>English</strong> |
  <a href="./README.zh-Hans.md">简体中文</a>
</p>

Quota Radar is a macOS menu bar app for monitoring search API balances and LLM coding-plan quotas. It is designed like a compact monitoring utility: the menu bar shows the smallest actionable signal, the popover triages risk, and the main window explains current quota, activity, timing, status, and actions.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

Current version: `v0.3.5`.

## Screenshots

<p align="center">
  <img src="./docs/assets/screenshots/en/quota-overview.png" alt="Quota Radar quota overview window" width="920">
</p>

<p align="center">
  <em>The main window shows provider-level Current, Activity, Time, Status, and actions; expanded accounts are compressed into Plan, Remaining, Critical Time, and Updated. Screenshots are captured from the running app, with credentials masked by Quota Radar.</em>
</p>

<p align="center">
  <img src="./docs/assets/screenshots/en/menu-bar-popover.png" alt="Quota Radar menu bar popover" width="620">
</p>

<p align="center">
  <em>The menu bar popover keeps the most important quota signals visible without turning into a dashboard.</em>
</p>

## Features

- Risk-first menu bar popover for low quota, expiring plans, failed checks, and recent activity.
- Main quota overview organized by `Provider`, `Current`, `Activity`, `Time`, `Status`, and actions.
- Multiple accounts per provider, with account-level plan, remaining quota, reset/expiry timing, and update time.
- API-key and web-login authorization credentials, including companion API keys for providers whose quota checks require web login.
- Local secret storage in `~/Library/Application Support/QuotaRadar/secrets.json` with `0600` permissions.
- `.env`, cURL, and `~/.claude/settings.json` import paths for supported providers.
- Configurable automatic refresh, quota-consuming refresh protection, proxy settings, launch at login, and GitHub Release update checks.

## Quick Start

```bash
./install.sh --bundle-only --rebuild
open 'build/Quota Radar.app'
```

Install into `/Applications`:

```bash
./install.sh
```

Run behavior tests:

```bash
bash Tests/run_behavior_tests.sh
```

For the full setup flow, see [Quickstart](./docs/quickstart.md).

## Supported Providers

AI Search providers include Tavily, Brave Search, SerpAPI, Serper, Exa, Bocha, AnySearch, Querit, and WeChat Search.

LLM / plan providers include Claude Subscription, Codex Subscription, Kimi, DeepSeek, XFYun Spark Coding Plan, Volcengine Coding Plan, OpenCode Go, Aliyun Coding Plan, and Tencent Cloud Coding Plan.

Provider credential types, quota fields, reset windows, plan expiry, parser notes, and hidden extension stubs are documented in [Providers](./docs/providers.md).

## Documentation

- [Quickstart](./docs/quickstart.md)
- [Providers](./docs/providers.md)
- [Roadmap](./docs/roadmap.md)
- [中文 README](./README.zh-Hans.md)

## Unsigned DMG And Gatekeeper

Local, self-use, or no-fee unsigned DMG:

```bash
scripts/package_dmg.sh --rebuild
open build/QuotaRadar.dmg
```

Manual GitHub Release upload:

```bash
gh release create v0.3.5 build/QuotaRadar.dmg \
  --title "Quota Radar v0.3.5" \
  --notes "Unsigned DMG for trusted users. macOS may require removing quarantine on first launch."
```

Unsigned DMGs do not require an Apple Developer Program account, but macOS Gatekeeper may block downloaded copies. Install only if you trust the source repository and release. If macOS says the app is damaged or cannot be opened:

```bash
xattr -dr com.apple.quarantine '/Applications/Quota Radar.app'
open '/Applications/Quota Radar.app'
```

For broader distribution, use Developer ID signing and Apple notarization.
