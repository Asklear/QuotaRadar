# QuotaBar TODO / Roadmap

<p align="right">
  Language:
  <a href="./TODO.md">简体中文</a> |
  <strong>English</strong>
</p>

QuotaBar's core goal is to reduce quota anxiety: users should not need to repeatedly log into provider dashboards to know which keys still work, when quota resets, which credentials expired, and which checks consume real quota.

## Product Principles

- Prefer official usage or billing APIs. Use dashboard-session cookies only when no official API exists.
- Clearly separate API keys, admin credentials, and dashboard cookies so users do not paste a model API key where a cookie is required.
- Automatic refresh must avoid real quota consumption by default. Providers such as Brave, where a check performs a real search request, should be manual-only unless the user explicitly opts in.
- Secrets stay local. Source code, tests, README files, and GitHub Releases must never contain real API keys or cookies.
- Every provider needs clear diagnostics: usable, quota unknown, credential expired, connection failed, unsupported API, or quota-consuming check.

## P0: Current Version Hardening

- [ ] Update QUICKSTART wording from the old "Language & Appearance" label to "Settings".
- [ ] Check Chinese and English docs for unsigned DMG, disabling automatic refresh, Brave auto-refresh skip behavior, and cookie-provider setup.
- [ ] Improve Release workflow notes so unsigned DMG users see the Gatekeeper workaround clearly.
- [ ] Keep the current unsigned DMG release path. Developer ID signing and notarization remain optional future work.
- [ ] Keep avoiding Keychain as the default secret path to reduce repeated login-keychain prompts.

## P1: Credential Configuration UX

- [ ] Turn `Credentials` into a provider-aware wizard instead of one generic form.
- [ ] Show the expected credential type for each provider:
  - API Key: Tavily, SerpAPI, Serper, Bocha, DeepSeek, and similar providers.
  - Admin Credential: Exa Team Management service key plus target API key id.
  - Dashboard Cookie: Querit, XFYun Spark, Volcengine, and OpenCode Go.
- [ ] Add "paste cURL and parse automatically" for dashboard-cookie providers:
  - Extract the Cookie header from copied `curl`.
  - Extract `csrfToken`, `ProjectName`, and related fields from Volcengine cURL.
  - Extract `workspaceID`, `serverID`, and `serverInstance` from OpenCode Go cURL.
  - For Querit, save only dashboard-session cookies and reject plain `QUERIT_API_KEY`.
- [ ] Make reauthentication auto-save:
  - Open the provider dashboard login page.
  - After the user logs in, read cookies from allowed domains.
  - Verify required cookies exist.
  - Save the credential to the local secret store after a successful test.
- [ ] Add credential state labels:
  - `Not Configured`
  - `Configured, Untested`
  - `Usable`
  - `Credential Expired`
  - `Quota API Unavailable`
  - `Check Consumes Quota`
- [ ] Add export/backup for credential metadata, but do not export secrets by default.

## P2: Connectivity Tests And Diagnostics

- [ ] Add an independent `Test Connection` button for each provider.
- [ ] Separate three test types:
  - No-cost ping: validates key/cookie format or account endpoint without consuming quota.
  - Quota check: reads real quota.
  - Costly check: consumes real quota and requires manual confirmation.
- [ ] Show richer diagnostics:
  - Last request time.
  - HTTP status.
  - Short provider error summary.
  - Whether a proxy was used.
  - Whether automatic refresh skipped this provider.
  - Next reset time or "provider does not expose reset time".
- [ ] Add proxy settings:
  - Use system proxy.
  - Manual HTTP proxy, such as `http://127.0.0.1:7890`.
  - Manual SOCKS proxy, such as `socks5://127.0.0.1:7890`.
  - No proxy.
- [ ] Add threshold notifications:
  - Quota below 20%.
  - Quota exhausted.
  - Cookie expired.
  - Provider connection failed repeatedly.

## P3: Provider Expansion

Acceptance criteria for a new provider:

- [ ] Find an official usage API, billing API, dashboard API, or confirm that only manual/dashboard-cookie monitoring is possible.
- [ ] Confirm quota units, reset cycle, and whether checking quota consumes real quota.
- [ ] Add parser fixtures; do not rely only on manual testing.
- [ ] Add provider icon, category, default credential name, and localized copy.
- [ ] Add `.env` and `~/.claude/settings.json` import rules.
- [ ] Add behavior tests and secret-safety checks.

### AI Search Candidates

- [ ] Perplexity / Sonar: verify whether official usage or billing APIs are available.
- [ ] You.com: verify API key usage or dashboard usage endpoint.
- [ ] Jina AI Search / Reader: confirm free quota, request quota, and reset behavior.
- [ ] Firecrawl: confirm credits API and team/project usage scope.
- [ ] Linkup: confirm API usage endpoint.
- [ ] Kagi Search API: confirm plan quota and usage API.
- [ ] Google Programmable Search: use Google Cloud quota/billing data; account for OAuth or service-account complexity.
- [ ] Azure Bing Search: use Azure quota/usage data; account for subscription and resource scope.

