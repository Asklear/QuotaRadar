# Quota Radar Roadmap

<p align="right">
  Language:
  <a href="./roadmap.zh-Hans.md">简体中文</a> |
  <strong>English</strong>
</p>

Quota Radar's core goal is to reduce quota anxiety: users should not need to repeatedly log into provider dashboards to know which keys still work, when quota resets, which credentials expired, and which checks consume real quota.

## Product Principles

- Prefer official usage or billing APIs. Use web login authorizations only when no official API exists.
- Clearly separate API keys and web login authorizations. Some provider usage APIs require API keys that differ from model/search invocation keys.
- Providers for which the user has a business key and account can enter a verification flow: store the business key, capture web login authorizations, and verify the quota endpoint. Providers without account or endpoint evidence stay as hidden extension stubs.
- Automatic refresh must avoid real quota consumption by default. Providers such as Brave, where a check performs a real search request, should be manual-only unless the user explicitly opts in.
- Secrets stay local. Source code, tests, README files, and GitHub Releases must never contain real API keys or cookies.
- Every provider needs clear diagnostics: usable, quota unknown, credential expired, connection failed, unsupported API, or quota-consuming check.

## v0.3.5 RC / Release Hygiene

- [x] Consolidate the README surface so English is the default entry point, with Simplified Chinese docs and screenshots linked explicitly.
- [x] Keep the monitoring model aligned with iStat / Stats: status and risk decide priority; trends explain recent movement only when they add signal.
- [x] Add menu-bar-to-main-window handoff QA for low quota, expiring plan, attention/failure, and recent consumption signals.
- [x] Compress expanded provider account rows around four durable facts: plan, remaining quota, reset/expiry, and last update.
- [x] Add release QA summaries under `build/visual-qa/summary.txt` and `build/visual-qa/summary.json`, including behavior test status, screenshot dimensions, and focused-signal highlight counts.
- [x] Verify the release bundle outside the development tree from the generated DMG installed into `/Applications/Quota Radar.app`.
- [x] Smoke-refresh Volcengine, Claude, Codex, and XFYun Spark with current local credentials before tagging.
- [x] Merge the feature branch back to `main`, then rerun behavior and visual QA on `main`.
- [x] Prepare the `v0.3.5` release notes, version metadata, and unsigned DMG workflow for tagging.

## v0.3.6 Monitoring UX Polish

- [x] De-duplicate menu-bar signal rows by provider, so multi-window balances such as Volcengine five-hour / weekly / monthly quota appear once in the popover.
- [x] Add user-selected watched providers in Settings. The menu bar can reserve a short watchlist without letting long-lived automatic attention items monopolize the feed.
- [x] Include money-balance providers such as DeepSeek, Bocha, and WeChat Search in Recent Change when balance snapshots show real depletion.
- [x] Localize the money-balance activity period marker so `balance` no longer leaks into Chinese, Traditional Chinese, Japanese, or Korean UI.
- [x] Update visual QA to match the current fixed-size menu bar panel and current risk-focus highlight colors.
- [x] Add a Settings color-scheme control for Follow System, Light Mode, and Dark Mode.
- [x] Fix live color-scheme switching so existing main windows and menu bar panels update immediately without restarting.
- [x] Refresh README screenshots with window/panel captures only, avoiding desktop backgrounds in release-facing images.
- [x] Bump version metadata and release notes for `v0.3.6`.

## v0.3.8 Reset And Account Layout Polish

- [x] Read Codex subscription reset-credit availability from `rate_limit_reset_credits.available_count` and persist it as non-secret credential metadata.
- [x] Add a guarded Codex `Use reset` action in the expanded account quota row. The action consumes one reset credit only after confirmation, refreshes the same account after the reset, and records the resulting quota snapshot.
- [x] Document that no Codex reset-credit expiry field has been observed yet; Quota Radar stores and displays only the available count.
- [x] Let Claude web-login authorization accept both `sessionKey` and `sessionKeyLC`, matching the current cookies exposed by WebKit.
- [x] Keep Volcengine automatic login capture watching longer during first-login SSO cookie settling, so the first reauthentication attempt can save without closing and reopening the window.
- [x] Hide providers from Quota Overview when all monitoring credentials are disabled.
- [x] Keep money-balance providers such as DeepSeek, Bocha, and WeChat Search from showing low-value `No reset cycle` timing copy.
- [x] Keep expanded account rows aligned with the original layout: account identity on the left, quota windows in the middle, and Critical Time / Last Updated in the right-side metadata panel.
- [x] Show quota-window details as reset time first, with remaining/total counts in parentheses for request-count providers such as XFYun Spark.
- [x] Restore Diagnostics category folding by AI Search and LLM.
- [x] Stabilize visual QA menu-bar screenshots with window-level capture so transparent popovers do not include the user's desktop background.

