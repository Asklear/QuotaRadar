#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_no_match() {
  local pattern="$1"
  local path="$2"
  local message="$3"
  if rg -n "$pattern" "$path" >/tmp/quotaradar-test-match.txt; then
    cat /tmp/quotaradar-test-match.txt >&2
    fail "$message"
  fi
}

assert_match() {
  local pattern="$1"
  local path="$2"
  local message="$3"
  if ! rg -n -- "$pattern" "$path" >/dev/null; then
    fail "$message"
  fi
}

echo "== Source safety checks =="
assert_no_match 'APIKey\(name: ".*API_KEY.*key: "[^"]{8,}' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "DefaultKeys must not contain embedded API secrets"
assert_no_match '@StateObject private var monitor = QuotaMonitor\(' \
  "QuotaRadar/Views/SettingsView.swift" \
  "SettingsView must use the shared QuotaMonitor instance"
assert_no_match 'for var key in apiKeys where key\.isActive' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "refreshAll must preserve inactive keys instead of filtering them out"
assert_no_match '\$\(' \
  "QuotaRadar/Info.plist" \
  "Info.plist in the source bundle must contain concrete app bundle values"
assert_match 'CFBundleIconFile' \
  "QuotaRadar/Info.plist" \
  "Info.plist must declare the app icon file"
assert_match 'CFBundleDisplayName' \
  "QuotaRadar/Info.plist" \
  "Info.plist must declare the Finder display name"
assert_match 'Quota Radar' \
  "QuotaRadar/Info.plist" \
  "App bundle display name should be Quota Radar"
assert_match '0\.2\.1' \
  "QuotaRadar/Info.plist" \
  "Quota Radar 0.2.1 should be recorded in Info.plist"
assert_no_match 'LSUIElement' \
  "QuotaRadar/Info.plist" \
  "QuotaRadar must appear in the macOS Dock after launch"
[[ -s docs/assets/screenshots/quota-overview.png ]] || fail "README quota overview screenshot asset should exist"
[[ -s docs/assets/screenshots/menu-bar-popover.png ]] || fail "README menu bar popover screenshot asset should exist"
assert_match 'docs/assets/screenshots/quota-overview\.png' \
  "README.md" \
  "Chinese README should show the quota overview screenshot"
assert_match 'docs/assets/screenshots/menu-bar-popover\.png' \
  "README.md" \
  "Chinese README should show the menu bar popover screenshot"
assert_match '真实运行画面，密钥由应用自动打码' \
  "README.md" \
  "Chinese README should clarify that public screenshots use masked real app captures"
assert_match 'docs/assets/screenshots/quota-overview\.png' \
  "README.en.md" \
  "English README should show the quota overview screenshot"
assert_match 'docs/assets/screenshots/menu-bar-popover\.png' \
  "README.en.md" \
  "English README should show the menu bar popover screenshot"
assert_match 'captured from the running app, with credentials masked by Quota Radar' \
  "README.en.md" \
  "English README should clarify that public screenshots use masked real app captures"
assert_match 'setActivationPolicy\(\.regular\)' \
  "QuotaRadar/AppDelegate.swift" \
  "QuotaRadar should explicitly use a regular activation policy so it appears in Dock"
assert_match 'enum AppLanguage' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "QuotaRadar should define an app language enum"
assert_match 'case english' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "QuotaRadar language options should include English"
assert_match 'case simplifiedChinese' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "QuotaRadar language options should include Simplified Chinese"
assert_match 'AppLanguageStore' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "QuotaRadar should persist the selected app language"
assert_match 'func displayName\(language: AppLanguage = AppLanguageStore\.shared\.language\)' \
  "QuotaRadar/Models/APIKey.swift" \
  "Providers should expose localized display names instead of rendering raw persistence values"
assert_match 'static var visibleCases: \[Provider\]' \
  "QuotaRadar/Models/APIKey.swift" \
  "Provider UI lists should use a visible provider list so unsupported providers can be kept out without breaking legacy decoding"
assert_match 'static let categoryDisplayOrder = \["AI Search", "LLM"\]' \
  "QuotaRadar/Models/APIKey.swift" \
  "Provider category display order should be defined once as AI Search before LLM"
assert_match 'Provider\.categoryDisplayOrder\.compactMap' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Status bar provider category groups should use the shared AI Search then LLM order"
assert_match 'Provider\.categoryDisplayOrder\.compactMap' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota overview and credential configuration should use the shared AI Search then LLM order"
assert_no_match '\["LLM", "AI Search"\]' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential configuration must not show LLM before AI Search"
assert_no_match 'ForEach\(Provider\.allCases\)' \
  "QuotaRadar/Views" \
  "Visible provider pickers should not render every Codable provider case"
assert_no_match 'Text\(.*(stat\.)?provider\.rawValue|Label\(.*rawValue|provider\.rawValue\) \(L10n\.t' \
  "QuotaRadar/Views" \
  "Visible provider labels should use localized display names instead of raw persistence values"
assert_no_match 'return \.anthropic' \
  "QuotaRadar/Services/EnvImporter.swift" \
  "Anthropic should not be imported as a supported provider for now"
assert_no_match '\| Anthropic \|' \
  "README.md" \
  "Anthropic should not be listed as a currently supported provider"
assert_no_match '\| Anthropic \|' \
  "README.en.md" \
  "English README should not list Anthropic as a currently supported provider"
assert_match '未签名 DMG' \
  "README.md" \
  "README should clearly label the no-fee GitHub Release path as an unsigned DMG"
assert_match "xattr -dr com\\.apple\\.quarantine '/Applications/Quota Radar\\.app'" \
  "README.md" \
  "README should document how trusted users can remove Gatekeeper quarantine from an unsigned app"
assert_match 'unsigned DMG' \
  "README.en.md" \
  "English README should clearly label the no-fee GitHub Release path as an unsigned DMG"
assert_match "xattr -dr com\\.apple\\.quarantine '/Applications/Quota Radar\\.app'" \
  "README.en.md" \
  "English README should document how trusted users can remove Gatekeeper quarantine from an unsigned app"
assert_match 'gh release create' \
  "README.md" \
  "README should document manual GitHub Release upload for unsigned DMGs"
assert_match 'gh release create' \
  "README.en.md" \
  "English README should document manual GitHub Release upload for unsigned DMGs"
assert_match 'on:' \
  ".github/workflows/release.yml" \
  "Repository should include a GitHub Release workflow"
assert_match 'tags:' \
  ".github/workflows/release.yml" \
  "Release workflow should run from version tags"
assert_match 'scripts/package_dmg.sh --rebuild' \
  ".github/workflows/release.yml" \
  "Release workflow should package QuotaRadar as a DMG"
assert_match 'softprops/action-gh-release' \
  ".github/workflows/release.yml" \
  "Release workflow should upload the DMG to GitHub Releases"
assert_match 'actions/setup-python' \
  ".github/workflows/release.yml" \
  "Release workflow should install a stable Python before installing Pillow"
assert_match 'actions/setup-python' \
  ".github/workflows/behavior-tests.yml" \
  "Behavior test workflow should install a stable Python before installing Pillow"
assert_match 'brew install ripgrep' \
  ".github/workflows/release.yml" \
  "Release workflow should install ripgrep because the behavior test script uses rg"
assert_match 'brew install ripgrep' \
  ".github/workflows/behavior-tests.yml" \
  "Behavior test workflow should install ripgrep because the behavior test script uses rg"
assert_no_match 'api\.anthropic\.com' \
  "QuotaRadar/Info.plist" \
  "Anthropic API domains should not be whitelisted while Anthropic is not supported"
assert_match '简体中文' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "The language picker should expose Simplified Chinese as a user-facing option"
assert_match 'applicationShouldHandleReopen' \
  "QuotaRadar/AppDelegate.swift" \
  "Dock icon clicks should reopen a visible QuotaRadar window instead of doing nothing"
assert_match 'openPreferences\(\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Dock reopen handling should show the settings window when no app window is visible"
assert_no_match 'SettingsView\(monitor: \.shared\)' \
  "QuotaRadar/QuotaRadarApp.swift" \
  "SwiftUI Settings scene must not host the real settings UI because it restores the old off-screen system settings window"
assert_match 'CommandGroup\(replacing: \.appSettings\)' \
  "QuotaRadar/QuotaRadarApp.swift" \
  "The app Settings command should route through AppDelegate.openPreferences so the managed window placement is used"
assert_match 'LegacyConfigurationMigrator\.migrateUserDefaultsIfNeeded' \
  "QuotaRadar/QuotaRadarApp.swift" \
  "Quota Radar should migrate old QuotaBar preferences before shared stores read UserDefaults"
assert_match 'clearSwiftUISettingsWindowAutosaveFrame' \
  "QuotaRadar/AppDelegate.swift" \
  "QuotaRadar should clear the stale SwiftUI Settings window autosave frame that can place the app on a hidden display"
assert_match 'showManagedSettingsWindowOnLaunch' \
  "QuotaRadar/AppDelegate.swift" \
  "Launching QuotaRadar should replace SwiftUI's empty Settings scene window with the managed settings window"
assert_match 'forceSettingsWindowOntoPreferredScreen' \
  "QuotaRadar/AppDelegate.swift" \
  "QuotaRadar should force the managed settings window onto the preferred screen after it is shown"
assert_no_match 'visibleFrame\.contains\(currentFrame\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Settings window placement should not skip repositioning because restored external-display frames can race after launch"
assert_match 'scheduleSettingsWindowPlacementRecovery' \
  "QuotaRadar/AppDelegate.swift" \
  "Settings window placement should be re-applied after launch restoration races"
assert_match 'applicationDidBecomeActive' \
  "QuotaRadar/AppDelegate.swift" \
  "Settings window placement should be recovered when QuotaRadar becomes active again"
assert_match 'windowDidBecomeKey' \
  "QuotaRadar/AppDelegate.swift" \
  "Settings window placement should be recovered when the settings window becomes key"
assert_match 'screen\.frame\.minX == 0 && screen\.frame\.minY == 0' \
  "QuotaRadar/AppDelegate.swift" \
  "Settings window placement should prefer the physical primary display at origin zero instead of NSScreen.main after a window was restored on an external display"
assert_match 'showStatusPanel' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar clicks should show only the status panel instead of activating the main app window"
assert_match 'openPreferencesFromStatusPopover\(destination: \.settings\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "The status bar settings button should open the Settings tab instead of the default API Keys page"
assert_match 'openPreferencesFromStatusPopover\(destination: \.apiKeys\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "The status bar empty-state configuration button should open the API Keys page"
assert_match 'SettingsNavigationStore' \
  "QuotaRadar/Views/SettingsView.swift" \
  "The settings window should expose shared navigation state so status-bar actions can select a tab"
assert_match '\$navigationStore\.selection' \
  "QuotaRadar/Views/SettingsView.swift" \
  "The sidebar selection should be driven by shared navigation state"
assert_match 'navigationOrder: \[SettingsDestination\] = \[\.providers, \.apiKeys, \.diagnostics, \.settings\]' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main navigation should prioritize quota observation, credential configuration, diagnostics, then language/appearance"
assert_match '@Published var selection: SettingsDestination\? = \.providers' \
  "QuotaRadar/Views/SettingsView.swift" \
  "The main window should open on quota observation by default"
assert_match 'case diagnostics' \
  "QuotaRadar/Views/SettingsView.swift" \
  "The main navigation should include a diagnostics page"
assert_match 'DiagnosticsView\(monitor: monitor\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Selecting diagnostics should show the diagnostics page"
assert_match 'CredentialDiagnosticRow' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Diagnostics should render credential-level rows"
assert_match 'startPopoverMouseExitMonitor' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar popover should start a mouse-exit monitor when shown"
assert_match 'closePopoverIfMouseExited' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar popover should close automatically after the pointer leaves the popover and status item"
assert_match 'NSEvent\.mouseLocation' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar popover auto-close should track the pointer in screen coordinates"
assert_match 'NSStatusBar\.system\.statusItem' \
  "QuotaRadar/AppDelegate.swift" \
  "AppDelegate must install a macOS status bar item"
assert_match 'enum RefreshMode' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Quota refreshes should distinguish manual refreshes from automatic background polling"
assert_match 'func refreshAll\(mode: RefreshMode = \.manual\)' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Manual UI refresh should remain available while automatic refreshes can avoid quota-consuming providers"
assert_match 'func refreshProvider\(_ provider: Provider, mode: RefreshMode = \.manual\)' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Manual UI refreshes should be available per provider instead of only globally"
assert_match '@Published var refreshingProviders: Set<Provider>' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Provider-level refresh buttons should have provider-specific loading state"
assert_match '@Published var refreshMessage' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Manual refresh clicks should have visible status feedback instead of appearing to do nothing"
assert_match 'L10n\.t\(\.refreshAlreadyRunning\)' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Manual refresh clicks during an active refresh should explain that a refresh is already running"
assert_match 'Refresh already running' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Manual refresh clicks during an active refresh should have an English localized message"
assert_match 'bypassCooldown: mode == \.manual' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Manual refreshes should bypass the short duplicate-check cooldown"
assert_match 'func checkQuota\(for key: APIKey, bypassCooldown: Bool = false\)' \
  "QuotaRadar/Services/QuotaService.swift" \
  "QuotaService should let manual refreshes bypass its duplicate-check cooldown"
assert_match 'httpStatus' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Quota results should carry HTTP status for diagnostics"
assert_match 'diagnosticMessage' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Quota results should carry a provider-specific diagnostic message"
assert_no_match 'throw QuotaError\.notSupported // 使用缓存或跳过' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Cooldown skips must not masquerade as unsupported providers"
assert_match 'quotaCheckConsumesSearchQuota' \
  "QuotaRadar/Models/APIKey.swift" \
  "Providers such as Brave should declare when checking quota consumes real search quota"
assert_match 'lastHTTPStatus' \
  "QuotaRadar/Models/APIKey.swift" \
  "API keys should persist the last HTTP status for diagnostics"
assert_match 'lastDiagnosticMessage' \
  "QuotaRadar/Models/APIKey.swift" \
  "API keys should persist the last diagnostic message"
assert_match 'httpNotRequested' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Diagnostics should distinguish unsupported or unrequested checks from failed HTTP requests"
assert_no_match 'key\.lastHTTPStatus\.map\(String\.init\) \?\? "N/A"' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Diagnostics should not show N/A when no HTTP request was made"
assert_match 'unsupportedQuotaDiagnosticMessage' \
  "QuotaRadar/Models/APIKey.swift" \
  "Unsupported providers should explain why quota checks cannot be monitored"
assert_match 'https://www\.querit\.ai/api/v1/user/account' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Querit should query the dashboard account endpoint with saved session cookies"
assert_match 'parseQueritAccount' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Querit account responses should be parsed from dashboard account data"
assert_match 'monthlyCreditsFormat' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Quota labels such as monthly credits should be localized instead of rendered as raw English"
assert_match 'zeroRemainingBadge' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Compact exhausted badges should be localized instead of hardcoding 0 left"
assert_match 'isUsableWithUnknownQuota' \
  "QuotaRadar/Models/APIKey.swift" \
  "API keys should distinguish usable credentials whose quota is not exposed"
assert_match 'isUsageLimitExceeded' \
  "QuotaRadar/Models/APIKey.swift" \
  "API keys should distinguish provider usage-limit exhaustion from unknown quota"
assert_match 'mode == \.automatic && key\.provider\.quotaCheckConsumesSearchQuota' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Automatic refreshes must skip quota checks that consume provider search quota"
assert_match 'case quotaConsumingAutomatic' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Quota-consuming providers should have a separate automatic refresh mode from normal free checks"
assert_match 'func refreshQuotaConsumingProviders\(mode: RefreshMode = \.quotaConsumingAutomatic\)' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Quota-consuming providers should be refreshed by their own long-cadence timer"
assert_match 'quotaMonitor\.refreshAll\(mode: \.automatic\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Background timer refreshes should use automatic mode"
assert_match 'quotaMonitor\.refreshQuotaConsumingProviders\(mode: \.quotaConsumingAutomatic\)' \
  "QuotaRadar/AppDelegate.swift" \
  "A separate timer should refresh quota-consuming providers only when explicitly enabled"
assert_match 'configureAutoRefreshTimer' \
  "QuotaRadar/AppDelegate.swift" \
  "Background quota refresh cadence should be configurable instead of hardcoded"
assert_match 'configureQuotaConsumingAutoRefreshTimer' \
  "QuotaRadar/AppDelegate.swift" \
  "Quota-consuming automatic refresh should use a separate long-cadence timer"
assert_match 'Timer\.publish\(every: interval' \
  "QuotaRadar/AppDelegate.swift" \
  "Auto refresh timer should use the configured interval"
assert_no_match 'Timer\.publish\(every: 300' \
  "QuotaRadar/AppDelegate.swift" \
  "Auto refresh timer should not be hardcoded to five minutes"
assert_no_match 'quotaMonitor\.refreshAll\(\)' \
  "QuotaRadar/AppDelegate.swift" \
  "AppDelegate must not use manual refresh semantics for background polling"
assert_match 'MenuContentView\(monitor: quotaMonitor\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar item must host MenuContentView with the shared monitor"
assert_no_match 'NSPopover' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar surface must not use NSPopover because its arrow and automatic offset do not match Stats/iStat-style popups"
assert_match 'NSPanel' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar surface should use an arrowless floating panel like Stats/iStat and the macOS input-method palette"
assert_match '\.nonactivatingPanel' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should not activate the main app when opened from the menu bar"
assert_match 'setupStatusPanel' \
  "QuotaRadar/AppDelegate.swift" \
  "AppDelegate should configure a dedicated status-bar panel for the glass surface"