### LLM / Coding Plan Candidates

- [ ] OpenAI: verify billing/usage API availability, organization/project scope, and API-key granularity.
- [ ] OpenRouter: check credits and usage API.
- [ ] Gemini / Google AI Studio: check quota, billing, and project scope.
- [ ] Qwen / DashScope: check Alibaba Cloud usage and resource packages.
- [ ] Moonshot / Kimi: check balance and resource packages.
- [ ] Zhipu / GLM: check account balance and call quota.
- [ ] MiniMax: check balance and token usage.
- [ ] Baidu Qianfan: check account resource packages.
- [ ] Tencent Hunyuan: check account resource packages.
- [ ] SiliconFlow: check balance and API-key usage.
- [ ] Anthropic: currently hidden from the main UI; re-evaluate only if the user wants it and usage can be queried reliably.

## P4: Frontend Aesthetics And Interaction

- [ ] Keep the main window moving toward a modern macOS style:
  - Clearer sidebar hierarchy.
  - Less repeated information.
  - Provider banners collapse on click without relying on triangle icons.
  - Collapse animations compress in place instead of flying in from above.
- [ ] Keep the menu bar popover lightweight:
  - Collapsible AI Search and LLM groups.
  - Credentials sorted by remaining quota inside each provider.
  - Keys shown as first four and last four characters, not environment variable names.
  - Auto-close when the pointer leaves, without activating the main window.
- [ ] Continue using the battery/quota metaphor:
  - The app icon should be simpler and readable at distance.
  - The menu bar icon should work on light, dark, and transparent menu bars.
  - Use official provider icons when available; use consistent fallbacks otherwise.
- [ ] Add a visual QA checklist:
  - 13-inch display, wide display, external display.
  - Light and dark mode.
  - Chinese and English.
  - Long provider names, long error messages, many keys.
  - No text overlap or clipping.

## P5: Multi-Platform And Multi-Language

- [ ] Keep macOS as the short-term priority and preserve the native SwiftUI menu bar experience.
- [ ] If Windows/Linux support becomes necessary, evaluate Tauri or Electron before trying to port SwiftUI behavior directly.
- [ ] Centralize localization keys and avoid hardcoded business copy inside views or parsers.
- [ ] Finish localization for dates and period units:
  - 5 hours
  - week
  - month
  - next reset
  - unavailable
  - quota unknown
- [ ] Define provider-name rules:
  - Brand names usually remain untranslated, such as Deepseek, Serper, Exa, and Querit.
  - Generic states and quota units must be localized.

## P6: History, Trends, And Alerts

- [ ] Store the last N quota snapshots for trend display.
- [ ] Add consumption-speed hints, such as unusually fast weekly usage.
- [ ] Add local notifications:
  - Nearly exhausted.
  - Exhausted.
  - Cookie expired.
  - Balance restored or monthly reset detected.
- [ ] Add provider-level refresh history so users can tell whether refresh actually changed anything.

## Next Starting Plan

Start with P1 + P2. They reduce configuration and diagnostics friction directly, and they create the foundation for provider expansion.

1. [ ] Build a provider capability matrix.
   - Suggested files: `docs/provider-capabilities.md` / `docs/provider-capabilities.en.md`.
   - Fields: provider, category, credential type, usage source, reset cycle, does check consume quota, diagnostic endpoint, notes.
2. [ ] Refactor the credential page into provider-aware forms.
   - Main files: `QuotaBar/Models/APIKey.swift`, `QuotaBar/Views/SettingsView.swift`, `QuotaBar/Services/EnvImporter.swift`.
   - Goal: after selecting a provider, users only see fields that provider needs.
3. [ ] Add a cURL paste parser.
   - Main file: create `QuotaBar/Services/CurlCredentialParser.swift`.
   - Goal: Querit, XFYun Spark, Volcengine, and OpenCode Go can extract cookies/headers from copied browser cURL.
4. [ ] Add per-provider connectivity tests.
   - Main files: `QuotaBar/Services/QuotaService.swift`, `QuotaBar/Models/QuotaMonitor.swift`, `QuotaBar/Views/SettingsView.swift`.
   - Goal: each provider can test credential usability and disclose whether the test consumes quota.
5. [ ] Add proxy settings.
   - Main files: `QuotaBar/Models/AppAppearance.swift`, `QuotaBar/Services/QuotaService.swift`, `QuotaBar/Views/SettingsView.swift`.
   - Goal: support system proxy, manual HTTP/SOCKS proxy, and no proxy.
6. [ ] Run a main-window and menu-popover visual QA pass.
   - Check screenshots across sizes, languages, and light/dark mode.
   - Prioritize overlap, clipping, repeated information, and collapse animation issues.

## Not Prioritized Yet

- [ ] Paid Apple Developer ID signing and notarization.
- [ ] Windows/Linux clients.
- [ ] Remote credential sync.
- [ ] Multi-user team dashboards.

