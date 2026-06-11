# Quota Radar Desktop Tauri UI Spec

This document is the UI source of truth for the future Tauri + Rust + TypeScript desktop client. The cross-platform client must feel like the current Quota Radar app, not like a separate product. Platform-specific shell behavior can differ, but information architecture, terminology, component hierarchy, quota status semantics, and provider ordering must stay aligned with the current macOS implementation.

## Goals

- Keep the current Quota Radar mental model across macOS, Windows, and Linux.
- Preserve the current main-window pages: quota monitoring, credentials, diagnostics, settings, and about.
- Preserve the tray/menu-bar popover as a compact risk surface, not a miniature copy of the main window.
- Preserve credential semantics: API key for copy/use, web login authorization for quota monitoring, and companion API key when a provider needs both.
- Preserve multilingual behavior and avoid hard-coded UI strings.
- Preserve provider ordering, provider categories, icon identity, status colors, and collapse behavior.

## Non-Goals

- Do not redesign Quota Radar as a SaaS dashboard.
- Do not add marketing-style cards, hero sections, decorative gradients, or large empty panels.
- Do not show unconfigured providers in quota monitoring, credentials, or diagnostics.
- Do not expose dashboard cookies or web login authorization values as copyable API keys.
- Do not force complete macOS visual parity where the platform shell differs. Windows and Linux may use their native tray and window behavior.

## Product Principles

- Numbers first: remaining quota, total quota, percentage, key time, last update, and health status are more important than decoration.
- Risk first: the tray popover highlights exhausted, low, failed, expired, and expiring credentials.
- Provider first: the main quota page summarizes by provider, then expands to credential-level detail.
- Credential clarity: API keys and web login authorizations are visually and semantically distinct.
- Cost awareness: providers whose quota check consumes real search quota must be labelled and excluded from normal automatic refresh.
- Minimal interruption: background update checks and refresh checks must not silently install, replace, or spend costly quota.

## Information Architecture

```text
Desktop Shell
├─ System Tray / Menu Bar Icon
│  └─ Compact Quota Popover
└─ Main Window
   ├─ Sidebar
   │  ├─ Quota Monitoring
   │  ├─ Credentials
   │  ├─ Diagnostics
   │  ├─ Settings
   │  └─ Version / Update Footer
   └─ Content
      ├─ Quota Monitoring
      ├─ Credentials
      ├─ Diagnostics
      ├─ Settings
      └─ About
```

Navigation order must be:

1. Quota Monitoring
2. Credentials
3. Diagnostics
4. Settings

About remains available from the app but is secondary. The sidebar footer always shows version and update status.

## Platform Shell

### macOS

- Menu bar item uses the Quota Radar status glyph.
- Popover appears near the menu bar icon, without a default arrow.
- Popover should auto-hide when the pointer leaves the panel region.
- Main window minimum content size: `900 x 600`.
- Preferred main content size: around `1120 x 640`.

### Windows

- Use system tray icon.
- The compact popover should anchor near the tray icon when possible.
- If exact tray-icon anchoring is not reliable, open near the lower-right work area and keep the visual surface compact.
- Use Windows-native installer/update expectations. Do not use macOS DMG language.

### Linux

- Use AppIndicator/system tray when available.
- Some desktop environments may not support reliable tray anchoring. In that case, open the compact panel near the current cursor or primary screen work area.
- Do not make Linux-only UI diverge from the component hierarchy.

## Visual Style

The visual style is a compact desktop monitoring panel:

- Dense but readable.
- Rounded corners are modest.
- Panels use translucent or material-like backgrounds where supported.
- Tables and rows are preferred over large stacked cards.
- Provider icons are compact and consistent.
- Status color is semantic, not decorative.

### Design Tokens

These tokens should be implemented in TypeScript/CSS and mapped to platform themes:

```text
Window minimum size:       900 x 600
Main preferred size:       1120 x 640
Sidebar width:             220
Sidebar divider width:     1
Tray popover size:         560 x 500
Tray popover corner radius:20
Tray content horizontal:   22
Tray content top inset:    18
Tray content bottom inset: 14
Panel corner radius:       12-16
Row corner radius:         8-11
Small icon button:         28 x 28
Header icon button:        32 x 32
Provider icon table:       28-30
Provider icon compact:     21-22
```

### Typography

