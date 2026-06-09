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
assert_match '0\.3\.0' \
  "QuotaRadar/Info.plist" \
  "Quota Radar 0.3.0 should be recorded in Info.plist"
assert_no_match 'LSUIElement' \
  "QuotaRadar/Info.plist" \
  "QuotaRadar must appear in the macOS Dock after launch"
assert_match 'struct QuotaRadarMark' \
  "QuotaRadar/Views/Components.swift" \
  "Main app should expose a shared quota-radar mark that matches the new Dock and menu bar icon direction"
assert_match 'Image\(nsImage: NSApp\.applicationIconImage\)' \
  "QuotaRadar/Views/Components.swift" \
  "Main app interface should reuse the actual app icon asset instead of drawing a separate visual variant"
assert_no_match 'badgeSystemImage' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main app header icons should not add page-specific badges that make the brand mark inconsistent"
assert_match 'QuotaRadarMark\(size: 42' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main app sidebar should use the shared quota-radar mark instead of a generic text-only brand"
assert_no_match 'QuotaRadarMark\(size: 36' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main app inner page headers should not repeat the app icon; the sidebar brand mark is enough"
assert_match 'QuotaRadarMark\(size: 76' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main app About page should use the same quota-radar mark as the app icon"
assert_match 'drawStatusIconInnerScreen' \
  "QuotaRadar/AppDelegate.swift" \
  "Menu bar icon should preserve the same outer tile, inner screen, and radar structure as the app icon"
assert_no_match '控制台会话 Cookie|控制台會話 Cookie|dashboard session cookies|dashboard-session Cookie|ダッシュボードセッション Cookie|대시보드 세션 Cookie' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "User-facing credential copy should avoid gray dashboard-session Cookie wording"
for icon_name in aliyun tencentCloud volcengine xfyun; do
  test -s "QuotaRadar/Assets.xcassets/ProviderIcons/${icon_name}.iconset/icon_32x32@2x.png" \
    || fail "shared official provider icon asset is missing: ${icon_name}"
done
for icon_name in claude codex; do
  test -s "QuotaRadar/Assets.xcassets/ProviderIcons/${icon_name}.iconset/icon_32x32@2x.png" \
    || fail "Claude/Codex provider icon asset is missing: ${icon_name}"
done
python3 - <<'PY'
from pathlib import Path
import sys

source = Path("QuotaRadar/Models/APIKey.swift").read_text()
required_fragments = {
    "Claude API and subscription providers should use a dedicated Claude icon instead of the Anthropic fallback":
        'case .claudeAPIUsage, .claudeSubscription:\n            return "ProviderIcons/claude"',
    "Codex API and subscription providers should use a dedicated Codex/OpenAI icon instead of OpenCode Go or SF Symbols":
        'case .codexAPIUsage, .codexSubscription:\n            return "ProviderIcons/codex"',
}

for message, fragment in required_fragments.items():
    if fragment not in source:
        print(f"FAIL: {message}", file=sys.stderr)
        sys.exit(1)
PY
assert_no_match 'case \.codexAPIUsage, \.codexSubscription: return Color\(hex: "10A37F"\)' \
  "QuotaRadar/Models/APIKey.swift" \
  "Codex provider tint should match the Codex icon style instead of using OpenAI green"
assert_match 'case \.codexAPIUsage, \.codexSubscription: return Color\(hex: "111827"\)' \
  "QuotaRadar/Models/APIKey.swift" \
  "Codex provider tint should use the same deep neutral tone as the Codex icon"
[[ -s docs/assets/screenshots/zh-Hans/quota-overview.png ]] || fail "Chinese README quota overview screenshot asset should exist"
[[ -s docs/assets/screenshots/zh-Hans/menu-bar-popover.png ]] || fail "Chinese README menu bar popover screenshot asset should exist"
[[ -s docs/assets/screenshots/en/quota-overview.png ]] || fail "English README quota overview screenshot asset should exist"
[[ -s docs/assets/screenshots/en/menu-bar-popover.png ]] || fail "English README menu bar popover screenshot asset should exist"
assert_match 'docs/assets/screenshots/zh-Hans/quota-overview\.png' \
  "README.md" \
  "Chinese README should show the Simplified Chinese quota overview screenshot"
assert_match 'docs/assets/screenshots/zh-Hans/menu-bar-popover\.png' \
  "README.md" \
  "Chinese README should show the Simplified Chinese menu bar popover screenshot"
assert_match '真实运行画面，密钥由应用自动打码' \
  "README.md" \
  "Chinese README should clarify that public screenshots use masked real app captures"
assert_no_match 'docs/assets/screenshots/en/' \
  "README.md" \
  "Chinese README should not link to English screenshots"
assert_match 'docs/assets/screenshots/en/quota-overview\.png' \
  "README.en.md" \
  "English README should show the English quota overview screenshot"
assert_match 'docs/assets/screenshots/en/menu-bar-popover\.png' \
  "README.en.md" \
  "English README should show the English menu bar popover screenshot"
assert_match 'captured from the running app, with credentials masked by Quota Radar' \
  "README.en.md" \
  "English README should clarify that public screenshots use masked real app captures"
assert_no_match 'docs/assets/screenshots/zh-Hans/' \
  "README.en.md" \
  "English README should not link to Simplified Chinese screenshots"
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
assert_match 'case aliyunCodingPlan = "Aliyun Coding Plan"' \
  "QuotaRadar/Models/APIKey.swift" \
  "Aliyun Coding Plan provider should be modeled explicitly"
assert_match 'case aliyunTokenPlan = "Aliyun Token Plan"' \
  "QuotaRadar/Models/APIKey.swift" \
  "Aliyun Token Plan provider should be modeled explicitly"
assert_match 'case tencentCloudCodingPlan = "Tencent Cloud Coding Plan"' \
  "QuotaRadar/Models/APIKey.swift" \
  "Tencent Cloud Coding Plan provider should be modeled explicitly"
assert_match 'case tencentCloudTokenPlan = "Tencent Cloud Token Plan"' \
  "QuotaRadar/Models/APIKey.swift" \
  "Tencent Cloud Token Plan provider should be modeled explicitly"
assert_match 'case xfyunTokenPlan = "XFYun Spark Token Plan"' \
  "QuotaRadar/Models/APIKey.swift" \
  "XFYun Spark Token Plan provider should be modeled explicitly"
assert_match 'case volcengineTokenPlan = "Volcengine Token Plan"' \
  "QuotaRadar/Models/APIKey.swift" \
  "Volcengine Token Plan provider should be modeled explicitly"
assert_match 'struct ProviderCapability' \
  "QuotaRadar/Models/APIKey.swift" \
  "Provider capability metadata should be centralized"
assert_match 'enum CredentialKind' \
  "QuotaRadar/Models/APIKey.swift" \
  "Provider capability metadata should distinguish credential types"
assert_match 'var capability: ProviderCapability' \
  "QuotaRadar/Models/APIKey.swift" \
  "Each provider should expose capability metadata"
assert_match 'CredentialKind\.dashboardCookie' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential form should react to dashboard-cookie providers"
assert_match '\.adminCredential' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential form should react to admin credential providers"
assert_match 'CurlCredentialParser' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential form should support cURL paste import"
assert_match 'struct CurlCredentialParser' \
  "QuotaRadar/Services/CurlCredentialParser.swift" \
  "cURL credential parser service should exist"
assert_match 'static func parse\(' \
  "QuotaRadar/Services/CurlCredentialParser.swift" \
  "cURL credential parser should expose a parse entry point"
assert_match 'provider-capabilities\.md' \
  "README.md" \
  "Chinese README should link provider capability matrix"
assert_match 'provider-capabilities\.en\.md' \
  "README.en.md" \
  "English README should link provider capability matrix"
assert_match '已验证接入: .*腾讯云 coding plan' \
  "TODO.md" \
  "Chinese roadmap should classify Tencent Cloud Coding Plan as a verified integration"
assert_match 'Verified integrations: .*Tencent Cloud Coding Plan' \
  "TODO.en.md" \
  "English roadmap should classify Tencent Cloud Coding Plan as a verified integration"
assert_match '阿里云 coding plan' \
  "docs/provider-capabilities.md" \
  "Chinese provider capability matrix should document Aliyun Coding Plan with localized provider copy"
assert_match 'Tencent Cloud Token Plan' \
  "docs/provider-capabilities.en.md" \
  "English provider capability matrix should document Tencent Cloud Token Plan"
assert_match 'Coding plan 计量口径' \
  "docs/provider-capabilities.md" \
  "Chinese provider capability matrix should document how Coding Plan quotas are measured"
assert_match 'Token plan 计量口径' \
  "docs/provider-capabilities.md" \
  "Chinese provider capability matrix should document how Token Plan quotas are measured"
assert_match 'Token Plan Measurement' \
  "docs/provider-capabilities.en.md" \
  "English provider capability matrix should document Token Plan measurement semantics"
assert_match '腾讯云 Token plan.*token' \
  "docs/provider-capabilities.md" \
  "Chinese provider capability matrix should state the current Tencent Cloud Token Plan unit"
assert_match '阿里云 Token plan.*积分' \
  "docs/provider-capabilities.md" \
  "Chinese provider capability matrix should state the expected Aliyun Token Plan unit"
assert_no_match '\["LLM", "AI Search"\]' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential configuration must not show LLM before AI Search"
assert_no_match 'ForEach\(Provider\.allCases\)' \
  "QuotaRadar/Views" \
  "Visible provider pickers should not render every Codable provider case"
assert_no_match 'Text\(.*(stat\.)?provider\.rawValue|Label\(.*rawValue|provider\.rawValue\) \(L10n\.t' \
  "QuotaRadar/Views" \
  "Visible provider labels should use localized display names instead of raw persistence values"
assert_match 'return \.claudeAPIUsage' \
  "QuotaRadar/Services/EnvImporter.swift" \
  "Claude API usage keys should be imported as a supported provider"
assert_match '\| Claude \|' \
  "README.md" \
  "Chinese README should list Claude as a currently supported provider"
assert_match '\| Claude \|' \
  "README.en.md" \
  "English README should list Claude as a currently supported provider"
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
assert_match 'api\.anthropic\.com' \
  "QuotaRadar/Info.plist" \
  "Anthropic API domains should be whitelisted for Claude API usage"
assert_match '简体中文' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "The language picker should expose Simplified Chinese as a user-facing option"
assert_match 'applicationShouldHandleReopen' \
  "QuotaRadar/AppDelegate.swift" \
  "Dock icon clicks should reopen a visible QuotaRadar window instead of doing nothing"
assert_match 'bringExistingSettingsWindowToFront' \
  "QuotaRadar/AppDelegate.swift" \
  "Dock icon clicks with a visible settings window should preserve the current page and any Add Credential sheet"
assert_match 'if flag, let settingsWindow, settingsWindow\.isVisible' \
  "QuotaRadar/AppDelegate.swift" \
  "Dock reopen handling should not reset SettingsNavigationStore when a visible settings window already exists"
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
assert_match 'restoreOrRepairSettingsWindowPlacement' \
  "QuotaRadar/AppDelegate.swift" \
  "QuotaRadar should restore or repair the managed settings window after it is shown without forcing it to another display"
assert_match 'settingsWindowFrameIsUsable' \
  "QuotaRadar/AppDelegate.swift" \
  "Settings window placement should preserve an on-screen frame on any active display"
assert_no_match 'forceSettingsWindowOntoPreferredScreen' \
  "QuotaRadar/AppDelegate.swift" \
  "Settings window placement must not force the window back to a preferred screen on every activation"
assert_match 'scheduleSettingsWindowPlacementRecovery' \
  "QuotaRadar/AppDelegate.swift" \
  "Settings window placement should be re-applied after launch restoration races"
assert_match 'saveSettingsWindowFrame' \
  "QuotaRadar/AppDelegate.swift" \
  "Settings window placement should remember the user's last manually chosen frame"
assert_match 'windowDidMove' \
  "QuotaRadar/AppDelegate.swift" \
  "Settings window movement should update the remembered frame"
assert_match 'windowDidEndLiveResize' \
  "QuotaRadar/AppDelegate.swift" \
  "Settings window resize should update the remembered frame"
assert_match 'applicationDidBecomeActive' \
  "QuotaRadar/AppDelegate.swift" \
  "Settings window placement should be recovered when QuotaRadar becomes active again"
assert_match 'windowDidBecomeKey' \
  "QuotaRadar/AppDelegate.swift" \
  "Settings window placement should be recovered when the settings window becomes key"
assert_match 'NSEvent\.mouseLocation' \
  "QuotaRadar/AppDelegate.swift" \
  "Settings window repair should prefer the display where the current interaction happened"
assert_no_match 'screen\.frame\.minX == 0 && screen\.frame\.minY == 0' \
  "QuotaRadar/AppDelegate.swift" \
  "Settings window placement must not always prefer the physical primary display in multi-screen setups"
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
assert_match 'https://chatgpt\.com/api/auth/session' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Codex subscription should first resolve the ChatGPT session access token before calling usage"
assert_match 'Bearer .*accessToken.*forHTTPHeaderField: "Authorization"' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Codex subscription usage requests should authenticate with the ChatGPT session Bearer token"
assert_no_match 'diagnosticMessage: "Querit account endpoint returned monthly request quota\."' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Querit refresh should not overwrite the parser's usage-only unknown-limit diagnostic"
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
  "Status bar surface must not use NSPopover because its arrow and automatic offset do not match the intended floating panel"
assert_match 'NSPanel' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar surface should use an arrowless floating panel with precise menu-bar placement"
assert_match '\.nonactivatingPanel' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should not activate the main app when opened from the menu bar"
assert_match 'setupStatusPanel' \
  "QuotaRadar/AppDelegate.swift" \
  "AppDelegate should configure a dedicated status-bar panel for the glass surface"
assert_match 'containerView\.addSubview\(hostingController\.view\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should host the shared SwiftUI menu content inside the AppKit container"
assert_match 'statusPanelOuterPadding' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should reserve transparent outer padding so the glass surface is not clipped by the NSPanel bounds"
assert_match 'statusPanelSize' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should size the AppKit window separately from the visible SwiftUI glass surface"
assert_match 'panel\.setContentSize\(statusPanelSize\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel must use a padded AppKit window size so the visible glass surface is not clipped"
assert_match 'statusPanelContentFrame' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should inset the SwiftUI surface inside the transparent AppKit container"
assert_no_match 'popover\.show|preferredEdge: \.minY' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar surface should not use NSPopover arrow anchoring"
assert_match 'statusPanelGap' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should keep a small native gap below the menu bar item"
assert_match 'frameForStatusPanel\(relativeTo: button\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should compute an explicit arrowless frame relative to the status item"
assert_match 'screenContainingStatusButton\(buttonFrame\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should choose the display from the clicked menu-bar button frame so multi-screen popovers stay near the icon"
assert_match 'NSScreen\.screens' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should inspect all screens when mapping a menu-bar button to its display"
assert_no_match 'let screen = button\.window\?\.screen \?\? NSScreen\.main' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel must not rely on the status item's window screen because it can be wrong on secondary displays"
assert_no_match 'statusPopoverAnchorRect|rect\.origin\.y -= statusPopoverAnchorOffset' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should remove the old popover anchor calculations"
assert_match 'buttonFrame\.midX - MenuContentView\.menuSize\.width / 2' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should align horizontally to the menu-bar icon instead of drifting away"
assert_match 'showStatusPanel\(relativeTo: button\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar clicks should show the arrowless status panel"
assert_match 'buttonFrame\.minY - statusPanelGap - MenuContentView\.menuSize\.height - statusPanelOuterPadding' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar visible glass surface should sit close below the real menu-bar button instead of adding the transparent padding to the visual gap"
assert_match 'visibleFrame\.maxY - statusPanelScreenInset - MenuContentView\.menuSize\.height - statusPanelOuterPadding' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar visible glass surface should clamp below the menu bar while allowing transparent outer padding above it"
assert_match 'visibleFrame\.minY \+ statusPanelScreenInset - statusPanelOuterPadding' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should clamp the visible glass surface to the screen bottom, not the transparent AppKit padding"
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
assert_match 'private let providerOverviewMaxHeight: CGFloat' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar provider overview should have a fixed height budget so many providers cannot overflow the popover"
assert_match 'MenuBoundedScrollRegion' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar provider overview should scroll inside its own compact region instead of growing the full popover"
assert_match '\.frame\(maxHeight: providerOverviewMaxHeight' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar provider overview scroll region should enforce the provider height budget"
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
  "Status bar popover should use a compact metric strip"
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
assert_match 'statusPanelSize' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar hosting window must be larger than MenuContentView.menuSize to avoid clipping"
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
assert_match 'button\.contentTintColor = nil' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar item should not tint the real white cutout glyph as a template icon"
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
assert_match 'struct MenuBoundedScrollRegion<Content: View>' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar body should keep the popover fixed while only overflowing provider grids scroll inside a bounded region"
assert_match 'contentHorizontalInset' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar home view should reserve an explicit horizontal inset to avoid left-edge clipping"
assert_match 'contentTopSafeInset' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar summary popover should reserve top breathing room below the menu bar"
content_top_safe_inset="$(awk -F'= ' '/contentTopSafeInset: CGFloat =/ { gsub(/[^0-9.]/, "", $2); print $2; exit }' QuotaRadar/Views/MenuContentView.swift)"
if [[ -z "$content_top_safe_inset" ]]; then
  fail "Status bar summary popover should keep contentTopSafeInset as a numeric constant"
