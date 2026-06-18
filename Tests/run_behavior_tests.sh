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
assert_match '^quotaradar-\*\.png$' \
  ".gitignore" \
  "Root-level ad-hoc QuotaRadar screenshot captures should stay out of the release surface"
assert_match '^task\*\.png$' \
  ".gitignore" \
  "Root-level temporary task screenshots should stay out of the release surface"
assert_match '^tauri-\*\.png$' \
  ".gitignore" \
  "Root-level parity screenshots should stay out of the release surface"
assert_match 'CFBundleIconFile' \
  "QuotaRadar/Info.plist" \
  "Info.plist must declare the app icon file"
assert_match 'CFBundleDisplayName' \
  "QuotaRadar/Info.plist" \
  "Info.plist must declare the Finder display name"
assert_match 'Quota Radar' \
  "QuotaRadar/Info.plist" \
  "App bundle display name should be Quota Radar"
assert_match '0\.3\.5' \
  "QuotaRadar/Info.plist" \
  "Quota Radar 0.3.5 should be recorded in Info.plist"
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
for icon_name in claude codex kimi; do
  test -s "QuotaRadar/Assets.xcassets/ProviderIcons/${icon_name}.iconset/icon_32x32@2x.png" \
    || fail "Claude/Codex/Kimi provider icon asset is missing: ${icon_name}"
done
python3 - <<'PY'
from pathlib import Path
import re
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
assert_match 'docs/assets/screenshots/en/quota-overview\.png' \
  "README.md" \
  "Default README should show the English quota overview screenshot"
assert_match 'docs/assets/screenshots/en/menu-bar-popover\.png' \
  "README.md" \
  "Default README should show the English menu bar popover screenshot"
assert_match 'captured from the running app, with credentials masked by Quota Radar' \
  "README.md" \
  "Default README should clarify that public screenshots use masked real app captures"
assert_no_match 'docs/assets/screenshots/zh-Hans/' \
  "README.md" \
  "Default README should not link to Simplified Chinese screenshots"
assert_match 'docs/assets/screenshots/zh-Hans/quota-overview\.png' \
  "README.zh-Hans.md" \
  "Chinese README should show the Simplified Chinese quota overview screenshot"
assert_match 'docs/assets/screenshots/zh-Hans/menu-bar-popover\.png' \
  "README.zh-Hans.md" \
  "Chinese README should show the Simplified Chinese menu bar popover screenshot"
assert_match '真实运行画面，密钥由应用自动打码' \
  "README.zh-Hans.md" \
  "Chinese README should clarify that public screenshots use masked real app captures"
assert_no_match 'docs/assets/screenshots/en/' \
  "README.zh-Hans.md" \
  "Chinese README should not link to English screenshots"
python3 - <<'PY'
from pathlib import Path
import sys

for path, limit in [("README.md", 140), ("README.zh-Hans.md", 140)]:
    line_count = len(Path(path).read_text().splitlines())
    if line_count > limit:
        print(f"FAIL: {path} should stay as a concise project entry ({line_count} lines > {limit})", file=sys.stderr)
        sys.exit(1)
PY
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
assert_match 'orderedVisibleCases\(from storedOrder:' \
  "QuotaRadar/Models/APIKey.swift" \
  "Provider UI lists should support a persisted custom provider order while filtering stale hidden providers"
assert_match 'static let categoryDisplayOrder = \["AI Search", "LLM"\]' \
  "QuotaRadar/Models/APIKey.swift" \
  "Provider category display order should be defined once as AI Search before LLM"
assert_match 'Provider\.categoryDisplayOrder\.compactMap' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Status bar provider category groups should use the shared AI Search then LLM order"
assert_match 'orderedVisibleProviders' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should expose one persisted provider order source for every page and the status bar"
assert_match 'isCustomProviderOrderEnabled' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Provider order customization should be explicitly gated so users can keep the product-defined locked order"
assert_match 'Toggle\("", isOn: \$monitor\.isCustomProviderOrderEnabled\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings should expose a switch that unlocks or locks custom provider ordering"
assert_match '@State private var showingProviderOrderSheet = false' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider order configuration should open from Settings as a focused sheet instead of occupying the quota overview page"
assert_match 'ProviderOrderSheet\(monitor: monitor\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings should present a provider order sheet for focused ordering work"
assert_match 'ProviderOrderDragRow' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider order editing should use draggable rows instead of one-by-one move buttons"
assert_match 'ProviderOrderSheetToolbar' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider order sheet should use a compact preference toolbar instead of a large content-page header"
assert_match 'ProviderOrderCategoryCard' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider order sheet should render each category as a compact material list card"
assert_match 'ProviderOrderCategoryHeader' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider order category cards should use compact list headers with counts"
assert_match '\.onDrag' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider order rows should support direct drag reordering"
assert_match '\.onDrop' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider order rows should accept drops for direct drag reordering"
assert_no_match 'ProviderOrderPanel\(monitor: monitor\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota overview should not embed provider-order configuration as a second settings page"
assert_no_match 'moveProviderUp|moveProviderDown' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider order editing should not rely on repetitive up/down move buttons"
assert_no_match 'arrow\.up\.arrow\.down\.circle\.fill' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider order sheet should avoid a large decorative header icon that makes the utility panel feel heavy"
assert_no_match 'SettingsFootnote\(icon: "hand\.draw\.fill"' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider order sheet should avoid a separate oversized instruction block inside the list"
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
assert_match 'enum QuotaActionKind' \
  "QuotaRadar/Models/APIKey.swift" \
  "Provider capability metadata should centralize quota action semantics"
assert_match 'let supportsQuota: Bool' \
  "QuotaRadar/Models/APIKey.swift" \
  "Provider capability metadata should explicitly state whether quota is observable"
assert_match 'let supportsBalance: Bool' \
  "QuotaRadar/Models/APIKey.swift" \
  "Provider capability metadata should explicitly state whether balance is observable"
assert_match 'let supportsPlan: Bool' \
  "QuotaRadar/Models/APIKey.swift" \
  "Provider capability metadata should explicitly state whether plan metadata is observable"
assert_match 'let supportsActivity: Bool' \
  "QuotaRadar/Models/APIKey.swift" \
  "Provider capability metadata should explicitly state whether recent activity can be inferred"
assert_match 'let supportsReset: Bool' \
  "QuotaRadar/Models/APIKey.swift" \
  "Provider capability metadata should explicitly state whether reset timing is observable"
assert_match 'let connectionTestKind: QuotaActionKind' \
  "QuotaRadar/Models/APIKey.swift" \
  "Provider capability metadata should distinguish no-cost connection tests from quota refresh"
assert_match 'let quotaRefreshKind: QuotaActionKind' \
  "QuotaRadar/Models/APIKey.swift" \
  "Provider capability metadata should distinguish normal quota refresh from costly checks"
assert_match 'let allowsAutomaticRefresh: Bool' \
  "QuotaRadar/Models/APIKey.swift" \
  "Provider capability metadata should be the source of automatic refresh eligibility"
assert_match 'let requiresCostlyConfirmation: Bool' \
  "QuotaRadar/Models/APIKey.swift" \
  "Provider capability metadata should mark providers that need costly-check confirmation"
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
assert_match 'docs/providers\.md' \
  "README.md" \
  "Default README should link provider documentation"
assert_match 'docs/providers\.zh-Hans\.md' \
  "README.zh-Hans.md" \
  "Chinese README should link provider documentation"
assert_match '已验证接入: .*腾讯云 coding plan' \
  "docs/roadmap.zh-Hans.md" \
  "Chinese roadmap should classify Tencent Cloud Coding Plan as a verified integration"
assert_match 'Verified integrations: .*Tencent Cloud Coding Plan' \
  "docs/roadmap.md" \
  "English roadmap should classify Tencent Cloud Coding Plan as a verified integration"
assert_match '阿里云 coding plan' \
  "docs/providers.zh-Hans.md" \
  "Chinese provider capability matrix should document Aliyun Coding Plan with localized provider copy"
assert_match 'Tencent Cloud Token Plan' \
  "docs/providers.md" \
  "English provider capability matrix should document Tencent Cloud Token Plan"
assert_match 'Coding plan 计量口径' \
  "docs/providers.zh-Hans.md" \
  "Chinese provider capability matrix should document how Coding Plan quotas are measured"
assert_match 'Token plan 计量口径' \
  "docs/providers.zh-Hans.md" \
  "Chinese provider capability matrix should document how Token Plan quotas are measured"
assert_match 'Token Plan Measurement' \
  "docs/providers.md" \
  "English provider capability matrix should document Token Plan measurement semantics"
assert_match 'Usage-only fields are parser evidence; the main UI still shows "Usable · quota unknown" until a remaining value or plan limit is exposed\.' \
  "docs/providers.md" \
  "English provider docs should separate raw usage-only evidence from remaining-first UI semantics"
assert_match 'usage-only 原始字段只作为解析证据；主界面仍显示“可用 · 额度未知”，直到接口暴露剩余额度或套餐上限。' \
  "docs/providers.zh-Hans.md" \
  "Chinese provider docs should separate raw usage-only evidence from remaining-first UI semantics"
assert_no_match 'Quota Radar 会显示该 key 在指定周期内的已用成本|可读月度已用量' \
  "README.zh-Hans.md" \
  "Chinese README should not describe usage-only provider evidence as the main quota display"
assert_no_match '有管理凭据时可查已用成本|已用量可查，上限未知' \
  "docs/providers.zh-Hans.md" \
  "Chinese provider matrix should not make usage-only fields look like a quota display mode"
assert_match '腾讯云 Token plan.*token' \
  "docs/providers.zh-Hans.md" \
  "Chinese provider capability matrix should state the current Tencent Cloud Token Plan unit"
assert_match '阿里云 Token plan.*积分' \
  "docs/providers.zh-Hans.md" \
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
assert_match 'Claude Subscription' \
  "README.md" \
  "Default README should list Claude as a currently supported provider"
assert_match '\| Claude \|' \
  "README.zh-Hans.md" \
  "Chinese README should list Claude as a currently supported provider"
assert_match 'unsigned DMG' \
  "README.md" \
  "README should clearly label the no-fee GitHub Release path as an unsigned DMG"
assert_match "xattr -dr com\\.apple\\.quarantine '/Applications/Quota Radar\\.app'" \
  "README.md" \
  "README should document how trusted users can remove Gatekeeper quarantine from an unsigned app"
assert_match '未签名 DMG' \
  "README.zh-Hans.md" \
  "Chinese README should clearly label the no-fee GitHub Release path as an unsigned DMG"
assert_match "xattr -dr com\\.apple\\.quarantine '/Applications/Quota Radar\\.app'" \
  "README.zh-Hans.md" \
  "Chinese README should document how trusted users can remove Gatekeeper quarantine from an unsigned app"
assert_match 'gh release create' \
  "README.md" \
  "README should document manual GitHub Release upload for unsigned DMGs"
assert_match 'gh release create' \
  "README.zh-Hans.md" \
  "Chinese README should document manual GitHub Release upload for unsigned DMGs"
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
assert_match 'final class GitHubReleaseUpdater' \
  "QuotaRadar/Services/GitHubReleaseUpdater.swift" \
  "QuotaRadar should include a GitHub Release updater service"
assert_match 'https://api\.github\.com/repos/Asklear/QuotaRadar/releases/latest' \
  "QuotaRadar/Services/GitHubReleaseUpdater.swift" \
  "Updater should check the Asklear/QuotaRadar latest GitHub Release endpoint"
assert_match 'https://github\.com/Asklear/QuotaRadar/releases/latest' \
  "QuotaRadar/Services/GitHubReleaseUpdater.swift" \
  "Updater should fall back to the GitHub latest-release redirect when the unauthenticated API is rate limited"
assert_match 'releases/download' \
  "QuotaRadar/Services/GitHubReleaseUpdater.swift" \
  "Updater fallback should construct the release asset download URL from the resolved release tag"
assert_match 'QuotaRadar\.dmg' \
  "QuotaRadar/Services/GitHubReleaseUpdater.swift" \
  "Updater should select the published QuotaRadar.dmg release asset"
assert_match 'releaseNotes' \
  "QuotaRadar/Services/GitHubReleaseUpdater.swift" \
  "Updater should preserve GitHub release notes for the update prompt"
assert_match 'downloadAndInstall' \
  "QuotaRadar/Services/GitHubReleaseUpdater.swift" \
  "Updater should provide a download-and-install flow instead of only opening the browser"
assert_match 'hdiutil attach' \
  "QuotaRadar/Services/GitHubReleaseUpdater.swift" \
  "Updater install flow should mount the downloaded DMG"
assert_match 'ditto' \
  "QuotaRadar/Services/GitHubReleaseUpdater.swift" \
  "Updater install flow should copy the downloaded app bundle over the installed app"
assert_match 'xattr -dr com\.apple\.quarantine' \
  "QuotaRadar/Services/GitHubReleaseUpdater.swift" \
  "Updater install flow should clear quarantine for trusted unsigned GitHub Release builds"
assert_match 'open -a' \
  "QuotaRadar/Services/GitHubReleaseUpdater.swift" \
  "Updater install flow should relaunch Quota Radar after replacing the app"
assert_match 'checkForUpdatesIfNeededOnLaunch' \
  "QuotaRadar/AppDelegate.swift" \
  "QuotaRadar should automatically check GitHub Releases after launch"
assert_match 'Check for Updates' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Updater controls should have English localization"
assert_match '检查更新' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Updater controls should have Simplified Chinese localization"
assert_match 'L10n\.t\(\.checkForUpdates\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings should expose a localized Check for Updates action"
assert_match 'SidebarUpdateFooter' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings sidebar should keep version and update status in the lower-left footer"
assert_match 'case sidebarStatistics' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Settings sidebar metrics should have a dedicated Statistics label instead of reusing the product name"
assert_match 'Text\(L10n\.t\(\.sidebarStatistics\)\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings sidebar metrics should be headed by Statistics, not Quota Radar"
python3 - <<'PY'
from pathlib import Path
import sys

source = Path("QuotaRadar/Views/SettingsView.swift").read_text()
try:
    sidebar = source.split("struct SettingsSidebarView: View", 1)[1].split("struct SidebarUpdateFooter: View", 1)[0]
except IndexError:
    print("FAIL: SettingsSidebarView should exist before sidebar footer", file=sys.stderr)
    sys.exit(1)

try:
    metrics = sidebar.split("VStack(alignment: .leading, spacing: 10)", 1)[1].split("Spacer()", 1)[0]
except IndexError:
    print("FAIL: Settings sidebar metrics block should exist above the sidebar footer", file=sys.stderr)
    sys.exit(1)

if "L10n.t(.apiQuotaTitle)" in metrics:
    print("FAIL: Settings sidebar metrics should not repeat the Quota Radar product title", file=sys.stderr)
    sys.exit(1)
if "L10n.t(.sidebarStatistics)" not in metrics:
    print("FAIL: Settings sidebar metrics should use the localized Statistics heading", file=sys.stderr)
    sys.exit(1)
PY
assert_match 'Text\(L10n\.t\(\.version\)\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings sidebar footer should show the installed app version"
assert_match 'updater\.checkForUpdatesFromUI\(\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings sidebar footer should provide a manual update check action"
assert_no_match 'SettingsFormSection\(title: L10n\.t\(\.settingsUpdateSection\)\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Update checks should not occupy a full settings content section"
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
python3 - <<'PY'
from pathlib import Path
import re
import sys

source = Path("QuotaRadar/Views/SettingsView.swift").read_text()
try:
    diagnostics = source.split("struct DiagnosticsView: View", 1)[1].split("struct CredentialDiagnosticProviderSection", 1)[0]
    diagnostic_section = source.split("struct CredentialDiagnosticProviderSection: View", 1)[1].split("struct CredentialDiagnosticRow", 1)[0]
except IndexError:
    print("FAIL: Diagnostics view structure should be present", file=sys.stderr)
    sys.exit(1)

if "monitor.orderedVisibleProviders.compactMap" not in diagnostics:
    print("FAIL: Diagnostics should use the same custom provider order as credentials and quota monitoring", file=sys.stderr)
    sys.exit(1)
if "credentialDiagnosticItems.isEmpty" not in diagnostics:
    print("FAIL: Diagnostics should hide providers that do not have any diagnostic credential group configured", file=sys.stderr)
    sys.exit(1)
if "ProviderQuotaEmptyKeyRow()" in diagnostic_section:
    print("FAIL: Diagnostics should not render empty credential placeholder rows for providers without configured credentials", file=sys.stderr)
    sys.exit(1)
PY
assert_match 'diagnosticCredentialGroupCountText' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Diagnostics provider headers should count logical credential groups instead of raw saved API key records"
assert_match 'enum CredentialConfigurationState' \
  "QuotaRadar/Models/APIKey.swift" \
  "Credential configuration state should be modeled explicitly"
assert_match 'var credentialConfigurationState: CredentialConfigurationState' \
  "QuotaRadar/Models/APIKey.swift" \
  "APIKey should expose a computed credential configuration state"
assert_match 'case configuredUntested' \
  "QuotaRadar/Models/APIKey.swift" \
  "Credential states should distinguish configured but untested credentials"
assert_no_match 'DiagnosticMetadataGrid' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Diagnostics should stay focused and not render low-level metadata grids by default"
assert_match 'struct DiagnosticDebugDisclosure' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Diagnostics should keep low-level HTTP and network details behind an explicit disclosure"
python3 - <<'PY'
from pathlib import Path
import sys

source = Path("QuotaRadar/Views/SettingsView.swift").read_text()
try:
    diagnostic_row = source.split("struct CredentialDiagnosticRow: View", 1)[1].split("struct DiagnosticDebugDisclosure", 1)[0]
    debug_disclosure = source.split("struct DiagnosticDebugDisclosure: View", 1)[1].split("struct DiagnosticDebugRow", 1)[0]
except IndexError:
    print("FAIL: Diagnostics should separate default rows from debug disclosures", file=sys.stderr)
    sys.exit(1)

for marker, message in [
    ("L10n.t(.lastHTTPStatus)", "raw HTTP status"),
    ("requestProxyModeText", "configured proxy mode"),
    ("autoRefreshSkipText", "auto-refresh skip metadata"),
]:
    if marker in diagnostic_row:
        print(f"FAIL: Diagnostics should not expose {message} in the default credential row", file=sys.stderr)
        sys.exit(1)

for marker, message in [
    ("DisclosureGroup", "an explicit disclosure control"),
    ("L10n.t(.lastHTTPStatus)", "HTTP status"),
    ("item.requestProxyModeText", "proxy mode"),
    ("item.autoRefreshSkipText", "auto-refresh skip metadata"),
    ("item.resetDiagnosticText", "reset diagnostics"),
    ("item.lastCheckedText", "last checked diagnostics"),
]:
    if marker not in debug_disclosure:
        print(f"FAIL: Diagnostic debug disclosure should render {message}", file=sys.stderr)
        sys.exit(1)
PY
assert_match 'key\.credentialConfigurationState\.displayText' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential rows should render explicit configuration state labels"
assert_match 'key\.credentialConfigurationState\.color' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential state labels should use the state color"
assert_no_match 'testConnectionForProvider' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should not expose duplicate provider-level connection testing when refresh already performs the quota check"
assert_no_match 'onTestConnection' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota monitor rows should not expose a duplicate Test Connection action"
assert_no_match 'TestConnectionButton\(size: size, action: onTestConnection\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "The quota page provider action group should use refresh as the single quota-check action"
assert_no_match 'showingCostlyTestConfirmation' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota monitor rows should not keep stale costly-test confirmation state after removing duplicate Test Connection"
assert_match 'refreshingQuotaAction' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Refresh controls should expose a distinct in-progress quota refresh state instead of reusing Test Connection wording"
assert_match 'refreshQuotaConsumesQuotaAction' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Refresh controls should clearly mark providers whose manual refresh spends one real request"
assert_match 'private var refreshActionLabel: String' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider refresh buttons should derive one clear label from refresh state and quota-consumption behavior"
assert_match 'isRefreshing \? L10n\.t\(\.refreshingQuotaAction\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider refresh buttons should announce when quota refresh is already running"
assert_match 'provider\.capability\.requiresCostlyConfirmation \? L10n\.t\(\.refreshQuotaConsumesQuotaAction\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider refresh buttons should warn when refreshing quota consumes a real request"
assert_match 'struct ProviderRefreshButton' \
  "QuotaRadar/Views/Components.swift" \
  "Provider refresh controls should centralize costly-check confirmation"
assert_match '@State private var showingCostlyRefreshConfirmation = false' \
  "QuotaRadar/Views/Components.swift" \
  "Costly provider refreshes should show an explicit confirmation before spending real quota"
assert_match 'provider\.capability\.requiresCostlyConfirmation' \
  "QuotaRadar/Views/Components.swift" \
  "The provider refresh gate should use ProviderCapability for costly-check semantics"
assert_match 'private var defaultActionLabel: String' \
  "QuotaRadar/Views/Components.swift" \
  "Provider refresh controls should derive a provider-aware default tooltip for every surface"
assert_match 'provider\.capability\.requiresCostlyConfirmation \? L10n\.t\(\.refreshQuotaConsumesQuotaAction\)' \
  "QuotaRadar/Views/Components.swift" \
  "Provider refresh controls should warn about costly refresh even when callers omit a custom label"
assert_match 'helpText \?\? defaultActionLabel' \
  "QuotaRadar/Views/Components.swift" \
  "Provider refresh controls should use the provider-aware default tooltip"
assert_match 'accessibilityLabelText \?\? defaultActionLabel' \
  "QuotaRadar/Views/Components.swift" \
  "Provider refresh controls should expose the provider-aware default accessibility label"
assert_match 'confirmationDialog\(L10n\.t\(\.costlyQuotaRefreshTitle\)' \
  "QuotaRadar/Views/Components.swift" \
  "Costly refresh confirmation should use refresh-specific wording instead of connection-test wording"
assert_match 'Button\(L10n\.t\(\.refreshQuotaConsumesQuotaAction\), role: \.destructive' \
  "QuotaRadar/Views/Components.swift" \
  "Costly refresh confirmation should require an explicit destructive confirmation action"
assert_match 'ProviderRefreshButton\(' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider quota rows should use the centralized provider refresh gate"
assert_match 'savedKey\.provider\.capability\.quotaRefreshKind == \.refreshQuota' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Saving a credential should only auto-refresh no-cost quota refresh providers"
assert_match 'struct QuotaSnapshot' \
  "QuotaRadar/Models/QuotaHistory.swift" \
  "Quota history should persist refresh snapshots"
assert_match 'enum QuotaSnapshotOutcome' \
  "QuotaRadar/Models/QuotaHistory.swift" \
  "Quota history should record refresh outcome without raw secrets"
assert_match 'struct QuotaHistoryStore' \
  "QuotaRadar/Services/QuotaHistoryStore.swift" \
  "Quota history should use a dedicated store"
assert_match 'quota-history\.json' \
  "QuotaRadar/Services/QuotaHistoryStore.swift" \
  "Quota history should persist outside API key metadata"
assert_match 'companionAPIKey' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Diagnostics rows should explain saved invocation API keys inside the paired quota-monitoring authorization row"
assert_match 'L10n\.t\(\.includesInvocationAPIKey\)' \
  "QuotaRadar/Models/APIKey.swift" \
  "Diagnostics rows should describe companion API keys tersely inside the paired authorization row"
assert_no_match 'item\.diagnosticSummary' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Diagnostics should not render quota-oriented diagnostic summaries in the main diagnostics list"
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
test -x "Tests/run_visual_qa.sh" || fail "Visual QA should be scriptable through Tests/run_visual_qa.sh"
assert_match 'QUOTARADAR_SHOW_STATUS_PANEL_FOR_AUTOMATION=1' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should use the existing automation hook to open the menu bar panel"
assert_match 'CGWindowListCopyWindowInfo' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should record real window coordinates so menu bar clipping can be diagnosed"
assert_match 'screencapture' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should capture visible app surfaces for manual review"
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
assert_match 'mode == \.automatic && !key\.provider\.capability\.allowsAutomaticRefresh' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Automatic refreshes must use provider capability instead of raw provider flags"
assert_match 'key\.provider\.capability\.matchesAutomaticRefreshLane\(consumesSearchQuota: consumesSearchQuota\)' \
  "QuotaRadar/Models/APIKey.swift" \
  "Automatic refresh due checks should use provider capability as the single source of truth"
assert_match 'case quotaConsumingAutomatic' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Quota-consuming providers should have a separate automatic refresh mode from normal free checks"
assert_match 'func refreshQuotaConsumingProviders\(mode: RefreshMode = \.quotaConsumingAutomatic\)' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Quota-consuming providers should be refreshed by their own long-cadence timer"
assert_match 'func providersDueForAutomaticRefresh' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should expose provider-level due checks based on persisted last refresh timestamps"
assert_match 'key\.lastUpdated == nil' \
  "QuotaRadar/Models/APIKey.swift" \
  "Automatic refresh due checks should refresh credentials that have never been checked"
assert_match 'now\.timeIntervalSince\(lastUpdated\) >= interval' \
  "QuotaRadar/Models/APIKey.swift" \
  "Automatic refresh due checks should use lastUpdated instead of resetting cadence on app launch"
assert_match 'quotaMonitor\.refreshProvidersDueForAutomaticRefresh\(interval: interval, consumesSearchQuota: false, mode: \.automatic\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Background timer refreshes should refresh only providers whose persisted last refresh is due"
assert_match 'quotaMonitor\.refreshProvidersDueForAutomaticRefresh\(interval: interval, consumesSearchQuota: true, mode: \.quotaConsumingAutomatic\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Quota-consuming automatic refresh should catch up after restart when the saved last refresh is older than the configured interval"
assert_no_match 'quotaMonitor\.refreshAll\(mode: \.automatic\)' \
  "QuotaRadar/AppDelegate.swift" \
  "AppDelegate should not blindly refresh every normal provider on every launch"
assert_no_match 'quotaMonitor\.refreshQuotaConsumingProviders\(mode: \.quotaConsumingAutomatic\)' \
  "QuotaRadar/AppDelegate.swift" \
  "AppDelegate should not wait a full new interval after every launch before refreshing quota-consuming providers"
assert_match 'configureAutoRefreshTimer' \
  "QuotaRadar/AppDelegate.swift" \
  "Background quota refresh cadence should be configurable instead of hardcoded"
assert_match 'configureQuotaConsumingAutoRefreshTimer' \
  "QuotaRadar/AppDelegate.swift" \
  "Quota-consuming automatic refresh should use a separate long-cadence timer"
assert_match 'automaticRefreshDueCheckInterval\(for: interval\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Auto refresh timers should poll for due providers instead of restarting the full interval after every app launch"
assert_no_match 'Timer\.publish\(every: interval' \
  "QuotaRadar/AppDelegate.swift" \
  "Auto refresh timers should not wait a full new configured interval after launch when a provider is almost due"
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
assert_match '@objc func showStatusPanelForAutomation\(\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar popover should expose a stable automation hook for screenshot verification"
assert_match 'QUOTARADAR_SHOW_STATUS_PANEL_FOR_AUTOMATION' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar popover screenshot automation should be triggerable when launching the built app"
assert_match 'QUOTARADAR_OPEN_MENU_SIGNAL_FOR_AUTOMATION' \
  "QuotaRadar/AppDelegate.swift" \
  "Menu-to-main focus should have a reliable automation hook that bypasses flaky transient-panel AX clicks"
assert_match 'openMenuSignalForAutomationIfRequested' \
  "QuotaRadar/AppDelegate.swift" \
  "AppDelegate should evaluate the menu signal focus automation hook on launch"
assert_match 'openProviderFromStatusPopover\(item\.provider, credentialID: item\.key\.id, reason: item\.signalReason\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Menu signal focus automation should exercise the same provider/account/reason handoff as status bar row clicks"
assert_match 'QUOTARADAR_OPEN_MENU_SIGNAL_FOR_AUTOMATION="\$\{signal\}"' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should capture a focused main-window state through the menu signal automation hook"
assert_match 'FOCUS_SIGNALS=\(low expiring attention recent\)' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should cover low quota, expiring, attention, and recent-usage menu signal handoffs"
assert_match 'SUMMARY_TEXT_FILE="\$\{OUTPUT_DIR\}/summary\.txt"' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should write a human-readable release summary"
assert_match 'SUMMARY_JSON_FILE="\$\{OUTPUT_DIR\}/summary\.json"' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should write a machine-readable release summary"
assert_match 'write_visual_qa_summary' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should centralize screenshot dimensions and highlight counts into one release summary"
assert_match 'focused_signals' \
  "Tests/run_visual_qa.sh" \
  "Visual QA summary should enumerate every focused menu signal checked for release QA"
assert_match 'capture_focused_signal "\$\{signal\}"' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should capture every configured menu signal through the same focused-window path"
assert_match 'focused-\$\{signal\}-window\.png' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should save one focused screenshot per menu signal for targeted review"
assert_match 'focused-main-window\.png' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should save a focused-main screenshot for menu-to-main handoff review"
assert_match 'assert_file_nonempty "\$\{PANEL_BOUNDS_FILE\}"' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should fail when it cannot find the status-panel window bounds"
assert_match 'assert_file_nonempty "\$\{MAIN_WINDOW_ID_FILE\}"' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should fail when it cannot identify the main settings window"
assert_match 'assert_png_minimum_size "\$\{OUTPUT_DIR\}/menu-bar-popover\.png" 540 720' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should assert the menu-bar popover screenshot is complete enough to catch clipped panels"
assert_match 'assert_png_minimum_size "\$\{focused_screenshot\}" 900 600' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should assert the focused main-window screenshot is large enough for account-highlight review"
assert_match 'assert_focused_highlight_present "\$\{focused_screenshot\}"' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should fail when menu-to-main focus opens the window without a visible account highlight"
assert_match 'minimum_highlight_pixels = 20000' \
  "Tests/run_visual_qa.sh" \
  "Focused visual QA should use a threshold high enough to distinguish the selected account highlight from incidental blue UI"