## v0.3.7 Monitoring Trust And Attention

- [x] Add a compact last-refresh status marker beside Last Updated in expanded provider rows, so users can see whether the latest refresh updated, had no change, failed, or was skipped without adding a history list.
- [x] Keep refresh consumption deltas on the quota/activity metric itself; Last Updated now shows status only and does not repeat amounts such as `-7pt`.
- [x] Record automatic refresh skips as quota history snapshots, so costly/manual-only providers explain why no provider request was made.
- [x] Keep refresh history reset-aware and balance-aware: top-ups and quota resets are recovery events, while money-balance drops render as currency deltas.
- [x] Add reset-aware consumption-speed hints. They render only when the current reset segment has enough history and the current pace is likely to cross the 20% low-quota threshold soon.
- [x] Preserve period names for multi-window providers such as weekly/monthly quotas, and avoid treating the first low sample after a reset as fast consumption.
- [x] Add recovery local notifications. Recent reset or top-up recoveries now send a `Quota recovered` notification through the existing permission and event-dedupe pipeline.
- [x] Keep the monitor UI lightweight: speed hints stay as a short inline state below Key Quota, without adding columns or history lists.
- [x] Add dense-account visual QA for a single provider with many accounts, long localized plan names, long account labels, and long diagnostics.
- [x] Add provider trust calibration metadata in code and document last verified time plus fallback behavior when provider fields drift.
- [x] Tighten the menu bar attention feed so rows stay short, action-first, and less metadata-heavy.
- [x] Make menu-bar-to-main-window handoff fall back to the most relevant account when provider-level signals are collapsed.
- [x] Add credential metadata export for backup/debugging without exporting raw API keys, cookies, tokens, or authorization values.
- [x] Refresh README screenshots with the latest fixture-based main-window and menu-bar captures for English and Simplified Chinese.

## Completed In v0.2.0

- Changed the menu bar popover into a quota-first provider overview grouped by `AI Search` and `LLM`.
- Enlarged the menu bar popover to reduce scrolling and fixed top/bottom clipping.
- Replaced fragile SwiftUI header actions in the popover with stable AppKit click targets so the first click works.
- Unified the main window and credential configuration order as `AI Search` before `LLM`.
- Made credential configuration distinguish API keys and web login authorization so Volcengine, XFYun Spark, and OpenCode Go are not mislabeled as plain API keys.
- Added launch at login, automatic refresh intervals, and the ability to disable automatic refresh; automatic refresh skips providers such as Brave that consume a real search request.
- Added menu bar transparency settings and propagated the configured transparency into inner popover cards.
- Added automatic reauthentication save for web-login providers, with provider quota validation before persisting.
- Fixed refreshed web login authorizations being overwritten by stale `~/.claude/settings.json` values. Claude settings are now imported only during first-run initialization, not during refresh.
- Kept the local secret file as the default credential store to avoid repeated login-keychain password prompts.
- Updated README, Quickstart, Release workflow notes, and unsigned DMG / Gatekeeper documentation.
- Added README main-window and menu-bar screenshots from the running app.
- DeepSeek, Bocha, and WeChat Search now display CNY balance values instead of credits or percentages.

## P0: Current Version Hardening

- [x] Update outdated quickstart settings-page wording to "Settings".
- [x] Check Chinese and English docs for unsigned DMG, disabling automatic refresh, Brave auto-refresh skip behavior, and web-login authorization setup.
- [x] Improve Release workflow notes so unsigned DMG users see the Gatekeeper workaround clearly.
- [x] Keep the current unsigned DMG release path. Developer ID signing and notarization remain optional future work.
- [x] Keep avoiding Keychain as the default secret path to reduce repeated login-keychain prompts.
- [x] Run screenshot QA for v0.2.2 menu bar transparency and make Chinese / English README pages use screenshots in their own language.
- [x] Fill in the provider capability matrix as the entry point for future provider additions.

