import Combine
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }

    static var systemDefault: AppLanguage {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
        return preferred.hasPrefix("zh") ? .simplifiedChinese : .english
    }
}

final class AppLanguageStore: ObservableObject {
    static let shared = AppLanguageStore()
    static let defaultsKey = "appLanguage"

    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Self.defaultsKey)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let rawValue = defaults.string(forKey: Self.defaultsKey),
           let language = AppLanguage(rawValue: rawValue) {
            self.language = language
        } else {
            self.language = .systemDefault
        }
    }
}

enum L10n {
    enum Key {
        case apiKeysTab
        case providersTab
        case diagnosticsTab
        case aboutTab
        case settingsTab
        case apiKeysCount
        case apiKeyConfiguration
        case apiKeyConfigurationDescription
        case importFromEnv
        case addKey
        case language
        case languageTitle
        case languageDescription
        case appLanguage
        case statusBarTransparency
        case statusBarTransparencyDescription
        case apiQuotaTitle
        case noApiKeys
        case noApiKeysMessage
        case openSettings
        case keys
        case providers
        case low
        case categoryCounts
        case activeCount
        case providerKeyCount
        case noKeyConfigured
        case openDashboard
        case updated
        case pullToRefresh
        case disabled
        case quotaUnavailable
        case remainingValue
        case addAPIKey
        case provider
        case keyName
        case apiKey
        case noteOptional
        case cancel
        case add
        case editAPIKey
        case note
        case active
        case quotaStatus
        case lastUpdated
        case delete
        case save
        case providersHeader
        case providersSupported
        case total
        case remaining
        case aboutSubtitle
        case featureSupport
        case featureRealtime
        case featureGlass
        case featureMenuBar
        case version
        case importNoKeys
        case importSummary
        case refreshAlreadyRunning
        case refreshing
        case refreshingProvider
        case updatedJustNow
        case failedRefresh
        case resetDate
        case resetsMonthlyDay1
        case noResetCycle
        case dashboardReset
        case resetNotExposed
        case credentialExpired
        case reauthenticate
        case saveCookie
        case cookieSaved
        case noCookiesFound
        case reauthTitle
        case reauthDescription
        case close
        case unlimited
        case noKeyValue
        case off
        case ok
        case expired
        case importPanelTitle
        case importPanelMessage
        case importedFromEnv
        case importedFromClaude
        case dashboardSession
        case diagnosticsDescription
        case healthStatus
        case lastHTTPStatus
        case httpNotRequested
        case diagnosticMessage
        case notChecked
        case usableUnknownQuota
        case usageLimitExceeded
        case healthHealthy
        case healthLow
        case healthExhausted
        case healthFailed
        case healthUnknown
        case braveQuotaUnknownDiagnostic
        case queritDashboardOnlyDiagnostic
        case exaServiceKeyDiagnostic
        case anthropicDashboardOnlyDiagnostic
        case quotaCheckNotSupportedDiagnostic
        case quotaConsumingRefreshWarning
        case monthlyCreditsFormat
        case monthlyRequestsFormat
        case searchesLeftFormat
        case creditsLeftFormat
        case noProviderCreditsAvailableFormat
        case moneyAvailableFormat
        case moneyBalanceFormat
        case manualRefreshOnly
        case zeroRemainingBadge
        case notAvailableShort
        case braveQuotaHeadersDiagnostic
        case braveUsageLimitDiagnostic
    }

    static func t(_ key: Key, language: AppLanguage = AppLanguageStore.shared.language) -> String {
        switch language {
        case .english:
            return english[key] ?? ""
        case .simplifiedChinese:
            return simplifiedChinese[key] ?? english[key] ?? ""
        }
    }

    static func format(_ key: Key, _ args: CVarArg..., language: AppLanguage = AppLanguageStore.shared.language) -> String {
        String(format: t(key, language: language), locale: Locale(identifier: language.rawValue), arguments: args)
    }

    static func categoryTitle(_ title: String, language: AppLanguage = AppLanguageStore.shared.language) -> String {
        guard language == .simplifiedChinese else { return title }
        switch title {
        case "AI Search":
            return "AI 搜索"
        case "LLM":
            return "LLM"
        default:
            return title
        }
    }