assert_match 'containerView\.addSubview\(hostingController\.view\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should host the shared SwiftUI menu content inside the AppKit container"
assert_match 'panel\.setContentSize\(MenuContentView\.menuSize\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel must use MenuContentView.menuSize"
assert_no_match 'popover\.show|preferredEdge: \.minY' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar surface should not use NSPopover arrow anchoring"
assert_match 'statusPanelGap' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should keep a small Stats-style gap below the menu bar item"
assert_match 'frameForStatusPanel\(relativeTo: button\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should compute an explicit arrowless frame relative to the status item"
assert_no_match 'statusPopoverAnchorRect|rect\.origin\.y -= statusPopoverAnchorOffset' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should remove the old popover anchor calculations"
assert_match 'buttonFrame\.midX - MenuContentView\.menuSize\.width / 2' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should align horizontally to the menu-bar icon instead of drifting away"
assert_match 'showStatusPanel\(relativeTo: button\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar clicks should show the arrowless status panel"
assert_match 'visibleFrame\.maxY - statusPanelGap' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should sit close below the menu bar without a popover arrow"
assert_match 'panel\.setFrame\(frame, display: true' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should be placed by explicit frame calculation"
assert_match 'configureStatusPanelWindowAppearance' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar transparency should clear the panel window chrome, not only the SwiftUI overlay"
assert_match 'window\.isOpaque = false' \
  "QuotaRadar/AppDelegate.swift" \
  "Panel window must be non-opaque for status bar transparency to be visible"
assert_match 'window\.backgroundColor = \.clear' \
  "QuotaRadar/AppDelegate.swift" \
  "Panel window background must be clear for status bar transparency to be visible"
assert_no_match 'statusItem\?\.menu = menu' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar glass surface must not be attached as an NSMenu"
assert_no_match 'class GlassMenu' \
  "QuotaRadar/AppDelegate.swift" \
  "The old NSMenu wrapper should be removed because it prevents the intended translucent glass surface"
assert_match 'homeProviderStats' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should expose provider stats for the home view"
assert_match 'homeCategoryStats' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should expose status bar category groups"
assert_match 'ProviderCategoryStats' \
  "QuotaRadar/Models/APIKey.swift" \
  "Status bar category groups should have a model instead of ad hoc view filtering"
assert_match 'struct QuotaPresentation' \
  "QuotaRadar/Models/APIKey.swift" \
  "Quota values should have a shared presentation model instead of each view inventing display strings"
assert_match 'enum QuotaDataSource' \
  "QuotaRadar/Models/APIKey.swift" \
  "Quota presentation should expose where the number came from"
assert_match 'var quotaPresentation: QuotaPresentation' \
  "QuotaRadar/Models/APIKey.swift" \
  "APIKey should expose a numeric-first quota presentation"
assert_match 'menuTopQuotaItems' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should expose top quota items for the menu bar summary"
assert_match 'menuQuotaSummary' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should expose anxiety-focused status counts for the menu bar"
assert_match 'menuAttentionQuotaItems' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should expose only credentials that need attention for the menu bar"
assert_match 'struct MenuQuotaSummary' \
  "QuotaRadar/Models/APIKey.swift" \
  "Menu bar summary counts should live in a shared model instead of view-only logic"
assert_match 'var statusBarCredentialLabel' \
  "QuotaRadar/Models/APIKey.swift" \
  "APIKey should expose a safe status-bar credential label that hides cookie JSON"
assert_match 'struct MenuQuotaItem' \
  "QuotaRadar/Models/APIKey.swift" \
  "Menu bar should use ranked quota items instead of rendering the full provider dashboard"
assert_match 'var id: String \{ provider\.id \}' \
  "QuotaRadar/Models/APIKey.swift" \
  "ProviderStats identity should be stable across quota refreshes so expanded sections and scroll position are preserved"
assert_no_match 'let id = UUID\(\)' \
  "QuotaRadar/Models/APIKey.swift" \
  "ProviderStats must not use a fresh UUID because refreshes would recreate every provider row"
assert_match '\$0\.remaining != Int\.max' \
  "QuotaRadar/Models/APIKey.swift" \
  "ProviderStats must exclude Int.max sentinel remaining values from provider totals to avoid arithmetic overflow"
assert_match '\$0\.limit != Int\.max' \
  "QuotaRadar/Models/APIKey.swift" \
  "ProviderStats must exclude Int.max sentinel limits from provider totals to avoid arithmetic overflow"
assert_match 'homeVisibleWithoutKeys' \
  "QuotaRadar/Models/APIKey.swift" \
  "New coding-plan providers should be able to appear on the home view before keys are configured"
assert_match 'provider\.homeVisibleWithoutKeys' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Home provider stats should include supported coding-plan provider placeholders"
assert_no_match 'provider.category == "Search"' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Home provider stats must include configured LLM providers instead of hiding them"
assert_no_match 'monitor.providerStats' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar home view should not use the old full provider stats data source"
assert_no_match 'ScrollView\(showsIndicators' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover should not be a long scrolling dashboard"
assert_match 'MenuProviderOverviewCard' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover should include provider-level quota statistics instead of only expired or low API keys"
assert_match 'ForEach\(monitor\.homeCategoryStats\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar provider overview should be grouped by AI Search and LLM provider categories"
assert_match 'MenuProviderQuotaCell' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar provider overview should render compact per-provider quota cells"
assert_no_match 'ForEach\(monitor\.homeProviderStats\) \{ stat in' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar home view should not render a flat provider list"
assert_match 'MenuMetricStrip' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover should show available, low-quota, and failed counts instead of provider/key totals"
assert_match 'struct MonitorModule<Content: View>' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover should use lightweight monitoring modules instead of large dashboard cards"
assert_match 'struct MenuMetricStrip' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover should use a compact metric strip like Stats/iStat Menus"
assert_match 'MenuMetricStrip\(summary: monitor\.menuQuotaSummary\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar summary metrics should be rendered as a compact strip"
assert_match 'struct MenuSectionHeader' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar sections should use a consistent compact monitoring header"
assert_match 'MenuAttentionItemsView' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover should keep credentials needing attention as secondary detail below provider statistics"
assert_match 'ForEach\(monitor\.menuAttentionQuotaItems' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar attention rows should come from QuotaMonitor.menuAttentionQuotaItems"
assert_no_match 'StatItem\(value: "\\\\\(totalProviders\\\\\)", label: L10n\.t\(\.providers\)\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar summary should not spend prime space on provider totals"
assert_no_match 'StatItem\(value: "\\\\\(totalKeys\\\\\)", label: L10n\.t\(\.keys\)\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar summary should not spend prime space on credential totals"
assert_match 'statusBarCredentialLabel' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar rows should use a safe credential label instead of rendering raw cookie JSON"
assert_no_match 'Text\(key\.maskedKey\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar rows must not show masked raw cookie JSON for dashboard-session providers"
assert_match 'L10n\.t\(\.needsAttention' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar attention list should have a clear localized title"
assert_no_match 'spring\(response: 0\.3\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar collapsible sections should not use spring animation"
assert_no_match 'Image\(systemName: "chevron.down"\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar collapsible sections should not show triangle/chevron disclosure icons"
assert_no_match 'openDashboard\(\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar header should avoid a second ambiguous dashboard action next to Settings"
assert_no_match 'MenuFooterBar' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover must not reserve a bottom footer because it gets clipped in the fixed-height popover"
assert_no_match 'Label\(L10n\.t\(\.providersHeader\), systemImage: "rectangle\.grid\.1x2"\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar footer must not render the Quota Overview title as a clipped visible button"
assert_no_match 'systemName: "rectangle\.grid\.1x2"' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar header should not show a second ambiguous dashboard icon next to Settings"
assert_match 'systemName: "slider\.horizontal\.3"' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar header should expose a single control-panel Settings action"
assert_no_match 'controlBackgroundColor\.withAlphaComponent\(0\.34\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar header action should not look like another heavy grey circular card"
assert_match 'toolTip = helpText' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Shared status bar icon buttons should expose their localized tooltip"
assert_match 'StatusHeaderIconButton' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar header actions should use a shared AppKit icon button with a stable hit target"
assert_match 'final class StatusHeaderActionButton: NSButton' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar header actions should use an AppKit NSButton instead of relying on SwiftUI Button in a transient popover"
assert_match 'override func acceptsFirstMouse\(for event: NSEvent\?\) -> Bool' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar header AppKit buttons should accept the first click while the app is inactive"
assert_match 'button\.actionHandler = action' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar header AppKit buttons should retain the action closure inside the NSButton"
assert_match 'override func mouseDown\(with event: NSEvent\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar header AppKit buttons should run the action on the first physical click inside the transient popover"
assert_match 'let handler = actionHandler' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar header buttons should capture the action before the transient popover can deallocate the button"
assert_no_match 'button\.sendAction\(on: \[\.leftMouseDown\]\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar header buttons should not rely on NSControl event masks inside the transient popover"
assert_match 'override func performClick\(_ sender: Any\?\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar header AppKit buttons should also respond to accessibility perform-click actions"
assert_match '\.allowsHitTesting\(false\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar decorative glass and stroke layers must not intercept button clicks"
assert_match '\.environment\(\\.menuGlassTransparency, statusBarTransparency\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar transparency should propagate into inner quota cards, not only the outer blur layer"
assert_match '@Environment\(\\.menuGlassTransparency\)' \
  "QuotaRadar/Views/Components.swift" \
  "Status bar GlassCard should read the configured transparency"
assert_match 'GlassBackground\(transparency: menuGlassTransparency\)' \
  "QuotaRadar/Views/Components.swift" \
  "Status bar card backgrounds should be driven by the configured transparency"
assert_match 'materialOpacity' \
  "QuotaRadar/Views/Components.swift" \
  "Status bar card material should change opacity with the transparency slider"
assert_match '0\.28 \+ \(1 - transparency\) \* 0\.62' \
  "QuotaRadar/Views/Components.swift" \
  "Status bar cards should visibly change material opacity with the transparency slider"
assert_match '\.fill\(\.regularMaterial\)' \
  "QuotaRadar/Views/Components.swift" \
  "Status bar cards should use regular material so quota text stays readable over bright or busy backgrounds"
assert_match 'baseFillOpacity' \
  "QuotaRadar/Views/Components.swift" \
  "Status bar cards should include an adaptive fill layer so text remains readable over busy backgrounds"
assert_match 'backdropTintOpacity' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar menu should use a light adaptive tint over the real blur instead of an opaque grey panel"
assert_match 'private var blurOpacity: Double \{' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar transparency should affect the outer blur layer, not only inner cards"
assert_match '0\.32 \+ \(1 - statusBarTransparency\) \* 0\.58' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar outer blur opacity should visibly change across the full transparency range"
assert_match 'Slider\(value: \$appearanceStore\.statusBarTransparency, in: 0\.0\.\.\.1\.0\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Status bar transparency slider should support the full 0% to 100% range"
assert_match 'openPreferencesFromStatusPopover\(destination: \.settings\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar settings icon should use the status-popover handoff path"
assert_match 'func openPreferencesFromStatusPopover\(destination: SettingsDestination\)' \
  "QuotaRadar/AppDelegate.swift" \
  "AppDelegate should expose a popover-safe window handoff for status bar buttons"
assert_match 'closeStatusPopover\(\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Popover-safe window handoff should close the status popover before opening a main window"
assert_match 'statusPanelClickMonitor' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should keep a native event-monitor fallback for header controls"
assert_match 'statusPanelGlobalClickMonitor' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should also observe global clicks because non-activating panels may not deliver local events"
assert_match 'NSEvent\.addLocalMonitorForEvents\(matching: \[\.leftMouseDown\]\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should monitor mouse-downs so header Settings clicks work in a non-activating panel"
assert_match 'NSEvent\.addGlobalMonitorForEvents\(matching: \[\.leftMouseDown\]\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should monitor global mouse-downs for non-activating panel Settings clicks"
assert_match 'statusHeaderSettingsHitRect\(in contentView: NSView\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should define a stable header Settings hit target independent of SwiftUI hit testing"
assert_match 'StatusPanelSettingsOverlayButton' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should install a transparent native Settings button above SwiftUI content"
assert_match 'StatusPanelContainerView' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should use an AppKit container so the Settings overlay is a sibling above SwiftUI content"
assert_no_match 'panel\.contentViewController = hostingController' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel must not put SwiftUI directly in the panel when native overlay controls need reliable clicks"
assert_match 'installStatusPanelSettingsOverlay' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should wire the transparent native Settings overlay during panel setup"
assert_match 'handleStatusPanelSettingsClick\(at:.*in:' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should route local and global click monitors through one Settings hot-zone handler"
assert_match 'contentView\.convert\(event\.locationInWindow, from: nil\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel local click handling should convert event points into the content view coordinate system"
assert_match 'NSEvent\.mouseLocation' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel global click handling should use screen coordinates instead of unreliable window-local global events"
assert_match 'contentView\.isFlipped' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar Settings hot zone should account for flipped SwiftUI hosting views"
assert_match 'openPreferencesFromStatusPopover\(destination: \.settings\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Clicking the status header Settings hot zone should open the managed Settings tab"
assert_match 'monitor\.refreshProvider\(item\.provider\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar top item rows should refresh only the selected provider"
assert_no_match 'onRefresh: \{ monitor\.refreshAll\(\) \}' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar home view must not expose only a single global refresh action"
assert_match 'RefreshButton\(isRefreshing: \.constant\(isRefreshing\), isEnabled: item\.canRefresh' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Each status bar top item row should own its refresh button"
assert_match 'MenuContentView.menuSize' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar hosting view must use MenuContentView.menuSize to avoid clipping"
assert_match 'statusItem = NSStatusBar\.system\.statusItem\(withLength: NSStatusItem\.squareLength\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar item should use a compact square hit target so it is less likely to be hidden by long app menus"
assert_no_match 'button\.sendAction\(on: \[\.leftMouseDown\]\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar item should use the default mouse-up action so the transient popover is not immediately closed by the same click"
assert_match 'button\.toolTip = L10n\.t\(\.apiQuotaTitle\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar item should expose the localized quota-relief title as its tooltip"
assert_match 'AppLanguageStore\.shared\.\$language' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar AppKit controls should subscribe to language changes instead of keeping launch-time localized strings"
assert_match 'updateLocalizedStatusBarStrings' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar AppKit controls should refresh tooltips and accessibility labels when language changes"
assert_match 'statusPanelSettingsOverlayButton' \
  "QuotaRadar/AppDelegate.swift" \
  "The transparent status-panel Settings button should be retained so its localized tooltip can update"
assert_match 'button\.imagePosition = \.imageOnly' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar item should center the icon inside the square menu-bar hit target"
assert_match 'button\.imageScaling = \.scaleProportionallyDown' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar item should scale the icon visibly inside the menu-bar button"
assert_match 'button\.contentTintColor = \.labelColor' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar item should explicitly tint the template icon with the menu-bar label color"
assert_match 'panel\.animationBehavior = \.none' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should not fade through a low-contrast half-transparent opening state"
assert_match 'hostingController\.view\.wantsLayer = true' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar hosting view should use a clear layer so the popover can render as frosted glass"
assert_match 'backgroundColor = NSColor\.clear\.cgColor' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar hosting view should not paint an opaque background over the frosted glass"
assert_match 'menuSize = CGSize\(width: 560, height: 680\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar summary popover should be wide enough to fit provider-level quota statistics without scrolling"
provider_overview_column_count="$(awk '
  /private let columns = \[/ { inside = 1; count = 0; next }
  inside && /\]/ { print count; exit }
  inside && /GridItem\(\.flexible\(\), spacing: 8\)/ { count++ }
' QuotaRadar/Views/MenuContentView.swift)"
if [[ "$provider_overview_column_count" != "4" ]]; then
  fail "Status bar provider overview should keep four columns in the fixed-size popover"