assert_match 'case "failed", "failure", "check-failed", "checkfailed":' \
  "QuotaRadar/AppDelegate.swift" \
  "Menu signal automation should expose failed credentials as an addressable action-feed reason"
assert_match 'layout\.attentionItems\.first \{ \$0\.signalReason == \.failed \}' \
  "QuotaRadar/AppDelegate.swift" \
  "Failed signal automation should prefer a failed attention item instead of an arbitrary attention row"
assert_match 'stopPopoverMouseExitMonitor\(\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Automation status-panel opening should keep the popover visible long enough for screenshots"
assert_no_match 'showStatusPanelForAutomation' \
  "QuotaRadar/QuotaRadarApp.swift" \
  "The status-panel automation hook must not appear as a user-facing menu command"
assert_match 'buttonFrame\.minY - statusPanelGap - statusPanelSize\.height' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar padded panel should sit below the real menu-bar button so the top edge is not hidden by the menu bar"
assert_match 'visibleFrame\.maxY - statusPanelScreenInset - statusPanelSize\.height' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar padded panel should clamp below the menu bar instead of letting transparent padding enter the menu-bar region"
assert_match 'visibleFrame\.minY \+ statusPanelScreenInset' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar padded panel should clamp the full AppKit window to the screen bottom"
assert_no_match 'visibleFrame\.maxY - statusPanelScreenInset - MenuContentView\.menuSize\.height - statusPanelOuterPadding' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar panel should not clamp only the visible glass content because the padded window can be obscured at the top"
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
assert_match 'menuSignalLayout' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should expose one globally capped signal layout for the menu bar"
assert_match 'menuWatchedProviders' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should persist user-selected providers that deserve fixed menu-bar attention"
assert_match 'setMenuWatchedProviders' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should provide a single sanitized setter for menu-bar watched providers"
assert_match 'menuWatchedProviderItems' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should expose watched provider rows separately from long-lived automatic attention"
assert_match 'struct MenuQuotaSummary' \
  "QuotaRadar/Models/APIKey.swift" \
  "Menu bar summary counts should live in a shared model instead of view-only logic"
assert_match 'var statusBarCredentialLabel' \
  "QuotaRadar/Models/APIKey.swift" \
  "APIKey should expose a safe status-bar credential label that hides cookie JSON"
assert_match 'struct MenuQuotaItem' \
  "QuotaRadar/Models/APIKey.swift" \
  "Menu bar should use ranked quota items instead of rendering the full provider dashboard"
assert_match 'struct MenuQuotaSignalLayout' \
  "QuotaRadar/Models/QuotaHistory.swift" \
  "Menu bar should use a single globally capped signal queue where quota history can rank recent usage"
assert_match 'enum MenuSignalReason' \
  "QuotaRadar/Models/APIKey.swift" \
  "Menu bar items should carry an explicit reason for why they are being surfaced"
assert_match 'var signalReason: MenuSignalReason' \
  "QuotaRadar/Models/APIKey.swift" \
  "Menu bar item reasons should be derived from provider/account state in the shared model"
assert_match 'func focusProvider\(_ provider: Provider, credentialID: UUID\?, reason: MenuSignalReason\?\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings navigation should accept a provider and credential focus target from the menu bar"
assert_match 'focusedCredentialID' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings navigation should remember the exact account opened from the menu bar"
assert_match 'focusedProviderScrollID' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider settings should expose a stable scroll target for menu-to-main navigation"
assert_match 'openProviderFromStatusPopover' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar menu rows should open the main settings window at the selected provider"
assert_match 'openProviderFromStatusPopover\(_ provider: Provider, credentialID: UUID\?, reason: MenuSignalReason\?\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar menu rows should pass the selected account to the main provider view"
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
assert_match 'MenuRiskSummaryCard' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover should lead with a risk summary instead of a dense provider grid"
assert_no_match 'MenuProviderOverviewCard\(monitor: monitor\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover should not render the full provider grid in the primary menu view"
assert_match 'MenuRiskSummaryCard\(summary: monitor\.menuQuotaSummary\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar risk summary should be driven by QuotaMonitor.menuQuotaSummary"
python3 - <<'PY'
from pathlib import Path
import sys

source = Path("QuotaRadar/Views/MenuContentView.swift").read_text()
try:
    summary_card = source.split("struct MenuRiskSummaryCard: View", 1)[1].split("struct CompactMetricItem: View", 1)[0]
except IndexError:
    print("FAIL: MenuRiskSummaryCard should exist before CompactMetricItem", file=sys.stderr)
    sys.exit(1)

if "MenuSectionHeader(title: L10n.t(.sidebarStatistics)" not in summary_card:
    print("FAIL: Status bar summary metrics should be headed by Statistics", file=sys.stderr)
    sys.exit(1)
if "L10n.t(.apiQuotaTitle)" in summary_card or "L10n.t(.quotaRiskToday)" in summary_card:
    print("FAIL: Status bar summary metrics should not repeat the product name or risk title above metrics", file=sys.stderr)
    sys.exit(1)
PY
python3 - <<'PY'
from pathlib import Path
import sys

source = Path("QuotaRadar/Views/MenuContentView.swift").read_text()
try:
    body = source.split("var body: some View", 1)[1].split("private func openSettings", 1)[0]
except IndexError:
    print("FAIL: MenuContentView body should exist before settings helpers", file=sys.stderr)
    sys.exit(1)

if "HeaderView(" not in body:
    print("FAIL: Status bar popover should keep the header in the fixed menu panel", file=sys.stderr)
    sys.exit(1)
if "MenuSignalSectionsScrollView" in body:
    print("FAIL: Status bar popover should be tall enough to show signal sections without a nested scroll view", file=sys.stderr)
    sys.exit(1)

required_order = [
    "HeaderView(",
    "MenuRiskSummaryCard(summary: monitor.menuQuotaSummary)",
    "MenuWatchedProviderItemsView(monitor: monitor, items: signalLayout.watchedProviderItems)",
    "MenuLowQuotaItemsView(items: signalLayout.lowQuotaItems)",
    "MenuExpiringQuotaItemsView(items: signalLayout.expiringSoonItems)",
    "MenuAttentionItemsView(monitor: monitor, items: signalLayout.attentionItems)",
    "MenuRecentUsageItemsView(monitor: monitor, items: signalLayout.recentUsageItems)",
    "MenuHiddenQuotaItemsView("
]
positions = [body.find(fragment) for fragment in required_order]
if any(position < 0 for position in positions):
    print("FAIL: Status bar popover should render every signal section directly in the taller fixed panel", file=sys.stderr)
    sys.exit(1)
if positions != sorted(positions):
    print("FAIL: Status bar popover should preserve risk-first ordering before recent changes", file=sys.stderr)
    sys.exit(1)
PY
assert_no_match 'ForEach\(monitor\.homeProviderStats\) \{ stat in' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar home view should not render a flat provider list"
assert_match 'struct MonitorModule<Content: View>' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover should use lightweight monitoring modules instead of large dashboard cards"
assert_no_match 'struct MenuSignalSectionsScrollView<Content: View>' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover should use a taller fixed monitoring panel instead of requiring signal-section scrolling"
assert_match 'struct MenuSectionHeader' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar sections should use a consistent compact monitoring header"
assert_match 'MenuAttentionItemsView' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover should keep credentials needing attention as secondary detail below provider statistics"
assert_match 'let signalLayout = monitor\.menuSignalLayout' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover should render from a single globally capped signal layout"
assert_match 'MenuWatchedProviderItemsView' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover should show a short user-selected watchlist before automatic long-lived signals"
assert_no_match 'ForEach\(monitor\.menuAttentionQuotaItems' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar attention rows should not bypass the global signal cap"
assert_match 'MenuLowQuotaItemsView' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover should reserve space for low-quota providers, not only expired or exhausted credentials"
assert_no_match 'ForEach\(monitor\.menuLowQuotaItems' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar low-quota rows should not bypass the global signal cap"
assert_match 'MenuExpiringQuotaItemsView' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover should reserve space for credentials whose plan or balance expires soon"
assert_no_match 'ForEach\(monitor\.menuExpiringQuotaItems' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar expiring-soon rows should not bypass the global signal cap"
assert_match 'MenuRecentUsageItemsView' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover should include a compact recent usage section"
assert_no_match 'ForEach\(monitor\.menuRecentUsageQuotaItems' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar recent usage rows should not bypass the global signal cap"
assert_match 'MenuHiddenQuotaItemsView' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover should show an entry point when more signal rows are hidden by the fixed-height panel"
assert_match 'hiddenQuotaSignalCount' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Hidden menu-bar signal count should be localized"
assert_match 'recentUsageDetail' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Recent provider usage section should use a secondary recent-activity detail instead of another quota-status header"
assert_match 'recentProviderUsage' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Recent provider usage menu label should be localized"
assert_match 'watchedProviders' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Watched provider menu labels should be localized"
assert_match 'configureWatchedProviders' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Settings should expose a localized way to configure menu-bar watched providers"
assert_match 'menuWatchedProviderLimit = 2' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Menu bar watched provider list should stay short enough to leave room for automatic signals"
assert_match 'limit: 2' \
  "QuotaRadar/Models/QuotaHistory.swift" \
  "Menu signal layout should render at most two watched providers in the status bar popover"
assert_match 'watchedCount\)/2' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Watched provider settings should communicate the compact menu-bar limit"
python3 - <<'PY'
from pathlib import Path
import sys

source = Path("QuotaRadar/Views/MenuContentView.swift").read_text()
try:
    recent_view = source.split("struct MenuRecentUsageItemsView: View", 1)[1].split("struct MenuExpiringQuotaItemRow: View", 1)[0]
except IndexError:
    print("FAIL: MenuRecentUsageItemsView should exist before recent usage row details", file=sys.stderr)
    sys.exit(1)
if "detail: L10n.t(.recentUsageDetail)" in recent_view:
    print("FAIL: Menu recent usage section should not rely on weak right-side detail headers for explanation", file=sys.stderr)
    sys.exit(1)
if "onRefresh: { monitor.refreshProvider(item.provider) }" not in recent_view:
    print("FAIL: Menu recent usage rows should allow refreshing the provider from the same compact row", file=sys.stderr)
    sys.exit(1)
if "onOpenProvider: { openProvider(item) }" not in recent_view:
    print("FAIL: Menu recent usage rows should open and focus the provider in the main app", file=sys.stderr)
    sys.exit(1)
if "activitySummary: monitor.activitySummary(for: item.key)" not in recent_view:
    print("FAIL: Menu recent usage rows should render from QuotaActivitySummary so money-balance providers can appear", file=sys.stderr)
    sys.exit(1)
try:
    watched_view = source.split("struct MenuWatchedProviderItemsView: View", 1)[1].split("struct MenuLowQuotaItemsView: View", 1)[0]
except IndexError:
    print("FAIL: MenuWatchedProviderItemsView should exist before low quota items", file=sys.stderr)
    sys.exit(1)
if "MenuWatchedProviderItemRow(" not in watched_view:
    print("FAIL: Menu watched providers should use a dedicated compact watchlist row instead of recent-change rows", file=sys.stderr)
    sys.exit(1)
if "MenuRecentUsageItemRow(" in watched_view or "activitySummary:" in watched_view:
    print("FAIL: Menu watched providers should not repeat recent-change activity explanations in the watchlist section", file=sys.stderr)
    sys.exit(1)
try:
    watched_row = source.split("struct MenuWatchedProviderItemRow: View", 1)[1].split("struct MenuRecentUsageItemRow: View", 1)[0]
except IndexError:
    print("FAIL: MenuWatchedProviderItemRow should exist before recent usage rows", file=sys.stderr)
    sys.exit(1)
if "let isRefreshing: Bool" not in watched_row or "let onRefresh: () -> Void" not in watched_row:
    print("FAIL: Menu watched provider rows should keep the compact refresh affordance", file=sys.stderr)
    sys.exit(1)
if "activitySummary" in watched_row or "activityText" in watched_row or "compactDeltaIndicator" in watched_row:
    print("FAIL: Menu watched provider rows should show current provider state, not trend/delta copy", file=sys.stderr)
    sys.exit(1)
try:
    attention_view = source.split("struct MenuAttentionItemsView: View", 1)[1].split("struct MenuRecentUsageItemsView: View", 1)[0]
except IndexError:
    print("FAIL: MenuAttentionItemsView should exist before recent usage items", file=sys.stderr)
    sys.exit(1)
if "if !items.isEmpty" not in attention_view:
    print("FAIL: Menu attention section should disappear when there are no actionable items", file=sys.stderr)
    sys.exit(1)
if "noAttentionItems" in attention_view or "checkmark.seal.fill" in attention_view:
    print("FAIL: Menu attention section should not spend space on a calm empty-state row", file=sys.stderr)
    sys.exit(1)
for noisy_header in [
    "MenuSectionHeader(title: L10n.t(.sidebarStatistics), detail:",
    "MenuSectionHeader(title: L10n.t(.watchedProviders), detail:",
    "MenuSectionHeader(title: L10n.t(.lowQuotaProviders), detail:",
    "MenuSectionHeader(title: L10n.t(.expiringSoon), detail:",
    "MenuSectionHeader(title: L10n.t(.needsAttention), detail:",
    "MenuSectionHeader(title: L10n.t(.recentProviderUsage), detail:"
]:
    if noisy_header in source:
        print("FAIL: Menu bar attention feed sections should not show weak right-side table headers", file=sys.stderr)
        sys.exit(1)
if "struct MenuSignalReasonBadge: View" not in source:
    print("FAIL: Menu bar rows should use compact reason badges so users know why each provider is shown", file=sys.stderr)
    sys.exit(1)
for row_name in [
    "MenuWatchedProviderItemRow",
    "MenuRecentUsageItemRow",
    "MenuCompactQuotaItemRow",
    "MenuQuotaItemRow",
    "MenuExpiringQuotaItemRow"
]:
    try:
        row_scope = source.split(f"struct {row_name}: View", 1)[1].split("\nstruct ", 1)[0]
    except IndexError:
        print(f"FAIL: {row_name} should exist for menu bar signal rows", file=sys.stderr)
        sys.exit(1)
    if "MenuSignalReasonBadge(" not in row_scope:
        print(f"FAIL: {row_name} should show a compact reason badge instead of relying on section headers", file=sys.stderr)
        sys.exit(1)
components_source = Path("QuotaRadar/Views/Components.swift").read_text()
if "static func menuSurfaceOpacity(for transparency: Double) -> Double" not in components_source:
    print("FAIL: Status bar glass metrics should centralize menu surface opacity", file=sys.stderr)
    sys.exit(1)
if "transparency <= 0 ? 1.0 : 0.78" not in components_source:
    print("FAIL: Status bar menu surface should keep enough opacity for readable attention-feed rows", file=sys.stderr)
    sys.exit(1)
if "static func moduleFillOpacity(for transparency: Double)" not in components_source or "0.16 + (1 - clamped(transparency)) * 0.28" not in components_source:
    print("FAIL: Status bar modules should have a stronger base fill so background content does not bleed through", file=sys.stderr)
    sys.exit(1)
try:
    recent_row = source.split("struct MenuRecentUsageItemRow: View", 1)[1].split("struct MenuQuotaItemRow: View", 1)[0]
except IndexError:
    print("FAIL: MenuRecentUsageItemRow should exist before generic quota item rows", file=sys.stderr)
    sys.exit(1)
if "let activitySummary: QuotaActivitySummary" not in recent_row:
    print("FAIL: Menu recent usage rows should accept activity summaries instead of percentage-only trend summaries", file=sys.stderr)
    sys.exit(1)
if "let trendSummary: QuotaTrendSummary" in recent_row:
    print("FAIL: Menu recent usage rows should not depend on percentage-only trend summaries", file=sys.stderr)
    sys.exit(1)
if "let isRefreshing: Bool" not in recent_row or "let onRefresh: () -> Void" not in recent_row:
    print("FAIL: Menu recent usage rows should accept refresh state and action", file=sys.stderr)
    sys.exit(1)
if "let onOpenProvider: () -> Void" not in recent_row:
    print("FAIL: Menu recent usage rows should accept a main-app focus action", file=sys.stderr)
    sys.exit(1)
if "ProviderRefreshButton(provider: item.provider" not in recent_row:
    print("FAIL: Menu recent usage rows should render the centralized provider refresh gate", file=sys.stderr)
    sys.exit(1)
if "MenuSignalReasonBadge(text: L10n.t(.recentProviderUsage)" not in recent_row:
    print("FAIL: Menu recent usage rows should label their reason as Recent Change instead of a generic quota-status reason", file=sys.stderr)
    sys.exit(1)
if "quotaTrendDecreasing" in recent_row:
    print("FAIL: Menu recent usage rows should not show old textual trend labels such as 7d -2pt", file=sys.stderr)
    sys.exit(1)
if "L10n.compactDeltaIndicator" not in recent_row:
    print("FAIL: Menu recent usage rows should use the shared compact direction indicator for remaining-quota drops", file=sys.stderr)
    sys.exit(1)
if "activitySummary.activityText" not in recent_row:
    print("FAIL: Menu recent usage rows should include a short explanation of the recent change behind the compact delta", file=sys.stderr)
    sys.exit(1)
if "key.usageCount" in recent_row or "key.lastUsed" in recent_row:
    print("FAIL: Menu recent usage rows should not fall back to legacy usage counts or last-used timestamps", file=sys.stderr)
    sys.exit(1)
try:
    attention_row = source.split("struct MenuQuotaItemRow: View", 1)[1].split("struct RefreshButton", 1)[0]
except IndexError:
    print("FAIL: MenuQuotaItemRow should exist before shared refresh controls", file=sys.stderr)
    sys.exit(1)
if "QuotaWindowDetails(" in attention_row:
    print("FAIL: Menu bar attention rows should not expand every quota window; one compact quota line is enough", file=sys.stderr)
    sys.exit(1)
if "compactDiagnosticText" not in attention_row:
    print("FAIL: Menu bar attention rows should filter duplicate diagnostic text before rendering", file=sys.stderr)
    sys.exit(1)
if "presentation.diagnosticText != presentation.primaryText" not in attention_row:
    print("FAIL: Menu bar attention rows should not repeat quota-window balances as both primary quota and diagnostic text", file=sys.stderr)
    sys.exit(1)
PY
python3 - <<'PY'
from pathlib import Path
import sys

source = Path("QuotaRadar/Views/MenuContentView.swift").read_text()
for struct_name in ["MenuCompactQuotaItemRow", "MenuExpiringQuotaItemRow"]:
    try:
        row = source.split(f"struct {struct_name}: View", 1)[1].split("struct ", 1)[0]
    except IndexError:
        print(f"FAIL: {struct_name} should exist", file=sys.stderr)
        sys.exit(1)
    if "Button(action: onOpenProvider)" not in row:
        print(f"FAIL: {struct_name} should be a real Button so menu-to-main focus is accessibility-testable", file=sys.stderr)
        sys.exit(1)
    if ".buttonStyle(.plain)" not in row:
        print(f"FAIL: {struct_name} should keep the compact row visual while using Button semantics", file=sys.stderr)
        sys.exit(1)
PY
assert_no_match 'StatItem\(value: "\\\\\(totalProviders\\\\\)", label: L10n\.t\(\.providers\)\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar summary should not spend prime space on provider totals"
assert_no_match 'StatItem\(value: "\\\\\(totalKeys\\\\\)", label: L10n\.t\(\.keys\)\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar summary should not spend prime space on credential totals"
assert_match 'L10n\.t\(\.keyQuota\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota overview table should use a user-oriented key quota column instead of ambiguous Remaining/Total headers"
assert_match 'L10n\.t\(\.credentialPool\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota overview table should expose credential-pool state for providers with multiple keys"
assert_match 'L10n\.t\(\.criticalTime\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota overview table should label reset or plan-end timing as critical time"
assert_no_match 'L10n\.t\(\.nextTime\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota overview table should not keep the old next-time label"
assert_no_match 'Text\(L10n\.t\(\.total\)\).*?ProviderQuotaMonitorTableHeader' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota overview table header should not use the ambiguous Total label for mixed provider types"
assert_match 'quotaOverviewRiskColor' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota overview provider rows should use a dedicated green/red risk color instead of provider or status-spectrum colors"
assert_match 'navigationStore\.focusedProvider == provider' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota overview provider rows should know when they are focused from the menu bar"
assert_match 'navigationStore\.focusedCredentialID == key\.id' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Expanded provider account rows should know when they are the exact menu-bar target"
assert_match 'MenuSignalReason' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota overview provider rows should be able to explain why the menu bar opened them"
python3 - <<'PY'
from pathlib import Path
import sys

source = Path("QuotaRadar/Views/SettingsView.swift").read_text()
try:
    providers_view = source.split("struct ProvidersView: View", 1)[1].split("struct ProviderSettingsCategorySection", 1)[0]
except IndexError:
    print("FAIL: Quota overview view structure should be present", file=sys.stderr)
    sys.exit(1)

if "monitor.orderedVisibleProviders.compactMap" not in providers_view:
    print("FAIL: Quota overview should preserve custom provider order while hiding providers without configured monitoring credentials", file=sys.stderr)
    sys.exit(1)
if "sortedMonitoringKeysByCurrentQuota.isEmpty" not in providers_view:
    print("FAIL: Quota overview should hide providers that do not have any quota-monitoring credential configured", file=sys.stderr)
    sys.exit(1)

try:
    provider_summary = source.split("private var providerSummaryRow: some View", 1)[1].split("ProviderQuotaColumnValue", 1)[0]
    provider_row_scope = source.split("struct ProviderQuotaMonitorRow: View", 1)[1].split("struct ProviderQuotaColumnValue", 1)[0]
except IndexError:
    print("FAIL: Provider quota summary row should be present", file=sys.stderr)
    sys.exit(1)

if "providerKeyCount" in provider_summary or "activeCount" in provider_summary:
    print("FAIL: Provider quota left column should not duplicate credential-pool key and usable counts", file=sys.stderr)
    sys.exit(1)
if "stat.effectivePlanDisplayName" in provider_summary:
    print("FAIL: Provider quota left column must not show plan/package names because one provider can contain accounts on different plans", file=sys.stderr)
    sys.exit(1)
if "provider.planTypeDisplayName()" not in provider_row_scope:
    print("FAIL: Provider quota left column should show the provider product type such as coding plan instead of only the broad LLM category", file=sys.stderr)
    sys.exit(1)
if "L10n.categoryTitle(provider.statusBarCategoryTitle)" not in provider_row_scope:
    print("FAIL: Provider quota left column should keep category fallback for providers without a product type", file=sys.stderr)
    sys.exit(1)
try:
    provider_row = source.split("struct ProviderQuotaMonitorRow: View", 1)[1].split("struct ProviderQuotaColumnValue", 1)[0]
except IndexError:
    print("FAIL: Provider quota monitor row should be present", file=sys.stderr)
    sys.exit(1)
if "stat.statusBarProviderStatusColor" in provider_row:
    print("FAIL: Quota overview provider rows should not reuse blue/orange status-bar colors for key quota and status", file=sys.stderr)
    sys.exit(1)
if "quotaOverviewRiskColor" not in provider_row:
    print("FAIL: Quota overview provider rows should use the dedicated green/red risk color", file=sys.stderr)
    sys.exit(1)
PY
assert_match 'statusBarAccountContextLabel' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar rows should use compact account context instead of repeating low-information web-login authorization text"
assert_no_match 'Text\(key\.statusBarCredentialLabel\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar rows should not repeat generic web-login authorization labels in every menu row"
assert_match 'struct QuotaThresholdNotificationEvent' \
  "QuotaRadar/Services/QuotaNotificationService.swift" \
  "Threshold notifications should use a lightweight event model"
assert_match 'QuotaThresholdNotificationService' \
  "QuotaRadar/Services/QuotaNotificationService.swift" \
  "Threshold notification decisions and delivery should be centralized in a service"
assert_match 'UNUserNotificationCenter' \
  "QuotaRadar/Services/QuotaNotificationService.swift" \
  "Threshold notifications should use macOS local notifications"
assert_match 'requestAuthorization' \
  "QuotaRadar/Services/QuotaNotificationService.swift" \
  "Threshold notifications should request notification permission before delivery"
assert_match 'consecutiveFailureCount' \
  "QuotaRadar/Models/APIKey.swift" \
  "API keys should persist consecutive quota-check failures for repeated-failure notifications"
assert_match 'key\.consecutiveFailureCount \+=' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should increment consecutive failure counts when quota checks fail"
assert_match 'key\.consecutiveFailureCount = 0' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should reset consecutive failure counts when checks recover or reach a non-connection terminal state"
assert_match 'QuotaThresholdNotificationService\.shared\.notifyIfNeeded' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should evaluate threshold notifications after refreshes update key state"
assert_match 'var planDisplayName: String\?' \
  "QuotaRadar/Services/QuotaService.swift" \
  "QuotaResult should carry a concrete plan/package display name when the provider exposes it"
assert_match 'var planDisplayName: String\?' \
  "QuotaRadar/Models/APIKey.swift" \
  "APIKey should retain a concrete plan/package display name from the latest quota refresh"
assert_match 'var planDisplayName: String\?' \
  "QuotaRadar/Services/APIKeyStore.swift" \
  "APIKeyStore metadata should persist concrete plan/package display names"
assert_match 'key\.planDisplayName = result\.planDisplayName' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should copy refreshed plan/package names onto API keys"
assert_match 'verifiedKey\.planDisplayName = result\.planDisplayName' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthorization should keep the concrete plan/package name from verification"
assert_match 'accountDisplayTitle' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings account rows should show refreshed concrete plan/package names when available"
assert_no_match 'stat\.effectivePlanDisplayName' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Menu provider rows must not show account-level plan/package names under the provider"
assert_no_match 'stat\.effectivePlanDisplayName' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider-level Settings sections must not show account-level plan/package names under the provider"
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
python3 - <<'PY'
from pathlib import Path
import re
import sys

menu_source = Path("QuotaRadar/Views/MenuContentView.swift").read_text()
limit_source = Path("QuotaRadar/Models/QuotaMonitor.swift").read_text()
menu_match = re.search(r"menuSize = CGSize\(width: ([0-9]+), height: ([0-9]+)\)", menu_source)
limit_match = re.search(r"menuSignalItemLimit = ([0-9]+)", limit_source)
if not menu_match or not limit_match:
    print("FAIL: Status bar menu should keep explicit fixed size and signal cap", file=sys.stderr)
    sys.exit(1)
height = int(menu_match.group(2))
visible_limit = int(limit_match.group(1))
if visible_limit >= 6 and height < 720:
    print("FAIL: Fixed status bar panel is too short for six visible signal rows", file=sys.stderr)
    sys.exit(1)
PY
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
assert_match 'StatusBarGlassMetrics\.materialOpacity\(for: transparency\)' \
  "QuotaRadar/Views/Components.swift" \
  "Status bar cards should visibly change material opacity with the transparency slider"
assert_match '\.fill\(\.regularMaterial\)' \
  "QuotaRadar/Views/Components.swift" \
  "Status bar cards should use regular material so quota text stays readable over bright or busy backgrounds"
assert_match 'baseFillOpacity' \
  "QuotaRadar/Views/Components.swift" \
  "Status bar cards should include an adaptive fill layer so text remains readable over busy backgrounds"
assert_match 'menuSurfaceOpacity' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar menu should use a SwiftUI-owned adaptive translucent surface instead of an opaque grey panel"
assert_match 'private var menuSurfaceOpacity: Double \{' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar transparency should affect the outer menu surface, not only inner cards"
assert_match 'StatusBarGlassMetrics\.menuSurfaceOpacity\(for: statusBarTransparency\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar outer surface opacity should come from the shared glass metrics"
assert_match 'StatusBarGlassMetrics\.materialOpacity\(for: transparency\)' \
  "QuotaRadar/Views/Components.swift" \
  "Status bar card material opacity should come from the shared glass metrics"
assert_match 'transparency <= 0 \? 1\.0 : 0\.78 \+ \(1 - clamped\(transparency\)\) \* 0\.18' \
  "QuotaRadar/Views/Components.swift" \
  "Status bar transparency 0% should be a fully opaque outer surface"
assert_match 'transparency <= 0 \? 0\.0 : 0\.28 \+ \(1 - clamped\(transparency\)\) \* 0\.62' \
  "QuotaRadar/Views/Components.swift" \
  "Status bar transparency 0% should disable frosted material bleed-through"
assert_match 'transparency <= 0 \? 1\.0 : 0\.08 \+ \(1 - clamped\(transparency\)\) \* 0\.42' \
  "QuotaRadar/Views/Components.swift" \
  "Status bar transparency 0% should use a fully opaque card fill"
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
assert_match 'ProviderRefreshButton\(provider: item\.provider, isRefreshing: \.constant\(isRefreshing\), isEnabled: item\.canRefresh' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Each status bar top item row should use the centralized provider refresh gate"
assert_match 'statusPanelSize' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar hosting window must be larger than MenuContentView.menuSize to avoid clipping"
assert_match 'statusItem = NSStatusBar\.system\.statusItem\(withLength: NSStatusItem\.squareLength\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar item should use a compact square hit target so it is less likely to be hidden by long app menus"
assert_match 'updateStatusItemPresentation\(\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar item should update its icon/text presentation from current quota signals"
assert_match 'NSStatusBar\.system\.thickness' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar item should grow only when a short quota signal needs text"
assert_no_match 'button\.imagePosition = \.imageOnly' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar item should not stay image-only when critical quota signals exist"
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
assert_match 'button\.imagePosition = \.imageLeading' \
  "QuotaRadar/AppDelegate.swift" \
  "Status bar item should support an icon plus compact text when quota signals need attention"
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
assert_match 'menuSize = CGSize\(width: 560, height: 740\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar risk popover should be tall enough to show the fixed attention feed without clipping"
menu_height="$(awk -F'height: ' '/menuSize = CGSize/ { gsub(/[^0-9.].*/, "", $2); print $2; exit }' QuotaRadar/Views/MenuContentView.swift)"
if [[ -z "$menu_height" ]]; then
  fail "Status bar popover should keep menuSize height as a numeric constant"
