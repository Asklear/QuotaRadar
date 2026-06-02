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
  if rg -n "$pattern" "$path" >/tmp/quotabar-test-match.txt; then
    cat /tmp/quotabar-test-match.txt >&2
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
  "QuotaBar/Models/QuotaMonitor.swift" \
  "DefaultKeys must not contain embedded API secrets"
assert_no_match '@StateObject private var monitor = QuotaMonitor\(' \
  "QuotaBar/Views/SettingsView.swift" \
  "SettingsView must use the shared QuotaMonitor instance"
assert_no_match 'for var key in apiKeys where key\.isActive' \
  "QuotaBar/Models/QuotaMonitor.swift" \
  "refreshAll must preserve inactive keys instead of filtering them out"
assert_no_match '\$\(' \
  "QuotaBar/Info.plist" \
  "Info.plist in the source bundle must contain concrete app bundle values"
assert_match 'CFBundleIconFile' \
  "QuotaBar/Info.plist" \
  "Info.plist must declare the app icon file"
assert_no_match 'LSUIElement' \
  "QuotaBar/Info.plist" \
  "QuotaBar must appear in the macOS Dock after launch"
assert_match 'setActivationPolicy\(\.regular\)' \
  "QuotaBar/AppDelegate.swift" \
  "QuotaBar should explicitly use a regular activation policy so it appears in Dock"
assert_match 'enum AppLanguage' \
  "QuotaBar/Models/AppLanguage.swift" \
  "QuotaBar should define an app language enum"
assert_match 'case english' \
  "QuotaBar/Models/AppLanguage.swift" \
  "QuotaBar language options should include English"
assert_match 'case simplifiedChinese' \
  "QuotaBar/Models/AppLanguage.swift" \
  "QuotaBar language options should include Simplified Chinese"
assert_match 'AppLanguageStore' \
  "QuotaBar/Models/AppLanguage.swift" \
  "QuotaBar should persist the selected app language"
assert_match 'func displayName\(language: AppLanguage = AppLanguageStore\.shared\.language\)' \
  "QuotaBar/Models/APIKey.swift" \
  "Providers should expose localized display names instead of rendering raw persistence values"
assert_match 'static var visibleCases: \[Provider\]' \
  "QuotaBar/Models/APIKey.swift" \
  "Provider UI lists should use a visible provider list so unsupported providers can be kept out without breaking legacy decoding"
assert_no_match 'ForEach\(Provider\.allCases\)' \
  "QuotaBar/Views" \
  "Visible provider pickers should not render every Codable provider case"
assert_no_match 'Text\(.*(stat\.)?provider\.rawValue|Label\(.*rawValue|provider\.rawValue\) \(L10n\.t' \
  "QuotaBar/Views" \
  "Visible provider labels should use localized display names instead of raw persistence values"
assert_no_match 'return \.anthropic' \
  "QuotaBar/Services/EnvImporter.swift" \
  "Anthropic should not be imported as a supported provider for now"
assert_no_match '\| Anthropic \|' \
  "README.md" \
  "Anthropic should not be listed as a currently supported provider"
assert_no_match 'api\.anthropic\.com' \
  "QuotaBar/Info.plist" \
  "Anthropic API domains should not be whitelisted while Anthropic is not supported"
assert_match '简体中文' \
  "QuotaBar/Models/AppLanguage.swift" \
  "The language picker should expose Simplified Chinese as a user-facing option"
assert_match 'applicationShouldHandleReopen' \
  "QuotaBar/AppDelegate.swift" \
  "Dock icon clicks should reopen a visible QuotaBar window instead of doing nothing"
assert_match 'openPreferences\(\)' \
  "QuotaBar/AppDelegate.swift" \
  "Dock reopen handling should show the settings window when no app window is visible"
assert_no_match 'SettingsView\(monitor: \.shared\)' \
  "QuotaBar/QuotaBarApp.swift" \
  "SwiftUI Settings scene must not host the real settings UI because it restores the old off-screen system settings window"
assert_match 'CommandGroup\(replacing: \.appSettings\)' \
  "QuotaBar/QuotaBarApp.swift" \
  "The app Settings command should route through AppDelegate.openPreferences so the managed window placement is used"
assert_match 'clearSwiftUISettingsWindowAutosaveFrame' \
  "QuotaBar/AppDelegate.swift" \
  "QuotaBar should clear the stale SwiftUI Settings window autosave frame that can place the app on a hidden display"
assert_match 'showManagedSettingsWindowOnLaunch' \
  "QuotaBar/AppDelegate.swift" \
  "Launching QuotaBar should replace SwiftUI's empty Settings scene window with the managed settings window"
assert_match 'forceSettingsWindowOntoPreferredScreen' \
  "QuotaBar/AppDelegate.swift" \
  "QuotaBar should force the managed settings window onto the preferred screen after it is shown"
assert_no_match 'visibleFrame\.contains\(currentFrame\)' \
  "QuotaBar/AppDelegate.swift" \
  "Settings window placement should not skip repositioning because restored external-display frames can race after launch"
assert_match 'scheduleSettingsWindowPlacementRecovery' \
  "QuotaBar/AppDelegate.swift" \
  "Settings window placement should be re-applied after launch restoration races"
assert_match 'applicationDidBecomeActive' \
  "QuotaBar/AppDelegate.swift" \
  "Settings window placement should be recovered when QuotaBar becomes active again"
assert_match 'windowDidBecomeKey' \
  "QuotaBar/AppDelegate.swift" \
  "Settings window placement should be recovered when the settings window becomes key"
assert_match 'screen\.frame\.minX == 0 && screen\.frame\.minY == 0' \
  "QuotaBar/AppDelegate.swift" \
  "Settings window placement should prefer the physical primary display at origin zero instead of NSScreen.main after a window was restored on an external display"
assert_match 'showStatusPopover' \
  "QuotaBar/AppDelegate.swift" \
  "Status bar clicks should show only the status popover instead of activating the main app window"
assert_match 'openPreferences\(destination: \.settings\)' \
  "QuotaBar/Views/MenuContentView.swift" \
  "The status bar settings button should open the Settings tab instead of the default API Keys page"
assert_match 'openPreferences\(destination: \.apiKeys\)' \
  "QuotaBar/Views/MenuContentView.swift" \
  "The status bar empty-state configuration button should open the API Keys page"
assert_match 'SettingsNavigationStore' \
  "QuotaBar/Views/SettingsView.swift" \
  "The settings window should expose shared navigation state so status-bar actions can select a tab"
assert_match '\$navigationStore\.selection' \
  "QuotaBar/Views/SettingsView.swift" \
  "The sidebar selection should be driven by shared navigation state"
assert_match 'navigationOrder: \[SettingsDestination\] = \[\.providers, \.apiKeys, \.diagnostics, \.settings\]' \
  "QuotaBar/Views/SettingsView.swift" \
  "Main navigation should prioritize quota observation, credential configuration, diagnostics, then language/appearance"
assert_match '@Published var selection: SettingsDestination\? = \.providers' \
  "QuotaBar/Views/SettingsView.swift" \
  "The main window should open on quota observation by default"