fi
if awk "BEGIN { exit !($content_top_safe_inset >= 16 && $content_top_safe_inset <= 22) }"; then
  :
else
  fail "Status bar summary popover top inset should be 16-22pt so the compact header is not clipped"
fi
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
assert_match 'struct CredentialEditorShell' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Add and edit credential sheets should share a polished compact editor shell instead of diverging into a plain Form"
assert_no_match 'struct EditKeySheet: View[[:space:][:print:]]*Form \{' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Edit Credential should not keep the old generic Form layout"
assert_match '@State private var provider: Provider' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Edit Credential should allow changing the provider of an existing credential"
assert_match 'AddCredentialProviderList\(provider: \$provider\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Edit Credential should reuse the provider picker so existing credentials can move providers"
assert_match 'companionAPIKeyCredentialForCurrentProvider' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Edit Credential should expose the saved companion API key for web-login providers such as XFYun and Volcengine Coding Plan"
assert_match 'saveCompanionAPIKeyIfNeeded' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Saving an edited web-login credential should add or update its companion API key record"
assert_match 'CredentialSecretInput' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential editors should use a reusable secret input with reveal support instead of hard-wired SecureField/TextField choices"
assert_match 'showCredentialValue' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Cookie credentials should be hidden by default but revealable in the editor"
assert_no_match 'Text\(updated, style: \.relative\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Edit Credential should render last-updated timestamps through localized app formatting instead of system English relative text"
assert_match 'L10n\.shortDateTime\(updated\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Edit Credential should use localized app date formatting for last updated"
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
assert_match 'timingText\(key\.visibleQuotaResetSummary' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings API key rows should show visible quota reset timing separately from package expiry"
assert_match 'key\.planEndSummary' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings API key rows should show package expiry as a separate weak detail"
assert_match 'ProviderQuotaTimingColumn\.width' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings API key timing column should use one shared width for header and rows"
assert_no_match 'frame\(width: 124, alignment: \.trailing\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings API key timing column must not keep the old narrow last-updated width"
assert_match 'ProviderQuotaTimingColumn\(key: key, updatedText: updatedText\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings API key rows should render update, reset, and plan-expiry timing through a dedicated column"
assert_match 'minimumScaleFactor\(0\.62\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings API key timing text should scale enough to avoid clipping localized reset and expiry strings"
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
assert_match 'presentation\.planEndText' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar top item rows must keep package expiry separate from reset timing"
assert_match 'QuotaWindowDetails' \
  "QuotaRadar/Views/Components.swift" \
  "Multi-window quota providers should render cycle details through one shared compact component"
assert_match 'quotaWindowDetails' \
  "QuotaRadar/Models/APIKey.swift" \
  "API keys should expose structured quota-window details instead of only one resetAt"
assert_match 'var resetSummary: String' \
  "QuotaRadar/Models/APIKey.swift" \
  "Quota reset timing should be shared by all key row views"
assert_match 'var quotaResetSummary: String' \
  "QuotaRadar/Models/APIKey.swift" \
  "Quota reset timing should not fall back to package expiry"
assert_match 'var visibleQuotaResetSummary: String' \
  "QuotaRadar/Models/APIKey.swift" \
  "Quota reset timing placeholders should stay out of compact UI rows"
assert_match 'var planEndSummary: String' \
  "QuotaRadar/Models/APIKey.swift" \
  "Package expiry should have its own presentation text"
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
assert_match 'ProviderPickerRow' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential provider selector should render official provider icons instead of SF Symbol placeholders"
assert_match 'ProviderIcon\(provider: provider, size: 22, style: \.compactBadge\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential provider selector should use fixed-size provider badges so provider icons do not look identical or uneven"
assert_match 'case \.aliyunCodingPlan, \.aliyunTokenPlan:' \
  "QuotaRadar/Models/APIKey.swift" \
  "Aliyun plan variants should share the official Aliyun provider icon"
assert_match 'case \.tencentCloudCodingPlan, \.tencentCloudTokenPlan:' \
  "QuotaRadar/Models/APIKey.swift" \
  "Tencent Cloud plan variants should share the official Tencent Cloud provider icon"
assert_match 'ScrollViewReader' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential provider selector should keep the selected provider visible when switching between categories"
assert_match 'proxy\.scrollTo\(newValue, anchor: \.center\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential provider selector should scroll the selected provider into view"
assert_no_match 'Label\(p\.displayName\(\), systemImage: p\.icon\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential provider selector must not use provider SF Symbol fallbacks"
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
assert_match 'let currentLanguage = languageStore\.language' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings window should explicitly depend on AppLanguageStore so every page repaints immediately after language changes"
assert_match '\.id\(currentLanguage\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings window should rebuild localized labels immediately when the selected language changes"
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
assert_match 'SettingsFormSection' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings should use compact grouped preference sections instead of stacked full-width cards"
assert_match 'SettingsPreferenceRow' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings should use compact preference rows with right-aligned controls"
assert_match 'Picker\("", selection: \$appearanceStore\.autoRefreshInterval' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Automatic refresh picker should hide the long label from the control row"
assert_match 'Picker\("", selection: \$appearanceStore\.quotaConsumingAutoRefreshInterval' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota-consuming refresh picker should hide the long label from the control row"
assert_match '\.frame\(width: 170\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings picker controls should use a fixed compact width"
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
assert_match 'lastAutoFilledCredentialName' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Add Credential should track generated credential names so switching providers does not keep TAVILY_API_KEY"
assert_match 'syncDefaultCredentialName\(for: newProvider, replacing: oldProvider\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Add Credential should update default credential names when the provider changes"
assert_match 'nameForSaving = trimmedName\.isEmpty \? provider\.defaultCredentialName : trimmedName' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Add Credential should save provider-specific default credential names instead of generic provider labels"
assert_match 'AddCredentialProviderList' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Add Credential should use a compact two-pane provider list instead of a crowded one-column form"
assert_match 'AddCredentialDetailPane' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Add Credential should keep credential fields in a focused detail pane"
assert_no_match 'ProviderSelectionMenu' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Add Credential should not use the old menu picker that made long provider names and fields feel cramped"
assert_no_match '\.frame\(width: 500\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Add Credential sheet must not keep the old narrow fixed width"
assert_match '\.frame\(width: 760, height: 540\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Add Credential sheet should use a stable compact monitoring-panel size"
assert_match 'Text\(key\.managementDisplayName\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential rows should use compact display names for legacy business invocation keys"
assert_match 'key\.displayNote' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential rows should localize persisted import-source notes instead of showing stale English"
assert_match 'key\.managementCredentialTypeBadgeText' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential rows should hide duplicate credential-type badges when the display name already names the type"
assert_match 'key\.managementCredentialValueText' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential rows should not show generated PROVIDER_API_KEY-style names under each provider"
assert_match 'copyCredentialToPasteboard' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential rows should expose a one-click copy action for the full saved credential"
assert_match 'key\.copyableCredentialValue' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential rows should only expose copying for user-facing API keys, not dashboard login authorizations"
assert_no_match 'setString\(key\.key' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential copy must not blindly copy raw stored secrets such as dashboard cookies"
assert_match 'NSPasteboard\.general' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential copy should use the macOS system pasteboard"
assert_match 'Image\(systemName: "doc\.on\.doc"\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential rows should use the standard copy icon instead of text-heavy buttons"
assert_match 'L10n\.t\(\.copyCredential\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential copy button tooltip should be localized"
assert_match 'case copyCredential' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Credential copy button should have a localization key"
assert_match 'supportsCompanionAPIKeyStorage' \
  "QuotaRadar/Models/APIKey.swift" \
  "Dashboard quota providers should declare whether a separate user-facing API key can be stored for copying"
assert_match 'copyableAPIKeyCredentialName' \
  "QuotaRadar/Models/APIKey.swift" \
  "Providers that use dashboard quota authorization should expose a stable default API-key storage name"
assert_match 'companionAPIKey' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Add Credential should let users store a user-facing API key together with dashboard quota authorization when useful"
assert_match 'key\.isStoredAPIKeyOnlyCredential' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Quota refresh should skip API-key-only records that are stored for copying but cannot query quota"
assert_match 'L10n\.t\(\.apiKeysTab' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings tab labels should use localized strings"
assert_match 'L10n\.t\(\.apiQuotaTitle' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar title should use localized strings"
assert_match 'window\.title = L10n\.t\(\.settingsWindowTitle\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Main settings window title should be localized instead of hardcoded English"
assert_no_match 'Quota Radar Settings' \
  "QuotaRadar/AppDelegate.swift" \
  "Main settings window title should not be hardcoded in English"
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
assert_match 'OAuthPopupWindow' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should open OAuth providers such as Querit Google login in a real popup window"
assert_match 'init\(contentView: NSView\)' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "OAuth popup windows should own their WKWebView content directly instead of replacing an empty content view controller"
assert_match 'isReleasedWhenClosed = false' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "OAuth popup windows should not be released by AppKit while the coordinator still manages their lifecycle"
assert_match 'animationBehavior = \.none' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "OAuth popup windows should disable AppKit transform animations that have crashed during provider reauthentication"
assert_no_match 'contentViewController' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "OAuth popup windows must not mix a placeholder contentViewController with a replaced WKWebView contentView"
assert_no_match 'popupWindow\.contentView = popupWebView' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "OAuth popup windows should install the WKWebView in the window initializer, not by replacing contentView after construction"
assert_match 'webViewDidClose' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should close OAuth popup windows when the provider closes them"
assert_match 'guard let popupWindow = oauthPopupWindows\.removeValue\(forKey: key\) else \{ return \}' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "OAuth popup close should remove the coordinator-owned window before touching AppKit window state to avoid reentrant close handling"
assert_match 'webView\.navigationDelegate = nil' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "OAuth popup close should detach the WKWebView navigation delegate before releasing the popup"
assert_match 'webView\.uiDelegate = nil' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "OAuth popup close should detach the WKWebView UI delegate before releasing the popup"
assert_match 'popupWindow\.orderOut\(nil\)' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "OAuth popup close should hide the popup without AppKit's close animation lifecycle"
assert_no_match 'oauthPopupWindows\[key\]\?\.close\(\)' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "OAuth popup close must not call close through the dictionary before removing the managed window"
assert_no_match 'webView\.load\(URLRequest\(url: popupURL\)\)' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication must not flatten Google OAuth popups into the dashboard WebView"
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
assert_match 'persistCookies\(cookieHeader, allowEmptyStatus: false, dismissAfterSave: false\)' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Automatic dashboard cookie capture should save in place instead of closing the WebView like a crash"
assert_match 'persistCookies\(cookieHeader, allowEmptyStatus: true, dismissAfterSave: true\)' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Manual dashboard cookie save can close the reauthentication WebView after validation"
assert_match 'try await QuotaService\(\)\.checkQuota\(for: candidateKey, bypassCooldown: true\)' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should call the provider quota endpoint before accepting captured cookies"
assert_match 'guard provider\.supportsQuotaQuery else' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should save captured cookies directly for dashboard providers whose quota endpoint is not implemented yet"
assert_match 'updatedKey\.isBusinessInvocationCredential' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should rename legacy API-key business credentials to the provider cookie credential name"
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
assert_match 'if provider\.supportsDashboardReauthentication' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Add Credential should expose provider-level dashboard reauthentication before a cookie credential exists"
assert_match 'DashboardReauthSheet\(monitor: monitor, provider: provider, key: nil\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Add Credential reauthentication should create or update provider cookie credentials through the same flow as Volcengine"
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
assert_match 'officialColorProviderIcon' \
  "QuotaRadar/Views/Components.swift" \
  "ProviderIcon should preserve provider-owned brand colors for Claude and other color-sensitive marks"
assert_match 'drawQuotaRadar' \
  "scripts/generate_app_icon.swift" \
  "The app icon generator should use the approved quota-radar icon"
assert_match 'drawRadarPulseArc' \
  "scripts/generate_app_icon.swift" \
  "The app icon generator should render radar arcs instead of a battery terminal"
assert_match 'drawMonitorTileBackground' \
  "scripts/generate_app_icon.swift" \
  "The app icon generator should use a crisp monitor-style tile background"
assert_no_match 'topGlow|drawGlassPanel' \
  "scripts/generate_app_icon.swift" \
  "The app icon generator should remove the old blurred glass glow treatment"
assert_no_match 'drawQuotaCell|drawQuotaCellFill|drawQuotaCellSegments|drawProviderDots|keyRingCenter|battery|capPath' \
  "scripts/generate_app_icon.swift" \
  "The app icon generator should remove battery-cell decorations that can be confused with power status"
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
  "Exa quota checks should authenticate with the service API key"
assert_match 'parseExaUsage' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Exa usage responses should be parsed from Team Management billing data"
assert_match 'Exa Admin API requires a service key' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Exa search API keys should explain that usage requires the service API key"
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
assert_match 'drawQuotaRadarStatusGlyph' \
  "QuotaRadar/AppDelegate.swift" \
  "The status bar icon should use a compact quota-radar glyph"
assert_match 'drawRadarPulseArc' \
  "QuotaRadar/AppDelegate.swift" \
  "The status bar icon should include a radar arc so it is distinguishable from the macOS battery icon"
assert_no_match 'drawStatusBatteryTerminal' \
  "QuotaRadar/AppDelegate.swift" \
  "The status bar icon must not draw a battery terminal that can be confused with the macOS battery icon"
assert_match 'makeStatusBarIcon' \
  "QuotaRadar/AppDelegate.swift" \
  "The status bar icon should be a purpose-built quota icon"
assert_match 'icon\.isTemplate = true' \
  "QuotaRadar/AppDelegate.swift" \
  "The menu bar icon should use a macOS template mask so it follows the active menu bar appearance"
assert_no_match 'icon\.isTemplate = false' \
  "QuotaRadar/AppDelegate.swift" \
  "The menu bar icon must not hard-code a fixed white/black rendered image"
assert_no_match 'NSColor\.white\.setFill' \
  "QuotaRadar/AppDelegate.swift" \
  "The menu bar icon should not hard-code a white base that clashes on light menu bars"
assert_no_match 'white quota-radar icon' \
  "install.sh" \
  "Install output should not describe the menu bar icon as fixed white"
assert_match 'compositingOperation = \.clear' \
  "QuotaRadar/AppDelegate.swift" \
  "The menu bar icon radar arcs and pointer should be cut out from the template mask"
assert_no_match 'battery\.75percent' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "The menu bar popover header should not use the macOS-style battery symbol"
assert_no_match 'dot\.radiowaves\.left\.and\.right' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "The menu bar popover header should not use a separate SF Symbol when the app icon is the shared brand mark"
assert_match 'QuotaRadarMark\(size: 22' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "The menu bar popover header should use the same app icon mark as the main app"
assert_no_match 'heights = \[0\.18, 0\.31, 0\.44\]' \
  "scripts/generate_app_icon.swift" \
  "The Dock app icon must not use the old three-bar chart glyph"
assert_match 'drawQuotaRadar' \
  "scripts/generate_app_icon.swift" \
  "The Dock app icon generator should use the approved quota-radar metaphor"
assert_match 'drawRadarSweep' \
  "scripts/generate_app_icon.swift" \
  "The Dock app icon should include a clear radar sweep"
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
assert_no_match 'Bundle\.module' \
  "QuotaRadar/Views/Components.swift" \
  "Provider icon loading should not use SwiftPM's fatal Bundle.module accessor in packaged app bundles"
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
    "aliyunCodingPlan", "aliyunTokenPlan",
    "anysearch", "bocha", "brave", "claude", "codex", "deepseek", "exa",
    "querit", "serpapi", "serper", "tavily",
    "tencentCloudCodingPlan", "tencentCloudTokenPlan",
    "volcengineCodingPlan", "volcengineTokenPlan",
    "wxmp",
    "xfyunCodingPlan", "xfyunTokenPlan",
}
expected_asset_names = {
    "aliyunCodingPlan": "aliyun",
    "aliyunTokenPlan": "aliyun",
    "tencentCloudCodingPlan": "tencentCloud",
    "tencentCloudTokenPlan": "tencentCloud",
    "volcengineCodingPlan": "volcengine",
    "volcengineTokenPlan": "volcengine",
    "xfyunCodingPlan": "xfyun",
    "xfyunTokenPlan": "xfyun",
}
legacy_placeholder_colors = {
    "aliyunCodingPlan": (255, 106, 0),
    "aliyunTokenPlan": (241, 90, 36),
    "anysearch": (156, 39, 176),
    "bocha": (0, 188, 212),
    "brave": (255, 127, 0),
    "claude": (212, 165, 116),
    "codex": (16, 163, 127),
    "deepseek": (77, 107, 250),
    "exa": (255, 105, 180),
    "querit": (63, 81, 181),
    "serpapi": (52, 168, 83),
    "serper": (3, 169, 244),
    "tavily": (66, 133, 244),
    "tencentCloudCodingPlan": (0, 110, 255),
    "tencentCloudTokenPlan": (0, 82, 217),
    "volcengineCodingPlan": (47, 107, 255),
    "volcengineTokenPlan": (21, 94, 239),
    "wxmp": (7, 193, 96),
    "xfyunCodingPlan": (226, 59, 59),
    "xfyunTokenPlan": (200, 30, 30),
}
expected_icon_average_colors = {
    "claude": (217, 119, 87),
}
legacy_placeholder_colors.update({
    "aliyun": legacy_placeholder_colors["aliyunCodingPlan"],
    "tencentCloud": legacy_placeholder_colors["tencentCloudCodingPlan"],
    "volcengine": legacy_placeholder_colors["volcengineCodingPlan"],
    "xfyun": legacy_placeholder_colors["xfyunCodingPlan"],
})