- Use system UI fonts.
- Use monospaced digits for quota numbers, percentages, update timestamps, and counts.
- Use small uppercase labels only for table headers and section labels.
- Keep provider names on one line with tail truncation.
- Use `minimum-scale-factor` equivalent behavior for narrow values; do not let text overflow.

### Semantic Colors

The Tauri client should not invent extra quota colors. Keep quota status simple:

```text
Healthy / available:   green
Needs attention:       red
Low count warning:     orange only in summary/count contexts
Disabled / unknown:    secondary/neutral
Failed / expired:      red
Plan expiring soon:    orange
Informational text:    secondary/tertiary
```

Provider brand colors may appear in icons and action accents, but provider quota status should use semantic colors.

## App Icon And Provider Icons

- App icon, main-window sidebar icon, tray icon, and tray-popover header icon must use the same Quota Radar identity.
- Provider icons must match official provider identity where practical.
- Provider icons must have equal visual size, even when source logos have different aspect ratios.
- In dense tables, use compact badge style with a subtle background.
- In monochrome contexts, template the icon where this does not break official identity. Claude can preserve official color if monochrome rendering harms recognition.

## Tray / Menu-Bar Popover

The tray popover is a compact anxiety-reduction surface. It should show what needs attention now.

### Size And Layout

```text
Popover 560 x 500
┌────────────────────────────────────────────┐
│ Header: icon, title, quote/status, settings│
├────────────────────────────────────────────┤
│ Quota Risk Today                           │
│ Low | Failed | Available                   │
├────────────────────────────────────────────┤
│ Low Quota Providers                         │
│ provider rows, max 3                        │
├────────────────────────────────────────────┤
│ Expiring Soon                               │
│ provider rows, max 3                        │
├────────────────────────────────────────────┤
│ Needs Attention                             │
│ provider rows, max 2 or empty message       │
└────────────────────────────────────────────┘
```

### Header

Header contents:

- App mark, size around `22`.
- Title: localized `API Quota`.
- Optional refresh status pill when there is no error.
- AI quote pill. Quotes are short and should truncate instead of wrapping.
- Settings icon button, size `32 x 32`.
- Red attention dot on the settings button when there is a refresh error or failed credential count.

The settings button must be clickable on the first click even if the app is inactive.

### Empty State

When no credentials exist:

- Show a compact empty panel.
- Icon: key symbol.
- Title: localized `No credentials`.
- Message: import or add credentials.
- Button: open credentials/settings page.

### Risk Summary

Always show when credentials exist:

- Low count.
- Failed count.
- Available count.

Low count can be orange when greater than zero. Failed count can be red. Available count is green.

### Attention Lists

The popover shows only non-empty lists:

- Low quota providers: maximum 3.
- Expiring soon providers: maximum 3.
- Needs attention: maximum 2, or a compact "no credentials need attention" message.

The popover should not show every provider if only a few are configured or if no action is needed.

### Popover Interactions

- Click tray icon to open.
- Pointer leave closes after a short delay.
- Click settings opens the main window directly to Settings.
- Empty-state action opens Credentials.
- Popover must not steal focus unnecessarily.
- No scroll should be required for the default summary. If content overflows, constrain the attention list, not the whole popover.

## Main Window

### Sidebar

Width: `220`.

Header:

- Quota Radar icon, size around `42`.
- App name: `Quota Radar`.
- Subtitle: localized `API Quota`.

Navigation:

- Quota Monitoring: server/rack-style icon.
- Credentials: key icon.
- Diagnostics: stethoscope icon.
- Settings: slider/settings icon.

Sidebar metrics:

- credentials count.
- configured provider count.
- low credential count.

Footer:

- version text.
- update status.
- manual update check button.
- busy state uses small progress indicator.

### Main Content Shell

Every page uses a `ModernPage` equivalent:

- Title.
- Subtitle.
- System icon.
- Optional max content width.
- Vertical scroll.
- Consistent padding.
- Material panels for grouped content.

Main content background should be subtle and native, not a bright dashboard background.

## Quota Monitoring Page

This is the first/main page. It is provider-level first.

### Category Sections

Sections:

- AI Search
- LLM

Each category header shows:

- localized category title.
- provider count and credential count.
- active credential count.
- category icon.

Click the category banner to collapse/expand. Do not require a triangle control. Collapse animation should be opacity/height compression, not a flying animation.

### Provider Summary Table

Columns:

```text
Provider | Key Quota | Credential Pool | Critical Time | Status | Actions
```

Column width targets from current app:

```text
Provider:        flexible, min 150
Key Quota:       104, right aligned
Credential Pool: 154, right aligned
Critical Time:   150, right aligned
Status:           92, right aligned
Actions:         104 reserved
```

Provider row contents:

- Provider icon, around `30`.
- Provider family display name.
- Optional plan type, such as `coding plan`, `Token plan`, `Subscription`.
- Key Quota: provider-level critical quota text.
- Credential Pool: credential summary.
- Critical Time: next reset or plan end according to provider data.
- Status pill: green when healthy, red when attention required.
- Action group: dashboard, re-authenticate, refresh as applicable.

Clicking the provider banner/row expands or collapses credential-level detail.

### Provider-Level Quota Computation

For providers with multiple credentials:

- Provider quota should represent the tightest relevant quota, not the average.
- If any active credential is expired, exhausted, failed, or low, provider status requires attention.
- If one credential has unlimited quota, do not let it hide an exhausted finite credential.
- If quota is unknown but the provider is usable, show `OK` / usable unknown quota, not a fake percentage.

For multi-cycle subscription providers:

- Use the lowest remaining percentage among active cycles as the key quota.
- Show cycle detail only inside the expanded credential detail, not repeatedly in the summary row.
- Critical time should prefer the next quota reset if a quota window is the current bottleneck.
- Plan end should be visible in credential details and used for expiring-soon alerts.

### Credential Detail

Expanded provider rows show a credential table:

```text
Credential | Remaining | Status | Last Updated
```

Rows:

- Status dot, `6 x 6`.
- Masked credential label, monospaced.
- Optional subtitle for credential kind or diagnostic summary.
- Remaining badge.
- Health/status pill.
- Timing column, width around `188`.

Timing column lines:

1. last updated.
2. quota reset summary, if known.
3. plan end summary, if known.

Plan end dates must include year when the date can cross a year boundary.

### Quota Window Details

For 5-hour / weekly / monthly subscription plans:

- Show window rows only once inside expanded detail.
- Each window shows localized period name and percent/remaining text.
- If reset time exists, include localized reset text.
- If the provider exposes maximum request counts, show remaining/total or detail value.

## Credentials Page

This page manages credentials. It should not duplicate the quota monitoring page.

### Page Purpose

- Add credentials.
- Import `.env`.
- Group existing credentials by provider.
- Enable/disable credentials.
- Copy API keys where safe.
- Edit credentials.

The page should not show providers with no saved credentials.

### Top Configuration Panel

Actions:

- Add credential.
- Import `.env`.

The panel explains that new credentials appear below by provider.

### Provider Groups

Each provider group uses a clickable provider banner:

- Provider icon, around `28`.
- Provider family name.
- Optional plan type/category.
- Active count pill.
- Credential count pill.

Click banner to collapse/expand. No triangle required.

### Credential Rows

Row contents:

- Status dot, around `7`.
- Credential display name.
- Credential type badge when useful.
- Masked credential value.
- Optional note.
- Status pill.
- Enabled switch.
- Copy button if copyable.
- Edit button.

Action order must be consistent:

```text
Status | Enabled | Copy | Edit
```

Do not show a copy action for dashboard login authorization/cookie credentials. Copy only API keys or other values explicitly meant for user reuse.

### Add/Edit Credential Sheet

Current sheet target:

```text
Width: 760
Height: 540
Layout:
┌────────────────────────────────────────────┐
│ Header: provider icon, title, provider name│
├───────────────┬────────────────────────────┤
│ Provider list │ Credential detail form      │
├───────────────┴────────────────────────────┤
│ Footer actions: Cancel / Add or Save        │
└────────────────────────────────────────────┘
```

Provider list width: `220`.

Detail form fields:

- Credential name.
- Optional companion API key for providers that support it.
- Primary monitoring credential:
  - API Key.
  - Web login authorization.
  - Admin/API management credential.
- Paste cURL input for supported web-login providers.
- Note.

Secret fields:

- Hidden by default.
- Eye button toggles visibility.
- Multiline credential content may expand when visible.

When adding or editing a quota-monitoring credential:

- Save metadata and secret separately.
- Save companion API key if provided.
- Immediately refresh that provider if the credential supports quota query.

## Diagnostics Page

Diagnostics is for connectivity and credential health, not for repeating quota content.

### Provider Section

Each section shows:

- Provider icon, around `28`.
- Provider family name.
- Plan type or category.
- Credential group count.
- Costly-check warning if quota check consumes real search quota.

