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
assert_match '0\.4\.5' \
  "QuotaRadar/Info.plist" \
  "Quota Radar 0.4.5 should be recorded in Info.plist"
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
assert_match 'QUOTARADAR_LIVE_ACCEPTANCE=1' \
  "scripts/live_acceptance.sh" \
  "Live acceptance should require an explicit environment opt-in before hitting provider endpoints"
assert_match '--live' \
  "scripts/live_acceptance.sh" \
  "Live acceptance should require a visible --live flag before hitting provider endpoints"
assert_match 'live-acceptance-src' \
  "scripts/live_acceptance.sh" \
  "Live acceptance should compile from a temporary source tree so the app target does not need to become a library"
assert_match 'QuotaRadarApp.swift' \
  "scripts/live_acceptance.sh" \
  "Live acceptance should exclude the SwiftUI @main app entry from its temporary CLI target"
assert_match 'No secrets, cookies, tokens, or raw provider responses are printed' \
  "scripts/live_acceptance.sh" \
  "Live acceptance should document its no-secret output boundary"
assert_match 'LiveAcceptanceRow' \
  "scripts/live_acceptance_main.swift" \
  "Live acceptance should use a structured sanitized row model"
assert_match 'Provider.visibleCases.filter \{ \$0.supportsDashboardReauthentication \}' \
  "scripts/live_acceptance_main.swift" \
  "Live acceptance should cover every visible dashboard-login provider"
assert_match 'store.loadSecrets' \
  "scripts/live_acceptance_main.swift" \
  "Live acceptance should hydrate local secrets only inside the acceptance runner"
assert_match 'com\.gaorongvc\.quotaradar' \
  "scripts/live_acceptance_main.swift" \
  "Live acceptance should read the app UserDefaults domain instead of the temporary CLI domain"
assert_no_match 'print\(.*key|print\(.*cookie|print\(.*token|print\(.*secret' \
  "scripts/live_acceptance_main.swift" \
  "Live acceptance output must not print raw keys, cookies, tokens, or secrets"
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
assert_match 'case longcat = "LongCat"' \
  "QuotaRadar/Models/APIKey.swift" \
  "LongCat should be modeled as one provider with multiple billing meters"
assert_no_match 'case longcat = "LongCat Token Pack"' \
  "QuotaRadar/Models/APIKey.swift" \
  "LongCat Token Pack should not be a separate top-level provider"
assert_no_match 'case longcat = "LongCat Pay-as-you-go"' \
  "QuotaRadar/Models/APIKey.swift" \
  "LongCat Pay-as-you-go should not be a separate top-level provider"
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
assert_match 'enum ProviderCalibrationStatus' \
  "QuotaRadar/Models/APIKey.swift" \
  "Provider calibration status should be modeled next to provider capabilities"
assert_match 'struct ProviderTrustCalibration' \
  "QuotaRadar/Models/APIKey.swift" \
  "Provider trust calibration should have a typed model instead of living only in docs"
assert_match 'var trustCalibration: ProviderTrustCalibration' \
  "QuotaRadar/Models/APIKey.swift" \
  "Each provider should expose trust calibration metadata from the same source as capability semantics"
test -s "docs/provider-calibration.md" || fail "English provider calibration backlog should exist"
test -s "docs/provider-calibration.zh-Hans.md" || fail "Chinese provider calibration backlog should exist"
assert_match 'Observed Before Fixture' \
  "docs/provider-calibration.md" \
  "Provider calibration backlog should require real observed fields before adding parser fixtures"
assert_match 'Long-Tail Calibration Queue' \
  "docs/provider-calibration.md" \
  "Provider calibration backlog should track long-tail provider packages separately from the main provider matrix"
assert_match 'Claude Subscription OAuth usage/limits' \
  "docs/provider-calibration.md" \
  "Provider calibration backlog should include the Claude OAuth usage follow-up"
assert_match 'OpenAI prepaid credits' \
  "docs/provider-calibration.md" \
  "Provider calibration backlog should keep prepaid credits separate from Codex subscription quota"
assert_match '先观察再加 fixture' \
  "docs/provider-calibration.zh-Hans.md" \
  "Chinese provider calibration backlog should require observed fields before parser fixtures"
assert_match '长尾校准队列' \
  "docs/provider-calibration.zh-Hans.md" \
  "Chinese provider calibration backlog should track long-tail provider packages separately from the main provider matrix"
assert_match 'calibrationStatus' \
  "scripts/live_acceptance_main.swift" \
  "Live acceptance output should include sanitized provider calibration status"
assert_match 'lastVerifiedAt' \
  "scripts/live_acceptance_main.swift" \
  "Live acceptance output should include sanitized last-verified timestamps"
assert_match 'calibrationEvidence' \
  "scripts/live_acceptance_main.swift" \
  "Live acceptance output should include sanitized calibration evidence summaries"
assert_match 'fallbackBehavior' \
  "scripts/live_acceptance_main.swift" \
  "Live acceptance output should include sanitized fallback behavior for schema drift"
assert_match 'mktemp -d "\$\{ROOT_DIR\}/build/live-acceptance-src' \
  "scripts/live_acceptance.sh" \
  "Live acceptance should use a per-run temporary source directory so concurrent QA commands do not race"
assert_match 'trap cleanup EXIT' \
  "scripts/live_acceptance.sh" \
  "Live acceptance should clean up its per-run temporary source directory"
assert_match 'QuotaMonitor\.refreshCandidateKeys' \
  "scripts/live_acceptance_main.swift" \
  "Live acceptance should reuse quota monitor refresh candidates so providers with shared dashboard authorization are accepted"
assert_match 'targetProviders: Set\(\[provider\]\)' \
  "scripts/live_acceptance_main.swift" \
  "Live acceptance should derive shared dashboard authorization candidates per provider"
assert_match '2026-06-23 13:06 CST' \
  "QuotaRadar/Models/APIKey.swift" \
  "Provider trust calibration metadata should record the latest redacted live acceptance timestamp"
assert_match '2026-06-23 13:06 CST' \
  "docs/providers.md" \
  "English provider docs should record the latest redacted live acceptance timestamp"
assert_match '2026-06-23 13:06 CST' \
  "docs/providers.zh-Hans.md" \
  "Chinese provider docs should record the latest redacted live acceptance timestamp"
assert_match 'Live acceptance snapshot: 2026-06-23 13:06 CST' \
  "docs/provider-calibration.md" \
  "Provider calibration backlog should retain the latest sanitized live acceptance snapshot summary"
assert_match 'Aliyun Coding Plan.*Missing saved account' \
  "docs/provider-calibration.md" \
  "Provider calibration backlog should distinguish missing saved accounts from failed calibration"
assert_match 'Tencent Cloud Coding Plan.*Missing saved account' \
  "docs/provider-calibration.md" \
  "Provider calibration backlog should distinguish missing Tencent saved accounts from failed calibration"
assert_match 'OpenAI prepaid credits.*Docs reviewed 2026-06-23' \
  "docs/provider-calibration.md" \
  "Provider calibration backlog should record the OpenAI prepaid docs-only observation"
assert_match 'GET/organization/costs' \
  "docs/provider-calibration.md" \
  "OpenAI prepaid calibration should distinguish organization costs from prepaid balance"
assert_match 'No public prepaid credit balance API confirmed' \
  "docs/provider-calibration.md" \
  "OpenAI prepaid calibration should not claim an endpoint before it is observed"
assert_match 'Claude Subscription OAuth usage/limits.*Docs reviewed 2026-06-23' \
  "docs/provider-calibration.md" \
  "Claude OAuth calibration should record docs-only observation separately from live endpoint proof"
assert_match 'org:admin' \
  "docs/provider-calibration.md" \
  "Claude OAuth calibration should distinguish admin API tokens from personal subscription OAuth"
assert_match 'Kimi WebBridge.*live browser observation' \
  "docs/provider-calibration.md" \
  "Provider calibration backlog should record that browser-level Claude observation ran"
assert_match 'Claude web usage/prepaid credits.*Live browser observation 2026-06-23' \
  "docs/provider-calibration.md" \
  "Provider calibration backlog should record the Claude prepaid browser observation"
assert_match 'prepaid/credits' \
  "docs/provider-calibration.md" \
  "Claude prepaid calibration should record the observed web endpoint without account identifiers"
assert_match 'OpenAI Platform login missing' \
  "docs/provider-calibration.md" \
  "OpenAI prepaid calibration should record why live browser observation could not verify a prepaid endpoint"
assert_match 'OpenAI prepaid credits.*文档观察 2026-06-23' \
  "docs/provider-calibration.zh-Hans.md" \
  "Chinese provider calibration backlog should record the OpenAI prepaid docs-only observation"
assert_match '未确认公开 prepaid credit balance API' \
  "docs/provider-calibration.zh-Hans.md" \
  "Chinese OpenAI prepaid calibration should not claim an endpoint before it is observed"
assert_match 'Claude Subscription OAuth usage/limits.*文档观察 2026-06-23' \
  "docs/provider-calibration.zh-Hans.md" \
  "Chinese Claude OAuth calibration should record docs-only observation separately from live endpoint proof"
assert_match 'Claude web usage/prepaid credits.*浏览器实测 2026-06-23' \
  "docs/provider-calibration.zh-Hans.md" \
  "Chinese provider calibration backlog should record the Claude prepaid browser observation"
assert_match 'prepaid/credits' \
  "docs/provider-calibration.zh-Hans.md" \
  "Chinese Claude prepaid calibration should record the observed web endpoint without account identifiers"
assert_match 'live acceptance 快照：2026-06-23 13:06 CST' \
  "docs/provider-calibration.zh-Hans.md" \
  "Chinese provider calibration backlog should retain the latest sanitized live acceptance snapshot summary"
assert_match 'Aliyun Coding Plan.*缺少已保存账号' \
  "docs/provider-calibration.zh-Hans.md" \
  "Chinese provider calibration backlog should distinguish missing saved accounts from failed calibration"
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
assert_match 'Last Verified' \
  "docs/providers.md" \
  "Provider docs should show when each calibration status was last verified"
assert_match 'Fallback Behavior' \
  "docs/providers.md" \
  "Provider docs should document fallback behavior when quota fields drift"
assert_match '最近验证' \
  "docs/providers.zh-Hans.md" \
  "Chinese provider docs should show when each calibration status was last verified"
assert_match '降级口径' \
  "docs/providers.zh-Hans.md" \
  "Chinese provider docs should document fallback behavior when quota fields drift"
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
assert_match '#if QUOTARADAR_DISABLE_GITHUB_UPDATER' \
  "QuotaRadar/Services/GitHubReleaseUpdater.swift" \
  "Updater should compile to a no-op implementation for white-label builds"
assert_match 'static let isUpdateCheckingAvailable = false' \
  "QuotaRadar/Services/GitHubReleaseUpdater.swift" \
  "White-label updater should tell the UI update checks are unavailable"
assert_match '#else' \
  "QuotaRadar/Services/GitHubReleaseUpdater.swift" \
  "Updater should keep the normal GitHub Release implementation outside the white-label branch"
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
test -s "docs/release-qa.md" || fail "English release QA checklist should exist"
test -s "docs/release-qa.zh-Hans.md" || fail "Chinese release QA checklist should exist"
assert_match 'Standard Updater Build' \
  "docs/release-qa.md" \
  "Release QA should split the standard updater build into its own checklist"
assert_match 'White-Label No-Updater Build' \
  "docs/release-qa.md" \
  "Release QA should split the white-label no-updater build into its own checklist"
assert_match 'build/QuotaRadar\.dmg' \
  "docs/release-qa.md" \
  "Standard release QA should verify the standard DMG artifact"
assert_match 'build/QuotaRadar-WhiteLabel\.dmg' \
  "docs/release-qa.md" \
  "White-label release QA should verify the white-label DMG artifact"
assert_match 'https://api\.github\.com/repos/Asklear/QuotaRadar/releases/latest' \
  "docs/release-qa.md" \
  "Standard release QA should explicitly scan for the expected GitHub Release API URL"
assert_match 'https://github\.com/Asklear/QuotaRadar/releases/latest' \
  "docs/release-qa.md" \
  "Standard release QA should explicitly scan for the expected GitHub latest-release fallback URL"
assert_match 'QUOTARADAR_DISABLE_GITHUB_UPDATER' \
  "docs/release-qa.md" \
  "White-label release QA should verify the updater compile flag boundary"
assert_match 'strings .*QuotaRadar-WhiteLabel\.dmg' \
  "docs/release-qa.md" \
  "White-label release QA should include a DMG string scan for leaked updater URLs"
assert_match 'secret|cookie|token|authorization' \
  "docs/release-qa.md" \
  "Release QA should include explicit secret scanning terms"
assert_match 'Tests/run_visual_qa\.sh' \
  "docs/release-qa.md" \
  "Release QA should include visual screenshot QA"
assert_match 'codesign --verify' \
  "docs/release-qa.md" \
  "Release QA should verify app code signatures"
assert_match 'hdiutil verify' \
  "docs/release-qa.md" \
  "Release QA should verify DMG integrity"
assert_match '标准 Updater 构建' \
  "docs/release-qa.zh-Hans.md" \
  "Chinese release QA should split the standard updater build into its own checklist"
assert_match '白牌 No-Updater 构建' \
  "docs/release-qa.zh-Hans.md" \
  "Chinese release QA should split the white-label no-updater build into its own checklist"
assert_match 'build/QuotaRadar\.dmg' \
  "docs/release-qa.zh-Hans.md" \
  "Chinese standard release QA should verify the standard DMG artifact"
assert_match 'build/QuotaRadar-WhiteLabel\.dmg' \
  "docs/release-qa.zh-Hans.md" \
  "Chinese white-label release QA should verify the white-label DMG artifact"
assert_match 'GitHub Release URL 扫描' \
  "docs/release-qa.zh-Hans.md" \
  "Chinese release QA should explicitly name the GitHub Release URL scan"
assert_match 'secret|cookie|token|authorization' \
  "docs/release-qa.zh-Hans.md" \
  "Chinese release QA should include explicit secret scanning terms"
assert_match 'Tests/run_visual_qa\.sh' \
  "docs/release-qa.zh-Hans.md" \
  "Chinese release QA should include visual screenshot QA"
assert_match 'hdiutil verify' \
  "docs/release-qa.zh-Hans.md" \
  "Chinese release QA should verify DMG integrity"
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
assert_match 'GitHubReleaseUpdater\.isUpdateCheckingAvailable' \
  "QuotaRadar/AppDelegate.swift" \
  "Launch update checks should be gated by updater availability for white-label builds"
assert_match 'Check for Updates' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Updater controls should have English localization"
assert_match '检查更新' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Updater controls should have Simplified Chinese localization"
assert_match 'L10n\.t\(\.checkForUpdates\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings should expose a localized Check for Updates action"
assert_match 'statusMessage = L10n\.t\(\.noUpdatesAvailable\)' \
  "QuotaRadar/Services/GitHubReleaseUpdater.swift" \
  "Updater should keep an up-to-date status in the lower-left footer after a successful background check finds no update"
assert_match 'SidebarUpdateFooter' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings sidebar should keep version and update status in the lower-left footer"
assert_match 'if GitHubReleaseUpdater\.isUpdateCheckingAvailable' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings should hide update-check controls for white-label builds"
assert_match '-DQUOTARADAR_DISABLE_GITHUB_UPDATER' \
  "install.sh" \
  "White-label install builds should pass the Swift flag that removes GitHub updater URLs"
assert_match '--white-label' \
  "install.sh" \
  "install.sh should expose a white-label build option"
assert_match '--white-label' \
  "scripts/package_dmg.sh" \
  "DMG packaging should expose a white-label build option"
assert_match 'QuotaRadar-WhiteLabel\.dmg' \
  "scripts/package_dmg.sh" \
  "White-label packaging should write a separate DMG name"
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
assert_no_match '\.version: ".*[0-9]+\.[0-9]+\.[0-9]+' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Version localization should be a label only and must not hard-code an app version"
assert_match 'private var versionText: String' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings sidebar footer should keep the installed version as a dedicated value"
assert_match 'private var updateStatusText: String\?' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings sidebar footer should keep update-check status separate from the installed version"
python3 - <<'PY'
from pathlib import Path
import sys

source = Path("QuotaRadar/Views/SettingsView.swift").read_text()
try:
    footer = source.split("struct SidebarUpdateFooter: View", 1)[1].split("\nstruct ", 1)[0]
except IndexError:
    print("FAIL: SidebarUpdateFooter should exist", file=sys.stderr)
    sys.exit(1)

required = {
    "Text(versionText)": "installed version should be rendered from versionText",
    "if let updateStatusText": "update status should be optional and secondary",
    "Text(updateStatusText)": "update status should render separately from the version",
    '"v\\(updater.currentVersion)"': "versionText should prefix the bundle version with v",
}

for needle, message in required.items():
    if needle not in footer:
        print(f"FAIL: Settings sidebar footer {message}", file=sys.stderr)
        sys.exit(1)

if "Text(statusText)" in footer or "private var statusText" in footer:
    print("FAIL: Settings sidebar footer should not replace the version with update status text", file=sys.stderr)
    sys.exit(1)
PY
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
if "diagnosticCategories" not in diagnostics or "Provider.categoryDisplayOrder.compactMap" not in diagnostics:
    print("FAIL: Diagnostics should group providers by shared AI Search / LLM category order", file=sys.stderr)
    sys.exit(1)
if "CredentialDiagnosticCategorySection" not in diagnostics:
    print("FAIL: Diagnostics should render collapsible AI Search / LLM category sections", file=sys.stderr)
    sys.exit(1)
if "struct CredentialDiagnosticCategorySection: View" not in source:
    print("FAIL: Diagnostics category section should exist", file=sys.stderr)
    sys.exit(1)
diagnostic_category_section = source.split("struct CredentialDiagnosticCategorySection: View", 1)[1].split("struct CredentialDiagnosticProviderSection", 1)[0]
if "CollapsibleBanner" not in diagnostic_category_section or "@State private var isExpanded = true" not in diagnostic_category_section:
    print("FAIL: Diagnostics category sections should use the shared collapsible banner behavior", file=sys.stderr)
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
assert_no_match 'recommendedActionText' \
  "QuotaRadar/Models/APIKey.swift" \
  "Credential diagnostics should not expose credential-management action entry points"
assert_no_match 'diagnosticAction' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Diagnostics should stay diagnostic-only instead of rendering action entry points"
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
assert_match 'scheduleStatusPanelForAutomationAttempt\(remainingAttempts: 12\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Visual QA status-panel automation should retry instead of relying on a single early status-item attempt"
assert_match 'capture_status_panel_bounds_with_retry' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should retry status-panel window capture so transient AppKit timing does not fail a valid UI"
assert_match 'showStatusPanelAtAutomationFallbackPosition' \
  "QuotaRadar/AppDelegate.swift" \
  "Visual QA status-panel automation should have a fallback when the status item button is not ready"
assert_match 'if isVisualQAAutomation \{' \
  "QuotaRadar/AppDelegate.swift" \
  "Visual QA status-panel automation should keep the menu popover on the main screen for reliable screenshots"
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
assert_match 'rate_limit_reset_credits' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Codex subscription usage should parse available reset-credit metadata from the wham usage response"
assert_match 'available_count' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Codex reset-credit parsing should read the available_count field"
assert_match 'https://chatgpt\.com/backend-api/wham/rate-limit-reset-credits' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Codex subscription refresh should query reset-credit detail metadata without consuming a credit"
assert_match 'https://chatgpt\.com/backend-api/wham/rate-limit-reset-credits/consume' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Codex quota reset should call the wham reset-credit consume endpoint"
assert_match 'https://chatgpt\.com/backend-api/accounts/check/v4-2023-04-27' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Codex subscription refresh should query accounts/check for concrete Pro 20x/5x plan tiers"
assert_match 'redeem_request_id' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Codex quota reset should send a unique redeem_request_id"
assert_match 'chatgpt-account-id' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Codex quota reset should scope the consume request to the selected ChatGPT account"
assert_match 'func resetCodexQuota' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should expose an account-scoped Codex quota reset action"
assert_match 'resettingCodexQuotaKeyIDs' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should track in-flight Codex reset actions by credential id"
assert_match 'codexResetCreditsRemaining' \
  "QuotaRadar/Services/QuotaService.swift" \
  "QuotaResult should carry Codex reset-credit availability"
assert_match 'codexResetCreditsRemaining' \
  "QuotaRadar/Models/APIKey.swift" \
  "APIKey should persist Codex reset-credit availability for the account row"
assert_match 'codexResetCreditsRemaining' \
  "QuotaRadar/Services/APIKeyStore.swift" \
  "APIKeyStore metadata should persist Codex reset-credit availability"
assert_match 'codexResetCreditsEarliestExpiresAt' \
  "QuotaRadar/Models/APIKey.swift" \
  "Codex reset-credit UI should persist the provider-returned earliest reset-credit expiry"
assert_match 'codexResetCreditsEarliestExpiresAt' \
  "QuotaRadar/Services/APIKeyStore.swift" \
  "APIKeyStore metadata should persist provider-returned Codex reset-credit expiry"
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
assert_match 'QUOTARADAR_OPEN_REAUTH_PROVIDER_FOR_AUTOMATION' \
  "QuotaRadar/AppDelegate.swift" \
  "Dashboard reauthentication QA should have a stable launch hook that bypasses flaky multi-window AX clicks"
assert_match 'QUOTARADAR_OPEN_REAUTH_PROVIDER_FOR_AUTOMATION' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Keys settings should present the add-credential sheet for the requested reauthentication provider during QA"
assert_match 'automaticallyOpenReauthentication' \
  "QuotaRadar/Views/SettingsView.swift" \
  "AddKeySheet should be able to open the dashboard-login authorization sheet after provider preselection"
assert_match 'capturedLoginFields' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication failures should disclose only sanitized captured field names to aid provider recalibration"
assert_match 'DashboardCookieBuilder\.credentialNames\(' \
  "QuotaRadar/Services/DashboardReauth.swift" \
  "Dashboard reauthentication diagnostics should derive captured names without printing credential values"
assert_match '/api/v1/user-current' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "LongCat dashboard reauthentication should probe the same-origin user-current endpoint when cookies are not script-readable"
assert_match 'longcatLoginStatus' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "LongCat dashboard reauthentication should carry sanitized page-login status metadata into save validation"
assert_match 'longCatLoginState' \
  "QuotaRadar/Services/DashboardReauth.swift" \
  "LongCat dashboard reauthentication should localize missing-login-state copy instead of exposing raw token and UUID field names as the primary error"
assert_match 'DashboardCredentialDisplayNames\.missingRequiredNames' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication missing-login copy should use localized display names instead of raw credential field names"
assert_match 'DashboardCredentialDisplayNames\.capturedNames' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication captured-login diagnostics should use localized display names instead of raw credential field names"
assert_no_match 'capturedNames\.joined\(separator: ", "\)' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should not directly join raw captured credential names into user-facing copy"
assert_match 'longCatLoginAuthorization' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "LongCat login authorization display name should be localized for diagnostics"
assert_match 'longCatBrowserIdentity' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "LongCat browser identity display name should be localized for diagnostics"
assert_match 'longCatAccountIdentity' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "LongCat account identity display name should be localized for diagnostics"
assert_match 'openMenuSignalForAutomationIfRequested' \
  "QuotaRadar/AppDelegate.swift" \
  "AppDelegate should evaluate the menu signal focus automation hook on launch"
assert_match 'openProviderFromStatusPopover\(item\.provider, credentialID: item\.key\.id, reason: item\.signalReason\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Menu signal focus automation should exercise the same provider/account/reason handoff as status bar row clicks"
assert_match 'layout\.attentionItems\.first \?\? layout\.visibleItems\.first' \
  "QuotaRadar/AppDelegate.swift" \
  "Menu attention focus automation should fall back to the first globally visible feed item after signal sections are compressed"