assert_match 'case diagnostics' \
  "QuotaBar/Views/SettingsView.swift" \
  "The main navigation should include a diagnostics page"
assert_match 'DiagnosticsView\(monitor: monitor\)' \
  "QuotaBar/Views/SettingsView.swift" \
  "Selecting diagnostics should show the diagnostics page"
assert_match 'CredentialDiagnosticRow' \
  "QuotaBar/Views/SettingsView.swift" \
  "Diagnostics should render credential-level rows"
assert_match 'startPopoverMouseExitMonitor' \
  "QuotaBar/AppDelegate.swift" \
  "Status bar popover should start a mouse-exit monitor when shown"
assert_match 'closePopoverIfMouseExited' \
  "QuotaBar/AppDelegate.swift" \
  "Status bar popover should close automatically after the pointer leaves the popover and status item"
assert_match 'NSEvent\.mouseLocation' \
  "QuotaBar/AppDelegate.swift" \
  "Status bar popover auto-close should track the pointer in screen coordinates"
assert_match 'NSStatusBar\.system\.statusItem' \
  "QuotaBar/AppDelegate.swift" \
  "AppDelegate must install a macOS status bar item"
assert_match 'enum RefreshMode' \
  "QuotaBar/Models/QuotaMonitor.swift" \
  "Quota refreshes should distinguish manual refreshes from automatic background polling"
assert_match 'func refreshAll\(mode: RefreshMode = \.manual\)' \
  "QuotaBar/Models/QuotaMonitor.swift" \
  "Manual UI refresh should remain available while automatic refreshes can avoid quota-consuming providers"
assert_match 'func refreshProvider\(_ provider: Provider, mode: RefreshMode = \.manual\)' \
  "QuotaBar/Models/QuotaMonitor.swift" \
  "Manual UI refreshes should be available per provider instead of only globally"
assert_match '@Published var refreshingProviders: Set<Provider>' \
  "QuotaBar/Models/QuotaMonitor.swift" \
  "Provider-level refresh buttons should have provider-specific loading state"
assert_match '@Published var refreshMessage' \
  "QuotaBar/Models/QuotaMonitor.swift" \
  "Manual refresh clicks should have visible status feedback instead of appearing to do nothing"
assert_match 'L10n\.t\(\.refreshAlreadyRunning\)' \
  "QuotaBar/Models/QuotaMonitor.swift" \
  "Manual refresh clicks during an active refresh should explain that a refresh is already running"
assert_match 'Refresh already running' \
  "QuotaBar/Models/AppLanguage.swift" \
  "Manual refresh clicks during an active refresh should have an English localized message"
assert_match 'bypassCooldown: mode == \.manual' \
  "QuotaBar/Models/QuotaMonitor.swift" \
  "Manual refreshes should bypass the short duplicate-check cooldown"
assert_match 'func checkQuota\(for key: APIKey, bypassCooldown: Bool = false\)' \
  "QuotaBar/Services/QuotaService.swift" \
  "QuotaService should let manual refreshes bypass its duplicate-check cooldown"
assert_match 'httpStatus' \
  "QuotaBar/Services/QuotaService.swift" \
  "Quota results should carry HTTP status for diagnostics"
assert_match 'diagnosticMessage' \
  "QuotaBar/Services/QuotaService.swift" \
  "Quota results should carry a provider-specific diagnostic message"
assert_no_match 'throw QuotaError\.notSupported // 使用缓存或跳过' \
  "QuotaBar/Services/QuotaService.swift" \
  "Cooldown skips must not masquerade as unsupported providers"
assert_match 'quotaCheckConsumesSearchQuota' \
  "QuotaBar/Models/APIKey.swift" \
  "Providers such as Brave should declare when checking quota consumes real search quota"
assert_match 'lastHTTPStatus' \
  "QuotaBar/Models/APIKey.swift" \
  "API keys should persist the last HTTP status for diagnostics"
assert_match 'lastDiagnosticMessage' \
  "QuotaBar/Models/APIKey.swift" \
  "API keys should persist the last diagnostic message"
assert_match 'httpNotRequested' \
  "QuotaBar/Models/AppLanguage.swift" \
  "Diagnostics should distinguish unsupported or unrequested checks from failed HTTP requests"
assert_no_match 'key\.lastHTTPStatus\.map\(String\.init\) \?\? "N/A"' \
  "QuotaBar/Views/SettingsView.swift" \
  "Diagnostics should not show N/A when no HTTP request was made"
assert_match 'unsupportedQuotaDiagnosticMessage' \
  "QuotaBar/Models/APIKey.swift" \
  "Unsupported providers should explain why quota checks cannot be monitored"
assert_match 'https://www\.querit\.ai/api/v1/user/account' \
  "QuotaBar/Services/QuotaService.swift" \
  "Querit should query the dashboard account endpoint with saved session cookies"
assert_match 'parseQueritAccount' \
  "QuotaBar/Services/QuotaService.swift" \
  "Querit account responses should be parsed from dashboard account data"
assert_match 'monthlyCreditsFormat' \
  "QuotaBar/Models/AppLanguage.swift" \
  "Quota labels such as monthly credits should be localized instead of rendered as raw English"
assert_match 'zeroRemainingBadge' \
  "QuotaBar/Models/AppLanguage.swift" \
  "Compact exhausted badges should be localized instead of hardcoding 0 left"
assert_match 'isUsableWithUnknownQuota' \
  "QuotaBar/Models/APIKey.swift" \
  "API keys should distinguish usable credentials whose quota is not exposed"
assert_match 'isUsageLimitExceeded' \
  "QuotaBar/Models/APIKey.swift" \
  "API keys should distinguish provider usage-limit exhaustion from unknown quota"
assert_match 'mode == \.automatic && key\.provider\.quotaCheckConsumesSearchQuota' \
  "QuotaBar/Models/QuotaMonitor.swift" \
  "Automatic refreshes must skip quota checks that consume provider search quota"
assert_match 'quotaMonitor\.refreshAll\(mode: \.automatic\)' \
  "QuotaBar/AppDelegate.swift" \
  "Background timer refreshes should use automatic mode"
assert_no_match 'quotaMonitor\.refreshAll\(\)' \
  "QuotaBar/AppDelegate.swift" \
  "AppDelegate must not use manual refresh semantics for background polling"
assert_match 'MenuContentView\(monitor: quotaMonitor\)' \
  "QuotaBar/AppDelegate.swift" \
  "Status bar item must host MenuContentView with the shared monitor"
assert_match 'NSPopover' \
  "QuotaBar/AppDelegate.swift" \
  "Status bar surface must use NSPopover instead of NSMenu so the frosted glass view is not painted over by an opaque menu window"
assert_match 'setupPopover' \
  "QuotaBar/AppDelegate.swift" \
  "AppDelegate should configure a dedicated popover for the status bar glass surface"
assert_match 'popover\.behavior = \.transient' \
  "QuotaBar/AppDelegate.swift" \
  "Status bar popover should dismiss naturally when the user clicks away"
assert_match 'popover\.contentSize = MenuContentView\.menuSize' \
  "QuotaBar/AppDelegate.swift" \
  "Status bar popover must use MenuContentView.menuSize"