Only providers with diagnostic items should appear.

### Diagnostic Row

Each diagnostic row shows:

- Status dot.
- Credential title.
- Credential subtitle.
- Health status pill.
- Last HTTP status pill.
- Optional provider diagnostic message.

Do not show quota values here unless they are part of a diagnostic message.

## Settings Page

Settings are grouped into material sections.

### General

- Language segmented control.
- Custom provider order toggle.
- Configure provider order button.
- Launch at login toggle.
- Automatic update check toggle.

### Refresh

- Normal auto refresh interval:
  - Off.
  - Every 5 minutes.
  - Every 15 minutes.
  - Every 30 minutes.
  - Every hour.
- Footnote: normal auto refresh skips Brave/costly providers.
- Costly quota-consuming refresh interval:
  - Off.
  - Every 6 hours.
  - Every 12 hours.
  - Every day.

### Network

- Proxy mode:
  - Follow system.
  - Direct.
  - Custom.
- Custom proxy URL input shown only when custom mode is selected.
- Custom proxy supports HTTP(S) and SOCKS-style URLs.

### Appearance

- Tray/menu-bar transparency slider.
- Show percentage value.
- Slider range: `0%` to `100%`.

### Provider Order Sheet

Sheet size: about `460 x 500`.

Behavior:

- Opened from Settings.
- Drag providers directly; do not rely on one-step up/down buttons.
- AI Search and LLM are separate groups.
- Providers cannot be dragged across categories.
- Reset order button.
- Close button.
- The resulting order is shared by quota monitoring, credentials, diagnostics, and tray popover.

## About Page

About page is secondary:

- App mark.
- App name.
- Version.
- Short feature list.
- Manual check for updates button.

## Provider Categories And Visibility

Category display order:

1. AI Search
2. LLM

Only configured providers appear in:

- tray provider-derived attention lists.
- quota monitoring.
- credentials.
- diagnostics.

Provider registry may contain hidden/pending providers. Hidden providers must not appear until their quota source, credential model, and parser behavior are verified.

## Credential Semantics

Credential kinds:

```text
apiKey              User API key, copyable when safe.
dashboardCookie     Web login authorization, not copyable.
adminCredential     Management/admin credential for usage APIs.
storedAPIKeyOnly    Companion API key, copyable, not used for quota monitoring.
```

Rules:

- Web login authorization is for Quota Radar quota reading only.
- Do not label web login authorization as API key.
- Companion API keys should be linked to the quota-monitoring authorization when possible.
- Diagnostics should avoid duplicating companion API key rows when they share the same provider/account health.
- Multiple web login authorizations for the same provider require an explicit save target during reauthentication.

## Status Model

Credential health states:

```text
healthy
failed
expired
usageLimitExceeded
disabled
unknownQuotaUsable
notChecked
unsupported
noSubscribedPlan
manualRefreshOnly
```

Provider summary status derives from active credential states:

- Disabled if all credentials are disabled.
- Expired if any active credential is expired.
- Usage limit exceeded if any active credential has usage limit exceeded.
- Low if any active credential is exhausted or low.
- Failed if any active credential failed.
- OK if usable with unknown quota.
- Healthy otherwise.

The UI should avoid ambiguous colors:

- Summary quota/status: green or red.
- Warning counts and plan-expiring-soon: orange.
- Disabled/unknown: neutral.

## Key Time Rules

Use the term `Critical Time` / localized equivalent in the main quota table.

Priority:

1. Next reset time for the quota window currently constraining usage.
2. Provider-level reset time.
3. Plan end time.
4. Provider reset policy, such as monthly day 1.
5. Not exposed.

In credential detail, show separate lines:

- last updated.
- reset summary.
- plan end summary.

Do not merge reset time and plan end into one concept internally.

## Localization

Languages currently expected:

- Simplified Chinese.
- Traditional Chinese.
- English.
- Japanese.
- Korean.

Rules:

- No user-visible string in React/Rust should bypass i18n.
- Provider names can remain provider-native where appropriate.
- Category names, actions, statuses, diagnostics, time labels, settings labels, tooltips, empty states, update messages, and error messages must be localized.
- Date formatting must use the active app language/locale.
- Test coverage must fail on missing translations or fallback English leakage for non-English languages.

## Actions And Tooltips

Provider action buttons must keep consistent meaning:

```text
Open dashboard       icon: external-link / arrow-up-right-square
Update authorization icon: person/key
Refresh quota        icon: refresh
```

