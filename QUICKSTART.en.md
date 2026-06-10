# Quota Radar Quickstart

<p align="right">
  Language:
  <a href="./QUICKSTART.md">简体中文</a> |
  <strong>English</strong>
</p>

## 1. Build

Run from the project root:

```bash
./install.sh --bundle-only --rebuild
open 'build/Quota Radar.app'
```

Install into `/Applications`:

```bash
./install.sh
```

## 2. Open The UI

Click the Quota Radar quota-radar icon in the macOS menu bar.

The Dock icon opens the main window; the menu bar popover gives quick quota visibility.

## 3. Configure Credentials

Open `Credentials` from the main window sidebar.

Normal providers use API keys. Exa uses a usage-query API key rather than a search invocation key. Querit, Claude, Codex, Kimi, XFYun Spark Coding Plan, Volcengine Coding Plan, OpenCode Go, and Aliyun/Tencent Cloud Coding Plan can store both an API key and web login authorization: API keys are for management and copying, while web login authorization is for quota monitoring.

The credential page separates `API Key` from `Quota monitoring authorization`: copy buttons appear only on API-key rows. Web login authorization is used only by Quota Radar to check quota and is not displayed or copied as an API key.

The `Credentials` page shows only providers with saved credentials. Add new, unconfigured providers from the top-level `Add Credential` action.

See the [Provider Capability Matrix](./docs/provider-capabilities.en.md) for what each provider exposes for quota, reset time, and plan end time.

## 4. Import From `.env`

Click the in-page `Import from .env` action and choose a file containing variables.

Example:

```env
TAVILY_API_KEY=...
BRAVE_API_KEY=...
DEEPSEEK_API_KEY=...
QUERIT_API_KEY=...
QUERIT_COOKIE=...
XFYUN_CODING_PLAN_COOKIE=...
VOLCENGINE_CODING_PLAN_COOKIE=...
OPENCODE_GO_COOKIE=...
ALIYUN_CODING_PLAN_API_KEY=...
TENCENT_CLOUD_CODING_PLAN_API_KEY=...
```

The `...` values are placeholders. Do not commit real `.env` files, cookies, or API keys.

For web-login authorization providers, prefer in-app reauthentication or paste a browser-copied cURL command when adding a credential. Aliyun/Tencent Cloud Coding Plan business API keys are not quota-query credentials.

## 5. Monitor Quotas

The `Quota Overview` page shows quota summaries for configured providers only. Providers without saved credentials do not appear as placeholders in `Quota Overview`, `Credentials`, or `Diagnostics`.

The menu bar popover prioritizes today's quota risk, expiring credentials, and items needing attention, with quick refresh for individual providers.

## 6. Settings

Use `Settings` to switch Simplified Chinese, Traditional Chinese, English, Japanese, and Korean; adjust menu bar popover transparency; configure launch at login; enable automatic update checks; set the network proxy; and set automatic refresh intervals. Automatic refresh can also be turned off.

Network proxy supports System, Direct, and Custom. Custom proxy accepts values such as `http://127.0.0.1:7890` or `socks5://127.0.0.1:7890`.

To keep frequently used providers near the top, enable `Custom Provider Order`, click `Configure`, and drag provider rows. This order is shared by Quota Overview, Credentials, Diagnostics, and the menu bar popover.

The lower-left corner of the main window shows the installed version and update status. When automatic update checks are enabled, the app only checks GitHub Releases. If a new version is available, Quota Radar shows release notes and does not download silently. It downloads the DMG and replaces the installed app only after you click `Download and Install`.

## 7. Local Data Locations

Secret file:

```text
~/Library/Application Support/QuotaRadar/secrets.json
```

This file is outside the repository and should never be pushed to GitHub.

## 8. Test

```bash
bash Tests/run_behavior_tests.sh
```

To install the existing bundle without rebuilding:

```bash
./install.sh
```

If source code changed, rebuild explicitly:

```bash
./install.sh --rebuild
```