## Fixed In v0.3.4

- [x] Fixed Brave manual refresh and quota-consuming automatic refresh appearing unchanged when Brave returns `402`, `422`, `429`, or hidden quota headers.
- [x] Brave usage-limit responses are persisted as exhausted quota; invalid keys preserve the real provider HTTP status for diagnostics.
- [x] Automatic refresh now uses each credential's persisted `lastUpdated` timestamp to decide whether it is due, so restarting the app does not restart the full interval.
- [x] Providers such as Brave that consume real search requests are polled for due status, but Quota Radar only sends the provider request after the configured interval has elapsed.

## Fixed In v0.3.3

- [x] Added a GitHub Release update entry point: the lower-left sidebar footer shows the version, update status, and a manual check button.
- [x] Added automatic update checks after launch, but they only detect new versions and show release notes. They do not silently download or replace the app.
- [x] After the user clicks `Download and Install`, Quota Radar downloads `QuotaRadar.dmg`, replaces `/Applications/Quota Radar.app`, clears quarantine, and relaunches.
- [x] Update checks reuse the app's network proxy settings. If the unauthenticated GitHub API is rate-limited, Quota Radar falls back to the latest-release redirect to resolve the version and download URL.
- [x] Refreshed Chinese and English README menu bar screenshots plus Quickstart / Roadmap wording, making the unsigned-release trust boundary and in-app update behavior explicit.

## Fixed In v0.3.2

- [x] Claude, Codex, Kimi, and OpenCode Go subscription providers can store companion API keys. API keys are only for copying and management; quota checks still use web login authorization.
- [x] Added network proxy settings: system proxy, direct connection, and custom HTTP/SOCKS proxy, with centered menu controls in Settings.
- [x] Adding or editing a credential immediately refreshes the matching provider, instead of waiting for automatic refresh or a second manual click.
- [x] When multiple web login authorizations exist, the reauthentication window requires an explicit save target so the wrong account is not overwritten.
- [x] The menu bar popover is now risk-first: `Quota Risk Today` plus `Needs Attention`, instead of squeezing the full provider grid into the small popover.
- [x] The main quota overview table now uses `Key Quota / Credential Pool / Critical Time / Status`, covering providers with multiple keys, subscription accounts, and multi-window quota cycles.
- [x] `Quota Overview`, `Credentials`, and `Diagnostics` now show only providers with saved credentials. Unconfigured providers no longer appear as empty placeholders.
- [x] Multi-window subscription quotas no longer repeat the 5-hour/weekly/monthly text in the credential row when the cycle details are shown below; plan-expiry dates include the year so annual plans are unambiguous.
- [x] Release behavior tests now cover companion credentials, proxy settings, immediate refresh, provider filtering, multi-window de-duplication, plan-expiry years, and release secret scanning.

## Fixed In v0.3.0

