import Foundation
import SwiftUI

enum Provider: String, Codable, CaseIterable, Identifiable {
    // 搜索 Providers
    case tavily = "Tavily"
    case brave = "Brave"
    case serpapi = "SerpAPI"
    case serper = "Serper"
    case exa = "Exa"
    case bocha = "Bocha"
    case anysearch = "AnySearch"
    case wxmp = "微信搜索"
    case querit = "Querit"

    // LLM Providers
    case anthropic = "Anthropic"
    case deepseek = "DeepSeek"
    case xfyunCodingPlan = "讯飞星火"
    case volcengineCodingPlan = "火山引擎"
    case opencodeGo = "OpenCode Go"

    var id: String { rawValue }

    static var visibleCases: [Provider] {
        allCases.filter { $0 != .anthropic }
    }

    static let categoryDisplayOrder = ["AI Search", "LLM"]

    func displayName(language: AppLanguage = AppLanguageStore.shared.language) -> String {
        switch language {
        case .english:
            switch self {
            case .wxmp:
                return "WeChat Search"
            case .xfyunCodingPlan:
                return "XFYun Spark"
            case .volcengineCodingPlan:
                return "Volcengine"
            case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .querit, .anthropic, .deepseek, .opencodeGo:
                return rawValue
            }
        case .simplifiedChinese:
            switch self {
            case .brave:
                return "Brave"
            case .serpapi:
                return "SerpAPI"
            case .serper:
                return "Serper"
            case .exa:
                return "Exa"
            case .bocha:
                return "博查"
            case .anysearch:
                return "AnySearch"
            case .querit:
                return "Querit"
            case .deepseek:
                return "Deepseek"
            case .tavily, .wxmp, .anthropic, .xfyunCodingPlan, .volcengineCodingPlan, .opencodeGo:
                return rawValue
            }
        case .traditionalChinese:
            switch self {
            case .wxmp:
                return "微信搜尋"
            case .xfyunCodingPlan:
                return "訊飛星火"
            case .volcengineCodingPlan:
                return "火山引擎"
            case .bocha:
                return "博查"
            case .deepseek:
                return "Deepseek"
            case .tavily, .brave, .serpapi, .serper, .exa, .anysearch, .querit, .anthropic, .opencodeGo:
                return rawValue
            }
        case .japanese:
            switch self {
            case .wxmp:
                return "WeChat 検索"
            case .xfyunCodingPlan:
                return "XFYun Spark"
            case .volcengineCodingPlan:
                return "Volcengine"
            case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .querit, .anthropic, .deepseek, .opencodeGo:
                return rawValue
            }
        case .korean:
            switch self {
            case .wxmp:
                return "WeChat 검색"
            case .xfyunCodingPlan:
                return "XFYun Spark"
            case .volcengineCodingPlan:
                return "Volcengine"
            case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .querit, .anthropic, .deepseek, .opencodeGo:
                return rawValue
            }
        }
    }

    /// Asset catalog name for custom icon
    var iconAssetName: String {
        "ProviderIcons/\(self)"
    }

    var quotaCheckConsumesSearchQuota: Bool {
        switch self {
        case .brave:
            return true
        case .tavily, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .querit, .anthropic, .deepseek, .xfyunCodingPlan, .volcengineCodingPlan, .opencodeGo:
            return false
        }
    }

    /// SF Symbol fallback name
    var icon: String {
        switch self {
        case .tavily: return "magnifyingglass.circle.fill"
        case .brave: return "shield.lefthalf.fill"
        case .serpapi: return "network"
        case .serper: return "safari.fill"
        case .exa: return "bolt.circle.fill"
        case .bocha: return "search.circle.fill"
        case .anysearch: return "globe"
        case .wxmp: return "message.circle.fill"
        case .querit: return "magnifyingglass"
        case .anthropic: return "brain.head.profile"
        case .deepseek: return "sparkles"
        case .xfyunCodingPlan: return "waveform.path.ecg"
        case .volcengineCodingPlan: return "flame.fill"
        case .opencodeGo: return "terminal.fill"
        }
    }