fi
assert_no_match '^[[:space:]]*ScrollView' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar body content should fit in the expanded popover instead of requiring scrolling"
assert_match 'contentHorizontalInset' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar home view should reserve an explicit horizontal inset to avoid left-edge clipping"
assert_match 'contentTopSafeInset' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar summary popover should reserve top breathing room below the menu bar"
assert_match 'contentTopSafeInset: CGFloat = 12' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Arrowless status panel should not keep the old large top blank reserved for an NSPopover arrow"
assert_match 'headerFillOpacity' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar header should fill the top area with a compact material strip instead of leaving empty glass"
assert_match 'RoundedRectangle\(cornerRadius: 14' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar header strip should use a compact rounded macOS palette shape"
assert_match 'HeaderStatusPill' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar header should still be able to render compact non-error refresh state inline"
assert_match 'if lastError == nil, let headerStatusMessage' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar header should not render failed-refresh errors as a text pill that crowds the quote"
assert_match 'SettingsAttentionDot' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar header should show failed quota state as a compact red dot on the Settings control"
assert_match 'failedCount: monitor\.menuQuotaSummary\.failedCount' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar header should receive the failed credential count, not only the last refresh error"
assert_match 'let failedCount: Int' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar header should model failed credentials separately from transient refresh errors"
assert_match 'settingsHelpText' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar Settings control should expose failed-refresh or failed-credential detail through hover help"
assert_match 'hasSettingsAttention' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar Settings control should show its red dot when there is a failed-refresh state or failed credentials"
assert_match 'failedCount > 0' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar Settings red dot should remain visible while the menu summary reports failed credentials"
assert_match 'HeaderQuotePill' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar header should show a compact built-in AI quote without adding another row"
assert_match 'headerStatusMessage' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar header should keep non-error refresh messages in one compact status value"
assert_no_match 'lastError \?\? refreshMessage' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar header should not prefer verbose failed-refresh text over the quote"
assert_no_match 'lineLimit\(2\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar header should not reserve a two-line error area that leaves the top panel visually empty"
assert_match 'button\.target = button' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar Settings button should keep an AppKit target/action path in the transient status panel"
assert_match 'button\.action = #selector\(StatusHeaderActionButton\.performHeaderAction' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar Settings button should expose a concrete AppKit action selector"
assert_match '@objc func performHeaderAction' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar Settings button should centralize click handling so mouse and accessibility paths behave the same"
assert_match 'AIQuoteStore\.shared\.advance' \
  "QuotaRadar/AppDelegate.swift" \
  "Opening the status panel should rotate the built-in AI quote without calling a network model"
assert_match 'quoteStore\.currentQuoteText\(\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar content should render the current built-in AI quote"
assert_match 'let currentLanguage = languageStore\.language' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar SwiftUI content should explicitly depend on AppLanguageStore so hidden panels repaint after language changes"
assert_match '\.id\(currentLanguage\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar SwiftUI content should rebuild localized text when the selected language changes"
assert_match 'struct AIQuoteLibrary' \
  "QuotaRadar/Models/AIQuoteLibrary.swift" \
  "Built-in AI quotes should live in a local library"
assert_no_match 'URLSession|http|https|apiKey|Bearer|sk-' \
  "QuotaRadar/Models/AIQuoteLibrary.swift" \
  "Built-in AI quotes must not call a model API or embed secrets"
assert_match 'menuTopQuotaItems: \[MenuQuotaItem\]' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should expose a compact status bar item set"
assert_match 'MenuQuotaItem\.topItems\(from: homeProviderStats, limit: 3\)' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Status bar summary should cap top items at three to avoid vertical clipping"
assert_match 'statusBarProviderQuotaText' \
  "QuotaRadar/Models/APIKey.swift" \
  "ProviderStats should expose compact provider-level quota text for the status bar"
assert_match 'statusBarProviderBadgeText' \
  "QuotaRadar/Models/APIKey.swift" \
  "ProviderStats should expose compact provider-level badges for the status bar"
assert_match 'menuGlassCornerRadius' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar menu should have a defined frosted-glass rounded container"
assert_match 'VisualEffectBlur\(material: \.popover' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar menu should use the native popover material for a readable macOS glass effect"
assert_match '\.clipShape\(RoundedRectangle\(cornerRadius: Self\.menuGlassCornerRadius' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar menu should clip the frosted background to a modern rounded container"
assert_match 'providerHeaderLeadingPadding' \
  "QuotaRadar/Views/SettingsView.swift" \
  "API Keys provider headers should reserve explicit leading space so provider icons are not clipped by the macOS List edge"
assert_match '\.padding\(\.leading, Self\.providerHeaderLeadingPadding\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "API Keys provider headers must apply their leading padding inside the section header"
assert_no_match 'hostingView\.frame = NSRect\(x: 0, y: 0, width: 340, height: 480\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar hosting view must not be smaller than the SwiftUI menu"
assert_match 'EmptyQuotaStateView' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar menu must have a first-run empty state"
assert_match 'quotaPresentation' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Key rows must use the shared quota presentation model"
assert_match 'Text\(key\.statusBarCredentialLabel\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar key rows should show masked API keys or safe cookie credential labels"
assert_no_match 'Text\(key\.name\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar key rows must not show TAVILY_API_KEY-style environment variable names"
assert_no_match 'key\.key\.count' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings API key rows must not waste the right side on API key character counts"
assert_no_match 'chars' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings API key rows must not show API key character counts"
assert_match 'Text\(key\.resetSummary\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings API key rows should show quota reset timing on the right side"
assert_match 'Text\(key\.quotaDisplayText\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings API key rows should show provider quota labels instead of only normalized remaining/limit values"
assert_no_match 'Text\("\\\(remaining\)/\\\(limit\)"\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings API key rows must not collapse multi-window coding-plan quotas to one normalized remaining/limit value"
assert_match 'sortedKeysByCurrentQuota' \
  "QuotaRadar/Models/APIKey.swift" \
  "ProviderStats should expose API keys sorted by current quota descending"
assert_no_match 'ProviderStats\.sortedByCurrentQuota' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Provider sections should keep the product-defined provider order"
assert_match 'return stats' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "ProviderStats should preserve Provider.allCases order instead of sorting provider sections by quota"
assert_no_match 'ForEach\(stat\.sortedKeysByCurrentQuota\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover should not list every key inside every provider"
assert_match 'sortedByCurrentQuota' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings API key sections should list keys by current quota descending"
assert_match 'Text\(presentation\.badgeText\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar key badges should come from the shared quota presentation"
assert_match 'presentation\.resetText' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar top item rows must expose reset timing through the shared presentation"
assert_match 'var resetSummary: String' \
  "QuotaRadar/Models/APIKey.swift" \
  "Quota reset timing should be shared by all key row views"
assert_match 'L10n\.t\(\.noResetCycle' \
  "QuotaRadar/Models/APIKey.swift" \
  "Money-balance providers should make clear that quota does not reset on a cycle"
assert_match 'L10n\.t\(\.resetsMonthlyDay1' \
  "QuotaRadar/Models/APIKey.swift" \
  "Tavily should communicate its known monthly reset cycle even before the next usage refresh"
assert_match 'L10n\.t\(\.resetNotExposed' \
  "QuotaRadar/Models/APIKey.swift" \
  "Providers without reset data should not pretend to know reset timing"
assert_match 'ProviderIcon\(provider: item.provider' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Menu top item rows should use official provider icons"
assert_match 'ModernPage\(' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Providers page must have its own modern header so the first provider card is not hidden under the title area"
assert_match 'keyProviderCategories' \
  "QuotaRadar/Views/SettingsView.swift" \
  "API Keys tab should group configured keys by AI Search and LLM so OpenCode Go is visible under LLM"
assert_match 'Provider\.categoryDisplayOrder\.compactMap' \
  "QuotaRadar/Views/SettingsView.swift" \
  "API Keys tab should use the shared AI Search then LLM category order"
assert_match 'NavigationSplitView' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main window should use the current macOS sidebar/content split view instead of an older tab-only layout"
assert_no_match '\.frame\(minWidth: 820, minHeight: 580\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main window must not keep the old narrow minimum size because the sidebar plus provider content gets squeezed"
assert_no_match '\.frame\(minWidth: 1040, minHeight: 640\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main window content must not force the default 1040px width as the minimum width"
assert_match '\.frame\(minWidth: 900, minHeight: 600\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main window should allow horizontal resizing below the default width while preserving usable provider panels"
assert_match 'preferredSettingsContentSize = NSSize\(width: 1040, height: 640\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Main window should still open at the comfortable default width"
assert_match 'minimumSettingsWindowSize = NSSize\(width: 900, height: 600\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Main window minimum size should allow users to resize horizontally below the default width"
assert_no_match 'window\.setContentSize\(NSSize\(width: 640, height: 560\)\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Settings window creation must not force the modern SettingsView into the old narrow 640x560 window"
assert_no_match 'window\.minSize = NSSize\(width: 560, height: 460\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Settings window minimum size must not remain smaller than the modern SettingsView layout"
assert_match 'preferredSettingsContentSize' \
  "QuotaRadar/AppDelegate.swift" \
  "Settings window should use one shared modern content size"
assert_match 'keepSettingsWindowOnScreen' \
  "QuotaRadar/AppDelegate.swift" \
  "Opening settings should pull any previously off-screen window back onto the visible display"
assert_match 'closeRestoredSettingsWindows' \
  "QuotaRadar/AppDelegate.swift" \
  "Dock icon reopen should replace restored stale settings windows instead of reusing a broken split-view state"
assert_match 'preferredSettingsVisibleFrame' \
  "QuotaRadar/AppDelegate.swift" \
  "Settings window should prefer the non-negative primary working screen instead of a stale negative-coordinate external display"
assert_match 'CGGetActiveDisplayList' \
  "QuotaRadar/AppDelegate.swift" \
  "Settings window placement should inspect all active displays and choose a non-negative display when available"
assert_no_match '\.frame\(minWidth: 480, maxWidth: 560' \
  "QuotaRadar/QuotaRadarApp.swift" \
  "The native Settings scene must not constrain the same SettingsView to a narrow 560-point maximum"
assert_match 'SettingsSidebarView' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main window should have a dedicated macOS-style sidebar"
assert_no_match 'List\(selection: \$selection\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main window sidebar should not rely on NavigationSplitView List selection because it is not rendering/clicking reliably in the custom NSWindow"
assert_no_match 'NavigationLink\(value: destination\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main window sidebar should not rely on value NavigationLink rows that disappear in the custom NSWindow"
assert_match 'SidebarNavigationButton' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main window sidebar rows should be explicit visible clickable buttons"
assert_match 'selection = destination' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main window sidebar buttons should explicitly switch the selected page"
assert_no_match '\.tag\(destination as SettingsDestination\?\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main window sidebar rows must not be inert Label rows that only rely on a tag"
assert_no_match '\.listStyle\(\.sidebar\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main window sidebar should not use a List style that leaves the navigation rows blank here"
assert_no_match 'ToolbarItemGroup|\.toolbar \{' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credentials page should not duplicate the in-page credential actions in the top-right toolbar"
assert_match 'MaterialPanel' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main window content should use modern material-backed panels instead of the old heavy glass card stack"
assert_no_match 'TabView\(selection:' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main window should not keep the old tab view chrome after adopting a macOS sidebar layout"
assert_match 'KeyProviderCategorySection' \
  "QuotaRadar/Views/SettingsView.swift" \
  "API Keys tab should render category sections instead of one long flat provider list"
assert_match 'ProviderIcon\(provider: provider' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings provider headers should use official provider icons"
assert_match 'providerCategories' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings Providers page should group providers into AI Search and LLM sections"
assert_match 'ProviderSettingsCategorySection' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings Providers page should render collapsible provider category sections"
assert_match 'ProviderQuotaMonitorTable' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota monitoring should use a compact provider table instead of stacked dashboard cards"
assert_match 'ProviderQuotaMonitorRow' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota monitoring should render each provider as a compact monitoring row"
assert_match '@State private var isExpanded = false' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider quota rows should default to a compact collapsed overview so the page starts as a monitor, not a long key dashboard"
assert_match 'ProviderQuotaKeyTableHeader' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Expanded provider quota rows should show a stable table header for key details"
assert_match 'ProviderQuotaKeyTableRow' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Expanded provider quota rows should render key details in table-like rows"
assert_no_match 'ProviderCard\(provider: stat\.provider' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota monitoring should not continue to render one large card per provider"
assert_no_match 'StatBadge\(' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota monitoring should not use large repeated stat badges for every provider"
assert_no_match 'spring\(response: 0\.3\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings collapsible sections should not use spring animation because it makes panels fly down"
assert_no_match 'move\(edge: \.top\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings collapsible sections should not use top-edge movement transitions"
assert_match 'settingsCollapseAnimation = Animation\.easeInOut\(duration: 0\.16\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings collapsible sections should use a short calm ease-in-out animation"
assert_match 'withAnimation\(settingsCollapseAnimation\) \{ isExpanded\.toggle\(\) \}' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings provider cards should collapse with the shared calm animation"
assert_match 'CollapsibleBanner' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings collapsible sections should use a clickable banner as the disclosure control"
assert_no_match 'Image\(systemName: "chevron.down"\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings collapsible sections should not show a triangle/chevron disclosure icon"
assert_match '\.contentShape\(RoundedRectangle\(cornerRadius: 12, style: \.continuous\)\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings collapsible banners should make the full banner clickable"
assert_match 'providerSummaryRow' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider quota rows should keep the provider summary as the dedicated collapse hit target"
assert_match 'ZStack\(alignment: \.trailing\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider quota rows should make the full row surface a collapse target while overlaying the refresh control"
assert_match 'trailingControlReserve' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider quota rows should reserve trailing space so row actions do not steal the collapse hit target"
assert_match 'Button\(action: onToggle\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider card banners should use a real button for reliable clicks on the non-control banner area"
assert_match 'monitor\.refreshProvider\(provider\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings provider sections should refresh only the selected provider"
assert_no_match 'Refresh All' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings must not present quota refresh as one global action"
assert_match 'AppSettingsView' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings should include an app settings tab for language selection"
assert_match 'Picker\(L10n\.t\(\.language' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings should provide a language picker"
assert_no_match 'Text\(L10n\.t\(\.appLanguage\)\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings language panel should not repeat an App Language summary row below the segmented picker"
assert_match 'AppAppearanceStore' \
  "QuotaRadar/Models/AppAppearance.swift" \
  "QuotaRadar should persist appearance settings such as status bar transparency"
assert_match 'autoRefreshInterval' \
  "QuotaRadar/Models/AppAppearance.swift" \
  "QuotaRadar should persist the automatic refresh interval"
assert_match 'AutoRefreshIntervalOption' \
  "QuotaRadar/Models/AppAppearance.swift" \
  "QuotaRadar should expose a finite set of safe automatic refresh intervals"
assert_match 'QuotaConsumingAutoRefreshIntervalOption' \
  "QuotaRadar/Models/AppAppearance.swift" \
  "Quota-consuming providers should use a separate long-cadence refresh interval option"
assert_match 'quotaConsumingAutoRefreshInterval' \
  "QuotaRadar/Models/AppAppearance.swift" \
  "Quota-consuming automatic refresh should be persisted separately from normal free refresh"
assert_match 'LaunchAtLoginStore' \
  "QuotaRadar/Models/AppAppearance.swift" \
  "QuotaRadar should expose a launch-at-login setting"
assert_match 'SMAppService\.mainApp' \
  "QuotaRadar/Models/AppAppearance.swift" \
  "Launch-at-login should use the modern macOS SMAppService main-app login item API"
assert_match 'statusBarTransparency' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar glass UI should react to the configured transparency"
assert_match 'Slider\(value: \$appearanceStore\.statusBarTransparency, in: 0\.0\.\.\.1\.0\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Language/appearance settings should expose a full 0%-100% status bar transparency slider"
assert_match 'Picker\(L10n\.t\(\.autoRefreshInterval' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings should let the user configure automatic refresh cadence"
assert_match 'Picker\(L10n\.t\(\.quotaConsumingAutoRefreshInterval' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings should expose a separate long-cadence automatic refresh option for quota-consuming providers"
assert_match 'Toggle\(isOn: Binding' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings should expose launch-at-login as a real toggle"
assert_match 'L10n\.t\(\.autoRefreshBraveWarning' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Auto refresh settings should warn that Brave is skipped because checks consume search quota"
assert_match 'L10n\.t\(\.quotaConsumingAutoRefreshWarning' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota-consuming auto refresh settings should warn that real search quota will be spent"
assert_no_match 'Text\(L10n\.t\(\.apiKeyConfiguration\)\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credentials page must not repeat the same Credential Configuration title in the top page header and local panel"
assert_no_match '0\.20\.\.\.0\.88|0\.72 \+ \(1 - statusBarTransparency\) \* 0\.20|0\.20 - statusBarTransparency \* 0\.12' \
  "QuotaRadar" \
  "Status bar transparency must not keep the old narrow range or barely visible opacity formula"
assert_match '\.providersTab: "额度监控"' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Simplified Chinese navigation should name the quota observation page explicitly"
assert_match '\.apiKeysTab: "配置凭据"' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Simplified Chinese navigation should avoid implying every credential is an API key"
assert_match '\.settingsTab: "设置"' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Simplified Chinese navigation should use the broader Settings label"
assert_match 'APIKeyConfigurationPanel' \
  "QuotaRadar/Views/SettingsView.swift" \
  "API Keys page should expose a visible in-page API key configuration panel"
assert_match 'L10n\.t\(\.apiKeyConfiguration\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "API key configuration panel should have a clear localized title"
assert_match 'Button\(action: onAddKey\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "API key configuration panel should expose a direct Add Key action in the main content area"
assert_match 'Button\(action: onImportEnv\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "API key configuration panel should expose a direct .env import action in the main content area"
assert_match 'APIKeyProviderBanner' \
  "QuotaRadar/Views/SettingsView.swift" \
  "API Keys provider sections should use a clickable provider banner"
assert_match '@State private var isExpanded = true' \
  "QuotaRadar/Views/SettingsView.swift" \
  "API Keys provider sections should own provider-level collapse state"
assert_match 'APIKeyManagementRow' \
  "QuotaRadar/Views/SettingsView.swift" \
  "API Keys page should use management-focused key rows rather than quota overview rows"
assert_no_match 'KeyRowItem' \
  "QuotaRadar/Views/SettingsView.swift" \
  "API Keys page should not use quota-observation rows that duplicate the Providers page"