- [x] Updated the provider capability matrix with real browser login-state checks and local redacted checks for each provider's `quota`, `resetAt`, and `planEndsAt` boundaries.
- [x] Corrected Querit monitoring semantics: the account endpoint returns monthly usage only, does not expose plan limit/reset/end fields, and a plain `QUERIT_API_KEY` cannot query dashboard usage.
- [x] Corrected Serper monitoring semantics: the Account API returns balance and `rateLimit`, but no reset/end fields.
- [x] Clarified Aliyun Coding Plan: `aliclaw.coding-plan` checks subscription state; `codingPlanInfo.endTime` can be a plan end when present, and if the dashboard exposes 5-hour/weekly/monthly request-count fields, Quota Radar renders remaining/total counts with the XFYun-style model.
- [x] Clarified Tencent Cloud Coding Plan: dashboard `cgi/capi?cmd=DescribePkg&serviceType=hunyuan` is the verified endpoint; subscribed packages can expose request counts, quota-window reset times, and package end time.
- [x] Clarified Tencent Cloud Token Plan: Quota Radar retains the official `DescribeTokenPlanApiKey` parser, but lacks a real user key sample; the dashboard discovers packages through `ListUserTokenPlans`, and it stays hidden until verified.
- [x] Documented Token Plan measurement semantics: Tencent Cloud currently exposes token quota, XFYun Spark looks like seat/count quota, Aliyun is expected to be credits-based, and Volcengine remains unconfirmed.
- [x] Synced README, Quickstart, and Roadmap wording so business API keys are not described as quota-query credentials.
- [x] Fixed the main window jumping to another display in multi-screen setups: Quota Radar now remembers the user's last window frame and repairs placement only when that saved frame is invalid or off-screen.
- [x] Changed the quota overview toward provider-first summaries, reducing repeated API-key detail rows while keeping sortable and expandable key-level detail inside each provider.
- [x] Stopped diagnostics from creating duplicate quota rows for copy-only companion API keys. Those API keys now reuse the paired web-login authorization's health and HTTP status.
- [x] Supported storing both a provider API key and web-login authorization: the API key is available for copying and management, while web-login authorization is used only for quota checks.
- [x] Refreshed Chinese and English README screenshots from the v0.3.0 running app, with credentials masked by Quota Radar.
- [x] Hardened release hygiene by ignoring `.playwright-mcp/`, `test-results/`, and similar temporary screenshot/debug directories, and by keeping a secret scan in the release checklist.

## Fixed In v0.2.2

- [x] Changed the menu bar icon to a white filled quota-radar glyph with cut-out radar arcs and pointer, so it is not confused with the macOS battery or power icon.
- [x] Unified the main-window top-left mark, menu-bar popover top-left mark, and Dock icon around the same app-icon visual; inner page headers no longer repeat the icon.
- [x] Split README screenshots into Simplified Chinese and English sets, so English docs no longer show Chinese UI captures.
- [x] Updated Quickstart / README wording from "battery icon" to "quota-radar icon".

## Fixed In v0.2.0

- [x] LLM coding plans in the menu bar must not always show the `5 hours` cycle. Compare all available cycles such as 5 hours, week, and month, then display the cycle with the lowest remaining percentage so a zero weekly quota is not hidden by a full 5-hour quota.
- [x] Fix Querit reauthentication when choosing Google login does not open the verification window.
- [x] Add a setting for automatic refresh of providers whose checks consume search quota, with longer interval choices than normal free checks to avoid wasting quota.
- [x] Re-investigate why menu bar transparency settings have no visible effect, including the outer popover, inner cards, and macOS material layers.
- [x] Add more language options, at least Simplified Chinese, Traditional Chinese, Japanese, and Korean, and fully localize descriptions, buttons, diagnostics, dates, period units, and provider configuration copy.
- [x] Simplify the `Credentials` page title hierarchy so the large title and subtitle do not both repeat "Credentials".

The broader UI redesign toward a native, dense, low-distraction macOS monitoring panel remains in P4, instead of being mixed into the v0.2.0 fix queue.

## P1: Credential Configuration UX

- [x] Turn `Credentials` into a provider-aware basic form instead of a fully generic form.
- [x] Simplify the credential page title hierarchy so the page title and local heading do not repeat the same wording.
- [x] Show the basic expected credential type for each provider:
  - API key: Tavily, SerpAPI, Serper, Bocha, DeepSeek, Exa Team Management service key plus target API key id, and similar providers.
  - Web login authorization: Querit, Claude Subscription, Codex Subscription, Kimi Subscription, XFYun Spark Coding Plan, Volcengine Coding Plan, OpenCode Go, Aliyun Coding Plan, and Tencent Cloud Coding Plan.
  - Verified integrations: Aliyun Coding Plan can check subscription state through `aliclaw.coding-plan` and now parses 5-hour/weekly/monthly request-count fields when exposed; Tencent Cloud Coding Plan parses request-count quota cycles through dashboard `cgi/capi?cmd=DescribePkg&serviceType=hunyuan`. Business invocation API keys for both can be stored and shown, but they are not used for quota monitoring.
  - Sample still needed: the current Aliyun Coding Plan account returns no subscription; usage-field parsing is reserved, and if a subscribed account still does not expose usage details, keep "Usable · quota unknown".
  - Hidden extension stubs: XFYun Spark Token Plan, Volcengine Token Plan, Aliyun Token Plan, and Tencent Cloud Token Plan. They are not shown, imported, or refreshed until usable quota fields, measurement units, and real credential samples are confirmed.