fi
if awk "BEGIN { exit !($menu_height >= 720 && $menu_height <= 760) }"; then
  :
else
  fail "Status bar popover height should fit the fixed attention feed without becoming a full dashboard"
fi
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
  "Status bar body should keep the popover fixed while overflow areas scroll inside bounded regions"
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
python3 - <<'PY'
from pathlib import Path
import sys

source = Path("QuotaRadar/Views/MenuContentView.swift").read_text()
try:
    header_view = source.split("struct HeaderView: View", 1)[1].split("struct HeaderStatusPill", 1)[0]
except IndexError:
    print("FAIL: Status bar header view should exist before header status pill", file=sys.stderr)
    sys.exit(1)

if "refreshMessage == L10n.t(.updatedJustNow)" not in header_view:
    print("FAIL: Status bar header should suppress the low-signal just-updated message beside the quote", file=sys.stderr)
    sys.exit(1)
if "return nil" not in header_view:
    print("FAIL: Status bar header should omit the status pill when the only status is just-updated", file=sys.stderr)
    sys.exit(1)
PY
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
assert_match 'MenuQuotaItem\.topItems\(from: homeProviderStats, limit: 3, providerOrder: orderedVisibleProviders\)' \
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
assert_no_match 'VisualEffectBlur\(material: \.popover' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar menu must not place an AppKit NSVisualEffectView inside the SwiftUI ZStack because it can cover the menu content"
assert_match 'menuSurfaceOpacity' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar menu should use a SwiftUI-owned translucent surface behind the content"
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
assert_match 'AddCredentialProviderList\(provider: \$provider, providers: providers\)' \
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
assert_match 'item\.statusBarAccountContextLabel' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar key rows should use compact account context and hide low-information web-login authorization labels"
assert_match 'credentialID: item\.key\.id' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar key rows should pass the exact account id when opening the main provider view"
assert_no_match 'Text\(key\.name\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar key rows must not show TAVILY_API_KEY-style environment variable names"
assert_no_match 'key\.key\.count' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings API key rows must not waste the right side on API key character counts"
assert_no_match 'chars' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings API key rows must not show API key character counts"
assert_no_match 'timingText\(key\.visibleQuotaResetSummary' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings API key rows should not duplicate quota-window reset timing in the account timing column"
assert_match 'key\.planEndSummary' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings API key rows should show package expiry as a separate weak detail"
assert_match 'ProviderQuotaAccountLayout\.columnWidths\(for:' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings API key timing column should align through the shared account grid width calculation"
assert_no_match 'frame\(width: 124, alignment: \.trailing\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings API key timing column must not keep the old narrow last-updated width"
assert_match 'criticalTimeText' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings API key rows should separate reset or package expiry into a compact critical-time column"
assert_match 'value: L10n\.format\(\.updated, updatedText\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings API key rows should keep last-updated text in its own compact column"
python3 - <<'PY'
from pathlib import Path
import sys

source = Path("QuotaRadar/Views/SettingsView.swift").read_text()
try:
    timing_column = source.split("struct ProviderQuotaTimingColumn: View", 1)[1].split("// MARK: - Diagnostics View", 1)[0]
except IndexError:
    print("FAIL: ProviderQuotaTimingColumn should exist before diagnostics", file=sys.stderr)
    sys.exit(1)

if "VStack(alignment: .trailing" not in timing_column:
    print("FAIL: Expanded settings account timing should stack update and package expiry vertically", file=sys.stderr)
    sys.exit(1)
if "timingText(key.visibleQuotaResetSummary" in timing_column:
    print("FAIL: Settings account timing should not render quota reset summaries beside update/expiry timing", file=sys.stderr)
    sys.exit(1)
if "HStack(alignment: .firstTextBaseline" in timing_column or 'Text("·")' in timing_column:
    print("FAIL: Expanded settings account timing should not join update and package expiry on one line", file=sys.stderr)
    sys.exit(1)
PY
assert_no_match 'trendSummary\(for: key\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings quota activity columns should not draw from textual trend summaries"
assert_no_match 'quotaTrendOverlayText' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings quota activity columns should not generate textual trend overlay labels"
assert_match 'case quotaActivity' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Activity column labels should be localized"
assert_match 'case quotaActivityRemaining' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Activity rows should label current values as remaining quota instead of used quota"
assert_match 'refreshDeltaText' \
  "QuotaRadar/Models/QuotaHistory.swift" \
  "Quota history should explain what changed on the latest refresh"
assert_match 'quotaRefreshDeltaConsumed' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Refresh delta labels should be localized"
assert_match 'struct QuotaSparklineSample' \
  "QuotaRadar/Models/QuotaHistory.swift" \
  "Quota history should expose normalized samples for compact trend sparklines"
assert_match 'enum QuotaActivityKind' \
  "QuotaRadar/Models/QuotaHistory.swift" \
  "Quota history should classify activity by provider quota semantics instead of only drawing remaining-quota trends"
assert_match 'struct QuotaActivitySummary' \
  "QuotaRadar/Models/QuotaHistory.swift" \
  "Quota history should expose activity summaries for the main app and menu bar"
assert_match 'static func activitySummary' \
  "QuotaRadar/Models/QuotaHistory.swift" \
  "Quota activity should be derived through one shared summary function"
assert_match 'var consumedPercentPoints: Double\?' \
  "QuotaRadar/Models/QuotaHistory.swift" \
  "Quota activity summaries should expose consumed percentage points so menu recency ranking uses the same reset-aware model"
assert_match 'var consumedUnits: Int\?' \
  "QuotaRadar/Models/QuotaHistory.swift" \
  "Quota activity summaries should expose consumed units so money-balance and fixed-quota providers can share menu recency ranking"
assert_match 'var usedFraction: Double\?' \
  "QuotaRadar/Models/QuotaHistory.swift" \
  "Quota activity summaries should expose an optional usage fraction for compact meters"
assert_match 'var shouldRender: Bool' \
  "QuotaRadar/Models/QuotaHistory.swift" \
  "Quota activity summaries should explicitly hide low-signal activity lanes"
assert_match 'func activitySummary\(for key: APIKey\)' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should expose activity summaries to SwiftUI surfaces"
assert_match 'struct QuotaActivityMeter' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings quota rows should render compact activity indicators instead of trend sparklines"
assert_no_match 'ProviderQuotaActivityHeaderCell' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota overview should not reserve a sparse Activity header column"
assert_no_match 'ProviderQuotaActivityColumn' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota overview should not reserve a sparse Activity scan column"
assert_no_match 'activityWidth' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota overview layout should not reserve fixed width for mostly-empty activity signals"
assert_match 'provider: providerColumnWidth,' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota overview should keep provider labels compact instead of stretching the removed Activity space"
assert_match 'keyQuota: keyQuotaWidth,' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota overview should keep key quota close to provider labels instead of right-aligning across a wide blank lane"
assert_match 'static let providerLabelWidth: CGFloat = 104' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota overview provider label width should stay compact after removing the Activity column"
python3 - <<'PY'
from pathlib import Path
import sys

source = Path("QuotaRadar/Views/SettingsView.swift").read_text()
try:
    grid_row = source.split("struct ProviderQuotaOverviewGridRow", 1)[1].split("struct ProviderQuotaMonitorTableHeader", 1)[0]
    overview_header = source.split("struct ProviderQuotaMonitorTableHeader: View", 1)[1].split("struct ProviderQuotaMonitorRow: View", 1)[0]
except IndexError:
    print("FAIL: Provider quota overview grid and header should be present", file=sys.stderr)
    sys.exit(1)
if "keyQuota\n                    .frame(width: widths.keyQuota, height: height, alignment: .leading)" not in grid_row:
    print("FAIL: Key quota cells should align near provider labels instead of floating at the far edge of a wide numeric lane", file=sys.stderr)
    sys.exit(1)
if "Text(L10n.t(.keyQuota))\n                .frame(maxWidth: .infinity, alignment: .leading)" not in overview_header:
    print("FAIL: Key quota header should align with key quota values after the Activity column is removed", file=sys.stderr)
    sys.exit(1)
PY
assert_no_match 'provider: providerColumnWidth \+ extraWidth' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider column must not absorb spare table width after Activity is hidden"
assert_no_match 'keyQuota: keyQuotaWidth \+ extraWidth' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Key quota column must not absorb spare table width after Activity is hidden"
assert_no_match 'activitySummary: monitor\.activitySummary\(for: key\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Expanded account rows should not repeat activity summaries after the compact four-column account layout"
assert_no_match 'summary: activitySummary' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Expanded account rows should not render a second activity meter inside the compact account layout"
assert_match 'summary: providerActivitySummary' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider summary rows should keep meaningful activity attached to the quota reading"
assert_match 'ProviderQuotaInlineActivity' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider summary rows should render activity as an inline quota-side signal"
assert_match 'summary\.deltaText\?\.trimmingCharacters' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Inline quota activity should hide bare period markers when there is no actual change"
assert_match 'var mostConstrainedActiveMonitoringKey' \
  "QuotaRadar/Models/APIKey.swift" \
  "Provider summary rows should be anchored to the most constrained active account instead of implying aggregated usage"
assert_no_match 'if let detailKey = keys\.first\(where: \{ !\$0\.quotaWindowDetails\.isEmpty \}\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Expanded provider details should not show the first account's quota windows as if they describe the whole provider"
assert_no_match 'QuotaTrendSparkline\(' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings quota rows should not render trend sparklines after the Activity model replaces trends"
assert_no_match 'struct QuotaTrendSparkline' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings quota rows should remove the old trend sparkline component"
assert_no_match 'ProviderQuotaTrendColumn' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings quota rows should remove the old trend column component"
assert_no_match 'sparklineSamples: monitor\.sparklineSamples\(for: key\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Expanded account rows should not request sparkline samples from QuotaMonitor"
python3 - <<'PY'
from pathlib import Path
import sys

source = Path("QuotaRadar/Models/QuotaHistory.swift").read_text()
try:
    recent_provider_usage = source.split("static func recentProviderUsageItems", 1)[1].split("private static func shouldRankRecentUsage", 1)[0]
except IndexError:
    print("FAIL: recentProviderUsageItems should exist before ranking helpers", file=sys.stderr)
    sys.exit(1)
if "QuotaActivitySummary.activitySummary" not in recent_provider_usage:
    print("FAIL: Menu bar recent changes should use the same reset-aware QuotaActivitySummary as the main activity column", file=sys.stderr)
    sys.exit(1)
if "QuotaTrendSummary.trendSummary" in recent_provider_usage:
    print("FAIL: Menu bar recent changes should not use generic quota trends that can cross reset windows", file=sys.stderr)
    sys.exit(1)
if "recentActivityMetrics" not in recent_provider_usage:
    print("FAIL: Menu bar recent changes should rank from a shared activity metric derived from QuotaActivitySummary", file=sys.stderr)
    sys.exit(1)
PY
python3 - <<'PY'
from pathlib import Path
import re
import sys

source = Path("QuotaRadar/Views/SettingsView.swift").read_text()
try:
    activity_meter_start = source.split("struct QuotaActivityMeter: View", 1)[1]
    activity_meter = activity_meter_start.split("struct ProviderQuotaStatusPill: View", 1)[0]
    overview_header = source.split("struct ProviderQuotaMonitorTableHeader: View", 1)[1].split("struct ProviderQuotaMonitorRow: View", 1)[0]
    provider_row = source.split("struct ProviderQuotaMonitorRow: View", 1)[1].split("struct ProviderQuotaColumnValue: View", 1)[0]
    grid_row = source.split("struct ProviderQuotaOverviewGridRow", 1)[1].split("struct ProviderQuotaMonitorTableHeader", 1)[0]
except IndexError:
    print("FAIL: Quota overview structure should expose activity meter, header, and provider row scopes", file=sys.stderr)
    sys.exit(1)

if "summary.shouldRender" not in activity_meter:
    print("FAIL: QuotaActivityMeter should delegate low-signal hiding to QuotaActivitySummary.shouldRender", file=sys.stderr)
    sys.exit(1)
if "summary.periodName.map" not in activity_meter or "quotaPeriodCompactTitle" not in activity_meter:
    print("FAIL: QuotaActivityMeter should render compact activity period labels such as month/week/5h", file=sys.stderr)
    sys.exit(1)
if "Text(periodLabel ?? \"\")" in activity_meter or ".opacity(periodLabel == nil ? 0 : 1)" in activity_meter:
    print("FAIL: QuotaActivityMeter should not place a reserved period-label slot before the primary activity value", file=sys.stderr)
    sys.exit(1)
if "Text(currentValueText)" in activity_meter:
    print("FAIL: QuotaActivityMeter should not duplicate the current quota value now that activity is attached to Key Quota", file=sys.stderr)
    sys.exit(1)
if "summary.currentText" not in activity_meter:
    print("FAIL: QuotaActivityMeter should still derive from the same summary model even when it suppresses duplicate current quota text", file=sys.stderr)
    sys.exit(1)
if "fixedSize(horizontal: true, vertical: false)" not in activity_meter:
    print("FAIL: QuotaActivityMeter values should keep compact money amounts readable instead of truncating them", file=sys.stderr)
    sys.exit(1)
if ".truncationMode(.tail)" in activity_meter:
    print("FAIL: QuotaActivityMeter should not hide money-balance activity behind tail truncation", file=sys.stderr)
    sys.exit(1)
if "quotaActivityRemaining" in activity_meter:
    print("FAIL: QuotaActivityMeter should not prefix compact readings with remaining-quota wording", file=sys.stderr)
    sys.exit(1)
if "summary.deltaText" not in activity_meter or "changeIndicatorText" not in activity_meter:
    print("FAIL: QuotaActivityMeter should convert remaining deltas into compact direction indicators such as ↓2pt", file=sys.stderr)
    sys.exit(1)
if "return deltaText" in activity_meter:
    print("FAIL: QuotaActivityMeter should not render raw remaining-delta text such as -2pt", file=sys.stderr)
    sys.exit(1)
if "summary.usedFraction" in activity_meter or "currentUsageText" in activity_meter or "quotaActivityUsed" in activity_meter:
    print("FAIL: QuotaActivityMeter should not expose used-quota wording in the remaining-first activity lane", file=sys.stderr)
    sys.exit(1)
if "summary.activityText" in activity_meter:
    print("FAIL: QuotaActivityMeter should not show consumption wording alongside remaining quota", file=sys.stderr)
    sys.exit(1)
if "activityFill" in activity_meter:
    print("FAIL: QuotaActivityMeter should avoid unlabeled progress bars that make activity deltas hard to interpret", file=sys.stderr)
    sys.exit(1)
if "Capsule()" in activity_meter:
    print("FAIL: QuotaActivityMeter should stay inline and avoid pill/card-like placeholder styling", file=sys.stderr)
    sys.exit(1)
if "Text(L10n.t(.quotaActivity))" in overview_header:
    print("FAIL: Provider quota overview header should not reserve a mostly-empty Activity column", file=sys.stderr)
    sys.exit(1)
if "activity:" in overview_header or "activity:" in provider_row or "let activity:" in grid_row:
    print("FAIL: Provider quota overview grid should remove the dedicated Activity column", file=sys.stderr)
    sys.exit(1)
if "ProviderQuotaOverviewGridRow(" not in overview_header:
    print("FAIL: Provider quota overview header should use the shared grid row so headers and values share positions", file=sys.stderr)
    sys.exit(1)
if "ProviderQuotaInlineActivity" not in provider_row or "summary: providerActivitySummary" not in provider_row:
    print("FAIL: Provider quota summary rows should attach meaningful activity under Key Quota instead of a sparse second column", file=sys.stderr)
    sys.exit(1)
if provider_row.find("ProviderQuotaColumnValue(value: keyQuotaText") > provider_row.find("ProviderQuotaInlineActivity"):
    print("FAIL: Provider quota summary rows should keep the quota value primary and show activity as supporting text below it", file=sys.stderr)
    sys.exit(1)
if "private var providerAvailabilityStatusColor: Color" not in provider_row:
    print("FAIL: Provider quota summary rows should separate availability status color from quota-risk color", file=sys.stderr)
    sys.exit(1)
if "ProviderQuotaStatusPill(text: statusText, tint: providerAvailabilityStatusColor)" not in provider_row:
    print("FAIL: Provider quota status pill should use availability color instead of quota-risk color", file=sys.stderr)
    sys.exit(1)
if "ProviderQuotaStatusPill(text: statusText, tint: quotaOverviewRiskColor)" in provider_row:
    print("FAIL: Provider quota status pill should not turn red only because quota is low", file=sys.stderr)
    sys.exit(1)
if "if keys.contains(where: { $0.isExhausted || $0.isLow }) { return L10n.t(.low) }" in provider_row:
    print("FAIL: Provider quota status text should not collapse low remaining quota into connection status", file=sys.stderr)
    sys.exit(1)
if "providerSummaryRowBackground" not in source or "providerSummaryRiskAccent" not in source:
    print("FAIL: Provider quota rows should lightly emphasize risk rows without turning the table into cards", file=sys.stderr)
    sys.exit(1)
layout_match = re.search(r"private enum ProviderQuotaOverviewLayout[\s\S]*?static let totalWidthBudget: CGFloat = ([0-9.]+)", source)
if not layout_match:
    print("FAIL: Provider quota overview rows should define an explicit width budget for the default settings window", file=sys.stderr)
    sys.exit(1)
if float(layout_match.group(1)) > 850:
    print("FAIL: Provider quota overview row width budget should fit the default settings window", file=sys.stderr)
    sys.exit(1)
if "ProviderQuotaAccountLayout" not in source:
    print("FAIL: Expanded account quota rows should use a shared compact account layout", file=sys.stderr)
    sys.exit(1)
if "static let rowHorizontalPadding: CGFloat" not in source:
    print("FAIL: Provider quota table rows should share one horizontal padding constant so headers, provider rows, and account rows start on the same grid", file=sys.stderr)
    sys.exit(1)
if "struct ProviderQuotaOverviewGridRow" not in source:
    print("FAIL: Provider quota overview header and rows should render through one shared grid row component", file=sys.stderr)
    sys.exit(1)
if "columnWidths(for:" not in source:
    print("FAIL: Provider quota overview columns should be calculated from one shared width model", file=sys.stderr)
    sys.exit(1)
try:
    provider_row = source.split("struct ProviderQuotaMonitorRow: View", 1)[1].split("struct ProviderQuotaColumnValue: View", 1)[0]
except IndexError:
    print("FAIL: ProviderQuotaMonitorRow should exist before quota column helpers", file=sys.stderr)
    sys.exit(1)
if "ZStack(alignment: .trailing)" in provider_row:
    print("FAIL: Provider quota action buttons must be part of the row grid instead of floating in a trailing overlay", file=sys.stderr)
    sys.exit(1)
if "ProviderQuotaActionGroup(" not in provider_row.split("private var providerSummaryRow: some View", 1)[1]:
    print("FAIL: Provider quota action buttons should live inside the provider summary row grid", file=sys.stderr)
    sys.exit(1)
if "isWatched: monitor.isMenuWatchedProvider(provider)" not in provider_row:
    print("FAIL: Provider quota rows should expose whether the provider is pinned in the menu watchlist", file=sys.stderr)
    sys.exit(1)
if "onToggleWatched: { monitor.toggleMenuWatchedProvider(provider) }" not in provider_row:
    print("FAIL: Provider quota rows should let users pin or unpin a provider without opening the watchlist settings sheet", file=sys.stderr)
    sys.exit(1)
if "ProviderQuotaOverviewGridRow(" not in overview_header or "ProviderQuotaOverviewGridRow(" not in provider_row:
    print("FAIL: Provider quota overview header and provider rows should both use the shared grid row component", file=sys.stderr)
    sys.exit(1)
if "private var providerSummaryCells" in provider_row:
    print("FAIL: Provider quota summary cells should not be a separate HStack with independent column positions", file=sys.stderr)
    sys.exit(1)
if "Spacer(minLength: ProviderQuotaOverviewLayout.flexibleGapMinWidth)" in provider_row or "Spacer(minLength: ProviderQuotaOverviewLayout.flexibleGapMinWidth)" in overview_header:
    print("FAIL: Provider quota overview rows should not rely on a loose spacer for column alignment", file=sys.stderr)
    sys.exit(1)
if ".padding(.leading, 56)" in provider_row:
    print("FAIL: Expanded quota account rows should align their borders with provider summary rows instead of adding a hard left indent", file=sys.stderr)
    sys.exit(1)
try:
    account_grid = source.split("struct ProviderQuotaAccountGridRow", 1)[1].split("struct ProviderQuotaOverviewGridRow", 1)[0]
    account_table = source.split("struct ProviderQuotaAccountGroup: View", 1)[1].split("struct ProviderQuotaTimingColumn: View", 1)[0]
except IndexError:
    print("FAIL: Expanded quota account group layout should exist before timing column helpers", file=sys.stderr)
    sys.exit(1)
if ".frame(width: 230" in account_table or ".frame(width: 86" in account_table or ".frame(width: 112" in account_table:
    print("FAIL: Expanded quota account table should not keep old hard-coded column widths", file=sys.stderr)
    sys.exit(1)
if "ProviderQuotaAccountGroup(" not in source:
    print("FAIL: Expanded quota rows should render account-group cards instead of continuing the provider table", file=sys.stderr)
    sys.exit(1)
if "HStack(alignment: .center, spacing: 14)" not in account_table:
    print("FAIL: Expanded account group identity and meta panel should be vertically centered against quota-window rows", file=sys.stderr)
    sys.exit(1)
if "ProviderQuotaKeyTableHeader()" in source or "ProviderQuotaKeyTableRow(" in source:
    print("FAIL: Expanded quota rows should not render the old header/key table layout", file=sys.stderr)
    sys.exit(1)
if "L10n.t(.quotaMonitoringAuthorization)" in account_table:
    print("FAIL: Expanded account groups should not show low-value web-login authorization copy under the account name", file=sys.stderr)
    sys.exit(1)
if "providerWindowDetailKey" in source:
    print("FAIL: Expanded quota window details should belong to each account instead of one provider-level selected key", file=sys.stderr)
    sys.exit(1)
if "QuotaWindowDetails(windows: detailKey.quotaWindowDetails)" in source:
    print("FAIL: Expanded quota window detail rows should not use the loose spacer-based QuotaWindowDetails layout", file=sys.stderr)
    sys.exit(1)
if "ProviderQuotaAccountQuotaWindows(" not in account_table:
    print("FAIL: Expanded account groups should render quota windows inside the account group body", file=sys.stderr)
    sys.exit(1)
if "periodText: L10n.t(.remaining)" in account_table:
    print("FAIL: Expanded account groups should not repeat Remaining as both section label and fallback row label", file=sys.stderr)
    sys.exit(1)
if "ProviderQuotaAccountMetaPanel(" not in account_table:
    print("FAIL: Expanded account groups should show plan expiry and last update once in a compact meta panel", file=sys.stderr)
    sys.exit(1)
if "planEndText: key.planEndSummary.isEmpty ? nil : key.planEndSummary" not in account_table:
    print("FAIL: Expanded account meta panel should show package expiry only when the account exposes one", file=sys.stderr)
    sys.exit(1)
if "criticalTimeText: criticalTimeText" in account_table:
    print("FAIL: Expanded account quota rows should not duplicate package expiry from the account meta panel", file=sys.stderr)
    sys.exit(1)
try:
    window_details = account_table.split("struct ProviderQuotaAccountQuotaWindows: View", 1)[1]
except IndexError:
    print("FAIL: Expanded quota window details should be present in the account group section", file=sys.stderr)
    sys.exit(1)
if "window.detailValueText" not in window_details:
    print("FAIL: Expanded quota window rows should include reset or remaining detail next to the period value", file=sys.stderr)
    sys.exit(1)
if "ProviderQuotaAccountGridRow(" in account_table or "ProviderQuotaWindowDetailGridRow(" in account_table:
    print("FAIL: Expanded account groups should not reuse table grid rows that recreate empty columns", file=sys.stderr)
    sys.exit(1)
if "L10n.t(.lastUpdated)" not in account_table:
    print("FAIL: Expanded account meta panel should keep last-updated visible once per account", file=sys.stderr)
    sys.exit(1)
try:
    action_group = source.split("struct ProviderQuotaActionGroup: View", 1)[1].split("struct AddCredentialProviderList", 1)[0]
except IndexError:
    print("FAIL: ProviderQuotaActionGroup should exist before add-credential provider list", file=sys.stderr)
    sys.exit(1)
if "let isWatched: Bool" not in action_group or "let onToggleWatched: () -> Void" not in action_group:
    print("FAIL: Provider quota action group should accept watchlist state and a watchlist toggle action", file=sys.stderr)
    sys.exit(1)
if "ProviderWatchedToggleButton(" not in action_group:
    print("FAIL: Provider quota action group should render a compact star button for menu watchlist linkage", file=sys.stderr)
    sys.exit(1)
try:
    watched_button = source.split("struct ProviderWatchedToggleButton: View", 1)[1].split("struct ProviderQuotaActionGroup", 1)[0]
except IndexError:
    print("FAIL: ProviderWatchedToggleButton should exist before ProviderQuotaActionGroup", file=sys.stderr)
    sys.exit(1)
if '"star.fill"' not in watched_button or '"star"' not in watched_button:
    print("FAIL: Provider watchlist toggle should use familiar star and filled-star symbols", file=sys.stderr)
    sys.exit(1)
if "addWatchedProviderAction" not in watched_button or "removeWatchedProviderAction" not in watched_button:
    print("FAIL: Provider watchlist toggle should expose localized add/remove help text", file=sys.stderr)
    sys.exit(1)
for expected in ["L10n.t(.lastUpdated)"]:
    if expected not in account_table:
        print(f"FAIL: Expanded quota account table should use compact core columns and include {expected}", file=sys.stderr)
        sys.exit(1)
for noisy in ["ProviderQuotaActivityHeaderCell()", "QuotaActivityMeter(", "ProviderQuotaStatusPill(text: key.healthDisplayText", "key.quotaRowSubtitle"]:
    if noisy in account_table:
        print("FAIL: Expanded quota account rows should hide low-value activity/status/subtitle details and keep plan, quota, timing, update columns", file=sys.stderr)
        sys.exit(1)
try:
    quota_key_row = source.split("struct ProviderQuotaAccountGroup: View", 1)[1].split("struct ProviderQuotaTimingColumn: View", 1)[0]
except IndexError:
    print("FAIL: ProviderQuotaAccountGroup should exist before timing helpers", file=sys.stderr)
    sys.exit(1)
if "struct ProviderQuotaAccountValueText" not in source:
    print("FAIL: Expanded quota account values should use one shared account-row text style", file=sys.stderr)
    sys.exit(1)
if "ProviderQuotaColumnValue(value: criticalTimeText" in quota_key_row:
    print("FAIL: Expanded quota account critical time should not reuse the larger provider-summary value style", file=sys.stderr)
    sys.exit(1)
if quota_key_row.count("ProviderQuotaAccountValueText(") < 3:
    print("FAIL: Expanded quota account remaining, critical time, and updated columns should share one font size", file=sys.stderr)
    sys.exit(1)
if ".font(.system(size: 11" in quota_key_row or ".font(.caption2.weight(.medium))" in quota_key_row:
    print("FAIL: Expanded quota account value columns should not mix 11pt and caption2 fonts", file=sys.stderr)
    sys.exit(1)
if "ProviderQuotaAccountLayout.columnWidths(for:" not in source:
    print("FAIL: Expanded quota account table should calculate column widths from available content width", file=sys.stderr)
    sys.exit(1)
if "static let planWidth: CGFloat = 156" not in source:
    print("FAIL: Expanded quota account plan column should stay compact instead of reserving a wide empty package lane", file=sys.stderr)
    sys.exit(1)
if "plan: planWidth + extraWidth" in source or "remaining: remainingWidth + extraWidth" in source:
    print("FAIL: Expanded quota account plan/remaining columns should not absorb spare width after Activity is removed", file=sys.stderr)
    sys.exit(1)
if "plan: planWidth," not in source or "remaining: remainingWidth," not in source:
    print("FAIL: Expanded quota account plan/remaining columns should use fixed compact widths", file=sys.stderr)
    sys.exit(1)
if "remaining\n                    .frame(width: widths.remaining, height: height, alignment: .leading)" not in account_grid:
    print("FAIL: Expanded quota account remaining cells should align near package labels instead of floating across a wide blank lane", file=sys.stderr)
    sys.exit(1)
if "Text(L10n.t(.remaining))" in account_table:
    print("FAIL: Expanded account groups should omit the low-value Remaining section label above quota-window rows", file=sys.stderr)
    sys.exit(1)
for column in ["criticalTime", "updated"]:
    marker = f"{column}\n                    .frame(width: widths.{column}, height: height, alignment: .leading)"
    if marker not in account_grid:
        print(f"FAIL: Expanded quota account {column} cells should share the same left boundary as their headers", file=sys.stderr)
        sys.exit(1)
if "metaRow(label: L10n.t(.criticalTime), value: planEndText)" not in account_table:
    print("FAIL: Expanded account groups should show critical time once in the account meta panel", file=sys.stderr)
    sys.exit(1)