assert_no_match '\.onTapGesture' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential rows must not open the edit sheet when the user is trying to toggle enabled state"
assert_match 'onSetActive: \{ isActive in' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential rows should route enabled-state changes through a dedicated handler"
assert_match 'Toggle\(isOn: Binding\(get: \{ key\.isActive \}' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential rows should enable or disable directly without opening the edit sheet"
assert_match 'provider\.supportsDashboardReauthentication \? L10n\.t\(\.dashboardSession\) : L10n\.t\(\.apiKey\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Dashboard-session providers should label their secret as a session cookie rather than an API key"
assert_match 'L10n\.t\(\.apiKeysTab' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings tab labels should use localized strings"
assert_match 'L10n\.t\(\.apiQuotaTitle' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar title should use localized strings"
assert_match 'L10n\.categoryTitle\(provider\.statusBarCategoryTitle' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider cards should localize category subtitles instead of showing raw English category labels"
assert_no_match '\.providersTab: "Provider"' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Simplified Chinese UI should not leave Providers untranslated as Provider"
assert_no_match '\.providers: "Provider"' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Simplified Chinese status bar stats should not leave Providers untranslated as Provider"
assert_match '\.provider: "服务商"' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Simplified Chinese form labels should not leave Provider untranslated"
assert_no_match 'provider 的额度|provider 刷新' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Simplified Chinese helper text should not keep provider as an untranslated UI word"
assert_match 'supportsDashboardReauthentication' \
  "QuotaRadar/Models/APIKey.swift" \
  "Dashboard-cookie Coding Plan providers should declare that they support in-app reauthentication"
assert_match 'cookieDomains' \
  "QuotaRadar/Models/APIKey.swift" \
  "Dashboard-cookie Coding Plan providers should declare the domains whose cookies can be saved"
assert_match 'dashboardAuthenticationCookieNames' \
  "QuotaRadar/Models/APIKey.swift" \
  "Dashboard-cookie providers should declare authentication cookie names for automatic saving"
assert_match 'DashboardReauthConfig' \
  "QuotaRadar/Services/DashboardReauth.swift" \
  "Dashboard reauthentication should have a provider-specific configuration model"
assert_match 'DashboardCookieBuilder' \
  "QuotaRadar/Services/DashboardReauth.swift" \
  "Dashboard reauthentication should build Cookie headers through a testable helper"
assert_match 'containsRequiredCookie' \
  "QuotaRadar/Services/DashboardReauth.swift" \
  "Dashboard reauthentication should wait for provider authentication cookies before auto-saving"
assert_match 'import WebKit' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should use an in-app WebKit login window"
assert_match 'WKWebView' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should embed WKWebView"
assert_match 'WKUIDelegate' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should handle OAuth popup windows such as Querit Google login"
assert_match 'webView\.uiDelegate = context\.coordinator' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should install a WKUIDelegate for login popups"
assert_match 'webView\(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures\)' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should load target=_blank OAuth windows instead of dropping them"
assert_match 'WKHTTPCookieStoreObserver' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should observe cookie changes instead of only page navigation"
assert_match 'clearProviderCookiesBeforeLoading' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should clear stale provider cookies before opening the login page"
assert_match 'cookieStore\.delete' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should delete stale WebView cookies for the provider domain"
assert_match 'cookiesDidChange' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should retry cookie capture when login cookies change"
assert_match 'WKNavigationDelegate' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should observe dashboard navigation so it can auto-save cookies after login"
assert_match 'webView\(_ webView: WKWebView, didFinish navigation: WKNavigation!\)' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should check cookies when the WebView finishes loading a dashboard page"
assert_match 'onCookiesAvailable' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should expose an automatic cookie-save callback"
assert_match 'reauthenticatedSecret' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should preserve non-cookie JSON credential metadata when refreshing cookies"
assert_no_match 'updatedKey\.key = cookieHeader' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication must not overwrite JSON dashboard credentials with a raw Cookie header"
assert_match 'validateAndPersistCookies' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should validate captured cookies before saving and closing"
assert_match 'try await QuotaService\(\)\.checkQuota\(for: candidateKey, bypassCooldown: true\)' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should call the provider quota endpoint before accepting captured cookies"
assert_match 'catch QuotaError\.unauthorized' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should keep the login window open when captured cookies still return unauthorized"
assert_match 'didAutoSave = false' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should allow retry after a captured cookie fails validation"
assert_no_match 'monitor\.refreshProvider\(provider\)' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should not close first and refresh later because invalid cookies look like no-op"
assert_match 'reauthStillUnauthorized' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Dashboard reauthentication should explain when captured cookies still fail provider login validation"
assert_match 'WKWebsiteDataStore\.default\(\)\.httpCookieStore' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should read only cookies from the in-app WebKit data store"
assert_match 'monitor\.updateKey' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Saving dashboard cookies should update the selected QuotaRadar credential"
assert_match 'verifiedKey\.remaining = result\.remaining' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Saving dashboard cookies should persist the validated quota result instead of closing first and refreshing later"
assert_match 'DashboardReauthSheet' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings should expose dashboard reauthentication for cookie-backed providers"
assert_match 'Credential expired' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Expired dashboard credentials should have an English localized label"
assert_match '凭据已过期' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Expired dashboard credentials should have a Simplified Chinese localized label"
assert_match 'autoCookieSaveHint' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Dashboard reauthentication should explain that cookies will be saved automatically after login"
assert_match 'QuotaError\.unauthorized' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Unauthorized quota refreshes should mark dashboard credentials as expired"
assert_match 'key\.lastDiagnosticMessage = key\.provider\.supportsDashboardReauthentication \? L10n\.t\(\.credentialExpired\) : error\.localizedDescription' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Dashboard-cookie providers should not describe expired cookies as invalid API keys"
assert_no_match 'Cookies\.binarycookies|Login Data|Library/Application Support/Google/Chrome|SecKeychain' \
  "QuotaRadar" \
  "QuotaRadar must not scrape browser cookie databases or use login Keychain APIs for reauthentication"
assert_no_match 'Image\(systemName: provider\.icon\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings provider headers must not fall back to colored SF Symbols when provider icons exist"
assert_no_match 'clipShape\(Circle\(\)\)' \
  "QuotaRadar/Views/Components.swift" \
  "ProviderIcon must not crop official provider logos into generic circles"
assert_match 'drawQuotaCell' \
  "scripts/generate_app_icon.swift" \
  "The app icon generator should use the approved quota-cell icon"
assert_match 'drawQuotaCellFill' \
  "scripts/generate_app_icon.swift" \
  "The app icon generator should render one large, clear quota-cell fill instead of tiny reserve segments"
assert_match 'drawMonitorTileBackground' \
  "scripts/generate_app_icon.swift" \
  "The app icon generator should use a crisp monitor-style tile background"
assert_no_match 'topGlow|drawGlassPanel' \
  "scripts/generate_app_icon.swift" \
  "The app icon generator should remove the old blurred glass glow treatment"
assert_no_match 'drawQuotaCellSegments|drawProviderDots|keyRingCenter' \
  "scripts/generate_app_icon.swift" \
  "The app icon generator should remove tiny decorations that make the battery blurry at small sizes"
assert_no_match 'drawModernQuotaGlyph|drawLiquidAppGlyph' \
  "scripts/generate_app_icon.swift" \
  "The app icon generator should remove earlier rejected app icon drawings"
assert_match 'title: L10n\.t\(\.providersHeader' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Providers tab header must label the page"
assert_match 'ClaudeSettingsImporter' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should initialize from ~/.claude/settings.json on first launch"
assert_match 'didAttemptClaudeSettingsImport' \
  "QuotaRadar/Services/APIKeyStore.swift" \
  "Claude settings auto-import must be guarded so it only runs once"
assert_match 'mergeImportedKeys' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should merge newly added Claude settings keys into existing QuotaRadar metadata"
assert_no_match 'hasAnySecret' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor must not skip Claude settings import just because old secrets already exist"
python3 - <<'PY'
from pathlib import Path
import re
import sys

source = Path("QuotaRadar/Models/QuotaMonitor.swift").read_text()
ensure_match = re.search(r"private func ensureSecretsLoaded\(\) \{(?P<body>.*?)\n    \}", source, re.S)
if not ensure_match:
    print("FAIL: QuotaMonitor.ensureSecretsLoaded should exist", file=sys.stderr)
    sys.exit(1)
if "ClaudeSettingsImporter" in ensure_match.group("body"):
    print("FAIL: Refresh-time secret hydration must not re-import ~/.claude/settings.json and overwrite reauthenticated cookies", file=sys.stderr)
    sys.exit(1)

load_match = re.search(r"private func loadKeys\(\) \{(?P<body>.*?)\n    \}", source, re.S)
if not load_match:
    print("FAIL: QuotaMonitor.loadKeys should exist", file=sys.stderr)
    sys.exit(1)
load_body = load_match.group("body")
if load_body.count("ClaudeSettingsImporter.parseDefaultSettings()") != 1:
    print("FAIL: Claude settings should be auto-imported only once during initial key loading", file=sys.stderr)
    sys.exit(1)
guard_index = load_body.find("if !store.didAttemptClaudeSettingsImport")
import_index = load_body.find("ClaudeSettingsImporter.parseDefaultSettings()")
if guard_index == -1 or import_index == -1 or import_index < guard_index:
    print("FAIL: Claude settings auto-import must be inside the first-run import guard", file=sys.stderr)
    sys.exit(1)
PY
assert_match 'func loadSecrets' \
  "QuotaRadar/Services/APIKeyStore.swift" \
  "Secrets must be loaded separately from metadata"
assert_no_match 'KeychainStore' \
  "QuotaRadar/Services/APIKeyStore.swift" \
  "APIKeyStore must not use the login Keychain because ad-hoc rebuilds trigger repeated macOS password prompts"
assert_no_match 'SecItem' \
  "QuotaRadar" \
  "QuotaRadar must not call login Keychain SecItem APIs"
assert_match 'Application Support/QuotaRadar' \
  "QuotaRadar/Services/FileSecretStore.swift" \
  "Secrets should be stored in QuotaRadar Application Support instead of the login Keychain"
assert_match 'Application Support/QuotaBar' \
  "QuotaRadar/Services/FileSecretStore.swift" \
  "Secrets should migrate from the old QuotaBar Application Support directory"
assert_match 'legacyDefaultFileURL' \
  "QuotaRadar/Services/FileSecretStore.swift" \
  "FileSecretStore should preserve old QuotaBar secrets during the Quota Radar rename"
assert_match 'com\.gaorongvc\.quotabar' \
  "QuotaRadar/Services/LegacyConfigurationMigrator.swift" \
  "Quota Radar should migrate legacy QuotaBar UserDefaults metadata after bundle id changes"
assert_match 'posixPermissions' \
  "QuotaRadar/Services/FileSecretStore.swift" \
  "Secret storage file must set restrictive filesystem permissions"
assert_match 'https://api.tavily.com/usage' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Tavily quota must use the official usage endpoint"
assert_match 'nextMonthStartLocal' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Tavily free monthly credits should reset on the first day of the next local month"
assert_match 'X-Subscription-Token' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Brave quota checks must use X-Subscription-Token authentication"
assert_no_match 'No monthly quota (remaining|configured)' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Brave keys that return HTTP 200 with a zero monthly header should not be labeled as unusable quota"
assert_match 'https://google.serper.dev/account' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Serper quota must use the non-search account endpoint"
assert_match 'parseSerperAccount' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Serper account responses should be parsed as credit balance"
assert_match 'X-API-KEY' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Serper account checks must authenticate with X-API-KEY"
assert_no_match 'api.exa.ai/(usage|account|user)' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Exa must not use removed/nonexistent plain search-key account endpoints"
assert_match 'https://admin-api\.exa\.ai/team-management/api-keys' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Exa quota should use the official Team Management usage endpoint"
assert_match 'request\.setValue\(credential\.serviceKey, forHTTPHeaderField: "x-api-key"\)' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Exa quota checks should authenticate with the Admin API service key"
assert_match 'parseExaUsage' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Exa usage responses should be parsed from Team Management billing data"
assert_match 'Exa Admin API requires a service key' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Exa search API keys should explain that usage requires the Admin API service key"
assert_match 'key\.remaining = nil' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Unsupported quota refreshes must clear stale remaining values"
assert_match 'key\.limit = nil' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Unsupported quota refreshes must clear stale quota limits"
assert_match 'key\.lastUpdated = Date\(\)' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Unsupported quota refreshes should still mark when the provider state was checked"
assert_no_match 'api.anysearch.ai' \
  "QuotaRadar/Services/QuotaService.swift" \
  "AnySearch must not use the obsolete .ai endpoint"
assert_match 'Unlimited free usage' \
  "QuotaRadar/Services/QuotaService.swift" \
  "AnySearch should be represented as free unlimited usage instead of quota unavailable"
assert_match 'case \.anysearch:' \
  "QuotaRadar/Services/QuotaService.swift" \
  "AnySearch must have explicit quota handling"
assert_match 'https://www.dajiala.com/fbmain/monitor/v3/get_remain_money' \
  "QuotaRadar/Services/QuotaService.swift" \
  "WeChat search quota must use the Dajiala remaining-money endpoint"
assert_match 'application/x-www-form-urlencoded' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Dajiala remaining-money checks must submit form-encoded API keys"
assert_match 'https://api.bochaai.com/v1/fund/remaining' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Bocha quota should use the official remaining-fund endpoint"
assert_match 'parseBochaRemainingFund' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Bocha remaining-fund responses should be parsed as account balance"
assert_match 'https://maas.xfyun.cn/api/v1/gpt-finetune/coding-plan/list' \
  "QuotaRadar/Services/QuotaService.swift" \
  "XFYun Coding Plan should use the dashboard coding-plan list endpoint"
assert_match 'https://console.volcengine.com/api/top/ark/cn-beijing/2024-01-01/GetCodingPlanUsage' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Volcengine Coding Plan should use the console GetCodingPlanUsage endpoint"
assert_match 'https://opencode.ai/_server' \
  "QuotaRadar/Services/QuotaService.swift" \
  "OpenCode Go should use the dashboard server function endpoint"
assert_match 'Chrome/148\.0\.0\.0 Safari/537\.36' \
  "QuotaRadar/Services/QuotaService.swift" \
  "OpenCode Go usage checks should send browser-like headers so opencode.ai does not reject URLSession defaults"
assert_match 'sec-fetch-site' \
  "QuotaRadar/Services/QuotaService.swift" \
  "OpenCode Go usage checks should include browser fetch metadata headers"
assert_match 'parseXFYunCodingPlanList' \
  "QuotaRadar/Services/QuotaService.swift" \
  "XFYun Coding Plan responses should be parsed as coding quota windows"
assert_match 'parseVolcengineCodingPlanUsage' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Volcengine Coding Plan responses should be parsed as coding quota windows"
assert_match 'parseOpenCodeGoUsage' \
  "QuotaRadar/Services/QuotaService.swift" \
  "OpenCode Go dashboard responses should be parsed as coding quota windows"
assert_match 'private func withHTTPStatus' \
  "QuotaRadar/Services/QuotaService.swift" \
  "QuotaService should centralize successful HTTP status propagation for Diagnostics"
assert_no_match 'return try QuotaParsers\.parse(TavilyUsage|SerpApiAccount|SerperAccount|BochaRemainingFund|DajialaRemainMoney|DeepSeekBalance|XFYunCodingPlanList|VolcengineCodingPlanUsage|OpenCodeGoUsage)\(data\)' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Successful quota endpoints must attach HTTP status before returning so Diagnostics does not show Not requested"
assert_match 'https://www.querit.ai/en/dashboard/usage' \
  "QuotaRadar/Models/APIKey.swift" \
  "Querit must link to the official usage dashboard when API quota is not exposed"
assert_no_match 'magnifyingglass.circle' \
  "QuotaRadar/AppDelegate.swift" \
  "The status bar icon must not use the indistinct magnifying glass symbol"
assert_no_match 'heights: \[CGFloat\] = \[5, 9, 12\]' \
  "QuotaRadar/AppDelegate.swift" \
  "The status bar icon must not use the old indistinct three-bar glyph"
assert_no_match 'dotRect' \
  "QuotaRadar/AppDelegate.swift" \
  "The status bar icon must not use the old bar-plus-dot glyph"
assert_match 'drawQuotaCellStatusGlyph' \
  "QuotaRadar/AppDelegate.swift" \
  "The status bar icon should use a compact quota-cell glyph"
assert_match 'drawStatusBatteryFill' \
  "QuotaRadar/AppDelegate.swift" \
  "The status bar quota-cell glyph should use a single clear battery fill"
assert_match 'drawStatusBatteryTerminal' \
  "QuotaRadar/AppDelegate.swift" \
  "The status bar quota icon should draw a distinct battery terminal at menu-bar size"
assert_match 'makeStatusBarIcon' \
  "QuotaRadar/AppDelegate.swift" \
  "The status bar icon should be a purpose-built quota icon"
assert_no_match 'heights = \[0\.18, 0\.31, 0\.44\]' \
  "scripts/generate_app_icon.swift" \
  "The Dock app icon must not use the old three-bar chart glyph"
assert_match 'drawQuotaCell' \
  "scripts/generate_app_icon.swift" \
  "The Dock app icon generator should use the approved quota-cell battery metaphor"