assert_match 'layout\.attentionItems\.first \{ \$0\.signalReason == \.failed \} \?\? layout\.attentionItems\.first \?\? layout\.visibleItems\.first' \
  "QuotaRadar/AppDelegate.swift" \
  "Menu failed focus automation should still open a useful feed item when no explicit failure row exists"
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
assert_match 'assert_png_minimum_size "\$\{OUTPUT_DIR\}/menu-bar-popover\.png" 500 500' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should assert the compressed menu-bar popover screenshot is complete enough to catch clipped panels"
assert_match 'assert_png_minimum_size "\$\{focused_screenshot\}" 900 600' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should assert the focused main-window screenshot is large enough for account-highlight review"
assert_match 'assert_focused_highlight_present "\$\{focused_screenshot\}"' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should fail when menu-to-main focus opens the window without a visible account highlight"
assert_match 'minimum_highlight_pixels = 20000' \
  "Tests/run_visual_qa.sh" \
  "Focused visual QA should use a threshold high enough to distinguish the selected account highlight from incidental blue UI"
assert_match 'VISUAL_QA_SCENARIOS=\(' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should define an explicit scenario matrix instead of relying on one manual screenshot state"
assert_match 'zh-Hans\|en' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should cover both Simplified Chinese and English language states"
assert_match 'light\|dark' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should cover both light and dark appearances"
assert_match '13-inch\|wide' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should cover compact 13-inch and wide-window main app layouts"
assert_match 'dense-accounts' \
  "Tests/run_visual_qa.sh" \
  "Visual QA scenario matrix should include a dense-account pass, not only generic wide and compact windows"
assert_match 'QUOTARADAR_VISUAL_QA_FIXTURES=1' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should run against deterministic fixture data for multi-key, long-name, and long-error coverage"
assert_match 'QUOTARADAR_VISUAL_QA_LANGUAGE' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should set the app language per scenario without relying on the user's saved preference"
assert_match 'QUOTARADAR_VISUAL_QA_APPEARANCE' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should set light/dark appearance per scenario"
assert_match 'QUOTARADAR_VISUAL_QA_WINDOW_SIZE' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should force compact and wide main-window sizes per scenario"
assert_match 'assert_main_table_alignment' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should report provider table header/content alignment failures explicitly"
assert_match 'assert_no_text_occlusion' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should report likely text overlap or occlusion failures explicitly"
assert_match 'assert_menu_panel_not_clipped' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should report menu-bar top/bottom clipping failures explicitly"
assert_match 'assert_transparency_readability' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should report menu-bar transparency/readability failures explicitly"
assert_match 'checklist' \
  "Tests/run_visual_qa.sh" \
  "Visual QA summary should include a checklist of covered languages, appearances, surfaces, and stress cases"
assert_match 'dense_single_provider_accounts' \
  "Tests/run_visual_qa.sh" \
  "Visual QA summary should explicitly record dense single-provider account coverage"
assert_match 'long_localized_plan_name' \
  "Tests/run_visual_qa.sh" \
  "Visual QA summary should record long localized plan/account copy coverage"
assert_match 'failure_reasons' \
  "Tests/run_visual_qa.sh" \
  "Visual QA summary should expose structured failure-reason fields for faster release review"
assert_match 'scenario_screenshots' \
  "Tests/run_visual_qa.sh" \
  "Visual QA summary should list stable screenshot names for every scenario"
assert_match 'capture_window_png "\$\{menu_window_id\}" "\$\{menu_screenshot\}"' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should capture the menu popover through CoreGraphics window id before falling back to fragile multi-display rectangles"
assert_match 'terminate_visual_qa_app_process' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should terminate per-scenario app processes explicitly instead of relying on stale direct-launch cleanup"
assert_match 'wait_for_visual_qa_app_window' \
  "Tests/run_visual_qa.sh" \
  "Visual QA should wait for each launched app process to expose windows before capturing scenario screenshots"
assert_match 'visualQAFixtureKeys' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should expose deterministic visual QA fixture data behind an automation environment flag"
python3 - <<'PY'
from pathlib import Path
import sys
source = Path("QuotaRadar/Models/QuotaMonitor.swift").read_text()
checks = {
    "saveKeys": ("private func saveKeys()", "store.save(apiKeys)", "Visual QA fixture mode must not save test credentials into the production APIKeyStore"),
    "recordQuotaSnapshot": ("private func recordQuotaSnapshot", "quotaSnapshots = historyStore.append", "Visual QA fixture mode must not write fixture quota snapshots into production history"),
    "ensureSecretsLoaded": ("private func ensureSecretsLoaded()", "apiKeys = store.loadSecrets", "Visual QA fixture mode must not hydrate test keys from the production secret store"),
}
for name, (start, end, message) in checks.items():
    try:
        block = source.split(start, 1)[1].split(end, 1)[0]
    except IndexError:
        print(f"FAIL: could not inspect QuotaMonitor.{name}", file=sys.stderr)
        sys.exit(1)
    if "if Self.usesVisualQAFixtures" not in block or "return" not in block:
        print(f"FAIL: {message}", file=sys.stderr)
        sys.exit(1)
PY
assert_match 'visualQADenseAccountFixtureKeys' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Visual QA fixtures should include a dense single-provider account pack to catch expanded-row layout regressions"
assert_match 'QUOTARADAR_VISUAL_QA_FIXTURES' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Visual QA fixtures should be gated by an explicit automation environment flag"
assert_match 'QUOTARADAR_VISUAL_QA_LANGUAGE' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "App language should support visual QA overrides without relying on saved user preferences"
assert_match 'QUOTARADAR_VISUAL_QA_TRANSPARENCY' \
  "QuotaRadar/Models/AppAppearance.swift" \
  "Menu transparency should support visual QA overrides without relying on saved user preferences"
assert_match 'QUOTARADAR_VISUAL_QA_APPEARANCE' \
  "QuotaRadar/AppDelegate.swift" \
  "AppDelegate should support visual QA light/dark appearance overrides"
assert_match 'QUOTARADAR_VISUAL_QA_WINDOW_SIZE' \
  "QuotaRadar/AppDelegate.swift" \
  "AppDelegate should support visual QA compact and wide main-window size overrides"
assert_match '!isVisualQAAutomation' \
  "QuotaRadar/AppDelegate.swift" \
  "Visual QA forced window sizes should not be persisted into the user's saved settings-window frame"
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
if "HStack(alignment: .center, spacing: 10)" not in summary_card:
    print("FAIL: Status bar summary should be a compact one-line monitoring strip, not a tall card", file=sys.stderr)
    sys.exit(1)
if "VStack(alignment: .leading, spacing: 10)" in summary_card:
    print("FAIL: Status bar summary should not spend vertical space on a large card layout", file=sys.stderr)
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
    "MenuSignalFeedView(monitor: monitor, layout: signalLayout)",
    "MenuHiddenQuotaItemsView("
]
positions = [body.find(fragment) for fragment in required_order]
if any(position < 0 for position in positions):
    print("FAIL: Status bar popover should render a compact summary, watchlist, unified signal feed, and overflow entry", file=sys.stderr)
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
assert_match 'let signalLayout = monitor\.menuSignalLayout' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover should render from a single globally capped signal layout"
assert_match 'MenuWatchedProviderItemsView' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover should show a short user-selected watchlist before automatic long-lived signals"
assert_no_match 'ForEach\(monitor\.menuAttentionQuotaItems' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar attention rows should not bypass the global signal cap"
assert_no_match 'ForEach\(monitor\.menuLowQuotaItems' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar low-quota rows should not bypass the global signal cap"
assert_no_match 'ForEach\(monitor\.menuExpiringQuotaItems' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar expiring-soon rows should not bypass the global signal cap"
assert_no_match 'ForEach\(monitor\.menuRecentUsageQuotaItems' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar recent usage rows should not bypass the global signal cap"
assert_match 'struct MenuSignalFeedView' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover should merge risk, expiry, and recent changes into one compact attention feed"
assert_match 'MenuSignalFeedView\(monitor: monitor, layout: signalLayout\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover should render one globally ranked signal feed instead of one card per signal type"
assert_no_match 'MenuLowQuotaItemsView\(items: signalLayout\.lowQuotaItems\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover should not spend separate cards on low-quota rows"
assert_no_match 'MenuExpiringQuotaItemsView\(items: signalLayout\.expiringSoonItems\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover should not spend separate cards on expiring rows"
assert_no_match 'MenuAttentionItemsView\(monitor: monitor, items: signalLayout\.attentionItems\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover should not spend a separate card on failed/exhausted rows"
assert_no_match 'MenuRecentUsageItemsView\(monitor: monitor, items: signalLayout\.recentUsageItems\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar popover should not spend a separate card on recent usage rows"
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
    feed_view = source.split("struct MenuSignalFeedView: View", 1)[1].split("struct MenuHiddenQuotaItemsView: View", 1)[0]
except IndexError:
    print("FAIL: MenuSignalFeedView should exist before hidden signal entry", file=sys.stderr)
    sys.exit(1)
for fragment in [
    "layout.attentionItems",
    "layout.lowQuotaItems",
    "layout.expiringSoonItems",
    "layout.recentUsageItems"
]:
    if fragment not in feed_view:
        print(f"FAIL: MenuSignalFeedView should merge {fragment} into the same compact feed", file=sys.stderr)
        sys.exit(1)
if "MonitorModule(spacing: 6)" not in feed_view:
    print("FAIL: MenuSignalFeedView should use one compact module instead of one card per signal type", file=sys.stderr)
    sys.exit(1)
if "MenuSignalFeedItemRow(" not in feed_view:
    print("FAIL: MenuSignalFeedView should render unified compact feed rows", file=sys.stderr)
    sys.exit(1)
if "section.id != sections.first?.id" not in feed_view:
    print("FAIL: MenuSignalFeedView should avoid repeating the feed title as the first subgroup label", file=sys.stderr)
    sys.exit(1)
if "onRefresh: { monitor.refreshProvider(item.provider) }" not in feed_view:
    print("FAIL: Menu signal feed rows should allow refreshing the provider from the same compact row", file=sys.stderr)
    sys.exit(1)
if "onOpenProvider: { openProvider(item) }" not in feed_view:
    print("FAIL: Menu signal feed rows should open and focus the provider in the main app", file=sys.stderr)
    sys.exit(1)
if "activitySummary: monitor.activitySummary(for: item.key)" not in feed_view:
    print("FAIL: Menu signal feed rows should render recent activity from QuotaActivitySummary", file=sys.stderr)
    sys.exit(1)
try:
    watched_view = source.split("struct MenuWatchedProviderItemsView: View", 1)[1].split("struct MenuSignalFeedView: View", 1)[0]
except IndexError:
    print("FAIL: MenuWatchedProviderItemsView should exist before the unified signal feed", file=sys.stderr)
    sys.exit(1)
if "MenuWatchedProviderItemRow(" not in watched_view:
    print("FAIL: Menu watched providers should use a dedicated compact watchlist row instead of recent-change rows", file=sys.stderr)
    sys.exit(1)
if "MenuSignalFeedItemRow(" in watched_view or "activitySummary:" in watched_view:
    print("FAIL: Menu watched providers should not repeat recent-change activity explanations in the watchlist section", file=sys.stderr)
    sys.exit(1)
try:
    watched_row = source.split("struct MenuWatchedProviderItemRow: View", 1)[1].split("struct MenuRecentUsageItemRow: View", 1)[0]
except IndexError:
    print("FAIL: MenuWatchedProviderItemRow should exist before recent usage compatibility row", file=sys.stderr)
    sys.exit(1)
if "let isRefreshing: Bool" not in watched_row or "let onRefresh: () -> Void" not in watched_row:
    print("FAIL: Menu watched provider rows should keep the compact refresh affordance", file=sys.stderr)
    sys.exit(1)
if "activitySummary" in watched_row or "activityText" in watched_row or "compactDeltaIndicator" in watched_row:
    print("FAIL: Menu watched provider rows should show current provider state, not trend/delta copy", file=sys.stderr)
    sys.exit(1)
if "noAttentionItems" in feed_view or "checkmark.seal.fill" in feed_view:
    print("FAIL: Menu signal feed should not spend space on a calm empty-state row", file=sys.stderr)
    sys.exit(1)
try:
    monitor_module = source.split("struct MonitorModule<Content: View>: View", 1)[1].split("struct MenuSectionHeader: View", 1)[0]
except IndexError:
    print("FAIL: MonitorModule should exist before section headers", file=sys.stderr)
    sys.exit(1)
if ".padding(.horizontal, 11)" not in monitor_module or ".padding(.vertical, 8)" not in monitor_module:
    print("FAIL: Menu modules should use compact list-style padding instead of large card padding", file=sys.stderr)
    sys.exit(1)
if "cornerRadius: 10" not in monitor_module:
    print("FAIL: Menu modules should use smaller radii so the popover reads as monitoring rows, not large cards", file=sys.stderr)
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
    "MenuSignalFeedItemRow"
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
    recent_row = source.split("struct MenuSignalFeedItemRow: View", 1)[1].split("\nstruct ", 1)[0]
except IndexError:
    print("FAIL: MenuSignalFeedItemRow should exist before shared refresh controls", file=sys.stderr)
    sys.exit(1)
if "let activitySummary: QuotaActivitySummary" not in recent_row:
    print("FAIL: Menu signal feed rows should accept activity summaries instead of percentage-only trend summaries", file=sys.stderr)
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
if "MenuSignalReasonBadge(text: reasonText" not in recent_row:
    print("FAIL: Menu signal feed rows should label each row with its concrete reason", file=sys.stderr)
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
attention_row = recent_row
if "QuotaWindowDetails(" in attention_row:
    print("FAIL: Menu bar attention rows should not expand every quota window; one compact quota line is enough", file=sys.stderr)
    sys.exit(1)
if "presentation.resetText" in attention_row or "presentation.planEndText" in attention_row or "presentation.sourceText" in attention_row:
    print("FAIL: Menu bar attention rows should not spend vertical space on reset/source/plan metadata; the feed should stay action-first", file=sys.stderr)
    sys.exit(1)
if "Button(action: onOpenProvider)" not in attention_row or ".buttonStyle(.plain)" not in attention_row:
    print("FAIL: Menu bar attention rows should use Button semantics while preserving compact row visuals", file=sys.stderr)
    sys.exit(1)
if ".onTapGesture(perform: onOpenProvider)" in attention_row:
    print("FAIL: Menu bar attention rows should not rely on tap gestures for provider focus actions", file=sys.stderr)
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
assert_match 'focusedCredentialIDForDisplay == key\.id' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Expanded provider account rows should use the exact or fallback menu-bar focus target"
assert_match 'focusedCredentialFirstDisplayKeys' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Expanded provider account rows should promote the menu-bar focused credential into the visible account area"
assert_match 'ForEach\(focusedCredentialFirstDisplayKeys, id: \\.id\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Expanded provider account rows should render from the focus-promoted account order"
assert_match 'fallbackFocusedCredential' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider-collapsed menu bar signals should fall back to the most relevant account in the main window"
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
if "hasActiveMonitoringCredentials" not in providers_view:
    print("FAIL: Quota overview should hide providers without active quota-monitoring credentials", file=sys.stderr)
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
assert_match 'case quotaRecovered' \
  "QuotaRadar/Services/QuotaNotificationService.swift" \
  "P6 recovery notifications should be part of the local quota notification event model"
assert_match 'snapshots: \[QuotaSnapshot\]' \
  "QuotaRadar/Services/QuotaNotificationService.swift" \
  "P6 recovery notifications should evaluate recent quota history snapshots"
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
python3 - <<'PY'
from pathlib import Path
import sys

source = Path("QuotaRadar/Models/QuotaMonitor.swift").read_text()
try:
    refresh = source.split("private func refresh(targetProviders:", 1)[1].split("    func addKey(", 1)[0]
except IndexError:
    print("FAIL: could not inspect QuotaMonitor refresh reconciliation", file=sys.stderr)
    sys.exit(1)

required = [
    "refreshStartKeys",
    "deferredResults",
    "reconcileRefreshResults",
    "reconciliation.acceptedResults",
    "affectedNotificationKeyIDs",
    "affectedKeyIDs: affectedNotificationKeyIDs",
]
missing = [token for token in required if token not in refresh]
if missing:
    print(f"FAIL: live refresh should defer and reconcile result side effects; missing {missing}", file=sys.stderr)
    sys.exit(1)

before_reconciliation, after_reconciliation = refresh.split("let reconciliation = Self.reconcileRefreshResults", 1)
if "recordQuotaSnapshot(for:" in before_reconciliation:
    print("FAIL: live refresh must not record quota snapshots before stale-result reconciliation", file=sys.stderr)
    sys.exit(1)
if "failedKeys.append" in before_reconciliation:
    print("FAIL: live refresh must not accumulate failure UI before stale-result reconciliation", file=sys.stderr)
    sys.exit(1)
if after_reconciliation.find("recordQuotaSnapshot(for:") < after_reconciliation.find("reconciliation.acceptedResults"):
    print("FAIL: snapshot recording should iterate only accepted refresh results", file=sys.stderr)
    sys.exit(1)
PY
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
if visible_limit > 4:
    print("FAIL: Status bar attention feed should cap automatic signals at four visible rows", file=sys.stderr)
    sys.exit(1)
if height < 480 or height > 520:
    print("FAIL: Status bar panel should stay compressed instead of becoming a tall dashboard", file=sys.stderr)
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
assert_match 'menuSize = CGSize\(width: 520, height: 500\)' \
  "QuotaRadar/Views/MenuContentView.swift" \
  "Status bar risk popover should stay compressed like a monitoring popover instead of a tall dashboard"
menu_height="$(awk -F'height: ' '/menuSize = CGSize/ { gsub(/[^0-9.].*/, "", $2); print $2; exit }' QuotaRadar/Views/MenuContentView.swift)"
if [[ -z "$menu_height" ]]; then
  fail "Status bar popover should keep menuSize height as a numeric constant"
fi
if awk "BEGIN { exit !($menu_height >= 480 && $menu_height <= 520) }"; then
  :
else
  fail "Status bar popover height should fit a compressed attention feed without becoming a full dashboard"
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
assert_match 'case skipped' \
  "QuotaRadar/Models/QuotaHistory.swift" \
  "Quota history should persist automatic refresh skips so users can tell why nothing changed"
assert_match 'enum QuotaRefreshHistoryKind' \
  "QuotaRadar/Models/QuotaHistory.swift" \
  "Quota history should classify refresh attempts into compact user-facing event kinds"
assert_match 'struct QuotaRefreshHistoryItem' \
  "QuotaRadar/Models/QuotaHistory.swift" \
  "Quota history should expose compact refresh-outcome markers for expanded provider accounts"
assert_match 'static func items' \
  "QuotaRadar/Models/QuotaHistory.swift" \
  "Quota refresh history should be derived through one shared summary function"
assert_match 'func refreshHistoryItems\(for key: APIKey\)' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should expose refresh-history rows to SwiftUI surfaces"
assert_match 'DeferredRefreshResult\(key: key, outcome: \.skipped, countsAsFailure: false\)' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "Automatic refresh skips should defer their quota snapshot until stale-result reconciliation"
assert_no_match 'struct ProviderQuotaRefreshHistoryView' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Expanded provider accounts should not add a bulky refresh-history list to the monitor"
assert_no_match 'ProviderQuotaRefreshHistoryView\(' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Refresh outcomes should be summarized near Last Updated instead of rendered as a separate list"
assert_no_match 'refreshHistoryItems:' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Expanded account groups should receive only the latest refresh marker, not a history list"
assert_match 'latestRefreshHistoryItem:' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Expanded account groups should attach the latest refresh outcome to the Last Updated metadata"
assert_match 'ProviderQuotaRefreshMarker' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Last Updated metadata should show a compact marker for refresh changes"
assert_match 'quotaRefreshMarkerUpdated' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Last Updated refresh markers should use a generic updated state instead of repeating quota deltas"
assert_no_match 'case refreshHistory' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Refresh-history list labels should be removed when the list is no longer rendered"
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
assert_match 'struct QuotaConsumptionSpeedSummary' \
  "QuotaRadar/Models/QuotaHistory.swift" \
  "P6 consumption-speed hints should be derived from quota history, not view-specific heuristics"
assert_match 'static func speedSummary' \
  "QuotaRadar/Models/QuotaHistory.swift" \
  "P6 consumption-speed hints should use one shared reset-aware summary function"
assert_match 'func consumptionSpeedSummary\(for key: APIKey\)' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should expose P6 consumption-speed hints to SwiftUI surfaces"
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
assert_match 'activitySummary: monitor\.activitySummary\(for: key\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Expanded account rows should attach account-specific recent changes to the quota area"
assert_no_match 'speedSummary: monitor\.consumptionSpeedSummary\(for: key\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Expanded account rows should keep speed-risk hints out of the quota-window table"
assert_no_match 'refreshItem\.deltaText' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Last Updated refresh markers should stay status-only instead of showing quota deltas"
python3 - <<'PY'
from pathlib import Path
import sys

source = Path("QuotaRadar/Views/SettingsView.swift").read_text()
try:
    quota_windows = source.split("struct ProviderQuotaAccountQuotaWindows: View", 1)[1].split("struct CodexResetCreditRow: View", 1)[0]
except IndexError:
    print("FAIL: Expanded account quota window block should exist", file=sys.stderr)
    sys.exit(1)
if "ProviderQuotaInlineActivity(" not in quota_windows:
    print("FAIL: Expanded account quota blocks should render recent changes below the quota windows", file=sys.stderr)
    sys.exit(1)
if "summary: activitySummary" not in quota_windows:
    print("FAIL: Expanded account quota blocks should use the account-specific activity summary", file=sys.stderr)
    sys.exit(1)
if "speedSummary: .empty" not in quota_windows:
    print("FAIL: Expanded account quota blocks should render only recent changes, not speed-risk hints", file=sys.stderr)
    sys.exit(1)
try:
    meta_panel = source.split("struct ProviderQuotaAccountMetaPanel: View", 1)[1].split("struct ProviderQuotaTimingColumn: View", 1)[0]
except IndexError:
    print("FAIL: Expanded account metadata panel should exist", file=sys.stderr)
    sys.exit(1)
if "activitySummary" in meta_panel or "speedSummary" in meta_panel or "deltaText" in meta_panel:
    print("FAIL: Last Updated metadata should stay refresh-status-only and not render quota activity", file=sys.stderr)
    sys.exit(1)
try:
    inline_activity = source.split("struct ProviderQuotaInlineActivity: View", 1)[1].split("struct QuotaSpeedHint: View", 1)[0]
except IndexError:
    print("FAIL: Inline quota activity component should exist", file=sys.stderr)
    sys.exit(1)
if "else if speedSummary.shouldRender" not in inline_activity:
    print("FAIL: Inline quota activity should prefer real recent changes over speed-risk hints instead of rendering both side by side", file=sys.stderr)
    sys.exit(1)
PY
assert_match 'summary: providerActivitySummary' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider summary rows should keep meaningful activity attached to the quota reading"
assert_match 'ProviderQuotaInlineActivity' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider summary rows should render activity as an inline quota-side signal"
assert_match 'summary\.deltaText\?\.trimmingCharacters' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Inline quota activity should hide bare period markers when there is no actual change"
assert_match 'summary\.kind == \.recovered' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Inline quota activity should surface balance replenishment instead of hiding recovered events behind a missing delta"
assert_match 'L10n\.t\(\.quotaTrendReplenished\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Inline quota activity should label recovered balance changes instead of showing a bare period marker"
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
if "Text(L10n.t(.credentialState))" not in overview_header:
    print("FAIL: Provider quota status column header should say Status/State now that quota risk lives in Key Quota", file=sys.stderr)
    sys.exit(1)
if "Text(L10n.t(.quotaStatus))" in overview_header:
    print("FAIL: Provider quota status column header should not still be labelled Quota Status", file=sys.stderr)
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
if "compactDataWidth" not in source or "compactScale" not in source:
    print("FAIL: Provider quota overview rows should shrink data columns in compact 13-inch windows so action buttons stay visible", file=sys.stderr)
    sys.exit(1)
if "contentWidth < minimumTotalWidth" not in source:
    print("FAIL: Provider quota overview layout should detect compact windows before applying the default width budget", file=sys.stderr)
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
if "CodexResetCreditRow(" not in account_table:
    print("FAIL: Codex reset-credit controls should live in the expanded account row near quota windows", file=sys.stderr)
    sys.exit(1)