if "metaRow(label: L10n.t(.lastUpdated), value: updatedText)" not in account_table:
    print("FAIL: Expanded account groups should show last updated once in the account meta panel", file=sys.stderr)
    sys.exit(1)
if "Circle()\n                .fill(isFocused ? Color.accentColor : key.status.color)" not in account_table:
    print("FAIL: Expanded account groups should keep a status dot next to each account identity", file=sys.stderr)
    sys.exit(1)
if "totalWidthBudget" in account_table:
    print("FAIL: Expanded quota account table should not keep a fixed left-anchored total width budget", file=sys.stderr)
    sys.exit(1)
if ".frame(width: ProviderQuotaAccountLayout.totalWidthBudget" in account_table:
    print("FAIL: Expanded quota account header and rows should consume available width instead of using a fixed table frame", file=sys.stderr)
    sys.exit(1)
if ".padding(.horizontal, ProviderQuotaOverviewLayout.rowHorizontalPadding)" not in overview_header:
    print("FAIL: Provider quota overview header should use the shared table padding", file=sys.stderr)
    sys.exit(1)
if ".padding(.horizontal, ProviderQuotaOverviewLayout.rowHorizontalPadding)" not in provider_row:
    print("FAIL: Provider quota summary rows should use the shared table padding", file=sys.stderr)
    sys.exit(1)
if ".padding(.horizontal, ProviderQuotaOverviewLayout.rowHorizontalPadding)" not in account_table:
    print("FAIL: Expanded quota account rows should use the shared table padding so nested row borders align with provider rows", file=sys.stderr)
    sys.exit(1)
if "Spacer(minLength: ProviderQuotaAccountLayout.flexibleGapMinWidth)" in account_table:
    print("FAIL: Expanded quota account rows should not rely on a loose spacer for column alignment", file=sys.stderr)
    sys.exit(1)
if ".frame(width: 232, alignment: .leading)" in overview_header:
    print("FAIL: Provider quota overview provider column should not use the old overflow-prone width", file=sys.stderr)
    sys.exit(1)
if "trailingControlReserve: CGFloat = 120" in source:
    print("FAIL: Provider quota overview action reserve should not keep the old overflow-prone width", file=sys.stderr)
    sys.exit(1)
PY
assert_no_match 'key\.quotaRowSubtitle' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings quota key rows should hide quota subtitles in the compact four-column account layout"
assert_no_match 'Text\(key\.quotaPresentation\.primaryText\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings quota key rows should not repeat multi-window quota text when structured cycle details are rendered below"
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
assert_match 'shortDateTime\(visiblePlanEndsAt, includesYear: true\)' \
  "QuotaRadar/Models/APIKey.swift" \
  "Package expiry should include the year so annual subscriptions are unambiguous"
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
python3 - <<'PY'
from pathlib import Path
import sys

source = Path("QuotaRadar/Views/SettingsView.swift").read_text()
try:
    keys_view = source.split("struct KeysManagementView: View", 1)[1].split("// MARK: - Add Key Sheet", 1)[0]
    provider_rows = source.split("struct ProviderKeyRowsSection: View", 1)[1].split("struct APIKeyProviderBanner", 1)[0]
except IndexError:
    print("FAIL: Credential configuration view structure should be present", file=sys.stderr)
    sys.exit(1)

if "monitor.orderedVisibleProviders.compactMap" not in keys_view:
    print("FAIL: Credential configuration should preserve custom provider order while hiding providers without saved credentials", file=sys.stderr)
    sys.exit(1)
if "guard !providerKeys.isEmpty" not in keys_view:
    print("FAIL: Credential configuration should hide providers that have no saved credentials yet", file=sys.stderr)
    sys.exit(1)
if "ProviderQuotaEmptyKeyRow()" in provider_rows:
    print("FAIL: Credential configuration should not render empty placeholder rows for providers without saved credentials", file=sys.stderr)
    sys.exit(1)
if "provider.planTypeDisplayName()" not in source.split("struct APIKeyProviderBanner: View", 1)[1].split("struct APIKeyManagementRow", 1)[0]:
    print("FAIL: API Keys provider banners should show product type such as coding plan instead of the broad LLM category", file=sys.stderr)
    sys.exit(1)
try:
    management_row = source.split("struct APIKeyManagementRow: View", 1)[1].split("struct CredentialRowActionGroup", 1)[0]
    quota_key_row = source.split("struct ProviderQuotaKeyTableRow: View", 1)[1].split("struct ProviderQuotaTimingColumn", 1)[0]
    diagnostic_provider = source.split("struct CredentialDiagnosticProviderSection: View", 1)[1].split("struct CredentialDiagnosticRow", 1)[0]
    diagnostic_row = source.split("struct CredentialDiagnosticRow: View", 1)[1].split("struct DiagnosticMessageRow", 1)[0]
except IndexError:
    print("FAIL: Account-level row views should be present", file=sys.stderr)
    sys.exit(1)
if "stat.provider.planTypeDisplayName()" not in diagnostic_provider:
    print("FAIL: Diagnostic provider sections should show product type such as coding plan instead of the broad LLM category", file=sys.stderr)
    sys.exit(1)
if "Text(key.accountDisplayTitle)" not in management_row:
    print("FAIL: API key management rows should promote the account-level plan/name as the row title", file=sys.stderr)
    sys.exit(1)
if "key.accountDisplaySubtitle" not in management_row:
    print("FAIL: API key management rows should use account identity as the row subtitle instead of low-information saved-login text", file=sys.stderr)
    sys.exit(1)
if "Text(key.accountDisplayTitle)" not in quota_key_row:
    print("FAIL: Quota overview expanded account rows should promote each account's own plan/package name", file=sys.stderr)
    sys.exit(1)
if "key.accountDisplaySubtitle" in quota_key_row:
    print("FAIL: Quota overview expanded account rows should hide account identity subtitles in the compact account layout", file=sys.stderr)
    sys.exit(1)
if "item.credentialTitle" not in diagnostic_row or "item.credentialSubtitle" not in diagnostic_row:
    print("FAIL: Diagnostic credential rows should share the account-level title/subtitle display model", file=sys.stderr)
    sys.exit(1)
PY
assert_match 'Provider\.categoryDisplayOrder\.compactMap' \
  "QuotaRadar/Views/SettingsView.swift" \
  "API Keys tab should use the shared AI Search then LLM category order"
assert_no_match 'NavigationSplitView' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main window should not use NavigationSplitView because it can compress the sidebar below usable width"
assert_match 'HStack\(spacing: 0\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main window should use a fixed sidebar plus flexible content layout"
assert_match 'GeometryReader' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main window should manually allocate sidebar and content widths instead of letting fixed provider columns compress the sidebar"
assert_no_match '\.frame\(minWidth: 820, minHeight: 580\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main window must not keep the old narrow minimum size because the sidebar plus provider content gets squeezed"
assert_no_match '\.frame\(minWidth: 1040, minHeight: 640\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main window content must not force the default 1040px width as the minimum width"
assert_match '\.frame\(minWidth: 900, minHeight: 600\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main window should allow horizontal resizing below the default width while preserving usable provider panels"
assert_match 'private static let sidebarWidth: CGFloat = 220' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main window sidebar should be wide enough for localized navigation labels"
assert_no_match 'maxWidth: 160' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main window sidebar content must not keep the old narrow 160-point cap inside the wider column"
assert_match '\.frame\(width: Self\.sidebarWidth, height: geometry\.size\.height, alignment: \.topLeading\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main window sidebar should keep a fixed usable width when the split view is resized"
assert_match '\.fixedSize\(horizontal: true, vertical: false\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main window sidebar should resist horizontal compression when the provider table is narrow"
assert_match '\.layoutPriority\(1\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Main window sidebar should have higher layout priority than the provider table"
assert_match 'preferredSettingsContentSize = NSSize\(width: 1120, height: 640\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Main window should open wide enough for the broader sidebar and quota table"
assert_match 'minimumSettingsWindowSize = NSSize\(width: 900, height: 600\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Main window minimum size should allow users to resize horizontally below the default width"
assert_match 'window\.contentMinSize = minimumSettingsWindowSize' \
  "QuotaRadar/AppDelegate.swift" \
  "Main window should enforce the same minimum content size at the AppKit window layer"
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
assert_match 'ProviderQuotaAccountGroup' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Expanded provider quota rows should group each account's quota windows and metadata"
python3 - <<'PY'
from pathlib import Path
import sys

source = Path("QuotaRadar/Views/SettingsView.swift").read_text()
if "struct ProviderQuotaAccountGroup: View" not in source:
    print("FAIL: Provider quota account group should exist", file=sys.stderr)
    sys.exit(1)
group = source.split("struct ProviderQuotaAccountGroup: View", 1)[1].split("struct ProviderQuotaTimingColumn: View", 1)[0]
if "L10n.t(.apiKey)" in group:
    print("FAIL: Quota monitor expanded account groups should say Credential instead of API Key for cookie-backed providers", file=sys.stderr)
    sys.exit(1)
if "ProviderQuotaKeyTableHeader" in group or "ProviderQuotaKeyTableRow" in group:
    print("FAIL: Quota monitor expanded account groups should not embed the old key table", file=sys.stderr)
    sys.exit(1)
PY
assert_match 'ProviderQuotaAccountQuotaWindows' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Expanded provider quota rows should render quota windows inside account groups"
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
assert_no_match 'ZStack\(alignment: \.trailing\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider quota rows should keep row actions inside the table grid instead of overlaying the refresh control"
assert_no_match 'trailingControlReserve' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider quota rows should use the shared action column instead of a separate overlay reserve"
assert_match 'ProviderQuotaActionGroup\(' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider quota rows should keep provider actions in the same HStack grid as summary cells"
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
assert_match 'NetworkProxyModeOption' \
  "QuotaRadar/Models/AppAppearance.swift" \
  "Settings should expose a finite network proxy mode model"
assert_match 'customProxyURL' \
  "QuotaRadar/Models/AppAppearance.swift" \
  "Settings should persist a custom proxy URL for users who need a local proxy such as 127.0.0.1:7890"
assert_match 'configuredURLSessionConfiguration' \
  "QuotaRadar/Models/AppAppearance.swift" \
  "Quota requests should be able to build URLSession configuration from the saved proxy setting"
assert_match '"sock", "socks", "socks5"' \
  "QuotaRadar/Models/AppAppearance.swift" \
  "Custom proxy URLs should support SOCKS aliases such as sock:// and socks5://"
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
assert_match 'SettingsCenteredMenuPicker\(selection: \$appearanceStore\.autoRefreshInterval' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Automatic refresh selection should use the centered settings menu control"
assert_match 'private var supportsQuotaConsumingAutomaticRefresh: Bool' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings should derive costly automatic refresh visibility from provider capability"
assert_match 'Provider\.visibleCases\.contains' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings should inspect provider capabilities before showing costly automatic refresh controls"
assert_match 'capability\.matchesAutomaticRefreshLane\(consumesSearchQuota: true\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings should reuse the same costly automatic refresh capability lane as the scheduler"
assert_match 'if supportsQuotaConsumingAutomaticRefresh' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota-consuming refresh selection should only render when a provider explicitly allows automatic costly checks"
assert_match 'L10n\.t\(\.quotaConsumingManualOnlyWarning' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings should explain that current costly checks require manual confirmation"
assert_match 'SettingsCenteredMenuPicker\(selection: \$appearanceStore\.networkProxyMode' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Network proxy selection should use the centered settings menu control"
assert_no_match 'Picker\("", selection: \$appearanceStore\.(autoRefreshInterval|quotaConsumingAutoRefreshInterval|networkProxyMode)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings menu selections should not use the default left-biased Picker label"
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
assert_match 'icon: "hand\.raised\.fill"' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings should replace inactive costly auto-refresh controls with a manual-confirmation footnote"
assert_match 'text: L10n\.t\(\.quotaConsumingManualOnlyWarning\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings should describe current costly checks as manual-confirmation only"
assert_match 'SettingsFormSection\(title: L10n\.t\(\.settingsNetworkSection\)\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings should group network proxy controls separately from refresh and appearance"
assert_match 'SettingsCenteredMenuPicker\(selection: \$appearanceStore\.networkProxyMode' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings should let users select system, direct, or custom proxy behavior with centered selected text"
assert_match 'TextField\(L10n\.t\(\.customProxyPlaceholder\), text: \$appearanceStore\.customProxyURL\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings should let users enter a local proxy URL without editing environment variables"
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
assert_match 'Text\(key\.accountDisplayTitle\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential rows should use account-level plan or compact credential names as the primary title"
assert_match 'displayNote' \
  "QuotaRadar/Models/APIKey.swift" \
  "Credential account subtitles should localize persisted import-source notes instead of showing stale English"
assert_match 'key\.managementCredentialTypeBadgeText' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential rows should hide duplicate credential-type badges when the display name already names the type"
assert_match 'key\.accountDisplaySubtitle' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential rows should show account identity instead of low-information saved-login state"
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
assert_match 'CredentialRowActionGroup' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential rows should use one fixed action group so status, enabled, copy, and edit stay in the same order"
assert_match 'copyActionSlot' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential rows should reserve the copy column even when dashboard login authorizations are not copyable"
assert_match 'statusPillWidth: CGFloat = 126' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential rows should give status labels a stable width before the enabled toggle"
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
assert_match 'linkedAuthorizationID' \
  "QuotaRadar/Models/APIKey.swift" \
  "Copyable API-key records should be linkable to the web-login authorization that monitors their quota"
assert_match 'linkedAuthorizationID = key\.linkedAuthorizationID' \
  "QuotaRadar/Services/APIKeyStore.swift" \
  "Credential metadata should persist the API-key to web-login authorization link"
assert_match 'companionAPIKey' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Add Credential should let users store a user-facing API key together with dashboard quota authorization when useful"
assert_match 'linkedAuthorizationID: newKey\.id' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Add Credential should bind the optional API key to the newly saved web-login authorization"
assert_match 'linkedAuthorizationID = authorizationKey\.id' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Edit Credential should keep companion API keys bound to the edited web-login authorization"
assert_match 'monitor\.refreshProvider\(provider\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Saving a quota-monitoring credential should immediately refresh that provider instead of waiting for manual or automatic refresh"
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
assert_match 'onCredentialAvailable' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should expose an automatic credential-save callback"
assert_match 'reauthenticatedSecret' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should preserve non-cookie JSON credential metadata when refreshing cookies"
assert_no_match 'updatedKey\.key = cookieHeader' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication must not overwrite JSON dashboard credentials with a raw Cookie header"
assert_match 'reauthTargetSummary' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should show which saved credential/account will be updated"
assert_match 'L10n\.format\(\.reauthSavingTo' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should localize the account/credential save target"
assert_match 'multipleAuthorizationKeys\.count > 1' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should warn when multiple credentials exist for the same provider"
assert_match 'Picker\(L10n\.t\(\.reauthTargetCredential\), selection: \$selectedAuthorizationTargetID\)' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should require an explicit target when multiple web-login authorizations exist"
assert_match 'guard !requiresAuthorizationTargetSelection \|\| selectedAuthorizationTargetID != nil' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication must not silently overwrite the first credential when multiple targets exist"
assert_match 'validateAndPersistCredential' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should validate captured credentials before saving and closing"
assert_match 'persistCredential\(credential, allowEmptyStatus: false, dismissAfterSave: false\)' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Automatic dashboard credential capture should save in place instead of closing the WebView like a crash"
assert_match 'persistCredential\(capturedCredential, allowEmptyStatus: true, dismissAfterSave: true\)' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Manual dashboard credential save can close the reauthentication WebView after validation"
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
assert_match 'readCookiesForManualSave' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Manual dashboard credential save should re-read cookies instead of reusing a stale first failed capture"
assert_match 'DashboardCredentialCapturePolicy\.isCredentialReady\(latestCapturedCredential' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Manual dashboard credential save should reuse only a completed captured credential"
assert_match 'DashboardCredentialCapturePolicy\.manualRetryDelays' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Manual dashboard credential save should briefly retry after early partial cookie reads"
assert_match 'scheduleCookieCaptureRetry' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Automatic dashboard credential capture should schedule delayed retries after cookie and navigation events"
assert_match 'DashboardCredentialCapturePolicy\.automaticRetryDelays' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Automatic dashboard credential capture should wait for provider cookies to settle before giving up"
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
assert_match 'ProviderQuotaActionGroup' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota monitor rows should use a dedicated action group instead of adding loose provider actions to unrelated credential forms"
assert_match 'ProviderDashboardJumpButton\(provider: provider, size: size\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota monitor rows should use the shared dashboard jump action instead of an unlabelled loose icon"
assert_match 'ProviderReauthenticationButton\(provider: provider, size: size' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota monitor rows should use the shared reauthentication action with a clear professional tooltip"
assert_match 'accessibilityLabelText: refreshActionLabel' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Quota monitor refresh action should expose a localized clear accessibility label that reflects refresh state"
assert_match 'DashboardReauthSheet\(' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Add Credential reauthentication should create or update provider cookie credentials through the same flow as Volcengine"
assert_match 'key: nil,' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Add Credential reauthentication should create provider cookie credentials instead of editing an unrelated key"
assert_match 'onSaved: handleDashboardCredentialSaved' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Add Credential reauthentication should notify the add sheet when a web-login credential has already been saved"
assert_match 'private func handleDashboardCredentialSaved\(_ savedKey: APIKey\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Add Credential should treat successful web-login authorization as a completed add instead of leaving an empty disabled form"
assert_match 'showingReauth = false' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Add Credential should close the web-login sheet after the captured credential is saved"
assert_match 'linkedAuthorizationID: savedKey\.id' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Companion API keys entered during Add Credential should be linked to the saved web-login authorization"
assert_match 'let onSaved: \(\(APIKey\) -> Void\)\?' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should expose a saved-credential callback for create flows"
assert_match 'onSaved\?\(verifiedKey\)' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should report validated saved credentials back to the Add Credential flow"
assert_match 'onSaved\?\(candidateKey\)' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should report directly saved dashboard credentials back to the Add Credential flow"
python3 - <<'PY'
from pathlib import Path
import sys

settings_source = Path("QuotaRadar/Views/SettingsView.swift").read_text()
add_detail_source = settings_source.split("struct AddCredentialDetailPane: View", 1)[1].split("struct EditKeySheet: View", 1)[0]
if "ProviderDashboardJumpButton" in add_detail_source:
    print("FAIL: Add Credential detail pane should not show dashboard jump actions; quota monitor rows own those actions", file=sys.stderr)
    sys.exit(1)

source = Path("QuotaRadar/Views/DashboardReauthView.swift").read_text()
if "existingQuotaAuthorizationKey" not in source:
    print("FAIL: Dashboard reauthentication should match existing quota authorization credentials separately from stored API keys", file=sys.stderr)
    sys.exit(1)
if "key ?? monitor.apiKeys.first(where: { $0.provider == provider })" in source:
    print("FAIL: Dashboard reauthentication must not overwrite the first provider credential when it may be a copy-only API key", file=sys.stderr)
    sys.exit(1)
if "catch QuotaError.noSubscription" not in source or ".noSubscribedPlan" not in source:
    print("FAIL: Dashboard reauthentication should save valid dashboard authorization even when the account has no subscribed package", file=sys.stderr)
    sys.exit(1)
PY
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
assert_match 'https://console.volcengine.com/api/top/ark/cn-beijing/2024-01-01/ListSubscribeTrade' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Volcengine Coding Plan should query the subscription-trade endpoint for the concrete package name"
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
assert_match 'parseVolcengineCodingPlanSubscription' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Volcengine Coding Plan subscription responses should be parsed for concrete Lite/Pro package names"
assert_match 'parseOpenCodeGoUsage' \
  "QuotaRadar/Services/QuotaService.swift" \
  "OpenCode Go dashboard responses should be parsed as coding quota windows"
assert_match 'https://claude\.ai/api/organizations' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Claude subscription should discover the active organization through claude.ai organizations"
assert_match 'fetchClaudeOrganizationContext' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Claude subscription should preserve plan evidence from the organizations endpoint"
assert_match 'shouldRefreshLowChurnAccountMetadata\(for: key, bypassCooldown: bypassCooldown\)' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Low-churn account/package metadata should be refreshed on manual checks or at most once per day automatically"
assert_match 'Calendar\.current\.isDate\(lastUpdated, inSameDayAs: Date\(\)\)' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Automatic low-churn package lookups should be skipped after a successful refresh on the same day"
assert_match 'https://claude\.ai/api/organizations/.*/usage' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Claude subscription should query organization usage windows"
assert_match 'https://claude\.ai/api/organizations/.*/subscription_details' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Claude subscription should query subscription details for plan-cycle end"
assert_match 'parseClaudeSubscriptionUsage' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Claude subscription usage responses should be parsed as rolling quota windows"
assert_match 'BillingService/GetUsages' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Kimi subscription should query the Kimi billing usage endpoint for five-hour and weekly quota"
assert_no_match 'MembershipService/GetSubscriptionStat' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Kimi subscription should not query the unimplemented membership stat endpoint"
assert_match 'MembershipService/GetSubscription' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Kimi subscription should query the membership subscription endpoint"
assert_match 'parseKimiSubscriptionUsage' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Kimi subscription responses should be parsed as confirmed quota windows and subscription balance"
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
    "kimi",
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
    "kimi": (17, 17, 17),
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
require(Provider.visibleCases.contains(.kimiSubscription), "Kimi subscription should appear in provider pickers and visible app sections")
require(Provider.pendingQuotaIntegrationCases == [.xfyunTokenPlan, .volcengineTokenPlan, .aliyunTokenPlan, .tencentCloudTokenPlan], "Pending quota integration cases should include providers without confirmed user key evidence")
require(!Provider.visibleCases.contains(.xfyunTokenPlan), "XFYun Token Plan should not appear in visible provider lists yet")
require(!Provider.visibleCases.contains(.volcengineTokenPlan), "Volcengine Token Plan should not appear in visible provider lists yet")
require(!Provider.visibleCases.contains(.aliyunTokenPlan), "Aliyun Token Plan should not appear in visible provider lists yet")
require(Provider.visibleCases.contains(.aliyunCodingPlan), "Aliyun Coding Plan should be visible as a verification candidate when the user has a business key/account")
require(Provider.visibleCases.contains(.tencentCloudCodingPlan), "Tencent Cloud Coding Plan should be visible as a verification candidate when the user has a business key/account")
require(!Provider.visibleCases.contains(.tencentCloudTokenPlan), "Tencent Cloud Token Plan should stay hidden until the user has a real key to validate")
let customOrderedProviders = Provider.orderedVisibleCases(from: [.deepseek, .anthropic, .tavily, .brave])
require(customOrderedProviders.prefix(3) == [.deepseek, .tavily, .brave], "Custom provider order should filter hidden stale providers and preserve saved visible providers")
require(customOrderedProviders.count == Provider.visibleCases.count, "Custom provider order should append visible providers that are not in the saved order")
require(Set(customOrderedProviders) == Set(Provider.visibleCases), "Custom provider order should never drop current visible providers")