assert_match 'popover\.show\(relativeTo: button\.bounds, of: button, preferredEdge: \.minY\)' \
  "QuotaBar/AppDelegate.swift" \
  "Status bar button should show the glass popover anchored below the menu bar icon"
assert_no_match 'statusItem\?\.menu = menu' \
  "QuotaBar/AppDelegate.swift" \
  "Status bar glass surface must not be attached as an NSMenu"
assert_no_match 'class GlassMenu' \
  "QuotaBar/AppDelegate.swift" \
  "The old NSMenu wrapper should be removed because it prevents the intended translucent glass surface"
assert_match 'homeProviderStats' \
  "QuotaBar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should expose provider stats for the home view"
assert_match 'homeCategoryStats' \
  "QuotaBar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should expose status bar category groups"
assert_match 'ProviderCategoryStats' \
  "QuotaBar/Models/APIKey.swift" \
  "Status bar category groups should have a model instead of ad hoc view filtering"
assert_match 'var id: String \{ provider\.id \}' \
  "QuotaBar/Models/APIKey.swift" \
  "ProviderStats identity should be stable across quota refreshes so expanded sections and scroll position are preserved"
assert_no_match 'let id = UUID\(\)' \
  "QuotaBar/Models/APIKey.swift" \
  "ProviderStats must not use a fresh UUID because refreshes would recreate every provider row"
assert_match '\$0\.remaining != Int\.max' \
  "QuotaBar/Models/APIKey.swift" \
  "ProviderStats must exclude Int.max sentinel remaining values from provider totals to avoid arithmetic overflow"
assert_match '\$0\.limit != Int\.max' \
  "QuotaBar/Models/APIKey.swift" \
  "ProviderStats must exclude Int.max sentinel limits from provider totals to avoid arithmetic overflow"
assert_match 'homeVisibleWithoutKeys' \
  "QuotaBar/Models/APIKey.swift" \
  "New coding-plan providers should be able to appear on the home view before keys are configured"
assert_match 'provider\.homeVisibleWithoutKeys' \
  "QuotaBar/Models/QuotaMonitor.swift" \
  "Home provider stats should include supported coding-plan provider placeholders"
assert_no_match 'provider.category == "Search"' \
  "QuotaBar/Models/QuotaMonitor.swift" \
  "Home provider stats must include configured LLM providers instead of hiding them"
assert_match 'monitor.homeProviderStats' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Home view should render all configured provider quota stats"
assert_no_match 'monitor.providerStats' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Home view should use QuotaMonitor.homeProviderStats as the single home data source"
assert_match 'ForEach\(monitor\.homeCategoryStats\)' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Status bar home view should group providers by category"
assert_no_match 'ForEach\(monitor\.homeProviderStats\) \{ stat in' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Status bar home view should not render a flat provider list"
assert_match 'ProviderCategorySection' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Status bar home view should provide collapsible category sections"
assert_no_match 'spring\(response: 0\.3\)' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Status bar collapsible sections should not use spring animation"
assert_no_match 'Image\(systemName: "chevron.down"\)' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Status bar collapsible sections should not show triangle/chevron disclosure icons"
assert_match 'menuCollapseAnimation = Animation\.easeInOut\(duration: 0\.16\)' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Status bar collapsible sections should use the same calm short animation as the main app"
assert_match 'MenuCollapsibleBanner' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Status bar category sections should use clickable banners"
assert_match 'MenuProviderBanner' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Status bar provider sections should use clickable provider banners"
assert_match 'ZStack\(alignment: \.trailing\)' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Status bar provider banners should make the full banner surface a collapse target while overlaying the refresh control"
assert_match 'trailingControlReserve' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Status bar provider banners should reserve trailing space so the refresh control does not steal the collapse hit target"
assert_match 'monitor\.refreshProvider\(stat\.provider\)' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Status bar provider sections should refresh only the selected provider"
assert_no_match 'onRefresh: \{ monitor\.refreshAll\(\) \}' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Status bar home view must not expose only a single global refresh action"
assert_match 'RefreshButton\(isRefreshing: \.constant\(isRefreshing\), isEnabled: canRefresh' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Each status bar provider section should own its refresh button"
assert_match 'AI Search' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Status bar home view should label search providers as AI Search"
assert_match 'LLM' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Status bar home view should label model/coding providers as LLM"
assert_match 'MenuContentView.menuSize' \
  "QuotaBar/AppDelegate.swift" \
  "Status bar hosting view must use MenuContentView.menuSize to avoid clipping"
assert_match 'hostingController\.view\.wantsLayer = true' \
  "QuotaBar/AppDelegate.swift" \
  "Status bar hosting view should use a clear layer so the popover can render as frosted glass"
assert_match 'backgroundColor = NSColor\.clear\.cgColor' \
  "QuotaBar/AppDelegate.swift" \
  "Status bar hosting view should not paint an opaque background over the frosted glass"
assert_match 'menuSize = CGSize\(width: 420, height: 560\)' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Status bar home view should be wide enough that the left edge is not covered"
assert_match 'contentHorizontalInset' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Status bar home view should reserve an explicit horizontal inset to avoid left-edge clipping"
assert_match 'menuGlassCornerRadius' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Status bar menu should have a defined frosted-glass rounded container"
assert_match 'VisualEffectBlur\(material: \.hudWindow' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Status bar menu should use a stronger translucent frosted-glass material"
assert_match '\.clipShape\(RoundedRectangle\(cornerRadius: Self\.menuGlassCornerRadius' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Status bar menu should clip the frosted background to a modern rounded container"
assert_match 'providerHeaderLeadingPadding' \
  "QuotaBar/Views/SettingsView.swift" \
  "API Keys provider headers should reserve explicit leading space so provider icons are not clipped by the macOS List edge"
assert_match '\.padding\(\.leading, Self\.providerHeaderLeadingPadding\)' \
  "QuotaBar/Views/SettingsView.swift" \
  "API Keys provider headers must apply their leading padding inside the section header"
assert_no_match 'hostingView\.frame = NSRect\(x: 0, y: 0, width: 340, height: 480\)' \
  "QuotaBar/AppDelegate.swift" \
  "Status bar hosting view must not be smaller than the SwiftUI menu"
assert_match 'EmptyQuotaStateView' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Status bar menu must have a first-run empty state"
assert_match 'quotaSummary' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Key rows must expose a quota summary for each API key"
assert_match 'Text\(key\.maskedKey\)' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Status bar key rows should show the actual masked API key, not the environment variable name"
assert_no_match 'Text\(key\.name\)' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Status bar key rows must not show TAVILY_API_KEY-style environment variable names"
assert_no_match 'key\.key\.count' \
  "QuotaBar/Views/SettingsView.swift" \
  "Settings API key rows must not waste the right side on API key character counts"
assert_no_match 'chars' \
  "QuotaBar/Views/SettingsView.swift" \
  "Settings API key rows must not show API key character counts"
assert_match 'Text\(key\.resetSummary\)' \
  "QuotaBar/Views/SettingsView.swift" \
  "Settings API key rows should show quota reset timing on the right side"
assert_match 'Text\(key\.quotaDisplayText\)' \
  "QuotaBar/Views/SettingsView.swift" \
  "Settings API key rows should show provider quota labels instead of only normalized remaining/limit values"