- [x] Add "paste cURL and parse automatically" for web-login providers:
  - Extract the required web login authorization data from copied `curl`, including the Cookie header when the provider endpoint requires it.
  - Extract `csrfToken`, `ProjectName`, and related fields from Volcengine cURL.
  - Extract `workspaceID`, `serverID`, and `serverInstance` from OpenCode Go cURL.
  - For Querit, `QUERIT_API_KEY` is stored only as a copyable API key; quota monitoring still stores web login authorization and uses the dashboard Account API.
  - For Kimi, extract the Bearer access token, `x-msh-device-id`, `x-msh-session-id`, `x-traffic-id`, and optional `kimi-auth` cookie.
- [x] Add companion API-key storage for providers that use web login authorization for quota monitoring but still need user-facing API-key management:
  - Querit, Claude Subscription, Codex Subscription, Kimi Subscription, XFYun Spark Coding Plan, Volcengine Coding Plan, OpenCode Go, Aliyun Coding Plan, and Tencent Cloud Coding Plan.
  - Companion API keys are copyable and editable, but do not create separate quota-monitoring or diagnostic rows.
  - Companion API keys are linked to the matching web login authorization; when multiple accounts exist, reauthentication requires an explicit save target.
- [x] Make reauthentication auto-save:
  - Open the provider dashboard login page.
  - After the user logs in, read cookies from allowed domains.
  - Verify required login authorization fields exist.
  - Save the credential to the local secret store after a successful test.
- [x] Fix Querit Google login in reauthentication; add OAuth popup/new-window handling or external-browser fallback if needed.
- [x] Add credential state labels:
  - `Not Configured`
  - `Configured, Untested`
  - `Usable`
  - `Credential Expired`
  - `Quota API Unavailable`
  - `Check Consumes Quota`
- [ ] Add export/backup for credential metadata, but do not export secrets by default.
- [x] Extend WebView reauthentication persistence beyond cookie store: support confirmed providers whose login token is stored in localStorage or sessionStorage. Kimi uses this when the web session writes `access_token` without a `kimi-auth` cookie.

## P2: Connectivity Tests And Diagnostics

- [x] Add an independent `Test Connection` button for each provider.
- [x] Separate three test types:
  - No-cost ping: validates key/cookie format or account endpoint without consuming quota.
  - Quota check: reads real quota.
  - Costly check: consumes real quota and requires manual confirmation.
- [x] Show richer diagnostics:
  - Last request time.
  - HTTP status.
  - Short provider error summary.
  - Whether a proxy was used.
  - Whether automatic refresh skipped this provider.
  - Next reset time or "provider does not expose reset time".
- [x] Add proxy settings:
  - Use system proxy.
  - Manual HTTP proxy, such as `http://127.0.0.1:7890`.
  - Manual SOCKS proxy, such as `socks5://127.0.0.1:7890`.
  - No proxy.
- [x] Add automatic refresh settings for quota-consuming providers:
  - Disabled by default.
  - Clearly warn that real request quota will be consumed.
  - Use longer intervals than normal refresh, such as 6 hours, 12 hours, and daily.
  - Providers such as Brave join automatic refresh only after the user enables this.
- [x] Add threshold notifications:
  - Quota below 20%.
  - Quota exhausted.
  - Login authorization expired.
  - Provider connection failed repeatedly.

## P3: Provider Expansion

Acceptance criteria for a new provider:

- [ ] Find an official usage API, billing API, dashboard API, or confirm that only manual/web-login monitoring is possible.
- [ ] Confirm quota units, reset cycle, and whether checking quota consumes real quota.
- [ ] Confirm and display the plan name / plan tier, such as Claude `Pro` / `Max`, Codex `Plus` / `Pro`, and cloud-provider values like `Coding Plan Pro`, package names, or membership names. If an endpoint only returns internal enums, add a local display mapping with localization instead of showing only the provider name.
- [ ] Add parser fixtures; do not rely only on manual testing.
- [x] Add browser/API verification records for currently integrated providers, including quota, resetAt, and planEndsAt field boundaries.
- [x] Add provider icon fallback, category, default credential name, and localized copy.
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
- [x] Moonshot / Kimi: Kimi Subscription is wired through web login authorization / Bearer access token. `BillingService/GetUsages` reads five-hour/weekly windows, remaining counts, and reset times, while `GetSubscription` reads subscription balance and expiry fields. No independent monthly rate-limit window is confirmed yet.
- [ ] Kimi Code OAuth unified authentication: the official `/coding/v1/usages` path returns a compatible `usage/limits` shape, but it requires a Device Code OAuth token. Add it later as a fallback/advanced path under one "Authenticate Kimi" action, not as a second primary button.
- [x] Plan-name detection phase 1: added `planDisplayName` through `QuotaResult`, `APIKey`, persistence, refresh saves, quota overview, menu bar popover, and diagnostics. Fixtures now cover Kimi membership names, XFYun Spark package names, Aliyun instance names / types, and Tencent Cloud package names.
- [ ] Plan-name detection remaining validation: Claude / Codex / Volcengine and similar providers need real response-field confirmation first. If an endpoint only returns internal enums, add localized display mappings and cover typical values such as `Pro`, `Max`, and `Plus`.
- [ ] Zhipu / GLM: check account balance and call quota.
- [ ] MiniMax: check balance and token usage.
- [ ] Baidu Qianfan: check account resource packages.
- [ ] Tencent Hunyuan: check account resource packages.
- [ ] SiliconFlow: check balance and API-key usage.
- [ ] Anthropic: currently hidden from the main UI; re-evaluate only if the user wants it and usage can be queried reliably.

### Pay-as-you-go / Prepaid Credits Candidates

Keep this separate from Claude / Codex subscription quota. Subscription quota tracks five-hour, weekly, monthly windows and plan expiry. Prepaid credits track API / Workbench / platform-call balances, so future integrations should be shown as separate provider types instead of pretending to be subscription remaining quota.

- [ ] Anthropic prepaid credits: research the Console prepaid credits balance endpoint, organization scope, required web-login authorization fields, and replay stability. If confirmed, expose it as a Claude API credits / Anthropic credits provider, not Claude Subscription.
- [ ] OpenAI prepaid credits: research OpenAI platform billing / credit grant / prepaid balance readability, organization/project scope, and whether it requires an Admin key or web-login authorization. If confirmed, expose it as an OpenAI API credits provider, not Codex Subscription.
- [ ] Claude Subscription follow-up: the current `claude.ai/api/organizations` path can expose five-hour/weekly windows in some login sessions, but `subscription_details` and organization selection are not stable enough. Claude Code style OAuth login is confirmed as a viable auth direction; next, verify whether an OAuth usage/limits endpoint reliably returns five-hour windows, weekly windows, reset times, and subscription-cycle dates, then keep the web organization endpoint as a fallback instead of the final source of truth.

## P4: Frontend Aesthetics And Interaction

- [ ] Establish Quota Radar's macOS monitoring-panel design baseline:
  - Dense but clear menu bar modules, refresh cadence controls, and settings grouping.
  - Lightweight native modules, compact metric blocks, and broad localization coverage.
  - Menu bar diagnostics, recent activity summaries, and quick actions.
  - Main-window tables, grouping, filtering, summary areas, and diagnostic information hierarchy.
- [ ] Position QuotaRadar as an API quota monitoring panel, not a SaaS dashboard:
  - Numbers first: remaining, total, percentage, reset time, and update time beat decoration.
  - Moderate density: the menu bar shows only provider-level essentials; the main window carries detail.
  - Native material: use macOS sidebar, toolbar, popover, separators, and material instead of marketing-style cards and large gradients.
  - Nearby actions: refresh, reauthenticate, test connection, and open dashboard should sit close to the relevant provider.
- [ ] Keep the main window moving toward a modern macOS style:
  - Clearer sidebar hierarchy.
  - Less repeated information.
  - Provider banners collapse on click without relying on triangle icons.
  - Collapse animations compress in place instead of flying in from above.
  - Make the quota overview table/grouping first with a side or bottom summary, not repeated card stacks.