let masked = APIKey(name: "TAVILY_API_KEY", key: "abcd1234wxyz", provider: .tavily).maskedKey
require(masked == "abcd••••wxyz", "APIKey.maskedKey should expose the first four and last four characters")
let emptyMasked = APIKey(name: "EMPTY", key: "", provider: .tavily).maskedKey
require(emptyMasked == "No key value", "APIKey.maskedKey should label missing secrets")
require(Provider.brave.quotaCheckConsumesSearchQuota, "Brave quota checks use real search requests and must not run in automatic polling")
require(!Provider.tavily.quotaCheckConsumesSearchQuota, "Tavily usage endpoint should be safe for automatic polling")
let automaticRefreshNow = Date(timeIntervalSince1970: 1_800_000_000)
let dueAutomaticProviders = Provider.providersDueForAutomaticRefresh(
    in: [
        APIKey(name: "TAVILY_RECENT", key: "tvly-recent", provider: .tavily, lastUpdated: automaticRefreshNow.addingTimeInterval(-60)),
        APIKey(name: "SERPAPI_STALE", key: "serp-stale", provider: .serpapi, lastUpdated: automaticRefreshNow.addingTimeInterval(-20 * 60)),
        APIKey(name: "BRAVE_STALE", key: "brave-stale", provider: .brave, lastUpdated: automaticRefreshNow.addingTimeInterval(-25 * 60 * 60)),
        APIKey(name: "QUERIT_API_KEY", key: "querit-copy", provider: .querit, lastUpdated: automaticRefreshNow.addingTimeInterval(-20 * 60)),
    ],
    interval: 15 * 60,
    consumesSearchQuota: false,
    now: automaticRefreshNow
)
require(dueAutomaticProviders == [.serpapi], "Normal automatic refresh should use persisted lastUpdated and exclude costly/copy-only providers")
let dueQuotaConsumingProviders = Provider.providersDueForAutomaticRefresh(
    in: [
        APIKey(name: "BRAVE_RECENT", key: "brave-recent", provider: .brave, lastUpdated: automaticRefreshNow.addingTimeInterval(-60 * 60)),
        APIKey(name: "BRAVE_STALE", key: "brave-stale", provider: .brave, lastUpdated: automaticRefreshNow.addingTimeInterval(-25 * 60 * 60)),
        APIKey(name: "TAVILY_STALE", key: "tvly-stale", provider: .tavily, lastUpdated: automaticRefreshNow.addingTimeInterval(-25 * 60 * 60)),
    ],
    interval: 24 * 60 * 60,
    consumesSearchQuota: true,
    now: automaticRefreshNow
)
require(dueQuotaConsumingProviders.isEmpty, "Costly checks such as Brave should not run from automatic refresh queues without explicit user confirmation")
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
require(Provider.kimiSubscription.category == "LLM", "Kimi subscription should be grouped as an LLM quota provider")
require(Provider.xfyunCodingPlan.providerFamilyDisplayName(language: .simplifiedChinese) == "讯飞星火", "XFYun Coding Plan should expose XFYun Spark as the first-level provider family")
require(Provider.xfyunCodingPlan.planTypeDisplayName(language: .simplifiedChinese) == "coding plan", "XFYun Coding Plan should expose coding plan as the provider-level product type")
require(Provider.xfyunTokenPlan.planTypeDisplayName(language: .simplifiedChinese) == "Token plan", "XFYun Token Plan should expose Token plan as the provider-level product type")
require(Provider.volcengineCodingPlan.providerFamilyDisplayName(language: .simplifiedChinese) == "火山引擎", "Volcengine Coding Plan should expose Volcengine as the first-level provider family")
require(Provider.aliyunCodingPlan.providerFamilyDisplayName(language: .simplifiedChinese) == "阿里云", "Aliyun Coding Plan should expose Aliyun as the first-level provider family")
require(Provider.tencentCloudCodingPlan.providerFamilyDisplayName(language: .simplifiedChinese) == "腾讯云", "Tencent Cloud Coding Plan should expose Tencent Cloud as the first-level provider family")
require(Provider.tencentCloudTokenPlan.planTypeDisplayName(language: .english) == "Token Plan", "Tencent Cloud Token Plan should expose Token Plan as the provider-level product type in English")
require(Provider.claudeAPIUsage.providerFamilyDisplayName(language: .english) == "Claude", "Claude API usage should expose Claude as provider family")
require(Provider.claudeAPIUsage.planTypeDisplayName(language: .english) == "API Usage", "Claude API usage should expose API Usage as second-level plan name")
require(Provider.claudeSubscription.planTypeDisplayName(language: .english) == "Subscription", "Claude subscription should expose Subscription as the provider-level product type")
require(Provider.codexAPIUsage.providerFamilyDisplayName(language: .english) == "Codex", "Codex API usage should expose Codex as provider family")
require(Provider.codexSubscription.planTypeDisplayName(language: .english) == "Subscription", "Codex subscription should expose Subscription as the provider-level product type")
require(Provider.kimiSubscription.providerFamilyDisplayName(language: .english) == "Kimi", "Kimi subscription should expose Kimi as provider family")
require(Provider.kimiSubscription.planTypeDisplayName(language: .simplifiedChinese) == "订阅", "Kimi subscription should expose a localized provider-level subscription product type")
require(Provider.opencodeGo.planTypeDisplayName(language: .english) == "Subscription", "OpenCode Go should expose Subscription as the provider-level product type")
require(Provider.opencodeGo.planTypeDisplayName(language: .simplifiedChinese) == "订阅", "OpenCode Go should expose a localized provider-level subscription product type")
require(Provider.tavily.planTypeDisplayName(language: .simplifiedChinese) == nil, "Plain AI Search providers should not expose a second-level plan name")
require(Provider.kimiSubscription.dashboardURL == "https://www.kimi.com/membership/subscription?tab=quota", "Kimi subscription should open the membership quota page")
require(Provider.tencentCloudCodingPlan.dashboardURL == "https://console.cloud.tencent.com/tokenhub/codingplan", "Tencent Cloud Coding Plan should open the TokenHub Coding Plan page")
require(Provider.tencentCloudTokenPlan.dashboardURL == "https://console.cloud.tencent.com/tokenhub/tokenplan", "Tencent Cloud Token Plan should open the TokenHub Token Plan page")
require(Provider.bocha.dashboardURL == "https://open.bochaai.com/dashboard", "Bocha should expose its official dashboard jump link")
require(Provider.anysearch.dashboardURL == "https://app.anysearch.ai/login", "AnySearch should expose the official app login jump link from its website")
require(Provider.xfyunCodingPlan.supportsQuotaQuery, "XFYun Coding Plan should support dashboard quota checks")
require(!Provider.xfyunTokenPlan.supportsQuotaQuery, "XFYun Token Plan should not claim quota checks until a usage API is implemented")
require(Provider.volcengineCodingPlan.supportsQuotaQuery, "Volcengine Coding Plan should support dashboard quota checks")
require(!Provider.volcengineTokenPlan.supportsQuotaQuery, "Volcengine Token Plan should not claim quota checks until official API wiring is implemented and verified")
require(Provider.opencodeGo.supportsQuotaQuery, "OpenCode Go should support dashboard quota checks")
require(Provider.aliyunCodingPlan.supportsQuotaQuery, "Aliyun Coding Plan should support dashboard subscription checks through queryCodingPlanInstanceInfoV2")
require(!Provider.aliyunTokenPlan.supportsQuotaQuery, "Aliyun Token Plan should not claim quota checks until an official or dashboard API is implemented")
require(Provider.tencentCloudCodingPlan.supportsQuotaQuery, "Tencent Cloud Coding Plan should support dashboard quota checks through DescribePkg")
require(Provider.tencentCloudTokenPlan.supportsQuotaQuery, "Tencent Cloud Token Plan should expose quota checks through the official TokenHub API")
require(!Provider.claudeAPIUsage.supportsQuotaQuery, "Claude API usage should not claim quota checks until Admin API credentials are modeled and verified")
require(Provider.claudeSubscription.supportsQuotaQuery, "Claude subscription should support quota checks through verified claude.ai organization usage endpoints")
require(!Provider.codexAPIUsage.supportsQuotaQuery, "Codex API usage should not claim quota checks until OpenAI Admin usage credentials are modeled and verified")
require(Provider.codexSubscription.supportsQuotaQuery, "Codex subscription should support quota checks through the verified ChatGPT wham endpoint")
require(Provider.kimiSubscription.supportsQuotaQuery, "Kimi subscription should support quota checks through the Kimi membership endpoints")
require(Provider.aliyunCodingPlan.capability.credentialKind == .dashboardCookie, "Aliyun Coding Plan quota monitoring should use dashboard cookies")
require(Provider.aliyunCodingPlan.capability.usageSource == .dashboardAPI, "Aliyun Coding Plan should expose subscription status through the dashboard queryCodingPlanInstanceInfoV2 API")
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
require(Provider.claudeSubscription.capability.usageSource == .dashboardAPI, "Claude subscription should expose quota status through claude.ai organization dashboard APIs")
require(Provider.claudeSubscription.capability.canTestConnection, "Claude subscription should expose refresh after organization usage endpoints are wired in QuotaService")
require(Provider.brave.capability.supportsQuota, "Brave capability should expose quota when rate-limit headers are returned")
require(Provider.brave.capability.supportsReset, "Brave capability should expose reset timing when rate-limit headers are returned")
require(Provider.brave.capability.quotaRefreshKind == .costlyCheck, "Brave quota refresh should be modeled as a costly check because it spends a real search")
require(!Provider.brave.capability.allowsAutomaticRefresh, "Brave should not be eligible for normal automatic refresh by default")
require(Provider.brave.capability.requiresCostlyConfirmation, "Brave manual quota checks should require a costly-check confirmation")
require(Provider.tavily.capability.supportsQuota, "Tavily capability should expose monthly quota")
require(Provider.tavily.capability.supportsReset, "Tavily capability should expose the known monthly reset")
require(Provider.tavily.capability.supportsActivity, "Tavily capability should allow activity inference from snapshots")
require(Provider.tavily.capability.quotaRefreshKind == .refreshQuota, "Tavily quota refresh should read quota without spending real search quota")
require(Provider.tavily.capability.allowsAutomaticRefresh, "Tavily should be eligible for normal automatic refresh")
require(!Provider.tavily.capability.requiresCostlyConfirmation, "Tavily refresh should not require costly-check confirmation")
require(Provider.deepseek.capability.supportsBalance, "DeepSeek capability should expose account balance")
require(!Provider.deepseek.capability.supportsReset, "DeepSeek balance should not invent a reset cycle")
require(Provider.deepseek.capability.supportsActivity, "DeepSeek balance snapshots should support recent activity")
require(Provider.deepseek.capability.quotaRefreshKind == .refreshQuota, "DeepSeek balance refresh should be a normal quota refresh action")
require(Provider.deepseek.capability.allowsAutomaticRefresh, "DeepSeek balance checks should be eligible for automatic refresh")
require(Provider.claudeSubscription.capability.supportsQuota, "Claude subscription should expose quota windows")
require(Provider.claudeSubscription.capability.supportsPlan, "Claude subscription should expose plan metadata when available")
require(Provider.claudeSubscription.capability.supportsActivity, "Claude subscription should support reset-aware activity")
require(Provider.claudeSubscription.capability.supportsReset, "Claude subscription should expose reset timing from quota windows")
require(Provider.claudeSubscription.capability.connectionTestKind == .testConnection, "Claude connection tests should be modeled as no-cost credential checks")
require(Provider.claudeSubscription.capability.quotaRefreshKind == .refreshQuota, "Claude quota refresh should be distinct from connection testing")
require(Provider.claudeSubscription.capability.allowsAutomaticRefresh, "Claude subscription checks should be eligible for no-cost automatic refresh")
require(Provider.codexSubscription.capability.supportsQuota, "Codex subscription should expose quota windows")
require(Provider.codexSubscription.capability.supportsPlan, "Codex subscription should expose plan metadata when available")
require(Provider.codexSubscription.capability.supportsActivity, "Codex subscription should support reset-aware activity")
require(Provider.codexSubscription.capability.supportsReset, "Codex subscription should expose reset timing from quota windows")
require(Provider.codexSubscription.capability.connectionTestKind == .testConnection, "Codex connection tests should be modeled as no-cost credential checks")
require(Provider.codexSubscription.capability.quotaRefreshKind == .refreshQuota, "Codex quota refresh should be distinct from connection testing")
require(Provider.codexSubscription.capability.allowsAutomaticRefresh, "Codex subscription checks should be eligible for no-cost automatic refresh")
require(Provider.xfyunCodingPlan.capability.supportsQuota, "XFYun Coding Plan should expose quota windows")
require(Provider.xfyunCodingPlan.capability.supportsPlan, "XFYun Coding Plan should expose package names and expiry when returned")
require(Provider.xfyunCodingPlan.capability.supportsActivity, "XFYun Coding Plan should support reset-aware quota activity")
require(Provider.xfyunCodingPlan.capability.supportsReset, "XFYun Coding Plan should expose inferred reset timing")
require(Provider.xfyunCodingPlan.capability.connectionTestKind == .testConnection, "XFYun connection tests should be modeled as no-cost credential checks")
require(Provider.xfyunCodingPlan.capability.quotaRefreshKind == .refreshQuota, "XFYun quota refresh should read package quota without spending generation quota")
require(Provider.xfyunCodingPlan.capability.allowsAutomaticRefresh, "XFYun Coding Plan checks should be eligible for no-cost automatic refresh")
require(Provider.kimiSubscription.capability.credentialKind == .dashboardCookie, "Kimi subscription should store web login authorization separately from API keys")
require(Provider.kimiSubscription.capability.usageSource == .dashboardAPI, "Kimi subscription should expose quota status through Kimi membership dashboard APIs")
require(Provider.kimiSubscription.capability.canTestConnection, "Kimi subscription should offer a non-consuming membership quota check")
require(Provider.querit.supportsQuotaQuery, "Querit should support dashboard-cookie quota checks through the user account endpoint")
require(Provider.querit.capability.resetCycle == .notExposed, "Querit account endpoint exposes monthly usage but no reset/end date")
require(Provider.querit.supportsCompanionAPIKeyStorage, "Querit should allow storing an optional API key separately from dashboard authorization")
require(Provider.claudeSubscription.supportsCompanionAPIKeyStorage, "Claude subscription should allow saving an optional API key separately from web login authorization")
require(Provider.claudeSubscription.copyableAPIKeyCredentialName == "ANTHROPIC_API_KEY", "Claude subscription companion API key should use the familiar Anthropic API key name")
require(Provider.codexSubscription.supportsCompanionAPIKeyStorage, "Codex subscription should allow saving an optional API key separately from web login authorization")
require(Provider.codexSubscription.copyableAPIKeyCredentialName == "OPENAI_API_KEY", "Codex subscription companion API key should use the familiar OpenAI API key name")
require(Provider.kimiSubscription.supportsCompanionAPIKeyStorage, "Kimi subscription should allow saving an optional API key separately from web login authorization")
require(Provider.kimiSubscription.copyableAPIKeyCredentialName == "KIMI_API_KEY", "Kimi subscription companion API key should use the familiar Kimi API key name")
require(Provider.serper.capability.resetCycle == .notExposed, "Serper account endpoint exposes credit balance but no reset/end date")
require(Provider.exa.supportsQuotaQuery, "Exa should support usage checks when a service API key and API key id are configured")
require(Provider.exa.localizedUnsupportedQuotaLabel(language: .simplifiedChinese) == "需要 API 密钥", "Exa plain search keys should ask for an API key without confusing admin credential wording")
require(Provider.exa.localizedUnsupportedQuotaLabel(language: .traditionalChinese) == "需要 API 金鑰", "Exa plain search keys should ask for an API key without confusing admin credential wording in Traditional Chinese")
require(Provider.exa.localizedUnsupportedQuotaLabel(language: .japanese) == "API キーが必要", "Exa plain search keys should ask for an API key without confusing admin credential wording in Japanese")
require(Provider.exa.localizedUnsupportedQuotaLabel(language: .korean) == "API 키 필요", "Exa plain search keys should ask for an API key without confusing admin credential wording in Korean")
require(Provider.tavily.homeVisibleWithoutKeys, "Tavily should appear as an AI Search home placeholder before a key is configured")
require(Provider.brave.homeVisibleWithoutKeys, "Brave should appear as an AI Search home placeholder before a key is configured")
require(Provider.serpapi.homeVisibleWithoutKeys, "SerpAPI should appear as an AI Search home placeholder before a key is configured")
require(Provider.bocha.homeVisibleWithoutKeys, "Bocha should appear as an AI Search home placeholder before a key is configured")
require(Provider.anysearch.homeVisibleWithoutKeys, "AnySearch should appear as an AI Search home placeholder so its dashboard jump is visible before a key is configured")
require(Provider.claudeSubscription.homeVisibleWithoutKeys, "Claude should appear as an LLM home placeholder before a key is configured")
require(Provider.codexSubscription.homeVisibleWithoutKeys, "Codex should appear as an LLM home placeholder before a key is configured")
require(Provider.deepseek.homeVisibleWithoutKeys, "DeepSeek should appear as an LLM home placeholder before a key is configured")
require(Provider.aliyunCodingPlan.homeVisibleWithoutKeys, "Aliyun Coding Plan should appear as an LLM home placeholder before a key is configured")
require(!Provider.kimiSubscription.homeVisibleWithoutKeys, "Kimi should not expand the empty-home LLM placeholder set until the user configures it")
require(!Provider.xfyunCodingPlan.homeVisibleWithoutKeys, "XFYun Coding Plan should stay off empty home placeholders after the LLM placeholder set moves to Claude/Codex/DeepSeek/Aliyun")
require(!Provider.volcengineCodingPlan.homeVisibleWithoutKeys, "Volcengine Coding Plan should stay off empty home placeholders after the LLM placeholder set moves to Claude/Codex/DeepSeek/Aliyun")
require(!Provider.opencodeGo.homeVisibleWithoutKeys, "OpenCode Go should stay off empty home placeholders after the LLM placeholder set moves to Claude/Codex/DeepSeek/Aliyun")
require(!Provider.tencentCloudTokenPlan.homeVisibleWithoutKeys, "Tencent Cloud Token Plan should stay off the home view until a real key is available")
require(!Provider.anthropic.homeVisibleWithoutKeys, "Anthropic should stay off the home view unless explicitly configured")
require(!Provider.xfyunTokenPlan.homeVisibleWithoutKeys, "XFYun Token Plan should stay off the home view until quota parsing is implemented")
require(!Provider.volcengineTokenPlan.homeVisibleWithoutKeys, "Volcengine Token Plan should stay off the home view until quota parsing is implemented")
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
            planDisplayName: "高效版",
            quotaLabel: "5h 99% · week 79.3% · month 89.7%"
        )
    ]
)
require(xfyunStat.totalLimitDisplayText == "month 89.7%", "Coding Plan provider total should display the monthly percentage window")
require(xfyunStat.totalRemainingDisplayText == "week 79.3%", "Coding Plan provider remaining should display the lowest remaining percentage window with its period")
require(xfyunStat.statusBarProviderQuotaText == "5h 99% · week 79.3% · month 89.7%", "Status bar coding-plan quota text should show all quota cycles")
require(xfyunStat.statusBarProviderBadgeText == "week 79.3%", "Status bar coding-plan badge should display the tightest quota cycle")
let xfyunConcretePlanKey = APIKey(name: "XFYUN_CODING_PLAN_COOKIE", key: "cookie", provider: .xfyunCodingPlan, planDisplayName: "高效版")
require(xfyunConcretePlanKey.effectivePlanDisplayName == "高效版", "APIKey should prefer a refreshed concrete package name over the generic provider plan type")
require(xfyunConcretePlanKey.accountDisplayTitle == "高效版", "Dashboard-cookie account rows should replace low-information saved-login text with the concrete package name")
require(xfyunConcretePlanKey.accountDisplaySubtitle == "Web login authorization", "Dashboard-cookie account rows should keep the credential identity as secondary context")
require(xfyunConcretePlanKey.accountDisplaySubtitle != "Login authorization saved", "Dashboard-cookie account rows should not use saved-login state as account identity")
let xfyunNamedConcretePlanKey = APIKey(name: "Work account", key: "cookie", provider: .xfyunCodingPlan, note: "Team quota", planDisplayName: "高效版")
require(xfyunNamedConcretePlanKey.accountDisplayTitle == "高效版", "Multiple accounts on the same package should keep the real package name unchanged")
require(xfyunNamedConcretePlanKey.accountDisplaySubtitle == "Work account · Team quota", "Multiple same-package accounts should be distinguished by account name and note")
let subscriptionPlanNameFallbacks: [(Provider, String)] = [
    (.claudeSubscription, "Claude Subscription"),
    (.codexSubscription, "Codex Subscription"),
    (.kimiSubscription, "Kimi Subscription"),
    (.opencodeGo, "OpenCode Go Subscription"),
    (.xfyunCodingPlan, "XFYun Spark Coding Plan"),
    (.volcengineCodingPlan, "Volcengine Coding Plan"),
    (.aliyunCodingPlan, "Aliyun Coding Plan"),
    (.tencentCloudCodingPlan, "Tencent Cloud Coding Plan"),
]
for (provider, expectedPlanName) in subscriptionPlanNameFallbacks {
    let key = APIKey(name: "\(provider.rawValue)_SESSION", key: "cookie", provider: provider)
    require(key.effectivePlanDisplayName == expectedPlanName, "\(provider.rawValue) should fall back to a provider-specific subscription/package plan name")
}
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
require(multiXfyunStat.keyQuotaDisplayText == "week 64.4%", "Quota overview key quota should surface the tightest subscription/coding-plan window")
require(multiXfyunStat.credentialPoolDisplayText == "2 keys · 2 usable", "Quota overview credential pool should summarize monitoring credentials, not quota windows")
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
require(xfyunWithCompanionStat.credentialPoolDisplayText == "1 key · 1 usable", "Provider credential pool should exclude copy-only companion API keys")
let multiBraveStat = ProviderStats(
    provider: .brave,
    keys: [
        APIKey(name: "BRAVE_API_KEY", key: "brave-a", provider: .brave, remaining: 920, limit: 1000),
        APIKey(name: "BRAVE_API_KEY_2", key: "brave-b", provider: .brave, remaining: 0, limit: 1000)
    ]
)
require(multiBraveStat.keyQuotaDisplayText == "0 left", "Quota overview key quota should show the tightest key for API-key pools")
require(multiBraveStat.credentialPoolDisplayText == "2 keys · 1 usable · 1 attention", "Quota overview credential pool should show attention count for exhausted keys")
let menuSplitStats = [
    ProviderStats(provider: .tavily, keys: [
        APIKey(name: "TAVILY_EMPTY", key: "tvly-empty", provider: .tavily, remaining: 0, limit: 1000),
        APIKey(name: "TAVILY_LOW", key: "tvly-low", provider: .tavily, remaining: 42, limit: 1000),
        APIKey(name: "TAVILY_OK", key: "tvly-ok", provider: .tavily, remaining: 650, limit: 1000)
    ])
]
require(MenuQuotaItem.attentionItems(from: menuSplitStats, limit: 5).map { $0.key.name } == ["TAVILY_EMPTY"], "Status bar attention items should focus on exhausted, failed, or expired credentials")
require(MenuQuotaItem.lowQuotaItems(from: menuSplitStats, limit: 5).map { $0.key.name } == ["TAVILY_LOW"], "Status bar low-quota items should separately surface providers that are still usable but tight")
require(MenuQuotaItem(provider: .tavily, key: menuSplitStats[0].keys[0]).signalReason == .exhausted, "Menu quota items should explain exhausted quota as the reason they are surfaced")
require(MenuQuotaItem(provider: .tavily, key: menuSplitStats[0].keys[1]).signalReason == .lowQuota, "Menu quota items should explain low quota as the reason they are surfaced")
let soonPlanEnd = Date().addingTimeInterval(5 * 24 * 60 * 60)
let laterPlanEnd = Date().addingTimeInterval(20 * 24 * 60 * 60)
let expiredPlanEnd = Date().addingTimeInterval(-1 * 24 * 60 * 60)
let expiringStats = [
    ProviderStats(provider: .xfyunCodingPlan, keys: [
        APIKey(name: "XFYUN_SOON", key: "cookie-soon", provider: .xfyunCodingPlan, remaining: 6000, limit: 10000, planEndsAt: soonPlanEnd),
        APIKey(name: "XFYUN_LATER", key: "cookie-later", provider: .xfyunCodingPlan, remaining: 6000, limit: 10000, planEndsAt: laterPlanEnd),
        APIKey(name: "XFYUN_EXPIRED", key: "cookie-expired", provider: .xfyunCodingPlan, remaining: 6000, limit: 10000, planEndsAt: expiredPlanEnd)
    ])
]
require(MenuQuotaItem.expiringSoonItems(from: expiringStats, limit: 5).map { $0.key.name } == ["XFYUN_SOON"], "Status bar expiring-soon items should show only future plan or balance expiries within 14 days")
require(MenuQuotaItem(provider: .xfyunCodingPlan, key: expiringStats[0].keys[0]).signalReason == .expiringSoon, "Menu quota items should explain expiring packages as the reason they are surfaced")
let companionDiagnostic = xfyunWithCompanionStat.credentialDiagnosticItems.first {
    $0.key.name == "XFYUN_CODING_PLAN_API_KEY"
}
require(companionDiagnostic == nil, "Diagnostics should merge copy-only companion API keys into the paired quota-monitoring authorization instead of rendering a second diagnostic row")
let mergedCompanionDiagnostic = xfyunWithCompanionStat.credentialDiagnosticItems.first {
    $0.key.name == "XFYUN_CODING_PLAN_COOKIE"
}
require(mergedCompanionDiagnostic != nil, "Diagnostics should keep the quota-monitoring authorization as the primary diagnostic row")
require(mergedCompanionDiagnostic!.companionAPIKey?.name == "XFYUN_CODING_PLAN_API_KEY", "Diagnostics should attach the copyable invocation API key to the authorization diagnostic row")
require(mergedCompanionDiagnostic!.credentialTitle == "XFYun Spark Coding Plan", "Diagnostics should use the account plan/name as the primary credential title when no concrete package name has been refreshed yet")
require(mergedCompanionDiagnostic!.credentialSubtitle == "Web login authorization · includes invocation key", "Diagnostics should describe credential identity plus companion API key without low-information saved-login text")
require(mergedCompanionDiagnostic!.diagnosticStatusText == "Healthy", "Merged companion API-key diagnostics should use connection health, not quota status")
require(mergedCompanionDiagnostic!.httpStatusText == "200", "Merged companion API-key diagnostics should use the quota-monitoring authorization HTTP status")
require(mergedCompanionDiagnostic!.connectionDiagnosticSummary == nil, "Healthy diagnostics should not repeat quota display content in the diagnostics page")
require(xfyunWithCompanionStat.diagnosticCredentialGroupCountText == "1 credential group", "Diagnostics provider header should count linked authorization plus API key as one credential group")
AppLanguageStore.shared.language = .simplifiedChinese
require(xfyunWithCompanionStat.diagnosticCredentialGroupCountText == "1 组凭据", "Diagnostics provider header should localize credential group counts")
require(mergedCompanionDiagnostic!.credentialTitle == "讯飞星火 coding plan", "Diagnostics account plan fallback should localize")
require(mergedCompanionDiagnostic!.credentialSubtitle == "网页登录授权 · 含调用密钥", "Diagnostics credential identity plus companion summary should localize")
let kimiUnknownQuotaDiagnostic = CredentialDiagnosticItem(
    key: APIKey(name: "KIMI_SESSION", key: "cookie", provider: .kimiSubscription, lastHTTPStatus: 200, quotaLabel: "Quota unavailable"),
    statusKey: APIKey(name: "KIMI_SESSION", key: "cookie", provider: .kimiSubscription, lastHTTPStatus: 200, quotaLabel: "Quota unavailable"),
    companionAPIKey: nil
)
require(kimiUnknownQuotaDiagnostic.diagnosticStatusText == "正常", "Diagnostics should not show quota-unavailable text as the connection status")
require(kimiUnknownQuotaDiagnostic.connectionDiagnosticSummary == nil, "Diagnostics should not repeat quota-unavailable content in the diagnostic message")
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
require(localizedExaUsage.quotaDisplayText == "可用 · 额度未知", "Exa usage-only checks should not expose used-cost wording in the main quota UI")
require(localizedExaUsage.quotaPresentation.primaryText == "可用 · 额度未知", "Exa usage-only quota presentation should stay remaining-first and hide raw used-cost labels")
require(localizedExaUsage.remainingBadgeText == "正常", "Exa usage-only checks should show a localized OK badge instead of a fake percentage")
let localizedQueritUsage = APIKey(name: "QUERIT_COOKIE", key: "querit", provider: .querit, remaining: Int.max, limit: Int.max, quotaText: .localized(.monthlyRequestsUsedFormat, "3601"), quotaLabel: "3601 monthly requests used")
require(localizedQueritUsage.quotaDisplayText == "可用 · 额度未知", "Querit usage-only checks should not expose used-request wording in the main quota UI")
require(localizedQueritUsage.quotaPresentation.primaryText == "可用 · 额度未知", "Querit usage-only quota presentation should stay remaining-first and hide raw used-request labels")
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
require(generatedXfyunCookie.managementCredentialValueText == "登录授权已保存", "XFYun dashboard-cookie rows should show a saved authorization state instead of a raw cookie or credential-type label")
require(generatedXfyunCookie.accountDisplayTitle == "讯飞星火 coding plan", "XFYun dashboard-cookie account rows should use package fallback as the visible title when no concrete package has been refreshed")
require(generatedXfyunCookie.accountDisplaySubtitle == "网页登录授权", "XFYun dashboard-cookie account rows should show credential identity instead of saved-login state")
require(generatedXfyunCookie.copyableCredentialValue == nil, "Dashboard-cookie quota authorizations must not be copyable")
let generatedXfyunAPIKey = APIKey(name: "XFYUN_CODING_PLAN_API_KEY", key: "xfyun-api-redacted", provider: .xfyunCodingPlan)
require(generatedXfyunAPIKey.isStoredAPIKeyOnlyCredential, "XFYun Coding Plan API keys should be stored separately from quota-monitoring authorization")
require(generatedXfyunAPIKey.managementDisplayName == "API 密钥", "XFYun API-key-only records should show the API key label")
require(generatedXfyunAPIKey.managementCredentialValueText == "xfyu••••cted", "XFYun API-key-only records should show a masked API key value")
require(generatedXfyunAPIKey.quotaDisplayText == "仅保存用于复制", "API-key-only records should explain that they are copy-only instead of repeating that the API key was saved")
require(generatedXfyunAPIKey.healthDisplayText == "仅保存用于复制", "API-key-only rows should not show the redundant API key saved status")
require(generatedXfyunAPIKey.diagnosticSummary == "仅保存用于复制", "API-key-only records should explain that they are not quota-monitoring credentials")
require(generatedXfyunAPIKey.copyableCredentialValue == "xfyun-api-redacted", "API-key-only records should be copyable")
let generatedQueritCookie = APIKey(name: "QUERIT_COOKIE", key: "osduss=redacted; passOsRefreshTk=redacted", provider: .querit)
require(generatedQueritCookie.managementDisplayName == "额度监控授权", "Querit dashboard-cookie rows should identify quota monitoring authorization")
require(generatedQueritCookie.managementCredentialValueText == "登录授权已保存", "Querit dashboard-cookie rows should show a saved authorization state")
require(generatedQueritCookie.accountDisplayTitle == "额度监控授权", "Querit dashboard-cookie account rows should fall back to the compact monitoring authorization title when no provider plan exists")
require(generatedQueritCookie.accountDisplaySubtitle == "网页登录授权", "Querit dashboard-cookie account rows should show credential identity instead of saved-login state")
require(generatedQueritCookie.copyableCredentialValue == nil, "Querit dashboard authorization must not be copyable")
let generatedQueritAPIKey = APIKey(name: "QUERIT_API_KEY", key: "querit-api-redacted", provider: .querit)
require(generatedQueritAPIKey.isStoredAPIKeyOnlyCredential, "Querit API keys should be stored separately from quota-monitoring authorization")
require(generatedQueritAPIKey.managementDisplayName == "API 密钥", "Querit optional API-key records should show the API key label")
require(generatedQueritAPIKey.copyableCredentialValue == "querit-api-redacted", "Querit optional API-key records should be copyable")
let generatedClaudeSubscriptionAPIKey = APIKey(name: "ANTHROPIC_API_KEY", key: "sk-ant-redacted", provider: .claudeSubscription)
require(generatedClaudeSubscriptionAPIKey.isStoredAPIKeyOnlyCredential, "Claude subscription API keys should be stored separately from web login authorization")
require(generatedClaudeSubscriptionAPIKey.managementDisplayName == "API 密钥", "Claude subscription API-key-only records should show the API key label")
require(generatedClaudeSubscriptionAPIKey.copyableCredentialValue == "sk-ant-redacted", "Claude subscription API-key-only records should be copyable")
let generatedCodexSubscriptionAPIKey = APIKey(name: "OPENAI_API_KEY", key: "sk-openai-redacted", provider: .codexSubscription)
require(generatedCodexSubscriptionAPIKey.isStoredAPIKeyOnlyCredential, "Codex subscription API keys should be stored separately from web login authorization")
require(generatedCodexSubscriptionAPIKey.managementDisplayName == "API 密钥", "Codex subscription API-key-only records should show the API key label")
require(generatedCodexSubscriptionAPIKey.copyableCredentialValue == "sk-openai-redacted", "Codex subscription API-key-only records should be copyable")
let generatedKimiSubscriptionAPIKey = APIKey(name: "KIMI_API_KEY", key: "sk-kimi-redacted", provider: .kimiSubscription)
require(generatedKimiSubscriptionAPIKey.isStoredAPIKeyOnlyCredential, "Kimi subscription API keys should be stored separately from web login authorization")
require(generatedKimiSubscriptionAPIKey.managementDisplayName == "API 密钥", "Kimi subscription API-key-only records should show the API key label")
require(generatedKimiSubscriptionAPIKey.copyableCredentialValue == "sk-kimi-redacted", "Kimi subscription API-key-only records should be copyable")
let generatedOpenCodeCookie = APIKey(name: "OPENCODE_GO_COOKIE", key: #"{"cookie":"auth=redacted-cookie","workspaceID":"wrk_123"}"#, provider: .opencodeGo)
require(generatedOpenCodeCookie.managementCredentialValueText == "登录授权已保存", "OpenCode Go dashboard-cookie rows should not show serialized credential values")
require(generatedOpenCodeCookie.accountDisplayTitle == "OpenCode Go 订阅", "OpenCode Go account rows should use subscription fallback as the visible title")
require(generatedOpenCodeCookie.accountDisplaySubtitle == "网页登录授权", "OpenCode Go account rows should show credential identity instead of saved-login state")
require(generatedOpenCodeCookie.copyableCredentialValue == nil, "OpenCode Go web login authorization should not be copyable")
let legacyDashboardNote = APIKey(name: "ALIYUN_CODING_PLAN_COOKIE", key: "login=redacted", provider: .aliyunCodingPlan, note: "网页登录授权")
require(legacyDashboardNote.displayNote == nil, "Legacy dashboard authorization notes should not leak a stale localized credential-type label")
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
require(localizedResetKey.quotaRowSubtitle == localizedResetKey.quotaPresentation.primaryText, "Single-value quota rows should keep their compact quota subtitle")
let annualPlanEndDate = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2027, month: 6, day: 28, hour: 17, minute: 48, second: 58))!
let annualPlanEndKey = APIKey(
    name: "XFYUN_CODING_PLAN_COOKIE",
    key: "cookie",
    provider: .xfyunCodingPlan,
    planEndsAt: annualPlanEndDate
)
require(L10n.shortDateTime(annualPlanEndDate, includesYear: true).contains("2027"), "Year-aware date formatting should include the year")
require(!L10n.shortDateTime(annualPlanEndDate).contains("2027"), "Normal reset/update timestamps should remain compact by default")
require(annualPlanEndKey.planEndSummary.contains("2027"), "Annual package expiry should include the year")
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
require(codexWindowResetKey.quotaRowSubtitle == "", "Codex subscription should not repeat multi-window quota text in the compact credential row")
require(codexWindowResetKey.quotaWindowDetails.count == 2, "Codex subscription should keep reset timing attached to the five-hour and weekly quota rows")
require(codexWindowResetKey.quotaWindowDetails.allSatisfy { $0.detailValueText != nil }, "Codex subscription quota rows should expose reset timing per window")
let claudeWindowResetKey = APIKey(
    name: "CLAUDE_SUBSCRIPTION_SESSION",
    key: "cookie",
    provider: .claudeSubscription,
    resetAt: localizedResetDate,
    quotaText: LocalizedTextDescriptor.quotaWindows([
        QuotaWindowText(name: "5h", percentText: "98%", resetAt: localizedResetDate),
        QuotaWindowText(name: "week", percentText: "100%", resetAt: localizedResetDate)
    ])
)
require(claudeWindowResetKey.visibleQuotaResetSummary == "", "Claude subscription should not duplicate 5h/week reset timing in the last-updated timing column")
require(claudeWindowResetKey.quotaRowSubtitle == "", "Claude subscription should not repeat multi-window quota text in the compact credential row")
require(claudeWindowResetKey.quotaWindowDetails.count == 2, "Claude subscription should keep reset timing attached to the five-hour and weekly quota rows")
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
require(volcengineDisplayKey.quotaRowSubtitle == "", "Volcengine should not repeat multi-window quota text above the quota-window detail rows")
require(volcengineDisplayKey.visibleQuotaResetSummary == "", "Volcengine should not show the monthly reset as a top-level reset when it is also the package end")
require(volcengineDisplayKey.planEndSummary == L10n.format(.planEndsDate, L10n.shortDateTime(localizedResetDate, includesYear: true)), "Volcengine should present the monthly reset timestamp as package expiry in compact timing rows")
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
require(opencodeDisplayKey.quotaRowSubtitle == "", "OpenCode Go should not repeat multi-window quota text above the quota-window detail rows")
require(opencodeDisplayKey.planEndSummary == L10n.format(.planEndsDate, L10n.shortDateTime(localizedResetDate, includesYear: true)), "OpenCode Go should present the monthly reset timestamp as package expiry in compact timing rows")
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
let samePriorityMenuItems = MenuQuotaItem.topItems(from: [
    ProviderStats(provider: .tavily, keys: [APIKey(name: "TAVILY_LOW", key: "tvly-low", provider: .tavily, remaining: 100, limit: 1000)]),
    ProviderStats(provider: .brave, keys: [APIKey(name: "BRAVE_LOW", key: "brave-low", provider: .brave, remaining: 100, limit: 1000)]),
], limit: 2, providerOrder: [.brave, .tavily])
require(samePriorityMenuItems.map { $0.provider } == [.brave, .tavily], "Status bar menu items should use the user's provider order as the stable ranking tie-breaker")
let trendNow = Date(timeIntervalSince1970: 1_800_000_000)
let trendKeyID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
let trendKey = APIKey(id: trendKeyID, name: "TAVILY_TREND", key: "tvly-trend", provider: .tavily, remaining: 700, limit: 1000)
let decreasingTrend = QuotaTrendSummary.trendSummary(
    for: trendKey,
    snapshots: [
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-2 * 24 * 60 * 60), outcome: .success, remaining: 900, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200),
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 700, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200)
    ],
    now: trendNow
)
require(decreasingTrend.direction == .decreasing, "Quota trend should mark meaningful remaining-quota drops as decreasing")
require(abs(decreasingTrend.consumedPercentPoints - 20) < 0.001, "Quota trend should report consumed percentage points")
require(decreasingTrend.consumedUnits == 200, "Quota trend should report consumed units when limits are comparable")
let resetDateA = trendNow.addingTimeInterval(24 * 60 * 60)
let resetDateB = trendNow.addingTimeInterval(8 * 24 * 60 * 60)
let replenishedTrend = QuotaTrendSummary.trendSummary(
    for: trendKey,
    snapshots: [
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-4 * 60 * 60), outcome: .success, remaining: 100, limit: 1000, resetAt: resetDateA, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200),
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 1000, limit: 1000, resetAt: resetDateB, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200)
    ],
    now: trendNow
)
require(replenishedTrend.direction == .replenished, "Quota trend should treat reset-window increases as replenishment instead of consumption")
let stableTrend = QuotaTrendSummary.trendSummary(
    for: trendKey,
    snapshots: [
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-3 * 60 * 60), outcome: .success, remaining: 900, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200),
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 895, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200)
    ],
    now: trendNow
)
require(stableTrend.direction == .stable, "Quota trend should ignore tiny changes below one percentage point")
let tavilyActivity = QuotaActivitySummary.activitySummary(
    for: trendKey,
    snapshots: [
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-2 * 24 * 60 * 60), outcome: .success, remaining: 900, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200),
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 700, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200)
    ],
    now: trendNow,
    language: .english
)
require(tavilyActivity.kind == .fixedQuota, "Quota activity should classify fixed-credit quota consumption")
require(tavilyActivity.shouldRender, "Quota activity should render meaningful fixed-credit consumption")
require(tavilyActivity.deltaText == "-200", "Quota activity should expose consumed fixed-credit units")
require(tavilyActivity.currentText == "70%", "Quota activity should expose the current remaining quota for the activity lane")
require(abs((tavilyActivity.usedFraction ?? 0) - 0.30) < 0.0001, "Quota activity should expose current used fraction for fixed-credit meters")
let refreshDeltaConsumedText = QuotaRefreshDeltaSummary.refreshDeltaText(
    for: trendKey,
    snapshots: [
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-5 * 60), outcome: .success, remaining: 900, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200),
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-30), outcome: .success, remaining: 700, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200)
    ],
    now: trendNow,
    language: .english
)
require(refreshDeltaConsumedText == "Remaining -200", "Latest refresh delta should explain quota change from the remaining-quota perspective")
let refreshDeltaNoChangeText = QuotaRefreshDeltaSummary.refreshDeltaText(
    for: trendKey,
    snapshots: [
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-5 * 60), outcome: .success, remaining: 700, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200),
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-30), outcome: .success, remaining: 700, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200)
    ],
    now: trendNow,
    language: .english
)
require(refreshDeltaNoChangeText == "Updated · no change", "Latest refresh delta should call out unchanged quota")
let refreshDeltaRecoveredText = QuotaRefreshDeltaSummary.refreshDeltaText(
    for: trendKey,
    snapshots: [
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-5 * 60), outcome: .success, remaining: 100, limit: 1000, resetAt: resetDateA, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200),
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-30), outcome: .success, remaining: 1000, limit: 1000, resetAt: resetDateB, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200)
    ],
    now: trendNow,
    language: .english
)
require(refreshDeltaRecoveredText == "Reset", "Latest refresh delta should show replenishment compactly")
let refreshDeltaFailedText = QuotaRefreshDeltaSummary.refreshDeltaText(
    for: trendKey,
    snapshots: [
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-5 * 60), outcome: .success, remaining: 700, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200),
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-30), outcome: .failed, remaining: 700, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 500)
    ],
    now: trendNow,
    language: .english
)
require(refreshDeltaFailedText == "Refresh failed", "Latest refresh delta should summarize failed refresh attempts")
let staleRefreshDeltaText = QuotaRefreshDeltaSummary.refreshDeltaText(
    for: trendKey,
    snapshots: [
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), outcome: .success, remaining: 900, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200),
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-90 * 60), outcome: .success, remaining: 700, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200)
    ],
    now: trendNow,
    language: .english
)
require(staleRefreshDeltaText == nil, "Latest refresh delta should not linger after the recent refresh window")
let sparklineSamples = QuotaSparklineSample.samples(
    for: trendKey,
    snapshots: [
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-4 * 60 * 60), outcome: .success, remaining: 1000, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200),
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-3 * 60 * 60), outcome: .failed, remaining: 1000, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 500),
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), outcome: .success, remaining: 750, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200),
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 500, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200)
    ],
    now: trendNow
)
require(sparklineSamples.map { $0.value } == [1.0, 0.75, 0.5], "Quota sparkline should use successful comparable quota percentages in time order")
require(sparklineSamples.map { $0.recordedAt } == sparklineSamples.map { $0.recordedAt }.sorted(), "Quota sparkline samples should be sorted by time")
require(!QuotaSparklineSample.shouldRenderSparkline([
    QuotaSparklineSample(recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), value: 0.9),
    QuotaSparklineSample(recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), value: 0.7)
]), "Quota sparkline should stay hidden until at least three valid samples exist")
require(!QuotaSparklineSample.shouldRenderSparkline([
    QuotaSparklineSample(recordedAt: trendNow.addingTimeInterval(-20 * 60), value: 0.9),
    QuotaSparklineSample(recordedAt: trendNow.addingTimeInterval(-10 * 60), value: 0.8),
    QuotaSparklineSample(recordedAt: trendNow.addingTimeInterval(-1 * 60), value: 0.7)
]), "Quota sparkline should stay hidden when the observation span is too short")
require(!QuotaSparklineSample.shouldRenderSparkline([
    QuotaSparklineSample(recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), value: 0.904),
    QuotaSparklineSample(recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), value: 0.9035),
    QuotaSparklineSample(recordedAt: trendNow.addingTimeInterval(-30 * 60), value: 0.903)
]), "Quota sparkline should stay hidden when quota barely changes")
require(QuotaSparklineSample.shouldRenderSparkline([
    QuotaSparklineSample(recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), value: 0.95),
    QuotaSparklineSample(recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), value: 0.80),
    QuotaSparklineSample(recordedAt: trendNow.addingTimeInterval(-30 * 60), value: 0.70)
]), "Quota sparkline should render when enough samples show a meaningful quota change")
require(QuotaSparklineSample.shouldRenderSparkline([
    QuotaSparklineSample(recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), value: 0.457),
    QuotaSparklineSample(recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), value: 0.459),
    QuotaSparklineSample(recordedAt: trendNow.addingTimeInterval(-30 * 60), value: 0.461)
]), "Quota sparkline should render large-period quota changes once they move by a few tenths of a percentage point")
let deepseekTrendKeyID = UUID(uuidString: "14141414-1414-1414-1414-141414141414")!
let deepseekTrendKey = APIKey(
    id: deepseekTrendKeyID,
    name: "DEEPSEEK_API_KEY",
    key: "deepseek-trend",
    provider: .deepseek,
    remaining: 850,
    limit: nil
)
let deepseekBalanceSparklineSamples = QuotaSparklineSample.samples(
    for: deepseekTrendKey,
    snapshots: [
        QuotaSnapshot(keyID: deepseekTrendKeyID, provider: .deepseek, credentialName: "DEEPSEEK_API_KEY", recordedAt: trendNow.addingTimeInterval(-3 * 60 * 60), outcome: .success, remaining: 1250, limit: nil, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "CNY 12.50 available", httpStatus: 200),
        QuotaSnapshot(keyID: deepseekTrendKeyID, provider: .deepseek, credentialName: "DEEPSEEK_API_KEY", recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), outcome: .success, remaining: 1000, limit: nil, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "CNY 10.00 available", httpStatus: 200),
        QuotaSnapshot(keyID: deepseekTrendKeyID, provider: .deepseek, credentialName: "DEEPSEEK_API_KEY", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 850, limit: nil, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "CNY 8.50 available", httpStatus: 200)
    ],
    now: trendNow
)
let expectedDeepseekBalanceValues = [1.0, 0.8, 0.68]
require(zip(deepseekBalanceSparklineSamples.map { $0.value }, expectedDeepseekBalanceValues).allSatisfy { abs($0 - $1) < 0.0001 }, "DeepSeek quota sparklines should draw balance changes even when the endpoint does not expose a quota limit")
require(QuotaSparklineSample.shouldRenderSparkline(deepseekBalanceSparklineSamples), "DeepSeek balance sparklines should render once enough balance samples show a meaningful change")
let deepseekActivity = QuotaActivitySummary.activitySummary(
    for: deepseekTrendKey,
    snapshots: [
        QuotaSnapshot(keyID: deepseekTrendKeyID, provider: .deepseek, credentialName: "DEEPSEEK_API_KEY", recordedAt: trendNow.addingTimeInterval(-3 * 60 * 60), outcome: .success, remaining: 1250, limit: nil, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "CNY 12.50 available", httpStatus: 200),
        QuotaSnapshot(keyID: deepseekTrendKeyID, provider: .deepseek, credentialName: "DEEPSEEK_API_KEY", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 850, limit: nil, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "CNY 8.50 available", httpStatus: 200)
    ],
    now: trendNow,
    language: .english
)
require(deepseekActivity.kind == .moneyBalance, "Quota activity should classify money-balance spend separately from quota-window consumption")
require(deepseekActivity.deltaText == "-CNY 4.00", "Quota activity should expose money-balance spend as currency")
require(deepseekActivity.shouldRender, "Quota activity should render meaningful money-balance spend")
let deepseekRecoveredActivity = QuotaActivitySummary.activitySummary(
    for: deepseekTrendKey,
    snapshots: [
        QuotaSnapshot(keyID: deepseekTrendKeyID, provider: .deepseek, credentialName: "DEEPSEEK_API_KEY", recordedAt: trendNow.addingTimeInterval(-3 * 60 * 60), outcome: .success, remaining: 850, limit: nil, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "CNY 8.50 available", httpStatus: 200),
        QuotaSnapshot(keyID: deepseekTrendKeyID, provider: .deepseek, credentialName: "DEEPSEEK_API_KEY", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 1250, limit: nil, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "CNY 12.50 available", httpStatus: 200)
    ],
    now: trendNow,
    language: .english
)
require(deepseekRecoveredActivity.kind == .recovered, "DeepSeek balance increases should be classified as recovery instead of consumption")
require(deepseekRecoveredActivity.deltaText == nil, "DeepSeek balance recovery should not expose a spent delta")
let wechatTrendKeyID = UUID(uuidString: "15151515-1515-1515-1515-151515151515")!
let wechatTrendKey = APIKey(
    id: wechatTrendKeyID,
    name: "WECHAT_API_KEY",
    key: "wechat-trend",
    provider: .wxmp,
    remaining: 15780,
    limit: nil
)
let wechatActivity = QuotaActivitySummary.activitySummary(
    for: wechatTrendKey,
    snapshots: [
        QuotaSnapshot(keyID: wechatTrendKeyID, provider: .wxmp, credentialName: "WECHAT_API_KEY", recordedAt: trendNow.addingTimeInterval(-3 * 60 * 60), outcome: .success, remaining: 16180, limit: nil, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "CNY 161.80 available", httpStatus: 200),
        QuotaSnapshot(keyID: wechatTrendKeyID, provider: .wxmp, credentialName: "WECHAT_API_KEY", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 15780, limit: nil, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "CNY 157.80 available", httpStatus: 200)
    ],
    now: trendNow,
    language: .simplifiedChinese
)
require(wechatActivity.kind == .moneyBalance, "WeChat Search activity should use the money-balance activity path")
require(wechatActivity.currentText == "¥157.80", "WeChat Search activity should use compact localized money for the current balance")
require(wechatActivity.deltaText == "-¥4.00", "WeChat Search activity should avoid English CNY text in Chinese dynamic changes")
require(!wechatActivity.deltaText!.contains("CNY"), "WeChat Search activity should not leak English currency text in Chinese UI")
let codexTrendKeyID = UUID(uuidString: "12121212-1212-1212-1212-121212121212")!
let codexTrendKey = APIKey(
    id: codexTrendKeyID,
    name: "CODEX_SUBSCRIPTION_SESSION",
    key: "codex-session",
    provider: .codexSubscription,
    remaining: 3900,
    limit: 10000,
    quotaText: .quotaWindows([
        QuotaWindowText(name: "5h", percentText: "39%"),
        QuotaWindowText(name: "week", percentText: "73%")
    ])
)
let codexWindowSparklineSamples = QuotaSparklineSample.samples(
    for: codexTrendKey,
    snapshots: [
        QuotaSnapshot(keyID: codexTrendKeyID, provider: .codexSubscription, credentialName: "CODEX_SUBSCRIPTION_SESSION", recordedAt: trendNow.addingTimeInterval(-3 * 60 * 60), outcome: .success, remaining: 9000, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "5h 60% · week 91%", httpStatus: 200, quotaWindows: [
            QuotaWindowSnapshot(name: "5h", remainingPercent: 60),
            QuotaWindowSnapshot(name: "week", remainingPercent: 91)
        ]),
        QuotaSnapshot(keyID: codexTrendKeyID, provider: .codexSubscription, credentialName: "CODEX_SUBSCRIPTION_SESSION", recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), outcome: .success, remaining: 8500, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "5h 50% · week 85%", httpStatus: 200, quotaWindows: [
            QuotaWindowSnapshot(name: "5h", remainingPercent: 50),
            QuotaWindowSnapshot(name: "week", remainingPercent: 85)
        ]),
        QuotaSnapshot(keyID: codexTrendKeyID, provider: .codexSubscription, credentialName: "CODEX_SUBSCRIPTION_SESSION", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 7300, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "5h 39% · week 73%", httpStatus: 200, quotaWindows: [
            QuotaWindowSnapshot(name: "5h", remainingPercent: 39),
            QuotaWindowSnapshot(name: "week", remainingPercent: 73)
        ])
    ],
    now: trendNow
)
require(codexWindowSparklineSamples.map { $0.value } == [0.91, 0.85, 0.73], "Codex quota sparklines should draw the largest available quota window, which is the weekly subscription window")
require(codexWindowSparklineSamples.allSatisfy { $0.windowName == "week" }, "Codex quota sparkline samples should preserve the represented weekly window for UI labeling")
let codexWindowActivity = QuotaActivitySummary.activitySummary(
    for: codexTrendKey,
    snapshots: [
        QuotaSnapshot(keyID: codexTrendKeyID, provider: .codexSubscription, credentialName: "CODEX_SUBSCRIPTION_SESSION", recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), outcome: .success, remaining: 9100, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "5h 60% · week 91%", httpStatus: 200, quotaWindows: [
            QuotaWindowSnapshot(name: "5h", remainingPercent: 60),
            QuotaWindowSnapshot(name: "week", remainingPercent: 91)
        ]),
        QuotaSnapshot(keyID: codexTrendKeyID, provider: .codexSubscription, credentialName: "CODEX_SUBSCRIPTION_SESSION", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 8500, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "5h 50% · week 85%", httpStatus: 200, quotaWindows: [
            QuotaWindowSnapshot(name: "5h", remainingPercent: 50),
            QuotaWindowSnapshot(name: "week", remainingPercent: 85)
        ])
    ],
    now: trendNow,
    language: .english
)
require(codexWindowActivity.kind == .windowedQuota, "Quota activity should classify subscription quota-window changes separately")
require(codexWindowActivity.currentText == "85%", "Quota activity should show the selected quota window's current remaining percentage")
require(codexWindowActivity.deltaText == "-6pt", "Quota activity should show remaining percentage-point deltas as compact pt changes")
let codexResetAwareSparklineSamples = QuotaSparklineSample.samples(
    for: codexTrendKey,
    snapshots: [
        QuotaSnapshot(keyID: codexTrendKeyID, provider: .codexSubscription, credentialName: "CODEX_SUBSCRIPTION_SESSION", recordedAt: trendNow.addingTimeInterval(-3 * 60 * 60), outcome: .success, remaining: 9000, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "5h 60% · week 91%", httpStatus: 200, quotaWindows: [
            QuotaWindowSnapshot(name: "5h", remainingPercent: 60, resetAt: trendNow.addingTimeInterval(5 * 60 * 60)),
            QuotaWindowSnapshot(name: "week", remainingPercent: 91, resetAt: trendNow.addingTimeInterval(24 * 60 * 60))
        ]),
        QuotaSnapshot(keyID: codexTrendKeyID, provider: .codexSubscription, credentialName: "CODEX_SUBSCRIPTION_SESSION", recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), outcome: .success, remaining: 8500, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "5h 50% · week 85%", httpStatus: 200, quotaWindows: [
            QuotaWindowSnapshot(name: "5h", remainingPercent: 50, resetAt: trendNow.addingTimeInterval(5 * 60 * 60)),
            QuotaWindowSnapshot(name: "week", remainingPercent: 85, resetAt: trendNow.addingTimeInterval(24 * 60 * 60))
        ]),
        QuotaSnapshot(keyID: codexTrendKeyID, provider: .codexSubscription, credentialName: "CODEX_SUBSCRIPTION_SESSION", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 9900, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "5h 99% · week 99%", httpStatus: 200, quotaWindows: [
            QuotaWindowSnapshot(name: "5h", remainingPercent: 99, resetAt: trendNow.addingTimeInterval(10 * 60 * 60)),
            QuotaWindowSnapshot(name: "week", remainingPercent: 99, resetAt: trendNow.addingTimeInterval(8 * 24 * 60 * 60))
        ])
    ],
    now: trendNow
)
require(codexResetAwareSparklineSamples.map { $0.value } == [0.99], "Quota sparkline samples should cut reset-crossing quota history and keep only the current reset segment")
require(codexResetAwareSparklineSamples.map { $0.resetAt } == [
    trendNow.addingTimeInterval(8 * 24 * 60 * 60)
], "Quota sparkline samples should not connect pre-reset and post-reset quota windows")
let codexRecoveryActivity = QuotaActivitySummary.activitySummary(
    for: codexTrendKey,
    snapshots: [
        QuotaSnapshot(keyID: codexTrendKeyID, provider: .codexSubscription, credentialName: "CODEX_SUBSCRIPTION_SESSION", recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), outcome: .success, remaining: 8500, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "5h 50% · week 85%", httpStatus: 200, quotaWindows: [
            QuotaWindowSnapshot(name: "week", remainingPercent: 85, resetAt: trendNow.addingTimeInterval(24 * 60 * 60))
        ]),
        QuotaSnapshot(keyID: codexTrendKeyID, provider: .codexSubscription, credentialName: "CODEX_SUBSCRIPTION_SESSION", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 9900, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "5h 99% · week 99%", httpStatus: 200, quotaWindows: [
            QuotaWindowSnapshot(name: "week", remainingPercent: 99, resetAt: trendNow.addingTimeInterval(8 * 24 * 60 * 60))
        ])
    ],
    now: trendNow,
    language: .english
)
require(codexRecoveryActivity.kind == .recovered, "Quota activity should classify reset-window increases as recovery instead of consumption")
require(codexRecoveryActivity.deltaText == nil, "Quota activity should not expose a consumed delta for recovered quota")
let codexResetLowerActivity = QuotaActivitySummary.activitySummary(
    for: codexTrendKey,
    snapshots: [
        QuotaSnapshot(keyID: codexTrendKeyID, provider: .codexSubscription, credentialName: "CODEX_SUBSCRIPTION_SESSION", recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), outcome: .success, remaining: 9100, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "week 91%", httpStatus: 200, quotaWindows: [
            QuotaWindowSnapshot(name: "week", remainingPercent: 91, resetAt: trendNow.addingTimeInterval(24 * 60 * 60))
        ]),
        QuotaSnapshot(keyID: codexTrendKeyID, provider: .codexSubscription, credentialName: "CODEX_SUBSCRIPTION_SESSION", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 8000, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "week 80%", httpStatus: 200, quotaWindows: [
            QuotaWindowSnapshot(name: "week", remainingPercent: 80, resetAt: trendNow.addingTimeInterval(8 * 24 * 60 * 60))
        ])
    ],
    now: trendNow,
    language: .english
)
require(codexResetLowerActivity.kind == .recovered, "Codex reset should cut the old weekly segment even when the first post-reset sample is already below the old-period remaining percentage")
require(codexResetLowerActivity.deltaText == nil, "Codex reset should not report consumption across different weekly reset windows")
let codexProviderScopedActivity = QuotaActivitySummary.activitySummary(
    for: codexTrendKey,
    snapshots: [
        QuotaSnapshot(keyID: codexTrendKeyID, provider: .codexSubscription, credentialName: "CODEX_SUBSCRIPTION_SESSION", recordedAt: trendNow.addingTimeInterval(-3 * 60 * 60), outcome: .success, remaining: 9100, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "week 91%", httpStatus: 200, quotaWindows: [
            QuotaWindowSnapshot(name: "week", remainingPercent: 91)
        ]),
        QuotaSnapshot(keyID: codexTrendKeyID, provider: .codexSubscription, credentialName: "CODEX_SUBSCRIPTION_SESSION", recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), outcome: .success, remaining: 8500, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "week 85%", httpStatus: 200, quotaWindows: [
            QuotaWindowSnapshot(name: "week", remainingPercent: 85)
        ]),
        QuotaSnapshot(keyID: codexTrendKeyID, provider: .xfyunCodingPlan, credentialName: "XFYUN_CODING_PLAN_COOKIE", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 2000, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "week 20%", httpStatus: 200, quotaWindows: [
            QuotaWindowSnapshot(name: "week", remainingPercent: 20)
        ])
    ],
    now: trendNow,
    language: .english
)
require(codexProviderScopedActivity.deltaText == "-6pt", "Quota activity should group snapshots by account and provider before comparing a quota window")
let xfyunTrendKeyID = UUID(uuidString: "13131313-1313-1313-1313-131313131313")!
let xfyunTrendKey = APIKey(
    id: xfyunTrendKeyID,
    name: "XFYUN_CODING_PLAN_COOKIE",
    key: "xfyun-session",
    provider: .xfyunCodingPlan,
    remaining: 2960,
    limit: 10000,
    quotaText: .quotaWindows([
        QuotaWindowText(name: "5h", percentText: "31%"),
        QuotaWindowText(name: "week", percentText: "30%"),
        QuotaWindowText(name: "month", percentText: "46%")
    ])
)
let xfyunWindowSparklineSamples = QuotaSparklineSample.samples(
    for: xfyunTrendKey,
    snapshots: [
        QuotaSnapshot(keyID: xfyunTrendKeyID, provider: .xfyunCodingPlan, credentialName: "XFYUN_CODING_PLAN_COOKIE", recordedAt: trendNow.addingTimeInterval(-3 * 60 * 60), outcome: .success, remaining: 2960, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "5h 38% · week 29.6% · month 45.7%", httpStatus: 200, quotaWindows: [
            QuotaWindowSnapshot(name: "5h", remainingPercent: 38),
            QuotaWindowSnapshot(name: "week", remainingPercent: 29.6),
            QuotaWindowSnapshot(name: "month", remainingPercent: 45.7)
        ]),
        QuotaSnapshot(keyID: xfyunTrendKeyID, provider: .xfyunCodingPlan, credentialName: "XFYUN_CODING_PLAN_COOKIE", recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), outcome: .success, remaining: 2920, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "5h 29.2% · week 29.9% · month 45.9%", httpStatus: 200, quotaWindows: [
            QuotaWindowSnapshot(name: "5h", remainingPercent: 29.2),
            QuotaWindowSnapshot(name: "week", remainingPercent: 29.9),
            QuotaWindowSnapshot(name: "month", remainingPercent: 45.9)
        ]),
        QuotaSnapshot(keyID: xfyunTrendKeyID, provider: .xfyunCodingPlan, credentialName: "XFYUN_CODING_PLAN_COOKIE", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 3020, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "5h 31.3% · week 30.2% · month 46.1%", httpStatus: 200, quotaWindows: [
            QuotaWindowSnapshot(name: "5h", remainingPercent: 31.3),
            QuotaWindowSnapshot(name: "week", remainingPercent: 30.2),
            QuotaWindowSnapshot(name: "month", remainingPercent: 46.1)
        ])
    ],
    now: trendNow
)
let expectedXfyunWindowSparklineValues = [0.457, 0.459, 0.461]
require(zip(xfyunWindowSparklineSamples.map { $0.value }, expectedXfyunWindowSparklineValues).allSatisfy { abs($0 - $1) < 0.0001 }, "XFYun quota sparklines should draw the largest available quota window, which is the monthly/package-period window")
require(xfyunWindowSparklineSamples.allSatisfy { $0.windowName == "month" }, "XFYun quota sparkline samples should preserve the represented monthly/package-period window for UI labeling")
let xfyunFallbackActivity = QuotaActivitySummary.activitySummary(
    for: xfyunTrendKey,
    snapshots: [
        QuotaSnapshot(keyID: xfyunTrendKeyID, provider: .xfyunCodingPlan, credentialName: "XFYUN_CODING_PLAN_COOKIE", recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), outcome: .success, remaining: 6200, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "5h 58% · week 62% · month 47.6%", httpStatus: 200, quotaWindows: [
            QuotaWindowSnapshot(name: "5h", remainingPercent: 58),
            QuotaWindowSnapshot(name: "week", remainingPercent: 62),
            QuotaWindowSnapshot(name: "month", remainingPercent: 47.6)
        ]),
        QuotaSnapshot(keyID: xfyunTrendKeyID, provider: .xfyunCodingPlan, credentialName: "XFYUN_CODING_PLAN_COOKIE", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 5800, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "5h 50% · week 58% · month 47.6%", httpStatus: 200, quotaWindows: [
            QuotaWindowSnapshot(name: "5h", remainingPercent: 50),
            QuotaWindowSnapshot(name: "week", remainingPercent: 58),
            QuotaWindowSnapshot(name: "month", remainingPercent: 47.6)
        ])
    ],
    now: trendNow,
    language: .english
)
require(xfyunFallbackActivity.shouldRender, "Windowed quota activity should fall back when the largest stable window hides meaningful remaining-quota change")
require(xfyunFallbackActivity.periodName == "week", "Windowed quota activity should choose the largest changed window after the largest period is stable")
require(xfyunFallbackActivity.currentText == "58%", "Windowed quota activity fallback should still show current remaining percentage")
require(xfyunFallbackActivity.deltaText == "-4pt", "Windowed quota activity fallback should show remaining percentage-point loss")
let xfyunResetLowerActivity = QuotaActivitySummary.activitySummary(
    for: xfyunTrendKey,
    snapshots: [
        QuotaSnapshot(keyID: xfyunTrendKeyID, provider: .xfyunCodingPlan, credentialName: "XFYUN_CODING_PLAN_COOKIE", recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), outcome: .success, remaining: 9800, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "month 98%", httpStatus: 200, quotaWindows: [
            QuotaWindowSnapshot(name: "month", remainingPercent: 98, resetAt: trendNow.addingTimeInterval(24 * 60 * 60))
        ]),
        QuotaSnapshot(keyID: xfyunTrendKeyID, provider: .xfyunCodingPlan, credentialName: "XFYUN_CODING_PLAN_COOKIE", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 9000, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "month 90%", httpStatus: 200, quotaWindows: [
            QuotaWindowSnapshot(name: "month", remainingPercent: 90, resetAt: trendNow.addingTimeInterval(31 * 24 * 60 * 60))
        ])
    ],
    now: trendNow,
    language: .english
)
require(xfyunResetLowerActivity.kind == .recovered, "XFYun monthly reset should cut the old package-period segment even when the first new-period sample is lower than the old period")
require(xfyunResetLowerActivity.deltaText == nil, "XFYun monthly reset should not report package-period consumption across reset windows")
let recentTavilyID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
let recentBraveID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
let recentSerperID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
let recentDeepSeekBalanceID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
let recentXFYunWindowID = UUID(uuidString: "99999999-1111-2222-3333-999999999999")!
let recentCodexResetID = UUID(uuidString: "99999999-2222-3333-4444-999999999999")!
let recentStats = [
    ProviderStats(provider: .tavily, keys: [APIKey(id: recentTavilyID, name: "TAVILY_ACTIVE", key: "tvly-active", provider: .tavily, remaining: 600, limit: 1000)]),
    ProviderStats(provider: .brave, keys: [APIKey(id: recentBraveID, name: "BRAVE_ACTIVE", key: "brave-active", provider: .brave, remaining: 850, limit: 1000)]),
    ProviderStats(provider: .serper, keys: [APIKey(id: recentSerperID, name: "SERPER_FALLBACK", key: "serper-active", provider: .serper, remaining: 1000, limit: 1000, usageCount: 100, lastUsed: trendNow)]),
    ProviderStats(provider: .deepseek, keys: [APIKey(id: recentDeepSeekBalanceID, name: "DEEPSEEK_BALANCE", key: "sk-deepseek", provider: .deepseek, remaining: 1750)]),
    ProviderStats(provider: .xfyunCodingPlan, keys: [APIKey(id: recentXFYunWindowID, name: "XFYUN_RECENT_WINDOW", key: "xfyun-cookie", provider: .xfyunCodingPlan, remaining: 4760, limit: 10000, quotaText: .quotaWindows([
        QuotaWindowText(name: "5h", percentText: "50%"),
        QuotaWindowText(name: "week", percentText: "50%"),
        QuotaWindowText(name: "month", percentText: "47.6%")
    ]))]),
    ProviderStats(provider: .codexSubscription, keys: [APIKey(id: recentCodexResetID, name: "CODEX_RESET_WINDOW", key: "codex-session", provider: .codexSubscription, remaining: 8000, limit: 10000, quotaText: .quotaWindows([
        QuotaWindowText(name: "week", percentText: "80%")
    ]))])
]
let recentUsageSnapshots = [
    QuotaSnapshot(keyID: recentTavilyID, provider: .tavily, credentialName: "TAVILY_ACTIVE", recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), outcome: .success, remaining: 900, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200),
    QuotaSnapshot(keyID: recentTavilyID, provider: .tavily, credentialName: "TAVILY_ACTIVE", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 600, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200),
    QuotaSnapshot(keyID: recentBraveID, provider: .brave, credentialName: "BRAVE_ACTIVE", recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), outcome: .success, remaining: 900, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200),
    QuotaSnapshot(keyID: recentBraveID, provider: .brave, credentialName: "BRAVE_ACTIVE", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 850, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200),
    QuotaSnapshot(keyID: recentDeepSeekBalanceID, provider: .deepseek, credentialName: "DEEPSEEK_BALANCE", recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), outcome: .success, remaining: 2000, limit: nil, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "¥20.00", httpStatus: 200),
    QuotaSnapshot(keyID: recentDeepSeekBalanceID, provider: .deepseek, credentialName: "DEEPSEEK_BALANCE", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 1750, limit: nil, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "¥17.50", httpStatus: 200),
    QuotaSnapshot(keyID: recentXFYunWindowID, provider: .xfyunCodingPlan, credentialName: "XFYUN_RECENT_WINDOW", recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), outcome: .success, remaining: 4760, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "5h 62% · week 62% · month 47.6%", httpStatus: 200, quotaWindows: [
        QuotaWindowSnapshot(name: "5h", remainingPercent: 62),
        QuotaWindowSnapshot(name: "week", remainingPercent: 62),
        QuotaWindowSnapshot(name: "month", remainingPercent: 47.6)
    ]),
    QuotaSnapshot(keyID: recentXFYunWindowID, provider: .xfyunCodingPlan, credentialName: "XFYUN_RECENT_WINDOW", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 4760, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "5h 50% · week 50% · month 47.6%", httpStatus: 200, quotaWindows: [
        QuotaWindowSnapshot(name: "5h", remainingPercent: 50),
        QuotaWindowSnapshot(name: "week", remainingPercent: 50),
        QuotaWindowSnapshot(name: "month", remainingPercent: 47.6)
    ]),
    QuotaSnapshot(keyID: recentCodexResetID, provider: .codexSubscription, credentialName: "CODEX_RESET_WINDOW", recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), outcome: .success, remaining: 9100, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "week 91%", httpStatus: 200, quotaWindows: [
        QuotaWindowSnapshot(name: "week", remainingPercent: 91, resetAt: trendNow.addingTimeInterval(24 * 60 * 60))
    ]),
    QuotaSnapshot(keyID: recentCodexResetID, provider: .codexSubscription, credentialName: "CODEX_RESET_WINDOW", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 8000, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "week 80%", httpStatus: 200, quotaWindows: [
        QuotaWindowSnapshot(name: "week", remainingPercent: 80, resetAt: trendNow.addingTimeInterval(8 * 24 * 60 * 60))
    ])
]
let recentUsageItems = MenuQuotaItem.recentProviderUsageItems(from: recentStats, snapshots: recentUsageSnapshots, limit: 4, providerOrder: [.serper, .brave, .tavily, .xfyunCodingPlan, .codexSubscription, .deepseek], now: trendNow)
require(recentUsageItems.map { $0.key.name } == ["TAVILY_ACTIVE", "XFYUN_RECENT_WINDOW", "BRAVE_ACTIVE", "DEEPSEEK_BALANCE"], "Recent provider usage should use reset-aware activity summaries, include windowed providers, and exclude reset-crossing Codex windows")
let excludedRecentUsageItems = MenuQuotaItem.recentProviderUsageItems(from: recentStats, snapshots: recentUsageSnapshots, limit: 4, providerOrder: [.serper, .brave, .tavily, .xfyunCodingPlan, .codexSubscription, .deepseek], excluding: [recentTavilyID], now: trendNow)
require(excludedRecentUsageItems.map { $0.key.name } == ["XFYUN_RECENT_WINDOW", "BRAVE_ACTIVE", "DEEPSEEK_BALANCE"], "Recent provider usage should allow menu risk sections to exclude already surfaced credentials without falling back to legacy usage counts")
let lowSignalRecentID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
let meaningfulRecentID = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
let attentionFeedRecentStats = [
    ProviderStats(provider: .serpapi, keys: [APIKey(id: lowSignalRecentID, name: "SERPAPI_TINY_DROP", key: "serpapi-tiny", provider: .serpapi, remaining: 990, limit: 1000)]),
    ProviderStats(provider: .bocha, keys: [APIKey(id: meaningfulRecentID, name: "BOCHA_MEANINGFUL_DROP", key: "bocha-meaningful", provider: .bocha, remaining: 820, limit: 1000)])
]
let attentionFeedRecentSnapshots = [
    QuotaSnapshot(keyID: lowSignalRecentID, provider: .serpapi, credentialName: "SERPAPI_TINY_DROP", recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), outcome: .success, remaining: 1000, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200),
    QuotaSnapshot(keyID: lowSignalRecentID, provider: .serpapi, credentialName: "SERPAPI_TINY_DROP", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 990, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200),
    QuotaSnapshot(keyID: meaningfulRecentID, provider: .bocha, credentialName: "BOCHA_MEANINGFUL_DROP", recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), outcome: .success, remaining: 1000, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200),
    QuotaSnapshot(keyID: meaningfulRecentID, provider: .bocha, credentialName: "BOCHA_MEANINGFUL_DROP", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 820, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200)
]
let attentionFeedRecentItems = MenuQuotaItem.recentProviderUsageItems(from: attentionFeedRecentStats, snapshots: attentionFeedRecentSnapshots, limit: 3, providerOrder: [.serpapi, .bocha], now: trendNow)
require(attentionFeedRecentItems.map { $0.key.name } == ["BOCHA_MEANINGFUL_DROP"], "Menu bar recent changes should behave like an attention feed and suppress tiny low-signal quota drops")
let overflowNow = Date()
let overflowRecentAID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
let overflowRecentBID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
let overflowStats = [
    ProviderStats(provider: .tavily, keys: [APIKey(name: "TAVILY_FAILED", key: "tvly-failed", provider: .tavily, lastDiagnosticMessage: "network failed")]),
    ProviderStats(provider: .brave, keys: [APIKey(name: "BRAVE_EMPTY", key: "brave-empty", provider: .brave, remaining: 0, limit: 1000)]),
    ProviderStats(provider: .serper, keys: [APIKey(name: "SERPER_LOW", key: "serper-low", provider: .serper, remaining: 42, limit: 1000)]),
    ProviderStats(provider: .xfyunCodingPlan, keys: [APIKey(name: "XFYUN_SOON", key: "cookie-soon", provider: .xfyunCodingPlan, remaining: 6000, limit: 10000, planEndsAt: overflowNow.addingTimeInterval(5 * 24 * 60 * 60))]),
    ProviderStats(provider: .exa, keys: [APIKey(id: overflowRecentAID, name: "EXA_RECENT", key: "exa-recent", provider: .exa, remaining: 700, limit: 1000)]),
    ProviderStats(provider: .querit, keys: [APIKey(id: overflowRecentBID, name: "QUERIT_RECENT", key: "querit-recent", provider: .querit, remaining: 760, limit: 1000)])
]
let overflowSnapshots = [
    QuotaSnapshot(keyID: overflowRecentAID, provider: .exa, credentialName: "EXA_RECENT", recordedAt: overflowNow.addingTimeInterval(-2 * 60 * 60), outcome: .success, remaining: 900, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200),
    QuotaSnapshot(keyID: overflowRecentAID, provider: .exa, credentialName: "EXA_RECENT", recordedAt: overflowNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 700, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200),
    QuotaSnapshot(keyID: overflowRecentBID, provider: .querit, credentialName: "QUERIT_RECENT", recordedAt: overflowNow.addingTimeInterval(-2 * 60 * 60), outcome: .success, remaining: 900, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200),
    QuotaSnapshot(keyID: overflowRecentBID, provider: .querit, credentialName: "QUERIT_RECENT", recordedAt: overflowNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 760, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200)
]
let overflowLayout = MenuQuotaSignalLayout.make(
    from: overflowStats,
    snapshots: overflowSnapshots,
    visibleLimit: 4,
    providerOrder: [.tavily, .brave, .serper, .xfyunCodingPlan, .exa, .querit],
    now: overflowNow
)
require(overflowLayout.visibleItems.map { $0.key.name } == ["TAVILY_FAILED", "BRAVE_EMPTY", "SERPER_LOW", "XFYUN_SOON"], "Menu signal layout should spend fixed panel slots on risk first before recent activity")
require(overflowLayout.hiddenItemCount == 2, "Menu signal layout should count recent activity rows hidden by the global fixed-panel cap")
require(overflowLayout.recentUsageItems.isEmpty, "Menu signal layout should hide recent activity when higher-priority signals consume the global cap")
let groupedProviderLayout = MenuQuotaSignalLayout.make(
    from: [
        ProviderStats(provider: .xfyunCodingPlan, keys: [
            APIKey(name: "XFYUN_CODING_PLAN_COOKIE", key: "cookie-low-a", provider: .xfyunCodingPlan, remaining: 8, limit: 1000, planDisplayName: "Pro"),
            APIKey(name: "XFYUN_CODING_PLAN_COOKIE", key: "cookie-low-b", provider: .xfyunCodingPlan, remaining: 45, limit: 1000, planDisplayName: "Lite")
        ]),
        ProviderStats(provider: .tavily, keys: [
            APIKey(name: "TAVILY_LOW", key: "tvly-low", provider: .tavily, remaining: 20, limit: 1000)
        ])
    ],
    snapshots: [],
    visibleLimit: 5,
    providerOrder: [.xfyunCodingPlan, .tavily],
    now: overflowNow
)
require(groupedProviderLayout.lowQuotaItems.map { $0.key.name } == ["XFYUN_CODING_PLAN_COOKIE", "TAVILY_LOW"], "Menu signal layout should collapse multiple same-provider low-quota accounts into one provider row")
require(groupedProviderLayout.lowQuotaItems.first?.providerSignalCount == 2, "Collapsed provider rows should retain the same-provider account count for the menu label")
require(groupedProviderLayout.hiddenItemCount == 0, "Collapsed same-provider accounts should not inflate the fixed-panel hidden-item count")
require(groupedProviderLayout.lowQuotaItems.first?.statusBarAccountContextLabel == "Pro · 2 accounts", "Collapsed provider rows should append a compact account-count hint to the representative account context")
let crossSignalLayout = MenuQuotaSignalLayout.make(
    from: [
        ProviderStats(provider: .volcengineCodingPlan, keys: [
            APIKey(name: "VOLCENGINE_LOW", key: "cookie-low", provider: .volcengineCodingPlan, remaining: 50, limit: 1000),
            APIKey(name: "VOLCENGINE_EXPIRES", key: "cookie-expiring", provider: .volcengineCodingPlan, remaining: 900, limit: 1000, planEndsAt: overflowNow.addingTimeInterval(3 * 24 * 60 * 60))
        ]),
        ProviderStats(provider: .tavily, keys: [
            APIKey(name: "TAVILY_LOW", key: "tvly-cross-low", provider: .tavily, remaining: 20, limit: 1000)
        ])
    ],
    snapshots: [],
    visibleLimit: 5,
    providerOrder: [.volcengineCodingPlan, .tavily],
    now: overflowNow
)
require(crossSignalLayout.visibleItems.map { $0.provider }.filter { $0 == .volcengineCodingPlan }.count == 1, "Menu signal layout should surface each provider only once across low/expiring/attention sections")
require(crossSignalLayout.visibleItems.map { $0.key.name } == ["TAVILY_LOW", "VOLCENGINE_LOW"], "When one provider has several automatic signals, the menu should keep only its strongest provider-level row")
let watchedLayout = MenuQuotaSignalLayout.make(
    from: [
        ProviderStats(provider: .brave, keys: [APIKey(name: "BRAVE_WATCHED", key: "brave-watched", provider: .brave, remaining: 880, limit: 1000)]),
        ProviderStats(provider: .tavily, keys: [APIKey(name: "TAVILY_LOW", key: "tvly-watched-low", provider: .tavily, remaining: 20, limit: 1000)])
    ],
    snapshots: [],
    visibleLimit: 5,
    providerOrder: [.tavily, .brave],
    watchedProviders: [.brave],
    now: overflowNow
)
require(watchedLayout.watchedProviderItems.map { $0.key.name } == ["BRAVE_WATCHED"], "Menu signal layout should reserve a separate short section for user-watched providers")
require(!watchedLayout.visibleItems.map { $0.key.name }.contains("BRAVE_WATCHED"), "Watched providers should not also consume automatic signal slots")
let menuSummary = MenuQuotaSummary(keys: [
    APIKey(name: "healthy", key: "tvly-healthy", provider: .tavily, remaining: 900, limit: 1000),
    APIKey(name: "low", key: "tvly-low", provider: .tavily, remaining: 20, limit: 1000),
    APIKey(name: "failed", key: "tvly-failed", provider: .tavily, lastDiagnosticMessage: "network failed"),
    APIKey(name: "expired", key: "cookie", provider: .volcengineCodingPlan, quotaLabel: "Credential expired")
])
require(menuSummary.availableCount == 2, "MenuQuotaSummary should count usable credentials, including low but still usable ones")
require(menuSummary.lowCount == 1, "MenuQuotaSummary should count low-quota credentials separately")
require(menuSummary.failedCount == 2, "MenuQuotaSummary should count failed and expired credentials")
require(menuSummary.statusItemShortText == "2 Failed", "Status bar short text should surface failed credentials before lower-priority low-quota counts")
let lowOnlyMenuSummary = MenuQuotaSummary(keys: [
    APIKey(name: "healthy", key: "tvly-healthy", provider: .tavily, remaining: 900, limit: 1000),
    APIKey(name: "low-a", key: "tvly-low-a", provider: .tavily, remaining: 20, limit: 1000),
    APIKey(name: "low-b", key: "brave-low-b", provider: .brave, remaining: 10, limit: 1000)
])
require(lowOnlyMenuSummary.statusItemShortText == "2 Low", "Status bar short text should show low-quota counts when no failed credentials exist")
let calmMenuSummary = MenuQuotaSummary(keys: [
    APIKey(name: "healthy", key: "tvly-healthy", provider: .tavily, remaining: 900, limit: 1000)
])
require(calmMenuSummary.statusItemShortText == nil, "Status bar short text should stay hidden when there is no meaningful quota signal")
let cookieStatusLabel = APIKey(
    name: "VOLCENGINE_CODING_PLAN_COOKIE",
    key: #"{"cookie":"c=a"}"#,
    provider: .volcengineCodingPlan
).statusBarCredentialLabel
require(cookieStatusLabel == "Web login authorization", "Status bar should show the credential type for web-login providers, not masked raw JSON")
let genericWebLoginMenuLabel = APIKey(
    name: "VOLCENGINE_CODING_PLAN_COOKIE",
    key: #"{"cookie":"c=a"}"#,
    provider: .volcengineCodingPlan
).statusBarAccountContextLabel
require(genericWebLoginMenuLabel == nil, "Menu bar rows should hide generic web-login authorization when it is the only account context")
let concretePlanMenuLabel = APIKey(
    name: "VOLCENGINE_CODING_PLAN_COOKIE",
    key: #"{"cookie":"c=a"}"#,
    provider: .volcengineCodingPlan,
    planDisplayName: "Lite"
).statusBarAccountContextLabel
require(concretePlanMenuLabel == "Lite", "Menu bar rows should show concrete dashboard package names instead of generic web-login authorization")
let namedConcretePlanMenuLabel = APIKey(
    name: "Work account",
    key: #"{"cookie":"c=a"}"#,
    provider: .volcengineCodingPlan,
    note: "Team",
    planDisplayName: "Lite"
).statusBarAccountContextLabel
require(namedConcretePlanMenuLabel == "Lite · Work account · Team", "Menu bar rows should distinguish multiple accounts that share the same package")
let apiStatusLabel = APIKey(
    name: "BRAVE_API_KEY",
    key: "abcd1234wxyz",
    provider: .brave
).statusBarCredentialLabel
require(apiStatusLabel == "abcd••••wxyz", "Status bar should still show masked concrete API keys for normal providers")
require(APIKey(
    name: "BRAVE_API_KEY",
    key: "abcd1234wxyz",
    provider: .brave
).statusBarAccountContextLabel == "abcd••••wxyz", "Menu bar rows should keep masked API keys when they identify normal API-key credentials")
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