assert_no_match 'Text\("\\\(remaining\)/\\\(limit\)"\)' \
  "QuotaBar/Views/SettingsView.swift" \
  "Settings API key rows must not collapse multi-window coding-plan quotas to one normalized remaining/limit value"
assert_match 'sortedKeysByCurrentQuota' \
  "QuotaBar/Models/APIKey.swift" \
  "ProviderStats should expose API keys sorted by current quota descending"
assert_no_match 'ProviderStats\.sortedByCurrentQuota' \
  "QuotaBar/Models/QuotaMonitor.swift" \
  "Provider sections should keep the product-defined provider order"
assert_match 'return stats' \
  "QuotaBar/Models/QuotaMonitor.swift" \
  "ProviderStats should preserve Provider.allCases order instead of sorting provider sections by quota"
assert_match 'ForEach\(stat\.sortedKeysByCurrentQuota\)' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Status bar provider sections should list keys by current quota descending"
assert_match 'sortedByCurrentQuota' \
  "QuotaBar/Views/SettingsView.swift" \
  "Settings API key sections should list keys by current quota descending"
assert_match 'Text\(key\.remainingBadgeText\)' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Status bar key badges should distinguish exhausted keys from tiny nonzero quotas"
assert_match 'resetSummary' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Key rows must expose reset timing for each API key"
assert_match 'var resetSummary: String' \
  "QuotaBar/Models/APIKey.swift" \
  "Quota reset timing should be shared by all key row views"
assert_match 'L10n\.t\(\.noResetCycle' \
  "QuotaBar/Models/APIKey.swift" \
  "Money-balance providers should make clear that quota does not reset on a cycle"
assert_match 'L10n\.t\(\.resetsMonthlyDay1' \
  "QuotaBar/Models/APIKey.swift" \
  "Tavily should communicate its known monthly reset cycle even before the next usage refresh"
assert_match 'L10n\.t\(\.resetNotExposed' \
  "QuotaBar/Models/APIKey.swift" \
  "Providers without reset data should not pretend to know reset timing"
assert_match 'L10n\.t\(\.openDashboard' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Provider sections should link to provider dashboards when available"
assert_match 'ProviderIcon\(provider: stat.provider' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Menu provider sections should use official provider icons"
assert_match 'ModernPage\(' \
  "QuotaBar/Views/SettingsView.swift" \
  "Providers page must have its own modern header so the first provider card is not hidden under the title area"
assert_match 'keyProviderCategories' \
  "QuotaBar/Views/SettingsView.swift" \
  "API Keys tab should group configured keys by AI Search and LLM so OpenCode Go is visible under LLM"
assert_match 'return \["LLM", "AI Search"\]' \
  "QuotaBar/Views/SettingsView.swift" \
  "API Keys tab should put LLM keys first so OpenCode Go is immediately visible"
assert_match 'NavigationSplitView' \
  "QuotaBar/Views/SettingsView.swift" \
  "Main window should use the current macOS sidebar/content split view instead of an older tab-only layout"
assert_no_match '\.frame\(minWidth: 820, minHeight: 580\)' \
  "QuotaBar/Views/SettingsView.swift" \
  "Main window must not keep the old narrow minimum size because the sidebar plus provider content gets squeezed"
assert_match '\.frame\(minWidth: 1040, minHeight: 640\)' \
  "QuotaBar/Views/SettingsView.swift" \
  "Main window should reserve enough width for the sidebar and modern provider panels"
assert_no_match 'window\.setContentSize\(NSSize\(width: 640, height: 560\)\)' \
  "QuotaBar/AppDelegate.swift" \
  "Settings window creation must not force the modern SettingsView into the old narrow 640x560 window"
assert_no_match 'window\.minSize = NSSize\(width: 560, height: 460\)' \
  "QuotaBar/AppDelegate.swift" \
  "Settings window minimum size must not remain smaller than the modern SettingsView layout"
assert_match 'preferredSettingsContentSize' \
  "QuotaBar/AppDelegate.swift" \
  "Settings window should use one shared modern content size"
assert_match 'keepSettingsWindowOnScreen' \
  "QuotaBar/AppDelegate.swift" \
  "Opening settings should pull any previously off-screen window back onto the visible display"
assert_match 'closeRestoredSettingsWindows' \
  "QuotaBar/AppDelegate.swift" \
  "Dock icon reopen should replace restored stale settings windows instead of reusing a broken split-view state"
assert_match 'preferredSettingsVisibleFrame' \
  "QuotaBar/AppDelegate.swift" \
  "Settings window should prefer the non-negative primary working screen instead of a stale negative-coordinate external display"
assert_match 'CGGetActiveDisplayList' \
  "QuotaBar/AppDelegate.swift" \
  "Settings window placement should inspect all active displays and choose a non-negative display when available"
assert_no_match '\.frame\(minWidth: 480, maxWidth: 560' \
  "QuotaBar/QuotaBarApp.swift" \
  "The native Settings scene must not constrain the same SettingsView to a narrow 560-point maximum"
assert_match 'SettingsSidebarView' \
  "QuotaBar/Views/SettingsView.swift" \
  "Main window should have a dedicated macOS-style sidebar"
assert_no_match 'List\(selection: \$selection\)' \
  "QuotaBar/Views/SettingsView.swift" \
  "Main window sidebar should not rely on NavigationSplitView List selection because it is not rendering/clicking reliably in the custom NSWindow"
assert_no_match 'NavigationLink\(value: destination\)' \
  "QuotaBar/Views/SettingsView.swift" \
  "Main window sidebar should not rely on value NavigationLink rows that disappear in the custom NSWindow"
assert_match 'SidebarNavigationButton' \
  "QuotaBar/Views/SettingsView.swift" \
  "Main window sidebar rows should be explicit visible clickable buttons"
assert_match 'selection = destination' \
  "QuotaBar/Views/SettingsView.swift" \
  "Main window sidebar buttons should explicitly switch the selected page"
assert_no_match '\.tag\(destination as SettingsDestination\?\)' \
  "QuotaBar/Views/SettingsView.swift" \
  "Main window sidebar rows must not be inert Label rows that only rely on a tag"
assert_no_match '\.listStyle\(\.sidebar\)' \
  "QuotaBar/Views/SettingsView.swift" \
  "Main window sidebar should not use a List style that leaves the navigation rows blank here"
assert_no_match 'ToolbarItemGroup|\.toolbar \{' \
  "QuotaBar/Views/SettingsView.swift" \
  "Credentials page should not duplicate the in-page credential actions in the top-right toolbar"
assert_match 'MaterialPanel' \
  "QuotaBar/Views/SettingsView.swift" \
  "Main window content should use modern material-backed panels instead of the old heavy glass card stack"
assert_no_match 'TabView\(selection:' \
  "QuotaBar/Views/SettingsView.swift" \
  "Main window should not keep the old tab view chrome after adopting a macOS sidebar layout"
assert_match 'KeyProviderCategorySection' \
  "QuotaBar/Views/SettingsView.swift" \
  "API Keys tab should render category sections instead of one long flat provider list"