root = Path("QuotaRadar/Assets.xcassets/ProviderIcons")
expected |= set(expected_asset_names.values())
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
    if image.size != (64, 64):
        print(f"FAIL: {name} provider icon 2x asset should be 64x64, got {image.size}", file=sys.stderr)
        sys.exit(1)
    for sibling, expected_size in [
        ("icon_32x32.png", (32, 32)),
        ("icon_16x16@2x.png", (32, 32)),
    ]:
        sibling_path = root / f"{name}.iconset" / sibling
        if not sibling_path.exists():
            print(f"FAIL: {name} provider icon is missing {sibling}", file=sys.stderr)
            sys.exit(1)
        sibling_image = Image.open(sibling_path)
        if sibling_image.size != expected_size:
            print(f"FAIL: {name} {sibling} should be {expected_size}, got {sibling_image.size}", file=sys.stderr)
            sys.exit(1)
    opaque_pixels = [pixel for pixel in image.getdata() if pixel[3] > 16]
    if not opaque_pixels:
        print(f"FAIL: {name} provider icon has no visible pixels", file=sys.stderr)
        sys.exit(1)
    rgb_values = {pixel[:3] for pixel in opaque_pixels}
    if rgb_values == {legacy_placeholder_colors[name]}:
        print(f"FAIL: {name} provider icon still uses the legacy one-color placeholder", file=sys.stderr)
        sys.exit(1)
    if name in expected_icon_average_colors:
        core_pixels = [pixel for pixel in opaque_pixels if pixel[3] > 128]
        average_rgb = tuple(round(sum(pixel[index] for pixel in core_pixels) / len(core_pixels)) for index in range(3))
        expected_rgb = expected_icon_average_colors[name]
        if any(abs(average_rgb[index] - expected_rgb[index]) > 8 for index in range(3)):
            print(
                f"FAIL: {name} provider icon should use its official brand color near "
                f"{expected_rgb}, got average {average_rgb}",
                file=sys.stderr
            )
            sys.exit(1)

shared_icon_groups = [
    ["aliyunCodingPlan", "aliyunTokenPlan", "aliyun"],
    ["tencentCloudCodingPlan", "tencentCloudTokenPlan", "tencentCloud"],
    ["volcengineCodingPlan", "volcengineTokenPlan", "volcengine"],
    ["xfyunCodingPlan", "xfyunTokenPlan", "xfyun"],
]

for group in shared_icon_groups:
    digests = []
    for name in group:
        path = root / f"{name}.iconset" / "icon_32x32@2x.png"
        digests.append(path.read_bytes())
    if len({bytes_value for bytes_value in digests}) != 1:
        print(f"FAIL: provider plan icons in {group} should share the official provider logo", file=sys.stderr)
        sys.exit(1)

distinct_icon_groups = [
    ["tavily", "serpapi", "exa"],
    ["aliyun", "tencentCloud", "volcengine", "xfyun"],
    ["claude", "codex", "anthropic"],
]