swiftc QuotaRadar/Models/AppLanguage.swift QuotaRadar/Models/APIKey.swift QuotaRadar/Models/QuotaHistory.swift QuotaRadar/Services/EnvImporter.swift QuotaRadar/Services/ClaudeSettingsImporter.swift "$TMP_DIR/main.swift" -o "$TMP_DIR/env-importer-test"
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

let kimiCurl = """
curl 'https://www.kimi.com/apiv2/kimi.gateway.membership.v2.MembershipService/GetSubscription' \
  -H 'authorization: Bearer kimi-token' \
  -H 'x-msh-device-id: device-redacted' \
  -H 'x-msh-session-id: session-redacted' \
  -H 'x-traffic-id: traffic-redacted' \
  -b 'kimi-auth=kimi-cookie-token-redacted; locale_mode=implicit' \
  --data-raw '{}'
"""
let kimi = try! CurlCredentialParser.parse(kimiCurl, provider: .kimiSubscription)
require(kimi.provider == .kimiSubscription, "Kimi cURL parse should preserve provider")
require(kimi.cookie.contains("kimi-auth=kimi-cookie-token-redacted"), "Kimi cURL parse should extract web login cookie")
require(kimi.fields["accessToken"] == "kimi-token", "Kimi cURL parse should extract the Bearer token without the prefix")
require(kimi.fields["deviceID"] == "device-redacted", "Kimi cURL parse should extract x-msh-device-id")
require(kimi.fields["sessionID"] == "session-redacted", "Kimi cURL parse should extract x-msh-session-id")
require(kimi.fields["trafficID"] == "traffic-redacted", "Kimi cURL parse should extract x-traffic-id")
require(kimi.serializedCredential.contains("\"accessToken\""), "Kimi parser should serialize Bearer token metadata as JSON")

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
require(L10n.t(.sidebarStatistics, language: .english) == "Statistics", "English sidebar metrics heading should describe statistics instead of repeating the app name")
require(L10n.t(.sidebarStatistics, language: .simplifiedChinese) == "统计", "Chinese sidebar metrics heading should describe statistics instead of repeating the app name")
require(L10n.t(.quotaActivity, language: .simplifiedChinese) == "动态", "Chinese Activity column should describe recent remaining-quota activity instead of used quota")
require(L10n.compactDeltaIndicator("-2pt") == "↓2pt", "Compact delta indicators should show remaining-quota drops with a down arrow instead of a minus sign")
require(L10n.compactDeltaIndicator("-CNY 4.00") == "↓CNY 4.00", "Compact delta indicators should preserve currency text when showing balance drops")
require(L10n.compactDeltaIndicator("+2pt") == "↑2pt", "Compact delta indicators should support quota increases with an up arrow")
require(L10n.t(.criticalTime, language: .english) == "Critical Time", "English quota overview timing column should use Critical Time")
require(L10n.t(.criticalTime, language: .simplifiedChinese) == "关键时间", "Chinese quota overview timing column should use 关键时间")
require(L10n.t(.lowQuotaProviders, language: .simplifiedChinese) == "额度紧张", "Chinese status bar low-quota section should have a clear localized label")
require(L10n.t(.expiringSoon, language: .english) == "Expiring Soon", "English status bar expiring-soon section should be localized")
require(L10n.t(.expiringSoon, language: .simplifiedChinese) == "即将到期", "Chinese status bar expiring-soon section should be localized")
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
require(L10n.t(.needsAttention, language: .english) == "Heads Up", "English menu attention title should be softened without losing alert meaning")
require(L10n.t(.watchedProviders, language: .simplifiedChinese) == "常看", "Chinese watched-provider title should be softer than attention wording")
require(L10n.t(.needsAttention, language: .simplifiedChinese) == "提醒", "Chinese menu attention title should be softer than 需要关注")
require(L10n.t(.noAttentionItems, language: .simplifiedChinese) == "暂无提醒", "Chinese no-attention empty state should be soft and compact")
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
require(L10n.quotaPeriodCompactTitle("5h", language: .simplifiedChinese) == "5h", "Sparkline five-hour period marker should stay compact in Chinese")
require(L10n.quotaPeriodCompactTitle("week", language: .simplifiedChinese) == "周", "Sparkline weekly period marker should stay compact in Chinese")
require(L10n.quotaPeriodCompactTitle("month", language: .simplifiedChinese) == "月", "Sparkline monthly period marker should stay compact in Chinese")
require(L10n.quotaPeriodCompactTitle("week", language: .english) == "wk", "Sparkline weekly period marker should stay compact in English")
require(L10n.quotaPeriodCompactTitle("balance", language: .english) == "bal", "Money-balance activity period marker should stay compact in English")
require(L10n.quotaPeriodCompactTitle("balance", language: .simplifiedChinese) == "余额", "Money-balance activity period marker should be localized in Chinese")
require(L10n.t(.httpNotRequested, language: .english) == "Not requested", "English diagnostics should distinguish skipped HTTP checks")
require(L10n.t(.httpNotRequested, language: .simplifiedChinese) == "未请求", "Chinese diagnostics should distinguish skipped HTTP checks")
require(QuotaDataSource.responseHeader.displayName(language: .simplifiedChinese) == "响应头", "Chinese quota data source labels should not leak English Header wording")
require(QuotaDataSource.responseHeader.displayName(language: .english) == "Response Header", "English quota data source labels should remain readable")
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