assert_match 'drawQuotaCellFill' \
  "scripts/generate_app_icon.swift" \
  "The Dock app icon should make the battery fill clear at small sizes"
assert_match 'drawMonitorTileBackground' \
  "scripts/generate_app_icon.swift" \
  "The Dock app icon should use a crisp monitor-style tile background instead of a blurry glass treatment"
assert_no_match 'drawQuotaGauge|drawQuotaNeedle' \
  "scripts/generate_app_icon.swift" \
  "The Dock app icon should not keep the old gauge/needle metaphor"
assert_no_match 'dotColors|drawProviderDots|keyRingCenter' \
  "scripts/generate_app_icon.swift" \
  "The Dock app icon should not keep small dot or key decorations"
assert_no_match 'let chip = NSRect' \
  "scripts/generate_app_icon.swift" \
  "The Dock app icon should not keep the old bottom chip decoration"
assert_match 'com.apple.quarantine' \
  "install.sh" \
  "Install script should clear quarantine so local builds do not repeatedly ask for open permission"
assert_match 'spctl --add' \
  "install.sh" \
  "Install script should register the installed app with local Gatekeeper when possible"
assert_match '--rebuild' \
  "install.sh" \
  "Install script should support explicit rebuilds instead of rebuilding every install"
assert_match 'Using existing app bundle' \
  "install.sh" \
  "Install script should reuse build/Quota Radar.app by default to preserve local approvals"
assert_match 'DISPLAY_NAME="Quota Radar"' \
  "install.sh" \
  "Install script should create a Finder-visible Quota Radar.app bundle"
assert_match 'PRODUCT_NAME="QuotaRadar"' \
  "install.sh" \
  "Install script should keep a no-space executable and package product name"
assert_match '/Applications/QuotaBar\.app' \
  "install.sh" \
  "Install script should remove the old QuotaBar.app during the rename"
test -f "QuotaRadar/Resources/QuotaRadar.icns" || fail "QuotaRadar.icns must exist for Finder/Application icon"
test -x "scripts/package_dmg.sh" || fail "scripts/package_dmg.sh must exist and be executable"
assert_match 'hdiutil create' \
  "scripts/package_dmg.sh" \
  "DMG packaging should create a disk image with hdiutil"
assert_match 'xcrun notarytool submit' \
  "scripts/package_dmg.sh" \
  "DMG packaging should support Apple notarization to avoid Gatekeeper damaged-app warnings for distribution"
assert_match 'xcrun stapler staple' \
  "scripts/package_dmg.sh" \
  "DMG packaging should staple successful notarization tickets"
assert_match 'DEVELOPER_ID_APPLICATION' \
  "scripts/package_dmg.sh" \
  "DMG packaging should support Developer ID Application signing"
assert_match 'xattr -dr com\.apple\.quarantine' \
  "scripts/package_dmg.sh" \
  "Local unsigned packaging should clear quarantine attributes for the generated app bundle"
plutil -lint "QuotaRadar/QuotaRadar.entitlements" >/dev/null || fail "entitlements plist must be valid"

echo "== Provider icon assets =="
python3 - <<'PY'
from pathlib import Path
from PIL import Image
import sys

expected = {
    "anysearch", "bocha", "brave", "deepseek", "exa",
    "querit", "serpapi", "serper", "tavily", "wxmp",
}
legacy_placeholder_colors = {
    "anysearch": (156, 39, 176),
    "bocha": (0, 188, 212),
    "brave": (255, 127, 0),
    "deepseek": (77, 107, 250),
    "exa": (255, 105, 180),
    "querit": (63, 81, 181),
    "serpapi": (52, 168, 83),
    "serper": (3, 169, 244),
    "tavily": (66, 133, 244),
    "wxmp": (7, 193, 96),
}

root = Path("QuotaRadar/Assets.xcassets/ProviderIcons")
missing = sorted(
    name for name in expected
    if not (root / f"{name}.iconset" / "icon_32x32@2x.png").exists()
)
if missing:
    print(f"FAIL: missing provider icon assets: {missing}", file=sys.stderr)
    sys.exit(1)

for name in sorted(expected):
    path = root / f"{name}.iconset" / "icon_32x32@2x.png"
    image = Image.open(path).convert("RGBA")
    opaque_pixels = [pixel for pixel in image.getdata() if pixel[3] > 16]
    if not opaque_pixels:
        print(f"FAIL: {name} provider icon has no visible pixels", file=sys.stderr)
        sys.exit(1)
    rgb_values = {pixel[:3] for pixel in opaque_pixels}
    if rgb_values == {legacy_placeholder_colors[name]}:
        print(f"FAIL: {name} provider icon still uses the legacy one-color placeholder", file=sys.stderr)
        sys.exit(1)
PY

echo "== EnvImporter behavior =="
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
cat >"$TMP_DIR/main.swift" <<'SWIFT'
import Foundation

AppLanguageStore.shared.language = .english

let env = """
# comment
TAVILY_API_KEY=tvly-test-key
DEEPSEEK_WEB_SEARCH_PRO_API_KEY=should-not-import
DEEPSEEK_API_KEY='deepseek-test-key'
XFYUN_CODING_PLAN_COOKIE='fake-xfyun-cookie-value'
VOLCENGINE_CODING_PLAN_COOKIE='fake-volcengine-cookie-value'
OPENCODE_GO_COOKIE='auth=opencode-auth; oc_locale=zh'
EMPTY_KEY=xxx
QUOTED_BRAVE_KEY="brave-key"
SERPER_API_KEY=serper-key
WECHAT_API_KEY=wechat-key
QUERIT_API_KEY=querit-api-key
QUERIT_COOKIE='fake-querit-cookie-value'
ANTHROPIC_AUTH_TOKEN=token-not-api-key
ANTHROPIC_API_KEY=anthropic-key
"""

AppLanguageStore.shared.language = .english
let keys = EnvImporter.parseEnvContent(env)

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(1)
    }
}

require(keys.count == 9, "expected exactly nine supported imported keys")
require(keys.contains { $0.name == "TAVILY_API_KEY" && $0.provider == .tavily && $0.key == "tvly-test-key" }, "missing Tavily key")
require(keys.contains { $0.name == "DEEPSEEK_API_KEY" && $0.provider == .deepseek && $0.key == "deepseek-test-key" }, "missing DeepSeek key")
require(keys.contains { $0.name == "XFYUN_CODING_PLAN_COOKIE" && $0.provider == .xfyunCodingPlan }, "missing XFYun Coding Plan cookie")
require(keys.contains { $0.name == "VOLCENGINE_CODING_PLAN_COOKIE" && $0.provider == .volcengineCodingPlan }, "missing Volcengine Coding Plan cookie")
require(keys.contains { $0.name == "OPENCODE_GO_COOKIE" && $0.provider == .opencodeGo }, "missing OpenCode Go cookie")
require(keys.contains { $0.name == "QUOTED_BRAVE_KEY" && $0.provider == .brave && $0.key == "brave-key" }, "missing quoted Brave key")
require(keys.contains { $0.name == "SERPER_API_KEY" && $0.provider == .serper && $0.key == "serper-key" }, "missing Serper key")
require(keys.contains { $0.name == "WECHAT_API_KEY" && $0.provider == .wxmp && $0.key == "wechat-key" }, "missing WeChat key")
require(keys.contains { $0.name == "QUERIT_COOKIE" && $0.provider == .querit && $0.key == "fake-querit-cookie-value" }, "missing Querit dashboard cookie")
require(!keys.contains { $0.name == "QUERIT_API_KEY" }, "Querit API keys must not be imported as dashboard cookies")
require(!keys.contains { $0.name == "DEEPSEEK_WEB_SEARCH_PRO_API_KEY" }, "web-search-pro DeepSeek key must be ignored")
require(!keys.contains { $0.name == "ANTHROPIC_AUTH_TOKEN" }, "Anthropic auth token must not be imported as an API key")
require(!keys.contains { $0.name == "ANTHROPIC_API_KEY" }, "Anthropic API key should not be imported while Anthropic is not in the supported provider list")
require(!Provider.visibleCases.contains(.anthropic), "Anthropic should not appear in provider pickers or visible app sections for now")