    static func shortDateTime(_ date: Date, language: AppLanguage = AppLanguageStore.shared.language) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.rawValue)
        switch language {
        case .english:
            formatter.dateFormat = "MMM d HH:mm"
        case .simplifiedChinese:
            formatter.dateFormat = "M月d日 HH:mm"
        }
        return formatter.string(from: date)
    }

    static func quotaPeriodTitle(_ title: String, language: AppLanguage = AppLanguageStore.shared.language) -> String {
        switch language {
        case .english:
            return title
        case .simplifiedChinese:
            switch title {
            case "5h":
                return "5 小时"
            case "week":
                return "周"
            case "month":
                return "月"
            default:
                return title
            }
        }
    }

    static func quotaWindowDisplay(_ name: String, _ percentageText: String, language: AppLanguage = AppLanguageStore.shared.language) -> String {
        "\(quotaPeriodTitle(name, language: language)) \(percentageText)"
    }

    static func localizedQuotaLabel(_ label: String, language: AppLanguage = AppLanguageStore.shared.language) -> String {
        if let exact = localizedExactQuotaLabel(label, language: language) {
            return exact
        }

        return label
            .components(separatedBy: " · ")
            .map { part in
                if let exact = localizedExactQuotaLabel(part, language: language) {
                    return exact
                }
                if let formatted = localizedStructuredQuotaLabel(part, language: language) {
                    return formatted
                }
                let pieces = part.split(separator: " ", maxSplits: 1).map(String.init)
                guard pieces.count == 2 else { return part }
                let period = pieces[0]
                let value = pieces[1]
                guard ["5h", "week", "month"].contains(period),
                      value.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("%") else {
                    return part
                }
                return quotaWindowDisplay(period, value, language: language)
            }
            .joined(separator: " · ")
    }

    private static func localizedExactQuotaLabel(_ label: String, language: AppLanguage) -> String? {
        switch label {
        case "Search OK · monthly quota not exposed":
            return t(.usableUnknownQuota, language: language)
        case "Usage limit exceeded":
            return t(.usageLimitExceeded, language: language)
        case "Unlimited free usage":
            return t(.unlimited, language: language)
        case "Unavailable":
            return t(.quotaUnavailable, language: language)
        case "Manual refresh only":
            return t(.manualRefreshOnly, language: language)
        case "Search works, but Brave did not expose monthly quota for this key.",
             "Search works, but monthly quota is hidden by Brave.":
            return t(.braveQuotaUnknownDiagnostic, language: language)
        case "Search works and Brave returned quota headers.":
            return t(.braveQuotaHeadersDiagnostic, language: language)
        case "Brave returned HTTP 402 usage limit exceeded.":
            return t(.braveUsageLimitDiagnostic, language: language)
        default:
            return nil
        }
    }

    private static func localizedStructuredQuotaLabel(_ label: String, language: AppLanguage) -> String? {
        if let match = regexCapture(label, pattern: #"^([0-9]+) / ([0-9]+) monthly credits$"#) {
            return format(.monthlyCreditsFormat, match[0], match[1], language: language)
        }
        if let match = regexCapture(label, pattern: #"^([0-9]+) / ([0-9]+) monthly requests$"#) {
            return format(.monthlyRequestsFormat, match[0], match[1], language: language)
        }
        if let match = regexCapture(label, pattern: #"^([0-9]+) searches left$"#) {
            return format(.searchesLeftFormat, match[0], language: language)
        }
        if let match = regexCapture(label, pattern: #"^([0-9]+) credits left$"#) {
            return format(.creditsLeftFormat, match[0], language: language)
        }
        if let match = regexCapture(label, pattern: #"^No ([A-Za-z0-9 ]+) credits available$"#) {
            return format(.noProviderCreditsAvailableFormat, match[0], language: language)
        }
        if let match = regexCapture(label, pattern: #"^([A-Z]{3}) ([0-9]+(?:\.[0-9]+)?) available$"#) {
            return format(.moneyAvailableFormat, match[0], match[1], language: language)
        }
        if let match = regexCapture(label, pattern: #"^([A-Z]{3}) ([0-9]+(?:\.[0-9]+)?) balance$"#) {
            return format(.moneyBalanceFormat, match[0], match[1], language: language)
        }
        return nil
    }

    private static func regexCapture(_ value: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, range: range),
              match.range.location == 0,
              match.range.length == range.length,
              match.numberOfRanges > 1 else {
            return nil
        }

        return (1..<match.numberOfRanges).compactMap { index in
            guard let captureRange = Range(match.range(at: index), in: value) else {
                return nil
            }
            return String(value[captureRange])
        }
    }

    private static let english: [Key: String] = [
        .apiKeysTab: "Credentials",
        .providersTab: "Quota Overview",
        .diagnosticsTab: "Diagnostics",
        .aboutTab: "About",
        .settingsTab: "Language & Appearance",
        .apiKeysCount: "%d credentials",
        .apiKeyConfiguration: "Credential Configuration",
        .apiKeyConfigurationDescription: "Add API keys or dashboard session cookies. New credentials appear below by provider.",
        .importFromEnv: "Import from .env",
        .addKey: "Add Credential",
        .language: "Language",
        .languageTitle: "Language",
        .languageDescription: "Choose the display language and menu bar appearance for QuotaBar.",
        .appLanguage: "App Language",
        .statusBarTransparency: "Status Bar Transparency",
        .statusBarTransparencyDescription: "Adjust the frosted-glass menu transparency.",
        .apiQuotaTitle: "API Quota",
        .noApiKeys: "No credentials",
        .noApiKeysMessage: "Import a .env file or add credentials on the Credentials page to show provider quotas here.",
        .openSettings: "Open Settings",
        .keys: "Keys",
        .providers: "Providers",
        .low: "Low",
        .categoryCounts: "%d providers · %d keys",
        .activeCount: "%d active",
        .providerKeyCount: "%d keys",
        .noKeyConfigured: "No key configured",
        .openDashboard: "Open Dashboard",
        .updated: "Updated %@",
        .pullToRefresh: "Pull to refresh",
        .disabled: "Disabled",
        .quotaUnavailable: "Quota unavailable",
        .remainingValue: "%d remaining",
        .addAPIKey: "Add Credential",
        .provider: "Provider",
        .keyName: "Credential Name",
        .apiKey: "API Key",
        .noteOptional: "Note (optional)",
        .cancel: "Cancel",
        .add: "Add",
        .editAPIKey: "Edit Credential",
        .note: "Note",
        .active: "Active",
        .quotaStatus: "Quota Status",
        .lastUpdated: "Last Updated",
        .delete: "Delete",
        .save: "Save",
        .providersHeader: "Quota Overview",
        .providersSupported: "%d configured · %d supported",
        .total: "Total",
        .remaining: "Remaining",
        .aboutSubtitle: "Monitor your API quotas in real time",
        .featureSupport: "Support multiple API providers",
        .featureRealtime: "Provider-level quota refresh",
        .featureGlass: "Frosted glass menu bar UI",
        .featureMenuBar: "Menu bar quick access",
        .version: "Version 1.0.0",
        .importNoKeys: "No supported API keys found in %@.",
        .importSummary: "Imported %d new and updated %d key(s).",
        .refreshAlreadyRunning: "Refresh already running",
        .refreshing: "Refreshing...",
        .refreshingProvider: "Refreshing %@...",
        .updatedJustNow: "Updated just now",
        .failedRefresh: "Failed to refresh %d key(s)",
        .resetDate: "Resets %@",
        .resetsMonthlyDay1: "Resets monthly on day 1",
        .noResetCycle: "No reset cycle",
        .dashboardReset: "Dashboard reset",
        .resetNotExposed: "Reset not exposed",
        .credentialExpired: "Credential expired",
        .reauthenticate: "Re-authenticate",
        .saveCookie: "Save Cookie",
        .cookieSaved: "Cookie saved",
        .noCookiesFound: "No matching cookies found",
        .reauthTitle: "Re-authenticate %@",
        .reauthDescription: "Log in to the provider dashboard, then save the current WebView cookies.",
        .close: "Close",
        .unlimited: "Unlimited",
        .noKeyValue: "No key value",
        .off: "Off",
        .ok: "OK",
        .expired: "Expired",
        .importPanelTitle: "Import credentials from .env",
        .importPanelMessage: "Choose a .env file containing supported API keys or dashboard session cookies.",
        .importedFromEnv: "Imported from .env",
        .importedFromClaude: "Imported from ~/.claude/settings.json",
        .dashboardSession: "Dashboard session cookie",
        .diagnosticsDescription: "Review each credential's latest check result, HTTP status, and provider-specific diagnostic note.",
        .healthStatus: "Health",
        .lastHTTPStatus: "HTTP",
        .httpNotRequested: "Not requested",
        .diagnosticMessage: "Diagnostic",
        .notChecked: "Not checked",
        .usableUnknownQuota: "Usable · quota unknown",
        .usageLimitExceeded: "Usage limit exceeded",
        .healthHealthy: "Healthy",
        .healthLow: "Low quota",
        .healthExhausted: "Exhausted",
        .healthFailed: "Check failed",
        .healthUnknown: "Unknown",
        .braveQuotaUnknownDiagnostic: "Search works, but Brave did not expose monthly quota for this key.",
        .queritDashboardOnlyDiagnostic: "Querit does not expose a public API-key usage endpoint. Open the usage dashboard to check quota.",
        .exaServiceKeyDiagnostic: "Exa usage requires an Admin API service key; a plain search API key cannot query quota.",
        .anthropicDashboardOnlyDiagnostic: "Anthropic does not expose this quota through a standard API-key usage endpoint. Open the dashboard to check usage.",
        .quotaCheckNotSupportedDiagnostic: "This provider does not expose a supported quota-check endpoint.",
        .quotaConsumingRefreshWarning: "Manual refresh for this provider consumes one real search request.",
        .monthlyCreditsFormat: "%@ / %@ monthly credits",
        .monthlyRequestsFormat: "%@ / %@ monthly requests",
        .searchesLeftFormat: "%@ searches left",
        .creditsLeftFormat: "%@ credits left",
        .noProviderCreditsAvailableFormat: "No %@ credits available",
        .moneyAvailableFormat: "%@ %@ available",
        .moneyBalanceFormat: "%@ %@ balance",
        .manualRefreshOnly: "Manual refresh only",
        .zeroRemainingBadge: "0 left",
        .notAvailableShort: "N/A",
        .braveQuotaHeadersDiagnostic: "Search works and Brave returned quota headers.",
        .braveUsageLimitDiagnostic: "Brave returned HTTP 402 usage limit exceeded.",
    ]

    private static let simplifiedChinese: [Key: String] = [
        .apiKeysTab: "配置凭据",
        .providersTab: "观察额度",
        .diagnosticsTab: "诊断",
        .aboutTab: "关于",
        .settingsTab: "语言与外观",
        .apiKeysCount: "%d 个凭据",
        .apiKeyConfiguration: "配置凭据",
        .apiKeyConfigurationDescription: "添加 API Key 或控制台会话 Cookie。新增凭据会按服务商显示在下方。",
        .importFromEnv: "从 .env 导入",
        .addKey: "添加凭据",
        .language: "语言",
        .languageTitle: "语言",
        .languageDescription: "选择 QuotaBar 的界面语言和状态栏外观。",
        .appLanguage: "应用语言",
        .statusBarTransparency: "状态栏透明度",
        .statusBarTransparencyDescription: "调整状态栏弹窗的磨砂玻璃透明程度。",
        .apiQuotaTitle: "API 额度",
        .noApiKeys: "没有凭据",
        .noApiKeysMessage: "导入 .env 文件或在凭据页添加凭据后，这里会显示各服务商的额度。",
        .openSettings: "打开设置",
        .keys: "密钥",
        .providers: "服务商",
        .low: "低额度",
        .categoryCounts: "%d 个服务商 · %d 个密钥",
        .activeCount: "%d 个可用",
        .providerKeyCount: "%d 个密钥",
        .noKeyConfigured: "未配置密钥",
        .openDashboard: "打开控制台",
        .updated: "%@ 更新",
        .pullToRefresh: "点击服务商刷新",
        .disabled: "已停用",
        .quotaUnavailable: "额度不可用",
        .remainingValue: "剩余 %d",
        .addAPIKey: "添加凭据",
        .provider: "服务商",
        .keyName: "凭据名称",
        .apiKey: "API 密钥",
        .noteOptional: "备注（可选）",
        .cancel: "取消",
        .add: "添加",
        .editAPIKey: "编辑凭据",
        .note: "备注",
        .active: "启用",
        .quotaStatus: "额度状态",
        .lastUpdated: "上次更新",
        .delete: "删除",
        .save: "保存",
        .providersHeader: "观察额度",
        .providersSupported: "已配置 %d 个 · 支持 %d 个",
        .total: "总量",
        .remaining: "剩余",
        .aboutSubtitle: "实时观察 API 额度",
        .featureSupport: "支持多个 API 服务商",
        .featureRealtime: "按服务商单独刷新额度",
        .featureGlass: "磨砂玻璃状态栏界面",
        .featureMenuBar: "状态栏快速访问",
        .version: "版本 1.0.0",
        .importNoKeys: "在 %@ 中没有找到支持的 API 密钥。",
        .importSummary: "已导入 %d 个，新更新 %d 个密钥。",
        .refreshAlreadyRunning: "刷新正在进行",
        .refreshing: "正在刷新...",
        .refreshingProvider: "正在刷新 %@...",
        .updatedJustNow: "刚刚已更新",
        .failedRefresh: "%d 个密钥刷新失败",
        .resetDate: "%@ 重置",
        .resetsMonthlyDay1: "每月 1 日重置",
        .noResetCycle: "无重置周期",
        .dashboardReset: "控制台周期",
        .resetNotExposed: "未公开重置时间",
        .credentialExpired: "凭据已过期",
        .reauthenticate: "重新认证",
        .saveCookie: "保存 Cookie",
        .cookieSaved: "Cookie 已保存",
        .noCookiesFound: "没有找到匹配的 Cookie",
        .reauthTitle: "重新认证 %@",
        .reauthDescription: "登录服务商控制台后，保存当前 WebView Cookie。",
        .close: "关闭",
        .unlimited: "无限",
        .noKeyValue: "没有密钥值",
        .off: "关闭",
        .ok: "正常",
        .expired: "过期",
        .importPanelTitle: "从 .env 导入凭据",
        .importPanelMessage: "选择包含受支持 API Key 或控制台会话 Cookie 的 .env 文件。",
        .importedFromEnv: "从 .env 导入",
        .importedFromClaude: "从 ~/.claude/settings.json 导入",
        .dashboardSession: "控制台会话 Cookie",
        .diagnosticsDescription: "查看每个凭据最近一次检查结果、HTTP 状态和服务商诊断信息。",
        .healthStatus: "健康状态",
        .lastHTTPStatus: "HTTP",
        .httpNotRequested: "未请求",
        .diagnosticMessage: "诊断信息",
        .notChecked: "尚未检查",
        .usableUnknownQuota: "可用 · 额度未知",
        .usageLimitExceeded: "额度已用尽",
        .healthHealthy: "正常",
        .healthLow: "额度偏低",
        .healthExhausted: "已耗尽",
        .healthFailed: "检查失败",
        .healthUnknown: "未知",
        .braveQuotaUnknownDiagnostic: "搜索可用，但 Brave 没有公开这个 key 的月度额度。",
        .queritDashboardOnlyDiagnostic: "Querit 没有公开可用 API Key 认证查询的额度接口；请打开用量控制台查看。",
        .exaServiceKeyDiagnostic: "Exa 用量查询需要 Admin API service key，普通搜索 API Key 不能查询额度。",
        .anthropicDashboardOnlyDiagnostic: "Anthropic 没有通过标准 API Key 用量接口公开该额度；请打开控制台查看。",
        .quotaCheckNotSupportedDiagnostic: "该服务商没有公开受支持的额度查询接口。",
        .quotaConsumingRefreshWarning: "手动刷新该服务商会消耗 1 次真实搜索请求。",
        .monthlyCreditsFormat: "%@ / %@ 月度积分",
        .monthlyRequestsFormat: "%@ / %@ 月度请求",
        .searchesLeftFormat: "剩余 %@ 次搜索",
        .creditsLeftFormat: "剩余 %@ 积分",
        .noProviderCreditsAvailableFormat: "没有可用的 %@ 积分",
        .moneyAvailableFormat: "可用 %@ %@",
        .moneyBalanceFormat: "余额 %@ %@",
        .manualRefreshOnly: "仅支持手动刷新",
        .zeroRemainingBadge: "剩余 0",
        .notAvailableShort: "未知",
        .braveQuotaHeadersDiagnostic: "搜索可用，Brave 返回了额度 Header。",
        .braveUsageLimitDiagnostic: "Brave 返回 HTTP 402，额度已用尽。",
    ]
}