- [x] Implement the menu bar popover's baseline monitoring interactions:
  - AI Search and LLM groups are shown separately.
  - Providers can collapse.
  - Credentials are sorted by remaining quota inside each provider.
  - Keys are shown as first four and last four characters, not environment variable names.
  - The popover auto-closes when the pointer leaves, without activating the main window.
  - LLM coding plans show the cycle with the lowest remaining percentage instead of always showing the 5-hour cycle.
  - Menu bar transparency is wired through and README screenshots have been refreshed from the running app.
  - The current menu bar main view keeps only `Quota Risk Today` and `Needs Attention`; full provider/key details live in the main window.
- [x] Adjust the main quota overview information architecture:
  - Provider rows changed from `Remaining/Total` to `Key Quota/Credential Pool/Critical Time/Status`.
  - `Key Quota` shows the tightest window for subscription/coding-plan providers and the best usable key for plain API-key pools.
  - `Credential Pool` counts only credentials that participate in quota monitoring, excluding copy-only companion API keys.
  - Expanded provider rows still show per-key/account details, reset timing, and plan expiry.
- [ ] Deepen the next menu bar visual pass:
  - Use compact metrics, fine separators, clear hierarchy, and no long scrolling dashboard.
  - Redesign the overall style toward native monitoring panels: tighter modules, fewer large cards, clearer metric hierarchy, and a cleaner action area.
  - Keep improving transparency across different desktop backgrounds while preserving text readability.
- [ ] Continue using the quota-radar metaphor:
  - The app icon and menu bar icon should stay structurally aligned and read as quota monitoring at distance.
  - The menu bar icon should work on light, dark, and transparent menu bars, without being confused with the macOS battery or power icon.
  - The menu bar popover's top-right action icon should be modern and semantically clear, not another generic grey circular button.
  - Use official provider icons when available; use consistent fallbacks otherwise.
- [x] Add a visual QA checklist:
  - 13-inch display, wide display, external display.
  - Light and dark mode.
  - Chinese and English.
  - Long provider names, long error messages, many keys.
  - Multi-screen open/reopen flows keep the window on the display where the user placed it.
  - No text overlap or clipping.

## P5: Multi-Platform And Multi-Language

- [ ] Keep macOS as the short-term priority and preserve the native SwiftUI menu bar experience.
- [ ] If Windows/Linux support becomes necessary, evaluate Tauri or Electron before trying to port SwiftUI behavior directly.
- [ ] Centralize localization keys and avoid hardcoded business copy inside views or parsers.
- [x] Add language options:
  - Traditional Chinese
  - Japanese
  - Korean
- [x] Finish localization for dates and period units:
  - 5 hours
  - week
  - month
  - next reset
  - unavailable
  - quota unknown
- [x] Sweep all help text, settings text, buttons, diagnostics, errors, and release-facing docs so new languages are complete.
- [ ] Define provider-name rules:
  - Brand names usually remain untranslated, such as Deepseek, Serper, Exa, and Querit.
  - Generic states and quota units must be localized.

## P6: History, Trends, And Alerts

- [x] Store the last N quota snapshots for trend display.
- [x] Add consumption-speed hints, such as unusually fast weekly usage.
- [x] Add local threshold notifications: quota below 20%, exhausted quota, expired login authorization, repeated failures, with event dedupe.
- [x] Add recovery local notifications: balance restored or monthly reset detected.
- [x] Add provider-level refresh history semantics so users can tell whether the latest refresh changed anything, failed, recovered, or was skipped.

## Next Starting Plan

The first P6 history/trend/alert pass is complete. The latest polish pass moved the app closer to a compact monitoring-tool workflow.

1. [x] Continue visual QA on dense account rows, especially many accounts per provider and long localized provider messages.
2. [x] Add provider trust calibration metadata and document fallback behavior when provider fields drift.
3. [x] Tighten the menu bar attention feed so rows stay short, actionable, and less metadata-heavy.
4. [x] Add credential metadata export/backup, without exporting secrets by default.

## Not Prioritized Yet

- [ ] Paid Apple Developer ID signing and notarization.
- [ ] Windows/Linux clients.
- [ ] Remote credential sync.
- [ ] Multi-user team dashboards.