assert_match 'ProviderIcon\(provider: provider' \
  "QuotaBar/Views/SettingsView.swift" \
  "Settings provider headers should use official provider icons"
assert_match 'providerCategories' \
  "QuotaBar/Views/SettingsView.swift" \
  "Settings Providers page should group providers into AI Search and LLM sections"
assert_match 'ProviderSettingsCategorySection' \
  "QuotaBar/Views/SettingsView.swift" \
  "Settings Providers page should render collapsible provider category sections"
assert_no_match 'spring\(response: 0\.3\)' \
  "QuotaBar/Views/SettingsView.swift" \
  "Settings collapsible sections should not use spring animation because it makes panels fly down"
assert_no_match 'move\(edge: \.top\)' \
  "QuotaBar/Views/SettingsView.swift" \
  "Settings collapsible sections should not use top-edge movement transitions"
assert_match 'settingsCollapseAnimation = Animation\.easeInOut\(duration: 0\.16\)' \
  "QuotaBar/Views/SettingsView.swift" \
  "Settings collapsible sections should use a short calm ease-in-out animation"
assert_match 'withAnimation\(settingsCollapseAnimation\) \{ isExpanded\.toggle\(\) \}' \
  "QuotaBar/Views/SettingsView.swift" \
  "Settings provider cards should collapse with the shared calm animation"
assert_match 'CollapsibleBanner' \
  "QuotaBar/Views/SettingsView.swift" \
  "Settings collapsible sections should use a clickable banner as the disclosure control"
assert_no_match 'Image\(systemName: "chevron.down"\)' \
  "QuotaBar/Views/SettingsView.swift" \
  "Settings collapsible sections should not show a triangle/chevron disclosure icon"
assert_match '\.contentShape\(RoundedRectangle\(cornerRadius: 12, style: \.continuous\)\)' \
  "QuotaBar/Views/SettingsView.swift" \
  "Settings collapsible banners should make the full banner clickable"
assert_match 'ProviderCardBanner' \
  "QuotaBar/Views/SettingsView.swift" \
  "Provider cards should use a dedicated clickable banner instead of only making the left label area clickable"
assert_match 'ZStack\(alignment: \.trailing\)' \
  "QuotaBar/Views/SettingsView.swift" \
  "Provider card banners should make the full banner surface a collapse target while overlaying the refresh control"
assert_match 'trailingControlReserve' \
  "QuotaBar/Views/SettingsView.swift" \
  "Provider card banners should reserve trailing space so the refresh control does not steal the collapse hit target"
assert_match 'Button\(action: onToggle\)' \
  "QuotaBar/Views/SettingsView.swift" \
  "Provider card banners should use a real button for reliable clicks on the non-control banner area"
assert_match 'monitor\.refreshProvider\(provider\)' \
  "QuotaBar/Views/SettingsView.swift" \
  "Settings provider sections should refresh only the selected provider"
assert_no_match 'Refresh All' \
  "QuotaBar/Views/SettingsView.swift" \
  "Settings must not present quota refresh as one global action"
assert_match 'AppSettingsView' \
  "QuotaBar/Views/SettingsView.swift" \
  "Settings should include an app settings tab for language selection"
assert_match 'Picker\(L10n\.t\(\.language' \
  "QuotaBar/Views/SettingsView.swift" \
  "Settings should provide a language picker"
assert_match 'AppAppearanceStore' \
  "QuotaBar/Models/AppAppearance.swift" \
  "QuotaBar should persist appearance settings such as status bar transparency"
assert_match 'statusBarTransparency' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Status bar glass UI should react to the configured transparency"
assert_match 'Slider\(value: \$appearanceStore\.statusBarTransparency, in: 0\.10\.\.\.0\.95\)' \
  "QuotaBar/Views/SettingsView.swift" \
  "Language/appearance settings should expose a wider 10%-95% status bar transparency slider"
assert_no_match '0\.20\.\.\.0\.88|0\.72 \+ \(1 - statusBarTransparency\) \* 0\.20|0\.20 - statusBarTransparency \* 0\.12' \
  "QuotaBar" \
  "Status bar transparency must not keep the old narrow range or barely visible opacity formula"
assert_match '\.providersTab: "额度监控"' \
  "QuotaBar/Models/AppLanguage.swift" \
  "Simplified Chinese navigation should name the quota observation page explicitly"
assert_match '\.apiKeysTab: "配置凭据"' \
  "QuotaBar/Models/AppLanguage.swift" \
  "Simplified Chinese navigation should avoid implying every credential is an API key"
assert_match '\.settingsTab: "语言与外观"' \
  "QuotaBar/Models/AppLanguage.swift" \
  "Simplified Chinese navigation should put language and appearance last"
assert_match 'APIKeyConfigurationPanel' \
  "QuotaBar/Views/SettingsView.swift" \
  "API Keys page should expose a visible in-page API key configuration panel"
assert_match 'L10n\.t\(\.apiKeyConfiguration\)' \
  "QuotaBar/Views/SettingsView.swift" \
  "API key configuration panel should have a clear localized title"
assert_match 'Button\(action: onAddKey\)' \
  "QuotaBar/Views/SettingsView.swift" \
  "API key configuration panel should expose a direct Add Key action in the main content area"
assert_match 'Button\(action: onImportEnv\)' \
  "QuotaBar/Views/SettingsView.swift" \
  "API key configuration panel should expose a direct .env import action in the main content area"
assert_match 'APIKeyProviderBanner' \
  "QuotaBar/Views/SettingsView.swift" \
  "API Keys provider sections should use a clickable provider banner"
assert_match '@State private var isExpanded = true' \
  "QuotaBar/Views/SettingsView.swift" \
  "API Keys provider sections should own provider-level collapse state"
assert_match 'APIKeyManagementRow' \
  "QuotaBar/Views/SettingsView.swift" \
  "API Keys page should use management-focused key rows rather than quota overview rows"
assert_no_match 'KeyRowItem' \
  "QuotaBar/Views/SettingsView.swift" \
  "API Keys page should not use quota-observation rows that duplicate the Providers page"
assert_no_match '\.onTapGesture' \
  "QuotaBar/Views/SettingsView.swift" \
  "Credential rows must not open the edit sheet when the user is trying to toggle enabled state"
assert_match 'onSetActive: \{ isActive in' \
  "QuotaBar/Views/SettingsView.swift" \
  "Credential rows should route enabled-state changes through a dedicated handler"
assert_match 'Toggle\(isOn: Binding\(get: \{ key\.isActive \}' \
  "QuotaBar/Views/SettingsView.swift" \
  "Credential rows should enable or disable directly without opening the edit sheet"
assert_match 'provider\.supportsDashboardReauthentication \? L10n\.t\(\.dashboardSession\) : L10n\.t\(\.apiKey\)' \
  "QuotaBar/Views/SettingsView.swift" \
  "Dashboard-session providers should label their secret as a session cookie rather than an API key"
assert_match 'L10n\.t\(\.apiKeysTab' \
  "QuotaBar/Views/SettingsView.swift" \
  "Settings tab labels should use localized strings"
assert_match 'L10n\.t\(\.apiQuotaTitle' \
  "QuotaBar/Views/MenuContentView.swift" \
  "Status bar title should use localized strings"