for group in distinct_icon_groups:
    digests = []
    for name in group:
        path = root / f"{name}.iconset" / "icon_32x32@2x.png"
        digests.append(path.read_bytes())
    if len({bytes_value for bytes_value in digests}) != len(group):
        print(f"FAIL: provider icons in {group} should be visually distinct assets", file=sys.stderr)
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
XFYUN_TOKEN_PLAN_API_KEY='fake-xfyun-token-plan-api-key'
VOLCENGINE_CODING_PLAN_COOKIE='fake-volcengine-cookie-value'
VOLCENGINE_TOKEN_PLAN_CREDENTIAL='{"accessKeyId":"<ak>","secretAccessKey":"<sk>","region":"cn-beijing"}'
OPENCODE_GO_COOKIE='auth=opencode-auth; oc_locale=zh'
EMPTY_KEY=xxx
QUOTED_BRAVE_KEY="brave-key"
SERPER_API_KEY=serper-key
WECHAT_API_KEY=wechat-key
QUERIT_API_KEY=querit-api-key
QUERIT_COOKIE='fake-querit-cookie-value'
ANTHROPIC_AUTH_TOKEN=token-not-api-key
ANTHROPIC_API_KEY=anthropic-key
OPENAI_API_KEY=openai-key
CODEX_SESSION_COOKIE='__Secure-next-auth.session-token=codex-session'
ALIYUN_CODING_PLAN_API_KEY=aliyun-coding-business-key
ALIYUN_TOKEN_PLAN_COOKIE=aliyun-token-cookie
TENCENT_CLOUD_CODING_PLAN_API_KEY=tencent-coding-business-key
TENCENT_CLOUD_TOKEN_PLAN_CREDENTIAL='{"secretId":"<secret-id>","secretKey":"<secret-key>","apiKeyId":"ak-tp-redacted","region":"ap-guangzhou"}'
"""

AppLanguageStore.shared.language = .english
let keys = EnvImporter.parseEnvContent(env)

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(1)
    }
}

require(keys.count == 12, "expected exactly twelve visible supported imported keys")
require(keys.contains { $0.name == "TAVILY_API_KEY" && $0.provider == .tavily && $0.key == "tvly-test-key" }, "missing Tavily key")
require(keys.contains { $0.name == "DEEPSEEK_API_KEY" && $0.provider == .deepseek && $0.key == "deepseek-test-key" }, "missing DeepSeek key")
require(keys.contains { $0.name == "XFYUN_CODING_PLAN_COOKIE" && $0.provider == .xfyunCodingPlan }, "missing XFYun Coding Plan cookie")
require(keys.contains { $0.name == "VOLCENGINE_CODING_PLAN_COOKIE" && $0.provider == .volcengineCodingPlan }, "missing Volcengine Coding Plan cookie")
require(keys.contains { $0.name == "OPENCODE_GO_COOKIE" && $0.provider == .opencodeGo }, "missing OpenCode Go cookie")
require(keys.contains { $0.name == "QUOTED_BRAVE_KEY" && $0.provider == .brave && $0.key == "brave-key" }, "missing quoted Brave key")
require(keys.contains { $0.name == "SERPER_API_KEY" && $0.provider == .serper && $0.key == "serper-key" }, "missing Serper key")
require(keys.contains { $0.name == "WECHAT_API_KEY" && $0.provider == .wxmp && $0.key == "wechat-key" }, "missing WeChat key")
require(keys.contains { $0.name == "QUERIT_COOKIE" && $0.provider == .querit && $0.key == "fake-querit-cookie-value" }, "missing Querit dashboard cookie")
require(keys.contains { $0.name == "QUERIT_API_KEY" && $0.provider == .querit && $0.key == "querit-api-key" }, "missing Querit optional API key")
require(!keys.contains { $0.name == "TENCENT_CLOUD_TOKEN_PLAN_CREDENTIAL" }, "Tencent Cloud Token Plan credentials should stay hidden from .env import until a real user key is available")
require(!keys.contains { $0.name == "ANTHROPIC_API_KEY" }, "Anthropic API keys should stay hidden until Claude API usage monitoring is configured")
require(!keys.contains { $0.name == "OPENAI_API_KEY" }, "OpenAI API keys should stay hidden until Codex API usage monitoring is configured")
require(!keys.contains { $0.provider == .xfyunTokenPlan }, "XFYun Token Plan should stay hidden until a quota endpoint is implemented")
require(!keys.contains { $0.provider == .volcengineTokenPlan }, "Volcengine Token Plan should stay hidden until a quota endpoint is implemented")
require(!keys.contains { $0.provider == .aliyunTokenPlan }, "Aliyun Token Plan should stay hidden until a quota endpoint is implemented")
require(keys.contains { $0.name == "ALIYUN_CODING_PLAN_API_KEY" && $0.provider == .aliyunCodingPlan && $0.key == "aliyun-coding-business-key" }, "Aliyun Coding Plan business API key should be importable for accounts that can verify dashboard quota access")
require(keys.contains { $0.name == "TENCENT_CLOUD_CODING_PLAN_API_KEY" && $0.provider == .tencentCloudCodingPlan && $0.key == "tencent-coding-business-key" }, "Tencent Cloud Coding Plan business API key should be importable for accounts that can verify dashboard quota access")
let importedQueritAPIKey = keys.first { $0.name == "QUERIT_API_KEY" }!
require(importedQueritAPIKey.isStoredAPIKeyOnlyCredential, "Querit API keys should import as copy-only API-key records, not dashboard cookies")
require(importedQueritAPIKey.copyableCredentialValue == "querit-api-key", "Querit optional API keys should be copyable")
require(!keys.contains { $0.name == "DEEPSEEK_WEB_SEARCH_PRO_API_KEY" }, "web-search-pro DeepSeek key must be ignored")
require(!keys.contains { $0.name == "ANTHROPIC_AUTH_TOKEN" }, "Anthropic auth token must not be imported as an API key")
require(!keys.contains { $0.name == "CODEX_SESSION_COOKIE" }, "Codex subscription cookies should be captured through web-login reauthentication instead of .env import")
require(!Provider.visibleCases.contains(.anthropic), "Legacy Anthropic provider should stay hidden in favor of Claude API/OAuth provider entries")
require(!Provider.visibleCases.contains(.claudeAPIUsage), "Claude API usage should stay hidden until the user has admin usage monitoring configured")
require(Provider.visibleCases.contains(.claudeSubscription), "Claude subscription should appear in provider pickers and visible app sections")
require(!Provider.visibleCases.contains(.codexAPIUsage), "Codex API usage should stay hidden until the user has admin usage monitoring configured")
require(Provider.visibleCases.contains(.codexSubscription), "Codex subscription should appear in provider pickers and visible app sections")
require(Provider.pendingQuotaIntegrationCases == [.xfyunTokenPlan, .volcengineTokenPlan, .aliyunTokenPlan, .tencentCloudTokenPlan], "Pending quota integration cases should include providers without confirmed user key evidence")
require(!Provider.visibleCases.contains(.xfyunTokenPlan), "XFYun Token Plan should not appear in visible provider lists yet")
require(!Provider.visibleCases.contains(.volcengineTokenPlan), "Volcengine Token Plan should not appear in visible provider lists yet")
require(!Provider.visibleCases.contains(.aliyunTokenPlan), "Aliyun Token Plan should not appear in visible provider lists yet")
require(Provider.visibleCases.contains(.aliyunCodingPlan), "Aliyun Coding Plan should be visible as a verification candidate when the user has a business key/account")
require(Provider.visibleCases.contains(.tencentCloudCodingPlan), "Tencent Cloud Coding Plan should be visible as a verification candidate when the user has a business key/account")
require(!Provider.visibleCases.contains(.tencentCloudTokenPlan), "Tencent Cloud Token Plan should stay hidden until the user has a real key to validate")

let masked = APIKey(name: "TAVILY_API_KEY", key: "abcd1234wxyz", provider: .tavily).maskedKey
require(masked == "abcd••••wxyz", "APIKey.maskedKey should expose the first four and last four characters")
let emptyMasked = APIKey(name: "EMPTY", key: "", provider: .tavily).maskedKey
require(emptyMasked == "No key value", "APIKey.maskedKey should label missing secrets")
require(Provider.brave.quotaCheckConsumesSearchQuota, "Brave quota checks use real search requests and must not run in automatic polling")
require(!Provider.tavily.quotaCheckConsumesSearchQuota, "Tavily usage endpoint should be safe for automatic polling")
require(Provider.xfyunCodingPlan.category == "LLM", "XFYun Coding Plan should be grouped as an LLM quota provider")
require(Provider.xfyunTokenPlan.category == "LLM", "XFYun Token Plan should be grouped as an LLM quota provider")
require(Provider.volcengineCodingPlan.category == "LLM", "Volcengine Coding Plan should be grouped as an LLM quota provider")
require(Provider.volcengineTokenPlan.category == "LLM", "Volcengine Token Plan should be grouped as an LLM quota provider")
require(Provider.opencodeGo.category == "LLM", "OpenCode Go should be grouped as an LLM quota provider")
require(Provider.aliyunCodingPlan.category == "LLM", "Aliyun Coding Plan should be grouped as an LLM quota provider")
require(Provider.aliyunTokenPlan.category == "LLM", "Aliyun Token Plan should be grouped as an LLM quota provider")
require(Provider.tencentCloudCodingPlan.category == "LLM", "Tencent Cloud Coding Plan should be grouped as an LLM quota provider")
require(Provider.tencentCloudTokenPlan.category == "LLM", "Tencent Cloud Token Plan should be grouped as an LLM quota provider")
require(Provider.claudeAPIUsage.category == "LLM", "Claude API usage should be grouped as an LLM quota provider")
require(Provider.codexSubscription.category == "LLM", "Codex subscription should be grouped as an LLM quota provider")
require(Provider.xfyunCodingPlan.providerFamilyDisplayName(language: .simplifiedChinese) == "讯飞星火", "XFYun Coding Plan should expose XFYun Spark as the first-level provider family")
require(Provider.xfyunCodingPlan.planTypeDisplayName(language: .simplifiedChinese) == "coding plan", "XFYun Coding Plan should expose coding plan as the second-level plan name")
require(Provider.xfyunTokenPlan.planTypeDisplayName(language: .simplifiedChinese) == "Token plan", "XFYun Token Plan should expose Token plan as the second-level plan name")
require(Provider.volcengineCodingPlan.providerFamilyDisplayName(language: .simplifiedChinese) == "火山引擎", "Volcengine Coding Plan should expose Volcengine as the first-level provider family")
require(Provider.aliyunCodingPlan.providerFamilyDisplayName(language: .simplifiedChinese) == "阿里云", "Aliyun Coding Plan should expose Aliyun as the first-level provider family")
require(Provider.tencentCloudCodingPlan.providerFamilyDisplayName(language: .simplifiedChinese) == "腾讯云", "Tencent Cloud Coding Plan should expose Tencent Cloud as the first-level provider family")
require(Provider.tencentCloudTokenPlan.planTypeDisplayName(language: .english) == "Token Plan", "Tencent Cloud Token Plan should expose Token Plan as the second-level plan name in English")
require(Provider.claudeAPIUsage.providerFamilyDisplayName(language: .english) == "Claude", "Claude API usage should expose Claude as provider family")
require(Provider.claudeAPIUsage.planTypeDisplayName(language: .english) == "API Usage", "Claude API usage should expose API Usage as second-level plan name")
require(Provider.claudeSubscription.planTypeDisplayName(language: .english) == "Subscription", "Claude subscription should expose Subscription as second-level plan name")
require(Provider.codexAPIUsage.providerFamilyDisplayName(language: .english) == "Codex", "Codex API usage should expose Codex as provider family")
require(Provider.codexSubscription.planTypeDisplayName(language: .english) == "Subscription", "Codex subscription should expose Subscription as second-level plan name")
require(Provider.tavily.planTypeDisplayName(language: .simplifiedChinese) == nil, "Plain AI Search providers should not expose a second-level plan name")
require(Provider.tencentCloudCodingPlan.dashboardURL == "https://console.cloud.tencent.com/tokenhub/codingplan", "Tencent Cloud Coding Plan should open the TokenHub Coding Plan page")
require(Provider.tencentCloudTokenPlan.dashboardURL == "https://console.cloud.tencent.com/tokenhub/tokenplan", "Tencent Cloud Token Plan should open the TokenHub Token Plan page")
require(Provider.xfyunCodingPlan.supportsQuotaQuery, "XFYun Coding Plan should support dashboard quota checks")
require(!Provider.xfyunTokenPlan.supportsQuotaQuery, "XFYun Token Plan should not claim quota checks until a usage API is implemented")
require(Provider.volcengineCodingPlan.supportsQuotaQuery, "Volcengine Coding Plan should support dashboard quota checks")
require(!Provider.volcengineTokenPlan.supportsQuotaQuery, "Volcengine Token Plan should not claim quota checks until official API wiring is implemented and verified")
require(Provider.opencodeGo.supportsQuotaQuery, "OpenCode Go should support dashboard quota checks")
require(Provider.aliyunCodingPlan.supportsQuotaQuery, "Aliyun Coding Plan should support dashboard subscription checks through aliclaw.coding-plan")
require(!Provider.aliyunTokenPlan.supportsQuotaQuery, "Aliyun Token Plan should not claim quota checks until an official or dashboard API is implemented")
require(Provider.tencentCloudCodingPlan.supportsQuotaQuery, "Tencent Cloud Coding Plan should support dashboard quota checks through DescribePkg")
require(Provider.tencentCloudTokenPlan.supportsQuotaQuery, "Tencent Cloud Token Plan should expose quota checks through the official TokenHub API")
require(!Provider.claudeAPIUsage.supportsQuotaQuery, "Claude API usage should not claim quota checks until Admin API credentials are modeled and verified")
require(!Provider.claudeSubscription.supportsQuotaQuery, "Claude subscription should not claim quota checks until a stable subscription quota endpoint is verified")
require(!Provider.codexAPIUsage.supportsQuotaQuery, "Codex API usage should not claim quota checks until OpenAI Admin usage credentials are modeled and verified")
require(Provider.codexSubscription.supportsQuotaQuery, "Codex subscription should support quota checks through the verified ChatGPT wham endpoint")
require(Provider.aliyunCodingPlan.capability.credentialKind == .dashboardCookie, "Aliyun Coding Plan quota monitoring should use dashboard cookies")
require(Provider.aliyunCodingPlan.capability.usageSource == .dashboardAPI, "Aliyun Coding Plan should expose subscription status through the dashboard aliclaw.coding-plan API")
require(Provider.aliyunCodingPlan.capability.canTestConnection, "Aliyun Coding Plan should offer a non-consuming dashboard subscription check")
require(Provider.xfyunTokenPlan.capability.credentialKind == .dashboardCookie, "XFYun Token Plan quota monitoring should use dashboard cookies until an official usage endpoint is confirmed")
require(Provider.xfyunTokenPlan.capability.usageSource == .unavailable, "XFYun Token Plan should not expose quota status until a safe usage endpoint is confirmed")
require(!Provider.xfyunTokenPlan.capability.canTestConnection, "XFYun Token Plan should not run generation requests as quota monitoring")
require(Provider.volcengineTokenPlan.capability.credentialKind == .dashboardCookie, "Volcengine Token Plan quota monitoring should use dashboard cookies until signed API wiring is implemented and verified")
require(Provider.volcengineTokenPlan.capability.usageSource == .unavailable, "Volcengine Token Plan should not expose quota status until official API wiring is implemented and verified")
require(!Provider.volcengineTokenPlan.capability.canTestConnection, "Volcengine Token Plan should not offer connection tests before a verified non-consuming usage check exists")
require(Provider.aliyunTokenPlan.capability.credentialKind == .dashboardCookie, "Aliyun Token Plan quota monitoring should use dashboard cookies until an official usage endpoint is confirmed")
require(Provider.tencentCloudCodingPlan.capability.credentialKind == .dashboardCookie, "Tencent Cloud Coding Plan quota monitoring should use dashboard cookies")
require(Provider.tencentCloudCodingPlan.capability.usageSource == .dashboardAPI, "Tencent Cloud Coding Plan should expose quota status through the dashboard DescribePkg API")
require(Provider.tencentCloudCodingPlan.capability.canTestConnection, "Tencent Cloud Coding Plan should offer a non-consuming dashboard quota check")
require(Provider.tencentCloudTokenPlan.capability.credentialKind == .adminCredential, "Tencent Cloud Token Plan should be configured as an admin credential because the official usage API requires signed Tencent Cloud API access")
require(Provider.tencentCloudTokenPlan.capability.canTestConnection, "Tencent Cloud Token Plan should support connection tests")
require(!Provider.tencentCloudTokenPlan.capability.consumesQuota, "Tencent Cloud Token Plan quota checks should not consume model/search quota")
require(Provider.codexSubscription.capability.credentialKind == .dashboardCookie, "Codex subscription should store web login authorization separately from API keys")
require(Provider.codexSubscription.capability.usageSource == .dashboardAPI, "Codex subscription should expose the verified ChatGPT usage endpoint as a dashboard API")
require(Provider.codexSubscription.capability.canTestConnection, "Codex subscription should expose refresh after the wham endpoint is wired in QuotaService")
require(Provider.querit.supportsQuotaQuery, "Querit should support dashboard-cookie quota checks through the user account endpoint")
require(Provider.querit.capability.resetCycle == .notExposed, "Querit account endpoint exposes monthly usage but no reset/end date")
require(Provider.querit.supportsCompanionAPIKeyStorage, "Querit should allow storing an optional API key separately from dashboard authorization")
require(Provider.serper.capability.resetCycle == .notExposed, "Serper account endpoint exposes credit balance but no reset/end date")
require(Provider.exa.supportsQuotaQuery, "Exa should support usage checks when a service API key and API key id are configured")
require(Provider.exa.localizedUnsupportedQuotaLabel(language: .simplifiedChinese) == "需要 API 密钥", "Exa plain search keys should ask for an API key without confusing admin credential wording")
require(Provider.exa.localizedUnsupportedQuotaLabel(language: .traditionalChinese) == "需要 API 金鑰", "Exa plain search keys should ask for an API key without confusing admin credential wording in Traditional Chinese")
require(Provider.exa.localizedUnsupportedQuotaLabel(language: .japanese) == "API キーが必要", "Exa plain search keys should ask for an API key without confusing admin credential wording in Japanese")
require(Provider.exa.localizedUnsupportedQuotaLabel(language: .korean) == "API 키 필요", "Exa plain search keys should ask for an API key without confusing admin credential wording in Korean")
require(Provider.deepseek.homeVisibleWithoutKeys, "DeepSeek should appear on the home view before a key is configured")
require(Provider.xfyunCodingPlan.homeVisibleWithoutKeys, "XFYun Coding Plan should appear on the home view before a key is configured")
require(Provider.volcengineCodingPlan.homeVisibleWithoutKeys, "Volcengine Coding Plan should appear on the home view before a key is configured")
require(Provider.opencodeGo.homeVisibleWithoutKeys, "OpenCode Go should appear on the home view before a key is configured")
require(!Provider.tencentCloudTokenPlan.homeVisibleWithoutKeys, "Tencent Cloud Token Plan should stay off the home view until a real key is available")
require(!Provider.anthropic.homeVisibleWithoutKeys, "Anthropic should stay off the home view unless explicitly configured")
require(!Provider.xfyunTokenPlan.homeVisibleWithoutKeys, "XFYun Token Plan should stay off the home view until quota parsing is implemented")
require(!Provider.volcengineTokenPlan.homeVisibleWithoutKeys, "Volcengine Token Plan should stay off the home view until quota parsing is implemented")
require(!Provider.aliyunCodingPlan.homeVisibleWithoutKeys, "Aliyun Coding Plan should stay off empty home placeholders but appear once a business key or dashboard cookie is configured")
require(!Provider.aliyunTokenPlan.homeVisibleWithoutKeys, "Aliyun Token Plan should stay off the home view until quota parsing is implemented")
require(!Provider.tencentCloudCodingPlan.homeVisibleWithoutKeys, "Tencent Cloud Coding Plan should stay off empty home placeholders but appear once a business key or dashboard cookie is configured")
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
require(xfyunStat.statusBarProviderQuotaText == "5h 99% · week 79.3% · month 89.7%", "Status bar coding-plan quota text should show all quota cycles")
require(xfyunStat.statusBarProviderBadgeText == "week 79.3%", "Status bar coding-plan badge should display the tightest quota cycle")
let codexSubscriptionStat = ProviderStats(
    provider: .codexSubscription,
    keys: [
        APIKey(
            name: "CODEX_SUBSCRIPTION_SESSION",
            key: "cookie",
            provider: .codexSubscription,
            remaining: 3000,
            limit: 10000,
            quotaLabel: "5h 100% · week 30%"
        )
    ]
)
require(codexSubscriptionStat.totalLimitDisplayText == "week 30%", "Codex subscription provider total should use the longest available percentage window instead of inventing a month value")
require(codexSubscriptionStat.totalRemainingDisplayText == "week 30%", "Codex subscription provider remaining should display the tightest percentage window")
require(codexSubscriptionStat.statusBarProviderQuotaText == "5h 100% · week 30%", "Status bar Codex subscription quota text should show all returned percentage windows")
require(codexSubscriptionStat.statusBarProviderBadgeText == "week 30%", "Status bar Codex subscription badge should display the tightest percentage window")
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
require(multiXfyunStat.statusBarProviderQuotaText == "5h 88% · week 64.4% · month 84%", "Status bar coding-plan quota text should show the tightest value for each quota cycle across credentials")
require(multiXfyunStat.statusBarProviderBadgeText == "week 64.4%", "Status bar coding-plan badge should use the tightest quota cycle across credentials")
let xfyunCompanionAPIKey = APIKey(
    name: "XFYUN_CODING_PLAN_API_KEY",
    key: "xfyun-api-redacted",
    provider: .xfyunCodingPlan
)
let xfyunMonitoringAuthorization = APIKey(
    name: "XFYUN_CODING_PLAN_COOKIE",
    key: "cookie-redacted",
    provider: .xfyunCodingPlan,
    remaining: 7934,
    limit: 10000,
    lastHTTPStatus: 200,
    quotaLabel: "5h 99% · week 79.3% · month 89.7%"
)
let xfyunWithCompanionStat = ProviderStats(
    provider: .xfyunCodingPlan,
    keys: [xfyunCompanionAPIKey, xfyunMonitoringAuthorization]
)
require(
    xfyunWithCompanionStat.sortedMonitoringKeysByCurrentQuota.map { $0.name } == ["XFYUN_CODING_PLAN_COOKIE"],
    "Provider quota detail rows should not duplicate copy-only companion API keys"
)
let companionDiagnostic = xfyunWithCompanionStat.credentialDiagnosticItems.first {
    $0.key.name == "XFYUN_CODING_PLAN_API_KEY"
}
require(companionDiagnostic != nil, "Diagnostics should still include copy-only companion API keys for editing context")
require(companionDiagnostic!.healthDisplayText == "Healthy", "Companion API-key diagnostics should reuse the paired quota-monitoring authorization health state")
require(companionDiagnostic!.httpStatusText == "200", "Companion API-key diagnostics should reuse the paired quota-monitoring authorization HTTP status")
AppLanguageStore.shared.language = .simplifiedChinese
require(xfyunStat.totalLimitDisplayText == "月 89.7%", "Coding Plan provider total should localize the monthly period label in Simplified Chinese")
require(xfyunStat.totalRemainingDisplayText == "周 79.3%", "Coding Plan provider remaining should localize the lowest remaining period label in Simplified Chinese")
let localizedWindowResetDate = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 23, minute: 30, second: 0))!
let localizedQuotaWindow = QuotaWindowText(name: "week", percentText: "89.2%", resetAt: localizedWindowResetDate)
require(localizedQuotaWindow.resetSummary.contains("6月8日"), "Quota window reset summaries should localize reset dates")
require(localizedQuotaWindow.displayText == "周 89.2%", "Quota window display text should reuse localized period labels")
require(localizedQuotaWindow.resetDetailText.contains("周 89.2%"), "Quota window detail should include the localized quota window")
require(localizedQuotaWindow.resetDetailText.contains("重置"), "Quota window detail should explicitly label reset timing when reset data exists")
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
require(L10n.localizedQuotaLabel("Querit account endpoint returned monthly request quota.", language: .simplifiedChinese) == "Querit 账户接口返回了月度已用请求，但没有返回套餐上限。", "Persisted legacy Querit quota diagnostics should render as usage-only in Simplified Chinese")
require(L10n.localizedQuotaLabel("Querit account endpoint returned monthly usage, but no plan quota limit.", language: .simplifiedChinese) == "Querit 账户接口返回了月度已用请求，但没有返回套餐上限。", "Querit usage-only diagnostics should localize centrally")
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
let localizedTencentTokenQuota = APIKey(name: "TENCENT_CLOUD_TOKEN_PLAN_CREDENTIAL", key: "{}", provider: .tencentCloudTokenPlan, quotaLabel: "650000 / 800000 tokens")
require(localizedTencentTokenQuota.quotaDisplayText == "650000 / 800000 个 token", "Legacy Tencent Cloud Token Plan token labels should localize in Simplified Chinese")
let noSubscriptionTencent = APIKey(
    name: "TENCENT_CLOUD_CODING_PLAN_COOKIE",
    key: "cookie",
    provider: .tencentCloudCodingPlan,
    lastHTTPStatus: 200,
    quotaText: .localized(.noSubscribedPlan)
)
require(noSubscriptionTencent.quotaDisplayText == "未发现订阅套餐", "Tencent Cloud Coding Plan should show a specific no-subscription status in Simplified Chinese")
require(noSubscriptionTencent.remainingBadgeText == "N/A", "No-subscription credentials should not look like exhausted quota")
let persistedEnglishUnavailable = APIKey(
    name: "TENCENT_CLOUD_CODING_PLAN_API_KEY",
    key: "sk-sp-redacted",
    provider: .tencentCloudCodingPlan,
    lastDiagnosticMessage: "Quota API pending.",
    quotaLabel: "Quota unavailable"
)
require(persistedEnglishUnavailable.quotaDisplayText == "业务 key 已保存", "Tencent Cloud Coding Plan business keys should show a saved-key state in quota monitoring")
require(persistedEnglishUnavailable.healthDisplayText == "业务 key 已保存", "Tencent Cloud Coding Plan business keys should show a saved-key state, not quota API pending")
require(persistedEnglishUnavailable.diagnosticSummary == "额度监控请用网页登录授权", "Tencent Cloud Coding Plan business-key diagnostics should direct users to web login authorization")
require(ProviderStats(provider: .tencentCloudCodingPlan, keys: [persistedEnglishUnavailable]).statusBarProviderQuotaText == "未配置密钥", "Provider overview should not treat copy-only business keys as quota-monitoring credentials")
require(L10n.localizedQuotaLabel("Quota unavailable", language: .simplifiedChinese) == "额度不可用", "Persisted English quota-unavailable labels should be normalized centrally")
require(L10n.localizedQuotaLabel("Quota API pending.", language: .simplifiedChinese) == "额度接口待确认。", "Generic persisted English quota-pending diagnostics should still be normalized centrally")
require(L10n.localizedQuotaLabel("This provider does not expose a supported quota-check endpoint.", language: .simplifiedChinese) == "该服务商没有公开受支持的额度查询接口。", "Persisted English unsupported quota diagnostics should be normalized centrally")
let persistedBraveDiagnostic = APIKey(
    name: "BRAVE_API_KEY",
    key: "brave",
    provider: .brave,
    lastDiagnosticMessage: "Search works, but Brave did not expose monthly quota for this key."
)
require(persistedBraveDiagnostic.diagnosticSummary == "搜索可用，但 Brave 没有公开这个 key 的月度额度。", "Persisted English Brave diagnostics should localize in Simplified Chinese diagnostics")
let legacyAliyunBusinessKey = APIKey(
    name: "ALIYUN_CODING_PLAN_API_KEY",
    key: "sk-sp-redacted",
    provider: .aliyunCodingPlan,
    quotaLabel: "Business invocation key is not used for quota monitoring. Add a dashboard Cookie credential instead."
)
require(legacyAliyunBusinessKey.managementDisplayName == "业务调用 key", "Legacy Aliyun business invocation keys should use a compact management display name")
require(legacyAliyunBusinessKey.managementCredentialValueText == "sk-s••••cted", "Legacy Aliyun business invocation rows should show the masked key value instead of repeating the dashboard-cookie instruction")
require(legacyAliyunBusinessKey.managementCredentialTypeBadgeText == nil, "Legacy business invocation rows should not show a misleading dashboard-cookie type badge")
require(legacyAliyunBusinessKey.quotaDisplayText == "业务 key 已保存", "Legacy Aliyun business invocation keys should show a saved-key status")
require(legacyAliyunBusinessKey.diagnosticSummary == "额度监控请用网页登录授权", "Legacy Aliyun business invocation diagnostics should point users to web login authorization")
require(L10n.localizedQuotaLabel("Business invocation key is not used for quota monitoring. Add a dashboard Cookie credential instead.", language: .simplifiedChinese) == "额度监控请用网页登录授权", "Persisted English business-invocation diagnostics should localize to the current Chinese action")
require(L10n.localizedQuotaLabel("Business invocation key is not used for quota monitoring Add a dashboard Cookie credential instead", language: .simplifiedChinese) == "额度监控请用网页登录授权", "Persisted business-invocation diagnostics should localize even when punctuation was truncated")
require(L10n.localizedQuotaLabel("Business invocation key is not used for quota monitoring Add a dashboard Cookie credential instead", language: .english) == "Use web login authorization for quota monitoring", "Persisted business-invocation diagnostics should be rewritten in English too")
let generatedTavilyKey = APIKey(name: "TAVILY_API_KEY", key: "abcd1234wxyz", provider: .tavily)
require(generatedTavilyKey.managementDisplayName == "API 密钥", "Credential rows should not repeat provider-derived API key environment variable names")
require(generatedTavilyKey.managementCredentialValueText == "abcd••••wxyz", "Credential rows should still show concrete masked API key values when available")
require(generatedTavilyKey.managementCredentialTypeBadgeText == nil, "Generated API-key credential rows should not repeat the API key label as a type badge")
require(generatedTavilyKey.copyableCredentialValue == "abcd1234wxyz", "Normal API key rows should expose a copyable value")
let generatedAliyunKey = APIKey(name: "ALIYUN_CODING_PLAN_API_KEY", key: "sk-sp-redacted", provider: .aliyunCodingPlan)
require(generatedAliyunKey.managementDisplayName == "业务调用 key", "Aliyun Coding Plan rows should identify business invocation keys compactly")
require(generatedAliyunKey.managementCredentialValueText == "sk-s••••cted", "Aliyun Coding Plan rows should show masked API key values")
require(generatedAliyunKey.managementCredentialTypeBadgeText == nil, "Generated Aliyun business-key rows should not repeat the API key type badge")
require(generatedAliyunKey.isStoredAPIKeyOnlyCredential, "Aliyun Coding Plan business API keys should be stored as copy-only API key records")
require(generatedAliyunKey.copyableCredentialValue == "sk-sp-redacted", "Business API keys should be copyable even when quota monitoring uses web login authorization")
let generatedXfyunCookie = APIKey(name: "XFYUN_CODING_PLAN_COOKIE", key: "ssoSessionId=redacted-session; account_id=123456", provider: .xfyunCodingPlan)
require(generatedXfyunCookie.managementDisplayName == "额度监控授权", "XFYun dashboard-cookie rows should identify quota monitoring authorization instead of an API key")
require(generatedXfyunCookie.managementCredentialValueText == "网页登录授权", "XFYun dashboard-cookie rows should not show even a masked cookie value")
require(generatedXfyunCookie.copyableCredentialValue == nil, "Dashboard-cookie quota authorizations must not be copyable")
let generatedXfyunAPIKey = APIKey(name: "XFYUN_CODING_PLAN_API_KEY", key: "xfyun-api-redacted", provider: .xfyunCodingPlan)
require(generatedXfyunAPIKey.isStoredAPIKeyOnlyCredential, "XFYun Coding Plan API keys should be stored separately from quota-monitoring authorization")
require(generatedXfyunAPIKey.managementDisplayName == "API 密钥", "XFYun API-key-only records should show the API key label")
require(generatedXfyunAPIKey.managementCredentialValueText == "xfyu••••cted", "XFYun API-key-only records should show a masked API key value")
require(generatedXfyunAPIKey.quotaDisplayText == "API key 已保存", "API-key-only records should not pretend quota is unavailable")
require(generatedXfyunAPIKey.diagnosticSummary == "仅保存用于复制", "API-key-only records should explain that they are not quota-monitoring credentials")
require(generatedXfyunAPIKey.copyableCredentialValue == "xfyun-api-redacted", "API-key-only records should be copyable")
let generatedQueritCookie = APIKey(name: "QUERIT_COOKIE", key: "osduss=redacted; passOsRefreshTk=redacted", provider: .querit)
require(generatedQueritCookie.managementDisplayName == "额度监控授权", "Querit dashboard-cookie rows should identify quota monitoring authorization")
require(generatedQueritCookie.managementCredentialValueText == "网页登录授权", "Querit dashboard-cookie rows should not show even a masked cookie value")
require(generatedQueritCookie.copyableCredentialValue == nil, "Querit dashboard authorization must not be copyable")
let generatedQueritAPIKey = APIKey(name: "QUERIT_API_KEY", key: "querit-api-redacted", provider: .querit)
require(generatedQueritAPIKey.isStoredAPIKeyOnlyCredential, "Querit API keys should be stored separately from quota-monitoring authorization")
require(generatedQueritAPIKey.managementDisplayName == "API 密钥", "Querit optional API-key records should show the API key label")
require(generatedQueritAPIKey.copyableCredentialValue == "querit-api-redacted", "Querit optional API-key records should be copyable")
let generatedOpenCodeCookie = APIKey(name: "OPENCODE_GO_COOKIE", key: #"{"cookie":"auth=redacted-cookie","workspaceID":"wrk_123"}"#, provider: .opencodeGo)
require(generatedOpenCodeCookie.managementCredentialValueText == "网页登录授权", "OpenCode Go dashboard-cookie rows should not show serialized credential values")
require(generatedOpenCodeCookie.copyableCredentialValue == nil, "OpenCode Go web login authorization should not be copyable")
let generatedTencentCodingKey = APIKey(name: "TENCENT_CLOUD_CODING_PLAN_API_KEY", key: "sk-sp-redacted", provider: .tencentCloudCodingPlan)
require(generatedTencentCodingKey.managementCredentialValueText == "sk-s••••cted", "Tencent Cloud Coding Plan rows should show a masked business key value")
require(generatedTencentCodingKey.copyableCredentialValue == "sk-sp-redacted", "Tencent Cloud Coding Plan business keys should be copyable")
let generatedTencentAdminCredential = APIKey(name: "TENCENT_CLOUD_TOKEN_PLAN_CREDENTIAL", key: #"{"secretId":"id"}"#, provider: .tencentCloudTokenPlan)
require(generatedTencentAdminCredential.managementDisplayName == "API 密钥", "Tencent Token Plan credential rows should use the familiar API key label")
require(generatedTencentAdminCredential.managementCredentialValueText == "API 密钥", "Tencent Token Plan credential rows should not expose raw signed credential JSON")
require(generatedTencentAdminCredential.managementCredentialTypeBadgeText == nil, "Generated API key rows should not repeat the API key label as a type badge")
let customNamedKey = APIKey(name: "Personal fallback", key: "tvly", provider: .tavily)
require(customNamedKey.managementDisplayName == "Personal fallback", "Custom credential names should still be preserved")
require(customNamedKey.managementCredentialTypeBadgeText == "API 密钥", "Custom credential names should keep a compact credential-type badge")
let claudeImportedKey = APIKey(name: "TAVILY_API_KEY", key: "abcd1234wxyz", provider: .tavily, note: "Imported from ~/.claude/settings.json")
require(claudeImportedKey.displayNote == "从 ~/.claude/settings.json 导入", "Credential rows should localize persisted Claude settings import notes")
let envImportedKey = APIKey(name: "TAVILY_API_KEY", key: "abcd1234wxyz", provider: .tavily, note: "Imported from .env")
require(envImportedKey.displayNote == "从 .env 导入", "Credential rows should localize persisted .env import notes")
let customNoteKey = APIKey(name: "TAVILY_API_KEY", key: "abcd1234wxyz", provider: .tavily, note: "keep this custom note")
require(customNoteKey.displayNote == "keep this custom note", "Custom credential notes should not be rewritten by localization")
let businessInvocationNoteKey = APIKey(name: "ALIYUN_CODING_PLAN_API_KEY", key: "sk-sp-redacted", provider: .aliyunCodingPlan, note: "Business invocation key is not used for quota monitoring Add a dashboard Cookie credential instead")
require(businessInvocationNoteKey.displayNote == nil, "Credential rows should suppress duplicated persisted business-invocation notes")
let localizedResetDate = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 6, day: 28, hour: 17, minute: 48, second: 58))!
let localizedResetKey = APIKey(
    name: "XFYUN_CODING_PLAN_COOKIE",
    key: "cookie",
    provider: .xfyunCodingPlan,
    resetAt: localizedResetDate
)
require(localizedResetKey.resetSummary.contains("月"), "Reset dates should be localized in Simplified Chinese instead of fixed English month names")
require(!localizedResetKey.resetSummary.contains("Jun"), "Reset dates should not leak English month names in Simplified Chinese")
require(localizedResetKey.visibleQuotaResetSummary == localizedResetKey.quotaResetSummary, "Visible reset summary should keep real provider reset timestamps")
let codexWindowResetKey = APIKey(
    name: "CODEX_SUBSCRIPTION_SESSION",
    key: "cookie",
    provider: .codexSubscription,
    resetAt: localizedResetDate,
    quotaText: LocalizedTextDescriptor.quotaWindows([
        QuotaWindowText(name: "5h", percentText: "91%", resetAt: localizedResetDate),
        QuotaWindowText(name: "week", percentText: "99%", resetAt: localizedResetDate)
    ])
)
require(codexWindowResetKey.visibleQuotaResetSummary == "", "Codex subscription should not duplicate reset timing above the plan expiry column")
require(codexWindowResetKey.quotaWindowDetails.count == 2, "Codex subscription should keep reset timing attached to the five-hour and weekly quota rows")
require(codexWindowResetKey.quotaWindowDetails.allSatisfy { $0.detailValueText != nil }, "Codex subscription quota rows should expose reset timing per window")
let planOnlyKey = APIKey(
    name: "XFYUN_CODING_PLAN_COOKIE",
    key: "cookie",
    provider: .xfyunCodingPlan,
    planEndsAt: localizedResetDate
)
require(planOnlyKey.quotaResetSummary == "未公开重置时间", "Quota reset summary should not invent a vague dashboard cycle when the endpoint exposes only plan end time")
require(planOnlyKey.visibleQuotaResetSummary == "", "Compact UI rows should hide placeholder reset copy when a provider only exposes the package end date")
require(planOnlyKey.planEndSummary.contains("套餐"), "Package expiry should be presented separately from quota reset timing")
require(planOnlyKey.quotaPresentation.resetText == "", "QuotaPresentation should not expose placeholder reset copy in compact UI")
require(planOnlyKey.quotaPresentation.planEndText == planOnlyKey.planEndSummary, "QuotaPresentation should expose package expiry as a separate field")
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
require(volcengineStat.statusBarProviderQuotaText == "5h 100% · week 89.2% · month 94.6%", "Volcengine status bar provider text should show all quota windows, including five-hour quota")
require(volcengineStat.statusBarProviderBadgeText == "week 89.2%", "Volcengine status bar badge should still summarize the tightest quota window")
let volcengineDisplayKey = APIKey(
    name: "VOLCENGINE_CODING_PLAN_COOKIE",
    key: "cookie",
    provider: .volcengineCodingPlan,
    resetAt: localizedResetDate,
    quotaText: LocalizedTextDescriptor.quotaWindows([
        QuotaWindowText(name: "5h", percentText: "100%"),
        QuotaWindowText(name: "week", percentText: "89.2%", resetAt: localizedResetDate),
        QuotaWindowText(name: "month", percentText: "94.6%", resetAt: localizedResetDate),
    ])
)
require(volcengineDisplayKey.quotaWindowDetails.map { $0.name } == ["5h", "week", "month"], "Volcengine quota window details should include five-hour quota even when that window has no reset timestamp")
require(volcengineDisplayKey.visibleQuotaResetSummary == "", "Volcengine should not show the monthly reset as a top-level reset when it is also the package end")
require(volcengineDisplayKey.planEndSummary == L10n.format(.planEndsDate, L10n.shortDateTime(localizedResetDate)), "Volcengine should present the monthly reset timestamp as package expiry in compact timing rows")
require(volcengineDisplayKey.quotaPresentation.resetText == "", "Volcengine quota presentation should avoid duplicating package expiry as reset timing")
require(volcengineDisplayKey.quotaPresentation.planEndText == volcengineDisplayKey.planEndSummary, "Volcengine quota presentation should expose derived package expiry")
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
let opencodeDisplayKey = APIKey(
    name: "OPENCODE_GO_COOKIE",
    key: "cookie",
    provider: .opencodeGo,
    resetAt: localizedResetDate,
    quotaText: LocalizedTextDescriptor.quotaWindows([
        QuotaWindowText(name: "5h", percentText: "98%", resetAt: localizedResetDate),
        QuotaWindowText(name: "week", percentText: "50%", resetAt: localizedResetDate),
        QuotaWindowText(name: "month", percentText: "25%", resetAt: localizedResetDate),
    ])
)
require(opencodeDisplayKey.visibleQuotaResetSummary == "", "OpenCode Go should not show the monthly reset as a top-level reset when it is also the package end")
require(opencodeDisplayKey.planEndSummary == L10n.format(.planEndsDate, L10n.shortDateTime(localizedResetDate)), "OpenCode Go should present the monthly reset timestamp as package expiry in compact timing rows")
require(opencodeDisplayKey.quotaPresentation.resetText == "", "OpenCode Go quota presentation should avoid duplicating package expiry as reset timing")
require(opencodeDisplayKey.quotaPresentation.planEndText == opencodeDisplayKey.planEndSummary, "OpenCode Go quota presentation should expose derived package expiry")
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
AppLanguageStore.shared.language = .simplifiedChinese
let unsupportedTencentCodingKey = APIKey(
    name: "TENCENT_CLOUD_CODING_PLAN_API_KEY",
    key: "sk-sp-redacted",
    provider: .tencentCloudCodingPlan,
    lastDiagnosticMessage: Provider.tencentCloudCodingPlan.unsupportedQuotaDiagnosticMessage(),
    quotaLabel: L10n.t(.quotaUnavailable)
)
require(unsupportedTencentCodingKey.status != KeyStatus.failed, "Unsupported Tencent Cloud Coding Plan API-key checks should not be reported as failed checks")
require(unsupportedTencentCodingKey.healthDisplayText == "业务 key 已保存", "Tencent Cloud Coding Plan business keys should show a saved-key state")
let unsupportedTencentBusinessKey = APIKey(
    name: "TENCENT_CLOUD_CODING_PLAN_API_KEY",
    key: "sk-sp-redacted",
    provider: .tencentCloudCodingPlan,
    lastDiagnosticMessage: Provider.tencentCloudCodingPlan.unsupportedQuotaDiagnosticMessage(),
    quotaLabel: L10n.t(.quotaUnavailable)
)
require(unsupportedTencentBusinessKey.status != KeyStatus.failed, "Tencent Cloud business invocation keys should not be reported as failed checks")
require(unsupportedTencentBusinessKey.healthDisplayText == "业务 key 已保存", "Tencent Cloud business invocation keys should show a saved-key state")
AppLanguageStore.shared.language = .english
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
require(cookieStatusLabel == "Web login authorization", "Status bar should show the credential type for web-login providers, not masked raw JSON")
let apiStatusLabel = APIKey(
    name: "BRAVE_API_KEY",
    key: "abcd1234wxyz",
    provider: .brave
).statusBarCredentialLabel
require(apiStatusLabel == "abcd••••wxyz", "Status bar should still show masked concrete API keys for normal providers")
let aliyunTokenPlanStatusLabel = APIKey(
    name: "ALIYUN_TOKEN_PLAN_API_KEY",
    key: "sk-sp-redacted",
    provider: .aliyunTokenPlan
).statusBarCredentialLabel
require(aliyunTokenPlanStatusLabel == "sk-s••••cted", "Status bar should show masked Aliyun Token Plan API keys")
let aliyunCodingPlanStatusLabel = APIKey(
    name: "ALIYUN_CODING_PLAN_API_KEY",
    key: "sk-sp-redacted",
    provider: .aliyunCodingPlan
).statusBarCredentialLabel
require(aliyunCodingPlanStatusLabel == "sk-s••••cted", "Status bar should show masked Aliyun Coding Plan API keys")
let tencentCodingPlanStatusLabel = APIKey(
    name: "TENCENT_CLOUD_CODING_PLAN_API_KEY",
    key: "sk-sp-redacted",
    provider: .tencentCloudCodingPlan
).statusBarCredentialLabel
require(tencentCodingPlanStatusLabel == "sk-s••••cted", "Status bar should show masked Tencent Cloud Coding Plan API keys")
let settingsURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("claude-settings.json")
try! Data("""
{"env":{"TAVILY_API_KEY":"tavily-from-settings","BRAVE_API_KEY":"brave-from-settings","ANTHROPIC_API_KEY":""}}
""".utf8).write(to: settingsURL)
let settingsKeys = ClaudeSettingsImporter.parseSettings(at: settingsURL)
require(settingsKeys.count == 2, "Claude settings importer should skip empty env values")
require(settingsKeys.contains { $0.name == "TAVILY_API_KEY" && $0.provider == .tavily }, "Claude settings importer missing Tavily")
require(settingsKeys.contains { $0.name == "BRAVE_API_KEY" && $0.provider == .brave }, "Claude settings importer missing Brave")
SWIFT

swiftc QuotaRadar/Models/AppLanguage.swift QuotaRadar/Models/APIKey.swift QuotaRadar/Services/EnvImporter.swift QuotaRadar/Services/ClaudeSettingsImporter.swift "$TMP_DIR/main.swift" -o "$TMP_DIR/env-importer-test"
"$TMP_DIR/env-importer-test"

echo "== cURL credential parser behavior =="
cat >"$TMP_DIR/main.swift" <<'SWIFT'
import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(1)
    }
}

let volcCurl = """
curl 'https://console.volcengine.com/api/top/ark/cn-beijing/2024-01-01/GetCodingPlanUsage?' \
  -H 'x-csrf-token: csrf-redacted' \
  -H 'x-web-id: web-id-redacted' \
  -b 'digest=redacted; AccountID=account-redacted; csrfToken=csrf-cookie' \
  --data-raw '{"ProjectName":"default"}'