let masked = APIKey(name: "TAVILY_API_KEY", key: "abcd1234wxyz", provider: .tavily).maskedKey
require(masked == "abcd••••wxyz", "APIKey.maskedKey should expose the first four and last four characters")
let emptyMasked = APIKey(name: "EMPTY", key: "", provider: .tavily).maskedKey
require(emptyMasked == "No key value", "APIKey.maskedKey should label missing secrets")
require(Provider.brave.quotaCheckConsumesSearchQuota, "Brave quota checks use real search requests and must not run in automatic polling")
require(!Provider.tavily.quotaCheckConsumesSearchQuota, "Tavily usage endpoint should be safe for automatic polling")
require(Provider.xfyunCodingPlan.category == "LLM", "XFYun Coding Plan should be grouped as an LLM quota provider")
require(Provider.volcengineCodingPlan.category == "LLM", "Volcengine Coding Plan should be grouped as an LLM quota provider")
require(Provider.opencodeGo.category == "LLM", "OpenCode Go should be grouped as an LLM quota provider")
require(Provider.xfyunCodingPlan.supportsQuotaQuery, "XFYun Coding Plan should support dashboard quota checks")
require(Provider.volcengineCodingPlan.supportsQuotaQuery, "Volcengine Coding Plan should support dashboard quota checks")
require(Provider.opencodeGo.supportsQuotaQuery, "OpenCode Go should support dashboard quota checks")
require(Provider.querit.supportsQuotaQuery, "Querit should support dashboard-cookie quota checks through the user account endpoint")
require(Provider.exa.supportsQuotaQuery, "Exa should support usage checks when an Admin API service key and API key id are configured")
require(Provider.exa.localizedUnsupportedQuotaLabel(language: .simplifiedChinese) == "需要管理员凭据", "Exa plain search keys should explain that Admin credentials are required with a fully localized Chinese status label")
require(Provider.exa.localizedUnsupportedQuotaLabel(language: .traditionalChinese) == "需要管理員憑證", "Exa plain search keys should explain that Admin credentials are required with a fully localized Traditional Chinese status label")
require(Provider.exa.localizedUnsupportedQuotaLabel(language: .japanese) == "管理者認証情報が必要", "Exa plain search keys should explain that Admin credentials are required with a fully localized Japanese status label")
require(Provider.exa.localizedUnsupportedQuotaLabel(language: .korean) == "관리자 자격 증명 필요", "Exa plain search keys should explain that Admin credentials are required with a fully localized Korean status label")
require(Provider.deepseek.homeVisibleWithoutKeys, "DeepSeek should appear on the home view before a key is configured")
require(Provider.xfyunCodingPlan.homeVisibleWithoutKeys, "XFYun Coding Plan should appear on the home view before a key is configured")
require(Provider.volcengineCodingPlan.homeVisibleWithoutKeys, "Volcengine Coding Plan should appear on the home view before a key is configured")
require(Provider.opencodeGo.homeVisibleWithoutKeys, "OpenCode Go should appear on the home view before a key is configured")
require(!Provider.anthropic.homeVisibleWithoutKeys, "Anthropic should stay off the home view unless explicitly configured")
let categoryStats = ProviderCategoryStats(title: "LLM", stats: [
    ProviderStats(provider: .deepseek, keys: [APIKey(name: "DEEPSEEK_API_KEY", key: "deepseek", provider: .deepseek, remaining: 1200, limit: 1200)]),
    ProviderStats(provider: .xfyunCodingPlan, keys: [APIKey(name: "XFYUN_CODING_PLAN_COOKIE", key: "cookie", provider: .xfyunCodingPlan, remaining: 7934, limit: 10000)]),
])
require(categoryStats.keyCount == 2, "Status bar category stats should count keys across providers")
require(categoryStats.providerCount == 2, "Status bar category stats should count providers")
let exhaustedBadge = APIKey(name: "BRAVE_API_KEY_3", key: "brave", provider: .brave, remaining: 0, limit: 1000).remainingBadgeText
require(exhaustedBadge == "0 left", "Remaining badge should make exhausted Brave keys clear instead of showing ambiguous 0%")
AppLanguageStore.shared.language = .simplifiedChinese
let localizedExhaustedBadge = APIKey(name: "BRAVE_API_KEY_3", key: "brave", provider: .brave, remaining: 0, limit: 1000).remainingBadgeText
require(localizedExhaustedBadge == "剩余 0", "Remaining badge should localize 0 left in Simplified Chinese")
AppLanguageStore.shared.language = .english
let tinyBadge = APIKey(name: "BRAVE_API_KEY_4", key: "brave", provider: .brave, remaining: 1, limit: 1000).remainingBadgeText
require(tinyBadge == "<1%", "Remaining badge should not round tiny nonzero quotas down to 0%")
let fullBadge = APIKey(name: "BRAVE_API_KEY_5", key: "brave", provider: .brave, remaining: 1000, limit: 1000).remainingBadgeText
require(fullBadge == "100%", "Remaining badge should show full quota as 100%")
let unlimitedAnySearch = APIKey(
    name: "ANYSEARCH_API_KEY",
    key: "anysearch",
    provider: .anysearch,
    remaining: Int.max,
    limit: Int.max,
    quotaLabel: "Unlimited free usage"
)
require(unlimitedAnySearch.isUnlimitedQuota, "AnySearch should recognize persisted Int.max quotas as unlimited")
require(unlimitedAnySearch.remainingBadgeText == "∞", "AnySearch should show an unlimited badge instead of a fake percentage")
require(unlimitedAnySearch.quotaDisplayText == "Unlimited", "AnySearch rows should not display the Int.max sentinel value")
let anySearchStat = ProviderStats(provider: .anysearch, keys: [unlimitedAnySearch])
require(anySearchStat.totalLimitDisplayText == "Unlimited", "AnySearch provider totals should not display the Int.max sentinel value")
require(anySearchStat.totalRemainingDisplayText == "Unlimited", "AnySearch provider remaining totals should not display the Int.max sentinel value")
require(anySearchStat.statusBarProviderQuotaText == "Unlimited", "Status bar provider quota text should show AnySearch as unlimited")
require(anySearchStat.statusBarProviderBadgeText == "∞", "Status bar provider badge should show AnySearch as unlimited")
let tavilyProviderOverview = ProviderStats(provider: .tavily, keys: [
    APIKey(name: "TAVILY_API_KEY", key: "tvly-1", provider: .tavily, remaining: 750, limit: 1000),
    APIKey(name: "TAVILY_API_KEY_2", key: "tvly-2", provider: .tavily, remaining: 250, limit: 1000),
])
require(tavilyProviderOverview.statusBarProviderQuotaText == "1000 / 2000", "Status bar provider quota text should aggregate known provider quota numerically")
require(tavilyProviderOverview.statusBarProviderBadgeText == "50%", "Status bar provider badge should aggregate known provider quota percentage")
let unconfiguredProviderOverview = ProviderStats(provider: .deepseek, keys: [])
require(unconfiguredProviderOverview.statusBarProviderQuotaText == "No key configured", "Status bar provider quota text should mark unconfigured provider placeholders")
require(unconfiguredProviderOverview.statusBarProviderBadgeText == "N/A", "Status bar provider badge should mark unconfigured provider placeholders")
let xfyunStat = ProviderStats(
    provider: .xfyunCodingPlan,
    keys: [
        APIKey(
            name: "XFYUN_CODING_PLAN_COOKIE",
            key: "cookie",
            provider: .xfyunCodingPlan,
            remaining: 7934,
            limit: 10000,
            quotaLabel: "5h 99% · week 79.3% · month 89.7%"
        )
    ]
)
require(xfyunStat.totalLimitDisplayText == "month 89.7%", "Coding Plan provider total should display the monthly percentage window")
require(xfyunStat.totalRemainingDisplayText == "week 79.3%", "Coding Plan provider remaining should display the lowest remaining percentage window with its period")
require(xfyunStat.statusBarProviderQuotaText == "week 79.3%", "Status bar coding-plan quota text should display the tightest quota cycle")
require(xfyunStat.statusBarProviderBadgeText == "month 89.7%", "Status bar coding-plan badge should display the monthly quota cycle")
let multiXfyunStat = ProviderStats(
    provider: .xfyunCodingPlan,
    keys: [
        APIKey(
            name: "XFYUN_CODING_PLAN_COOKIE",
            key: "cookie-a",
            provider: .xfyunCodingPlan,
            remaining: 6440,
            limit: 10000,
            quotaLabel: "5h 100% · week 64.4% · month 91%"
        ),
        APIKey(
            name: "XFYUN_CODING_PLAN_COOKIE_2",
            key: "cookie-b",
            provider: .xfyunCodingPlan,
            remaining: 8400,
            limit: 10000,
            quotaLabel: "5h 88% · week 70% · month 84%"
        )
    ]
)
require(multiXfyunStat.totalLimitDisplayText == "month 84%", "Coding Plan provider monthly total should use the lowest monthly percentage across credentials")
require(multiXfyunStat.totalRemainingDisplayText == "week 64.4%", "Coding Plan provider remaining should use the tightest quota cycle across credentials")
require(multiXfyunStat.statusBarProviderQuotaText == "week 64.4%", "Status bar coding-plan quota text should use the tightest quota cycle across credentials")
require(multiXfyunStat.statusBarProviderBadgeText == "month 84%", "Status bar coding-plan badge should use the lowest monthly quota cycle across credentials")
AppLanguageStore.shared.language = .simplifiedChinese
require(xfyunStat.totalLimitDisplayText == "月 89.7%", "Coding Plan provider total should localize the monthly period label in Simplified Chinese")
require(xfyunStat.totalRemainingDisplayText == "周 79.3%", "Coding Plan provider remaining should localize the lowest remaining period label in Simplified Chinese")
let localizedTavilyCredits = APIKey(name: "TAVILY_API_KEY", key: "tvly", provider: .tavily, remaining: 850, limit: 1000, quotaLabel: "850 / 1000 monthly credits")
require(localizedTavilyCredits.quotaDisplayText == "850 / 1000 月度积分", "Tavily monthly credits should be localized in Simplified Chinese")
let localizedBraveRequests = APIKey(name: "BRAVE_API_KEY", key: "brave", provider: .brave, remaining: 999, limit: 1000, quotaLabel: "999 / 1000 monthly requests")
require(localizedBraveRequests.quotaDisplayText == "999 / 1000 月度请求", "Brave monthly requests should be localized in Simplified Chinese")
let localizedSerpSearches = APIKey(name: "SERPAPI_API_KEY", key: "serp", provider: .serpapi, remaining: 5, limit: 255, quotaLabel: "5 searches left")
require(localizedSerpSearches.quotaDisplayText == "剩余 5 次搜索", "SerpAPI searches-left labels should be localized in Simplified Chinese")
let localizedSerperCredits = APIKey(name: "SERPER_API_KEY", key: "serper", provider: .serper, remaining: 24, limit: 24, quotaLabel: "24 credits left")
require(localizedSerperCredits.quotaDisplayText == "剩余 24 积分", "Serper credits-left labels should be localized in Simplified Chinese")
let localizedSerperExhausted = APIKey(name: "SERPER_API_KEY", key: "serper", provider: .serper, remaining: 0, limit: 0, quotaLabel: "No Serper credits available")
require(localizedSerperExhausted.quotaDisplayText == "没有可用的 Serper 积分", "Serper exhausted credit labels should be localized in Simplified Chinese")
let localizedDeepSeekMoney = APIKey(name: "DEEPSEEK_API_KEY", key: "deepseek", provider: .deepseek, remaining: 1250, limit: 1250, quotaLabel: "CNY 12.50 available")
require(localizedDeepSeekMoney.quotaDisplayText == "可用人民币 12.50 元", "DeepSeek money balance labels should be localized as RMB, not credits")
require(localizedDeepSeekMoney.remainingBadgeText == "¥12.50", "DeepSeek money balance badge should show currency amount, not 100%")
let localizedBochaBalance = APIKey(name: "BOCHA_API_KEY", key: "bocha", provider: .bocha, remaining: 1400, limit: 1400, quotaLabel: "CNY 14.00 balance")
require(localizedBochaBalance.quotaDisplayText == "余额人民币 14.00 元", "Bocha money balance labels should be localized as RMB, not credits")
require(localizedBochaBalance.remainingBadgeText == "¥14.00", "Bocha money balance badge should show currency amount, not 100%")
let localizedWeChatMoney = APIKey(name: "WECHAT_API_KEY", key: "wechat", provider: .wxmp, remaining: 16180, limit: 16180, quotaLabel: "CNY 161.80 available")
require(localizedWeChatMoney.quotaDisplayText == "可用人民币 161.80 元", "WeChat Search money balance labels should be localized as RMB, not credits")
require(localizedWeChatMoney.remainingBadgeText == "¥161.80", "WeChat Search money balance badge should show currency amount, not 100%")
let moneyStats = ProviderStats(provider: .bocha, keys: [localizedBochaBalance])
require(moneyStats.totalRemainingDisplayText == "¥14.00", "Money-balance provider overview should show RMB amount instead of cents")
require(moneyStats.statusBarProviderBadgeText == "¥14.00", "Money-balance status bar badge should show RMB amount instead of percentage")
let localizedExaUsage = APIKey(name: "EXA_ADMIN", key: "exa", provider: .exa, remaining: Int.max, limit: Int.max, quotaLabel: "USD 45.67 used")
require(localizedExaUsage.quotaDisplayText == "已用 USD 45.67", "Exa usage cost labels should be localized in Simplified Chinese")
require(localizedExaUsage.remainingBadgeText == "正常", "Exa usage-only checks should show a localized OK badge instead of a fake percentage")
let localizedQuotaKey = APIKey(
    name: "XFYUN_CODING_PLAN_COOKIE",
    key: "cookie",
    provider: .xfyunCodingPlan,
    remaining: 7934,
    limit: 10000,
    quotaLabel: "5h 99% · week 79.3% · month 89.7%"
)
require(localizedQuotaKey.quotaDisplayText == "5 小时 99% · 周 79.3% · 月 89.7%", "Coding Plan key rows should localize five-hour, weekly, and monthly quota windows")
let localizedResetDate = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 6, day: 28, hour: 17, minute: 48, second: 58))!
let localizedResetKey = APIKey(
    name: "XFYUN_CODING_PLAN_COOKIE",
    key: "cookie",
    provider: .xfyunCodingPlan,
    resetAt: localizedResetDate
)
require(localizedResetKey.resetSummary.contains("月"), "Reset dates should be localized in Simplified Chinese instead of fixed English month names")
require(!localizedResetKey.resetSummary.contains("Jun"), "Reset dates should not leak English month names in Simplified Chinese")
AppLanguageStore.shared.language = .english
let volcengineStat = ProviderStats(
    provider: .volcengineCodingPlan,
    keys: [
        APIKey(
            name: "VOLCENGINE_CODING_PLAN_COOKIE",
            key: "cookie",
            provider: .volcengineCodingPlan,
            remaining: 8918,
            limit: 10000,
            quotaLabel: "5h 100% · week 89.2% · month 94.6%"
        )
    ]
)
require(volcengineStat.totalLimitDisplayText == "month 94.6%", "Volcengine provider total should display the monthly percentage window")
require(volcengineStat.totalRemainingDisplayText == "week 89.2%", "Volcengine provider remaining should display the lowest remaining percentage window with its period")
let opencodeStat = ProviderStats(
    provider: .opencodeGo,
    keys: [
        APIKey(
            name: "OPENCODE_GO_COOKIE",
            key: "cookie",
            provider: .opencodeGo,
            remaining: 2500,
            limit: 10000,
            quotaLabel: "5h 98% · week 50% · month 25%"
        )
    ]
)
require(opencodeStat.totalLimitDisplayText == "month 25%", "OpenCode Go provider total should display the monthly percentage window")
require(opencodeStat.totalRemainingDisplayText == "month 25%", "OpenCode Go provider remaining should display the lowest remaining percentage window with its period")
let exposedUnknownKey = APIKey(
    name: "BRAVE_API_KEY_6",
    key: "brave",
    provider: .brave,
    remaining: Int.max,
    limit: Int.max,
    lastHTTPStatus: 200,
    lastDiagnosticMessage: "Search works, but monthly quota is hidden by Brave.",
    quotaLabel: "Search OK · monthly quota not exposed"
)
require(exposedUnknownKey.remainingBadgeText == "OK", "Brave keys with working search but hidden monthly quota should show OK instead of a fake percentage")
require(exposedUnknownKey.isUsableWithUnknownQuota, "Brave HTTP 200 keys with hidden monthly quota should be marked usable with unknown quota")
require(exposedUnknownKey.status == .usableUnknown, "Brave HTTP 200 keys with hidden monthly quota should use the usable-unknown health state")
require(exposedUnknownKey.healthDisplayText == "Usable · quota unknown", "English health text should explain usable unknown-quota Brave keys")
let usageLimitedBrave = APIKey(
    name: "BRAVE_API_KEY_7",
    key: "brave",
    provider: .brave,
    remaining: Int.max,
    limit: Int.max,
    lastHTTPStatus: 402,
    lastDiagnosticMessage: "Brave returned HTTP 402 usage limit exceeded.",
    quotaLabel: "Usage limit exceeded"
)
require(usageLimitedBrave.isUsageLimitExceeded, "Brave HTTP 402 usage-limit responses should be marked as usage limit exceeded")
require(usageLimitedBrave.isExhausted, "Brave usage-limit responses should be treated as exhausted")
require(usageLimitedBrave.status == .exhausted, "Brave usage-limit responses should use the exhausted health state")
require(usageLimitedBrave.remainingBadgeText == "0 left", "Brave usage-limit responses should show 0 left instead of OK")
require(usageLimitedBrave.healthDisplayText == "Usage limit exceeded", "English health text should explain Brave usage-limit exhaustion")
var disabledKey = APIKey(name: "BRAVE_DISABLED", key: "brave", provider: .brave, remaining: 1000, limit: 1000)
disabledKey.isActive = false
require(disabledKey.remainingBadgeText == "Off", "Remaining badge should show inactive keys as Off")
let sortedStat = ProviderStats(
    provider: .brave,
    keys: [
        APIKey(name: "unknown", key: "brave", provider: .brave),
        APIKey(name: "low", key: "brave", provider: .brave, remaining: 20, limit: 1000),
        APIKey(name: "high", key: "brave", provider: .brave, remaining: 900, limit: 1000),
        APIKey(name: "empty", key: "brave", provider: .brave, remaining: 0, limit: 1000),
        APIKey(name: "usableUnknown", key: "brave", provider: .brave, remaining: Int.max, limit: Int.max, lastHTTPStatus: 200, quotaLabel: "Search OK · monthly quota not exposed"),
        APIKey(name: "usageLimited", key: "brave", provider: .brave, remaining: Int.max, limit: Int.max, lastHTTPStatus: 402, quotaLabel: "Usage limit exceeded"),
    ]
)
require(
    sortedStat.sortedKeysByCurrentQuota.map { $0.name } == ["high", "low", "usableUnknown", "empty", "usageLimited", "unknown"],
    "ProviderStats.sortedKeysByCurrentQuota should sort known quotas first, keep usable-unknown before exhausted keys, and keep unchecked unknown last"
)
let numericPresentation = APIKey(
    name: "TAVILY_API_KEY",
    key: "tvly-test-key",
    provider: .tavily,
    remaining: 750,
    limit: 1000,
    resetAt: localizedResetDate,
    lastUpdated: localizedResetDate,
    quotaLabel: "750 / 1000 monthly credits"
).quotaPresentation
require(numericPresentation.primaryText == "750 / 1000 monthly credits", "QuotaPresentation should preserve the numeric quota as the primary text")
require(numericPresentation.badgeText == "75%", "QuotaPresentation should expose the numeric remaining badge")
require(numericPresentation.percentRemaining == 0.75, "QuotaPresentation should expose normalized remaining percentage")
require(numericPresentation.dataSource == .officialAPI, "Tavily presentation should identify official API data")
let braveUnknownPresentation = exposedUnknownKey.quotaPresentation
require(braveUnknownPresentation.primaryText == "Search OK · monthly quota not exposed", "Usable unknown quota should still explain the numeric gap")
require(braveUnknownPresentation.percentRemaining == nil, "Unknown quota should not invent a fake remaining percentage")
require(braveUnknownPresentation.dataSource == .responseHeader, "Brave hidden quota should identify response-header probing")
let rankedMenuItems = MenuQuotaItem.topItems(from: [
    ProviderStats(provider: .tavily, keys: [
        APIKey(name: "TAVILY_LOW", key: "tvly-low", provider: .tavily, remaining: 100, limit: 1000),
        APIKey(name: "TAVILY_HIGH", key: "tvly-high", provider: .tavily, remaining: 900, limit: 1000),
    ]),
    sortedStat
], limit: 3)
require(
    rankedMenuItems.map { $0.key.name } == ["usageLimited", "empty", "low"],
    "MenuQuotaItem.topItems should rank exhausted and lowest numeric quotas for the compact status bar summary"
)
let menuSummary = MenuQuotaSummary(keys: [
    APIKey(name: "healthy", key: "tvly-healthy", provider: .tavily, remaining: 900, limit: 1000),
    APIKey(name: "low", key: "tvly-low", provider: .tavily, remaining: 20, limit: 1000),
    APIKey(name: "failed", key: "tvly-failed", provider: .tavily, lastDiagnosticMessage: "network failed"),
    APIKey(name: "expired", key: "cookie", provider: .volcengineCodingPlan, quotaLabel: "Credential expired")
])
require(menuSummary.availableCount == 2, "MenuQuotaSummary should count usable credentials, including low but still usable ones")
require(menuSummary.lowCount == 1, "MenuQuotaSummary should count low-quota credentials separately")
require(menuSummary.failedCount == 2, "MenuQuotaSummary should count failed and expired credentials")
let cookieStatusLabel = APIKey(
    name: "VOLCENGINE_CODING_PLAN_COOKIE",
    key: #"{"cookie":"c=a"}"#,
    provider: .volcengineCodingPlan
).statusBarCredentialLabel
require(cookieStatusLabel == "Dashboard session cookie", "Status bar should show the credential type for cookie-backed providers, not masked raw JSON")
let apiStatusLabel = APIKey(
    name: "BRAVE_API_KEY",
    key: "abcd1234wxyz",
    provider: .brave
).statusBarCredentialLabel
require(apiStatusLabel == "abcd••••wxyz", "Status bar should still show masked concrete API keys for normal providers")
let settingsURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("claude-settings.json")
try! Data("""
{"env":{"TAVILY_API_KEY":"tvly-from-settings","BRAVE_API_KEY":"brave-from-settings","ANTHROPIC_API_KEY":""}}
""".utf8).write(to: settingsURL)
let settingsKeys = ClaudeSettingsImporter.parseSettings(at: settingsURL)
require(settingsKeys.count == 2, "Claude settings importer should skip empty env values")
require(settingsKeys.contains { $0.name == "TAVILY_API_KEY" && $0.provider == .tavily }, "Claude settings importer missing Tavily")
require(settingsKeys.contains { $0.name == "BRAVE_API_KEY" && $0.provider == .brave }, "Claude settings importer missing Brave")
SWIFT

swiftc QuotaRadar/Models/AppLanguage.swift QuotaRadar/Models/APIKey.swift QuotaRadar/Services/EnvImporter.swift QuotaRadar/Services/ClaudeSettingsImporter.swift "$TMP_DIR/main.swift" -o "$TMP_DIR/env-importer-test"
"$TMP_DIR/env-importer-test"

echo "== Language behavior =="
cat >"$TMP_DIR/main.swift" <<'SWIFT'
import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(1)
    }
}