assert_match 'L10n\.categoryTitle\(provider\.statusBarCategoryTitle' \
  "QuotaBar/Views/SettingsView.swift" \
  "Provider cards should localize category subtitles instead of showing raw English category labels"
assert_no_match '\.providersTab: "Provider"' \
  "QuotaBar/Models/AppLanguage.swift" \
  "Simplified Chinese UI should not leave Providers untranslated as Provider"
assert_no_match '\.providers: "Provider"' \
  "QuotaBar/Models/AppLanguage.swift" \
  "Simplified Chinese status bar stats should not leave Providers untranslated as Provider"
assert_match '\.provider: "服务商"' \
  "QuotaBar/Models/AppLanguage.swift" \
  "Simplified Chinese form labels should not leave Provider untranslated"
assert_no_match 'provider 的额度|provider 刷新' \
  "QuotaBar/Models/AppLanguage.swift" \
  "Simplified Chinese helper text should not keep provider as an untranslated UI word"
assert_match 'supportsDashboardReauthentication' \
  "QuotaBar/Models/APIKey.swift" \
  "Dashboard-cookie Coding Plan providers should declare that they support in-app reauthentication"
assert_match 'cookieDomains' \
  "QuotaBar/Models/APIKey.swift" \
  "Dashboard-cookie Coding Plan providers should declare the domains whose cookies can be saved"
assert_match 'dashboardAuthenticationCookieNames' \
  "QuotaBar/Models/APIKey.swift" \
  "Dashboard-cookie providers should declare authentication cookie names for automatic saving"
assert_match 'DashboardReauthConfig' \
  "QuotaBar/Services/DashboardReauth.swift" \
  "Dashboard reauthentication should have a provider-specific configuration model"
assert_match 'DashboardCookieBuilder' \
  "QuotaBar/Services/DashboardReauth.swift" \
  "Dashboard reauthentication should build Cookie headers through a testable helper"
assert_match 'containsRequiredCookie' \
  "QuotaBar/Services/DashboardReauth.swift" \
  "Dashboard reauthentication should wait for provider authentication cookies before auto-saving"
assert_match 'import WebKit' \
  "QuotaBar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should use an in-app WebKit login window"
assert_match 'WKWebView' \
  "QuotaBar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should embed WKWebView"
assert_match 'WKNavigationDelegate' \
  "QuotaBar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should observe dashboard navigation so it can auto-save cookies after login"
assert_match 'webView\(_ webView: WKWebView, didFinish navigation: WKNavigation!\)' \
  "QuotaBar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should check cookies when the WebView finishes loading a dashboard page"
assert_match 'onCookiesAvailable' \
  "QuotaBar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should expose an automatic cookie-save callback"
assert_match 'WKWebsiteDataStore\.default\(\)\.httpCookieStore' \
  "QuotaBar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should read only cookies from the in-app WebKit data store"
assert_match 'monitor\.updateKey' \
  "QuotaBar/Views/DashboardReauthView.swift" \
  "Saving dashboard cookies should update the selected QuotaBar credential"
assert_match 'monitor\.refreshProvider' \
  "QuotaBar/Views/DashboardReauthView.swift" \
  "Saving dashboard cookies should immediately refresh that provider"
assert_match 'DashboardReauthSheet' \
  "QuotaBar/Views/SettingsView.swift" \
  "Settings should expose dashboard reauthentication for cookie-backed providers"
assert_match 'Credential expired' \
  "QuotaBar/Models/AppLanguage.swift" \
  "Expired dashboard credentials should have an English localized label"
assert_match '凭据已过期' \
  "QuotaBar/Models/AppLanguage.swift" \
  "Expired dashboard credentials should have a Simplified Chinese localized label"
assert_match 'autoCookieSaveHint' \
  "QuotaBar/Models/AppLanguage.swift" \
  "Dashboard reauthentication should explain that cookies will be saved automatically after login"
assert_match 'QuotaError\.unauthorized' \
  "QuotaBar/Models/QuotaMonitor.swift" \
  "Unauthorized quota refreshes should mark dashboard credentials as expired"
assert_match 'key\.lastDiagnosticMessage = key\.provider\.supportsDashboardReauthentication \? L10n\.t\(\.credentialExpired\) : error\.localizedDescription' \
  "QuotaBar/Models/QuotaMonitor.swift" \
  "Dashboard-cookie providers should not describe expired cookies as invalid API keys"
assert_no_match 'Cookies\.binarycookies|Login Data|Library/Application Support/Google/Chrome|SecKeychain' \
  "QuotaBar" \
  "QuotaBar must not scrape browser cookie databases or use login Keychain APIs for reauthentication"
assert_no_match 'Image\(systemName: provider\.icon\)' \
  "QuotaBar/Views/SettingsView.swift" \
  "Settings provider headers must not fall back to colored SF Symbols when provider icons exist"
assert_no_match 'clipShape\(Circle\(\)\)' \
  "QuotaBar/Views/Components.swift" \
  "ProviderIcon must not crop official provider logos into generic circles"
assert_match 'drawQuotaCell' \
  "scripts/generate_app_icon.swift" \
  "The app icon generator should use the approved quota-cell icon"
assert_match 'drawQuotaCellFill' \
  "scripts/generate_app_icon.swift" \
  "The app icon generator should render one large, clear quota-cell fill instead of tiny reserve segments"
assert_no_match 'drawQuotaCellSegments|drawProviderDots|keyRingCenter' \
  "scripts/generate_app_icon.swift" \
  "The app icon generator should remove tiny decorations that make the battery blurry at small sizes"
assert_no_match 'drawModernQuotaGlyph|drawLiquidAppGlyph' \
  "scripts/generate_app_icon.swift" \
  "The app icon generator should remove earlier rejected app icon drawings"
assert_match 'title: L10n\.t\(\.providersHeader' \
  "QuotaBar/Views/SettingsView.swift" \
  "Providers tab header must label the page"
assert_match 'ClaudeSettingsImporter' \
  "QuotaBar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should initialize from ~/.claude/settings.json on first launch"
assert_match 'didAttemptClaudeSettingsImport' \
  "QuotaBar/Services/APIKeyStore.swift" \
  "Claude settings auto-import must be guarded so it only runs once"
assert_match 'mergeImportedKeys' \
  "QuotaBar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should merge newly added Claude settings keys into existing QuotaBar metadata"
assert_no_match 'hasAnySecret' \
  "QuotaBar/Models/QuotaMonitor.swift" \
  "QuotaMonitor must not skip Claude settings import just because old secrets already exist"
assert_match 'func loadSecrets' \
  "QuotaBar/Services/APIKeyStore.swift" \
  "Secrets must be loaded separately from metadata"
assert_no_match 'KeychainStore' \
  "QuotaBar/Services/APIKeyStore.swift" \
  "APIKeyStore must not use the login Keychain because ad-hoc rebuilds trigger repeated macOS password prompts"
assert_no_match 'SecItem' \
  "QuotaBar" \
  "QuotaBar must not call login Keychain SecItem APIs"