Only show actions that apply to that provider:

- No dashboard button if no dashboard URL is known.
- No reauthentication button if provider does not support web login authorization.
- Refresh disabled if no active monitoring credential exists.

Every icon-only action needs an accessible label and tooltip.

## Empty States

No credentials:

- Tray: compact empty card with an action to open Credentials.
- Quota Monitoring: empty panel with action to add credential.
- Credentials: empty panel with action to add credential.
- Diagnostics: empty panel with no diagnostic rows.

No unconfigured provider placeholders should appear in tables.

## Update UI

The version/update footer stays in the lower-left sidebar.

States:

- Idle: show version and `Check for Updates`.
- Checking: show busy spinner and `Checking for updates...`.
- Available: show `Version X available`.
- Downloading: show `Downloading version X...`.
- Preparing/installing: show install status.
- Error: show localized failure message.

Automatic update checks may detect versions in the background, but downloading and replacing the app requires user confirmation and visible release notes.

Platform-specific install wording:

- macOS: DMG/app replacement/quarantine language.
- Windows: installer or updater language.
- Linux: package/AppImage updater language.

## Responsive Rules

Main window:

- Minimum width `900`.
- Sidebar fixed at `220`, never compress below readable width.
- Table columns can reduce spacing, but provider name and status should not overlap actions.
- Long localized strings must truncate or scale, not break layout.

Tray popover:

- Fixed default surface around `560 x 500`.
- Prefer limiting list item counts over introducing large scroll regions.
- If platform constraints require a smaller panel, keep header + risk summary + top attention list.

Credential sheet:

- Fixed target around `760 x 540`.
- Provider list remains readable.
- Detail pane scrolls; header and footer stay fixed.

## Tauri Component Mapping

Suggested React components:

```text
AppShell
Sidebar
SidebarNavItem
SidebarMetricRow
SidebarUpdateFooter
TrayPopover
TrayHeader
RiskSummaryCard
AttentionList
ProviderCategorySection
ProviderQuotaTable
ProviderQuotaRow
CredentialDetailTable
QuotaWindowDetails
CredentialsPage
ProviderCredentialGroup
CredentialRow
CredentialEditorDialog
DiagnosticsPage
DiagnosticProviderSection
DiagnosticRow
SettingsPage
ProviderOrderDialog
AboutPage
ProviderIcon
StatusPill
IconButton
MaterialPanel
```

Suggested shared DTOs:

```text
Provider
ProviderCategory
Credential
CredentialKind
QuotaSnapshot
QuotaWindow
ProviderStats
MenuQuotaSummary
MenuQuotaItem
DiagnosticItem
AppSettings
UpdateState
```

The React UI should not re-implement provider quota computation ad hoc. Provider-level summary data should come from Rust/TS shared selectors that mirror the current Swift `ProviderStats`, `MenuQuotaItem`, and `APIKey` presentation behavior.

## Test Expectations

The Tauri project should include behavior tests for:

- Navigation order.
- Sidebar width and minimum window size.
- Tray popover section order and max item counts.
- Provider filtering: unconfigured providers are hidden.
- Provider ordering shared by all pages and tray popover.
- Credential action order: status, enabled, copy, edit.
- Copy not shown for web login authorization.
- Dashboard/reauth/refresh actions only shown when supported.
- Multi-cycle quota chooses the lowest remaining period.
- Reset and plan end are separate fields.
- Plan end dates include year.
- Costly providers skipped by normal automatic refresh.
- All visible strings go through i18n.
- No real secrets in source, tests, screenshots, or release notes.

## Migration Notes From SwiftUI

Current SwiftUI/AppKit source areas to mirror:

- `QuotaRadar/Views/MenuContentView.swift`: tray/menu-bar popover layout and risk-first summary.
- `QuotaRadar/Views/SettingsView.swift`: sidebar, main pages, quota table, credentials page, diagnostics, settings, provider order sheet.
- `QuotaRadar/Views/Components.swift`: shared glass panels, provider icon behavior, quota window details, refresh button.
- `QuotaRadar/Models/APIKey.swift`: provider metadata, credential semantics, quota presentation, status derivation.
- `QuotaRadar/Models/QuotaMonitor.swift`: provider order, home stats, menu summary, refresh policies.
- `QuotaRadar/Models/AppLanguage.swift`: localization keys and fallback checks.

The Tauri version can use different implementation details, but any intentional UI divergence should be recorded here before implementation.
