# Quota Radar Quickstart

<p align="right">
  Language:
  <a href="./quickstart.zh-Hans.md">简体中文</a> |
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

Build a white-label bundle with update checks removed:

```bash
./install.sh --bundle-only --rebuild --white-label
scripts/package_dmg.sh --rebuild --white-label
```

## 2. Open The UI

Click the Quota Radar quota-radar icon in the macOS menu bar.

The Dock icon opens the main window; the menu bar popover gives quick quota visibility.

## 3. Configure Credentials

Open `Credentials` from the main window sidebar.

Normal providers use API keys. Exa uses a usage-query API key rather than a search invocation key. Querit, Claude, Codex, Kimi, LongCat, XFYun Spark Coding Plan, Volcengine Coding Plan, OpenCode Go, and Aliyun/Tencent Cloud Coding Plan can store both an API key and web login authorization: API keys are for management and copying, while web login authorization is for quota monitoring.

The credential page separates `API Key` from `Quota monitoring authorization`: copy buttons appear only on API-key rows. Web login authorization is used only by Quota Radar to check quota and is not displayed or copied as an API key.

The `Credentials` page shows only providers with saved credentials. Add new, unconfigured providers from the top-level `Add Credential` action.

See [Providers](./providers.md) for what each provider exposes for quota, reset time, and plan end time.

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
LONGCAT_SESSION=...
LONGCAT_API_KEY=...
ALIYUN_CODING_PLAN_API_KEY=...
TENCENT_CLOUD_CODING_PLAN_API_KEY=...
```

The `...` values are placeholders. Do not commit real `.env` files, cookies, or API keys.

For web-login authorization providers, prefer in-app reauthentication or paste a browser-copied cURL command when adding a credential. LongCat quota monitoring accepts a `longcat_session` cookie or captured login material containing `token` plus `uuid` / `passport_uuid`; LongCat API keys are stored only for copying. Aliyun/Tencent Cloud Coding Plan business API keys are not quota-query credentials.

## 5. Monitor Quotas

The `Quota Overview` page shows quota summaries for configured providers only. Providers without saved credentials do not appear as placeholders in `Quota Overview`, `Credentials`, or `Diagnostics`.

Provider rows are organized around `Key Quota`, `Credential Pool`, `Critical Time`, and `Status`. Recent quota changes appear under the quota value they describe, while `Last Updated` in expanded account rows shows only refresh status such as updated, no change, failed, or skipped.

The menu bar popover is intentionally short: it shows a one-line risk summary, up to two watched providers, and a small risk-ranked attention feed for low quota, failed checks, expiry, and recent activity. Click a feed row to open the matching provider/account in the main window, or use the row refresh button for a quick provider refresh.

## 6. Settings

Use `Settings` to switch Simplified Chinese, Traditional Chinese, English, Japanese, and Korean; adjust menu bar popover transparency; configure launch at login; enable automatic update checks in standard builds; set the network proxy; and set automatic refresh intervals. Automatic refresh can also be turned off.

Network proxy supports System, Direct, and Custom. Custom proxy accepts values such as `http://127.0.0.1:7890` or `socks5://127.0.0.1:7890`.

To keep frequently used providers near the top, enable `Custom Provider Order`, click `Configure`, and drag provider rows. This order is shared by Quota Overview, Credentials, Diagnostics, and the menu bar popover.

The lower-left corner of the main window shows the installed version and update status. When automatic update checks are enabled in standard builds, the app only checks GitHub Releases. If a new version is available, Quota Radar shows release notes and does not download silently. It downloads the DMG and replaces the installed app only after you click `Download and Install`.

White-label builds are compiled with `QUOTARADAR_DISABLE_GITHUB_UPDATER`; they hide update-check controls, skip launch-time update checks, and do not embed the upstream GitHub Release URL.

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

Run the saved web-login provider acceptance matrix without calling provider endpoints:

```bash
scripts/live_acceptance.sh
```

Run live quota endpoint acceptance explicitly:

```bash
QUOTARADAR_LIVE_ACCEPTANCE=1 scripts/live_acceptance.sh --live
```

The live acceptance output is a sanitized matrix. It does not print secrets, cookies, tokens, credential labels, or raw provider responses.

To install the existing bundle without rebuilding:

```bash
./install.sh
```

If source code changed, rebuild explicitly:

```bash
./install.sh --rebuild
```