assert_match 'Application Support/QuotaBar' \
  "QuotaBar/Services/FileSecretStore.swift" \
  "Secrets should be stored in QuotaBar Application Support instead of the login Keychain"
assert_match 'posixPermissions' \
  "QuotaBar/Services/FileSecretStore.swift" \
  "Secret storage file must set restrictive filesystem permissions"
assert_match 'https://api.tavily.com/usage' \
  "QuotaBar/Services/QuotaService.swift" \
  "Tavily quota must use the official usage endpoint"
assert_match 'nextMonthStartLocal' \
  "QuotaBar/Services/QuotaService.swift" \
  "Tavily free monthly credits should reset on the first day of the next local month"
assert_match 'X-Subscription-Token' \
  "QuotaBar/Services/QuotaService.swift" \
  "Brave quota checks must use X-Subscription-Token authentication"
assert_no_match 'No monthly quota (remaining|configured)' \
  "QuotaBar/Services/QuotaService.swift" \
  "Brave keys that return HTTP 200 with a zero monthly header should not be labeled as unusable quota"
assert_match 'https://google.serper.dev/account' \
  "QuotaBar/Services/QuotaService.swift" \
  "Serper quota must use the non-search account endpoint"
assert_match 'parseSerperAccount' \
  "QuotaBar/Services/QuotaService.swift" \
  "Serper account responses should be parsed as credit balance"
assert_match 'X-API-KEY' \
  "QuotaBar/Services/QuotaService.swift" \
  "Serper account checks must authenticate with X-API-KEY"
assert_no_match 'api.exa.ai/(usage|account|user)' \
  "QuotaBar/Services/QuotaService.swift" \
  "Exa must not use removed/nonexistent plain search-key account endpoints"
assert_match 'https://admin-api\.exa\.ai/team-management/api-keys' \
  "QuotaBar/Services/QuotaService.swift" \
  "Exa quota should use the official Team Management usage endpoint"
assert_match 'request\.setValue\(credential\.serviceKey, forHTTPHeaderField: "x-api-key"\)' \
  "QuotaBar/Services/QuotaService.swift" \
  "Exa quota checks should authenticate with the Admin API service key"
assert_match 'parseExaUsage' \
  "QuotaBar/Services/QuotaService.swift" \
  "Exa usage responses should be parsed from Team Management billing data"
assert_match 'Exa Admin API requires a service key' \
  "QuotaBar/Services/QuotaService.swift" \
  "Exa search API keys should explain that usage requires the Admin API service key"
assert_match 'key\.remaining = nil' \
  "QuotaBar/Models/QuotaMonitor.swift" \
  "Unsupported quota refreshes must clear stale remaining values"
assert_match 'key\.limit = nil' \
  "QuotaBar/Models/QuotaMonitor.swift" \
  "Unsupported quota refreshes must clear stale quota limits"
assert_match 'key\.lastUpdated = Date\(\)' \
  "QuotaBar/Models/QuotaMonitor.swift" \
  "Unsupported quota refreshes should still mark when the provider state was checked"
assert_no_match 'api.anysearch.ai' \
  "QuotaBar/Services/QuotaService.swift" \
  "AnySearch must not use the obsolete .ai endpoint"
assert_match 'Unlimited free usage' \
  "QuotaBar/Services/QuotaService.swift" \
  "AnySearch should be represented as free unlimited usage instead of quota unavailable"
assert_match 'case \.anysearch:' \
  "QuotaBar/Services/QuotaService.swift" \
  "AnySearch must have explicit quota handling"
assert_match 'https://www.dajiala.com/fbmain/monitor/v3/get_remain_money' \
  "QuotaBar/Services/QuotaService.swift" \
  "WeChat search quota must use the Dajiala remaining-money endpoint"
assert_match 'application/x-www-form-urlencoded' \
  "QuotaBar/Services/QuotaService.swift" \
  "Dajiala remaining-money checks must submit form-encoded API keys"
assert_match 'https://api.bochaai.com/v1/fund/remaining' \
  "QuotaBar/Services/QuotaService.swift" \
  "Bocha quota should use the official remaining-fund endpoint"
assert_match 'parseBochaRemainingFund' \
  "QuotaBar/Services/QuotaService.swift" \
  "Bocha remaining-fund responses should be parsed as account balance"
assert_match 'https://maas.xfyun.cn/api/v1/gpt-finetune/coding-plan/list' \
  "QuotaBar/Services/QuotaService.swift" \
  "XFYun Coding Plan should use the dashboard coding-plan list endpoint"
assert_match 'https://console.volcengine.com/api/top/ark/cn-beijing/2024-01-01/GetCodingPlanUsage' \
  "QuotaBar/Services/QuotaService.swift" \
  "Volcengine Coding Plan should use the console GetCodingPlanUsage endpoint"
assert_match 'https://opencode.ai/_server' \
  "QuotaBar/Services/QuotaService.swift" \
  "OpenCode Go should use the dashboard server function endpoint"
assert_match 'Chrome/148\.0\.0\.0 Safari/537\.36' \
  "QuotaBar/Services/QuotaService.swift" \
  "OpenCode Go usage checks should send browser-like headers so opencode.ai does not reject URLSession defaults"
assert_match 'sec-fetch-site' \
  "QuotaBar/Services/QuotaService.swift" \
  "OpenCode Go usage checks should include browser fetch metadata headers"
assert_match 'parseXFYunCodingPlanList' \
  "QuotaBar/Services/QuotaService.swift" \
  "XFYun Coding Plan responses should be parsed as coding quota windows"
assert_match 'parseVolcengineCodingPlanUsage' \
  "QuotaBar/Services/QuotaService.swift" \
  "Volcengine Coding Plan responses should be parsed as coding quota windows"
assert_match 'parseOpenCodeGoUsage' \
  "QuotaBar/Services/QuotaService.swift" \
  "OpenCode Go dashboard responses should be parsed as coding quota windows"
assert_match 'https://www.querit.ai/en/dashboard/usage' \
  "QuotaBar/Models/APIKey.swift" \
  "Querit must link to the official usage dashboard when API quota is not exposed"
assert_no_match 'magnifyingglass.circle' \
  "QuotaBar/AppDelegate.swift" \
  "The status bar icon must not use the indistinct magnifying glass symbol"
assert_no_match 'heights: \[CGFloat\] = \[5, 9, 12\]' \
  "QuotaBar/AppDelegate.swift" \
  "The status bar icon must not use the old indistinct three-bar glyph"
assert_no_match 'dotRect' \
  "QuotaBar/AppDelegate.swift" \
  "The status bar icon must not use the old bar-plus-dot glyph"
assert_match 'drawQuotaCellStatusGlyph' \
  "QuotaBar/AppDelegate.swift" \
  "The status bar icon should use a compact quota-cell glyph"
assert_match 'drawStatusBatteryFill' \
  "QuotaBar/AppDelegate.swift" \
  "The status bar quota-cell glyph should use a single clear battery fill"
assert_match 'makeStatusBarIcon' \
  "QuotaBar/AppDelegate.swift" \
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
  "Install script should reuse build/QuotaBar.app by default to preserve local approvals"