echo "== Threshold notification behavior =="
cat >"$TMP_DIR/main.swift" <<'SWIFT'
import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(1)
    }
}

AppLanguageStore.shared.language = .english

let lowKey = APIKey(
    name: "TAVILY_API_KEY",
    key: "tvly-low",
    provider: .tavily,
    remaining: 19,
    limit: 100
)
let exhaustedKey = APIKey(
    name: "SERPER_API_KEY",
    key: "serper-zero",
    provider: .serper,
    remaining: 0,
    limit: 100
)
let expiredDashboardKey = APIKey(
    name: "KIMI_AUTH",
    key: "kimi-auth=expired",
    provider: .kimiSubscription,
    quotaText: .localized(.credentialExpired),
    quotaLabel: "Credential expired"
)
let firstFailureKey = APIKey(
    name: "DEEPSEEK_API_KEY",
    key: "deepseek-fail",
    provider: .deepseek,
    lastHTTPStatus: 502,
    lastDiagnosticMessage: "Bad gateway",
    consecutiveFailureCount: 1
)
let repeatedFailureKey = APIKey(
    name: "BRAVE_API_KEY",
    key: "brave-fail",
    provider: .brave,
    lastHTTPStatus: 503,
    lastDiagnosticMessage: "Service unavailable",
    consecutiveFailureCount: 3
)
let copyOnlyKey = APIKey(
    name: "KIMI_API_KEY",
    key: "sk-kimi",
    provider: .kimiSubscription,
    remaining: 0,
    limit: 100
)
let disabledLowKey = APIKey(
    name: "DISABLED",
    key: "disabled",
    provider: .tavily,
    isActive: false,
    remaining: 1,
    limit: 100
)

let events = QuotaThresholdNotificationService.events(for: [
    lowKey,
    exhaustedKey,
    expiredDashboardKey,
    firstFailureKey,
    repeatedFailureKey,
    copyOnlyKey,
    disabledLowKey,
])
require(events.map(\.kind) == [.credentialExpired, .quotaExhausted, .repeatedFailures, .lowQuota], "Threshold notification events should use severity order and skip inactive, copy-only, and first-failure credentials")
require(events.contains { $0.kind == .lowQuota && $0.keyID == lowKey.id }, "Quota below 20% should trigger a low-quota notification")
require(events.contains { $0.kind == .quotaExhausted && $0.keyID == exhaustedKey.id }, "Zero remaining quota should trigger an exhausted notification instead of a low-quota duplicate")
require(events.contains { $0.kind == .credentialExpired && $0.keyID == expiredDashboardKey.id }, "Expired web-login authorizations should trigger credential-expired notifications")
require(events.contains { $0.kind == .repeatedFailures && $0.keyID == repeatedFailureKey.id }, "Three consecutive provider failures should trigger repeated-failure notifications")
require(!events.contains { $0.keyID == firstFailureKey.id }, "One-off failures should not trigger repeated-failure notifications")
require(events.allSatisfy { !$0.title.isEmpty && !$0.body.isEmpty }, "Threshold notification events should carry localizable title and body text")

let defaults = UserDefaults(suiteName: "QuotaRadarThresholdNotificationTests.\(UUID().uuidString)")!
let store = QuotaThresholdNotificationStore(defaults: defaults)
let freshEvents = store.freshEvents(from: events)
require(freshEvents.count == events.count, "Threshold notification store should allow first-time active events")
require(store.freshEvents(from: events).count == events.count, "Threshold notification store should not suppress events before the notification is actually delivered")
store.markDelivered(freshEvents, retainingActive: events)
require(store.freshEvents(from: events).isEmpty, "Threshold notification store should suppress duplicate active threshold notifications")
store.clearResolvedEvents(retainingActive: [])
require(store.freshEvents(from: []).isEmpty, "Threshold notification store should clear resolved events when no thresholds are active")
require(store.freshEvents(from: [events[0]]) == [events[0]], "Threshold notification store should allow a threshold notification again after the condition recovered")

SWIFT