"""
let volc = try! CurlCredentialParser.parse(volcCurl, provider: .volcengineCodingPlan)
require(volc.provider == .volcengineCodingPlan, "Volcengine cURL parse should preserve provider")
require(volc.cookie.contains("digest=redacted"), "Volcengine cURL parse should extract cookie")
require(volc.fields["csrfToken"] == "csrf-redacted", "Volcengine cURL parse should extract x-csrf-token")
require(volc.fields["projectName"] == "default", "Volcengine cURL parse should extract ProjectName")
require(volc.serializedCredential.contains("\"cookie\""), "Volcengine parser should serialize credential as JSON")

let opencodeCurl = """
curl 'https://opencode.ai/_server?id=server-redacted&args=%7B%7D' \
  -H 'x-server-id: server-redacted' \
  -H 'x-server-instance: server-fn:11' \
  -H 'referer: https://opencode.ai/workspace/wrk_1234567890ABCDEFG/go' \
  -b 'auth=auth-redacted; oc_locale=zh'
"""
let opencode = try! CurlCredentialParser.parse(opencodeCurl, provider: .opencodeGo)
require(opencode.cookie.contains("auth=auth-redacted"), "OpenCode cURL parse should extract auth cookie")
require(opencode.fields["workspaceID"] == "wrk_1234567890ABCDEFG", "OpenCode cURL parse should extract workspace id")
require(opencode.fields["serverID"] == "server-redacted", "OpenCode cURL parse should extract server id")
require(opencode.fields["serverInstance"] == "server-fn:11", "OpenCode cURL parse should extract server instance")

let queritCurl = """
curl 'https://www.querit.ai/api/v1/user/account' \
  -H 'accept: application/json' \
  -b 'osduss=session-redacted; passOsRefreshTk=refresh-redacted; osfuid=device-redacted'