let defaults = UserDefaults(suiteName: "QuotaRadarLanguageTests.\(UUID().uuidString)")!
defaults.removePersistentDomain(forName: defaults.dictionaryRepresentation().description)
defaults.set(AppLanguage.simplifiedChinese.rawValue, forKey: AppLanguageStore.defaultsKey)
let store = AppLanguageStore(defaults: defaults)
require(store.language == .simplifiedChinese, "AppLanguageStore should load the persisted Simplified Chinese selection")
store.language = .english
require(defaults.string(forKey: AppLanguageStore.defaultsKey) == AppLanguage.english.rawValue, "AppLanguageStore should persist language changes")
require(AppLanguage.english.displayName == "English", "English language option should have a stable display name")
require(AppLanguage.simplifiedChinese.displayName == "简体中文", "Simplified Chinese language option should have a Chinese display name")
require(AppLanguage.traditionalChinese.displayName == "繁體中文", "Traditional Chinese language option should have a native display name")
require(AppLanguage.japanese.displayName == "日本語", "Japanese language option should have a native display name")
require(AppLanguage.korean.displayName == "한국어", "Korean language option should have a native display name")
require(L10n.t(.providersTab, language: .english) == "Quota Overview", "English quota overview tab title should be available")
require(L10n.t(.providersHeader, language: .english) == "Quota Overview", "English quota overview page title should match the navigation")
require(L10n.t(.apiQuotaTitle, language: .english) == "Quota Radar", "English menu bar title should express active quota monitoring instead of a bland API quota label")
require(AIQuoteLibrary.quotes.count >= 50, "Built-in AI quote library should include about 50 concise quotes")
for language in AppLanguage.allCases {
    let localizedQuotes = AIQuoteLibrary.quotes.map { $0.text(language: language) }
    require(localizedQuotes.allSatisfy { !$0.isEmpty }, "\(language.rawValue) should have non-empty built-in AI quotes")
    let maxLength = language == .english ? 40 : 18
    require(localizedQuotes.allSatisfy { $0.count <= maxLength }, "\(language.rawValue) built-in AI quotes should stay concise enough for the status header")
}
let quoteDefaults = UserDefaults(suiteName: "QuotaRadarQuoteTests.\(UUID().uuidString)")!
quoteDefaults.removePersistentDomain(forName: quoteDefaults.dictionaryRepresentation().description)
let quoteStore = AIQuoteStore(defaults: quoteDefaults)
let firstQuote = quoteStore.currentQuoteText(language: .english)
quoteStore.advance()
let secondQuote = quoteStore.currentQuoteText(language: .english)
require(firstQuote != secondQuote, "Opening the status panel should rotate to the next built-in AI quote")
require(L10n.t(.apiKeysTab, language: .english) == "Credentials", "English credentials tab title should be available")
require(L10n.t(.settingsTab, language: .english) == "Settings", "English settings tab title should be available")
require(L10n.t(.providersTab, language: .simplifiedChinese) == "额度监控", "Chinese quota monitoring tab title should be available")
require(L10n.t(.providersHeader, language: .simplifiedChinese) == "额度监控", "Chinese quota monitoring page title should match the navigation")
require(L10n.t(.apiQuotaTitle, language: .simplifiedChinese) == "余量雷达", "Chinese menu bar title should express active quota monitoring instead of a bland API quota label")
require(L10n.t(.apiKeysTab, language: .simplifiedChinese) == "配置凭据", "Chinese credentials tab title should be available")
require(L10n.t(.dashboardSession, language: .simplifiedChinese) == "控制台会话 Cookie", "Chinese dashboard-session credential label should avoid API key wording")
require(L10n.t(.settingsTab, language: .simplifiedChinese) == "设置", "Chinese settings tab title should be available")
require(L10n.t(.provider, language: .simplifiedChinese) == "服务商", "Chinese provider form label should be fully translated")
require(L10n.t(.language, language: .simplifiedChinese) == "语言", "Chinese language label should be available")
require(L10n.t(.statusBarTransparency, language: .simplifiedChinese) == "状态栏透明度", "Chinese status bar transparency label should be available")
require(L10n.t(.adminCredentialRequired, language: .simplifiedChinese) == "需要管理员凭据", "Chinese Admin credential status should be fully translated")
require(L10n.t(.autoRefreshInterval, language: .simplifiedChinese) == "自动刷新", "Chinese settings should include an automatic refresh label")
require(L10n.t(.available, language: .english) == "Available", "English menu summary should label available credentials")
require(L10n.t(.available, language: .simplifiedChinese) == "可用", "Chinese menu summary should label available credentials")
require(L10n.t(.failed, language: .english) == "Failed", "English menu summary should label failed credentials")
require(L10n.t(.failed, language: .simplifiedChinese) == "失败", "Chinese menu summary should label failed credentials")
require(L10n.t(.needsAttention, language: .english) == "Needs Attention", "English menu attention title should be available")
require(L10n.t(.needsAttention, language: .simplifiedChinese) == "需要关注", "Chinese menu attention title should be available")
require(L10n.t(.noAttentionItems, language: .simplifiedChinese) == "暂无需要关注的凭据", "Chinese no-attention empty state should be available")
require(AutoRefreshIntervalOption.off.timeInterval == nil, "Automatic refresh settings should support disabling background refresh")
require(AutoRefreshIntervalOption.fifteenMinutes.timeInterval == 900, "Automatic refresh settings should expose a 15 minute interval")
require(QuotaConsumingAutoRefreshIntervalOption.off.timeInterval == nil, "Quota-consuming automatic refresh should be disabled by default")
require(QuotaConsumingAutoRefreshIntervalOption.sixHours.timeInterval == 21_600, "Quota-consuming automatic refresh should expose a long 6 hour interval")
require(QuotaConsumingAutoRefreshIntervalOption.twelveHours.timeInterval == 43_200, "Quota-consuming automatic refresh should expose a long 12 hour interval")
require(QuotaConsumingAutoRefreshIntervalOption.oneDay.timeInterval == 86_400, "Quota-consuming automatic refresh should expose a daily interval")
for language in AppLanguage.allCases {
    require(L10n.missingTranslationKeys(language: language).isEmpty, "\(language.rawValue) should have translations for every L10n key")
    require(!L10n.t(.settingsTab, language: language).isEmpty, "\(language.rawValue) settings label should not be empty")
    require(!L10n.t(.quotaConsumingAutoRefreshWarning, language: language).isEmpty, "\(language.rawValue) quota-consuming refresh warning should not be empty")
    require(!L10n.quotaPeriodTitle("week", language: language).isEmpty, "\(language.rawValue) week period label should be localized")
}
require(L10n.t(.settingsTab, language: .traditionalChinese) == "設定", "Traditional Chinese settings label should be localized")
require(L10n.t(.apiQuotaTitle, language: .traditionalChinese) == "餘量雷達", "Traditional Chinese menu bar title should express active quota monitoring")
require(L10n.t(.settingsTab, language: .japanese) == "設定", "Japanese settings label should be localized")
require(L10n.t(.apiQuotaTitle, language: .japanese) == "クォータレーダー", "Japanese menu bar title should express active quota monitoring")
require(L10n.t(.settingsTab, language: .korean) == "설정", "Korean settings label should be localized")
require(L10n.t(.apiQuotaTitle, language: .korean) == "할당량 레이더", "Korean menu bar title should express active quota monitoring")
require(L10n.quotaPeriodTitle("5h", language: .traditionalChinese) == "5 小時", "Traditional Chinese five-hour quota period should be localized")
require(L10n.quotaPeriodTitle("week", language: .japanese) == "週", "Japanese week quota period should be localized")
require(L10n.quotaPeriodTitle("month", language: .korean) == "월", "Korean month quota period should be localized")
require(L10n.t(.httpNotRequested, language: .english) == "Not requested", "English diagnostics should distinguish skipped HTTP checks")
require(L10n.t(.httpNotRequested, language: .simplifiedChinese) == "未请求", "Chinese diagnostics should distinguish skipped HTTP checks")
require(Provider.bocha.displayName(language: .simplifiedChinese) == "博查", "Bocha should have a Simplified Chinese provider display name")
require(Provider.wxmp.displayName(language: .english) == "WeChat Search", "WeChat Search should have an English provider display name")
require(Provider.brave.displayName(language: .simplifiedChinese) == "Brave", "Brave should not repeat the generic search category in its Simplified Chinese provider display name")
require(Provider.serpapi.displayName(language: .simplifiedChinese) == "SerpAPI", "SerpAPI should not repeat the generic search category in its Simplified Chinese provider display name")
require(Provider.serper.displayName(language: .simplifiedChinese) == "Serper", "Serper should not repeat the generic search category in its Simplified Chinese provider display name")
require(Provider.exa.displayName(language: .simplifiedChinese) == "Exa", "Exa should not repeat the generic search category in its Simplified Chinese provider display name")
require(Provider.anysearch.displayName(language: .simplifiedChinese) == "AnySearch", "AnySearch should not repeat the generic search category in its Simplified Chinese provider display name")
require(Provider.deepseek.displayName(language: .simplifiedChinese) == "Deepseek", "DeepSeek should keep the brand name in its Simplified Chinese provider display name")
require(Provider.querit.displayName(language: .simplifiedChinese) == "Querit", "Querit should not repeat the generic search category in its Simplified Chinese provider display name")
SWIFT

swiftc QuotaRadar/Models/AppLanguage.swift QuotaRadar/Models/AppAppearance.swift QuotaRadar/Models/APIKey.swift QuotaRadar/Models/AIQuoteLibrary.swift "$TMP_DIR/main.swift" -o "$TMP_DIR/language-test"
"$TMP_DIR/language-test"

echo "== Dashboard reauthentication behavior =="
cat >"$TMP_DIR/main.swift" <<'SWIFT'
import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(1)
    }
}

AppLanguageStore.shared.language = .english
let opencodeCookie = HTTPCookie(properties: [
    .domain: ".opencode.ai",
    .path: "/",
    .name: "auth",
    .value: "opencode-auth",
    .secure: "TRUE"
])!
let opencodeLocale = HTTPCookie(properties: [
    .domain: "opencode.ai",
    .path: "/",
    .name: "oc_locale",
    .value: "zh"
])!
let unrelated = HTTPCookie(properties: [
    .domain: "example.com",
    .path: "/",
    .name: "auth",
    .value: "wrong"
])!

let header = DashboardCookieBuilder.cookieHeader(
    from: [unrelated, opencodeLocale, opencodeCookie],
    domains: ["opencode.ai"]
)
require(header == "auth=opencode-auth; oc_locale=zh", "DashboardCookieBuilder should filter by domain and sort cookies by name")
require(DashboardCookieBuilder.cookieHeader(from: [unrelated], domains: ["opencode.ai"]).isEmpty, "DashboardCookieBuilder should ignore unrelated cookies")
require(DashboardCookieBuilder.containsRequiredCookie(from: [opencodeLocale], domains: ["opencode.ai"], requiredNames: ["auth"]) == false, "DashboardCookieBuilder should not treat preference cookies as a logged-in session")
require(DashboardCookieBuilder.containsRequiredCookie(from: [opencodeLocale, opencodeCookie], domains: ["opencode.ai"], requiredNames: ["auth"]), "DashboardCookieBuilder should detect provider authentication cookies")

let volcengineAccountID = HTTPCookie(properties: [
    .domain: ".volcengine.com",
    .path: "/",
    .name: "AccountID",
    .value: "2120638754",
    .secure: "TRUE"
])!
let volcengineCSRF = HTTPCookie(properties: [
    .domain: "console.volcengine.com",
    .path: "/",
    .name: "csrfToken",
    .value: "c",
    .secure: "TRUE"
])!
let volcengineDigest = HTTPCookie(properties: [
    .domain: ".volcengine.com",
    .path: "/",
    .name: "digest",
    .value: "digest-token",
    .secure: "TRUE"
])!
let volcengineUserInfo = HTTPCookie(properties: [
    .domain: ".volcengine.com",
    .path: "/",
    .name: "userInfo",
    .value: "user-info-token",
    .secure: "TRUE"
])!

let volcengineRequiredCookies = Provider.volcengineCodingPlan.dashboardAuthenticationCookieNames
require(DashboardCookieBuilder.containsRequiredCookie(
    from: [volcengineAccountID, volcengineCSRF],
    domains: ["volcengine.com", "console.volcengine.com"],
    requiredNames: volcengineRequiredCookies
) == false, "Volcengine reauthentication must not auto-save partial console cookies")
require(DashboardCookieBuilder.containsRequiredCookie(
    from: [volcengineAccountID, volcengineCSRF, volcengineDigest],
    domains: ["volcengine.com", "console.volcengine.com"],
    requiredNames: volcengineRequiredCookies
), "Volcengine reauthentication should not block on the userInfo display cookie when core auth cookies are present")
require(DashboardCookieBuilder.missingRequiredCookieNames(
    inCookieHeader: "AccountID=2120638754; csrfToken=c",
    requiredNames: volcengineRequiredCookies
) == ["digest"], "Manual Volcengine cookie save should report missing core auth cookies only")
let reauthedVolcengineSecret = DashboardCookieBuilder.reauthenticatedSecret(
    cookieHeader: "AccountID=2120638754; csrfToken=n; digest=d; userInfo=u",
    existingSecret: #"{"cookie":"old","csrfToken":"old","projectName":"default","xWebId":"web-id"}"#
)
let reauthedVolcengineData = reauthedVolcengineSecret.data(using: .utf8)!
let reauthedVolcengineObject = try! JSONSerialization.jsonObject(with: reauthedVolcengineData) as! [String: String]
require(reauthedVolcengineObject["cookie"]?.contains("digest=d") == true, "Volcengine reauthentication should replace the saved cookie inside JSON credentials")
require(reauthedVolcengineObject["csrfToken"] == "n", "Volcengine reauthentication should sync csrfToken from the refreshed cookie")
require(reauthedVolcengineObject["projectName"] == "default", "Volcengine reauthentication should preserve the projectName JSON field")
require(reauthedVolcengineObject["xWebId"] == "web-id", "Volcengine reauthentication should preserve the xWebId JSON field")

let reauthedOpenCodeSecret = DashboardCookieBuilder.reauthenticatedSecret(
    cookieHeader: "auth=a; oc_locale=zh",
    existingSecret: #"{"cookie":"old","workspaceID":"wrk_1","serverID":"srv_1","serverInstance":"server-fn:11"}"#
)
let reauthedOpenCodeData = reauthedOpenCodeSecret.data(using: .utf8)!
let reauthedOpenCodeObject = try! JSONSerialization.jsonObject(with: reauthedOpenCodeData) as! [String: String]
require(reauthedOpenCodeObject["cookie"] == "auth=a; oc_locale=zh", "OpenCode Go reauthentication should replace the saved cookie inside JSON credentials")
require(reauthedOpenCodeObject["workspaceID"] == "wrk_1", "OpenCode Go reauthentication should preserve workspaceID")
require(reauthedOpenCodeObject["serverID"] == "srv_1", "OpenCode Go reauthentication should preserve serverID")
require(reauthedOpenCodeObject["serverInstance"] == "server-fn:11", "OpenCode Go reauthentication should preserve serverInstance")

require(Provider.xfyunCodingPlan.supportsDashboardReauthentication, "XFYun should support dashboard reauthentication")
require(Provider.volcengineCodingPlan.supportsDashboardReauthentication, "Volcengine should support dashboard reauthentication")
require(Provider.opencodeGo.supportsDashboardReauthentication, "OpenCode Go should support dashboard reauthentication")
require(Provider.querit.supportsDashboardReauthentication, "Querit should support dashboard-cookie reauthentication")
require(!Provider.brave.supportsDashboardReauthentication, "Brave should not use dashboard-cookie reauthentication")
require(DashboardReauthConfig(provider: .opencodeGo)?.cookieDomains == ["opencode.ai"], "OpenCode Go should capture only opencode.ai cookies")
require(DashboardReauthConfig(provider: .xfyunCodingPlan)?.cookieDomains == ["xfyun.cn", "maas.xfyun.cn"], "XFYun should capture maas.xfyun.cn and domain-wide xfyun.cn cookies")
require(DashboardReauthConfig(provider: .volcengineCodingPlan)?.cookieDomains == ["volcengine.com", "console.volcengine.com"], "Volcengine should capture console.volcengine.com and domain-wide volcengine.com cookies")
require(DashboardReauthConfig(provider: .querit)?.cookieDomains == ["querit.ai"], "Querit should capture querit.ai dashboard cookies")
require(DashboardReauthConfig(provider: .opencodeGo)?.requiredCookieNames == ["auth"], "OpenCode Go should auto-save only after auth cookies exist")
require(DashboardReauthConfig(provider: .querit)?.requiredCookieNames.contains("osduss") == true, "Querit should auto-save only after account cookies exist")

for provider in [Provider.querit, .xfyunCodingPlan, .volcengineCodingPlan, .opencodeGo] {
    guard let config = DashboardReauthConfig(provider: provider) else {
        require(false, "\(provider.rawValue) should expose dashboard reauthentication config")
        continue
    }
    let completeCookies = config.requiredCookieNames.map { name in
        HTTPCookie(properties: [
            .domain: config.cookieDomains.first ?? "",
            .path: "/",
            .name: name,
            .value: "v",
            .secure: "TRUE"
        ])!
    }
    let partialCookies = Array(completeCookies.dropLast())
    require(DashboardCookieBuilder.containsRequiredCookie(
        from: partialCookies,
        domains: config.cookieDomains,
        requiredNames: config.requiredCookieNames
    ) == false, "\(provider.rawValue) should not save a partial dashboard login cookie set")
    require(DashboardCookieBuilder.containsRequiredCookie(
        from: completeCookies,
        domains: config.cookieDomains,
        requiredNames: config.requiredCookieNames
    ), "\(provider.rawValue) should save once all dashboard login cookies are present")
}
SWIFT

swiftc QuotaRadar/Models/AppLanguage.swift QuotaRadar/Models/APIKey.swift QuotaRadar/Services/DashboardReauth.swift "$TMP_DIR/main.swift" -o "$TMP_DIR/dashboard-reauth-test"
"$TMP_DIR/dashboard-reauth-test"

echo "== Legacy configuration migration behavior =="
cat >"$TMP_DIR/main.swift" <<'SWIFT'
import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(1)
    }
}

let defaults = UserDefaults(suiteName: "QuotaRadarMigrationTests.\(UUID().uuidString)")!
let legacyDefaults = UserDefaults(suiteName: "QuotaRadarLegacyMigrationTests.\(UUID().uuidString)")!
defaults.removePersistentDomain(forName: defaults.dictionaryRepresentation().description)
legacyDefaults.removePersistentDomain(forName: legacyDefaults.dictionaryRepresentation().description)
legacyDefaults.set("simplifiedChinese", forKey: "appLanguage")
legacyDefaults.set("legacy-metadata".data(using: .utf8), forKey: "apiKeyMetadata")
defaults.set(0.42, forKey: "statusBarTransparency")
LegacyConfigurationMigrator.migrateUserDefaultsIfNeeded(defaults: defaults, legacyDefaults: legacyDefaults)
require(defaults.string(forKey: "appLanguage") == "simplifiedChinese", "Legacy migration should copy missing language preference")
require(defaults.data(forKey: "apiKeyMetadata") == "legacy-metadata".data(using: .utf8), "Legacy migration should copy missing API metadata")
require(defaults.double(forKey: "statusBarTransparency") == 0.42, "Legacy migration should not overwrite existing new preferences")
require(defaults.bool(forKey: LegacyConfigurationMigrator.migrationMarkerKey), "Legacy migration should set a marker")

let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
let newURL = root.appendingPathComponent("QuotaRadar/secrets.json")
let oldURL = root.appendingPathComponent("QuotaBar/secrets.json")
try! FileManager.default.createDirectory(at: oldURL.deletingLastPathComponent(), withIntermediateDirectories: true)
FileManager.default.createFile(
    atPath: oldURL.path,
    contents: try! JSONEncoder().encode(["legacy-id": "legacy-secret"]),
    attributes: [.posixPermissions: 0o644]
)
try! FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: oldURL.deletingLastPathComponent().path)
let migratedSecretStore = FileSecretStore(fileURL: newURL, legacyFileURL: oldURL)
require((try! migratedSecretStore.read(account: "legacy-id")) == "legacy-secret", "FileSecretStore should copy old QuotaBar secrets into QuotaRadar on first read")
require(FileManager.default.fileExists(atPath: newURL.path), "FileSecretStore should create the new QuotaRadar secret file during migration")
let migratedFilePermissions = ((try! FileManager.default.attributesOfItem(atPath: newURL.path)[.posixPermissions] as! NSNumber).intValue & 0o777)
require(migratedFilePermissions == 0o600, "Migrated QuotaRadar secret file should use 0600 permissions")
SWIFT