if "isResettingCodexQuota" not in account_table or "onResetCodexQuota" not in account_table:
    print("FAIL: Expanded account rows should receive account-scoped Codex reset state and action callbacks", file=sys.stderr)
    sys.exit(1)
if "provider == .codexSubscription" not in account_table:
    print("FAIL: Codex reset-credit controls should be gated to Codex subscription credentials", file=sys.stderr)
    sys.exit(1)
if "Provider.codexSubscription" in account_table:
    print("FAIL: Codex reset-credit account rows should gate on the selected key provider instead of a provider-level constant", file=sys.stderr)
    sys.exit(1)
if "periodText: L10n.t(.remaining)" in account_table:
    print("FAIL: Expanded account groups should not repeat Remaining as both section label and fallback row label", file=sys.stderr)
    sys.exit(1)
if "ProviderQuotaAccountMetaPanel(" not in account_table:
    print("FAIL: Expanded account groups should show plan expiry and last update once in a compact meta panel", file=sys.stderr)
    sys.exit(1)
account_group_body = account_table.split("var body: some View", 1)[1].split("struct ProviderQuotaRefreshMarker", 1)[0]
identity_position = account_group_body.find("ProviderQuotaAccountIdentity(")
windows_position = account_group_body.find("ProviderQuotaAccountQuotaWindows(")
meta_position = account_group_body.find("ProviderQuotaAccountMetaPanel(")
if not (0 <= identity_position < windows_position < meta_position):
    print("FAIL: Expanded account groups should keep quota windows between identity and the original right-side critical-time/last-updated panel", file=sys.stderr)
    sys.exit(1)
if "Spacer(minLength: 12)" in account_group_body and account_group_body.find("Spacer(minLength: 12)") < meta_position:
    print("FAIL: Expanded account groups should not replace the quota-window column with a spacer before the right-side time panel", file=sys.stderr)
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
quota_windows_container = window_details.split("struct CodexResetCreditRow: View", 1)[0]
if ".frame(maxWidth: .infinity, alignment: .leading)" not in quota_windows_container:
    print("FAIL: Expanded quota window containers should fill the available account width so reset details are readable", file=sys.stderr)
    sys.exit(1)
try:
    quota_window_row = source.split("struct ProviderQuotaAccountQuotaWindowRow: View", 1)[1].split("struct ProviderQuotaAccountMetaPanel", 1)[0]
except IndexError:
    print("FAIL: Expanded account quota window row should exist", file=sys.stderr)
    sys.exit(1)
if "HStack(alignment: .firstTextBaseline, spacing: 12)" not in quota_window_row or "value: detailText ?? \"\"" not in quota_window_row:
    print("FAIL: Expanded quota window rows should keep remaining percentage and reset detail on the same horizontal line", file=sys.stderr)
    sys.exit(1)
if "let resetText: String?" in quota_window_row or "if let resetText" in quota_window_row:
    print("FAIL: Expanded quota window rows should not split reset timing into a separate vertical line", file=sys.stderr)
    sys.exit(1)
if ".frame(width: 72, alignment: .leading)" not in quota_window_row or ".frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)" not in quota_window_row:
    print("FAIL: Expanded quota window rows should claim the available width for reset details instead of shrinking to a narrow intrinsic row", file=sys.stderr)
    sys.exit(1)
if "ProviderQuotaAccountGridRow(" in account_table or "ProviderQuotaWindowDetailGridRow(" in account_table:
    print("FAIL: Expanded account groups should not reuse table grid rows that recreate empty columns", file=sys.stderr)
    sys.exit(1)
if "L10n.t(.lastUpdated)" not in account_table:
    print("FAIL: Expanded account meta panel should keep last-updated visible once per account", file=sys.stderr)
    sys.exit(1)
if "struct CodexResetCreditRow: View" not in source:
    print("FAIL: Settings should define a compact CodexResetCreditRow for account-level reset credits", file=sys.stderr)
    sys.exit(1)
codex_reset_row = source.split("struct CodexResetCreditRow: View", 1)[1].split("struct ProviderQuotaAccountSingleQuotaRow", 1)[0]
if "codexResetCreditsRemaining" not in codex_reset_row or "codexResetQuotaAction" not in codex_reset_row:
    print("FAIL: Codex reset-credit row should show available credits and a localized reset action", file=sys.stderr)
    sys.exit(1)
if "codexResetCreditExpiryText" not in codex_reset_row:
    print("FAIL: Codex reset-credit row should show provider-returned earliest expiry when available", file=sys.stderr)
    sys.exit(1)
if "struct CodexResetCreditActionGroup: View" not in source:
    print("FAIL: Codex reset-credit expiry and manual action should be grouped into a compact trailing action group", file=sys.stderr)
    sys.exit(1)
codex_reset_action_group = source.split("struct CodexResetCreditActionGroup: View", 1)[1].split("struct ProviderQuotaAccountSingleQuotaRow", 1)[0]
if "codexResetCreditExpiryText" not in codex_reset_action_group or "Button(action: onResetCodexQuota)" not in codex_reset_action_group:
    print("FAIL: Codex reset-credit expiry should live with the reset action instead of a separate middle column", file=sys.stderr)
    sys.exit(1)
if "VStack(alignment: .leading" not in codex_reset_action_group:
    print("FAIL: Codex reset-credit action group should stack expiry context with the action for a quieter account row", file=sys.stderr)
    sys.exit(1)
if "let resetText: String?" in codex_reset_row or "if let resetText" in codex_reset_row:
    print("FAIL: Codex reset-credit row should not group reset dates with the manual reset action; keep both aligned by column rules", file=sys.stderr)
    sys.exit(1)
if "HStack(alignment: .firstTextBaseline, spacing: 12)" not in codex_reset_row:
    print("FAIL: Codex reset-credit row should align with quota-window period/value/detail columns", file=sys.stderr)
    sys.exit(1)
if ".frame(width: 62, alignment: .leading)" not in codex_reset_row or ".frame(width: 72, alignment: .leading)" not in codex_reset_row:
    print("FAIL: Codex reset-credit count should use the same period and value column widths as reset-date rows", file=sys.stderr)
    sys.exit(1)
if "Button(" not in codex_reset_action_group or ".disabled(" not in codex_reset_action_group:
    print("FAIL: Codex reset-credit row should render a disabled-safe button", file=sys.stderr)
    sys.exit(1)
if ".buttonStyle(.bordered)" in codex_reset_action_group:
    print("FAIL: Codex reset-credit action should not use a bordered button in the compact monitor row", file=sys.stderr)
    sys.exit(1)
if "Text(L10n.t(.codexResetQuotaAction))" not in codex_reset_action_group:
    print("FAIL: Codex reset-credit action should keep visible localized text so users understand the reset function", file=sys.stderr)
    sys.exit(1)
if "Image(systemName: \"arrow.counterclockwise\")" not in codex_reset_action_group:
    print("FAIL: Codex reset-credit action should keep a compact reset icon next to the explanatory text", file=sys.stderr)
    sys.exit(1)
if ".buttonStyle(.plain)" not in codex_reset_action_group or ".frame(height: 22)" not in codex_reset_action_group:
    print("FAIL: Codex reset-credit action should match compact monitoring controls with a fixed-height inline action", file=sys.stderr)
    sys.exit(1)
if ".frame(maxWidth: .infinity, alignment: .leading)" not in codex_reset_row:
    print("FAIL: Codex reset-credit action should align to the same detail-column start as reset-date text", file=sys.stderr)
    sys.exit(1)
if "resetText: nextResetText" in account_table or "private var nextResetText: String?" in account_table:
    print("FAIL: Expanded Codex reset-credit rows should not duplicate reset timing inside the manual action row", file=sys.stderr)
    sys.exit(1)
if "Capsule(style: .continuous)" not in codex_reset_action_group:
    print("FAIL: Codex reset-credit action should use a low-noise capsule treatment instead of a standard button bezel", file=sys.stderr)
    sys.exit(1)
if ".accessibilityLabel(L10n.t(.codexResetQuotaAction))" not in codex_reset_action_group:
    print("FAIL: Codex reset-credit action should keep an accessible localized action label", file=sys.stderr)
    sys.exit(1)
if "codexResetQuotaConfirmTitle" not in source or "confirmationDialog" not in source:
    print("FAIL: Codex quota reset should ask for confirmation before consuming a reset credit", file=sys.stderr)
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
if "metaRow(label: L10n.t(.lastUpdated), value: updatedText, refreshItem: refreshItem)" not in account_table:
    print("FAIL: Expanded account groups should show last updated with a compact refresh marker in the account meta panel", file=sys.stderr)
    sys.exit(1)
try:
    refresh_marker = source.split("struct ProviderQuotaRefreshMarker: View", 1)[1].split("struct ProviderQuotaAccountIdentity: View", 1)[0]
except IndexError:
    print("FAIL: ProviderQuotaRefreshMarker should exist before account identity", file=sys.stderr)
    sys.exit(1)
if "item.deltaText" in refresh_marker:
    print("FAIL: Last Updated refresh marker should not repeat quota change amounts such as -7pt", file=sys.stderr)
    sys.exit(1)
if "case .consumed, .recovered:" not in refresh_marker:
    print("FAIL: Last Updated refresh marker should collapse consumed/recovered success into one generic updated state", file=sys.stderr)
    sys.exit(1)
if "L10n.t(.quotaRefreshMarkerUpdated)" not in refresh_marker:
    print("FAIL: Last Updated refresh marker should show Updated for successful changed refreshes", file=sys.stderr)
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
assert_match 'enum AppThemeModeOption: String, CaseIterable, Identifiable' \
  "QuotaRadar/Models/AppAppearance.swift" \
  "QuotaRadar should expose a finite app theme mode model"
assert_match 'case system' \
  "QuotaRadar/Models/AppAppearance.swift" \
  "App theme mode should support following the macOS system appearance"
assert_match 'case light' \
  "QuotaRadar/Models/AppAppearance.swift" \
  "App theme mode should support a forced light appearance"
assert_match 'case dark' \
  "QuotaRadar/Models/AppAppearance.swift" \
  "App theme mode should support a forced dark appearance"
assert_match 'static let appearanceModeKey = "appearanceMode"' \
  "QuotaRadar/Models/AppAppearance.swift" \
  "Theme mode should persist under a stable UserDefaults key"
assert_match '@Published var appearanceMode: AppThemeModeOption' \
  "QuotaRadar/Models/AppAppearance.swift" \
  "Theme mode changes should publish to the running app"
assert_match 'appearanceMode = \.system' \
  "QuotaRadar/Models/AppAppearance.swift" \
  "QuotaRadar should default to following the system appearance"
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
assert_match 'SettingsCenteredMenuPicker\(selection: \$appearanceStore\.appearanceMode' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Settings should let users choose system, light, or dark appearance with the compact menu control"
assert_match 'L10n\.t\(\.appearanceMode' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Theme mode settings row should use localized labels"
assert_match 'AppAppearanceStore\.shared\.\$appearanceMode' \
  "QuotaRadar/AppDelegate.swift" \
  "The running app should observe saved theme-mode changes"
assert_match 'sink \{ \[weak self\] appearanceMode in' \
  "QuotaRadar/AppDelegate.swift" \
  "Theme-mode changes should apply the freshly published value instead of re-reading the old @Published stored value"
assert_no_match 'sink \{ \[weak self\] _ in[[:space:]]*self\?\.applyConfiguredAppearanceMode\(\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Theme-mode changes must not be applied from the stale @Published stored value"
assert_match 'applyConfiguredAppearanceMode' \
  "QuotaRadar/AppDelegate.swift" \
  "AppDelegate should apply the user-configured theme mode"
assert_match 'NSApp\.appearance = nil' \
  "QuotaRadar/AppDelegate.swift" \
  "Following system appearance should clear the app-level appearance override"
assert_match 'NSAppearance\(named: \.aqua\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Forced light mode should use the macOS Aqua appearance"
assert_match 'NSAppearance\(named: \.darkAqua\)' \
  "QuotaRadar/AppDelegate.swift" \
  "Forced dark mode should use the macOS dark Aqua appearance"
assert_match 'guard !applyVisualQAAppearanceOverrideIfRequested\(\) else \{ return \}' \
  "QuotaRadar/AppDelegate.swift" \
  "Visual QA light/dark overrides should take priority over saved user theme mode without persisting it"
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
assert_match 'Button\(action: onExportMetadata\)' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential configuration panel should expose a direct metadata export action"
assert_match 'exportCredentialMetadata' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Credential metadata export button should be localized"
assert_match 'struct CredentialMetadataExporter' \
  "QuotaRadar/Services/CredentialMetadataExporter.swift" \
  "Credential metadata export should live in a dedicated service"
assert_no_match 'var key:|let key:|cookie|authorization|token|secret' \
  "QuotaRadar/Services/CredentialMetadataExporter.swift" \
  "Credential metadata export service must not include secret-bearing fields or names"
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
assert_no_match 'clearProviderCookiesBeforeLoading' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should preserve provider cookies before opening the login page so first-save captures can reuse completed web-login state"
assert_no_match 'cookieStore\.delete' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should not delete WebView cookies while the user is trying to save web-login authorization"
assert_no_match 'removeData\(|removeDataOfTypes|removeWebsiteData' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard reauthentication should preserve WebKit website data while capturing a fresh login credential"
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
assert_match 'captureCredentialForManualSave' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Manual dashboard credential save should re-read cookies instead of reusing a stale first failed capture"
assert_no_match 'WKWebsiteDataStore\.default\(\)\.httpCookieStore\.getAllCookies' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Manual dashboard credential save should read from the current authentication WebView instead of a global cookie store"
assert_match 'manualCaptureRequestID' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Manual dashboard credential save should signal the embedded WebView to capture the current login state"
assert_no_match 'latestCapturedCredential' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Manual dashboard credential save must not keep or resubmit a stale cached credential"
assert_match 'captureCredential\(from: webView\)' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Manual dashboard credential save should share the automatic cookie and WebStorage capture path"
assert_match 'automaticCaptureResetRequestID' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Provider validation failure should explicitly re-arm automatic WebView credential capture"
assert_match 'DashboardCredentialCapturePolicy\.manualRetryDelays' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Manual dashboard credential save should briefly retry after early partial cookie reads"
assert_match 'scheduleCookieCaptureRetry' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Automatic dashboard credential capture should schedule delayed retries after cookie and navigation events"
assert_match 'DashboardCredentialCapturePolicy\.nextAutomaticRetryDelay' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Automatic dashboard credential capture should use the provider retry policy before giving up"
assert_match 'automaticRetryDelays\(for provider: Provider\)' \
  "QuotaRadar/Services/DashboardReauth.swift" \
  "Dashboard reauthentication should allow provider-specific delayed cookie capture"
assert_match 'captureWebStorageFieldsIfAllowed' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard credential capture should read WebStorage only when the visible page is on an allowed provider domain"
assert_match 'guard !captureLifecycle\.hasEmittedAutomaticCredential, let webView else' \
  "QuotaRadar/Views/DashboardReauthView.swift" \
  "Dashboard cookie capture should rely on provider-domain cookie filtering instead of requiring the visible WebView URL to have returned to the provider domain"
assert_match 'reauthStillUnauthorized' \
  "QuotaRadar/Models/AppLanguage.swift" \
  "Dashboard reauthentication should explain when captured cookies still fail provider login validation"