test -f "QuotaBar/Resources/QuotaBar.icns" || fail "QuotaBar.icns must exist for Finder/Application icon"
plutil -lint "QuotaBar/QuotaBar.entitlements" >/dev/null || fail "entitlements plist must be valid"

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

root = Path("QuotaBar/Assets.xcassets/ProviderIcons")
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
require(Provider.exa.localizedUnsupportedQuotaLabel(language: .simplifiedChinese) == "需要 Admin 凭据", "Exa plain search keys should explain that Admin credentials are required instead of showing a generic unavailable label")
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
require(xfyunStat.totalRemainingDisplayText == "5h 99%", "Coding Plan provider remaining should display the largest remaining percentage window with its period")
AppLanguageStore.shared.language = .simplifiedChinese
require(xfyunStat.totalLimitDisplayText == "月 89.7%", "Coding Plan provider total should localize the monthly period label in Simplified Chinese")
require(xfyunStat.totalRemainingDisplayText == "5 小时 99%", "Coding Plan provider remaining should localize the five-hour period label in Simplified Chinese")
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
require(localizedDeepSeekMoney.quotaDisplayText == "可用 CNY 12.50", "Money available labels should be localized in Simplified Chinese")
let localizedBochaBalance = APIKey(name: "BOCHA_API_KEY", key: "bocha", provider: .bocha, remaining: 1400, limit: 1400, quotaLabel: "CNY 14.00 balance")
require(localizedBochaBalance.quotaDisplayText == "余额 CNY 14.00", "Money balance labels should be localized in Simplified Chinese")
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
require(volcengineStat.totalRemainingDisplayText == "5h 100%", "Volcengine provider remaining should display the largest remaining percentage window with its period")
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
require(opencodeStat.totalRemainingDisplayText == "5h 98%", "OpenCode Go provider remaining should display the largest remaining percentage window with its period")
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
let settingsURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("claude-settings.json")
try! Data("""
{"env":{"TAVILY_API_KEY":"tvly-from-settings","BRAVE_API_KEY":"brave-from-settings","ANTHROPIC_API_KEY":""}}
""".utf8).write(to: settingsURL)
let settingsKeys = ClaudeSettingsImporter.parseSettings(at: settingsURL)
require(settingsKeys.count == 2, "Claude settings importer should skip empty env values")
require(settingsKeys.contains { $0.name == "TAVILY_API_KEY" && $0.provider == .tavily }, "Claude settings importer missing Tavily")
require(settingsKeys.contains { $0.name == "BRAVE_API_KEY" && $0.provider == .brave }, "Claude settings importer missing Brave")
SWIFT

swiftc QuotaBar/Models/AppLanguage.swift QuotaBar/Models/APIKey.swift QuotaBar/Services/EnvImporter.swift QuotaBar/Services/ClaudeSettingsImporter.swift "$TMP_DIR/main.swift" -o "$TMP_DIR/env-importer-test"
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

let defaults = UserDefaults(suiteName: "QuotaBarLanguageTests.\(UUID().uuidString)")!
defaults.removePersistentDomain(forName: defaults.dictionaryRepresentation().description)
defaults.set(AppLanguage.simplifiedChinese.rawValue, forKey: AppLanguageStore.defaultsKey)
let store = AppLanguageStore(defaults: defaults)
require(store.language == .simplifiedChinese, "AppLanguageStore should load the persisted Simplified Chinese selection")
store.language = .english
require(defaults.string(forKey: AppLanguageStore.defaultsKey) == AppLanguage.english.rawValue, "AppLanguageStore should persist language changes")
require(AppLanguage.english.displayName == "English", "English language option should have a stable display name")
require(AppLanguage.simplifiedChinese.displayName == "简体中文", "Simplified Chinese language option should have a Chinese display name")
require(L10n.t(.providersTab, language: .english) == "Quota Overview", "English quota overview tab title should be available")
require(L10n.t(.providersHeader, language: .english) == "Quota Overview", "English quota overview page title should match the navigation")
require(L10n.t(.apiKeysTab, language: .english) == "Credentials", "English credentials tab title should be available")
require(L10n.t(.settingsTab, language: .english) == "Language & Appearance", "English language and appearance tab title should be available")
require(L10n.t(.providersTab, language: .simplifiedChinese) == "额度监控", "Chinese quota monitoring tab title should be available")
require(L10n.t(.providersHeader, language: .simplifiedChinese) == "额度监控", "Chinese quota monitoring page title should match the navigation")
require(L10n.t(.apiKeysTab, language: .simplifiedChinese) == "配置凭据", "Chinese credentials tab title should be available")
require(L10n.t(.dashboardSession, language: .simplifiedChinese) == "控制台会话 Cookie", "Chinese dashboard-session credential label should avoid API key wording")
require(L10n.t(.settingsTab, language: .simplifiedChinese) == "语言与外观", "Chinese language and appearance tab title should be available")
require(L10n.t(.provider, language: .simplifiedChinese) == "服务商", "Chinese provider form label should be fully translated")
require(L10n.t(.language, language: .simplifiedChinese) == "语言", "Chinese language label should be available")
require(L10n.t(.statusBarTransparency, language: .simplifiedChinese) == "状态栏透明度", "Chinese status bar transparency label should be available")
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

swiftc QuotaBar/Models/AppLanguage.swift QuotaBar/Models/APIKey.swift "$TMP_DIR/main.swift" -o "$TMP_DIR/language-test"
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
SWIFT

swiftc QuotaBar/Models/AppLanguage.swift QuotaBar/Models/APIKey.swift QuotaBar/Services/DashboardReauth.swift "$TMP_DIR/main.swift" -o "$TMP_DIR/dashboard-reauth-test"
"$TMP_DIR/dashboard-reauth-test"

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

let defaults = UserDefaults(suiteName: "QuotaBarBehaviorTests.\(UUID().uuidString)")!
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

swiftc QuotaBar/Models/AppLanguage.swift QuotaBar/Models/APIKey.swift QuotaBar/Services/FileSecretStore.swift QuotaBar/Services/APIKeyStore.swift "$TMP_DIR/main.swift" -o "$TMP_DIR/secret-store-test"
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

swiftc QuotaBar/Models/AppLanguage.swift QuotaBar/Models/APIKey.swift QuotaBar/Services/QuotaService.swift "$TMP_DIR/main.swift" -o "$TMP_DIR/quota-parser-test"
"$TMP_DIR/quota-parser-test"

echo "== SwiftPM build =="
swift build

echo "== App bundle build =="
./install.sh --bundle-only --rebuild
test -x "build/QuotaBar.app/Contents/MacOS/QuotaBar" || fail "app bundle executable is missing"
test -f "build/QuotaBar.app/Contents/Resources/QuotaBar.icns" || fail "app bundle icon is missing"
plutil -extract CFBundleExecutable raw "build/QuotaBar.app/Contents/Info.plist" | rg '^QuotaBar$' >/dev/null || fail "bundle executable name is wrong"
plutil -extract CFBundleIconFile raw "build/QuotaBar.app/Contents/Info.plist" | rg '^QuotaBar$' >/dev/null || fail "bundle icon name is wrong"
codesign --verify --deep --strict --verbose=2 "build/QuotaBar.app" >/dev/null

echo "All behavior tests passed"
