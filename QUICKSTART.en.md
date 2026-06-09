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

Normal providers use API keys. Exa uses a usage-query API key rather than a search invocation key. Querit API keys can be stored for copying, but quota monitoring still requires web login authorization. XFYun Spark Coding Plan, Volcengine Coding Plan, and OpenCode Go also use web login authorizations. Aliyun/Tencent Cloud Coding Plan business API keys can be stored for display/copying, but quota monitoring still requires reauthentication to capture web login authorization.

The credential page separates `API Key` from `Quota monitoring authorization`: copy buttons appear only on API-key rows. Web login authorization is used only by Quota Radar to check quota and is not displayed or copied as an API key.

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

The `Quota Overview` page shows provider-level quota summaries.

The menu bar popover groups providers by `AI Search` and `LLM`, supports collapsible providers, and refreshes one provider at a time.

## 6. Settings

Use `Settings` to switch Simplified Chinese, Traditional Chinese, English, Japanese, and Korean; adjust menu bar popover transparency; configure launch at login; and set the automatic refresh interval. Automatic refresh can also be turned off.

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
