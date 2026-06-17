# QuotaRadar Monitoring Model Refresh Design

Date: 2026-06-17
Status: Approved direction, implementation in progress

## Summary

QuotaRadar should behave like a compact monitoring utility, closer to iStat Menus and Stats than a reporting dashboard. The menu bar should surface the smallest actionable signal, the popover should triage risk and recent activity, and the main app should explain why a provider is visible and what action is available.

The current trend sparkline is too ambiguous. It shows remaining quota movement, which can point upward after resets or when a parser accidentally uses usage as remaining. Replace that visual model with an explicit activity model: current remaining quota remains the primary state, while activity shows a compact remaining-quota delta only when the data is meaningful.

## Product Model

Every provider should map to the same four signals:

- Current: the most useful current quantity, such as `5h 2440 left`, `week 30%`, or `CNY 125.00`.
- Pressure: whether the current state needs attention: healthy, low, exhausted, expired, failed, stale, or unknown.
- Activity: current remaining plus recent change, rendered as a compact monitor reading such as `79% · ↓2pt`, `700 · ↓200`, or `CNY 8.50 · ↓CNY 4.00`.
- Timing: last updated, next reset, and plan expiry, kept visually secondary.

Trend lines are not a first-class concept. The product should render compact activity meters and deltas, and leave the activity lane empty when there is not enough comparable history or the value has not changed.

## Provider Families

### Windowed Request Counts

Providers: XFYun Spark Coding Plan, Aliyun Coding Plan, Tencent Cloud Coding Plan.

- Current: show the tightest active window by remaining count and compact label.
- Activity: show the largest stable billing window's current remaining percentage plus comparable remaining delta, usually month, otherwise week, otherwise 5h.
- Timing: show update time and package expiry. Reset details can stay in the existing quota-window detail area, not in every compact row.
- Parser rule: never treat `usage` fields as remaining. Remaining equals `limit - usage`, except when a provider exposes an explicit remaining/left field.

### Windowed Percent Quotas

Providers: Claude Subscription, Codex Subscription, Kimi Subscription, Volcengine Coding Plan, OpenCode Go.

- Current: show the tightest active window by remaining percentage.
- Activity: show the selected billing window's current remaining percentage plus comparable remaining percentage-point delta. Hide it when no comparable history is available.
- Timing: show update time plus plan expiry when exposed.
- Reset recovery is a state transition, not an upward trend line.

### Money Balance

Providers: DeepSeek, Bocha, WeChat Search.

- Current: show remaining balance.
- Activity: show current remaining balance plus recent balance drop from snapshots when comparable.
- Timing: show update time. Do not show reset timing unless the provider really exposes one.

### Fixed Credits Or Search Quota

Providers: Tavily, Brave Search, SerpAPI, Serper.

- Current: show remaining credits/searches.
- Activity: show current remaining credits/searches plus recent remaining-unit drop from snapshots.
- Timing: show reset when known; otherwise show update time only.
- Costly refresh providers must not be pulled into automatic activity collection too aggressively.

### Usage Without Known Limit

Providers: Exa, Querit.

- Current: show usage or usable state, not fake remaining quota.
- Activity: show recent remaining or cost change only when the provider exposes comparable data.
- Menu bar: show only for errors, stale checks, or notable recent activity.

### Unlimited Or Unknown

Providers: AnySearch and unsupported fallback states.

- Current: show available or quota unknown.
- Activity: no activity meter.
- Menu bar: only show on failure, expired authorization, or stale check.

## Menu Bar Interaction

The menu bar has one job: tell the user whether there is anything worth acting on.

Menu bar text should follow priority order:

1. Critical risk count or most urgent provider, such as `2 low` or `XFYun 5h 2440`.
2. Expiring authorization or plan, such as `Claude expires`.
3. Notable recent remaining change, such as `Tavily -320`.
4. Otherwise icon-only.

The popover should be divided into compact triage sections:

- Needs Attention: low quota, exhausted quota, expired credentials, failed checks, expiring plans.
- Recent Change: providers with meaningful recent remaining change that are not already in Needs Attention.
- Recently Updated: only refresh results with a visible delta or recovery. Do not show "updated just now" as a persistent header status.

Clicking a popover provider row should open the main app, select Quota Overview, scroll to the provider, and expand it. The main provider row should display a weak `Menu Signal` explanation such as `Shown because 5h quota is low`.

## Main App Layout

Quota Overview should use these provider columns:

- Provider
- Current
- Activity
- Time
- Status
- Actions

Expanded account rows should use the same conceptual columns. The layout must consume the available content width instead of anchoring a fixed-width account table to the left. Credential and Time columns should receive most flexible width. Current, Status, and Actions should keep stable scan anchors.

Activity should be rendered as an inline meter, not a card:

- A short period label, such as `month`, `week`, `5h`, or `balance`.
- The current remaining value for the selected period.
- A compact delta when history proves recent remaining quota changed.
- Empty state when data is insufficient or unchanged.

## Documentation Model

Root documentation should be English-first:

- `README.md`: concise English overview, screenshots, quick start, and provider summary.
- `README.zh-Hans.md`: Chinese translation.
- `docs/providers.md` and `docs/providers.zh-Hans.md`: provider capability matrix and parser notes.
- `docs/roadmap.md` and `docs/roadmap.zh-Hans.md`: roadmap replacing root TODO files.
- `docs/assets/screenshots/en/...`: default README screenshots.
- `docs/assets/screenshots/zh-Hans/...`: translated screenshots.

Root-level temporary screenshots and `.superpowers/` brainstorming artifacts should not be part of release documentation.

## Acceptance Criteria

- XFYun displays remaining counts and percentages that match official dashboard semantics.
- Activity never treats a quota reset as consumption and never displays an upward "remaining" trend as user activity.
- Money-balance providers display balance activity, not quota-window activity.
- Providers without comparable quota do not render fake activity.
- Menu bar and popover explain why a provider is shown and can navigate to the provider in the main app.
- Quota Overview rows use available width cleanly without a large empty right side.
- README defaults to English and English screenshots; Chinese docs remain available but no longer dominate root docs.