    var color: Color {
        switch self {
        case .tavily: return .blue
        case .brave: return .orange
        case .serpapi: return .green
        case .serper: return .mint
        case .exa: return .pink
        case .bocha: return .cyan
        case .anysearch: return .purple
        case .wxmp: return .green
        case .querit: return .indigo
        case .anthropic: return Color(hex: "D4A574") // Claude beige
        case .deepseek: return Color(hex: "4D6BFA") // DeepSeek blue
        case .xfyunCodingPlan: return Color(hex: "E23B3B")
        case .volcengineCodingPlan: return Color(hex: "2F6BFF")
        case .opencodeGo: return Color(hex: "111827")
        }
    }

    var category: String {
        switch self {
        case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .querit:
            return "Search"
        case .anthropic, .deepseek, .xfyunCodingPlan, .volcengineCodingPlan, .opencodeGo:
            return "LLM"
        }
    }

    var statusBarCategoryTitle: String {
        switch category {
        case "Search":
            return "AI Search"
        default:
            return category
        }
    }

    var homeVisibleWithoutKeys: Bool {
        switch self {
        case .deepseek, .xfyunCodingPlan, .volcengineCodingPlan, .opencodeGo:
            return true
        case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .querit, .anthropic:
            return false
        }
    }

    var supportsDashboardReauthentication: Bool {
        switch self {
        case .querit, .xfyunCodingPlan, .volcengineCodingPlan, .opencodeGo:
            return true
        case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .anthropic, .deepseek:
            return false
        }
    }

    var cookieDomains: [String] {
        switch self {
        case .xfyunCodingPlan:
            return ["xfyun.cn", "maas.xfyun.cn"]
        case .volcengineCodingPlan:
            return ["volcengine.com", "console.volcengine.com"]
        case .opencodeGo:
            return ["opencode.ai"]
        case .querit:
            return ["querit.ai"]
        case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .anthropic, .deepseek:
            return []
        }
    }

    var dashboardAuthenticationCookieNames: [String] {
        switch self {
        case .querit:
            return ["osduss", "passOsRefreshTk", "osfuid"]
        case .xfyunCodingPlan:
            return ["ssoSessionId", "tenantToken", "atp-auth-token", "account_id"]
        case .volcengineCodingPlan:
            return ["digest", "AccountID", "csrfToken"]
        case .opencodeGo:
            return ["auth"]
        case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .anthropic, .deepseek:
            return []
        }
    }

    var defaultCredentialName: String {
        switch self {
        case .xfyunCodingPlan:
            return "XFYUN_CODING_PLAN_COOKIE"
        case .volcengineCodingPlan:
            return "VOLCENGINE_CODING_PLAN_COOKIE"
        case .opencodeGo:
            return "OPENCODE_GO_COOKIE"
        case .tavily:
            return "TAVILY_API_KEY"
        case .brave:
            return "BRAVE_API_KEY"
        case .serpapi:
            return "SERPAPI_API_KEY"
        case .serper:
            return "SERPER_API_KEY"
        case .exa:
            return "EXA_API_KEY"
        case .bocha:
            return "BOCHA_API_KEY"
        case .anysearch:
            return "ANYSEARCH_API_KEY"
        case .wxmp:
            return "WECHAT_API_KEY"
        case .querit:
            return "QUERIT_COOKIE"
        case .anthropic:
            return "ANTHROPIC_API_KEY"
        case .deepseek:
            return "DEEPSEEK_API_KEY"
        }
    }

    /// 是否支持主动查询 quota（通过 API endpoint）
    var supportsQuotaQuery: Bool {
        switch self {
        case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .querit, .deepseek, .xfyunCodingPlan, .volcengineCodingPlan, .opencodeGo:
            return true
        case .anthropic:
            return false // 只能通过 response header、dashboard，或未公开 quota API
        }
    }

    func localizedUnsupportedQuotaLabel(language: AppLanguage = AppLanguageStore.shared.language) -> String {
        switch self {
        case .querit, .anthropic:
            return dashboardURL == nil ? L10n.t(.quotaUnavailable, language: language) : L10n.t(.openDashboard, language: language)
        case .exa:
            return L10n.t(.adminCredentialRequired, language: language)
        case .tavily, .brave, .serpapi, .serper, .bocha, .anysearch, .wxmp, .deepseek, .xfyunCodingPlan, .volcengineCodingPlan, .opencodeGo:
            return L10n.t(.quotaUnavailable, language: language)
        }
    }