swiftc QuotaRadar/Services/FileSecretStore.swift QuotaRadar/Services/LegacyConfigurationMigrator.swift "$TMP_DIR/main.swift" -o "$TMP_DIR/legacy-migration-test"
"$TMP_DIR/legacy-migration-test"

echo "== Secret store behavior =="
cat >"$TMP_DIR/main.swift" <<'SWIFT'
import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(1)
    }
}

AppLanguageStore.shared.language = .english
let secretURL = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent(UUID().uuidString)
    .appendingPathComponent("secrets.json")
let secretStore = FileSecretStore(fileURL: secretURL)
try! secretStore.save("tvly-secret", account: "account-1")
require((try! secretStore.read(account: "account-1")) == "tvly-secret", "FileSecretStore should read saved secrets")

let attrs = try! FileManager.default.attributesOfItem(atPath: secretURL.path)
let permissions = (attrs[.posixPermissions] as! NSNumber).intValue & 0o777
require(permissions == 0o600, "FileSecretStore should write secrets with 0600 permissions")
let dirAttrs = try! FileManager.default.attributesOfItem(atPath: secretURL.deletingLastPathComponent().path)
let dirPermissions = (dirAttrs[.posixPermissions] as! NSNumber).intValue & 0o777
require(dirPermissions == 0o700, "FileSecretStore should create its directory with 0700 permissions")

secretStore.delete(account: "account-1")
require((try! secretStore.read(account: "account-1")) == nil, "FileSecretStore should delete secrets")

let legacyURL = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent(UUID().uuidString)
    .appendingPathComponent("secrets.json")
try! FileManager.default.createDirectory(at: legacyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
FileManager.default.createFile(
    atPath: legacyURL.path,
    contents: try! JSONEncoder().encode(["legacy": "secret"]),
    attributes: [.posixPermissions: 0o644]
)
try! FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: legacyURL.deletingLastPathComponent().path)
let legacyStore = FileSecretStore(fileURL: legacyURL)
require((try! legacyStore.read(account: "legacy")) == "secret", "FileSecretStore should read existing secret files")
let tightenedDirAttrs = try! FileManager.default.attributesOfItem(atPath: legacyURL.deletingLastPathComponent().path)
let tightenedDirPermissions = (tightenedDirAttrs[.posixPermissions] as! NSNumber).intValue & 0o777
let tightenedFileAttrs = try! FileManager.default.attributesOfItem(atPath: legacyURL.path)
let tightenedFilePermissions = (tightenedFileAttrs[.posixPermissions] as! NSNumber).intValue & 0o777
require(tightenedDirPermissions == 0o700, "FileSecretStore should tighten legacy directory permissions on read")
require(tightenedFilePermissions == 0o600, "FileSecretStore should tighten legacy file permissions on read")

let defaults = UserDefaults(suiteName: "QuotaRadarBehaviorTests.\(UUID().uuidString)")!
let store = APIKeyStore(defaults: defaults, secretStore: secretStore)
let keyID = UUID()
let key = APIKey(id: keyID, name: "TAVILY_API_KEY", key: "tvly-from-store", provider: .tavily)
store.save([key])
let metadataOnly = store.load()
require(metadataOnly.count == 1, "APIKeyStore should load saved metadata")
require(metadataOnly[0].key.isEmpty, "APIKeyStore metadata load should not include secrets")
let hydrated = store.loadSecrets(for: metadataOnly)
require(hydrated[0].key == "tvly-from-store", "APIKeyStore should hydrate secrets from FileSecretStore")

let staleQueritID = UUID()
let validQueritID = UUID()
let staleQueritMetadata = """
[{"id":"\(staleQueritID.uuidString)","name":"QUERIT_API_KEY","provider":"Querit","isActive":true,"quotaLabel":"凭据已过期","usageCount":0},{"id":"\(validQueritID.uuidString)","name":"QUERIT_COOKIE","provider":"Querit","isActive":true,"usageCount":0}]
"""
defaults.set(Data(staleQueritMetadata.utf8), forKey: "apiKeyMetadata")
let migratedQuerit = store.load()
require(!migratedQuerit.contains { $0.name == "QUERIT_API_KEY" }, "APIKeyStore should remove stale Querit API-key records because Querit quota checks require dashboard cookies")
require(migratedQuerit.contains { $0.name == "QUERIT_COOKIE" && $0.provider == .querit }, "APIKeyStore should keep valid Querit cookie records")

let staleBraveID = UUID()
let staleBraveMetadata = """
[{"id":"\(staleBraveID.uuidString)","name":"BRAVE_API_KEY","provider":"Brave","isActive":true,"remaining":0,"limit":0,"quotaLabel":"No monthly quota remaining","usageCount":0}]
"""
defaults.set(Data(staleBraveMetadata.utf8), forKey: "apiKeyMetadata")
let migratedBrave = store.load()
require(migratedBrave.count == 1, "APIKeyStore should load Brave metadata")
require(migratedBrave[0].quotaLabel == "Search OK · monthly quota not exposed", "APIKeyStore should migrate ambiguous Brave zero-window labels")
SWIFT

swiftc QuotaRadar/Models/AppLanguage.swift QuotaRadar/Models/APIKey.swift QuotaRadar/Services/FileSecretStore.swift QuotaRadar/Services/APIKeyStore.swift "$TMP_DIR/main.swift" -o "$TMP_DIR/secret-store-test"
"$TMP_DIR/secret-store-test"

echo "== Quota parser behavior =="
cat >"$TMP_DIR/main.swift" <<'SWIFT'
import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(1)
    }
}

AppLanguageStore.shared.language = .english
let tavily = try! QuotaParsers.parseTavilyUsage(Data("""
{"key":{"usage":150,"limit":1000},"account":{"plan_usage":500,"plan_limit":15000}}
""".utf8))
require(tavily.remaining == 850, "Tavily should use key limit when present")
require(tavily.limit == 1000, "Tavily key limit should be parsed")
require(tavily.quotaLabel == "850 / 1000 monthly credits", "Tavily should label free quota as monthly credits")
require(tavily.resetAt != nil, "Tavily free monthly credits should expose the next monthly reset date")
let tavilyResetComponents = Calendar.current.dateComponents([.day, .hour, .minute, .second], from: tavily.resetAt!)
require(tavilyResetComponents.day == 1, "Tavily free monthly credits should reset on the first day of the next month")
require(tavilyResetComponents.hour == 0 && tavilyResetComponents.minute == 0 && tavilyResetComponents.second == 0, "Tavily free monthly credits should reset at local midnight")

let tavilyAccount = try! QuotaParsers.parseTavilyUsage(Data("""
{"key":{"usage":1000,"limit":null},"account":{"plan_usage":1000,"plan_limit":1000}}
""".utf8))
require(tavilyAccount.remaining == 0, "Tavily should fall back to account plan remaining")
require(tavilyAccount.limit == 1000, "Tavily account plan limit should be parsed")
require(tavilyAccount.resetAt != nil, "Tavily account fallback should still expose the known monthly reset date")

let brave = try! QuotaParsers.parseBraveRateLimit(
    limitHeader: "50, 1000",
    remainingHeader: "49, 812",
    resetHeader: "1, 931196",
    policyHeader: "50;w=1, 1000;w=2678400"
)
require(brave.remaining == 812, "Brave should parse the monthly window remaining value")
require(brave.limit == 1000, "Brave should parse the monthly window limit value")
require(brave.resetAt != nil && brave.resetAt! > Date(), "Brave should expose a future reset time from X-RateLimit-Reset")
let braveExhausted = try! QuotaParsers.parseBraveRateLimit(
    limitHeader: "50, 0",
    remainingHeader: "49, 0",
    resetHeader: "1, 931196",
    policyHeader: "50;w=1, 0;w=2678400"
)
require(braveExhausted.remaining == Int.max, "Brave zero monthly windows with HTTP 200 should not be treated as exhausted")
require(braveExhausted.limit == Int.max, "Brave zero monthly windows with HTTP 200 should not be treated as a 0 / 0 quota")
require(braveExhausted.quotaLabel == "Search OK · monthly quota not exposed", "Brave zero monthly windows should show usable search with unavailable monthly quota")
let braveKnownManualQuota = QuotaParsers.applyKnownBraveMonthlyQuotaIfNeeded(
    braveExhausted,
    knownRemaining: 1000,
    knownLimit: 1000
)
require(braveKnownManualQuota.remaining == 999, "Known Brave monthly quotas should decrement once for the quota-check search")
require(braveKnownManualQuota.limit == 1000, "Known Brave monthly quota limit should be preserved when Brave hides the monthly header")
require(braveKnownManualQuota.quotaLabel == "999 / 1000 monthly requests", "Known Brave monthly quotas should display the known manual limit")

let serp = try! QuotaParsers.parseSerpApiAccount(Data("""
{"searches_per_month":250,"plan_searches_left":0,"extra_credits":5,"total_searches_left":5,"this_month_usage":250}
""".utf8))
require(serp.remaining == 5, "SerpAPI should prefer total_searches_left")
require(serp.limit == 255, "SerpAPI should include extra credits in the displayed limit")
var utcCalendar = Calendar(identifier: .gregorian)
utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
let serpResetComponents = utcCalendar.dateComponents([.day, .hour, .minute, .second], from: serp.resetAt!)
require(serpResetComponents.day == 1, "SerpAPI reset should be represented as the first day of next month in UTC")
require(serpResetComponents.hour == 0 && serpResetComponents.minute == 0 && serpResetComponents.second == 0, "SerpAPI reset should be midnight UTC")

let serper = try! QuotaParsers.parseSerperAccount(Data("""
{"balance":24,"rateLimit":5}
""".utf8))
require(serper.remaining == 24, "Serper should parse account balance as remaining credits")
require(serper.limit == 24, "Serper should not invent a larger monthly request limit")
require(serper.quotaLabel == "24 credits left", "Serper should display credit balance")
require(serper.resetAt == nil, "Serper account endpoint does not expose a reset date")

let exhaustedSerper = try! QuotaParsers.parseSerperAccount(Data("""
{"balance":-1,"rateLimit":5}
""".utf8))
require(exhaustedSerper.remaining == 0, "Serper negative balance should be displayed as exhausted")
require(exhaustedSerper.limit == 0, "Serper exhausted balance should not look like an available limit")
require(exhaustedSerper.quotaLabel == "No Serper credits available", "Serper negative balance should explain the exhausted state")

let exaUsage = try! QuotaParsers.parseExaUsage(Data("""
{"api_key_id":"550e8400-e29b-41d4-a716-446655440000","api_key_name":"Production API Key","total_cost_usd":45.67,"cost_breakdown":[]}
""".utf8))
require(exaUsage.remaining == Int.max, "Exa usage is billing cost only and should not invent a remaining quota")
require(exaUsage.limit == Int.max, "Exa usage is billing cost only and should not invent a quota limit")
require(exaUsage.quotaLabel == "USD 45.67 used", "Exa usage should display total billed cost for the period")

let deepSeek = try! QuotaParsers.parseDeepSeekBalance(Data("""
{"is_available":true,"balance_infos":[{"currency":"CNY","total_balance":"12.50","granted_balance":"0","topped_up_balance":"12.50"}]}
""".utf8))
require(deepSeek.remaining == 1250, "DeepSeek balance should be represented in cents")
require(deepSeek.quotaLabel == "CNY 12.50 available", "DeepSeek should display money, not fake request counts")

let wechat = try! QuotaParsers.parseDajialaRemainMoney(Data("""
{"code":0,"remain_money":161.8,"yesterday_money":162.02,"request_time":"2026-05-21 13:54:32"}
""".utf8))
require(wechat.remaining == 16180, "WeChat search balance should be represented in cents")
require(wechat.limit == 16180, "WeChat search balance should not invent a larger request limit")
require(wechat.quotaLabel == "CNY 161.80 available", "WeChat search should display remaining money")

let bocha = try! QuotaParsers.parseBochaRemainingFund(Data("""
{"success":true,"code":"200","msg":"success","data":{"remaining":14.00}}
""".utf8))
require(bocha.remaining == 1400, "Bocha account balance should be represented in cents")
require(bocha.limit == 1400, "Bocha account balance should not invent a larger request limit")
require(bocha.quotaLabel == "CNY 14.00 balance", "Bocha should display remaining account balance")
require(bocha.resetAt == nil, "Bocha account balance should not invent a reset cycle")

let querit = try! QuotaParsers.parseQueritAccount(Data("""
{"ErrNo":200,"Msg":"success","Data":{"current_plan":{"plan_type":"free","free_usage_month":120,"coupon_quota":300,"coupon_used":20,"paid_usage_month":0,"enterprise_usage_month":0}}}
""".utf8))
require(querit.remaining == 1160, "Querit should calculate remaining monthly requests from 1000 + coupon_quota - free_usage_month - coupon_used")
require(querit.limit == 1300, "Querit should include coupon quota in the monthly request limit")
require(querit.quotaLabel == "1160 / 1300 monthly requests", "Querit should display monthly request quota")
require(querit.resetAt != nil, "Querit monthly account quota should expose the next reset date")

let xfyun = try! QuotaParsers.parseXFYunCodingPlanList(Data("""
{"code":0,"data":{"rows":[{"name":"高效版","expiresAt":"2026-06-28 17:48:58","codingPlanUsageDTO":{"packageLeft":80704,"packageLimit":90000,"packageUsage":9296,"rp5hLimit":6000,"rp5hUsage":60,"rpwLimit":45000,"rpwUsage":9296}}]},"succeed":true}
""".utf8))
require(xfyun.remaining == 7934, "XFYun should represent the tightest coding-plan window as basis-point percentage remaining")
require(xfyun.limit == 10000, "XFYun coding-plan percentage limit should be 10000 basis points")
require(xfyun.quotaLabel == "5h 99% · week 79.3% · month 89.7%", "XFYun should display only remaining percentages")
require(xfyun.resetAt != nil, "XFYun should expose the package expiry as the reset date")

let volc = try! QuotaParsers.parseVolcengineCodingPlanUsage(Data("""
{"ResponseMetadata":{"Action":"GetCodingPlanUsage"},"Result":{"Status":"Running","QuotaUsage":[{"Level":"session","Percent":0,"ResetTimestamp":-1},{"Level":"weekly","Percent":10.814960999999998,"ResetTimestamp":1780848000},{"Level":"monthly","Percent":5.407480499999999,"ResetTimestamp":1782921599}]}}
""".utf8))
require(volc.remaining == 8918, "Volcengine should use the tightest remaining usage window")
require(volc.limit == 10000, "Volcengine coding-plan percentage limit should be 10000 basis points")
require(volc.quotaLabel == "5h 100% · week 89.2% · month 94.6%", "Volcengine should display five-hour, weekly, and monthly usage windows")
require(volc.resetAt != nil, "Volcengine should expose the tightest finite reset timestamp")

let opencode = try! QuotaParsers.parseOpenCodeGoUsage(Data("""
;0x00000129;((self.$R=self.$R||{})["server-fn:11"]=[],($R=>$R[0]={mine:!0,useBalance:!1,rollingUsage:$R[1]={status:"ok",resetInSec:16946,usagePercent:2},weeklyUsage:$R[2]={status:"ok",resetInSec:547976,usagePercent:50},monthlyUsage:$R[3]={status:"ok",resetInSec:2204389,usagePercent:75}})($R["server-fn:11"]))
""".utf8))
require(opencode.remaining == 2500, "OpenCode Go should use the tightest remaining usage window")
require(opencode.limit == 10000, "OpenCode Go percentage limit should be 10000 basis points")
require(opencode.quotaLabel == "5h 98% · week 50% · month 25%", "OpenCode Go should display rolling, weekly, and monthly usage windows")
require(opencode.resetAt != nil && opencode.resetAt! > Date(), "OpenCode Go should convert resetInSec into a future reset date")
SWIFT

swiftc QuotaRadar/Models/AppLanguage.swift QuotaRadar/Models/APIKey.swift QuotaRadar/Services/QuotaService.swift "$TMP_DIR/main.swift" -o "$TMP_DIR/quota-parser-test"
"$TMP_DIR/quota-parser-test"

echo "== SwiftPM build =="
swift build

echo "== App bundle build =="
./install.sh --bundle-only --rebuild
test -x "build/Quota Radar.app/Contents/MacOS/QuotaRadar" || fail "app bundle executable is missing"
test -f "build/Quota Radar.app/Contents/Resources/QuotaRadar.icns" || fail "app bundle icon is missing"
plutil -extract CFBundleExecutable raw "build/Quota Radar.app/Contents/Info.plist" | rg '^QuotaRadar$' >/dev/null || fail "bundle executable name is wrong"
plutil -extract CFBundleIconFile raw "build/Quota Radar.app/Contents/Info.plist" | rg '^QuotaRadar$' >/dev/null || fail "bundle icon name is wrong"
plutil -extract CFBundleDisplayName raw "build/Quota Radar.app/Contents/Info.plist" | rg '^Quota Radar$' >/dev/null || fail "bundle display name is wrong"
codesign --verify --deep --strict --verbose=2 "build/Quota Radar.app" >/dev/null

echo "All behavior tests passed"