"""
let querit = try! CurlCredentialParser.parse(queritCurl, provider: .querit)
require(querit.cookie.contains("osduss=session-redacted"), "Querit cURL parse should extract dashboard cookie")
require(querit.serializedCredential.contains("\"cookie\""), "Querit parser should serialize dashboard cookie")

do {
    _ = try CurlCredentialParser.parse("curl https://example.com", provider: .querit)
    require(false, "cURL parser should reject requests without cookie or provider credential material")
} catch {
    require(true, "cURL parser should reject unusable input")
    AppLanguageStore.shared.language = .simplifiedChinese
    require(error.localizedDescription == "无法从 cURL 中解析凭据。", "cURL parser errors should be localized instead of leaking English fallback text")
}
SWIFT

swiftc QuotaRadar/Models/AppLanguage.swift QuotaRadar/Models/APIKey.swift QuotaRadar/Services/CurlCredentialParser.swift "$TMP_DIR/main.swift" -o "$TMP_DIR/curl-parser-test"
"$TMP_DIR/curl-parser-test"

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
require(L10n.t(.dashboardSession, language: .english) == "Web login authorization", "English web-login credential label should avoid raw cookie wording")
require(L10n.t(.dashboardSession, language: .simplifiedChinese) == "网页登录授权", "Chinese web-login credential label should avoid gray cookie wording")
require(L10n.t(.adminCredential, language: .english) == "API Key", "English service credential label should use familiar API key wording")
require(L10n.t(.adminCredential, language: .simplifiedChinese) == "API 密钥", "Chinese service credential label should use familiar API key wording")
require(L10n.t(.credentialHelp, language: .simplifiedChinese).contains("专门用于用量查询"), "Chinese credential help should explain service API keys without admin credential wording")
require(!L10n.t(.credentialHelp, language: .simplifiedChinese).contains("管理员凭据"), "Chinese credential help should not use confusing admin credential wording")
require(L10n.t(.disabled, language: .simplifiedChinese) == "停用", "Chinese disabled status should stay compact in tight provider and credential rows")
require(L10n.t(.settingsTab, language: .simplifiedChinese) == "设置", "Chinese settings tab title should be available")
require(L10n.t(.settingsWindowTitle, language: .simplifiedChinese) == "Quota Radar 设置", "Chinese settings window title should be localized")
require(L10n.t(.provider, language: .simplifiedChinese) == "服务商", "Chinese provider form label should be fully translated")
require(L10n.t(.language, language: .simplifiedChinese) == "语言", "Chinese language label should be available")
require(L10n.t(.statusBarTransparency, language: .simplifiedChinese) == "状态栏透明度", "Chinese status bar transparency label should be available")
require(L10n.t(.adminCredentialRequired, language: .simplifiedChinese) == "需要 API 密钥", "Chinese service API key status should be fully translated without admin credential wording")
require(L10n.localizedQuotaLabel("需要管理员凭据", language: .english) == "API Key required", "Persisted legacy Chinese Admin credential labels should render with the current API key wording")
require(L10n.localizedCredentialNote("Imported from ~/.claude/settings.json", language: .simplifiedChinese) == "从 ~/.claude/settings.json 导入", "Persisted English Claude settings import notes should localize to Simplified Chinese")
require(L10n.localizedCredentialNote("从 ~/.claude/settings.json 导入", language: .english) == "Imported from ~/.claude/settings.json", "Persisted Chinese Claude settings import notes should localize to English")
require(L10n.localizedCredentialNote("Imported from .env", language: .japanese) == ".env からインポート", "Persisted .env import notes should localize to Japanese")
require(L10n.t(.importedFromClaude, language: .japanese) == "~/.claude/settings.json からインポート", "Japanese Claude settings import note should not fall back to English")
require(L10n.t(.importedFromClaude, language: .korean) == "~/.claude/settings.json에서 가져옴", "Korean Claude settings import note should not fall back to English")
require(L10n.t(.autoRefreshInterval, language: .simplifiedChinese) == "刷新频率", "Chinese settings should use a compact automatic refresh label")
require(L10n.t(.quotaConsumingAutoRefreshInterval, language: .simplifiedChinese) == "检索刷新", "Chinese settings should use a compact quota-consuming refresh label")
require(L10n.t(.settingsGeneralSection, language: .simplifiedChinese) == "通用", "Chinese settings should include a compact General section label")
require(L10n.t(.settingsRefreshSection, language: .simplifiedChinese) == "刷新", "Chinese settings should include a compact Refresh section label")
require(L10n.t(.settingsAppearanceSection, language: .simplifiedChinese) == "外观", "Chinese settings should include a compact Appearance section label")
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
    let fallbackKeys = L10n.fallbackTranslationKeys(language: language)
    require(fallbackKeys.isEmpty, "\(language.rawValue) should not silently fall back to English UI strings: \(fallbackKeys)")
    require(!L10n.t(.settingsTab, language: language).isEmpty, "\(language.rawValue) settings label should not be empty")
    require(!L10n.t(.quotaConsumingAutoRefreshWarning, language: language).isEmpty, "\(language.rawValue) quota-consuming refresh warning should not be empty")
    require(!L10n.quotaPeriodTitle("week", language: language).isEmpty, "\(language.rawValue) week period label should be localized")
}
require(L10n.t(.settingsTab, language: .traditionalChinese) == "設定", "Traditional Chinese settings label should be localized")
require(L10n.t(.apiQuotaTitle, language: .traditionalChinese) == "餘量雷達", "Traditional Chinese menu bar title should express active quota monitoring")
require(L10n.t(.healthFailed, language: .traditionalChinese) == "檢查失敗", "Traditional Chinese failed-check status should be converted from Simplified Chinese")
require(L10n.t(.httpNotRequested, language: .traditionalChinese) == "未請求", "Traditional Chinese diagnostics should not leak Simplified Chinese text")
require(L10n.t(.settingsTab, language: .japanese) == "設定", "Japanese settings label should be localized")
require(L10n.t(.apiQuotaTitle, language: .japanese) == "クォータレーダー", "Japanese menu bar title should express active quota monitoring")
require(L10n.t(.healthHealthy, language: .japanese) == "正常", "Japanese healthy status should not fall back to English")
require(L10n.t(.healthFailed, language: .japanese) == "確認失敗", "Japanese failed-check status should not fall back to English")
require(L10n.t(.settingsTab, language: .korean) == "설정", "Korean settings label should be localized")
require(L10n.t(.apiQuotaTitle, language: .korean) == "할당량 레이더", "Korean menu bar title should express active quota monitoring")
require(L10n.t(.healthHealthy, language: .korean) == "정상", "Korean healthy status should not fall back to English")
require(L10n.t(.healthFailed, language: .korean) == "확인 실패", "Korean failed-check status should not fall back to English")
require(L10n.quotaPeriodTitle("5h", language: .traditionalChinese) == "5 小時", "Traditional Chinese five-hour quota period should be localized")
require(L10n.quotaPeriodTitle("week", language: .japanese) == "週", "Japanese week quota period should be localized")
require(L10n.quotaPeriodTitle("month", language: .korean) == "월", "Korean month quota period should be localized")
require(L10n.t(.httpNotRequested, language: .english) == "Not requested", "English diagnostics should distinguish skipped HTTP checks")
require(L10n.t(.httpNotRequested, language: .simplifiedChinese) == "未请求", "Chinese diagnostics should distinguish skipped HTTP checks")
require(QuotaDataSource.responseHeader.displayName == "响应头", "Chinese quota data source labels should not leak English Header wording")
require(L10n.t(.braveQuotaHeadersDiagnostic, language: .simplifiedChinese) == "搜索可用，Brave 返回了额度响应头。", "Chinese Brave diagnostics should not leak English Header wording")
require(Provider.bocha.displayName(language: .simplifiedChinese) == "博查", "Bocha should have a Simplified Chinese provider display name")
require(Provider.wxmp.displayName(language: .english) == "WeChat Search", "WeChat Search should have an English provider display name")
require(Provider.brave.displayName(language: .simplifiedChinese) == "Brave", "Brave should not repeat the generic search category in its Simplified Chinese provider display name")
require(Provider.serpapi.displayName(language: .simplifiedChinese) == "SerpAPI", "SerpAPI should not repeat the generic search category in its Simplified Chinese provider display name")
require(Provider.serper.displayName(language: .simplifiedChinese) == "Serper", "Serper should not repeat the generic search category in its Simplified Chinese provider display name")
require(Provider.exa.displayName(language: .simplifiedChinese) == "Exa", "Exa should not repeat the generic search category in its Simplified Chinese provider display name")
require(Provider.anysearch.displayName(language: .simplifiedChinese) == "AnySearch", "AnySearch should not repeat the generic search category in its Simplified Chinese provider display name")
require(Provider.deepseek.displayName(language: .simplifiedChinese) == "Deepseek", "DeepSeek should keep the brand name in its Simplified Chinese provider display name")
require(Provider.querit.displayName(language: .simplifiedChinese) == "Querit", "Querit should not repeat the generic search category in its Simplified Chinese provider display name")
require(Provider.xfyunCodingPlan.displayName(language: .simplifiedChinese) == "讯飞星火 coding plan", "XFYun Spark should mark Coding Plan in Simplified Chinese")
require(Provider.xfyunTokenPlan.displayName(language: .simplifiedChinese) == "讯飞星火 Token plan", "XFYun Spark should mark Token Plan in Simplified Chinese")
require(Provider.volcengineCodingPlan.displayName(language: .simplifiedChinese) == "火山引擎 coding plan", "Volcengine should mark Coding Plan in Simplified Chinese")
require(Provider.volcengineTokenPlan.displayName(language: .simplifiedChinese) == "火山引擎 Token plan", "Volcengine should mark Token Plan in Simplified Chinese")
require(Provider.xfyunCodingPlan.displayName(language: .english) == "XFYun Spark Coding Plan", "XFYun Spark should mark Coding Plan in English")
require(Provider.xfyunTokenPlan.displayName(language: .english) == "XFYun Spark Token Plan", "XFYun Spark should mark Token Plan in English")
require(Provider.volcengineCodingPlan.displayName(language: .english) == "Volcengine Coding Plan", "Volcengine should mark Coding Plan in English")
require(Provider.volcengineTokenPlan.displayName(language: .english) == "Volcengine Token Plan", "Volcengine should mark Token Plan in English")
require(Provider.aliyunCodingPlan.displayName(language: .simplifiedChinese) == "阿里云 coding plan", "Aliyun Coding Plan should keep the Coding Plan naming in Simplified Chinese")
require(Provider.aliyunTokenPlan.displayName(language: .simplifiedChinese) == "阿里云 Token plan", "Aliyun Token Plan should keep the Token Plan naming in Simplified Chinese")
require(Provider.tencentCloudCodingPlan.displayName(language: .simplifiedChinese) == "腾讯云 coding plan", "Tencent Cloud Coding Plan should keep the Coding Plan naming in Simplified Chinese")
require(Provider.tencentCloudTokenPlan.displayName(language: .simplifiedChinese) == "腾讯云 Token plan", "Tencent Cloud Token Plan should keep the Token Plan naming in Simplified Chinese")
require(Provider.aliyunCodingPlan.unsupportedQuotaDiagnosticMessage(language: .simplifiedChinese) == "额度接口待确认。", "Aliyun Coding Plan non-business credential fallback should still use a conservative quota-pending diagnostic")
require(Provider.tencentCloudCodingPlan.unsupportedQuotaDiagnosticMessage(language: .simplifiedChinese) == "该服务商没有公开受支持的额度查询接口。", "Tencent Cloud Coding Plan unsupported diagnostic should not use the business-key pending message after DescribePkg support is implemented")
AppLanguageStore.shared.language = .simplifiedChinese
require(Provider.aliyunCodingPlan.capability.notes == "使用网页登录授权查询额度。", "Aliyun Coding Plan capability note should explain web-login authorization checks in Simplified Chinese")
require(Provider.tencentCloudCodingPlan.capability.notes == "使用网页登录授权查询额度。", "Tencent Cloud Coding Plan capability note should explain web-login authorization checks in Simplified Chinese")
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
) == false, "Volcengine reauthentication must not auto-save partial web login authorization")
require(DashboardCookieBuilder.containsRequiredCookie(
    from: [volcengineAccountID, volcengineCSRF, volcengineDigest],
    domains: ["volcengine.com", "console.volcengine.com"],
    requiredNames: volcengineRequiredCookies
), "Volcengine reauthentication should not block on the userInfo display cookie when core auth cookies are present")
require(DashboardCookieBuilder.missingRequiredCookieNames(
    inCookieHeader: "AccountID=account-redacted; csrfToken=c",
    requiredNames: volcengineRequiredCookies
) == ["digest"], "Manual Volcengine cookie save should report missing core auth cookies only")
let reauthedVolcengineSecret = DashboardCookieBuilder.reauthenticatedSecret(
    cookieHeader: "AccountID=account-redacted; csrfToken=n; digest=d; userInfo=u",
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
require(!Provider.xfyunTokenPlan.supportsDashboardReauthentication, "XFYun Token Plan should use its dedicated API key instead of web-login reauthentication")
require(Provider.volcengineCodingPlan.supportsDashboardReauthentication, "Volcengine should support dashboard reauthentication")
require(!Provider.volcengineTokenPlan.supportsDashboardReauthentication, "Volcengine Token Plan should use signed API credentials instead of web-login reauthentication")
require(Provider.opencodeGo.supportsDashboardReauthentication, "OpenCode Go should support dashboard reauthentication")
require(Provider.querit.supportsDashboardReauthentication, "Querit should support web-login reauthentication")
require(Provider.aliyunCodingPlan.supportsDashboardReauthentication, "Aliyun Coding Plan should support web-login authorization capture so users with accounts can verify the quota endpoint")
require(!Provider.aliyunTokenPlan.supportsDashboardReauthentication, "Aliyun Token Plan should use its dedicated API key until a quota endpoint is captured")
require(Provider.tencentCloudCodingPlan.supportsDashboardReauthentication, "Tencent Cloud Coding Plan should support web-login authorization capture so users with accounts can verify the quota endpoint")
require(!Provider.tencentCloudTokenPlan.supportsDashboardReauthentication, "Tencent Cloud Token Plan should keep using API keys instead of web-login reauthentication")
require(!Provider.claudeAPIUsage.supportsDashboardReauthentication, "Claude API usage should use API keys instead of web-login reauthentication")
require(Provider.claudeSubscription.supportsDashboardReauthentication, "Claude subscription should support web-login authorization capture")
require(!Provider.codexAPIUsage.supportsDashboardReauthentication, "Codex API usage should use API keys instead of web-login reauthentication")
require(Provider.codexSubscription.supportsDashboardReauthentication, "Codex subscription should support web-login authorization capture")
require(!Provider.brave.supportsDashboardReauthentication, "Brave should not use dashboard-cookie reauthentication")
require(DashboardReauthConfig(provider: .opencodeGo)?.cookieDomains == ["opencode.ai"], "OpenCode Go should capture only opencode.ai cookies")
require(DashboardReauthConfig(provider: .xfyunCodingPlan)?.cookieDomains == ["xfyun.cn", "maas.xfyun.cn"], "XFYun should capture maas.xfyun.cn and domain-wide xfyun.cn cookies")
require(DashboardReauthConfig(provider: .xfyunTokenPlan) == nil, "XFYun Token Plan should not expose dashboard-cookie reauthentication")
require(DashboardReauthConfig(provider: .volcengineCodingPlan)?.cookieDomains == ["volcengine.com", "console.volcengine.com"], "Volcengine should capture console.volcengine.com and domain-wide volcengine.com cookies")
require(DashboardReauthConfig(provider: .volcengineTokenPlan) == nil, "Volcengine Token Plan should not expose dashboard-cookie reauthentication")
require(DashboardReauthConfig(provider: .querit)?.cookieDomains == ["querit.ai"], "Querit should capture querit.ai dashboard cookies")
require(DashboardReauthConfig(provider: .aliyunCodingPlan)?.cookieDomains == ["aliyun.com", "bailian.console.aliyun.com"], "Aliyun Coding Plan should capture Alibaba Cloud web login authorization for quota endpoint verification")
require(DashboardReauthConfig(provider: .aliyunTokenPlan) == nil, "Aliyun Token Plan should not capture cookies without a verified dashboard quota endpoint")
require(DashboardReauthConfig(provider: .tencentCloudCodingPlan)?.cookieDomains == ["cloud.tencent.com", "console.cloud.tencent.com"], "Tencent Cloud Coding Plan should capture Tencent Cloud web login authorization for quota endpoint verification")
require(DashboardReauthConfig(provider: .claudeSubscription)?.cookieDomains == ["claude.ai"], "Claude subscription should capture claude.ai web-login authorization")
require(DashboardReauthConfig(provider: .codexSubscription)?.cookieDomains == ["chatgpt.com"], "Codex subscription should capture ChatGPT web-login authorization")
require(DashboardReauthConfig(provider: .claudeAPIUsage) == nil, "Claude API usage should not expose dashboard reauthentication")
require(DashboardReauthConfig(provider: .codexAPIUsage) == nil, "Codex API usage should not expose dashboard reauthentication")
require(DashboardReauthConfig(provider: .opencodeGo)?.requiredCookieNames == ["auth"], "OpenCode Go should auto-save only after auth cookies exist")
require(DashboardReauthConfig(provider: .querit)?.requiredCookieNames.contains("osduss") == true, "Querit should auto-save only after account cookies exist")
require(DashboardReauthConfig(provider: .codexSubscription)?.requiredCookieNames.joined(separator: "|").contains("__search-next-auth") == true, "Codex subscription should auto-save after any recognized ChatGPT auth cookie exists")
let codexRequiredCookies = Provider.codexSubscription.dashboardAuthenticationCookieNames
require(DashboardCookieBuilder.containsRequiredCookie(
    inCookieHeader: "__search-next-auth=chatgpt-session",
    requiredNames: codexRequiredCookies
), "Codex subscription should accept the observed __search-next-auth ChatGPT login cookie")
require(DashboardCookieBuilder.containsRequiredCookie(
    inCookieHeader: "__Secure-next-auth.session-token.0=part-a; __Secure-next-auth.session-token.1=part-b",
    requiredNames: codexRequiredCookies
), "Codex subscription should accept chunked NextAuth session cookies")

for provider in [Provider.querit, .xfyunCodingPlan, .volcengineCodingPlan, .opencodeGo, .claudeSubscription, .codexSubscription] {
    guard let config = DashboardReauthConfig(provider: provider) else {
        require(false, "\(provider.rawValue) should expose dashboard reauthentication config")
        continue
    }
    let completeCookies = config.requiredCookieNames.map { requirement in
        let name = String(requirement.split(separator: "|").first ?? Substring(requirement))
            .replacingOccurrences(of: ".*", with: "")
        return HTTPCookie(properties: [
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

let recoveredDefaults = UserDefaults(suiteName: "QuotaRadarMigrationRecoveryTests.\(UUID().uuidString)")!
let recoveredLegacyDefaults = UserDefaults(suiteName: "QuotaRadarMigrationRecoveryLegacyTests.\(UUID().uuidString)")!
let emptyMetadata = Data("[]".utf8)
let legacyMetadata = Data("[{\"name\":\"BRAVE_API_KEY\",\"provider\":\"Brave\"}]".utf8)
recoveredDefaults.set(true, forKey: LegacyConfigurationMigrator.migrationMarkerKey)
recoveredDefaults.set(emptyMetadata, forKey: "apiKeyMetadata")
recoveredLegacyDefaults.set(legacyMetadata, forKey: "apiKeyMetadata")
LegacyConfigurationMigrator.migrateUserDefaultsIfNeeded(defaults: recoveredDefaults, legacyDefaults: recoveredLegacyDefaults)
require(recoveredDefaults.data(forKey: "apiKeyMetadata") == legacyMetadata, "Legacy migration should recover old API metadata when the new Quota Radar domain only has an accidental empty list")

let userClearedDefaults = UserDefaults(suiteName: "QuotaRadarMigrationUserClearedTests.\(UUID().uuidString)")!
let userClearedLegacyDefaults = UserDefaults(suiteName: "QuotaRadarMigrationUserClearedLegacyTests.\(UUID().uuidString)")!
userClearedDefaults.set(true, forKey: LegacyConfigurationMigrator.migrationMarkerKey)
userClearedDefaults.set(emptyMetadata, forKey: "apiKeyMetadata")
userClearedDefaults.set(true, forKey: LegacyConfigurationMigrator.apiKeyMetadataClearedByUserKey)
userClearedLegacyDefaults.set(legacyMetadata, forKey: "apiKeyMetadata")
LegacyConfigurationMigrator.migrateUserDefaultsIfNeeded(defaults: userClearedDefaults, legacyDefaults: userClearedLegacyDefaults)
require(userClearedDefaults.data(forKey: "apiKeyMetadata") == emptyMetadata, "Legacy migration should not resurrect old API metadata after the user intentionally cleared credentials")

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

let clearedDefaults = UserDefaults(suiteName: "QuotaRadarClearedCredentialsTests.\(UUID().uuidString)")!
let clearedStore = APIKeyStore(defaults: clearedDefaults, secretStore: secretStore)
clearedStore.save([key])
require(!clearedDefaults.bool(forKey: "apiKeyMetadataClearedByUser"), "APIKeyStore should not mark credentials as user-cleared while credentials are present")
clearedStore.save([])
require(clearedDefaults.bool(forKey: "apiKeyMetadataClearedByUser"), "APIKeyStore should mark an intentionally saved empty credential list so legacy migration does not resurrect old keys")
clearedStore.save([key])
require(!clearedDefaults.bool(forKey: "apiKeyMetadataClearedByUser"), "APIKeyStore should clear the user-cleared marker after credentials are saved again")

let structuredKeyID = UUID()
let structuredKey = APIKey(
    id: structuredKeyID,
    name: "TAVILY_STRUCTURED",
    key: "tvly-structured",
    provider: .tavily,
    remaining: 850,
    limit: 1000,
    quotaText: LocalizedTextDescriptor.localized(.monthlyCreditsFormat, "850", "1000"),
    quotaLabel: "850 / 1000 monthly credits"
)
store.save([structuredKey])
let structuredMetadata = store.load()
require(structuredMetadata[0].quotaText?.key == .monthlyCreditsFormat, "APIKeyStore should persist structured quota descriptors")
AppLanguageStore.shared.language = .simplifiedChinese
require(structuredMetadata[0].quotaDisplayText == "850 / 1000 月度积分", "APIKey quota display should prefer structured descriptors over persisted English labels")
AppLanguageStore.shared.language = .english

let queritAPIKeyID = UUID()
let validQueritID = UUID()
let queritMetadata = """
[{"id":"\(queritAPIKeyID.uuidString)","name":"QUERIT_API_KEY","provider":"Querit","isActive":true,"quotaLabel":"凭据已过期","usageCount":0},{"id":"\(validQueritID.uuidString)","name":"QUERIT_COOKIE","provider":"Querit","isActive":true,"usageCount":0}]
"""
defaults.set(Data(queritMetadata.utf8), forKey: "apiKeyMetadata")
let migratedQuerit = store.load()
require(migratedQuerit.contains { $0.name == "QUERIT_API_KEY" && $0.provider == .querit && $0.isStoredAPIKeyOnlyCredential }, "APIKeyStore should keep Querit optional API-key records for copying")
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

func fail(_ message: String) {
    FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
    exit(1)
}

AppLanguageStore.shared.language = .simplifiedChinese
require(QuotaError.unauthorized.errorDescription == "API Key 无效", "QuotaError should emit localized invalid-key diagnostics in Simplified Chinese")
require(QuotaError.invalidResponse.errorDescription == "服务器响应无效", "QuotaError should emit localized invalid-response diagnostics in Simplified Chinese")
require(QuotaError.networkError(URLError(.timedOut)).errorDescription == "网络错误：请求超时", "QuotaError should emit localized timeout network diagnostics in Simplified Chinese")
require(QuotaError.networkError(URLError(.notConnectedToInternet)).errorDescription == "网络错误：网络离线", "QuotaError should emit localized offline network diagnostics in Simplified Chinese")
require(QuotaError.networkError(URLError(.networkConnectionLost)).errorDescription == "网络错误：连接中断", "QuotaError should emit localized connection-lost diagnostics in Simplified Chinese")
require(L10n.localizedQuotaLabel("Invalid API key", language: .simplifiedChinese) == "API Key 无效", "Persisted English invalid-key diagnostics should localize centrally")
require(L10n.localizedQuotaLabel("Network error: offline", language: .simplifiedChinese) == "网络错误：网络离线", "Persisted English network diagnostics should localize centrally")
require(L10n.localizedQuotaLabel("The request timed out.", language: .simplifiedChinese) == "网络错误：请求超时", "Bare URLSession timeout diagnostics should localize as network errors")
require(L10n.localizedQuotaLabel("The Internet connection appears to be offline.", language: .simplifiedChinese) == "网络错误：网络离线", "Bare URLSession offline diagnostics should localize as network errors")
require(L10n.localizedQuotaLabel("The network connection was lost.", language: .simplifiedChinese) == "网络错误：连接中断", "Bare URLSession connection-lost diagnostics should localize as network errors")
require(L10n.localizedQuotaLabel("A server with the specified hostname could not be found.", language: .simplifiedChinese) == "网络错误：找不到主机", "Bare URLSession host lookup diagnostics should localize as network errors")
require(L10n.localizedQuotaLabel("Could not connect to the server.", language: .simplifiedChinese) == "网络错误：无法连接服务器", "Bare URLSession connect diagnostics should localize as network errors")
let legacyChineseExpiredCredential = APIKey(name: "VOLC_COOKIE", key: "cookie", provider: .volcengineCodingPlan, quotaLabel: "凭据已过期")
require(legacyChineseExpiredCredential.isCredentialExpired, "Credential-expired status checks should recognize legacy Chinese labels")
let legacyChineseLimitExceeded = APIKey(name: "BRAVE_API_KEY", key: "brave", provider: .brave, quotaLabel: "额度已用尽")
require(legacyChineseLimitExceeded.isUsageLimitExceeded, "Usage-limit status checks should recognize legacy Chinese labels")
let legacyChineseNoSubscription = APIKey(name: "TENCENT_CLOUD_CODING_PLAN_COOKIE", key: "cookie", provider: .tencentCloudCodingPlan, quotaLabel: "未发现订阅套餐")
require(legacyChineseNoSubscription.isNoSubscribedPlan, "No-subscription status checks should recognize legacy Chinese labels")
require(L10n.localizedQuotaLabel("API Key 无效", language: .english) == "Invalid API key", "Persisted Chinese invalid-key diagnostics should relocalize when switching to English")
require(L10n.localizedQuotaLabel("服务器响应无效", language: .english) == "Invalid response from server", "Persisted Chinese invalid-response diagnostics should relocalize when switching to English")
require(L10n.localizedQuotaLabel("网络错误：网络离线", language: .english) == "Network error: offline", "Persisted Chinese network diagnostics should relocalize when switching to English")
let timedOutDiagnostic = APIKey(
    name: "WECHAT_API_KEY_TIMEOUT",
    key: "wechat",
    provider: .wxmp,
    lastDiagnosticMessage: "The request timed out."
)
require(timedOutDiagnostic.diagnosticSummary == "网络错误：请求超时", "Credential diagnostics should localize bare request-timeout errors")
AppLanguageStore.shared.language = .english
let localizedWeChatInvalidKey = APIKey(
    name: "WECHAT_API_KEY",
    key: "wechat",
    provider: .wxmp,
    lastHTTPStatus: 401,
    lastDiagnosticMessage: "API Key 无效",
    quotaLabel: "API Key 无效"
)
require(localizedWeChatInvalidKey.diagnosticSummary == "Invalid API key", "WeChat Search diagnostics should not keep a persisted Chinese invalid-key prompt after switching to English")
let persistedChineseExpiredCredential = APIKey(name: "WXMP_COOKIE", key: "wechat", provider: .wxmp, quotaLabel: "凭据已过期")
require(persistedChineseExpiredCredential.isCredentialExpired, "Persisted Chinese expired credential labels should still be recognized as expired")
require(persistedChineseExpiredCredential.healthDisplayText == "Expired", "Persisted Chinese expired credential labels should relocalize status after switching to English")
let tavily = try! QuotaParsers.parseTavilyUsage(Data("""
{"key":{"usage":150,"limit":1000},"account":{"plan_usage":500,"plan_limit":15000}}
""".utf8))
require(tavily.remaining == 850, "Tavily should use key limit when present")
require(tavily.limit == 1000, "Tavily key limit should be parsed")
require(tavily.quotaLabel == "850 / 1000 monthly credits", "Tavily should label free quota as monthly credits")
require(tavily.quotaText?.key == .monthlyCreditsFormat, "Tavily quota results should carry a structured localized text descriptor")
AppLanguageStore.shared.language = .simplifiedChinese
require(tavily.quotaText?.render() == "850 / 1000 月度积分", "Structured quota descriptors should render in the current UI language without parsing persisted English")
AppLanguageStore.shared.language = .english
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
require(brave.quotaText?.key == .monthlyRequestsFormat, "Brave monthly quota should carry a structured request quota descriptor")
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
require(braveExhausted.quotaText?.key == .usableUnknownQuota, "Brave hidden monthly quota should carry a structured usable-unknown descriptor")
let braveKnownManualQuota = QuotaParsers.applyKnownBraveMonthlyQuotaIfNeeded(
    braveExhausted,
    knownRemaining: 1000,
    knownLimit: 1000
)
require(braveKnownManualQuota.remaining == 999, "Known Brave monthly quotas should decrement once for the quota-check search")
require(braveKnownManualQuota.limit == 1000, "Known Brave monthly quota limit should be preserved when Brave hides the monthly header")
require(braveKnownManualQuota.quotaLabel == "999 / 1000 monthly requests", "Known Brave monthly quotas should display the known manual limit")
require(braveKnownManualQuota.quotaText?.key == .monthlyRequestsFormat, "Known Brave monthly quota should carry a structured request quota descriptor")

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
require(serper.quotaText?.key == .creditsLeftFormat, "Serper credit balance should carry a structured credits-left descriptor")
require(serper.resetAt == nil, "Serper account endpoint does not expose a reset date")
require(serper.planEndsAt == nil, "Serper account endpoint should not invent a subscription end date")

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
AppLanguageStore.shared.language = .simplifiedChinese
require(exaUsage.quotaText?.render() == "已用 USD 45.67", "Structured money descriptors should render usage in the current UI language")
AppLanguageStore.shared.language = .english

let deepSeek = try! QuotaParsers.parseDeepSeekBalance(Data("""
{"is_available":true,"balance_infos":[{"currency":"CNY","total_balance":"12.50","granted_balance":"0","topped_up_balance":"12.50"}]}
""".utf8))
require(deepSeek.remaining == 1250, "DeepSeek balance should be represented in cents")
require(deepSeek.quotaLabel == "CNY 12.50 available", "DeepSeek should display money, not fake request counts")
require(deepSeek.quotaText?.key == .moneyAvailableFormat, "DeepSeek balance should carry a structured money descriptor")

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
require(bocha.quotaText?.key == .moneyBalanceFormat, "Bocha balance should carry a structured money-balance descriptor")
require(bocha.resetAt == nil, "Bocha account balance should not invent a reset cycle")

let querit = try! QuotaParsers.parseQueritAccount(Data("""
{"ErrNo":200,"Msg":"success","Data":{"current_plan":{"plan_type":"free","free_usage_month":10,"coupon_quota":0,"coupon_used":0,"paid_usage_month":0,"enterprise_usage_month":0}}}
""".utf8))
require(querit.remaining == Int.max, "Querit should not invent a remaining quota when the dashboard exposes usage but no plan limit")
require(querit.limit == Int.max, "Querit should keep quota unknown when current_plan has no limit field and coupon quota is zero")
require(querit.quotaLabel == "10 monthly requests used", "Querit should display observed monthly usage instead of a fake free quota")
require(querit.quotaText?.key == .monthlyRequestsUsedFormat, "Querit usage-only results should carry a structured monthly-requests-used descriptor")
require(querit.resetAt == nil, "Querit account endpoint does not expose a reset date")
require(querit.planEndsAt == nil, "Querit account endpoint does not expose a plan end date")

let xfyun = try! QuotaParsers.parseXFYunCodingPlanList(Data("""
{"code":0,"data":{"rows":[{"name":"高效版","expiresAt":"2026-06-28 17:48:58","codingPlanUsageDTO":{"packageLeft":80704,"packageLimit":90000,"packageUsage":9296,"rp5hLimit":6000,"rp5hUsage":60,"rpwLimit":45000,"rpwUsage":9296}}]},"succeed":true}
""".utf8))
require(xfyun.remaining == 7934, "XFYun should represent the tightest coding-plan window as basis-point percentage remaining")
require(xfyun.limit == 10000, "XFYun coding-plan percentage limit should be 10000 basis points")
require(xfyun.quotaLabel == "5h 99% · week 79.3% · month 89.7%", "XFYun should display only remaining percentages")
AppLanguageStore.shared.language = .simplifiedChinese
require(xfyun.quotaText?.render() == "5 小时 99% · 周 79.3% · 月 89.7%", "Structured quota-window descriptors should render period labels in the current UI language")
AppLanguageStore.shared.language = .english
require(xfyun.quotaText?.quotaWindows.first(where: { $0.name == "5h" })?.remainingText == "5940 / 6000", "XFYun should preserve five-hour remaining and maximum request counts")
require(xfyun.quotaText?.quotaWindows.first(where: { $0.name == "week" })?.remainingText == "35704 / 45000", "XFYun should preserve weekly remaining and maximum request counts")
require(xfyun.quotaText?.quotaWindows.first(where: { $0.name == "month" })?.remainingText == "80704 / 90000", "XFYun should preserve monthly remaining and maximum request counts")
let xfyunDisplayKey = APIKey(name: "XFYUN_CODING_PLAN_COOKIE", key: "cookie", provider: .xfyunCodingPlan, quotaText: xfyun.quotaText, quotaLabel: xfyun.quotaLabel)
require(xfyunDisplayKey.quotaWindowDetails.count == 3, "XFYun should render cycle detail rows with remaining/maximum counts even when reset times are not exposed")
require(xfyun.resetAt == nil, "XFYun coding-plan list does not expose individual quota window reset dates")
require(xfyun.planEndsAt != nil, "XFYun should expose the package expiry as the plan end date")

let volc = try! QuotaParsers.parseVolcengineCodingPlanUsage(Data("""
{"ResponseMetadata":{"Action":"GetCodingPlanUsage"},"Result":{"Status":"Running","QuotaUsage":[{"Level":"session","Percent":0,"ResetTimestamp":-1},{"Level":"weekly","Percent":10.814960999999998,"ResetTimestamp":1780848000},{"Level":"monthly","Percent":5.407480499999999,"ResetTimestamp":1782921599}]}}
""".utf8))
require(volc.remaining == 8918, "Volcengine should use the tightest remaining usage window")
require(volc.limit == 10000, "Volcengine coding-plan percentage limit should be 10000 basis points")
require(volc.quotaLabel == "5h 100% · week 89.2% · month 94.6%", "Volcengine should display five-hour, weekly, and monthly usage windows")
require(volc.quotaText?.kind == .quotaWindows, "Volcengine coding plan should carry structured quota-window descriptors")
require(volc.quotaText?.quotaWindows.count == 3, "Volcengine should keep structured reset details for all quota windows")
require(volc.quotaText?.quotaWindows.first(where: { $0.name == "week" })?.resetAt != nil, "Volcengine weekly quota window should preserve its reset timestamp")
require(volc.quotaText?.quotaWindows.first(where: { $0.name == "month" })?.resetAt != nil, "Volcengine monthly quota window should preserve its reset timestamp")
require(volc.resetAt != nil, "Volcengine should expose the tightest finite reset timestamp")
require(volc.planEndsAt == nil, "Volcengine GetCodingPlanUsage does not expose the subscription end date")

let opencode = try! QuotaParsers.parseOpenCodeGoUsage(Data("""
;0x00000129;((self.$R=self.$R||{})["server-fn:11"]=[],($R=>$R[0]={mine:!0,useBalance:!1,rollingUsage:$R[1]={status:"ok",resetInSec:16946,usagePercent:2},weeklyUsage:$R[2]={status:"ok",resetInSec:547976,usagePercent:50},monthlyUsage:$R[3]={status:"ok",resetInSec:2204389,usagePercent:75}})($R["server-fn:11"]))
""".utf8))
require(opencode.remaining == 2500, "OpenCode Go should use the tightest remaining usage window")
require(opencode.limit == 10000, "OpenCode Go percentage limit should be 10000 basis points")
require(opencode.quotaLabel == "5h 98% · week 50% · month 25%", "OpenCode Go should display rolling, weekly, and monthly usage windows")
require(opencode.resetAt != nil && opencode.resetAt! > Date(), "OpenCode Go should convert resetInSec into a future reset date")
require(opencode.planEndsAt == nil, "OpenCode Go usage endpoint does not expose the subscription end date")

do {
    _ = try QuotaParsers.parseAliyunCodingPlanStatus(Data("""
{"code":"200","data":{"DataV2":{"data":{"data":{"hasCodingPlan":false,"clawQuota":0},"success":true,"failed":false},"success":true}},"successResponse":true}
""".utf8))
    fail("Aliyun Coding Plan should report noSubscription when aliclaw.coding-plan hasCodingPlan is false")
} catch QuotaError.noSubscription {
} catch {
    fail("Aliyun Coding Plan no-plan response should throw noSubscription, got \(error)")
}

let aliyunCodingPlan = try! QuotaParsers.parseAliyunCodingPlanStatus(Data("""
{"code":"200","data":{"DataV2":{"data":{"data":{"hasCodingPlan":true,"clawQuota":2,"codingPlanInfo":{"instanceType":"Lite","status":"VALID","startTime":1780858373000,"endTime":1783448373000,"remainingDays":30}},"success":true,"failed":false},"success":true}},"successResponse":true}
""".utf8))
require(aliyunCodingPlan.remaining == Int.max, "Aliyun Coding Plan should not invent a percentage quota when the dashboard only exposes subscription status")
require(aliyunCodingPlan.limit == Int.max, "Aliyun Coding Plan should keep unknown quota as unknown")
require(aliyunCodingPlan.quotaText?.key == .usableUnknownQuota, "Aliyun Coding Plan active subscriptions should display usable unknown quota until usage details are confirmed")
let aliyunDisplayKey = APIKey(name: "ALIYUN_CODING_PLAN_COOKIE", key: "cookie", provider: .aliyunCodingPlan, quotaText: aliyunCodingPlan.quotaText, quotaLabel: aliyunCodingPlan.quotaLabel)
require(aliyunDisplayKey.quotaWindowDetails.isEmpty, "Aliyun Coding Plan should not render cycle detail rows until a real usage sample exposes window counts")
require(aliyunCodingPlan.resetAt == nil, "Aliyun Coding Plan subscription-status endpoint should not treat the plan end as a quota reset")
require(aliyunCodingPlan.planEndsAt != nil, "Aliyun Coding Plan should expose the subscription end time when present")

let aliyunCodingPlanWithUsage = try! QuotaParsers.parseAliyunCodingPlanStatus(Data("""
{"code":"200","data":{"DataV2":{"data":{"data":{"hasCodingPlan":true,"clawQuota":2,"codingPlanInfo":{"instanceType":"Lite","status":"VALID","startTime":1780858373000,"endTime":1783448373000,"remainingDays":30,"usageDetail":{"perFiveHour":{"used":20,"total":1000},"perWeek":{"used":1200,"total":6000},"perMonth":{"used":2000,"total":10000}}}},"success":true,"failed":false},"success":true}},"successResponse":true}
""".utf8))
require(aliyunCodingPlanWithUsage.remaining == 8000, "Aliyun Coding Plan should use the tightest request-count window when the dashboard exposes usage details")
require(aliyunCodingPlanWithUsage.limit == 10000, "Aliyun Coding Plan usage-window percentage limit should be 10000 basis points")
require(aliyunCodingPlanWithUsage.quotaLabel == "5h 98% · week 80% · month 80%", "Aliyun Coding Plan should display usage windows when present")
require(aliyunCodingPlanWithUsage.quotaText?.kind == .quotaWindows, "Aliyun Coding Plan should carry structured quota-window descriptors when usage details are exposed")
require(aliyunCodingPlanWithUsage.quotaText?.quotaWindows.first(where: { $0.name == "5h" })?.remainingText == "980 / 1000", "Aliyun Coding Plan should preserve five-hour remaining and maximum request counts")
require(aliyunCodingPlanWithUsage.quotaText?.quotaWindows.first(where: { $0.name == "week" })?.remainingText == "4800 / 6000", "Aliyun Coding Plan should preserve weekly remaining and maximum request counts")
require(aliyunCodingPlanWithUsage.quotaText?.quotaWindows.first(where: { $0.name == "month" })?.remainingText == "8000 / 10000", "Aliyun Coding Plan should preserve monthly remaining and maximum request counts")
require(aliyunCodingPlanWithUsage.resetAt == nil, "Aliyun Coding Plan usage count sample does not expose reset timestamps")
require(aliyunCodingPlanWithUsage.planEndsAt != nil, "Aliyun Coding Plan usage details should preserve the package end time")

let tencentCodingPlan = try! QuotaParsers.parseTencentCloudCodingPlanDescribePkg(Data("""
{"code":0,"data":{"code":0,"cgwerrorCode":0,"data":{"Response":{"RequestId":"request-redacted","PkgList":[{"PkgName":"Lite","PkgType":"lite","Status":"Normal","StartTime":"2026-06-01 00:00:00","EndTime":"2026-07-01 00:00:00","RemainingDays":22,"UsageDetail":{"PerFiveHour":{"Used":12,"Total":1200,"UsagePercent":1,"EndTime":"2026-06-08 06:00:00"},"PerWeek":{"Used":900,"Total":9000,"UsagePercent":10,"EndTime":"2026-06-15 00:00:00"},"PerMonth":{"Used":3600,"Total":18000,"UsagePercent":20,"EndTime":"2026-07-01 00:00:00"}}}]}}},"mccode":0}
""".utf8))
require(tencentCodingPlan.remaining == 8000, "Tencent Cloud Coding Plan should use the tightest remaining quota window")
require(tencentCodingPlan.limit == 10000, "Tencent Cloud Coding Plan percentage limit should be 10000 basis points")
require(tencentCodingPlan.quotaLabel == "5h 99% · week 90% · month 80%", "Tencent Cloud Coding Plan should display DescribePkg usage windows")
require(tencentCodingPlan.quotaText?.kind == .quotaWindows, "Tencent Cloud Coding Plan should carry structured quota-window descriptors")
require(tencentCodingPlan.quotaText?.quotaWindows.first(where: { $0.name == "5h" })?.remainingText == "1188 / 1200", "Tencent Cloud Coding Plan should preserve five-hour remaining and maximum request counts")
require(tencentCodingPlan.quotaText?.quotaWindows.first(where: { $0.name == "week" })?.remainingText == "8100 / 9000", "Tencent Cloud Coding Plan should preserve weekly remaining and maximum request counts")
require(tencentCodingPlan.quotaText?.quotaWindows.first(where: { $0.name == "month" })?.remainingText == "14400 / 18000", "Tencent Cloud Coding Plan should preserve monthly remaining and maximum request counts")
require(tencentCodingPlan.resetAt != nil, "Tencent Cloud Coding Plan should expose the tightest quota window reset timestamp")
require(tencentCodingPlan.planEndsAt != nil, "Tencent Cloud Coding Plan should expose the package EndTime as the plan end date")

let codexUsage = try! QuotaParsers.parseCodexWhamUsage(Data("""
{"plan_type":"pro","rate_limit":{"allowed":true,"limit_reached":false,"primary_window":{"used_percent":0,"limit_window_seconds":18000,"reset_after_seconds":18000,"reset_at":1780924878},"secondary_window":{"used_percent":70,"limit_window_seconds":604800,"reset_after_seconds":233270,"reset_at":1781140147}},"additional_rate_limits":[{"limit_name":"GPT-5.3-Codex-Spark","rate_limit":{"allowed":true,"limit_reached":false,"primary_window":{"used_percent":0,"limit_window_seconds":18000,"reset_after_seconds":18000,"reset_at":1780924878},"secondary_window":{"used_percent":0,"limit_window_seconds":604800,"reset_after_seconds":604800,"reset_at":1781511678}}}],"credits":{"has_credits":false,"unlimited":false,"balance":"0"}}
""".utf8))
require(codexUsage.remaining == 3000, "Codex subscription usage should use the tightest remaining quota window")
require(codexUsage.limit == 10000, "Codex subscription usage should use percentage basis points")
require(codexUsage.quotaLabel == "5h 100% · week 30%", "Codex subscription usage should display five-hour and weekly windows")
require(codexUsage.quotaText?.kind == .quotaWindows, "Codex subscription usage should carry structured quota-window descriptors")
require(codexUsage.resetAt != nil, "Codex subscription usage should expose the tightest quota window reset date")
require(codexUsage.planEndsAt == nil, "Codex wham usage does not expose subscription end date")
let codexPlanEndsAt = try! QuotaParsers.parseCodexSubscriptionLifecycle(Data("""
{"active_start":"2026-06-08T16:42:25Z","active_until":"2026-07-08T16:42:25Z","billing_period":"monthly","plan_type":"pro","will_renew":true}
""".utf8))
require(codexPlanEndsAt != nil, "Codex subscription lifecycle should parse active_until as the plan end date")

do {
    _ = try QuotaParsers.parseTencentCloudCodingPlanDescribePkg(Data("""
{"code":0,"data":{"code":0,"cgwerrorCode":0,"data":{"Response":{"RequestId":"request-redacted","PkgList":[]}}},"mccode":0}
""".utf8))
    fail("Tencent Cloud Coding Plan should report noSubscription when DescribePkg returns an empty package list")
} catch QuotaError.noSubscription {
} catch {
    fail("Tencent Cloud Coding Plan empty package list should throw noSubscription, got \(error)")
}

let tencentTokenPlan = try! QuotaParsers.parseTencentCloudTokenPlanApiKey(Data("""
{"Response":{"ApiKey":{"ApiKeyId":"ak-tp-redacted","Status":"enable","StopReason":"NORMAL"},"Balance":{"ExclusiveQuota":"500000","ExclusiveUsed":"100000","ExclusiveRemain":"400000","SharedQuota":"300000","SharedUsed":"50000","SharedRemain":"250000","Status":0},"RequestId":"request-redacted"}}
""".utf8))
require(tencentTokenPlan.remaining == 650000, "Tencent Cloud Token Plan should add exclusive and shared remaining quota")
require(tencentTokenPlan.limit == 800000, "Tencent Cloud Token Plan should add exclusive and shared quota limits")
require(tencentTokenPlan.quotaLabel == "650000 / 800000 tokens", "Tencent Cloud Token Plan should display token quota")
require(tencentTokenPlan.quotaText?.key == .tokenQuotaFormat, "Tencent Cloud Token Plan should carry a structured token quota descriptor")

SWIFT

swiftc QuotaRadar/Models/AppLanguage.swift QuotaRadar/Models/APIKey.swift QuotaRadar/Services/QuotaService.swift "$TMP_DIR/main.swift" -o "$TMP_DIR/quota-parser-test"
"$TMP_DIR/quota-parser-test"

echo "== SwiftPM build =="
swift build

echo "== App bundle build =="
./install.sh --bundle-only --rebuild
test -x "build/Quota Radar.app/Contents/MacOS/QuotaRadar" || fail "app bundle executable is missing"
test -f "build/Quota Radar.app/Contents/Resources/QuotaRadar.icns" || fail "app bundle icon is missing"
test -d "build/Quota Radar.app/Contents/Resources/QuotaRadar_QuotaRadar.bundle" || fail "app bundle SwiftPM resource bundle is missing"
plutil -extract CFBundleExecutable raw "build/Quota Radar.app/Contents/Info.plist" | rg '^QuotaRadar$' >/dev/null || fail "bundle executable name is wrong"
plutil -extract CFBundleIconFile raw "build/Quota Radar.app/Contents/Info.plist" | rg '^QuotaRadar$' >/dev/null || fail "bundle icon name is wrong"
plutil -extract CFBundleDisplayName raw "build/Quota Radar.app/Contents/Info.plist" | rg '^Quota Radar$' >/dev/null || fail "bundle display name is wrong"
codesign --verify --deep --strict --verbose=2 "build/Quota Radar.app" >/dev/null

echo "All behavior tests passed"