swiftc QuotaRadar/Models/AppLanguage.swift QuotaRadar/Models/APIKey.swift QuotaRadar/Services/QuotaNotificationService.swift "$TMP_DIR/main.swift" -o "$TMP_DIR/threshold-notification-test"
"$TMP_DIR/threshold-notification-test"

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
let partialVolcengineCredential = DashboardCapturedCredential(
    provider: .volcengineCodingPlan,
    cookieHeader: "AccountID=account-redacted; csrfToken=c"
)
let completeVolcengineCredential = DashboardCapturedCredential(
    provider: .volcengineCodingPlan,
    cookieHeader: "AccountID=account-redacted; csrfToken=c; digest=digest-token"
)
require(!DashboardCredentialCapturePolicy.isCredentialReady(
    partialVolcengineCredential,
    requiredNames: volcengineRequiredCookies
), "Partial Volcengine login cookies should not be treated as a completed dashboard credential")
require(DashboardCredentialCapturePolicy.shouldRetryCapture(
    partialVolcengineCredential,
    requiredNames: volcengineRequiredCookies,
    completedRetryCount: 0,
    retryDelays: DashboardCredentialCapturePolicy.manualRetryDelays
), "Manual Volcengine save should retry after an early partial cookie read instead of caching the first failed result")
require(!DashboardCredentialCapturePolicy.shouldRetryCapture(
    partialVolcengineCredential,
    requiredNames: volcengineRequiredCookies,
    completedRetryCount: DashboardCredentialCapturePolicy.manualRetryDelays.count,
    retryDelays: DashboardCredentialCapturePolicy.manualRetryDelays
), "Manual Volcengine save should surface the missing-cookie message only after the retry window is exhausted")
require(DashboardCredentialCapturePolicy.isCredentialReady(
    completeVolcengineCredential,
    requiredNames: volcengineRequiredCookies
), "Complete Volcengine login cookies should be ready for dashboard credential validation")
require(!DashboardCredentialCapturePolicy.shouldRetryCapture(
    completeVolcengineCredential,
    requiredNames: volcengineRequiredCookies,
    completedRetryCount: 0,
    retryDelays: DashboardCredentialCapturePolicy.manualRetryDelays
), "Complete Volcengine login cookies should save immediately without waiting for more retries")
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
require(Provider.kimiSubscription.supportsDashboardReauthentication, "Kimi subscription should support web-login authorization capture")
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
require(DashboardReauthConfig(provider: .kimiSubscription)?.cookieDomains == ["kimi.com", "www.kimi.com"], "Kimi subscription should capture kimi.com web-login authorization")
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
require(DashboardCookieBuilder.containsRequiredCookie(
    inCookieHeader: "kimi-auth=kimi-session",
    requiredNames: Provider.kimiSubscription.dashboardAuthenticationCookieNames
), "Kimi subscription should accept the observed kimi-auth login cookie")
let kimiCapturedFromStorage = DashboardCapturedCredential(
    provider: .kimiSubscription,
    cookieHeader: "locale_mode=implicit",
    webStorageFields: ["kimi-auth": "kimi-storage-token", "x-msh-device-id": "device-redacted"]
)
require(kimiCapturedFromStorage.fields["accessToken"] == "kimi-storage-token", "Kimi reauthentication should normalize the web storage kimi-auth token into accessToken")
require(kimiCapturedFromStorage.fields["deviceID"] == "device-redacted", "Kimi reauthentication should preserve x-msh device metadata from web storage")
require(DashboardCookieBuilder.missingRequiredCredentialNames(
    cookieHeader: kimiCapturedFromStorage.cookieHeader,
    fields: kimiCapturedFromStorage.fields,
    requiredNames: Provider.kimiSubscription.dashboardAuthenticationCookieNames
).isEmpty, "Kimi reauthentication should accept accessToken captured from web storage when the auth cookie is not exposed")
require(kimiCapturedFromStorage.reauthenticatedSecret(existingSecret: nil).contains("\"accessToken\""), "Kimi reauthentication should save storage-derived token metadata as JSON instead of a raw preference cookie")

for provider in [Provider.querit, .xfyunCodingPlan, .volcengineCodingPlan, .opencodeGo, .claudeSubscription, .codexSubscription, .kimiSubscription] {
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
    planDisplayName: "Team Pro",
    consecutiveFailureCount: 2,
    quotaText: LocalizedTextDescriptor.localized(.monthlyCreditsFormat, "850", "1000"),
    quotaLabel: "850 / 1000 monthly credits"
)
store.save([structuredKey])
let structuredMetadata = store.load()
require(structuredMetadata[0].quotaText?.key == .monthlyCreditsFormat, "APIKeyStore should persist structured quota descriptors")
require(structuredMetadata[0].planDisplayName == "Team Pro", "APIKeyStore should persist refreshed concrete plan/package display names")
require(structuredMetadata[0].consecutiveFailureCount == 2, "APIKeyStore should persist consecutive quota-check failure counts for threshold notifications")
AppLanguageStore.shared.language = .simplifiedChinese
require(structuredMetadata[0].quotaDisplayText == "850 / 1000 月度积分", "APIKey quota display should prefer structured descriptors over persisted English labels")
AppLanguageStore.shared.language = .english

let legacyDashboardNoteID = UUID()
let legacyDashboardNoteJSON = """
[{
  "id":"\(legacyDashboardNoteID.uuidString)",
  "name":"ALIYUN_CODING_PLAN_COOKIE",
  "provider":"Aliyun Coding Plan",
  "isActive":true,
  "note":"网页登录授权",
  "usageCount":0
}]
"""
let legacyDashboardNoteDefaults = UserDefaults(suiteName: "QuotaRadarLegacyDashboardNoteTests.\(UUID().uuidString)")!
legacyDashboardNoteDefaults.set(Data(legacyDashboardNoteJSON.utf8), forKey: "apiKeyMetadata")
let legacyDashboardNoteStore = APIKeyStore(defaults: legacyDashboardNoteDefaults, secretStore: secretStore)
let loadedLegacyDashboardNotes = legacyDashboardNoteStore.load()
require(loadedLegacyDashboardNotes.count == 1, "APIKeyStore should load legacy dashboard authorization metadata")
require(loadedLegacyDashboardNotes[0].note == nil, "APIKeyStore should strip generated web-login notes from legacy metadata")
require(loadedLegacyDashboardNotes[0].displayNote == nil, "English credential rows should not show stale Chinese web-login notes")
require(loadedLegacyDashboardNotes[0].managementDisplayName == "Quota monitoring authorization", "Legacy dashboard authorization names should render in the current English language")
require(loadedLegacyDashboardNotes[0].managementCredentialValueText == "Login authorization saved", "Legacy dashboard authorization values should render in the current English language")
require(loadedLegacyDashboardNotes[0].accountDisplayTitle == "Aliyun Coding Plan", "Legacy dashboard authorization account rows should show provider plan fallback as the primary title")
require(loadedLegacyDashboardNotes[0].accountDisplaySubtitle == "Web login authorization", "Legacy dashboard authorization account rows should use credential identity instead of saved-login state")

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

func localTestDate(_ value: String) -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    if let date = formatter.date(from: value) {
        return date
    } else {
        fail("Could not parse local test date: \(value)")
        return Date(timeIntervalSince1970: 0)
    }
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
let braveUsageLimitedResponse = try! QuotaParsers.parseBraveHTTPResponse(
    statusCode: 402,
    limitHeader: nil,
    remainingHeader: nil,
    resetHeader: nil,
    policyHeader: nil,
    knownRemaining: 1000,
    knownLimit: 1000
)
require(braveUsageLimitedResponse.httpStatus == 402, "Brave HTTP 402 responses without quota headers should preserve the provider HTTP status")
require(braveUsageLimitedResponse.remaining == 0, "Brave HTTP 402 responses should update the key to an exhausted state")
require(braveUsageLimitedResponse.limit == 1000, "Brave HTTP 402 responses should preserve the last known monthly quota limit")
require(braveUsageLimitedResponse.quotaText?.key == .usageLimitExceeded, "Brave HTTP 402 responses should use a structured usage-limit descriptor")
do {
    _ = try QuotaParsers.parseBraveHTTPResponse(
        statusCode: 422,
        limitHeader: nil,
        remainingHeader: nil,
        resetHeader: nil,
        policyHeader: nil,
        knownRemaining: nil,
        knownLimit: nil
    )
    fail("Brave HTTP 422 invalid subscription tokens should throw an invalid-key error")
} catch let error as QuotaError {
    require(error.httpStatus == 422, "Brave HTTP 422 invalid subscription tokens should preserve the provider HTTP status")
    require(error.errorDescription == "Invalid API key", "Brave HTTP 422 invalid subscription tokens should render as an invalid API key")
} catch {
    fail("Brave HTTP 422 invalid subscription tokens should throw QuotaError")
}

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
let exaUsageDisplayKey = APIKey(name: "EXA_ADMIN", key: "exa", provider: .exa, remaining: exaUsage.remaining, limit: exaUsage.limit, quotaText: exaUsage.quotaText, quotaLabel: exaUsage.quotaLabel)
require(exaUsageDisplayKey.quotaDisplayText == "可用 · 额度未知", "Exa parser usage evidence should not leak used-cost wording into the main quota UI")
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
{"code":0,"data":{"rows":[{"name":"高效版","validFrom":"2026-05-28 17:48:58","expiresAt":"2026-06-28 17:48:58","codingPlanUsageDTO":{"packageLeft":853441,"packageLimit":900000,"packageUsage":46559,"rp5hLimit":6000,"rp5hUsage":3622,"rpwLimit":450000,"rpwUsage":17454}}]},"succeed":true}
""".utf8))
require(xfyun.limit == 10000, "XFYun coding-plan percentage limit should be 10000 basis points")
require(xfyun.remaining == 3963, "XFYun should use the tightest remaining coding-plan window after converting official used counts")
require(xfyun.quotaLabel == "5h 39.6% · week 96.1% · month 94.8%", "XFYun should display remaining percentages computed from official used counts")
AppLanguageStore.shared.language = .simplifiedChinese
require(xfyun.quotaText?.render() == "5 小时 39.6% · 周 96.1% · 月 94.8%", "Structured quota-window descriptors should render period labels in the current UI language")
require(xfyun.quotaText?.quotaWindows.first(where: { $0.name == "5h" })?.detailValueText == "2378 / 6000", "XFYun quota-window details should use the same remaining/total semantics as other providers")
AppLanguageStore.shared.language = .english
require(xfyun.quotaText?.quotaWindows.first(where: { $0.name == "5h" })?.remainingText == "2378 / 6000", "XFYun should display five-hour remaining and maximum request counts")
require(xfyun.quotaText?.quotaWindows.first(where: { $0.name == "week" })?.remainingText == "432546 / 450000", "XFYun should display weekly remaining and maximum request counts")
require(xfyun.quotaText?.quotaWindows.first(where: { $0.name == "month" })?.remainingText == "853441 / 900000", "XFYun should display monthly remaining and maximum request counts")
require(xfyun.quotaText?.quotaWindows.first(where: { $0.name == "5h" })?.detailValueText == "2378 / 6000", "XFYun quota-window details should not use provider-specific used-count labels")
let xfyunDisplayKey = APIKey(name: "XFYUN_CODING_PLAN_COOKIE", key: "cookie", provider: .xfyunCodingPlan, quotaText: xfyun.quotaText, quotaLabel: xfyun.quotaLabel)
require(xfyunDisplayKey.quotaWindowDetails.count == 3, "XFYun should render cycle detail rows with remaining/maximum counts even when reset times are not exposed")
let xfyunWindowed = try! QuotaParsers.parseXFYunCodingPlanList(Data("""
{"code":0,"data":{"rows":[{"name":"高效版-包月","validFrom":"2026-05-28 17:48:58","expiresAt":"2026-06-28 17:48:58","codingPlanUsageDTO":{"packageLeft":853441,"packageLimit":900000,"packageUsage":46559,"rp5hLimit":6000,"rp5hUsage":3622,"rpwLimit":450000,"rpwUsage":17454}}]},"succeed":true}
""".utf8), now: localTestDate("2026-06-16 18:15:00"))
require(xfyunWindowed.quotaText?.quotaWindows.first(where: { $0.name == "5h" })?.resetAt == localTestDate("2026-06-16 21:48:58"), "XFYun should infer the next five-hour reset boundary from validFrom")
require(xfyunWindowed.quotaText?.quotaWindows.first(where: { $0.name == "week" })?.resetAt == localTestDate("2026-06-18 17:48:58"), "XFYun should infer the next weekly reset boundary from validFrom")
require(xfyunWindowed.quotaText?.quotaWindows.first(where: { $0.name == "month" })?.resetAt == localTestDate("2026-06-28 17:48:58"), "XFYun should use package expiry as the total-package reset boundary")
require(xfyunWindowed.resetAt == localTestDate("2026-06-16 21:48:58"), "XFYun should expose the tightest inferred quota window reset")
require(xfyun.planEndsAt != nil, "XFYun should expose the package expiry as the plan end date")
require(xfyun.planDisplayName == "高效版", "XFYun should expose the concrete coding-plan package name when present")

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

let volcSubscription = try! QuotaParsers.parseVolcengineCodingPlanSubscription(Data("""
{"ResponseMetadata":{"Action":"ListSubscribeTrade"},"Result":{"InfoList":[{"ResourceType":"CodingPlan","ResourceName":"","BizInfo":"lite","PayType":"pre","Status":"Running","InstanceID":"tsi-redacted","StartTime":"2026-06-01T05:18:09Z","EndTime":"2026-07-01T15:59:59Z","EnableAutoRenew":false,"Quantity":1,"Period":"monthly"}]}}
""".utf8))
require(volcSubscription.planDisplayName == "Lite", "Volcengine Coding Plan should expose BizInfo lite as the concrete package name")
require(volcSubscription.planEndsAt != nil, "Volcengine Coding Plan should parse ListSubscribeTrade EndTime as the plan end date")

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

do {
    _ = try QuotaParsers.parseAliyunCodingPlanStatus(Data("""
{"code":"200","data":{"DataV2":{"ret":["SUCCESS::接口调用成功"],"data":{"data":{"codingPlanInstanceInfos":[],"userId":"redacted"},"success":true,"failed":false}},"success":true,"httpStatus":200,"api":"zeldaEasy.broadscope-bailian.codingPlan.queryCodingPlanInstanceInfoV2","errorMsg":""},"successResponse":true}
""".utf8))
    fail("Aliyun Coding Plan should report noSubscription when queryCodingPlanInstanceInfoV2 returns an empty subscription list")
} catch QuotaError.noSubscription {
} catch {
    fail("Aliyun Coding Plan empty subscription list should throw noSubscription, got \(error)")
}

let aliyunCodingPlan = try! QuotaParsers.parseAliyunCodingPlanStatus(Data("""
{"code":"200","data":{"DataV2":{"ret":["SUCCESS::接口调用成功"],"data":{"data":{"codingPlanInstanceInfos":[{"instanceName":"Coding Plan Pro","instanceType":"pro","status":"VALID","instanceStartTime":1772064682000,"instanceEndTime":1782489600000,"remainingDays":17,"codingPlanQuotaInfo":{"per5HourUsedQuota":43,"per5HourTotalQuota":6000,"per5HourQuotaNextRefreshTime":1780980997000,"perWeekUsedQuota":165,"perWeekTotalQuota":45000,"perWeekQuotaNextRefreshTime":1781452800000,"perBillMonthUsedQuota":2913,"perBillMonthTotalQuota":90000,"perBillMonthQuotaNextRefreshTime":1782489600000}}],"userId":"redacted"},"success":true,"failed":false}},"success":true,"httpStatus":200,"api":"zeldaEasy.broadscope-bailian.codingPlan.queryCodingPlanInstanceInfoV2","errorMsg":""},"successResponse":true}
""".utf8))
require(aliyunCodingPlan.remaining == 9676, "Aliyun Coding Plan should use the tightest request-count window from queryCodingPlanInstanceInfoV2")
require(aliyunCodingPlan.limit == 10000, "Aliyun Coding Plan usage-window percentage limit should be 10000 basis points")
require(aliyunCodingPlan.quotaLabel == "5h 99.3% · week 99.6% · month 96.8%", "Aliyun Coding Plan should display queryCodingPlanInstanceInfoV2 usage windows")
let aliyunDisplayKey = APIKey(name: "ALIYUN_CODING_PLAN_COOKIE", key: "cookie", provider: .aliyunCodingPlan, quotaText: aliyunCodingPlan.quotaText, quotaLabel: aliyunCodingPlan.quotaLabel)
require(aliyunDisplayKey.quotaWindowDetails.count == 3, "Aliyun Coding Plan should render cycle detail rows when queryCodingPlanInstanceInfoV2 exposes window counts")
require(aliyunCodingPlan.quotaText?.quotaWindows.first(where: { $0.name == "5h" })?.remainingText == "5957 / 6000", "Aliyun Coding Plan should preserve five-hour remaining and maximum request counts")
require(aliyunCodingPlan.quotaText?.quotaWindows.first(where: { $0.name == "week" })?.remainingText == "44835 / 45000", "Aliyun Coding Plan should preserve weekly remaining and maximum request counts")
require(aliyunCodingPlan.quotaText?.quotaWindows.first(where: { $0.name == "month" })?.remainingText == "87087 / 90000", "Aliyun Coding Plan should preserve monthly remaining and maximum request counts")
require(aliyunCodingPlan.quotaText?.quotaWindows.first(where: { $0.name == "5h" })?.resetAt != nil, "Aliyun Coding Plan should preserve the five-hour quota reset timestamp")
require(aliyunCodingPlan.quotaText?.quotaWindows.first(where: { $0.name == "week" })?.resetAt != nil, "Aliyun Coding Plan should preserve the weekly quota reset timestamp")
require(aliyunCodingPlan.quotaText?.quotaWindows.first(where: { $0.name == "month" })?.resetAt != nil, "Aliyun Coding Plan should preserve the monthly quota reset timestamp")
require(aliyunCodingPlan.resetAt != nil, "Aliyun Coding Plan should expose the tightest quota window reset timestamp")
require(aliyunCodingPlan.planEndsAt != nil, "Aliyun Coding Plan should expose the subscription end time when present")
require(aliyunCodingPlan.planDisplayName == "Coding Plan Pro", "Aliyun Coding Plan should expose the concrete instance name when present")
let aliyunProviderStat = ProviderStats(provider: .aliyunCodingPlan, keys: [aliyunDisplayKey])
require(aliyunProviderStat.totalLimitDisplayText == "month 96.8%", "Aliyun Coding Plan provider total should display the monthly percentage window")
require(aliyunProviderStat.totalRemainingDisplayText == "month 96.8%", "Aliyun Coding Plan provider remaining should display the tightest quota cycle")

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
require(aliyunCodingPlanWithUsage.planDisplayName == "Lite", "Aliyun Coding Plan should expose the plan instance type when a friendlier name is not present")

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
require(tencentCodingPlan.planDisplayName == "Lite", "Tencent Cloud Coding Plan should expose the concrete package name when present")

do {
    _ = try QuotaParsers.parseTencentCloudCodingPlanDescribePkg(Data("""
{"code":0,"data":{"code":0,"cgwerrorCode":0,"data":{"Response":{"RequestId":"request-redacted","TotalCount":0}}},"mccode":0}
""".utf8))
    fail("Tencent Cloud Coding Plan should report noSubscription when DescribePkg returns zero packages without PkgList")
} catch QuotaError.noSubscription {
} catch {
    fail("Tencent Cloud Coding Plan zero-package response should throw noSubscription, got \(error)")
}

do {
    _ = try QuotaParsers.parseTencentCloudCodingPlanDescribePkg(Data("""
{"code":7,"mccode":7,"msg":"登录态验证失败，请重新登录(UIN_OR_SKEY_MISSING)","uiMsg":"登录态验证失败，请重新登录"}
""".utf8))
    fail("Tencent Cloud Coding Plan login-state failures should be reported as unauthorized")
} catch QuotaError.unauthorized {
} catch {
    fail("Tencent Cloud Coding Plan login-state failure should throw unauthorized, got \(error)")
}

let claudeOrganizationID = try! QuotaParsers.parseClaudeOrganizationID(Data("""
[{"uuid":"org-redacted","name":"Personal","active":true}]
""".utf8))
require(claudeOrganizationID == "org-redacted", "Claude subscription should discover an organization uuid from claude.ai organizations")
let claudeOrganizationContext = try! QuotaParsers.parseClaudeOrganizationContext(Data("""
[{"uuid":"org-redacted","name":"Personal","active":true,"billing_type":"stripe_subscription","rate_limit_tier":"default_claude_ai","capabilities":["chat","claude_pro"]}]
""".utf8))
require(claudeOrganizationContext.id == "org-redacted", "Claude subscription organization context should preserve the active organization uuid")
require(claudeOrganizationContext.planDisplayName == "Pro", "Claude subscription organization context should expose claude_pro as the concrete plan name")

let claudeUsage = try! QuotaParsers.parseClaudeSubscriptionUsage(Data("""
{"five_hour":{"utilization":24.5,"resets_at":"2026-06-09T10:00:00Z"},"seven_day":{"utilization":"70","resets_at":"2026-06-15T00:00:00Z"},"seven_day_opus":{"utilization":95,"resets_at":"2026-06-15T00:00:00Z"}}
""".utf8))
require(claudeUsage.remaining == 3000, "Claude subscription should use the tightest remaining percentage from 5h and weekly windows")
require(claudeUsage.limit == 10000, "Claude subscription percentage limit should use basis points")
require(claudeUsage.quotaLabel == "5h 75.5% · week 30%", "Claude subscription should display five-hour and weekly remaining percentages")
require(claudeUsage.quotaText?.kind == .quotaWindows, "Claude subscription should carry structured quota-window descriptors")
require(claudeUsage.quotaText?.quotaWindows.count == 2, "Claude subscription should keep the stable five-hour and weekly windows in compact UI")
require(claudeUsage.quotaText?.quotaWindows.first(where: { $0.name == "5h" })?.resetAt != nil, "Claude five-hour quota window should preserve reset timestamp")
require(claudeUsage.quotaText?.quotaWindows.first(where: { $0.name == "week" })?.resetAt != nil, "Claude weekly quota window should preserve reset timestamp")
require(claudeUsage.resetAt != nil, "Claude subscription should expose the tightest quota window reset timestamp")
require(claudeUsage.planEndsAt == nil, "Claude usage endpoint should not invent subscription end time")
let claudeSubscriptionDisplayKey = APIKey(name: "CLAUDE_SUBSCRIPTION_COOKIE", key: "cookie", provider: .claudeSubscription, quotaText: claudeUsage.quotaText, quotaLabel: claudeUsage.quotaLabel)
let claudeSubscriptionStat = ProviderStats(provider: .claudeSubscription, keys: [claudeSubscriptionDisplayKey])
require(claudeSubscriptionStat.totalRemainingDisplayText == "week 30%", "Claude subscription provider remaining should display the tightest percentage window")

let claudeSubscriptionDetails = try! QuotaParsers.parseClaudeSubscriptionDetails(Data("""
{"subscription_type":"pro","next_charge_date":"2026-07-08T16:42:25Z"}
""".utf8))
require(claudeSubscriptionDetails.planEndsAt != nil, "Claude subscription details should parse next_charge_date as the plan-cycle end date")
require(claudeSubscriptionDetails.planDisplayName == "Pro", "Claude subscription details should expose subscription_type as a concrete plan name")
let claudeDetailsFromChargeAt = try! QuotaParsers.parseClaudeSubscriptionDetails(Data("""
{"status":"active","billing_interval":"monthly","next_charge_date":"2026-07-09","next_charge_at":"2026-07-09T09:57:27Z"}
""".utf8))
require(claudeDetailsFromChargeAt.planEndsAt != nil, "Claude subscription details should parse next_charge_at when next_charge_date is date-only")
let claudePlanFormatter = ISO8601DateFormatter()
let expectedClaudePlanEnd = claudePlanFormatter.date(from: "2026-07-09T09:57:27Z")!
require(abs(claudeDetailsFromChargeAt.planEndsAt!.timeIntervalSince1970 - expectedClaudePlanEnd.timeIntervalSince1970) < 1, "Claude subscription details should prefer next_charge_at over date-only next_charge_date")

let codexUsage = try! QuotaParsers.parseCodexWhamUsage(Data("""
{"plan_type":"pro","rate_limit":{"allowed":true,"limit_reached":false,"primary_window":{"used_percent":0,"limit_window_seconds":18000,"reset_after_seconds":18000,"reset_at":1780924878},"secondary_window":{"used_percent":70,"limit_window_seconds":604800,"reset_after_seconds":233270,"reset_at":1781140147}},"additional_rate_limits":[{"limit_name":"GPT-5.3-Codex-Spark","rate_limit":{"allowed":true,"limit_reached":false,"primary_window":{"used_percent":0,"limit_window_seconds":18000,"reset_after_seconds":18000,"reset_at":1780924878},"secondary_window":{"used_percent":0,"limit_window_seconds":604800,"reset_after_seconds":604800,"reset_at":1781511678}}}],"credits":{"has_credits":false,"unlimited":false,"balance":"0"}}
""".utf8))
require(codexUsage.remaining == 3000, "Codex subscription usage should use the tightest remaining quota window")
require(codexUsage.limit == 10000, "Codex subscription usage should use percentage basis points")
require(codexUsage.quotaLabel == "5h 100% · week 30%", "Codex subscription usage should display five-hour and weekly windows")
require(codexUsage.quotaText?.kind == .quotaWindows, "Codex subscription usage should carry structured quota-window descriptors")
require(codexUsage.resetAt != nil, "Codex subscription usage should expose the tightest quota window reset date")
require(codexUsage.planEndsAt == nil, "Codex wham usage does not expose subscription end date")
require(codexUsage.planDisplayName == "Pro", "Codex wham usage should expose plan_type as a concrete plan name")
let codexLifecycle = try! QuotaParsers.parseCodexSubscriptionLifecycle(Data("""
{"active_start":"2026-06-08T16:42:25Z","active_until":"2026-07-08T16:42:25Z","billing_period":"monthly","plan_type":"pro","will_renew":true}
""".utf8))
require(codexLifecycle.planEndsAt != nil, "Codex subscription lifecycle should parse active_until as the plan end date")
require(codexLifecycle.planDisplayName == "Pro", "Codex subscription lifecycle should expose plan_type as a concrete plan name")

let kimiUsage = try! QuotaParsers.parseKimiSubscriptionUsage(
    subscriptionData: Data("""
{"subscription":{"goods":{"title":"Kimi Plus"},"next_billing_time":"2026-07-01T00:00:00Z"},"balances":[{"feature":"CHAT","type":"SUBSCRIPTION","unit":"CREDIT","amount":"10000","amount_left":"3000","amount_used_ratio":0.7,"expire_time":"2026-07-01T00:00:00Z"}],"subscribed":true}
""".utf8),
    usageData: Data("""
{"usages":[{"scope":"FEATURE_CODING","detail":{"limit":100,"remaining":30,"used":70,"resetTime":"2026-06-15T00:00:00Z"},"limits":[{"window":{"duration":300,"timeUnit":"TIME_UNIT_MINUTE"},"detail":{"limit":100,"remaining":75,"used":25,"resetTime":"2026-06-09T10:00:00Z"}}]}],"totalQuota":100}
""".utf8)
)
require(kimiUsage.remaining == 3000, "Kimi subscription should use the tightest remaining percentage across returned windows")
require(kimiUsage.limit == 10000, "Kimi subscription percentage limit should use basis points")
require(kimiUsage.quotaLabel == "5h 75% · week 30% · month 30%", "Kimi subscription should display confirmed five-hour, weekly, and subscription-balance windows")
require(kimiUsage.quotaText?.quotaWindows.first(where: { $0.name == "5h" })?.resetAt != nil, "Kimi five-hour quota window should preserve reset timestamp")
require(kimiUsage.quotaText?.quotaWindows.first(where: { $0.name == "week" })?.resetAt != nil, "Kimi weekly quota window should preserve reset timestamp")
require(kimiUsage.quotaText?.quotaWindows.first(where: { $0.name == "month" })?.remainingText == "3000 / 10000", "Kimi subscription balance should preserve remaining and total credits")
require(kimiUsage.planEndsAt != nil, "Kimi subscription should expose next billing or balance expiry as plan end")
require(kimiUsage.planDisplayName == "Kimi Plus", "Kimi subscription should expose the concrete membership goods title when present")

let kimiOAuthUsageShape = try! QuotaParsers.parseKimiSubscriptionUsage(
    subscriptionData: Data("""
{"subscription":{"goods":{"title":"Kimi Code"}},"balances":[],"subscribed":true}
""".utf8),
    usageData: Data("""
{"usage":{"name":"Weekly limit","limit":100,"remaining":78,"resetAt":"2026-06-10T08:54:48.859647Z"},"limits":[{"window":{"duration":300,"timeUnit":"MINUTE"},"detail":{"limit":100,"remaining":96,"resetAt":"2026-06-09T13:54:48.859647Z"}}]}
""".utf8)
)
require(kimiOAuthUsageShape.quotaLabel == "5h 96% · week 78%", "Kimi parser should support the official Kimi Code OAuth /coding/v1/usages shape")
require(kimiOAuthUsageShape.quotaText?.quotaWindows.first(where: { $0.name == "5h" })?.remainingText == "96 / 100", "Kimi OAuth usage parser should preserve five-hour remaining counts")
require(kimiOAuthUsageShape.quotaText?.quotaWindows.first(where: { $0.name == "week" })?.remainingText == "78 / 100", "Kimi OAuth usage parser should preserve weekly remaining counts")

let kimiUnknownQuota = try! QuotaParsers.parseKimiSubscriptionUsage(
    subscriptionData: Data("""
{"subscription":{"goods":{"title":"Kimi Free"}},"balances":[],"subscribed":true}
""".utf8),
    usageData: nil
)
require(kimiUnknownQuota.quotaText?.render(language: .english) == "Usable · quota unknown", "Kimi subscription should not invent quota when membership data lacks usage windows")
require(kimiUnknownQuota.planEndsAt == nil, "Kimi unknown-quota fallback should not invent a plan end date")
require(kimiUnknownQuota.planDisplayName == "Kimi Free", "Kimi subscription should preserve the membership name even when quota details are not exposed")

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

swiftc QuotaRadar/Models/AppLanguage.swift QuotaRadar/Models/APIKey.swift QuotaRadar/Models/AppAppearance.swift QuotaRadar/Services/QuotaService.swift "$TMP_DIR/main.swift" -o "$TMP_DIR/quota-parser-test"
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

mkdir -p "build/visual-qa"
{
  echo "status=passed"
  echo "command=bash Tests/run_behavior_tests.sh"
  echo "bundle=build/Quota Radar.app"
  date -u +"completed_at=%Y-%m-%dT%H:%M:%SZ"
} > "build/visual-qa/behavior-tests-status.txt"

echo "All behavior tests passed"