assert_match 'configuration\.websiteDataStore = \.default\(\)' \
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
assert_match 'https://claude\.ai/api/organizations/.*/prepaid/credits' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Anthropic Credits should replay the observed claude.ai prepaid credits endpoint with saved web-login authorization"
assert_match 'fetchClaudeOrganizationContext' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Claude subscription should preserve plan evidence from the organizations endpoint"
assert_match 'parseAnthropicPrepaidCredits' \
  "QuotaRadar/Services/QuotaService.swift" \
  "Anthropic Credits responses should be parsed separately from Claude subscription quota windows"
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
LONGCAT_TOKEN_PACK_SESSION='longcat_session=token-pack-session'
LONGCAT_PAYGO_SESSION='longcat_session=paygo-session'
LONGCAT_TOKEN_PACK_API_KEY=longcat-token-pack-api-key
LONGCAT_PAYGO_API_KEY=longcat-paygo-api-key
LONGCAT_API_KEY=longcat-generic-api-key
"""

AppLanguageStore.shared.language = .english
let keys = EnvImporter.parseEnvContent(env)

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(1)
    }
}

require(keys.count == 17, "expected exactly seventeen visible supported imported keys")
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
require(keys.contains { $0.name == "LONGCAT_TOKEN_PACK_SESSION" && $0.provider == .longcat && $0.key == "longcat_session=token-pack-session" }, "LongCat Token Pack dashboard session should be importable for quota monitoring")
require(keys.contains { $0.name == "LONGCAT_PAYGO_SESSION" && $0.provider == .longcat && $0.key == "longcat_session=paygo-session" }, "LongCat Pay-as-you-go dashboard session should be importable for balance monitoring")
require(keys.contains { $0.name == "LONGCAT_TOKEN_PACK_API_KEY" && $0.provider == .longcat && $0.key == "longcat-token-pack-api-key" }, "LongCat Token Pack companion API key should be importable as copy-only storage")
require(keys.contains { $0.name == "LONGCAT_PAYGO_API_KEY" && $0.provider == .longcat && $0.key == "longcat-paygo-api-key" }, "LongCat Pay-as-you-go companion API key should be importable as copy-only storage")
require(keys.contains { $0.name == "LONGCAT_API_KEY" && $0.provider == .longcat && $0.key == "longcat-generic-api-key" }, "Generic LongCat API keys should default to the API pay-as-you-go provider as copy-only storage")
let importedQueritAPIKey = keys.first { $0.name == "QUERIT_API_KEY" }!
require(importedQueritAPIKey.isStoredAPIKeyOnlyCredential, "Querit API keys should import as copy-only API-key records, not dashboard cookies")
require(importedQueritAPIKey.copyableCredentialValue == "querit-api-key", "Querit optional API keys should be copyable")
let importedLongCatPaygoAPIKey = keys.first { $0.name == "LONGCAT_PAYGO_API_KEY" }!
require(importedLongCatPaygoAPIKey.isStoredAPIKeyOnlyCredential, "LongCat API keys should import as copy-only API-key records, not dashboard quota credentials")
require(importedLongCatPaygoAPIKey.copyableCredentialValue == "longcat-paygo-api-key", "LongCat optional API keys should be copyable")
let importedLongCatGenericAPIKey = keys.first { $0.name == "LONGCAT_API_KEY" }!
require(importedLongCatGenericAPIKey.isStoredAPIKeyOnlyCredential, "Generic LongCat API keys should remain copy-only and should not be treated as dashboard authorization")
require(importedLongCatGenericAPIKey.copyableCredentialValue == "longcat-generic-api-key", "Generic LongCat API keys should be copyable")
require(!keys.contains { $0.name == "DEEPSEEK_WEB_SEARCH_PRO_API_KEY" }, "web-search-pro DeepSeek key must be ignored")
require(!keys.contains { $0.name == "ANTHROPIC_AUTH_TOKEN" }, "Anthropic auth token must not be imported as an API key")
require(!keys.contains { $0.name == "CODEX_SESSION_COOKIE" }, "Codex subscription cookies should be captured through web-login reauthentication instead of .env import")
require(!Provider.visibleCases.contains(.anthropic), "Legacy Anthropic provider should stay hidden in favor of Claude API/OAuth provider entries")
require(!Provider.visibleCases.contains(.claudeAPIUsage), "Claude API usage should stay hidden until the user has admin usage monitoring configured")
require(Provider.visibleCases.contains(.claudeSubscription), "Claude subscription should appear in provider pickers and visible app sections")
require(Provider.visibleCases.contains(.anthropicCredits), "Anthropic Credits should appear as a separate provider after the prepaid credits endpoint is observed")
require(!Provider.visibleCases.contains(.codexAPIUsage), "Codex API usage should stay hidden until the user has admin usage monitoring configured")
require(Provider.visibleCases.contains(.codexSubscription), "Codex subscription should appear in provider pickers and visible app sections")
require(Provider.visibleCases.contains(.kimiSubscription), "Kimi subscription should appear in provider pickers and visible app sections")
require(Provider.visibleCases.filter { $0 == .longcat }.count == 1, "LongCat should appear once in provider pickers and visible app sections")
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
require(Provider.longcat.category == "LLM", "LongCat should be grouped as one LLM provider")
require(Provider.claudeAPIUsage.category == "LLM", "Claude API usage should be grouped as an LLM quota provider")
require(Provider.anthropicCredits.category == "LLM", "Anthropic Credits should be grouped as an LLM balance provider")
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
require(Provider.anthropicCredits.providerFamilyDisplayName(language: .english) == "Anthropic", "Anthropic Credits should expose Anthropic as the provider family")
require(Provider.anthropicCredits.planTypeDisplayName(language: .english) == "Credits", "Anthropic Credits should expose credits as the provider-level product type")
require(Provider.anthropicCredits.planTypeDisplayName(language: .simplifiedChinese) == "余额", "Anthropic Credits should expose a localized credits product type")
require(Provider.codexAPIUsage.providerFamilyDisplayName(language: .english) == "Codex", "Codex API usage should expose Codex as provider family")
require(Provider.codexSubscription.planTypeDisplayName(language: .english) == "Subscription", "Codex subscription should expose Subscription as the provider-level product type")
require(Provider.kimiSubscription.providerFamilyDisplayName(language: .english) == "Kimi", "Kimi subscription should expose Kimi as provider family")
require(Provider.kimiSubscription.planTypeDisplayName(language: .simplifiedChinese) == "订阅", "Kimi subscription should expose a localized provider-level subscription product type")
require(Provider.longcat.providerFamilyDisplayName(language: .simplifiedChinese) == "LongCat", "LongCat should expose LongCat as provider family")
require(Provider.longcat.planTypeDisplayName(language: .simplifiedChinese) == "Token 资源包 / API 按量", "LongCat should expose both token package and API pay-as-you-go billing modes")
require(Provider.longcat.providerFamilyDisplayName(language: .english) == "LongCat", "LongCat should expose LongCat as provider family")
require(Provider.longcat.planTypeDisplayName(language: .english) == "Token Pack / Pay-as-you-go", "LongCat should expose both billing modes in English")
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
require(Provider.anthropicCredits.supportsQuotaQuery, "Anthropic Credits should support balance checks through the observed claude.ai prepaid credits endpoint")
require(!Provider.codexAPIUsage.supportsQuotaQuery, "Codex API usage should not claim quota checks until OpenAI Admin usage credentials are modeled and verified")
require(Provider.codexSubscription.supportsQuotaQuery, "Codex subscription should support quota checks through the verified ChatGPT wham endpoint")
require(Provider.kimiSubscription.supportsQuotaQuery, "Kimi subscription should support quota checks through the Kimi membership endpoints")
require(Provider.longcat.supportsQuotaQuery, "LongCat should support quota and balance checks through LongCat dashboard billing APIs")
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
require(Provider.anthropicCredits.capability.credentialKind == .dashboardCookie, "Anthropic Credits should use Claude web login authorization instead of Anthropic API keys")
require(Provider.anthropicCredits.capability.usageSource == .dashboardAPI, "Anthropic Credits should use the observed claude.ai dashboard prepaid credits endpoint")
require(Provider.anthropicCredits.capability.supportsBalance, "Anthropic Credits should present prepaid credits as a balance, not subscription quota")
require(!Provider.anthropicCredits.capability.supportsReset, "Anthropic Credits should not invent a reset cycle")
require(Provider.anthropicCredits.capability.canTestConnection, "Anthropic Credits should offer a non-consuming dashboard balance check")
require(Provider.anthropicCredits.capability.allowsAutomaticRefresh, "Anthropic Credits should be eligible for normal no-cost automatic refresh once saved")
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
require(Provider.longcat.capability.credentialKind == .dashboardCookie, "LongCat should store web login authorization separately from API keys")
require(Provider.longcat.capability.usageSource == .dashboardAPI, "LongCat should expose token package and API balance through LongCat dashboard APIs")
require(Provider.longcat.capability.supportsQuota, "LongCat should expose token package remaining and total")
require(Provider.longcat.capability.supportsBalance, "LongCat should expose API pay-as-you-go balance")
require(Provider.longcat.capability.supportsPlan, "LongCat should expose package validity and billing mode metadata")
require(!Provider.longcat.capability.supportsReset, "LongCat should expose package expiry as validity instead of inventing a reset cycle")
require(Provider.longcat.capability.canTestConnection, "LongCat should offer a non-consuming dashboard billing check")
require(Provider.longcat.capability.allowsAutomaticRefresh, "LongCat billing checks should be eligible for no-cost automatic refresh")
require(Provider.querit.supportsQuotaQuery, "Querit should support dashboard-cookie quota checks through the user account endpoint")
require(Provider.querit.capability.resetCycle == .notExposed, "Querit account endpoint exposes monthly usage but no reset/end date")
require(Provider.querit.supportsCompanionAPIKeyStorage, "Querit should allow storing an optional API key separately from dashboard authorization")
require(Provider.claudeSubscription.supportsCompanionAPIKeyStorage, "Claude subscription should allow saving an optional API key separately from web login authorization")
require(Provider.claudeSubscription.copyableAPIKeyCredentialName == "ANTHROPIC_API_KEY", "Claude subscription companion API key should use the familiar Anthropic API key name")
require(Provider.codexSubscription.supportsCompanionAPIKeyStorage, "Codex subscription should allow saving an optional API key separately from web login authorization")
require(Provider.codexSubscription.copyableAPIKeyCredentialName == "OPENAI_API_KEY", "Codex subscription companion API key should use the familiar OpenAI API key name")
require(Provider.kimiSubscription.supportsCompanionAPIKeyStorage, "Kimi subscription should allow saving an optional API key separately from web login authorization")
require(Provider.kimiSubscription.copyableAPIKeyCredentialName == "KIMI_API_KEY", "Kimi subscription companion API key should use the familiar Kimi API key name")
require(Provider.longcat.supportsCompanionAPIKeyStorage, "LongCat should allow saving an optional API key separately from web login authorization")
require(Provider.longcat.copyableAPIKeyCredentialName == "LONGCAT_API_KEY", "LongCat companion API key should use one provider-level API key name")
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
require(!Provider.longcat.homeVisibleWithoutKeys, "LongCat Token Pack should stay off empty home placeholders until configured")
require(!Provider.longcat.homeVisibleWithoutKeys, "LongCat Pay-as-you-go should stay off empty home placeholders until configured")
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
    (.longcat, "LongCat"),
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
require(multiBraveStat.keyQuotaDisplayText == "92%", "Quota overview key quota should prefer the tightest usable key when an API-key pool also contains an exhausted key")
require(multiBraveStat.credentialPoolDisplayText == "2 keys · 1 usable · 1 attention", "Quota overview credential pool should show attention count for exhausted keys")
let mixedTavilyStat = ProviderStats(
    provider: .tavily,
    keys: [
        APIKey(name: "TAVILY_EMPTY", key: "tvly-empty", provider: .tavily, remaining: 0, limit: 1000, resetAt: localizedResetDate),
        APIKey(name: "TAVILY_USABLE", key: "tvly-usable", provider: .tavily, remaining: 361, limit: 1000, resetAt: localizedResetDate)
    ]
)
require(mixedTavilyStat.keyQuotaDisplayText == "36%", "Tavily overview should not let a long-exhausted key hide the remaining quota on a usable key")
let exhaustedTavilyWithReset = APIKey(
    name: "TAVILY_EMPTY",
    key: "tvly-empty",
    provider: .tavily,
    remaining: 0,
    limit: 1000,
    resetAt: localizedResetDate,
    quotaLabel: "0 / 1000 monthly credits"
)
require(
    exhaustedTavilyWithReset.quotaPresentation.primaryText == "\(L10n.t(.healthExhausted)) · \(exhaustedTavilyWithReset.visibleQuotaResetSummary)",
    "Exhausted Tavily keys should surface reset timing instead of repeating a stale 0 / limit quota as the primary monitoring signal"
)
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
require(MenuSignalReason.unknown.displayText == L10n.t(.needsAttention), "Unknown menu reasons should use a soft attention label instead of generic quota status")
let schemaDriftMenuKey = APIKey(
    name: "CODEX_SCHEMA_DRIFT",
    key: "cookie",
    provider: .codexSubscription,
    lastDiagnosticMessage: "Provider quota fields may have changed. Recalibrate this provider.",
    lastDiagnosticText: .localized(.quotaErrorSchemaDrift)
)
let schemaDriftMenuStats = [
    ProviderStats(provider: .codexSubscription, keys: [schemaDriftMenuKey])
]
let schemaDriftMenuItems = MenuQuotaItem.attentionItems(from: schemaDriftMenuStats, limit: 5)
require(schemaDriftMenuItems.map { $0.key.name } == ["CODEX_SCHEMA_DRIFT"], "Status bar attention items should surface provider schema drift as an actionable calibration issue")
require(MenuQuotaItem(provider: .codexSubscription, key: schemaDriftMenuKey).signalReason == .schemaDrift, "Menu quota items should distinguish schema drift from generic failed checks")
require(MenuSignalReason.schemaDrift.displayText == "Recalibrate", "English menu schema-drift reason should use a short action label")
require(schemaDriftMenuKey.healthDisplayText == "Needs Recalibration", "Schema-drift credential health should be actionable instead of generic check failed")
require(schemaDriftMenuKey.credentialConfigurationState.displayText == "Needs Recalibration", "Schema-drift credential state should be actionable instead of generic check failed")
let schemaDriftCredentialDiagnostic = CredentialDiagnosticItem(
    key: schemaDriftMenuKey,
    statusKey: schemaDriftMenuKey,
    companionAPIKey: nil
)
require(schemaDriftCredentialDiagnostic.diagnosticStatusText == "Needs Recalibration", "Diagnostics should show schema drift as a recalibration issue instead of a generic failed check")
AppLanguageStore.shared.language = .simplifiedChinese
require(MenuSignalReason.schemaDrift.displayText == "重新校准", "Chinese menu schema-drift reason should use a short action label")
require(schemaDriftMenuKey.healthDisplayText == "需要重新校准", "Chinese schema-drift health should be actionable")
require(schemaDriftCredentialDiagnostic.diagnosticStatusText == "需要重新校准", "Chinese diagnostics should show schema drift as a recalibration issue")
AppLanguageStore.shared.language = .english
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
let localizedAnthropicCredits = APIKey(name: "ANTHROPIC_CREDITS_SESSION", key: "claude-session", provider: .anthropicCredits, remaining: 42, limit: 42, quotaLabel: "42 credits left")
require(localizedAnthropicCredits.quotaDisplayText == "剩余 42 积分", "Anthropic Credits should localize prepaid credits as credits, not as Claude subscription quota")
require(localizedAnthropicCredits.remainingBadgeText == "42", "Anthropic Credits badges should show the credit balance instead of a fake percentage")
let anthropicCreditsStats = ProviderStats(provider: .anthropicCredits, keys: [localizedAnthropicCredits])
require(anthropicCreditsStats.totalRemainingDisplayText == "42", "Anthropic Credits provider overview should show the credit balance")
require(anthropicCreditsStats.totalLimitDisplayText == "", "Anthropic Credits provider overview should leave reset-cycle columns blank")
let localizedDeepSeekMoney = APIKey(name: "DEEPSEEK_API_KEY", key: "deepseek", provider: .deepseek, remaining: 1250, limit: 1250, quotaLabel: "CNY 12.50 available")
require(localizedDeepSeekMoney.quotaDisplayText == "可用¥12.50", "DeepSeek money balance labels should use compact RMB symbols, not credits or verbose RMB copy")
require(localizedDeepSeekMoney.remainingBadgeText == "¥12.50", "DeepSeek money balance badge should show currency amount, not 100%")
require(localizedDeepSeekMoney.visibleQuotaResetSummary == "", "DeepSeek compact quota rows should not show no-reset-cycle placeholder copy")
let localizedLongCatPackageEnd = Date().addingTimeInterval(30 * 24 * 60 * 60)
let localizedLongCatTokenPack = APIKey(
    name: "LONGCAT_SESSION",
    key: "longcat-session",
    provider: .longcat,
    remaining: 1250000,
    limit: 5000000,
    planEndsAt: localizedLongCatPackageEnd,
    quotaText: .quotaWindows([
        QuotaWindowText(name: "tokenPack", percentText: "25%", remainingText: "1250000 / 5000000 tokens"),
        QuotaWindowText(name: "paygoBalance", percentText: "¥128.50", remainingText: "CNY 128.50 balance")
    ]),
    quotaLabel: "Token Pack 25% · API Balance ¥128.50"
)
require(localizedLongCatTokenPack.quotaDisplayText == "Token 资源包 25% · API 按量余额 ¥128.50", "LongCat should render token package and API balance as two billing meters")
require(localizedLongCatTokenPack.quotaWindowDetails.count == 2, "LongCat should keep token package and API balance under one account row")
require(localizedLongCatTokenPack.quotaWindowDetails[0].remainingText == "1250000 / 5000000 tokens", "LongCat Token Pack row should preserve remaining over total tokens")
require(localizedLongCatTokenPack.quotaWindowDetails[0].detailValueText == "1250000 / 5000000 个 token", "LongCat Token Pack detail row should localize token units in Simplified Chinese")
require(localizedLongCatTokenPack.quotaWindowDetails[1].percentText == "¥128.50", "LongCat API pay-as-you-go row should show money instead of a fake percentage")
require(localizedLongCatTokenPack.quotaWindowDetails[1].detailValueText == "余额¥128.50", "LongCat API pay-as-you-go detail row should use compact RMB symbols in Simplified Chinese")
require(localizedLongCatTokenPack.remainingBadgeText == "25%", "LongCat badges should use the token package percentage when a token package exists")
require(abs((localizedLongCatTokenPack.quotaPresentation.percentRemaining ?? 0) - 0.25) < 0.001, "LongCat should expose a real remaining percentage from the token package")
require(localizedLongCatTokenPack.planEndSummary == L10n.format(.planEndsDate, L10n.shortDateTime(localizedLongCatPackageEnd, includesYear: true)), "LongCat should expose token package validity as plan expiry")
let localizedLongCatTokenPackStats = ProviderStats(provider: .longcat, keys: [localizedLongCatTokenPack])
require(localizedLongCatTokenPackStats.totalRemainingDisplayText == "Token 资源包 25%", "LongCat provider overview should use the token package percentage as the key quota")
require(localizedLongCatTokenPackStats.totalLimitDisplayText == "Token 资源包 25%", "LongCat provider overview should not invent a monthly window for token package quota")
require(localizedLongCatTokenPackStats.criticalTimeDisplayText == localizedLongCatTokenPack.planEndSummary, "LongCat provider overview should show the package expiry as the key time")
let deepSeekMoneyStats = ProviderStats(provider: .deepseek, keys: [localizedDeepSeekMoney])
require(deepSeekMoneyStats.totalLimitDisplayText == "", "DeepSeek balance provider overview should not show a no-reset-cycle placeholder")
require(deepSeekMoneyStats.criticalTimeDisplayText == "", "DeepSeek balance provider critical time should stay blank when there is no reset or expiry")
let localizedBochaBalance = APIKey(name: "BOCHA_API_KEY", key: "bocha", provider: .bocha, remaining: 1400, limit: 1400, quotaLabel: "CNY 14.00 balance")
require(localizedBochaBalance.quotaDisplayText == "余额¥14.00", "Bocha money balance labels should use compact RMB symbols, not credits or verbose RMB copy")
require(localizedBochaBalance.remainingBadgeText == "¥14.00", "Bocha money balance badge should show currency amount, not 100%")
let localizedWeChatMoney = APIKey(name: "WECHAT_API_KEY", key: "wechat", provider: .wxmp, remaining: 16180, limit: 16180, quotaLabel: "CNY 161.80 available")
require(localizedWeChatMoney.quotaDisplayText == "可用¥161.80", "WeChat Search money balance labels should use compact RMB symbols, not credits or verbose RMB copy")
require(localizedWeChatMoney.remainingBadgeText == "¥161.80", "WeChat Search money balance badge should show currency amount, not 100%")
require(L10n.localizedQuotaLabel("Querit account endpoint returned monthly request quota.", language: .simplifiedChinese) == "Querit 账户接口返回了月度已用请求，但没有返回套餐上限。", "Persisted legacy Querit quota diagnostics should render as usage-only in Simplified Chinese")
require(L10n.localizedQuotaLabel("Querit account endpoint returned monthly usage, but no plan quota limit.", language: .simplifiedChinese) == "Querit 账户接口返回了月度已用请求，但没有返回套餐上限。", "Querit usage-only diagnostics should localize centrally")
let moneyStats = ProviderStats(provider: .bocha, keys: [localizedBochaBalance])
require(moneyStats.totalRemainingDisplayText == "¥14.00", "Money-balance provider overview should show RMB amount instead of cents")
require(moneyStats.totalLimitDisplayText == "", "Money-balance provider overview should leave reset-cycle columns blank instead of showing no-reset-cycle copy")
require(moneyStats.criticalTimeDisplayText == "", "Money-balance provider critical time should stay blank when there is no reset or expiry")
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
let generatedLongCatTokenPackAPIKey = APIKey(name: "LONGCAT_TOKEN_PACK_API_KEY", key: "sk-longcat-token-pack-redacted", provider: .longcat)
require(generatedLongCatTokenPackAPIKey.isStoredAPIKeyOnlyCredential, "LongCat Token Pack API keys should be stored separately from web login authorization")
require(generatedLongCatTokenPackAPIKey.managementDisplayName == "API 密钥", "LongCat Token Pack API-key-only records should show the API key label")
require(generatedLongCatTokenPackAPIKey.copyableCredentialValue == "sk-longcat-token-pack-redacted", "LongCat Token Pack API-key-only records should be copyable")
let generatedLongCatPaygoAPIKey = APIKey(name: "LONGCAT_PAYGO_API_KEY", key: "sk-longcat-paygo-redacted", provider: .longcat)
require(generatedLongCatPaygoAPIKey.isStoredAPIKeyOnlyCredential, "LongCat Pay-as-you-go API keys should be stored separately from web login authorization")
require(generatedLongCatPaygoAPIKey.managementDisplayName == "API 密钥", "LongCat Pay-as-you-go API-key-only records should show the API key label")
require(generatedLongCatPaygoAPIKey.copyableCredentialValue == "sk-longcat-paygo-redacted", "LongCat Pay-as-you-go API-key-only records should be copyable")
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
let localizedResetDate = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2027, month: 6, day: 28, hour: 17, minute: 48, second: 58))!
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
let duplicateKimiWindow = QuotaWindowText(name: "5h", percentText: "98%", resetAt: localizedResetDate, remainingText: "98 / 100")
require(duplicateKimiWindow.detailValueText?.contains("98 / 100") == false, "Kimi percentage-scale quota details should not repeat the same 98/100 payload after the 98% value")
let scaleAwareKimiWindow = QuotaWindowText(name: "month", percentText: "30%", resetAt: localizedResetDate, remainingText: "3000 / 10000")
require(scaleAwareKimiWindow.detailValueText?.contains("3000 / 10000") == true, "Kimi subscription-balance details should keep absolute remaining/total credits when they add scale beyond the percentage")
let expiredClaudeFiveHourReset = Date().addingTimeInterval(-60 * 60)
let futureClaudeWeeklyReset = Date().addingTimeInterval(60 * 60)
let staleClaudeWindowResetKey = APIKey(
    name: "CLAUDE_SUBSCRIPTION_SESSION",
    key: "cookie",
    provider: .claudeSubscription,
    resetAt: expiredClaudeFiveHourReset,
    quotaText: LocalizedTextDescriptor.quotaWindows([
        QuotaWindowText(name: "5h", percentText: "0%", resetAt: expiredClaudeFiveHourReset),
        QuotaWindowText(name: "week", percentText: "90%", resetAt: futureClaudeWeeklyReset)
    ])
)
let staleClaudeWindowDetails = staleClaudeWindowResetKey.quotaWindowDetails
require(staleClaudeWindowDetails.first(where: { $0.name == "5h" })?.resetAt == nil, "Claude expired five-hour reset should not keep showing a past reset time")
require(staleClaudeWindowDetails.first(where: { $0.name == "week" })?.resetAt != nil, "Claude future weekly reset should remain visible")
require(staleClaudeWindowResetKey.visibleQuotaResetSummary == "", "Claude expired top-level reset should not reappear above multi-window quota rows")
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
let disabledProviderStat = ProviderStats(provider: .brave, keys: [disabledKey])
require(disabledProviderStat.sortedMonitoringKeysByCurrentQuota.isEmpty, "Quota monitoring should hide providers when all monitoring credentials are disabled")
require(!disabledProviderStat.hasActiveMonitoringCredentials, "Quota overview should treat all-disabled provider credentials as hidden from monitoring")
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
let fastConsumption = QuotaConsumptionSpeedSummary.speedSummary(
    for: trendKey,
    snapshots: [
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-2 * 24 * 60 * 60), outcome: .success, remaining: 900, limit: 1000, resetAt: resetDateB, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200),
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 500, limit: 1000, resetAt: resetDateB, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200)
    ],
    now: trendNow,
    language: .english
)
require(fastConsumption.shouldRender, "P6 consumption-speed hints should render when current usage pace will soon cross low-quota threshold")
require(fastConsumption.periodName == nil, "Fixed-quota speed hints should not invent a quota-window period")
require(fastConsumption.projectedDaysToLowQuota != nil && fastConsumption.projectedDaysToLowQuota! < 2, "P6 speed hints should estimate days until low quota")
require(fastConsumption.hintText == "Fast use", "P6 speed hints should use a compact localized label")
let stableConsumptionSpeed = QuotaConsumptionSpeedSummary.speedSummary(
    for: trendKey,
    snapshots: [
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-2 * 24 * 60 * 60), outcome: .success, remaining: 900, limit: 1000, resetAt: resetDateB, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200),
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 870, limit: 1000, resetAt: resetDateB, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200)
    ],
    now: trendNow,
    language: .english
)
require(!stableConsumptionSpeed.shouldRender, "P6 consumption-speed hints should stay hidden for slow ordinary usage")
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
let deepseekRefreshHistoryKeyID = UUID(uuidString: "16161616-1616-1616-1616-161616161616")!
let deepseekRefreshHistoryKey = APIKey(
    id: deepseekRefreshHistoryKeyID,
    name: "DEEPSEEK_REFRESH_HISTORY",
    key: "deepseek-refresh-history",
    provider: .deepseek,
    remaining: 10261,
    limit: nil
)
let deepseekRefreshHistoryItems = QuotaRefreshHistoryItem.items(
    for: deepseekRefreshHistoryKey,
    snapshots: [
        QuotaSnapshot(keyID: deepseekRefreshHistoryKeyID, provider: .deepseek, credentialName: "DEEPSEEK_REFRESH_HISTORY", recordedAt: trendNow.addingTimeInterval(-5 * 60 * 60), outcome: .success, remaining: 263, limit: nil, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "CNY 2.63 available", httpStatus: 200),
        QuotaSnapshot(keyID: deepseekRefreshHistoryKeyID, provider: .deepseek, credentialName: "DEEPSEEK_REFRESH_HISTORY", recordedAt: trendNow.addingTimeInterval(-4 * 60 * 60), outcome: .success, remaining: 10262, limit: nil, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "CNY 102.62 available", httpStatus: 200),
        QuotaSnapshot(keyID: deepseekRefreshHistoryKeyID, provider: .deepseek, credentialName: "DEEPSEEK_REFRESH_HISTORY", recordedAt: trendNow.addingTimeInterval(-3 * 60 * 60), outcome: .success, remaining: 10261, limit: nil, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "CNY 102.61 available", httpStatus: 200),
        QuotaSnapshot(keyID: deepseekRefreshHistoryKeyID, provider: .deepseek, credentialName: "DEEPSEEK_REFRESH_HISTORY", recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), outcome: .success, remaining: 10261, limit: nil, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "CNY 102.61 available", httpStatus: 200),
        QuotaSnapshot(keyID: deepseekRefreshHistoryKeyID, provider: .deepseek, credentialName: "DEEPSEEK_REFRESH_HISTORY", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 10261, limit: nil, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "CNY 102.61 available", httpStatus: 200)
    ],
    limit: 4,
    now: trendNow,
    language: .english
)
require(deepseekRefreshHistoryItems.map { $0.kind } == [.noChange, .consumed, .recovered], "Refresh history should collapse repeated no-change refreshes while keeping top-up and tiny-spend events")
require(deepseekRefreshHistoryItems[0].repeatCount == 2, "Refresh history should record how many consecutive unchanged refreshes were collapsed")
require(deepseekRefreshHistoryItems[0].primaryText == "Updated · no change", "Refresh history should label collapsed unchanged refreshes clearly")
require(deepseekRefreshHistoryItems[1].deltaText == "-CNY 0.01", "Refresh history should show DeepSeek money-balance consumption in currency")
require(deepseekRefreshHistoryItems[1].valueText == "CNY 102.61", "Refresh history should keep the refreshed balance value beside the event")
require(deepseekRefreshHistoryItems[2].primaryText == "Reset", "Refresh history should treat large balance increases as recovery instead of consumption")

let failedRefreshHistoryItems = QuotaRefreshHistoryItem.items(
    for: trendKey,
    snapshots: [
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-10 * 60), outcome: .success, remaining: 700, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200),
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-5 * 60), outcome: .failed, remaining: 700, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 500)
    ],
    now: trendNow,
    language: .english
)
require(failedRefreshHistoryItems.first?.kind == .failed, "Refresh history should retain failed refresh attempts")
require(failedRefreshHistoryItems.first?.primaryText == "Refresh failed", "Refresh history should label failed refresh attempts")
require(failedRefreshHistoryItems.first?.httpStatusText == "HTTP 500", "Refresh history should expose the failed refresh HTTP status")

let skippedRefreshHistoryItems = QuotaRefreshHistoryItem.items(
    for: trendKey,
    snapshots: [
        QuotaSnapshot(keyID: trendKeyID, provider: .tavily, credentialName: "TAVILY_TREND", recordedAt: trendNow.addingTimeInterval(-5 * 60), outcome: .skipped, remaining: 700, limit: 1000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "Manual refresh only", httpStatus: nil)
    ],
    now: trendNow,
    language: .english
)
require(skippedRefreshHistoryItems.first?.kind == .skipped, "Refresh history should include automatic refresh skips")
require(skippedRefreshHistoryItems.first?.primaryText == "Skipped", "Refresh history should label skipped refresh attempts")
require(skippedRefreshHistoryItems.first?.httpStatusText == "Not requested", "Refresh history should explain that skipped refreshes did not make an HTTP request")
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
let deepseekRecoveredAfterStableRefresh = QuotaActivitySummary.activitySummary(
    for: deepseekTrendKey,
    snapshots: [
        QuotaSnapshot(keyID: deepseekTrendKeyID, provider: .deepseek, credentialName: "DEEPSEEK_API_KEY", recordedAt: trendNow.addingTimeInterval(-3 * 60 * 60), outcome: .success, remaining: 850, limit: nil, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "CNY 8.50 available", httpStatus: 200),
        QuotaSnapshot(keyID: deepseekTrendKeyID, provider: .deepseek, credentialName: "DEEPSEEK_API_KEY", recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), outcome: .success, remaining: 1250, limit: nil, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "CNY 12.50 available", httpStatus: 200),
        QuotaSnapshot(keyID: deepseekTrendKeyID, provider: .deepseek, credentialName: "DEEPSEEK_API_KEY", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 1250, limit: nil, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "CNY 12.50 available", httpStatus: 200)
    ],
    now: trendNow,
    language: .english
)
require(deepseekRecoveredAfterStableRefresh.kind == .recovered, "DeepSeek balance recovery should remain visible after later unchanged refreshes")
require(deepseekRecoveredAfterStableRefresh.shouldRender, "Recovered DeepSeek balances should still render as recent activity after stable refreshes")
let deepseekLargeTopUpAfterTinySpend = QuotaActivitySummary.activitySummary(
    for: deepseekTrendKey,
    snapshots: [
        QuotaSnapshot(keyID: deepseekTrendKeyID, provider: .deepseek, credentialName: "DEEPSEEK_API_KEY", recordedAt: trendNow.addingTimeInterval(-4 * 60 * 60), outcome: .success, remaining: 263, limit: nil, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "CNY 2.63 available", httpStatus: 200),
        QuotaSnapshot(keyID: deepseekTrendKeyID, provider: .deepseek, credentialName: "DEEPSEEK_API_KEY", recordedAt: trendNow.addingTimeInterval(-3 * 60 * 60), outcome: .success, remaining: 10262, limit: nil, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "CNY 102.62 available", httpStatus: 200),
        QuotaSnapshot(keyID: deepseekTrendKeyID, provider: .deepseek, credentialName: "DEEPSEEK_API_KEY", recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), outcome: .success, remaining: 10261, limit: nil, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "CNY 102.61 available", httpStatus: 200),
        QuotaSnapshot(keyID: deepseekTrendKeyID, provider: .deepseek, credentialName: "DEEPSEEK_API_KEY", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 10261, limit: nil, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "CNY 102.61 available", httpStatus: 200)
    ],
    now: trendNow,
    language: .english
)
require(deepseekLargeTopUpAfterTinySpend.kind == .recovered, "DeepSeek top-ups should stay visible as recovery when only a tiny post-top-up spend happened")
require(deepseekLargeTopUpAfterTinySpend.deltaText == nil, "DeepSeek top-ups should not be overwritten by a tiny post-top-up money delta")
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
let codexFastWeeklySpeed = QuotaConsumptionSpeedSummary.speedSummary(
    for: codexTrendKey,
    snapshots: [
        QuotaSnapshot(keyID: codexTrendKeyID, provider: .codexSubscription, credentialName: "CODEX_SUBSCRIPTION_SESSION", recordedAt: trendNow.addingTimeInterval(-2 * 24 * 60 * 60), outcome: .success, remaining: 9000, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "week 85%", httpStatus: 200, quotaWindows: [
            QuotaWindowSnapshot(name: "week", remainingPercent: 85, resetAt: resetDateB)
        ]),
        QuotaSnapshot(keyID: codexTrendKeyID, provider: .codexSubscription, credentialName: "CODEX_SUBSCRIPTION_SESSION", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 5000, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "week 50%", httpStatus: 200, quotaWindows: [
            QuotaWindowSnapshot(name: "week", remainingPercent: 50, resetAt: resetDateB)
        ])
    ],
    now: trendNow,
    language: .english
)
require(codexFastWeeklySpeed.shouldRender, "P6 speed hints should work for subscription quota windows")
require(codexFastWeeklySpeed.periodName == "week", "P6 speed hints should preserve the quota-window period they describe")
let codexResetSpeed = QuotaConsumptionSpeedSummary.speedSummary(
    for: codexTrendKey,
    snapshots: [
        QuotaSnapshot(keyID: codexTrendKeyID, provider: .codexSubscription, credentialName: "CODEX_SUBSCRIPTION_SESSION", recordedAt: trendNow.addingTimeInterval(-2 * 60 * 60), outcome: .success, remaining: 9100, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "week 91%", httpStatus: 200, quotaWindows: [
            QuotaWindowSnapshot(name: "week", remainingPercent: 91, resetAt: trendNow.addingTimeInterval(24 * 60 * 60))
        ]),
        QuotaSnapshot(keyID: codexTrendKeyID, provider: .codexSubscription, credentialName: "CODEX_SUBSCRIPTION_SESSION", recordedAt: trendNow.addingTimeInterval(-1 * 60 * 60), outcome: .success, remaining: 5000, limit: 10000, resetAt: nil, planEndsAt: nil, planDisplayName: nil, quotaLabel: "week 50%", httpStatus: 200, quotaWindows: [
            QuotaWindowSnapshot(name: "week", remainingPercent: 50, resetAt: trendNow.addingTimeInterval(8 * 24 * 60 * 60))
        ])
    ],
    now: trendNow,
    language: .english
)
require(!codexResetSpeed.shouldRender, "P6 speed hints should not report fast consumption across quota reset boundaries")
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
require(volc.fields["xWebId"] == "web-id-redacted", "Volcengine cURL parse should normalize x-web-id to the replay field name")
require(volc.fields["webID"] == nil, "Volcengine cURL parse should not keep the legacy unread webID alias")
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
require(L10n.t(.appearanceMode, language: .english) == "Color Scheme", "English theme-mode label should be explicit")
require(L10n.t(.appearanceModeSystem, language: .english) == "Follow System", "English theme mode should avoid the bare System label")
require(L10n.t(.appearanceModeLight, language: .english) == "Light Mode", "English theme mode should avoid the bare Light label")
require(L10n.t(.appearanceModeDark, language: .english) == "Dark Mode", "English theme mode should avoid the bare Dark label")
require(L10n.t(.appearanceMode, language: .simplifiedChinese) == "配色模式", "Chinese theme-mode label should be explicit")
require(L10n.t(.appearanceModeSystem, language: .simplifiedChinese) == "跟随系统", "Chinese theme mode should include system")
require(L10n.t(.appearanceModeLight, language: .simplifiedChinese) == "浅色模式", "Chinese theme mode should avoid the bare light label")
require(L10n.t(.appearanceModeDark, language: .simplifiedChinese) == "深色模式", "Chinese theme mode should avoid the bare dark label")
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
require(AppThemeModeOption.allCases.map(\.rawValue) == ["system", "light", "dark"], "Theme mode should expose system, light, and dark in that order")
let appearanceDefaults = UserDefaults(suiteName: "QuotaRadarAppearanceTests.\(UUID().uuidString)")!
appearanceDefaults.removePersistentDomain(forName: appearanceDefaults.dictionaryRepresentation().description)
let defaultAppearanceStore = AppAppearanceStore(defaults: appearanceDefaults)
require(defaultAppearanceStore.appearanceMode == .system, "Theme mode should default to following system appearance")
defaultAppearanceStore.appearanceMode = .dark
require(appearanceDefaults.string(forKey: "appearanceMode") == "dark", "Theme mode changes should persist to UserDefaults")
appearanceDefaults.set("light", forKey: "appearanceMode")
let savedAppearanceStore = AppAppearanceStore(defaults: appearanceDefaults)
require(savedAppearanceStore.appearanceMode == .light, "Theme mode should restore the saved UserDefaults value")
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

let notificationNow = Date(timeIntervalSince1970: 1_800_000_000)
let recoveredKeyID = UUID(uuidString: "71717171-7171-7171-7171-717171717171")!
let recoveredKey = APIKey(
    id: recoveredKeyID,
    name: "TAVILY_RECOVERED",
    key: "tvly-recovered",
    provider: .tavily,
    remaining: 1000,
    limit: 1000
)
let recoveryEvents = QuotaThresholdNotificationService.events(
    for: [recoveredKey],
    snapshots: [
        QuotaSnapshot(keyID: recoveredKeyID, provider: .tavily, credentialName: "TAVILY_RECOVERED", recordedAt: notificationNow.addingTimeInterval(-5 * 60), outcome: .success, remaining: 100, limit: 1000, resetAt: notificationNow.addingTimeInterval(24 * 60 * 60), planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200),
        QuotaSnapshot(keyID: recoveredKeyID, provider: .tavily, credentialName: "TAVILY_RECOVERED", recordedAt: notificationNow.addingTimeInterval(-30), outcome: .success, remaining: 1000, limit: 1000, resetAt: notificationNow.addingTimeInterval(8 * 24 * 60 * 60), planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200)
    ],
    now: notificationNow
)
require(recoveryEvents.map(\.kind) == [.quotaRecovered], "P6 recovery notifications should fire after a recent reset or top-up recovery")
require(recoveryEvents.first?.title == "Quota recovered", "P6 recovery notification title should be localized")
let staleRecoveryEvents = QuotaThresholdNotificationService.events(
    for: [recoveredKey],
    snapshots: [
        QuotaSnapshot(keyID: recoveredKeyID, provider: .tavily, credentialName: "TAVILY_RECOVERED", recordedAt: notificationNow.addingTimeInterval(-2 * 60 * 60), outcome: .success, remaining: 100, limit: 1000, resetAt: notificationNow.addingTimeInterval(24 * 60 * 60), planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200),
        QuotaSnapshot(keyID: recoveredKeyID, provider: .tavily, credentialName: "TAVILY_RECOVERED", recordedAt: notificationNow.addingTimeInterval(-90 * 60), outcome: .success, remaining: 1000, limit: 1000, resetAt: notificationNow.addingTimeInterval(8 * 24 * 60 * 60), planEndsAt: nil, planDisplayName: nil, quotaLabel: nil, httpStatus: 200)
    ],
    now: notificationNow
)
require(staleRecoveryEvents.isEmpty, "P6 recovery notifications should not fire for stale historical recoveries")

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

let scopedDefaults = UserDefaults(suiteName: "QuotaRadarScopedThresholdNotificationTests.\(UUID().uuidString)")!
let scopedStore = QuotaThresholdNotificationStore(defaults: scopedDefaults)
let scopedEvents = Array(events.prefix(2))
scopedStore.markDelivered(scopedEvents, retainingActive: scopedEvents)
scopedStore.clearResolvedEvents(retainingActive: [], affectedKeyIDs: [scopedEvents[0].keyID])
require(scopedStore.freshEvents(from: scopedEvents) == [scopedEvents[0]], "Scoped clearing should resolve only accepted credential IDs and preserve unaffected delivery state")
require(
    QuotaThresholdNotificationService.affectedEvents(
        from: scopedEvents,
        affectedKeyIDs: [scopedEvents[1].keyID]
    ) == [scopedEvents[1]],
    "Notification delivery should select only accepted refresh credential IDs"
)

SWIFT

swiftc QuotaRadar/Models/AppLanguage.swift QuotaRadar/Models/APIKey.swift QuotaRadar/Models/QuotaHistory.swift QuotaRadar/Services/QuotaNotificationService.swift "$TMP_DIR/main.swift" -o "$TMP_DIR/threshold-notification-test"
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
let defaultAutomaticCredentialDelays = DashboardCredentialCapturePolicy.automaticRetryDelays(for: .claudeSubscription)
let volcengineAutomaticCredentialDelays = DashboardCredentialCapturePolicy.automaticRetryDelays(for: .volcengineCodingPlan)
require(defaultAutomaticCredentialDelays == [0.35, 1.0, 2.0], "Default dashboard credential auto-capture retry timing should stay compact")
require(volcengineAutomaticCredentialDelays.count > defaultAutomaticCredentialDelays.count, "Volcengine dashboard credential auto-capture should keep watching longer during first-login SSO cookie settling")
require(volcengineAutomaticCredentialDelays.last ?? 0 >= 7.0, "Volcengine dashboard credential auto-capture should wait long enough for first-login cookies to settle")
require(DashboardCredentialCapturePolicy.nextAutomaticRetryDelay(
    for: .codexSubscription,
    completedRetryCount: defaultAutomaticCredentialDelays.count
) == nil, "Cookie-backed providers should stop automatic polling after the compact retry window")
require(DashboardCredentialCapturePolicy.nextAutomaticRetryDelay(
    for: .kimiSubscription,
    completedRetryCount: defaultAutomaticCredentialDelays.count
) != nil, "Kimi should continue low-frequency capture when login material arrives through WebStorage only")
require(DashboardCredentialCapturePolicy.nextAutomaticRetryDelay(
    for: .longcat,
    completedRetryCount: defaultAutomaticCredentialDelays.count
) != nil, "LongCat should continue low-frequency capture when login material arrives through WebStorage only")
require(DashboardCredentialCapturePolicy.nextAutomaticRetryDelay(
    for: .tencentCloudCodingPlan,
    completedRetryCount: 100
) != nil, "Tencent Cloud should keep passive capture alive while QQ login replaces stale console cookies")
require(DashboardCredentialCapturePolicy.nextAutomaticRetryDelay(
    for: .aliyunCodingPlan,
    completedRetryCount: defaultAutomaticCredentialDelays.count
) == nil, "Aliyun visitor pages should not add indefinite shared capture polling")

let rejectedCapture = DashboardCapturedCredential(
    provider: .codexSubscription,
    cookieHeader: "__search-next-auth=rejected"
)
let unchangedRejectedCapture = DashboardCapturedCredential(
    provider: .codexSubscription,
    cookieHeader: "__search-next-auth=rejected"
)
let refreshedCapture = DashboardCapturedCredential(
    provider: .codexSubscription,
    cookieHeader: "__search-next-auth=refreshed"
)
require(rejectedCapture.captureIdentity == unchangedRejectedCapture.captureIdentity, "Equivalent browser credentials should have the same in-memory capture identity")
require(rejectedCapture.captureIdentity != refreshedCapture.captureIdentity, "Changed browser credentials should have a different in-memory capture identity")

let tencentCaptureWithTrackingA = DashboardCapturedCredential(
    provider: .tencentCloudCodingPlan,
    cookieHeader: "uin=o123; skey=session-redacted; ownerUin=o123; nodesess=tracking-a"
)
let tencentCaptureWithTrackingB = DashboardCapturedCredential(
    provider: .tencentCloudCodingPlan,
    cookieHeader: "uin=o123; skey=session-redacted; ownerUin=o123; nodesess=tracking-b"
)
let tencentCaptureWithNewSession = DashboardCapturedCredential(
    provider: .tencentCloudCodingPlan,
    cookieHeader: "uin=o123; skey=new-session-redacted; ownerUin=o123; nodesess=tracking-b"
)
require(tencentCaptureWithTrackingA.captureIdentity == tencentCaptureWithTrackingB.captureIdentity, "Tencent capture identity should ignore unrelated rotating cookies")
require(tencentCaptureWithTrackingA.captureIdentity != tencentCaptureWithNewSession.captureIdentity, "Tencent capture identity should change when authentication cookies change")

var captureLifecycle = DashboardCredentialCaptureLifecycle(initialResetRequestID: 0)
require(captureLifecycle.automaticEmissionDecision(credentialIdentity: rejectedCapture.captureIdentity) == .emit, "The first ready dashboard credential should be emitted")
require(captureLifecycle.automaticEmissionDecision(credentialIdentity: rejectedCapture.captureIdentity) == .blocked, "A ready credential should not be emitted twice while validation is pending")
require(!captureLifecycle.consumeResetRequest(0), "The initial reset request ID should not re-arm capture")
require(captureLifecycle.consumeResetRequest(1), "A validation failure should consume a new reset request and re-arm capture")
require(captureLifecycle.automaticEmissionDecision(credentialIdentity: unchangedRejectedCapture.captureIdentity) == .unchanged, "Re-armed automatic capture must not immediately revalidate the unchanged rejected credential")
require(DashboardCredentialCapturePolicy.nextAutomaticRetryDelay(
    for: .kimiSubscription,
    completedRetryCount: 100
) != nil, "An unchanged rejected Kimi credential should keep low-frequency WebStorage polling active without validation")
require(DashboardCredentialCapturePolicy.nextAutomaticRetryDelay(
    for: .longcat,
    completedRetryCount: 100
) != nil, "An unchanged rejected LongCat credential should keep low-frequency WebStorage polling active without validation")
require(captureLifecycle.automaticEmissionDecision(credentialIdentity: refreshedCapture.captureIdentity) == .emit, "A changed dashboard credential should be emitted after failed validation re-arms capture")
require(!captureLifecycle.consumeResetRequest(1), "The same reset request ID should not re-arm capture twice")

var validationLifecycle = DashboardReauthValidationLifecycle()
require(validationLifecycle.beginValidation(), "The first automatic dashboard credential should start validation")
require(!validationLifecycle.beginValidation(), "Manual save must not overlap an automatic validation already in flight")
require(validationLifecycle.finishValidation(succeeded: false) == .recapture, "Unauthorized validation should request recapture without persistence")
require(!validationLifecycle.isValidationInFlight, "Failed validation should release the shared in-flight gate")
require(validationLifecycle.beginValidation(), "A fresh manual WebView capture should validate after the failed candidate")
require(validationLifecycle.finishValidation(succeeded: true) == .persist, "Only successful validation should permit credential persistence")
require(!validationLifecycle.isValidationInFlight, "Successful validation should release the shared in-flight gate")
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
require(Provider.anthropicCredits.supportsDashboardReauthentication, "Anthropic Credits should support Claude web-login authorization capture")
require(!Provider.codexAPIUsage.supportsDashboardReauthentication, "Codex API usage should use API keys instead of web-login reauthentication")
require(Provider.codexSubscription.supportsDashboardReauthentication, "Codex subscription should support web-login authorization capture")
require(Provider.kimiSubscription.supportsDashboardReauthentication, "Kimi subscription should support web-login authorization capture")
require(Provider.longcat.supportsDashboardReauthentication, "LongCat should support web-login authorization capture")
require(!Provider.brave.supportsDashboardReauthentication, "Brave should not use dashboard-cookie reauthentication")
let expectedDashboardReauthProviders: Set<Provider> = [
    .querit,
    .xfyunCodingPlan,
    .volcengineCodingPlan,
    .opencodeGo,
    .aliyunCodingPlan,
    .tencentCloudCodingPlan,
    .claudeSubscription,
    .anthropicCredits,
    .codexSubscription,
    .kimiSubscription,
    .longcat
]
let actualDashboardReauthProviders = Set(Provider.allCases.filter(\.supportsDashboardReauthentication))
require(actualDashboardReauthProviders == expectedDashboardReauthProviders, "Dashboard reauthentication provider coverage should stay explicit and complete")
require(DashboardReauthConfig(provider: .opencodeGo)?.cookieDomains == ["opencode.ai"], "OpenCode Go should capture only opencode.ai cookies")
require(DashboardReauthConfig(provider: .xfyunCodingPlan)?.cookieDomains == ["xfyun.cn", "maas.xfyun.cn"], "XFYun should capture maas.xfyun.cn and domain-wide xfyun.cn cookies")
require(DashboardReauthConfig(provider: .xfyunTokenPlan) == nil, "XFYun Token Plan should not expose dashboard-cookie reauthentication")
require(DashboardReauthConfig(provider: .volcengineCodingPlan)?.cookieDomains == ["volcengine.com", "console.volcengine.com"], "Volcengine should capture console.volcengine.com and domain-wide volcengine.com cookies")
require(DashboardReauthConfig(provider: .volcengineTokenPlan) == nil, "Volcengine Token Plan should not expose dashboard-cookie reauthentication")
require(DashboardReauthConfig(provider: .querit)?.cookieDomains == ["querit.ai"], "Querit should capture querit.ai dashboard cookies")
require(DashboardReauthConfig(provider: .aliyunCodingPlan)?.cookieDomains == ["aliyun.com", "bailian.console.aliyun.com"], "Aliyun Coding Plan should capture Alibaba Cloud web login authorization for quota endpoint verification")
require(DashboardReauthConfig(provider: .aliyunCodingPlan)?.loginURL.absoluteString == "https://bailian.console.aliyun.com/?tab=plan#/efm/subscription/coding-plan", "Aliyun Coding Plan reauthentication should open the protected subscription route instead of the public home page")
require(DashboardReauthConfig(provider: .aliyunTokenPlan) == nil, "Aliyun Token Plan should not capture cookies without a verified dashboard quota endpoint")
let aliyunVisitorCredential = DashboardCapturedCredential(
    provider: .aliyunCodingPlan,
    cookieHeader: "_bl_uid=visitor-redacted"
)
require(!DashboardCredentialCapturePolicy.isCredentialReady(
    aliyunVisitorCredential,
    requiredNames: Provider.aliyunCodingPlan.dashboardAuthenticationCookieNames
), "Aliyun visitor cookies must not be accepted as dashboard login authorization")
require(DashboardCredentialCapturePolicy.missingRequiredCredentialNames(
    aliyunVisitorCredential,
    requiredNames: Provider.aliyunCodingPlan.dashboardAuthenticationCookieNames
).contains("login_aliyunid_ticket"), "Aliyun visitor state should keep requiring the real login ticket")
require(Provider.tencentCloudCodingPlan.dashboardAuthenticationCookieNames == ["uin", "skey|p_skey"], "Tencent Cloud dashboard capture should accept p_skey only as an alternative to skey")
require(DashboardReauthConfig(provider: .tencentCloudCodingPlan)?.cookieDomains == ["cloud.tencent.com", "console.cloud.tencent.com"], "Tencent Cloud Coding Plan should capture Tencent Cloud web login authorization for quota endpoint verification")
require(DashboardReauthConfig(provider: .claudeSubscription)?.cookieDomains == ["claude.ai"], "Claude subscription should capture claude.ai web-login authorization")
require(DashboardReauthConfig(provider: .anthropicCredits)?.cookieDomains == ["claude.ai"], "Anthropic Credits should capture the same claude.ai login authorization")
require(DashboardReauthConfig(provider: .codexSubscription)?.cookieDomains == ["chatgpt.com"], "Codex subscription should capture ChatGPT web-login authorization")
require(DashboardReauthConfig(provider: .kimiSubscription)?.cookieDomains == ["kimi.com", "www.kimi.com"], "Kimi subscription should capture kimi.com web-login authorization")
require(DashboardReauthConfig(provider: .longcat)?.cookieDomains == ["longcat.chat", "passport.meituan.com", "i.meituan.com", "passport.mykeeta.com"], "LongCat should capture LongCat and Passport web-login authorization")
require(DashboardReauthConfig(provider: .claudeAPIUsage) == nil, "Claude API usage should not expose dashboard reauthentication")
require(DashboardReauthConfig(provider: .codexAPIUsage) == nil, "Codex API usage should not expose dashboard reauthentication")
require(DashboardReauthConfig(provider: .claudeSubscription)?.requiredCookieNames == ["sessionKey|sessionKeyLC"], "Claude subscription should accept either current sessionKey or sessionKeyLC login cookies")
require(DashboardReauthConfig(provider: .anthropicCredits)?.requiredCookieNames == ["sessionKey|sessionKeyLC"], "Anthropic Credits should accept either current Claude session cookie")
let claudeRequiredCookies = Provider.claudeSubscription.dashboardAuthenticationCookieNames
require(DashboardCookieBuilder.containsRequiredCookie(
    inCookieHeader: "sessionKeyLC=claude-session",
    requiredNames: claudeRequiredCookies
), "Claude subscription should save login authorization when WebKit only exposes sessionKeyLC")
require(DashboardCookieBuilder.containsRequiredCookie(
    inCookieHeader: "sessionKey=claude-session",
    requiredNames: claudeRequiredCookies
), "Claude subscription should keep accepting the original sessionKey cookie")
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
let longCatCapturedFromStorage = DashboardCapturedCredential(
    provider: .longcat,
    cookieHeader: "locale=zh",
    webStorageFields: [
        "token": "Bearer longcat-storage-token",
        "userTicket": "ticket-redacted",
        "uuid": "uuid-redacted",
        "passport_uuid": "passport-redacted",
        "lt": "lt-redacted"
    ]
)
require(longCatCapturedFromStorage.fields["token"] == "longcat-storage-token", "LongCat reauthentication should normalize WebStorage token without the Bearer prefix")
require(longCatCapturedFromStorage.fields["userTicket"] == "ticket-redacted", "LongCat reauthentication should preserve userTicket from WebStorage")
require(longCatCapturedFromStorage.fields["uuid"] == "uuid-redacted", "LongCat reauthentication should preserve uuid from WebStorage")
require(longCatCapturedFromStorage.fields["passport_uuid"] == "passport-redacted", "LongCat reauthentication should preserve passport_uuid from WebStorage")
require(longCatCapturedFromStorage.fields["lt"] == "lt-redacted", "LongCat reauthentication should preserve lt from WebStorage")
require(DashboardCredentialCapturePolicy.isCredentialReady(
    longCatCapturedFromStorage,
    requiredNames: Provider.longcat.dashboardAuthenticationCookieNames
), "LongCat reauthentication should accept a complete WebStorage login material set when auth cookies are not exposed")
let partialLongCatStorageCredential = DashboardCapturedCredential(
    provider: .longcat,
    cookieHeader: "locale=zh",
    webStorageFields: [
        "token": "longcat-storage-token"
    ]
)
require(!DashboardCredentialCapturePolicy.isCredentialReady(
    partialLongCatStorageCredential,
    requiredNames: Provider.longcat.dashboardAuthenticationCookieNames
), "LongCat reauthentication should reject token-only WebStorage login material")
require(longCatCapturedFromStorage.reauthenticatedSecret(existingSecret: nil).contains("\"userTicket\""), "LongCat reauthentication should save storage-derived token metadata as JSON")
require(longCatCapturedFromStorage.reauthenticatedSecret(existingSecret: nil).contains("\"passport_uuid\""), "LongCat reauthentication should save passport UUID metadata as JSON")
let longCatCapturedFromFrontendLoginMaterial = DashboardCapturedCredential(
    provider: .longcat,
    cookieHeader: "locale=zh",
    webStorageFields: [
        "token": "longcat-storage-token",
        "passport_uuid": "passport-redacted"
    ]
)
require(DashboardCredentialCapturePolicy.isCredentialReady(
    longCatCapturedFromFrontendLoginMaterial,
    requiredNames: Provider.longcat.dashboardAuthenticationCookieNames
), "LongCat first-save capture should accept the login material used by the public frontend without requiring non-persistent userTicket or lt fields")
require(longCatCapturedFromFrontendLoginMaterial.reauthenticatedSecret(existingSecret: nil).contains("\"token\""), "LongCat frontend login material should save token metadata as JSON")
require(longCatCapturedFromFrontendLoginMaterial.reauthenticatedSecret(existingSecret: nil).contains("\"passport_uuid\""), "LongCat frontend login material should save passport UUID metadata as JSON")
let longCatCapturedFromUserCurrentProbe = DashboardCapturedCredential(
    provider: .longcat,
    cookieHeader: "locale=zh",
    webStorageFields: [
        "longcatUserCurrentToken": "longcat-user-current-token",
        "longcatLoginStatus": "1",
        "passport_uuid": "passport-redacted"
    ]
)
require(longCatCapturedFromUserCurrentProbe.fields["token"] == "longcat-user-current-token", "LongCat reauthentication should normalize token returned by same-origin user-current")
require(longCatCapturedFromUserCurrentProbe.fields["longcatLoginStatus"] == "1", "LongCat reauthentication should preserve sanitized same-origin login status")
require(DashboardCredentialCapturePolicy.isCredentialReady(
    longCatCapturedFromUserCurrentProbe,
    requiredNames: Provider.longcat.dashboardAuthenticationCookieNames
), "LongCat first-save capture should accept same-origin user-current login material")
require(longCatCapturedFromUserCurrentProbe.reauthenticatedSecret(existingSecret: nil).contains("\"longcatLoginStatus\""), "LongCat same-origin login status should be persisted as sanitized metadata")
let longCatLocalizedMissingNames = DashboardCredentialDisplayNames.missingRequiredNames(
    ["longcat_session", "token", "uuid|passport_uuid"],
    provider: .longcat,
    language: .simplifiedChinese
)
require(longCatLocalizedMissingNames == ["LongCat 登录授权", "LongCat 浏览器身份"], "LongCat missing-login diagnostics should group raw token and UUID requirements into localized user-facing labels")
let longCatLocalizedCapturedNames = DashboardCredentialDisplayNames.capturedNames(
    for: longCatCapturedFromUserCurrentProbe,
    language: .simplifiedChinese
)
require(longCatLocalizedCapturedNames == ["LongCat 登录状态", "LongCat 登录授权", "LongCat 浏览器身份"], "LongCat captured-login diagnostics should show localized grouped labels in a stable order")
let longCatRawCapturedCopy = longCatLocalizedCapturedNames.joined(separator: ", ")
require(!longCatRawCapturedCopy.contains("token"), "LongCat captured-login diagnostics should not expose raw token field names")
require(!longCatRawCapturedCopy.contains("passport_uuid"), "LongCat captured-login diagnostics should not expose raw passport UUID field names")
require(!longCatRawCapturedCopy.contains("longcatLoginStatus"), "LongCat captured-login diagnostics should not expose raw login status field names")
for language in AppLanguage.allCases {
    require(!L10n.t(.longCatLoginAuthorization, language: language).isEmpty, "LongCat login authorization display name should be localized for \(language.rawValue)")
    require(!L10n.t(.longCatBrowserIdentity, language: language).isEmpty, "LongCat browser identity display name should be localized for \(language.rawValue)")
    require(!L10n.t(.longCatAccountIdentity, language: language).isEmpty, "LongCat account identity display name should be localized for \(language.rawValue)")
}
let longCatCapturedFromVerifiedPageCookie = DashboardCapturedCredential(
    provider: .longcat,
    cookieHeader: "unknown_login_cookie=redacted",
    webStorageFields: [
        "longcatLoginStatus": "1"
    ]
)
require(DashboardCredentialCapturePolicy.isCredentialReady(
    longCatCapturedFromVerifiedPageCookie,
    requiredNames: Provider.longcat.dashboardAuthenticationCookieNames
), "LongCat first-save capture should trust same-origin loginStatus when the browser has a working login cookie with an unknown or HttpOnly-backed name")
require(
    DashboardCredentialDisplayNames.capturedNames(for: longCatCapturedFromVerifiedPageCookie, language: .simplifiedChinese)
        == ["LongCat 登录状态", "LongCat 登录授权"],
    "LongCat captured-login diagnostics should label unknown login cookies without exposing raw cookie names"
)
let longCatCapturedFromMisspelledPassportStorage = DashboardCapturedCredential(
    provider: .longcat,
    cookieHeader: "locale=zh",
    webStorageFields: [
        "token": "longcat-storage-token",
        "userTicket": "ticket-redacted",
        "uuid": "uuid-redacted",
        "passpoart_uuid": "passport-redacted",
        "lt": "lt-redacted"
    ]
)
require(longCatCapturedFromMisspelledPassportStorage.fields["passport_uuid"] == "passport-redacted", "LongCat reauthentication should normalize the observed passpoart_uuid WebStorage typo")
require(DashboardCredentialCapturePolicy.isCredentialReady(
    longCatCapturedFromMisspelledPassportStorage,
    requiredNames: Provider.longcat.dashboardAuthenticationCookieNames
), "LongCat first-save capture should accept the observed passpoart_uuid WebStorage typo")

struct FirstSaveDashboardProviderScenario {
    let provider: Provider
    let cookies: [HTTPCookie]
    let webStorageFields: [String: String]
    let expectedSecretFragments: [String]
}

func firstSaveCookie(_ name: String, value: String = "v", domain: String) -> HTTPCookie {
    HTTPCookie(properties: [
        .domain: domain,
        .path: "/",
        .name: name,
        .value: value,
        .secure: "TRUE"
    ])!
}

let firstSaveDashboardProviderScenarios: [FirstSaveDashboardProviderScenario] = [
    FirstSaveDashboardProviderScenario(
        provider: .claudeSubscription,
        cookies: [
            firstSaveCookie("sessionKeyLC", value: "claude-session", domain: ".claude.ai")
        ],
        webStorageFields: [:],
        expectedSecretFragments: ["sessionKeyLC=claude-session"]
    ),
    FirstSaveDashboardProviderScenario(
        provider: .anthropicCredits,
        cookies: [
            firstSaveCookie("sessionKey", value: "anthropic-session", domain: ".claude.ai")
        ],
        webStorageFields: [:],
        expectedSecretFragments: ["sessionKey=anthropic-session"]
    ),
    FirstSaveDashboardProviderScenario(
        provider: .codexSubscription,
        cookies: [
            firstSaveCookie("__search-next-auth", value: "chatgpt-session", domain: ".chatgpt.com")
        ],
        webStorageFields: [:],
        expectedSecretFragments: ["__search-next-auth=chatgpt-session"]
    ),
    FirstSaveDashboardProviderScenario(
        provider: .volcengineCodingPlan,
        cookies: [
            firstSaveCookie("AccountID", value: "account-redacted", domain: ".volcengine.com"),
            firstSaveCookie("csrfToken", value: "csrf-redacted", domain: "console.volcengine.com"),
            firstSaveCookie("digest", value: "digest-redacted", domain: ".volcengine.com")
        ],
        webStorageFields: [:],
        expectedSecretFragments: ["AccountID=account-redacted", "csrfToken=csrf-redacted", "digest=digest-redacted"]
    ),
    FirstSaveDashboardProviderScenario(
        provider: .xfyunCodingPlan,
        cookies: [
            firstSaveCookie("account_id", value: "account-redacted", domain: ".xfyun.cn"),
            firstSaveCookie("atp-auth-token", value: "atp-redacted", domain: "maas.xfyun.cn"),
            firstSaveCookie("ssoSessionId", value: "sso-redacted", domain: ".xfyun.cn"),
            firstSaveCookie("tenantToken", value: "tenant-redacted", domain: "maas.xfyun.cn")
        ],
        webStorageFields: [:],
        expectedSecretFragments: ["account_id=account-redacted", "atp-auth-token=atp-redacted", "ssoSessionId=sso-redacted", "tenantToken=tenant-redacted"]
    ),
    FirstSaveDashboardProviderScenario(
        provider: .aliyunCodingPlan,
        cookies: [
            firstSaveCookie("aliyun_lang", value: "zh", domain: ".aliyun.com"),
            firstSaveCookie("cna", value: "device-redacted", domain: ".aliyun.com"),
            firstSaveCookie("login_aliyunid_ticket", value: "aliyun-ticket", domain: "bailian.console.aliyun.com")
        ],
        webStorageFields: [:],
        expectedSecretFragments: ["aliyun_lang=zh", "cna=device-redacted", "login_aliyunid_ticket=aliyun-ticket"]
    ),
    FirstSaveDashboardProviderScenario(
        provider: .tencentCloudCodingPlan,
        cookies: [
            firstSaveCookie("skey", value: "tencent-skey", domain: ".cloud.tencent.com"),
            firstSaveCookie("uin", value: "tencent-uin", domain: "console.cloud.tencent.com")
        ],
        webStorageFields: [:],
        expectedSecretFragments: ["skey=tencent-skey", "uin=tencent-uin"]
    ),
    FirstSaveDashboardProviderScenario(
        provider: .kimiSubscription,
        cookies: [
            firstSaveCookie("locale_mode", value: "implicit", domain: ".kimi.com")
        ],
        webStorageFields: [
            "access_token": "kimi-storage-token",
            "x-msh-device-id": "device-redacted",
            "x-msh-session-id": "session-redacted",
            "x-traffic-id": "traffic-redacted"
        ],
        expectedSecretFragments: ["\"accessToken\"", "\"deviceID\"", "\"sessionID\"", "\"trafficID\""]
    ),
    FirstSaveDashboardProviderScenario(
        provider: .opencodeGo,
        cookies: [
            firstSaveCookie("auth", value: "opencode-auth", domain: ".opencode.ai")
        ],
        webStorageFields: [:],
        expectedSecretFragments: ["auth=opencode-auth"]
    ),
    FirstSaveDashboardProviderScenario(
        provider: .querit,
        cookies: [
            firstSaveCookie("osduss", value: "querit-session", domain: ".querit.ai"),
            firstSaveCookie("osfuid", value: "querit-user", domain: ".querit.ai"),
            firstSaveCookie("passOsRefreshTk", value: "querit-refresh", domain: ".querit.ai")
        ],
        webStorageFields: [:],
        expectedSecretFragments: ["osduss=querit-session", "osfuid=querit-user", "passOsRefreshTk=querit-refresh"]
    ),
    FirstSaveDashboardProviderScenario(
        provider: .longcat,
        cookies: [
            firstSaveCookie("longcat_session", value: "longcat-session", domain: ".longcat.chat")
        ],
        webStorageFields: [:],
        expectedSecretFragments: ["longcat_session=longcat-session"]
    ),
    FirstSaveDashboardProviderScenario(
        provider: .longcat,
        cookies: [],
        webStorageFields: [
            "token": "longcat-storage-token",
            "userTicket": "ticket-redacted",
            "uuid": "uuid-redacted",
            "passport_uuid": "passport-redacted",
            "lt": "lt-redacted"
        ],
        expectedSecretFragments: ["\"token\"", "\"userTicket\"", "\"uuid\"", "\"passport_uuid\"", "\"lt\""]
    )
]

let expectedFirstSaveProviders: [Provider] = [
    .claudeSubscription,
    .anthropicCredits,
    .codexSubscription,
    .volcengineCodingPlan,
    .xfyunCodingPlan,
    .aliyunCodingPlan,
    .tencentCloudCodingPlan,
    .kimiSubscription,
    .opencodeGo,
    .querit,
    .longcat,
    .longcat
]
require(firstSaveDashboardProviderScenarios.map(\.provider) == expectedFirstSaveProviders, "First-save regression matrix should explicitly cover all eleven dashboard reauthentication providers, plus LongCat cookie and storage captures")

for scenario in firstSaveDashboardProviderScenarios {
    guard let config = DashboardReauthConfig(provider: scenario.provider) else {
        require(false, "\(scenario.provider.rawValue) should have a first-save dashboard reauthentication config")
        continue
    }

    let cookieHeader = DashboardCookieBuilder.cookieHeader(
        from: scenario.cookies,
        domains: config.cookieDomains
    )
    let capturedCredential = DashboardCapturedCredential(
        provider: scenario.provider,
        cookieHeader: cookieHeader,
        webStorageFields: scenario.webStorageFields
    )

    require(capturedCredential.hasCredentialMaterial, "\(scenario.provider.rawValue) first-save capture should contain credential material")
    require(DashboardCredentialCapturePolicy.isCredentialReady(
        capturedCredential,
        requiredNames: config.requiredCookieNames
    ), "\(scenario.provider.rawValue) first-save capture should be ready once required cookies or WebStorage fields are present")
    require(!DashboardCredentialCapturePolicy.shouldRetryCapture(
        capturedCredential,
        requiredNames: config.requiredCookieNames,
        completedRetryCount: 0,
        retryDelays: DashboardCredentialCapturePolicy.manualRetryDelays
    ), "\(scenario.provider.rawValue) first-save capture should not retry after all required fields are present")

    let savedSecret = capturedCredential.reauthenticatedSecret(existingSecret: nil)
    for fragment in scenario.expectedSecretFragments {
        require(savedSecret.contains(fragment), "\(scenario.provider.rawValue) first-save saved secret should preserve \(fragment)")
    }

    if !scenario.cookies.isEmpty {
        let partialCookies = Array(scenario.cookies.dropLast())
        let partialHeader = DashboardCookieBuilder.cookieHeader(
            from: partialCookies,
            domains: config.cookieDomains
        )
        let partialCredential = DashboardCapturedCredential(
            provider: scenario.provider,
            cookieHeader: partialHeader,
            webStorageFields: scenario.provider == .kimiSubscription ? [:] : scenario.webStorageFields
        )
        require(!DashboardCredentialCapturePolicy.isCredentialReady(
            partialCredential,
            requiredNames: config.requiredCookieNames
        ), "\(scenario.provider.rawValue) first-save capture should reject partial login material")
        require(DashboardCredentialCapturePolicy.shouldRetryCapture(
            partialCredential,
            requiredNames: config.requiredCookieNames,
            completedRetryCount: 0,
            retryDelays: DashboardCredentialCapturePolicy.manualRetryDelays
        ), "\(scenario.provider.rawValue) first-save capture should retry after early partial login material")
    }
}

for provider in Provider.allCases where provider.supportsDashboardReauthentication {
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
let exportedMetadata = try! store.exportMetadata([structuredKey])
let exportedText = String(data: exportedMetadata, encoding: .utf8)!
require(exportedText.contains("\"app\":\"Quota Radar\""), "Credential metadata export should identify the app without exposing runtime secrets")
require(exportedText.contains("\"provider\":\"Tavily\""), "Credential metadata export should include provider identity")
require(exportedText.contains("\"planDisplayName\":\"Team Pro\""), "Credential metadata export should include non-secret plan metadata")
require(!exportedText.contains("tvly-structured"), "Credential metadata export should not include raw API keys")
for forbiddenExportField in ["\"key\"", "cookie", "authorization", "token", "secret"] {
    require(!exportedText.localizedCaseInsensitiveContains(forbiddenExportField), "Credential metadata export should omit sensitive field names: \(forbiddenExportField)")
}
AppLanguageStore.shared.language = .simplifiedChinese
require(structuredMetadata[0].quotaDisplayText == "850 / 1000 月度积分", "APIKey quota display should prefer structured descriptors over persisted English labels")
AppLanguageStore.shared.language = .english

let codexResetCreditKey = APIKey(
    id: UUID(),
    name: "CODEX_SUBSCRIPTION_SESSION",
    key: "__Secure-next-auth.session-token=redacted",
    provider: .codexSubscription,
    remaining: 3000,
    limit: 10000,
    planDisplayName: "Pro",
    codexResetCreditsRemaining: 2,
    codexResetCreditsEarliestExpiresAt: Date(timeIntervalSince1970: 1784335094.297461),
    quotaText: .quotaWindows([
        QuotaWindowText(name: "5h", percentText: "100%", resetAt: Date(timeIntervalSince1970: 1780924878)),
        QuotaWindowText(name: "week", percentText: "30%", resetAt: Date(timeIntervalSince1970: 1781140147))
    ]),
    quotaLabel: "5h 100% · week 30%"
)
store.save([codexResetCreditKey])
let codexResetCreditMetadata = store.load()
require(codexResetCreditMetadata[0].codexResetCreditsRemaining == 2, "APIKeyStore should persist Codex reset-credit availability")
require(codexResetCreditMetadata[0].codexResetCreditsEarliestExpiresAt == Date(timeIntervalSince1970: 1784335094.297461), "APIKeyStore should persist Codex reset-credit earliest expiry")
require(codexResetCreditMetadata[0].canResetCodexQuota == false, "Metadata-only Codex keys should not expose reset while the secret is not hydrated")
let codexHydratedResetCreditMetadata = store.loadSecrets(for: codexResetCreditMetadata)
require(codexHydratedResetCreditMetadata[0].canResetCodexQuota, "Hydrated Codex keys with available credits should expose the reset action")
let exportedCodexMetadata = String(data: try! store.exportMetadata([codexResetCreditKey]), encoding: .utf8)!
require(exportedCodexMetadata.contains("\"codexResetCreditsRemaining\":2"), "Credential metadata export should include non-secret Codex reset-credit availability")
require(exportedCodexMetadata.contains("\"codexResetCreditsEarliestExpiresAt\""), "Credential metadata export should include non-secret Codex reset-credit earliest expiry")
require(!exportedCodexMetadata.contains("__Secure-next-auth.session-token"), "Credential metadata export should not include dashboard cookies")

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

swiftc QuotaRadar/Models/AppLanguage.swift QuotaRadar/Models/APIKey.swift QuotaRadar/Services/FileSecretStore.swift QuotaRadar/Services/APIKeyStore.swift QuotaRadar/Services/CredentialMetadataExporter.swift "$TMP_DIR/main.swift" -o "$TMP_DIR/secret-store-test"
"$TMP_DIR/secret-store-test"

echo "== Quota monitor behavior =="
cat >"$TMP_DIR/main.swift" <<'SWIFT'
import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(1)
    }
}

let claudeAuthorizationID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
let claudeAuthorization = APIKey(
    id: claudeAuthorizationID,
    name: "CLAUDE_SUBSCRIPTION_SESSION",
    key: "sessionKey=redacted",
    provider: .claudeSubscription,
    remaining: 6400,
    limit: 10000,
    planDisplayName: "Pro",
    lastUpdated: Date(timeIntervalSince1970: 1_800_000_000),
    quotaLabel: "5h 80% · week 64%"
)

let anthopicRefreshKeys = QuotaMonitor.refreshCandidateKeys(
    from: [claudeAuthorization],
    targetProviders: [.anthropicCredits]
)
let derivedAnthropicCredentials = anthopicRefreshKeys.filter { $0.provider == .anthropicCredits }
require(derivedAnthropicCredentials.count == 1, "Refreshing Anthropic Credits should derive one monitoring credential from an existing Claude web-login authorization")
let derivedAnthropicCredential = derivedAnthropicCredentials[0]
require(derivedAnthropicCredential.id != claudeAuthorizationID, "Derived Anthropic Credits credentials should persist as an independent account row")
require(derivedAnthropicCredential.name == Provider.anthropicCredits.defaultCredentialName, "Derived Anthropic Credits credentials should use the Anthropic Credits default credential name")
require(derivedAnthropicCredential.key == "sessionKey=redacted", "Derived Anthropic Credits credentials should reuse only the saved Claude web-login secret")
require(derivedAnthropicCredential.linkedAuthorizationID == claudeAuthorizationID, "Derived Anthropic Credits credentials should remember the source Claude authorization")
require(derivedAnthropicCredential.remaining == nil, "Derived Anthropic Credits credentials should not copy Claude subscription quota values")
require(derivedAnthropicCredential.limit == nil, "Derived Anthropic Credits credentials should not copy Claude subscription limits")
require(derivedAnthropicCredential.quotaLabel == nil, "Derived Anthropic Credits credentials should not copy Claude subscription quota labels")
require(derivedAnthropicCredential.lastUpdated == nil, "Derived Anthropic Credits credentials should require its own refresh timestamp")
require(anthopicRefreshKeys.contains { $0.id == claudeAuthorizationID }, "Refresh candidates should keep the source Claude credential in the list for preservation")

let directAnthropicCredential = APIKey(
    id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
    name: "ANTHROPIC_CREDITS_SESSION",
    key: "sessionKey=anthropic-redacted",
    provider: .anthropicCredits
)
let directAnthropicRefreshKeys = QuotaMonitor.refreshCandidateKeys(
    from: [claudeAuthorization, directAnthropicCredential],
    targetProviders: [.anthropicCredits]
)
require(
    directAnthropicRefreshKeys.filter { $0.provider == .anthropicCredits }.map(\.id) == [directAnthropicCredential.id],
    "Refreshing Anthropic Credits should not derive duplicate credentials once a direct Anthropic Credits row exists"
)

let inactiveDirectAnthropicCredential = APIKey(
    id: UUID(uuidString: "20000000-0000-0000-0000-000000000003")!,
    name: "ANTHROPIC_CREDITS_SESSION",
    key: "sessionKey=anthropic-disabled",
    provider: .anthropicCredits,
    isActive: false
)
let inactiveDirectAnthropicRefreshKeys = QuotaMonitor.refreshCandidateKeys(
    from: [claudeAuthorization, inactiveDirectAnthropicCredential],
    targetProviders: [.anthropicCredits]
)
require(
    inactiveDirectAnthropicRefreshKeys.filter { $0.provider == .anthropicCredits }.map(\.id) == [inactiveDirectAnthropicCredential.id],
    "Disabled direct Anthropic Credits credentials should suppress derived credentials so user intent is respected"
)

let unrelatedRefreshKeys = QuotaMonitor.refreshCandidateKeys(
    from: [claudeAuthorization],
    targetProviders: [.codexSubscription]
)
require(!unrelatedRefreshKeys.contains { $0.provider == .anthropicCredits }, "Refreshing unrelated providers should not create derived Anthropic Credits credentials")

func refreshFixture(
    id: UUID,
    name: String = "VOLCENGINE_CODING_PLAN_COOKIE",
    secret: String = "old-secret",
    provider: Provider = .volcengineCodingPlan,
    isActive: Bool = true,
    note: String? = "old-note",
    linkedAuthorizationID: UUID? = nil,
    lastUpdated: Date? = Date(timeIntervalSince1970: 100)
) -> APIKey {
    let key = APIKey(
        id: id,
        name: name,
        key: secret,
        provider: provider,
        isActive: isActive,
        note: note,
        linkedAuthorizationID: linkedAuthorizationID,
        remaining: 100,
        limit: 1000,
        resetAt: Date(timeIntervalSince1970: 200),
        planEndsAt: Date(timeIntervalSince1970: 300),
        planDisplayName: "Old",
        codexResetCreditsRemaining: 1,
        codexResetCreditsEarliestExpiresAt: Date(timeIntervalSince1970: 400),
        lastUpdated: lastUpdated,
        lastHTTPStatus: 200,
        lastDiagnosticMessage: "old-diagnostic",
        lastDiagnosticText: .localized(.updatedJustNow),
        consecutiveFailureCount: 1,
        quotaText: .localized(.updatedJustNow),
        quotaLabel: "old",
        usageCount: 7,
        lastUsed: Date(timeIntervalSince1970: 500)
    )
    return key
}

func refreshedFixture(from original: APIKey, remaining: Int = 800) -> APIKey {
    var key = original
    key.remaining = remaining
    key.limit = 2000
    key.resetAt = Date(timeIntervalSince1970: 1_200)
    key.planEndsAt = Date(timeIntervalSince1970: 1_300)
    key.planDisplayName = "Pro"
    key.codexResetCreditsRemaining = 4
    key.codexResetCreditsEarliestExpiresAt = Date(timeIntervalSince1970: 1_400)
    key.lastUpdated = Date(timeIntervalSince1970: 1_500)
    key.lastHTTPStatus = 201
    key.lastDiagnosticMessage = "fresh-diagnostic"
    key.lastDiagnosticText = .localized(.noSubscribedPlan)
    key.consecutiveFailureCount = 3
    key.quotaText = .localized(.noSubscribedPlan)
    key.quotaLabel = "fresh"
    key.usageCount = 0
    key.lastUsed = nil
    return key
}

let refreshMergeID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
let refreshOriginal = refreshFixture(id: refreshMergeID)
let refreshResultKey = refreshedFixture(from: refreshOriginal)
var refreshCurrent = refreshOriginal
refreshCurrent.usageCount = 99
refreshCurrent.lastUsed = Date(timeIntervalSince1970: 999)
let acceptedRefresh = QuotaMonitor.reconcileRefreshResults(
    startedWith: [refreshOriginal],
    results: [.init(key: refreshResultKey, outcome: .success, countsAsFailure: false)],
    current: [refreshCurrent]
)
require(acceptedRefresh.keys.count == 1 && acceptedRefresh.acceptedResults.count == 1, "Unchanged credentials should accept exactly one refresh result")
let acceptedRefreshKey = acceptedRefresh.keys[0]
require(acceptedRefreshKey.remaining == 800 && acceptedRefreshKey.limit == 2000, "Accepted refreshes should copy remaining and limit")
require(acceptedRefreshKey.resetAt == Date(timeIntervalSince1970: 1_200), "Accepted refreshes should copy resetAt")
require(acceptedRefreshKey.planEndsAt == Date(timeIntervalSince1970: 1_300) && acceptedRefreshKey.planDisplayName == "Pro", "Accepted refreshes should copy plan lifecycle metadata")
require(acceptedRefreshKey.codexResetCreditsRemaining == 4 && acceptedRefreshKey.codexResetCreditsEarliestExpiresAt == Date(timeIntervalSince1970: 1_400), "Accepted refreshes should copy both Codex reset-credit fields")
require(acceptedRefreshKey.quotaLabel == "fresh" && acceptedRefreshKey.quotaText?.key == .noSubscribedPlan, "Accepted refreshes should copy quota labels and structured text")
require(acceptedRefreshKey.lastHTTPStatus == 201 && acceptedRefreshKey.lastDiagnosticMessage == "fresh-diagnostic" && acceptedRefreshKey.lastDiagnosticText?.key == .noSubscribedPlan, "Accepted refreshes should copy HTTP and diagnostic fields")
require(acceptedRefreshKey.consecutiveFailureCount == 3 && acceptedRefreshKey.lastUpdated == Date(timeIntervalSince1970: 1_500), "Accepted refreshes should copy failure count and refresh timestamp")
require(acceptedRefreshKey.usageCount == 99 && acceptedRefreshKey.lastUsed == Date(timeIntervalSince1970: 999), "Accepted refreshes should preserve concurrent local usage state")

let signatureMutations: [(String, (inout APIKey) -> Void)] = [
    ("secret", { $0.key = "new-secret" }),
    ("name", { $0.name = "RENAMED" }),
    ("provider", { $0.provider = .tencentCloudCodingPlan }),
    ("active state", { $0.isActive = false }),
    ("note", { $0.note = "new-note" }),
    ("linked authorization", { $0.linkedAuthorizationID = UUID(uuidString: "30000000-0000-0000-0000-000000000099")! }),
    ("last-updated timestamp", { $0.lastUpdated = Date(timeIntervalSince1970: 101) }),
]
for (label, mutate) in signatureMutations {
    var current = refreshOriginal
    mutate(&current)
    let rejected = QuotaMonitor.reconcileRefreshResults(
        startedWith: [refreshOriginal],
        results: [.init(key: refreshResultKey, outcome: .unauthorized, countsAsFailure: true)],
        current: [current]
    )
    require(rejected.keys == [current], "Concurrent \(label) changes should remain current")
    require(rejected.acceptedResults.isEmpty, "Concurrent \(label) changes should reject stale refresh side effects")
}

let addedDuringRefresh = refreshFixture(
    id: UUID(uuidString: "30000000-0000-0000-0000-000000000002")!,
    name: "NEW_ACCOUNT"
)
let preserveAddition = QuotaMonitor.reconcileRefreshResults(
    startedWith: [refreshOriginal],
    results: [.init(key: refreshResultKey, outcome: .success, countsAsFailure: false)],
    current: [refreshCurrent, addedDuringRefresh]
)
require(preserveAddition.keys.map(\.id) == [refreshMergeID, addedDuringRefresh.id], "Credentials added during refresh should preserve current order")
let preserveDeletion = QuotaMonitor.reconcileRefreshResults(
    startedWith: [refreshOriginal],
    results: [.init(key: refreshResultKey, outcome: .success, countsAsFailure: false)],
    current: []
)
require(preserveDeletion.keys.isEmpty && preserveDeletion.acceptedResults.isEmpty, "Credentials deleted during refresh should not be recreated or emit side effects")

let failureID = UUID(uuidString: "30000000-0000-0000-0000-000000000003")!
let failureOriginal = refreshFixture(id: failureID, name: "SECOND_ACCOUNT")
let acceptedOutcomes = QuotaMonitor.reconcileRefreshResults(
    startedWith: [refreshOriginal, failureOriginal],
    results: [
        .init(key: refreshResultKey, outcome: .success, countsAsFailure: false),
        .init(key: refreshedFixture(from: failureOriginal, remaining: 0), outcome: .failed, countsAsFailure: true),
    ],
    current: [refreshOriginal, failureOriginal]
)
require(acceptedOutcomes.acceptedResults.map(\.outcome) == [.success, .failed], "Accepted success and failure outcomes should be emitted once in result order")
require(acceptedOutcomes.acceptedResults.map(\.countsAsFailure) == [false, true], "Accepted failure UI flags should be preserved exactly once")

let sourceOneID = UUID(uuidString: "30000000-0000-0000-0000-000000000010")!
let sourceTwoID = UUID(uuidString: "30000000-0000-0000-0000-000000000011")!
let sourceOne = refreshFixture(id: sourceOneID, name: "CLAUDE_ONE", secret: "source-one", provider: .claudeSubscription, note: nil)
let sourceTwo = refreshFixture(id: sourceTwoID, name: "CLAUDE_TWO", secret: "source-two", provider: .claudeSubscription, note: nil)
let derivedOneID = UUID(uuidString: "30000000-0000-0000-0000-000000000012")!
let derivedTwoID = UUID(uuidString: "30000000-0000-0000-0000-000000000013")!
var derivedOne = refreshFixture(id: derivedOneID, name: "ANTHROPIC_ONE", secret: sourceOne.key, provider: .anthropicCredits, note: nil, linkedAuthorizationID: sourceOneID, lastUpdated: nil)
derivedOne = refreshedFixture(from: derivedOne, remaining: 600)
var derivedTwo = refreshFixture(id: derivedTwoID, name: "ANTHROPIC_TWO", secret: sourceTwo.key, provider: .anthropicCredits, note: nil, linkedAuthorizationID: sourceTwoID, lastUpdated: nil)
derivedTwo = refreshedFixture(from: derivedTwo, remaining: 700)
let acceptedDerived = QuotaMonitor.reconcileRefreshResults(
    startedWith: [sourceOne, sourceTwo],
    results: [
        .init(key: derivedOne, outcome: .success, countsAsFailure: false),
        .init(key: derivedTwo, outcome: .success, countsAsFailure: false),
    ],
    current: [sourceOne, sourceTwo]
)
require(acceptedDerived.keys.map(\.id) == [sourceOneID, sourceTwoID, derivedOneID, derivedTwoID], "Multiple eligible derived results should append independently in result order")
require(acceptedDerived.acceptedResults.map { $0.key.id } == [derivedOneID, derivedTwoID], "Derived accepted side effects should retain result order")

let existingLinkedDerived = refreshFixture(
    id: UUID(uuidString: "30000000-0000-0000-0000-000000000014")!,
    name: "EXISTING_LINKED",
    secret: sourceOne.key,
    provider: .anthropicCredits,
    note: nil,
    linkedAuthorizationID: sourceOneID
)
let linkedRowsAreNotDirect = QuotaMonitor.reconcileRefreshResults(
    startedWith: [sourceOne, sourceTwo],
    results: [.init(key: derivedTwo, outcome: .success, countsAsFailure: false)],
    current: [sourceOne, sourceTwo, existingLinkedDerived]
)
require(linkedRowsAreNotDirect.keys.contains { $0.id == derivedTwoID }, "Linked derived rows should not suppress another eligible derived result as a direct credential")

for (label, mutate) in signatureMutations {
    var changedSource = sourceOne
    mutate(&changedSource)
    let rejectedDerived = QuotaMonitor.reconcileRefreshResults(
        startedWith: [sourceOne],
        results: [.init(key: derivedOne, outcome: .unauthorized, countsAsFailure: true)],
        current: [changedSource]
    )
    require(!rejectedDerived.keys.contains { $0.id == derivedOneID }, "Derived results should reject concurrent source \(label) changes")
    require(rejectedDerived.acceptedResults.isEmpty, "Rejected derived source \(label) changes should emit no side effects")
}

let deletedSourceDerived = QuotaMonitor.reconcileRefreshResults(
    startedWith: [sourceOne],
    results: [.init(key: derivedOne, outcome: .success, countsAsFailure: false)],
    current: []
)
require(deletedSourceDerived.keys.isEmpty && deletedSourceDerived.acceptedResults.isEmpty, "Deleted sources should reject derived refresh results")
let concurrentDirectAnthropic = refreshFixture(
    id: UUID(uuidString: "30000000-0000-0000-0000-000000000015")!,
    name: "ANTHROPIC_DIRECT",
    secret: "direct-secret",
    provider: .anthropicCredits,
    note: nil,
    linkedAuthorizationID: nil
)
let directSuppressesDerived = QuotaMonitor.reconcileRefreshResults(
    startedWith: [sourceOne],
    results: [.init(key: derivedOne, outcome: .success, countsAsFailure: false)],
    current: [sourceOne, concurrentDirectAnthropic]
)
require(directSuppressesDerived.keys.map(\.id) == [sourceOneID, concurrentDirectAnthropic.id] && directSuppressesDerived.acceptedResults.isEmpty, "A concurrently added direct credential should suppress stale derived rows")
SWIFT

swiftc \
  QuotaRadar/Models/AppLanguage.swift \
  QuotaRadar/Models/AppAppearance.swift \
  QuotaRadar/Models/APIKey.swift \
  QuotaRadar/Models/AIQuoteLibrary.swift \
  QuotaRadar/Models/QuotaHistory.swift \
  QuotaRadar/Services/FileSecretStore.swift \
  QuotaRadar/Services/APIKeyStore.swift \
  QuotaRadar/Services/CredentialMetadataExporter.swift \
  QuotaRadar/Services/QuotaHistoryStore.swift \
  QuotaRadar/Services/QuotaNotificationService.swift \
  QuotaRadar/Services/EnvImporter.swift \
  QuotaRadar/Services/ClaudeSettingsImporter.swift \
  QuotaRadar/Services/QuotaService.swift \
  QuotaRadar/Models/QuotaMonitor.swift \
  "$TMP_DIR/main.swift" \
  -o "$TMP_DIR/quota-monitor-test"
"$TMP_DIR/quota-monitor-test"

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
require(QuotaError.schemaDrift.errorDescription == "接口字段可能变化，请重新校准该服务商。", "QuotaError should emit actionable schema-drift diagnostics in Simplified Chinese")
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
require(L10n.localizedQuotaLabel("接口字段可能变化，请重新校准该服务商。", language: .english) == "Provider quota fields may have changed. Recalibrate this provider.", "Persisted Chinese schema-drift diagnostics should relocalize when switching to English")
let schemaDriftDiagnostic = APIKey(
    name: "CODEX_SUBSCRIPTION_SESSION",
    key: "cookie",
    provider: .codexSubscription,
    lastDiagnosticMessage: "Provider quota fields may have changed. Recalibrate this provider."
)
require(schemaDriftDiagnostic.diagnosticSummary == "接口字段可能变化，请重新校准该服务商。", "Credential diagnostics should localize schema-drift failures instead of showing a generic invalid-response prompt")
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

let anthropicPrepaidCredits = try! QuotaParsers.parseAnthropicPrepaidCredits(Data("""
{"amount":42,"auto_reload_settings":null,"currency":null,"last_paid_purchase_cents":null,"pending_invoice_amount_cents":null}
""".utf8))
require(anthropicPrepaidCredits.remaining == 42, "Anthropic prepaid credits should expose amount as remaining credits")
require(anthropicPrepaidCredits.limit == 42, "Anthropic prepaid credits should not invent a larger limit")
require(anthropicPrepaidCredits.quotaLabel == "42 credits left", "Anthropic prepaid credits should display a credits balance")
require(anthropicPrepaidCredits.quotaText?.key == .creditsLeftFormat, "Anthropic prepaid credits should carry a structured credits-left descriptor")
require(anthropicPrepaidCredits.resetAt == nil, "Anthropic prepaid credits should not invent a reset cycle")
let emptyAnthropicPrepaidCredits = try! QuotaParsers.parseAnthropicPrepaidCredits(Data("""
{"amount":0,"auto_reload_settings":null,"currency":null}
""".utf8))
require(emptyAnthropicPrepaidCredits.remaining == 0, "Empty Anthropic prepaid credits should be exhausted")
require(emptyAnthropicPrepaidCredits.quotaLabel == "No Anthropic credits available", "Empty Anthropic prepaid credits should explain the exhausted balance")

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

let longCatTokenPackExpiry = ISO8601DateFormatter().date(from: "2026-08-07T10:00:00+08:00")!
let longCatTokenPackData = Data("""
{"code":0,"data":{"currentLot":{"remainingToken":1250000,"totalToken":5000000,"consumedToken":3750000,"consumedRatio":0.75,"expireTime":"2026-08-07T10:00:00+08:00","remainSeconds":2592000,"grantCategory":"PAID"},"estimate":{"exhaustedAfterDays":12},"otherLots":[{"remainingToken":300000,"expireTime":"2026-08-10T10:00:00+08:00","grantCategory":"GIFT"}]}}
""".utf8)
let longCatTokenPack = try! QuotaParsers.parseLongCatTokenPackSummary(longCatTokenPackData)
require(longCatTokenPack.remaining == 1250000, "LongCat Token Pack should display token remaining")
require(longCatTokenPack.limit == 5000000, "LongCat Token Pack should display token package total")
require(longCatTokenPack.quotaLabel == "1250000 / 5000000 tokens", "LongCat Token Pack should display remaining over total tokens")
require(longCatTokenPack.quotaText?.key == .tokenQuotaFormat, "LongCat Token Pack should carry a structured token quota descriptor")
require(abs((longCatTokenPack.planEndsAt?.timeIntervalSince1970 ?? 0) - longCatTokenPackExpiry.timeIntervalSince1970) < 1, "LongCat Token Pack should expose current package expiry as plan validity")
require(longCatTokenPack.resetAt == nil, "LongCat Token Pack should not invent a reset cycle")
require(longCatTokenPack.planDisplayName == "Token Pack", "LongCat Token Pack should expose the token-package billing mode")
do {
    _ = try QuotaParsers.parseLongCatTokenPackSummary(Data("""
{"code":401,"msg":"用户未登录，请先登录","data":null}
""".utf8))
    fail("LongCat Token Pack dashboard 401 bodies should throw unauthorized")
} catch QuotaError.unauthorized {
} catch {
    fail("LongCat Token Pack dashboard 401 bodies should throw unauthorized, got \(error)")
}

let longCatPaygoData = Data("""
{"code":0,"data":{"paygoBalance":{"primary":{"currency":"CNY","amount":"128.50"}},"paygoStatus":"NORMAL","rechargeEnabled":true,"statusTip":""}}
""".utf8)
let longCatPaygo = try! QuotaParsers.parseLongCatPayAsYouGoSummary(longCatPaygoData)
require(longCatPaygo.remaining == 12850, "LongCat Pay-as-you-go balance should be represented in cents")
require(longCatPaygo.limit == 12850, "LongCat Pay-as-you-go balance should not invent a fixed spending ceiling")
require(longCatPaygo.quotaLabel == "CNY 128.50 balance", "LongCat Pay-as-you-go should display API balance")
require(longCatPaygo.quotaText?.key == .moneyBalanceFormat, "LongCat Pay-as-you-go balance should carry a structured money-balance descriptor")
require(longCatPaygo.resetAt == nil, "LongCat Pay-as-you-go balance should not invent a reset cycle")
require(longCatPaygo.planEndsAt == nil, "LongCat Pay-as-you-go balance should not invent an expiry because dashboard copy says balance does not expire")
require(longCatPaygo.planDisplayName == "API Pay-as-you-go", "LongCat Pay-as-you-go should expose the API billing mode")
do {
    _ = try QuotaParsers.parseLongCatPayAsYouGoSummary(Data("""
{"code":401,"msg":"用户未登录，请先登录","data":null}
""".utf8))
    fail("LongCat Pay-as-you-go dashboard 401 bodies should throw unauthorized")
} catch QuotaError.unauthorized {
} catch {
    fail("LongCat Pay-as-you-go dashboard 401 bodies should throw unauthorized, got \(error)")
}

let longCatCombined = try! QuotaParsers.parseLongCatBillingSummary(
    tokenPackData: longCatTokenPackData,
    payAsYouGoData: longCatPaygoData
)
require(longCatCombined.planDisplayName == "LongCat", "LongCat combined billing summary should stay under one provider plan name")
require(longCatCombined.remaining == 1250000, "LongCat combined billing summary should use token package remaining as the key quota")
require(longCatCombined.limit == 5000000, "LongCat combined billing summary should use token package total as the key quota")
require(longCatCombined.quotaText?.kind == .quotaWindows, "LongCat combined billing summary should render multiple billing meters under one account")
require(longCatCombined.quotaText?.quotaWindows.count == 2, "LongCat combined billing summary should include Token Pack and API pay-as-you-go rows")
require(longCatCombined.quotaText?.quotaWindows.first?.name == "tokenPack", "LongCat combined billing summary should keep Token Pack as the first meter")
require(longCatCombined.quotaText?.quotaWindows.first?.percentText == "25%", "LongCat Token Pack meter should expose the real remaining percentage")
require(longCatCombined.quotaText?.quotaWindows.first?.remainingText == "1250000 / 5000000 tokens", "LongCat Token Pack meter should preserve remaining over total tokens")
require(longCatCombined.quotaText?.quotaWindows.last?.name == "paygoBalance", "LongCat combined billing summary should keep API pay-as-you-go as the second meter")
require(longCatCombined.quotaText?.quotaWindows.last?.percentText == "¥128.50", "LongCat pay-as-you-go meter should show balance money instead of a fake percentage")
require(longCatCombined.quotaText?.quotaWindows.last?.remainingText == "CNY 128.50 balance", "LongCat pay-as-you-go meter should preserve the raw balance label")
require(abs((longCatCombined.planEndsAt?.timeIntervalSince1970 ?? 0) - longCatTokenPackExpiry.timeIntervalSince1970) < 1, "LongCat combined billing summary should expose Token Pack expiry as account-level package validity")
let longCatMixedJSONCredential = LongCatDashboardCredential("""
{"cookie":"locale=zh; passport_uuid=passport-from-cookie","token":"token-from-json","passport_uuid":"passport-from-json"}
""")!
require(longCatMixedJSONCredential.cookieHeader.contains("locale=zh"), "LongCat mixed JSON credentials should preserve existing cookie header fields")
require(longCatMixedJSONCredential.cookieHeader.contains("token=token-from-json"), "LongCat mixed JSON credentials should merge JSON token metadata into the Cookie header")
require(longCatMixedJSONCredential.cookieHeader.contains("passport_uuid=passport-from-json"), "LongCat mixed JSON credentials should prefer JSON passport metadata over stale cookie-only values")
try! QuotaParsers.validateLongCatUserCurrent(Data("""
{"code":0,"data":{"userId":12345,"loginStatus":1,"name":"LongCat User"}}
""".utf8))
try! QuotaParsers.validateLongCatUserCurrent(Data("""
{"code":0,"data":{"loginStatus":1}}
""".utf8))
do {
    try QuotaParsers.validateLongCatUserCurrent(Data("""
{"code":0,"data":{"loginStatus":0}}
""".utf8))
    fail("LongCat login validation should reject user-current responses that still indicate logged-out status")
} catch QuotaError.unauthorized {
} catch {
    fail("LongCat logged-out user-current responses should throw unauthorized, got \(error)")
}

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
require(xfyun.quotaText?.quotaWindows.first(where: { $0.name == "5h" })?.remainingText == "2378 / 6000", "XFYun quota-window details should use the same remaining/total semantics as other providers")
AppLanguageStore.shared.language = .english
require(xfyun.quotaText?.quotaWindows.first(where: { $0.name == "5h" })?.remainingText == "2378 / 6000", "XFYun should display five-hour remaining and maximum request counts")
require(xfyun.quotaText?.quotaWindows.first(where: { $0.name == "week" })?.remainingText == "432546 / 450000", "XFYun should display weekly remaining and maximum request counts")
require(xfyun.quotaText?.quotaWindows.first(where: { $0.name == "month" })?.remainingText == "853441 / 900000", "XFYun should display monthly remaining and maximum request counts")
let xfyunEnglishFiveHourDetail = xfyun.quotaText?.quotaWindows.first(where: { $0.name == "5h" })?.detailValueText ?? ""
require(xfyunEnglishFiveHourDetail.hasPrefix("Resets ") && xfyunEnglishFiveHourDetail.hasSuffix(" (2378 / 6000)"), "XFYun quota-window details should show reset timing first and count details in parentheses")
let xfyunDisplayKey = APIKey(name: "XFYUN_CODING_PLAN_COOKIE", key: "cookie", provider: .xfyunCodingPlan, quotaText: xfyun.quotaText, quotaLabel: xfyun.quotaLabel)
require(xfyunDisplayKey.quotaWindowDetails.count == 3, "XFYun should render cycle detail rows with remaining/maximum counts even when reset times are not exposed")
let xfyunDecimalUsage = try! QuotaParsers.parseXFYunCodingPlanList(Data("""
{"code":0,"data":{"rows":[{"name":"高效版-包月","validFrom":"2026-05-28 17:48:58","expiresAt":"2026-06-28 17:48:58","status":1,"codingPlanUsageDTO":{"packageLeft":16052.4,"packageLimit":90000,"packageUsage":73947.6,"rp5hLimit":6000,"rp5hUsage":1118.4,"rpwLimit":45000,"rpwUsage":38953.6}}],"page":1,"size":6,"total":1},"succeed":true,"failed":false}
""".utf8), now: localTestDate("2026-06-20 23:55:00"))
require(xfyunDecimalUsage.remaining == 1343, "XFYun should parse decimal official usage values and still use the tightest remaining window")
require(xfyunDecimalUsage.quotaLabel == "5h 81.4% · week 13.4% · month 17.8%", "XFYun decimal usage should render remaining percentages")
require(xfyunDecimalUsage.quotaText?.quotaWindows.first(where: { $0.name == "5h" })?.remainingText == "4881 / 6000", "XFYun decimal five-hour usage should render request counts as whole numbers")
require(xfyunDecimalUsage.quotaText?.quotaWindows.first(where: { $0.name == "week" })?.remainingText == "6046 / 45000", "XFYun decimal weekly usage should render request counts as whole numbers")
require(xfyunDecimalUsage.quotaText?.quotaWindows.first(where: { $0.name == "month" })?.remainingText == "16052 / 90000", "XFYun decimal monthly usage should render request counts as whole numbers")
let xfyunWindowed = try! QuotaParsers.parseXFYunCodingPlanList(Data("""
{"code":0,"data":{"rows":[{"name":"高效版-包月","validFrom":"2026-05-28 17:48:58","expiresAt":"2026-06-28 17:48:58","codingPlanUsageDTO":{"packageLeft":853441,"packageLimit":900000,"packageUsage":46559,"rp5hLimit":6000,"rp5hUsage":3622,"rpwLimit":450000,"rpwUsage":17454}}]},"succeed":true}
""".utf8), now: localTestDate("2026-06-16 18:15:00"))
require(xfyunWindowed.quotaText?.quotaWindows.first(where: { $0.name == "5h" })?.resetAt == localTestDate("2026-06-16 21:48:58"), "XFYun should infer the next five-hour reset boundary from validFrom")
require(xfyunWindowed.quotaText?.quotaWindows.first(where: { $0.name == "week" })?.resetAt == localTestDate("2026-06-18 17:48:58"), "XFYun should infer the next weekly reset boundary from validFrom")
require(xfyunWindowed.quotaText?.quotaWindows.first(where: { $0.name == "month" })?.resetAt == localTestDate("2026-06-28 17:48:58"), "XFYun should use package expiry as the total-package reset boundary")
AppLanguageStore.shared.language = .simplifiedChinese
require(xfyunWindowed.quotaText?.quotaWindows.first(where: { $0.name == "week" })?.detailValueText == "6月18日 17:48 重置（432546 / 450000）", "Quota-window details should show reset timing first and append count details in parentheses")
AppLanguageStore.shared.language = .english
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

do {
    _ = try QuotaParsers.parseVolcengineCodingPlanUsage(Data("""
{"ResponseMetadata":{"Action":"GetCodingPlanUsage"},"Result":{"Status":"Running","QuotaUsage":[{"Level":"session","Percent":0,"ResetTimestamp":-1},{"Level":"weekly","Percent":10.814960999999998},{"Level":"monthly","Percent":5.407480499999999,"ResetTimestamp":1782921599}]}}
""".utf8))
    fail("Volcengine coding-plan usage should reject calibrated weekly/monthly quota windows when reset timestamps disappear")
} catch QuotaError.schemaDrift {
} catch {
    fail("Volcengine coding-plan missing reset timestamp should throw schemaDrift, got \(error)")
}

do {
    _ = try QuotaParsers.parseVolcengineCodingPlanUsage(Data("""
{"ResponseMetadata":{"Action":"GetCodingPlanUsage"},"Result":{"Status":"Running","QuotaUsage":[{"Level":"session","ResetTimestamp":-1}]}}
""".utf8))
    fail("Volcengine coding-plan incomplete HTTP-200 envelopes should not leak JSON decoding errors")
} catch QuotaError.invalidResponse {
} catch {
    fail("Volcengine coding-plan incomplete HTTP-200 envelopes should map to invalidResponse, got \(error)")
}

do {
    _ = try QuotaParsers.parseVolcengineCodingPlanUsage(Data("""
{"ResponseMetadata":{"Action":"GetCodingPlanUsage"},"Result":{"Status":"NotSubscribed","UpdateTimestamp":1782921599}}
""".utf8))
    fail("Volcengine coding-plan no-subscription envelopes should not be treated as malformed usage")
} catch QuotaError.noSubscription {
} catch {
    fail("Volcengine coding-plan Result without QuotaUsage but with Status and UpdateTimestamp should map to noSubscription, got \(error)")
}

for nearMiss in [
    #"{"ResponseMetadata":{"Action":"GetCodingPlanUsage"},"Result":{"Status":"NotSubscribed","UpdateTimestamp":1782921599,"Message":"shape changed"}}"#,
    #"{"ResponseMetadata":{"Action":"GetCodingPlanUsage"},"Result":{"Status":null,"UpdateTimestamp":1782921599}}"#,
    #"{"ResponseMetadata":{"Action":"GetCodingPlanUsage"},"Result":{"Status":"NotSubscribed","UpdateTimestamp":null}}"#,
] {
    do {
        _ = try QuotaParsers.parseVolcengineCodingPlanUsage(Data(nearMiss.utf8))
        fail("Volcengine coding-plan no-subscription near-misses should not parse as valid usage")
    } catch QuotaError.invalidResponse {
    } catch {
        fail("Volcengine coding-plan no-subscription near-misses should map to invalidResponse, got \(error)")
    }
}

let volcInvalidCSRFData = Data("""
{"ResponseMetadata":{"Action":"GetCodingPlanUsage","Error":{"Code":"InvalidCSRFToken","Message":"Invalid CSRF token."}},"Result":null}
""".utf8)
require(VolcengineCodingPlanAuthPolicy.errorCode(in: volcInvalidCSRFData) == "InvalidCSRFToken", "Volcengine should classify HTTP-200 CSRF error envelopes before quota parsing")
require(VolcengineCodingPlanAuthPolicy.shouldRetryInvalidCSRF(completedRetryCount: 0), "Volcengine should allow one CSRF bootstrap retry")
require(!VolcengineCodingPlanAuthPolicy.shouldRetryInvalidCSRF(completedRetryCount: 1), "Volcengine must not retry InvalidCSRFToken more than once")
let volcRotatedResponse = HTTPURLResponse(
    url: URL(string: "https://console.volcengine.com/api/top/ark/cn-beijing/2024-01-01/GetCodingPlanUsage")!,
    statusCode: 200,
    httpVersion: "HTTP/2",
    headerFields: ["x-need-token": "rotated-redacted"]
)!
require(VolcengineCodingPlanAuthPolicy.rotatedCSRFToken(from: volcRotatedResponse) == "rotated-redacted", "Volcengine should read the rotated token from x-need-token")
let rotatedVolcCookie = VolcengineCodingPlanAuthPolicy.replacingCookie(
    named: "csrfToken",
    value: "rotated-redacted",
    in: "digest=d; csrfToken=stale; AccountID=a"
)
require(rotatedVolcCookie.contains("csrfToken=rotated-redacted"), "Volcengine CSRF retry should replace the stale csrfToken cookie")
require(!rotatedVolcCookie.contains("csrfToken=stale"), "Volcengine CSRF retry must not replay the rejected csrfToken")

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
    _ = try QuotaParsers.parseOpenCodeGoUsage(
        Data(#";0x0000002f;((self.$R=self.$R||{})["server-fn:11"]=[],null)"#.utf8),
        expectedServerInstance: "server-fn:11"
    )
    fail("OpenCode Go should report noSubscription when the authenticated server function returns null")
} catch QuotaError.noSubscription {
} catch {
    fail("OpenCode Go null subscription should throw noSubscription, got \(error)")
}

for openCodeNullNearMiss in [
    #";0x0000002f;((self.$R=self.$R||{})["server-fn:12"]=[],null)"#,
    #";0x00000030;((self.$R=self.$R||{})["server-fn:11"]=[],null)"#,
    #"prefix;0x0000002f;((self.$R=self.$R||{})["server-fn:11"]=[],null)"#,
] {
    do {
        _ = try QuotaParsers.parseOpenCodeGoUsage(
            Data(openCodeNullNearMiss.utf8),
            expectedServerInstance: "server-fn:11"
        )
        fail("OpenCode Go should reject null envelopes with the wrong frame or server instance")
    } catch QuotaError.invalidResponse {
    } catch {
        fail("OpenCode Go null near-miss should throw invalidResponse, got \(error)")
    }
}

do {
    _ = try QuotaParsers.parseOpenCodeGoUsage(Data("<a href=\"/auth/authorize\">login</a>".utf8))
    fail("OpenCode Go auth redirect should remain unauthorized")
} catch QuotaError.unauthorized {
} catch {
    fail("OpenCode Go auth redirect should throw unauthorized, got \(error)")
}

do {
    _ = try QuotaParsers.parseOpenCodeGoUsage(Data(";0x1;((self.$R=self.$R||{})[\"server-fn:11\"]=[],{unexpected:true})".utf8))
    fail("OpenCode Go malformed non-null responses should remain invalidResponse")
} catch QuotaError.invalidResponse {
} catch {
    fail("OpenCode Go malformed non-null response should throw invalidResponse, got \(error)")
}

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

for tencentUnauthorizedPayload in [
    #"{"code":50,"msg":"登录态过期，请重新登录(-40002)"}"#,
    #"{"code":9,"msg":"验证CSRF失败，请重新登录"}"#,
    #"{"code":123,"msg":"login expired"}"#,
] {
    do {
        _ = try QuotaParsers.parseTencentCloudCodingPlanDescribePkg(Data(tencentUnauthorizedPayload.utf8))
        fail("Tencent Cloud HTTP-200 login and CSRF failures should be unauthorized")
    } catch QuotaError.unauthorized {
    } catch {
        fail("Tencent Cloud auth envelope should throw unauthorized, got \(error)")
    }
}

do {
    _ = try QuotaParsers.parseTencentCloudCodingPlanDescribePkg(Data(#"{"code":123,"msg":"login service unavailable"}"#.utf8))
    fail("Tencent Cloud generic login-service failures should remain invalidResponse")
} catch QuotaError.invalidResponse {
} catch {
    fail("Tencent Cloud generic login-service error should throw invalidResponse, got \(error)")
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
let claudeMax20xOrganizationContext = try! QuotaParsers.parseClaudeOrganizationContext(Data("""
[{"uuid":"org-redacted","name":"Personal","active":true,"billing_type":"stripe_subscription","rate_limit_tier":"max_20x","capabilities":["chat","claude_max"]}]
""".utf8))
require(claudeMax20xOrganizationContext.planDisplayName == "Max 20x", "Claude subscription organization context should expose max_20x as Max 20x")
let claudeMax5xOrganizationContext = try! QuotaParsers.parseClaudeOrganizationContext(Data("""
[{"uuid":"org-redacted","name":"Personal","active":true,"billing_type":"stripe_subscription","rate_limit_tier":"max_5x","capabilities":["chat","claude_max"]}]
""".utf8))
require(claudeMax5xOrganizationContext.planDisplayName == "Max 5x", "Claude subscription organization context should expose max_5x as Max 5x")
let claudeMax20xCapabilityOrganizationContext = try! QuotaParsers.parseClaudeOrganizationContext(Data("""
[{"uuid":"org-redacted","name":"Personal","active":true,"billing_type":"stripe_subscription","rateLimitTier":"rate_limit_20x","capabilities":["chat","claude_max"]}]
""".utf8))
require(claudeMax20xCapabilityOrganizationContext.planDisplayName == "Max 20x", "Claude subscription organization context should combine claude_max capability with a 20x rate tier")

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

let claudeUsageWithMissingFiveHourReset = try! QuotaParsers.parseClaudeSubscriptionUsage(Data("""
{"five_hour":{"limit_dollars":null,"remaining_dollars":null,"resets_at":null,"used_dollars":null,"utilization":100},"seven_day":{"limit_dollars":null,"remaining_dollars":null,"resets_at":"2026-06-15T00:00:00.000000Z","used_dollars":null,"utilization":37.5},"limits":[{"group":"default","is_active":true,"kind":"rolling","percent":100,"resets_at":null,"severity":"normal"}],"spend":{"enabled":false,"percent":0}}
""".utf8))
require(claudeUsageWithMissingFiveHourReset.quotaLabel == "5h 0% · week 62.5%", "Claude subscription should verify successfully when the current usage endpoint omits five-hour reset timing")
require(claudeUsageWithMissingFiveHourReset.quotaText?.quotaWindows.first(where: { $0.name == "5h" })?.resetAt == nil, "Claude five-hour quota row should omit reset timing when the provider no longer returns it")
require(claudeUsageWithMissingFiveHourReset.quotaText?.quotaWindows.first(where: { $0.name == "week" })?.resetAt != nil, "Claude weekly quota row should keep reset timing when present")

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
let claudeMax20xSubscriptionDetails = try! QuotaParsers.parseClaudeSubscriptionDetails(Data("""
{"subscription":{"tierName":"Claude Max 20x"},"next_charge_at":"2026-07-09T09:57:27Z"}
""".utf8))
require(claudeMax20xSubscriptionDetails.planDisplayName == "Max 20x", "Claude subscription details should normalize nested Claude Max 20x tier names")
let claudeMax5xSubscriptionDetails = try! QuotaParsers.parseClaudeSubscriptionDetails(Data("""
{"subscription":{"plan_type":"max-5x"},"next_charge_at":"2026-07-09T09:57:27Z"}
""".utf8))
require(claudeMax5xSubscriptionDetails.planDisplayName == "Max 5x", "Claude subscription details should normalize nested max-5x tier names")

let codexUsage = try! QuotaParsers.parseCodexWhamUsage(Data("""
{"plan_type":"pro","rate_limit":{"allowed":true,"limit_reached":false,"primary_window":{"used_percent":0,"limit_window_seconds":18000,"reset_after_seconds":18000,"reset_at":1780924878},"secondary_window":{"used_percent":70,"limit_window_seconds":604800,"reset_after_seconds":233270,"reset_at":1781140147}},"additional_rate_limits":[{"limit_name":"GPT-5.3-Codex-Spark","rate_limit":{"allowed":true,"limit_reached":false,"primary_window":{"used_percent":0,"limit_window_seconds":18000,"reset_after_seconds":18000,"reset_at":1780924878},"secondary_window":{"used_percent":0,"limit_window_seconds":604800,"reset_after_seconds":604800,"reset_at":1781511678}}}],"credits":{"has_credits":false,"unlimited":false,"balance":"0"},"rate_limit_reset_credits":{"available_count":3}}
""".utf8))
require(codexUsage.remaining == 3000, "Codex subscription usage should use the tightest remaining quota window")
require(codexUsage.limit == 10000, "Codex subscription usage should use percentage basis points")
require(codexUsage.quotaLabel == "5h 100% · week 30%", "Codex subscription usage should display five-hour and weekly windows")
require(codexUsage.quotaText?.kind == .quotaWindows, "Codex subscription usage should carry structured quota-window descriptors")
require(codexUsage.resetAt != nil, "Codex subscription usage should expose the tightest quota window reset date")
require(codexUsage.planEndsAt == nil, "Codex wham usage does not expose subscription end date")
require(codexUsage.planDisplayName == "Pro", "Codex wham usage should expose plan_type as a concrete plan name")
require(codexUsage.codexResetCreditsRemaining == 3, "Codex wham usage should expose available reset credits")
let codexWeeklyOnlyUsage = try! QuotaParsers.parseCodexWhamUsage(Data("""
{"plan_type":"pro","rate_limit":{"allowed":true,"limit_reached":false,"primary_window":{"used_percent":10,"limit_window_seconds":604800,"reset_after_seconds":576032,"reset_at":1784512371},"secondary_window":null}}
""".utf8))
require(codexWeeklyOnlyUsage.quotaLabel == "week 90%", "Codex should display a returned weekly-only quota window")
require(codexWeeklyOnlyUsage.quotaText?.quotaWindows.map(\.name) == ["week"], "Codex should not synthesize a missing five-hour window")
let codexFiveHourOnlyUsage = try! QuotaParsers.parseCodexWhamUsage(Data("""
{"plan_type":"pro","rate_limit":{"allowed":true,"limit_reached":false,"primary_window":{"used_percent":25,"limit_window_seconds":18000,"reset_after_seconds":12000,"reset_at":1784512371},"secondary_window":null}}
""".utf8))
require(codexFiveHourOnlyUsage.quotaLabel == "5h 75%", "Codex should display a returned five-hour-only quota window")
require(codexFiveHourOnlyUsage.quotaText?.quotaWindows.map(\.name) == ["5h"], "Codex should not synthesize a missing weekly window")
let codexUnknownAndWeeklyUsage = try! QuotaParsers.parseCodexWhamUsage(Data("""
{"plan_type":"pro","rate_limit":{"allowed":true,"limit_reached":false,"primary_window":{"used_percent":25,"limit_window_seconds":12345,"reset_after_seconds":12000,"reset_at":1784512371},"secondary_window":{"used_percent":10,"limit_window_seconds":604800,"reset_after_seconds":576032,"reset_at":1784512371}}}
""".utf8))
require(codexUnknownAndWeeklyUsage.quotaLabel == "week 90%", "Codex should ignore an unknown quota duration when a recognized weekly window is present")
require(codexUnknownAndWeeklyUsage.quotaText?.quotaWindows.map(\.name) == ["week"], "Codex should not mislabel an unknown quota duration as five-hour usage")
do {
    _ = try QuotaParsers.parseCodexWhamUsage(Data("""
    {"plan_type":"pro","rate_limit":{"allowed":true,"limit_reached":false,"primary_window":{"used_percent":25,"limit_window_seconds":12345,"reset_after_seconds":12000,"reset_at":1784512371},"secondary_window":null}}
    """.utf8))
    fail("Codex should reject a response containing only unknown quota-window durations")
} catch QuotaError.schemaDrift {
} catch QuotaError.invalidResponse {
} catch {
    fail("Codex unknown-only quota duration should throw schemaDrift or invalidResponse, got \(error)")
}
let codexResetCreditDetails = try! QuotaParsers.parseCodexResetCreditDetails(Data("""
{"credits":[{"id":"reset-redacted-1","reset_type":"codex_rate_limits","status":"available","granted_at":"2026-06-18T00:38:14.297461Z","expires_at":"2026-07-18T00:38:14.297461Z","redeem_started_at":null,"redeemed_at":null},{"id":"reset-redacted-2","reset_type":"codex_rate_limits","status":"available","granted_at":"2026-06-26T23:56:41.527892Z","expires_at":"2026-07-26T23:56:41.527892Z","redeem_started_at":null,"redeemed_at":null}],"available_count":2,"total_earned_count":0}
""".utf8))
require(codexResetCreditDetails.availableCount == 2, "Codex reset-credit details should expose available_count")
require(abs((codexResetCreditDetails.earliestExpiresAt?.timeIntervalSince1970 ?? 0) - 1784335094.297461) < 1, "Codex reset-credit details should expose the earliest provider-returned expiry")
let codexRedeemedResetCreditDetails = try! QuotaParsers.parseCodexResetCreditDetails(Data("""
{"credits":[{"id":"reset-redacted-1","reset_type":"codex_rate_limits","status":"redeemed","expires_at":"2026-07-01T00:00:00Z","redeemed_at":"2026-06-20T00:00:00Z"},{"id":"reset-redacted-2","reset_type":"codex_rate_limits","status":"available","expires_at":"2026-07-26T23:56:41.527892Z","redeemed_at":null}],"available_count":1}
""".utf8))
require(abs((codexRedeemedResetCreditDetails.earliestExpiresAt?.timeIntervalSince1970 ?? 0) - 1785110201.527892) < 1, "Codex reset-credit details should ignore redeemed credits when picking earliest expiry")
let codexNegativeResetCredits = try! QuotaParsers.parseCodexWhamUsage(Data("""
{"plan_type":"pro","rate_limit":{"allowed":true,"limit_reached":false,"primary_window":{"used_percent":0,"limit_window_seconds":18000,"reset_at":1780924878},"secondary_window":{"used_percent":70,"limit_window_seconds":604800,"reset_at":1781140147}},"rate_limit_reset_credits":{"available_count":-1}}
""".utf8))
require(codexNegativeResetCredits.codexResetCreditsRemaining == nil, "Codex reset-credit parser should ignore negative available_count values")
let codexStringResetCredits = try! QuotaParsers.parseCodexWhamUsage(Data("""
{"plan_type":"pro","rate_limit":{"allowed":true,"limit_reached":false,"primary_window":{"used_percent":0,"limit_window_seconds":18000,"reset_at":1780924878},"secondary_window":{"used_percent":70,"limit_window_seconds":604800,"reset_at":1781140147}},"rate_limit_reset_credits":{"available_count":"3"}}
""".utf8))
require(codexStringResetCredits.codexResetCreditsRemaining == nil, "Codex reset-credit parser should ignore non-numeric available_count values")
do {
    _ = try QuotaParsers.parseCodexWhamUsage(Data("""
{"plan_type":"pro","rate_limit":{"allowed":true,"limit_reached":false,"primary_window":{"used_percent":0,"limit_window_seconds":18000},"secondary_window":{"used_percent":70,"limit_window_seconds":604800,"reset_at":1781140147}}}
""".utf8))
    fail("Codex subscription usage should reject calibrated quota windows when reset timestamps disappear")
} catch QuotaError.schemaDrift {
} catch {
    fail("Codex subscription missing reset timestamp should throw schemaDrift, got \(error)")
}
let codexLifecycle = try! QuotaParsers.parseCodexSubscriptionLifecycle(Data("""
{"active_start":"2026-06-08T16:42:25Z","active_until":"2026-07-08T16:42:25Z","billing_period":"monthly","plan_type":"pro","will_renew":true}
""".utf8))
require(codexLifecycle.planEndsAt != nil, "Codex subscription lifecycle should parse active_until as the plan end date")
require(codexLifecycle.planDisplayName == "Pro", "Codex subscription lifecycle should expose plan_type as a concrete plan name")
let codexPro20xLifecycle = try! QuotaParsers.parseCodexSubscriptionLifecycle(Data("""
{"active_start":"2026-06-08T16:42:25Z","active_until":"2026-07-08T16:42:25Z","billing_period":"monthly","plan_type":"pro","subscription_plan":"chatgptpro","will_renew":true}
""".utf8))
require(codexPro20xLifecycle.planDisplayName == "Pro 20x", "Codex subscription lifecycle should expose chatgptpro as Pro 20x")
let codexPro5xLifecycle = try! QuotaParsers.parseCodexSubscriptionLifecycle(Data("""
{"active_start":"2026-06-08T16:42:25Z","active_until":"2026-07-08T16:42:25Z","billing_period":"monthly","plan_type":"pro","subscription_plan":"chatgptprolite","will_renew":true}
""".utf8))
require(codexPro5xLifecycle.planDisplayName == "Pro 5x", "Codex subscription lifecycle should expose chatgptprolite as Pro 5x")
let codexAccountsCheckLifecycle = try! QuotaParsers.parseCodexSubscriptionLifecycle(Data("""
{"accounts":{"account-redacted":{"account":{"plan_type":"pro"},"entitlement":{"has_active_subscription":true,"subscription_plan":"chatgptpro","renews_at":"2026-07-08T16:42:25+00:00","billing_period":"monthly","billing_currency":"JPY"}}}}
""".utf8))
require(codexAccountsCheckLifecycle.planEndsAt != nil, "Codex accounts/check lifecycle should parse entitlement renews_at as the plan end date")
require(codexAccountsCheckLifecycle.planDisplayName == "Pro 20x", "Codex accounts/check lifecycle should expose entitlement subscription_plan as the concrete Pro tier")
let codexAccountsCheckPro5xLifecycle = try! QuotaParsers.parseCodexSubscriptionLifecycle(Data("""
{"accounts":{"account-redacted":{"account":{"plan_type":"pro"},"entitlement":{"has_active_subscription":true,"subscription_plan":"chatgptprolite","renews_at":"2026-07-08T16:42:25+00:00","billing_period":"monthly","billing_currency":"USD"}}}}
""".utf8))
require(codexAccountsCheckPro5xLifecycle.planDisplayName == "Pro 5x", "Codex accounts/check lifecycle should expose entitlement chatgptprolite as Pro 5x")
let codexRevenueCatOfferingLifecycle = try! QuotaParsers.parseCodexSubscriptionLifecycle(Data("""
{"active_until":"2026-07-08T16:42:25Z","revenuecat_offering_ids":["chatgpt_pro_lite"]}
""".utf8))
require(codexRevenueCatOfferingLifecycle.planDisplayName == "Pro 5x", "Codex subscription lifecycle should inspect RevenueCat offering IDs for Pro 5x")
let codexHumanReadableProLiteLifecycle = try! QuotaParsers.parseCodexSubscriptionLifecycle(Data("""
{"active_until":"2026-07-08T16:42:25Z","subscription_plan":"ChatGPT Pro Lite"}
""".utf8))
require(codexHumanReadableProLiteLifecycle.planDisplayName == "Pro 5x", "Codex subscription lifecycle should normalize human-readable ChatGPT Pro Lite values")

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
