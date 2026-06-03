# QuotaBar Quickstart

<p align="right">
  Language:
  <a href="./QUICKSTART.md">简体中文</a> |
  <strong>English</strong>
</p>

## 1. Build

Run from the project root:

```bash
./install.sh --bundle-only --rebuild
open build/QuotaBar.app
```

Install into `/Applications`:

```bash
./install.sh
```

## 2. Open The UI

Click the QuotaBar battery icon in the macOS menu bar.

The Dock icon opens the main window; the menu bar popover gives quick quota visibility.

## 3. Configure Credentials

Open `Credentials` from the main window sidebar.

Normal providers use API keys. XFYun, Volcengine, and OpenCode Go use dashboard-session cookies, not model invocation API keys.

## 4. Import From `.env`

Click the in-page `Import from .env` action and choose a file containing variables.

Example:

```env
TAVILY_API_KEY=...
BRAVE_API_KEY=...
DEEPSEEK_API_KEY=...
XFYUN_CODING_PLAN_COOKIE=...
VOLCENGINE_CODING_PLAN_COOKIE=...
OPENCODE_GO_COOKIE=...
```

The `...` values are placeholders. Do not commit real `.env` files, cookies, or API keys.

## 5. Monitor Quotas

The `Quota Overview` page shows provider-level quota summaries.

The menu bar popover groups providers by `AI Search` and `LLM`, supports collapsible providers, and refreshes one provider at a time.

## 6. Settings

Use `Settings` to switch English/Simplified Chinese, adjust menu bar popover transparency, configure launch at login, and set the automatic refresh interval. Automatic refresh can also be turned off.

## 7. Local Data Locations

Secret file:

```text
~/Library/Application Support/QuotaBar/secrets.json
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