    func unsupportedQuotaDiagnosticMessage(language: AppLanguage = AppLanguageStore.shared.language) -> String {
        switch self {
        case .querit:
            return L10n.t(.queritDashboardOnlyDiagnostic, language: language)
        case .exa:
            return L10n.t(.exaServiceKeyDiagnostic, language: language)
        case .anthropic:
            return L10n.t(.anthropicDashboardOnlyDiagnostic, language: language)
        case .tavily, .brave, .serpapi, .serper, .bocha, .anysearch, .wxmp, .deepseek, .xfyunCodingPlan, .volcengineCodingPlan, .opencodeGo:
            return L10n.t(.quotaCheckNotSupportedDiagnostic, language: language)
        }
    }

    /// Dashboard URL 用于手动查看
    var dashboardURL: String? {
        switch self {
        case .tavily:
            return "https://app.tavily.com/home"
        case .brave:
            return "https://api.search.brave.com/app/dashboard"
        case .serpapi:
            return "https://serpapi.com/dashboard"
        case .serper:
            return "https://serper.dev/api-key"
        case .exa:
            return "https://dashboard.exa.ai/"
        case .bocha:
            return nil
        case .anysearch:
            return nil
        case .wxmp:
            return "https://www.dajiala.com/main/interface?actnav=1"
        case .querit:
            return "https://www.querit.ai/en/dashboard/usage"
        case .anthropic:
            return "https://console.anthropic.com/settings/usage"
        case .deepseek:
            return "https://platform.deepseek.com/usage"
        case .xfyunCodingPlan:
            return "https://maas.xfyun.cn/packageSubscription"
        case .volcengineCodingPlan:
            return "https://console.volcengine.com/ark/region:ark+cn-beijing/openManagement?LLM=%7B%7D&advancedActiveKey=subscribe&projectName=default"
        case .opencodeGo:
            return "https://opencode.ai/workspace/wrk_01KSKR4K4WDJY0JZSCJTMRZ5CV/go"
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Quota Presentation

enum QuotaDataSource: String, Equatable {
    case officialAPI
    case dashboardAPI
    case responseHeader
    case localPolicy
    case unavailable

    var displayName: String {
        switch (self, AppLanguageStore.shared.language) {
        case (.officialAPI, .english):
            return "Official API"
        case (.officialAPI, .simplifiedChinese):
            return "官方 API"
        case (.officialAPI, .traditionalChinese):
            return "官方 API"
        case (.officialAPI, .japanese):
            return "公式 API"
        case (.officialAPI, .korean):
            return "공식 API"
        case (.dashboardAPI, .english):
            return "Dashboard API"
        case (.dashboardAPI, .simplifiedChinese):
            return "控制台接口"
        case (.dashboardAPI, .traditionalChinese):
            return "控制台介面"
        case (.dashboardAPI, .japanese):
            return "ダッシュボード API"
        case (.dashboardAPI, .korean):
            return "대시보드 API"
        case (.responseHeader, .english):
            return "Response Header"
        case (.responseHeader, .simplifiedChinese):
            return "响应 Header"
        case (.responseHeader, .traditionalChinese):
            return "回應 Header"
        case (.responseHeader, .japanese):
            return "レスポンス Header"
        case (.responseHeader, .korean):
            return "응답 Header"
        case (.localPolicy, .english):
            return "Local Policy"
        case (.localPolicy, .simplifiedChinese):
            return "本地规则"
        case (.localPolicy, .traditionalChinese):
            return "本地規則"
        case (.localPolicy, .japanese):
            return "ローカルルール"
        case (.localPolicy, .korean):
            return "로컬 규칙"
        case (.unavailable, .english):
            return "Not Exposed"
        case (.unavailable, .simplifiedChinese):
            return "未公开"
        case (.unavailable, .traditionalChinese):
            return "未公開"
        case (.unavailable, .japanese):
            return "非公開"
        case (.unavailable, .korean):
            return "비공개"
        }
    }
}

struct QuotaPresentation: Equatable {
    let primaryText: String
    let badgeText: String
    let resetText: String
    let percentRemaining: Double?
    let dataSource: QuotaDataSource
    let diagnosticText: String

    var sourceText: String {
        dataSource.displayName
    }
}

struct MenuQuotaSummary: Equatable {
    let availableCount: Int
    let lowCount: Int
    let failedCount: Int

    init(keys: [APIKey]) {
        let activeKeys = keys.filter { $0.isActive && !$0.key.isEmpty }
        availableCount = activeKeys.filter { key in
            switch key.status {
            case .healthy, .low, .usableUnknown:
                return true
            case .exhausted, .expired, .failed, .disabled, .unknown:
                return false
            }
        }.count
        lowCount = activeKeys.filter { $0.isLow || $0.isExhausted }.count
        failedCount = activeKeys.filter { $0.status == .failed || $0.isCredentialExpired }.count
    }
}

struct MenuQuotaItem: Identifiable, Equatable {
    let provider: Provider
    let key: APIKey

    var id: UUID { key.id }

    var presentation: QuotaPresentation {
        key.quotaPresentation
    }

    var canRefresh: Bool {
        key.isActive && !key.key.isEmpty
    }

    static func topItems(from stats: [ProviderStats], limit: Int = 5) -> [MenuQuotaItem] {
        Array(
            stats
                .flatMap { stat in
                    stat.keys.map { MenuQuotaItem(provider: stat.provider, key: $0) }
                }
                .filter { $0.key.isActive }
                .sorted(by: shouldRankBefore)
                .prefix(limit)
        )
    }

    static func attentionItems(from stats: [ProviderStats], limit: Int = 5) -> [MenuQuotaItem] {
        Array(
            stats
                .flatMap { stat in
                    stat.keys.map { MenuQuotaItem(provider: stat.provider, key: $0) }
                }
                .filter { $0.key.isActive && $0.key.needsStatusBarAttention }
                .sorted(by: shouldRankBefore)
                .prefix(limit)
        )
    }

    private static func shouldRankBefore(_ lhs: MenuQuotaItem, _ rhs: MenuQuotaItem) -> Bool {
        let lhsKey = lhs.priorityKey
        let rhsKey = rhs.priorityKey

        if lhsKey.severity != rhsKey.severity {
            return lhsKey.severity < rhsKey.severity
        }

        if lhsKey.percentRemaining != rhsKey.percentRemaining {
            return lhsKey.percentRemaining < rhsKey.percentRemaining
        }

        if lhsKey.remaining != rhsKey.remaining {
            return lhsKey.remaining < rhsKey.remaining
        }

        let lhsProviderIndex = Provider.visibleCases.firstIndex(of: lhs.provider) ?? Int.max
        let rhsProviderIndex = Provider.visibleCases.firstIndex(of: rhs.provider) ?? Int.max
        if lhsProviderIndex != rhsProviderIndex {
            return lhsProviderIndex < rhsProviderIndex
        }

        return lhs.key.name.localizedStandardCompare(rhs.key.name) == .orderedAscending
    }

    private var priorityKey: (severity: Int, percentRemaining: Double, remaining: Int) {
        let severity: Int
        if key.isCredentialExpired {
            severity = 0
        } else if key.isUsageLimitExceeded {
            severity = 1
        } else if key.isExhausted {
            severity = 2
        } else if key.status == .failed {
            severity = 3
        } else if key.quotaPresentation.percentRemaining != nil {
            severity = 4
        } else if key.isUsableWithUnknownQuota {
            severity = 5
        } else if key.isUnlimitedQuota {
            severity = 7
        } else {
            severity = 6
        }

        let percent = key.quotaPresentation.percentRemaining ?? Double.greatestFiniteMagnitude
        let remaining = key.remaining ?? Int.max
        return (severity, percent, remaining)
    }
}

// MARK: - API Key Model

struct APIKey: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var key: String
    var provider: Provider
    var isActive: Bool = true
    var note: String? = nil

    // Quota 信息
    var remaining: Int?
    var limit: Int?
    var resetAt: Date?
    var lastUpdated: Date?
    var lastHTTPStatus: Int?
    var lastDiagnosticMessage: String?
    var quotaLabel: String?

    // 使用量统计（本地记录）
    var usageCount: Int = 0
    var lastUsed: Date?

    var usagePercentage: Double {
        guard !isUnlimitedQuota else { return 0 }
        guard let remaining = remaining, let limit = limit, limit > 0 else { return 0 }
        return Double(limit - remaining) / Double(limit)
    }

    var isLow: Bool {
        guard !isUnlimitedQuota else { return false }
        guard !isUsableWithUnknownQuota else { return false }
        guard !isUsageLimitExceeded else { return false }
        guard let remaining = remaining else { return false }
        return remaining < 100
    }

    var isExhausted: Bool {
        guard !isUnlimitedQuota else { return false }
        if isUsageLimitExceeded { return true }
        guard !isUsableWithUnknownQuota else { return false }
        guard let remaining = remaining else { return false }
        return remaining <= 0
    }

    var isUnlimitedQuota: Bool {
        guard provider == .anysearch else { return false }
        if remaining == Int.max || limit == Int.max {
            return true
        }
        return quotaLabel?.localizedCaseInsensitiveContains("unlimited") == true
    }

    var isCredentialExpired: Bool {
        guard let quotaLabel else { return false }
        return quotaLabel.localizedCaseInsensitiveContains("credential expired")
            || quotaLabel.contains("凭据已过期")
    }

    var isUsableWithUnknownQuota: Bool {
        if quotaLabel == "Search OK · monthly quota not exposed" {
            return true
        }
        if provider == .brave,
           lastHTTPStatus == 200,
           remaining == Int.max,
           limit == Int.max {
            return true
        }
        return provider == .exa
            && quotaLabel?.range(of: #"^[A-Z]{3} [0-9]+(?:\.[0-9]+)? used$"#, options: .regularExpression) != nil
    }

    var isUsageLimitExceeded: Bool {
        if lastHTTPStatus == 402 {
            return true
        }
        return quotaLabel?.localizedCaseInsensitiveContains("usage limit exceeded") == true
            || quotaLabel?.contains("额度已用尽") == true
    }

    var quotaDisplayText: String {
        guard isActive else { return L10n.t(.disabled) }
        if isUnlimitedQuota { return L10n.t(.unlimited) }
        if isUsageLimitExceeded { return L10n.t(.usageLimitExceeded) }

        if let quotaLabel, !quotaLabel.isEmpty {
            return L10n.localizedQuotaLabel(quotaLabel)
        }

        if isUsableWithUnknownQuota { return L10n.t(.usableUnknownQuota) }

        if let remaining, let limit, limit > 0 {
            return "\(remaining) / \(limit)"
        }

        if let remaining {
            return "\(remaining)"
        }

        return L10n.t(.quotaUnavailable)
    }

    var quotaPresentation: QuotaPresentation {
        QuotaPresentation(
            primaryText: quotaPresentationPrimaryText,
            badgeText: remainingBadgeText,
            resetText: resetSummary,
            percentRemaining: percentRemaining,
            dataSource: quotaDataSource,
            diagnosticText: diagnosticSummary
        )
    }

    private var quotaPresentationPrimaryText: String {
        if isUsableWithUnknownQuota {
            switch AppLanguageStore.shared.language {
            case .english:
                return "Search OK · monthly quota not exposed"
            case .simplifiedChinese:
                return "搜索可用 · 未公开月度额度"
            case .traditionalChinese:
                return "搜尋可用 · 未公開月度額度"
            case .japanese:
                return "検索利用可 · 月間クォータ非公開"
            case .korean:
                return "검색 가능 · 월간 할당량 비공개"
            }
        }
        return quotaDisplayText
    }

    private var percentRemaining: Double? {
        guard isActive,
              !isUnlimitedQuota,
              !isUsableWithUnknownQuota,
              let remaining,
              let limit,
              limit > 0,
              remaining != Int.max,
              limit != Int.max else {
            return nil
        }
        return max(0, min(1, Double(remaining) / Double(limit)))
    }

    private var quotaDataSource: QuotaDataSource {
        guard isActive else { return .unavailable }
        if isUnlimitedQuota { return .localPolicy }

        switch provider {
        case .brave:
            return .responseHeader
        case .querit, .xfyunCodingPlan, .volcengineCodingPlan, .opencodeGo:
            return .dashboardAPI
        case .tavily, .serpapi, .serper, .exa, .bocha, .wxmp, .deepseek:
            return .officialAPI
        case .anysearch:
            return .localPolicy
        case .anthropic:
            return .unavailable
        }
    }

    var maskedKey: String {
        guard !key.isEmpty else { return L10n.t(.noKeyValue) }
        guard key.count > 8 else { return "***" }
        return "\(key.prefix(4))••••\(key.suffix(4))"
    }

    var statusBarCredentialLabel: String {
        provider.supportsDashboardReauthentication ? L10n.t(.dashboardSession) : maskedKey
    }

    var needsStatusBarAttention: Bool {
        guard isActive, !key.isEmpty else { return false }
        return isCredentialExpired || isUsageLimitExceeded || isExhausted || isLow || status == .failed
    }

    var resetSummary: String {
        guard isActive else { return L10n.t(.disabled) }

        if let resetAt {
            return L10n.format(.resetDate, L10n.shortDateTime(resetAt))
        }

        switch provider {
        case .tavily:
            return L10n.t(.resetsMonthlyDay1)
        case .deepseek, .wxmp, .bocha, .anysearch:
            return L10n.t(.noResetCycle)
        case .xfyunCodingPlan, .volcengineCodingPlan, .opencodeGo:
            return L10n.t(.dashboardReset)
        case .brave, .serpapi, .serper, .exa, .querit, .anthropic:
            return L10n.t(.resetNotExposed)
        }
    }

    var remainingBadgeText: String {
        guard isActive else { return L10n.t(.off) }

        if isCredentialExpired {
            return L10n.t(.expired)
        }

        if isUsageLimitExceeded {
            return L10n.t(.zeroRemainingBadge)
        }

        if isUsableWithUnknownQuota {
            return L10n.t(.ok)
        }

        if isUnlimitedQuota {
            return "∞"
        }

        guard let remaining else { return L10n.t(.notAvailableShort) }

        if let limit, limit > 0 {
            guard remaining > 0 else { return L10n.t(.zeroRemainingBadge) }
            let percentage = Double(remaining) / Double(limit) * 100
            if percentage < 1 {
                return "<1%"
            }
            return "\(Int(percentage))%"
        }

        return remaining <= 0 ? L10n.t(.zeroRemainingBadge) : "\(remaining)"
    }

    private var currentQuotaSortValue: Int {
        guard isActive, let remaining else { return Int.min }
        if isUnlimitedQuota { return Int.max }
        if isUsableWithUnknownQuota { return 1 }
        if isUsageLimitExceeded { return -1 }
        return remaining
    }

    static func sortedByCurrentQuota(_ keys: [APIKey]) -> [APIKey] {
        keys.sorted { lhs, rhs in
            if lhs.currentQuotaSortValue != rhs.currentQuotaSortValue {
                return lhs.currentQuotaSortValue > rhs.currentQuotaSortValue
            }

            let lhsLimit = lhs.limit ?? Int.min
            let rhsLimit = rhs.limit ?? Int.min
            if lhsLimit != rhsLimit {
                return lhsLimit > rhsLimit
            }

            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    var status: KeyStatus {
        guard isActive else { return .disabled }
        if isCredentialExpired { return .expired }
        if isExhausted { return .exhausted }
        if isUsableWithUnknownQuota { return .usableUnknown }
        if isLow { return .low }
        if remaining != nil || lastHTTPStatus == 200 { return .healthy }
        if lastHTTPStatus != nil || lastDiagnosticMessage != nil { return .failed }
        return .unknown
    }

    var healthDisplayText: String {
        switch status {
        case .healthy:
            return L10n.t(.healthHealthy)
        case .low:
            return L10n.t(.healthLow)
        case .exhausted:
            return isUsageLimitExceeded ? L10n.t(.usageLimitExceeded) : L10n.t(.healthExhausted)
        case .expired:
            return L10n.t(.expired)
        case .usableUnknown:
            return L10n.t(.usableUnknownQuota)
        case .failed:
            return L10n.t(.healthFailed)
        case .disabled:
            return L10n.t(.disabled)
        case .unknown:
            return L10n.t(.healthUnknown)
        }
    }

    var diagnosticSummary: String {
        if isUsageLimitExceeded {
            return L10n.t(.usageLimitExceeded)
        }
        if isUsableWithUnknownQuota {
            return L10n.t(.braveQuotaUnknownDiagnostic)
        }
        if let lastDiagnosticMessage, !lastDiagnosticMessage.isEmpty {
            return L10n.localizedQuotaLabel(lastDiagnosticMessage)
        }
        if let quotaLabel, !quotaLabel.isEmpty {
            return L10n.localizedQuotaLabel(quotaLabel)
        }
        return L10n.t(.notChecked)
    }
}

enum KeyStatus: String {
    case healthy = "正常"
    case low = "不足"
    case exhausted = "耗尽"
    case expired = "过期"
    case usableUnknown = "可用但额度未知"
    case failed = "异常"
    case disabled = "停用"
    case unknown = "未知"

    var color: Color {
        switch self {
        case .healthy: return .green
        case .low: return .orange
        case .exhausted: return .red
        case .expired: return .orange
        case .usableUnknown: return .blue
        case .failed: return .red
        case .disabled: return .gray
        case .unknown: return .gray
        }
    }
}

// MARK: - Provider Stats

struct ProviderStats: Identifiable {
    let provider: Provider
    let keys: [APIKey]

    var id: String { provider.id }

    var sortedKeysByCurrentQuota: [APIKey] {
        APIKey.sortedByCurrentQuota(keys)
    }

    var totalRemaining: Int {
        finiteQuotaKeys.compactMap { $0.remaining }.reduce(0, +)
    }

    var hasKnownQuota: Bool {
        keys.contains { $0.isActive && $0.remaining != nil }
    }

    var hasUnlimitedQuota: Bool {
        keys.contains { $0.isUnlimitedQuota }
    }

    var totalLimit: Int {
        finiteQuotaKeys.compactMap { $0.limit }.reduce(0, +)
    }

    var totalRemainingDisplayText: String {
        if hasUnlimitedQuota { return L10n.t(.unlimited) }
        if usesPercentageQuota {
            return tightestQuotaWindowDisplay ?? formatProviderPercent(totalRemainingPercent)
        }
        return "\(totalRemaining)"
    }

    var totalLimitDisplayText: String {
        if hasUnlimitedQuota { return L10n.t(.unlimited) }
        if usesPercentageQuota {
            return monthlyQuotaWindowDisplay ?? L10n.quotaWindowDisplay("month", formatProviderPercent(totalRemainingPercent))
        }
        return "\(totalLimit)"
    }

    var overallUsage: Double {
        guard totalLimit > 0 else { return 0 }
        return Double(totalLimit - totalRemaining) / Double(totalLimit)
    }

    var availableKeys: Int {
        keys.filter { !$0.isExhausted }.count
    }

    var headerSubtitle: String {
        guard !keys.isEmpty else { return L10n.t(.noKeyConfigured) }
        return "\(L10n.format(.providerKeyCount, keys.count)) · \(L10n.format(.activeCount, availableKeys))"
    }

    var statusBarProviderQuotaText: String {
        guard !activeCredentialKeys.isEmpty else { return L10n.t(.noKeyConfigured) }
        if activeCredentialKeys.contains(where: { $0.isUnlimitedQuota }) {
            return L10n.t(.unlimited)
        }
        if usesPercentageQuota {
            return totalRemainingDisplayText
        }
        if activeCredentialKeys.count == 1, let key = activeCredentialKeys.first {
            return key.quotaPresentation.primaryText
        }
        if activeFiniteQuotaKeys.reduce(0, { $0 + ($1.limit ?? 0) }) > 0 {
            let remaining = activeFiniteQuotaKeys.compactMap { $0.remaining }.reduce(0, +)
            let limit = activeFiniteQuotaKeys.compactMap { $0.limit }.reduce(0, +)
            return "\(remaining) / \(limit)"
        }
        if let firstKnown = sortedKeysByCurrentQuota.first(where: { $0.isActive && !$0.key.isEmpty }) {
            return firstKnown.quotaPresentation.primaryText
        }
        return L10n.t(.quotaUnavailable)
    }

    var statusBarProviderBadgeText: String {
        guard !activeCredentialKeys.isEmpty else { return L10n.t(.notAvailableShort) }
        if activeCredentialKeys.contains(where: { $0.isUnlimitedQuota }) {
            return "∞"
        }
        if usesPercentageQuota {
            return monthlyQuotaWindowDisplay ?? totalRemainingDisplayText
        }
        if let percent = statusBarProviderPercentRemaining {
            if percent <= 0 {
                return L10n.t(.zeroRemainingBadge)
            }
            if percent < 1 {
                return "<1%"
            }
            return "\(Int(percent.rounded(.down)))%"
        }
        if activeCredentialKeys.allSatisfy({ $0.isExhausted || $0.isUsageLimitExceeded }) {
            return L10n.t(.zeroRemainingBadge)
        }
        if activeCredentialKeys.contains(where: { $0.isUsableWithUnknownQuota }) {
            return L10n.t(.ok)
        }
        return L10n.t(.notAvailableShort)
    }

    var statusBarProviderStatusColor: Color {
        guard !activeCredentialKeys.isEmpty else { return .gray }
        if activeCredentialKeys.allSatisfy({ $0.status == .failed || $0.isCredentialExpired || $0.isExhausted }) {
            return .red
        }
        if activeCredentialKeys.contains(where: { $0.isLow || $0.isExhausted || $0.isCredentialExpired || $0.status == .failed }) {
            return .orange
        }
        if activeCredentialKeys.contains(where: { $0.isUsableWithUnknownQuota }) {
            return .blue
        }
        return .green
    }

    private var usesPercentageQuota: Bool {
        switch provider {
        case .xfyunCodingPlan, .volcengineCodingPlan, .opencodeGo:
            return true
        case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .querit, .anthropic, .deepseek:
            return false
        }
    }

    private var totalRemainingPercent: Double {
        let percentageKeys = finiteQuotaKeys.filter { ($0.limit ?? 0) > 0 && $0.remaining != nil }
        guard !percentageKeys.isEmpty else { return 0 }

        let percentages = percentageKeys.map { key -> Double in
            let remaining = Double(key.remaining ?? 0)
            let limit = Double(key.limit ?? 1)
            return max(0, min(100, remaining / limit * 100))
        }
        return percentages.reduce(0, +) / Double(percentages.count)
    }

    private var percentageQuotaWindows: [(name: String, percent: Double)] {
        finiteQuotaKeys
            .compactMap { $0.quotaLabel }
            .flatMap { label -> [(name: String, percent: Double)] in
                label
                    .components(separatedBy: " · ")
                    .compactMap { part in
                        let pieces = part.split(separator: " ", maxSplits: 1).map(String.init)
                        guard pieces.count == 2 else { return nil }
                        let percentText = pieces[1].trimmingCharacters(in: CharacterSet(charactersIn: "%"))
                        guard let percent = Double(percentText) else { return nil }
                        return (name: pieces[0], percent: max(0, min(100, percent)))
                    }
            }
    }

    private var monthlyQuotaWindowDisplay: String? {
        percentageQuotaWindows
            .filter { $0.name == "month" }
            .min { lhs, rhs in lhs.percent < rhs.percent }
            .map { L10n.quotaWindowDisplay($0.name, formatProviderPercent($0.percent)) }
    }

    private var tightestQuotaWindowDisplay: String? {
        percentageQuotaWindows
            .min { lhs, rhs in lhs.percent < rhs.percent }
            .map { L10n.quotaWindowDisplay($0.name, formatProviderPercent($0.percent)) }
    }

    private func formatProviderPercent(_ value: Double) -> String {
        let clamped = max(0, min(100, value))
        if abs(clamped.rounded() - clamped) < 0.05 {
            return "\(Int(clamped.rounded()))%"
        }
        return String(format: "%.1f%%", clamped)
    }

    private var finiteQuotaKeys: [APIKey] {
        keys.filter {
            !$0.isUnlimitedQuota &&
            $0.remaining != Int.max &&
            $0.limit != Int.max
        }
    }

    private var activeCredentialKeys: [APIKey] {
        keys.filter { $0.isActive && !$0.key.isEmpty }
    }

    private var activeFiniteQuotaKeys: [APIKey] {
        activeCredentialKeys.filter {
            !$0.isUnlimitedQuota &&
            $0.remaining != Int.max &&
            $0.limit != Int.max
        }
    }

    private var statusBarProviderPercentRemaining: Double? {
        let quotaKeys = activeFiniteQuotaKeys.filter { ($0.limit ?? 0) > 0 && $0.remaining != nil }
        let totalLimit = quotaKeys.compactMap { $0.limit }.reduce(0, +)
        guard totalLimit > 0 else { return nil }
        let totalRemaining = quotaKeys.compactMap { $0.remaining }.reduce(0, +)
        return max(0, min(100, Double(totalRemaining) / Double(totalLimit) * 100))
    }
}

struct ProviderCategoryStats: Identifiable {
    let title: String
    let stats: [ProviderStats]

    var id: String { title }

    var providerCount: Int {
        stats.count
    }

    var keyCount: Int {
        stats.map { $0.keys.count }.reduce(0, +)
    }

    var activeKeyCount: Int {
        stats.flatMap { $0.keys }.filter { $0.isActive && !$0.isExhausted }.count
    }
}
