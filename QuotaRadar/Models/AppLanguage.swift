import Combine
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        case .traditionalChinese:
            return "繁體中文"
        case .japanese:
            return "日本語"
        case .korean:
            return "한국어"
        }
    }

    static var systemDefault: AppLanguage {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
        if preferred.hasPrefix("zh-hant") || preferred.hasPrefix("zh-tw") || preferred.hasPrefix("zh-hk") || preferred.hasPrefix("zh-mo") {
            return .traditionalChinese
        }
        if preferred.hasPrefix("zh") {
            return .simplifiedChinese
        }
        if preferred.hasPrefix("ja") {
            return .japanese
        }
        if preferred.hasPrefix("ko") {
            return .korean
        }
        return .english
    }
}

struct LocalizedTextDescriptor: Codable, Equatable {
    enum Kind: String, Codable {
        case localized
        case quotaWindows
    }

    var kind: Kind = .localized
    var key: L10n.Key?
    var arguments: [String] = []
    var quotaWindows: [QuotaWindowText] = []

    static func localized(_ key: L10n.Key, _ arguments: String...) -> LocalizedTextDescriptor {
        LocalizedTextDescriptor(kind: .localized, key: key, arguments: arguments, quotaWindows: [])
    }

    static func quotaWindows(_ windows: [QuotaWindowText]) -> LocalizedTextDescriptor {
        LocalizedTextDescriptor(kind: .quotaWindows, key: nil, arguments: [], quotaWindows: windows)
    }

    static func fromLegacyLabel(_ label: String) -> LocalizedTextDescriptor? {
        let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if isBusinessInvocationLabel(normalized) {
            return .localized(.businessInvocationKeyUnsupportedDiagnostic)
        }
        switch normalized {
        case "Search OK · monthly quota not exposed":
            return .localized(.usableUnknownQuota)
        case "Usage limit exceeded":
            return .localized(.usageLimitExceeded)
        case "Unlimited free usage":
            return .localized(.unlimited)
        case "Unavailable", "Quota unavailable":
            return .localized(.quotaUnavailable)
        case "No subscribed plan", "No subscription found":
            return .localized(.noSubscribedPlan)
        case "Manual refresh only":
            return .localized(.manualRefreshOnly)
        case "Admin credential required",
             "Management API credential required",
             "API Key required",
             "需要管理员凭据",
             "需要管理 API 凭据",
             "需要 API 密钥",
             "需要管理員憑證",
             "需要管理 API 憑證",
             "需要 API 金鑰",
             "管理者認証情報が必要",
             "管理 API 認証情報が必要",
             "API キーが必要",
             "관리자 자격 증명 필요",
             "관리 API 자격 증명 필요",
             "API 키 필요":
            return .localized(.adminCredentialRequired)
        case "Credential expired", "凭据已过期", "憑證已過期", "認証情報の期限切れ", "자격 증명 만료됨":
            return .localized(.credentialExpired)
        case "Cookie saved":
            return .localized(.cookieSaved)
        case "Search works, but Brave did not expose monthly quota for this key.",
             "Search works, but monthly quota is hidden by Brave.":
            return .localized(.braveQuotaUnknownDiagnostic)
        case "Search works and Brave returned quota headers.":
            return .localized(.braveQuotaHeadersDiagnostic)
        case "Brave returned HTTP 402 usage limit exceeded.":
            return .localized(.braveUsageLimitDiagnostic)
        case "Querit account endpoint returned monthly request quota.",
             "Querit account endpoint returned monthly usage, but no plan quota limit.":
            return .localized(.queritAccountDiagnostic)
        case "Exa Team Management usage endpoint returned billing usage.":
            return .localized(.exaBillingUsageDiagnostic)
        case "Quota check not supported for this provider":
            return .localized(.quotaCheckNotSupportedDiagnostic)
        case "Invalid response from server", "服务器响应无效", "伺服器回應無效", "サーバー応答が無効です", "서버 응답이 올바르지 않습니다":
            return .localized(.quotaErrorInvalidResponse)
        case "Rate limit exceeded":
            return .localized(.quotaErrorRateLimited)
        case "Invalid API key", "API Key 无效", "API Key 無效", "API キーが無効です", "API 키가 유효하지 않습니다":
            return .localized(.quotaErrorInvalidAPIKey)
        case "Quota was checked recently":
            return .localized(.quotaErrorCooldown)
        default:
            break
        }

        if let match = regexCapture(normalized, pattern: #"^([0-9]+) / ([0-9]+) monthly credits$"#) {
            return .localized(.monthlyCreditsFormat, match[0], match[1])
        }
        if let match = regexCapture(normalized, pattern: #"^([0-9]+) / ([0-9]+) monthly requests$"#) {
            return .localized(.monthlyRequestsFormat, match[0], match[1])
        }
        if let match = regexCapture(normalized, pattern: #"^([0-9]+) monthly requests used$"#) {
            return .localized(.monthlyRequestsUsedFormat, match[0])
        }
        if let match = regexCapture(normalized, pattern: #"^([0-9]+) / ([0-9]+) tokens$"#) {
            return .localized(.tokenQuotaFormat, match[0], match[1])
        }
        if let match = regexCapture(normalized, pattern: #"^([0-9]+) searches left$"#) {
            return .localized(.searchesLeftFormat, match[0])
        }
        if let match = regexCapture(normalized, pattern: #"^([0-9]+) credits left$"#) {
            return .localized(.creditsLeftFormat, match[0])
        }
        if let match = regexCapture(normalized, pattern: #"^No ([A-Za-z0-9 ]+) credits available$"#) {
            return .localized(.noProviderCreditsAvailableFormat, match[0])
        }
        if let match = regexCapture(normalized, pattern: #"^([A-Z]{3}) ([0-9]+(?:\.[0-9]+)?) available$"#) {
            return .localized(.moneyAvailableFormat, match[0], match[1])
        }
        if let match = regexCapture(normalized, pattern: #"^([A-Z]{3}) ([0-9]+(?:\.[0-9]+)?) balance$"#) {
            return .localized(.moneyBalanceFormat, match[0], match[1])
        }
        if let match = regexCapture(normalized, pattern: #"^([A-Z]{3}) ([0-9]+(?:\.[0-9]+)?) used$"#) {
            return .localized(.moneyUsedFormat, match[0], match[1])
        }
        if let networkErrorKey = L10n.knownNetworkErrorKey(normalized) {
            return .localized(networkErrorKey)
        }
        if let detail = L10n.localizedNetworkErrorDetail(normalized) {
            return .localized(.quotaErrorNetworkFormat, detail)
        }

        let windows = normalized
            .components(separatedBy: " · ")
            .compactMap { part -> QuotaWindowText? in
                let pieces = part.split(separator: " ", maxSplits: 1).map(String.init)
                guard pieces.count == 2,
                      pieces[1].trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("%") else {
                    return nil
                }
                return QuotaWindowText(name: pieces[0], percentText: pieces[1])
            }
        if !windows.isEmpty, windows.count == normalized.components(separatedBy: " · ").count {
            return .quotaWindows(windows)
        }

        return nil
    }

    func render(language: AppLanguage = AppLanguageStore.shared.language) -> String {
        switch kind {
        case .localized:
            guard let key else { return "" }
            if isMoneyFormat(key), arguments.count >= 2 {
                let moneyText = L10n.localizedMoneyText(
                    currency: arguments[0],
                    amount: arguments[1],
                    language: language
                )
                return L10n.format(key, moneyText, language: language)
            }
            guard !arguments.isEmpty else {
                return L10n.t(key, language: language)
            }
            return String(
                format: L10n.t(key, language: language),
                locale: Locale(identifier: language.rawValue),
                arguments: arguments.map { $0 as CVarArg }
            )
        case .quotaWindows:
            return quotaWindows
                .map { L10n.quotaWindowDisplay($0.name, $0.percentText, language: language) }
                .joined(separator: " · ")
        }
    }

    private func isMoneyFormat(_ key: L10n.Key) -> Bool {
        key == .moneyAvailableFormat || key == .moneyBalanceFormat || key == .moneyUsedFormat
    }

    private static func isBusinessInvocationLabel(_ label: String) -> Bool {
        let normalized = label.lowercased()
        if normalized == "use dashboard cookie" || normalized == "use dashboard cookie." {
            return true
        }
        return normalized.contains("business invocation key")
            && normalized.contains("quota monitoring")
            && normalized.contains("dashboard")
            && normalized.contains("cookie")
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
}

struct QuotaWindowText: Codable, Equatable {
    let name: String
    let percentText: String
    var resetAt: Date? = nil
    var remainingText: String? = nil

    var displayText: String {
        L10n.quotaWindowDisplay(name, percentText)
    }

    var resetSummary: String {
        guard let resetAt else { return L10n.t(.resetNotExposed) }
        return L10n.format(.resetDate, L10n.shortDateTime(resetAt))
    }

    var resetDetailText: String {
        L10n.quotaWindowResetDisplay(name, percentText, resetAt: resetAt)
    }

    var detailValueText: String? {
        if let remainingText {
            return remainingText
        }
        if let resetAt {
            return L10n.format(.resetDate, L10n.shortDateTime(resetAt))
        }
        return nil
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
    enum Key: String, CaseIterable, Codable {
        case apiKeysTab
        case providersTab
        case diagnosticsTab
        case aboutTab
        case settingsTab
        case settingsWindowTitle
        case apiKeysCount
        case apiKeyConfiguration
        case apiKeyConfigurationDescription
        case importFromEnv
        case addKey
        case language
        case languageTitle
        case languageDescription
        case appLanguage
        case settingsGeneralSection
        case settingsRefreshSection
        case settingsAppearanceSection
        case statusBarTransparency
        case statusBarTransparencyDescription
        case launchAtLogin
        case launchAtLoginDescription
        case autoRefreshInterval
        case autoRefreshDescription
        case autoRefreshBraveWarning
        case quotaConsumingAutoRefreshInterval
        case quotaConsumingAutoRefreshWarning
        case autoRefreshFiveMinutes
        case autoRefreshFifteenMinutes
        case autoRefreshThirtyMinutes
        case autoRefreshOneHour
        case quotaConsumingAutoRefreshSixHours
        case quotaConsumingAutoRefreshTwelveHours
        case quotaConsumingAutoRefreshOneDay
        case apiQuotaTitle
        case noApiKeys
        case noApiKeysMessage
        case openSettings
        case keys
        case providers
        case available
        case failed
        case needsAttention
        case noAttentionItems
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
        case noSubscribedPlan
        case remainingValue
        case addAPIKey
        case provider
        case keyName
        case apiKey
        case apiKeyForCopy
        case apiKeyForCopyHelp
        case apiKeySaved
        case apiKeyStoredForCopyOnly
        case adminCredential
        case credentialValue
        case showCredential
        case hideCredential
        case credentialHelp
        case quotaMonitoringAuthorization
        case quotaMonitoringAuthorizationHelp
        case pasteCurl
        case curlImportFailed
        case noteOptional
        case cancel
        case add
        case editAPIKey
        case copyCredential
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
        case planEndsDate
        case resetsMonthlyDay1
        case noResetCycle
        case resetNotExposed
        case credentialExpired
        case reauthenticate
        case saveCookie
        case cookieSaved
        case noCookiesFound
        case missingRequiredCookies
        case reauthTitle
        case reauthDescription
        case autoCookieSaveHint
        case autoSavingCookie
        case checkingCookie
        case reauthStillUnauthorized
        case reauthValidationFailed
        case close
        case unlimited
        case noKeyValue
        case adminCredentialRequired
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
        case businessInvocationKeyUnsupportedDiagnostic
        case businessInvocationKeySaved
        case businessInvocationKeyQuotaInstruction
        case businessInvocationKey
        case useDashboardCookie
        case quotaCheckNotSupportedDiagnostic
        case quotaConsumingRefreshWarning
        case dashboardCookieCapabilityNote
        case quotaParsingNotImplementedCapabilityNote
        case tencentCloudTokenPlanCredentialNote
        case monthlyCreditsFormat
        case monthlyRequestsFormat
        case monthlyRequestsUsedFormat
        case searchesLeftFormat
        case creditsLeftFormat
        case noProviderCreditsAvailableFormat
        case moneyAvailableFormat
        case moneyBalanceFormat
        case moneyUsedFormat
        case manualRefreshOnly
        case zeroRemainingBadge
        case notAvailableShort
        case braveQuotaHeadersDiagnostic
        case braveUsageLimitDiagnostic
        case queritAccountDiagnostic
        case exaBillingUsageDiagnostic
        case tokenQuotaFormat
        case quotaErrorInvalidResponse
        case quotaErrorNetworkFormat
        case quotaErrorTimedOutDetail
        case quotaErrorTimedOutNetwork
        case quotaErrorOfflineNetwork
        case quotaErrorConnectionLostNetwork
        case quotaErrorHostNotFoundNetwork
        case quotaErrorCannotConnectNetwork
        case quotaErrorRateLimited
        case quotaErrorInvalidAPIKey
        case quotaErrorCooldown
    }

    static func t(_ key: Key, language: AppLanguage = AppLanguageStore.shared.language) -> String {
        switch language {
        case .english:
            return english[key] ?? ""
        case .simplifiedChinese:
            return simplifiedChinese[key] ?? english[key] ?? ""
        case .traditionalChinese:
            if let value = traditionalChinese[key] {
                return value
            }
            if let value = simplifiedChinese[key] {
                return simplifiedChineseToTraditional(value)
            }
            return english[key] ?? ""
        case .japanese:
            return japanese[key] ?? english[key] ?? ""
        case .korean:
            return korean[key] ?? english[key] ?? ""
        }
    }

    static func missingTranslationKeys(language: AppLanguage) -> [Key] {
        Key.allCases.filter { t($0, language: language).isEmpty }
    }

    static func fallbackTranslationKeys(language: AppLanguage) -> [Key] {
        guard language != .english else { return [] }
        return Key.allCases.filter { key in
            guard !allowedSharedEnglishKeys.contains(key) else { return false }
            let localized = t(key, language: language)
            return !localized.isEmpty && localized == t(key, language: .english)
        }
    }

    private static let allowedSharedEnglishKeys: Set<Key> = [
        .lastHTTPStatus
    ]

    static func format(_ key: Key, _ args: CVarArg..., language: AppLanguage = AppLanguageStore.shared.language) -> String {
        String(format: t(key, language: language), locale: Locale(identifier: language.rawValue), arguments: args)
    }

    static func categoryTitle(_ title: String, language: AppLanguage = AppLanguageStore.shared.language) -> String {
        switch language {
        case .english:
            return title
        case .simplifiedChinese:
            switch title {
            case "AI Search": return "AI 搜索"
            case "LLM": return "LLM"
            default: return title
            }
        case .traditionalChinese:
            switch title {
            case "AI Search": return "AI 搜尋"
            case "LLM": return "LLM"
            default: return title
            }
        case .japanese:
            switch title {
            case "AI Search": return "AI 検索"
            case "LLM": return "LLM"
            default: return title
            }
        case .korean:
            switch title {
            case "AI Search": return "AI 검색"
            case "LLM": return "LLM"
            default: return title
            }
        }
    }

    static func shortDateTime(_ date: Date, language: AppLanguage = AppLanguageStore.shared.language) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.rawValue)
        switch language {
        case .english:
            formatter.dateFormat = "MMM d HH:mm"
        case .simplifiedChinese, .traditionalChinese, .japanese:
            formatter.dateFormat = "M月d日 HH:mm"
        case .korean:
            formatter.dateFormat = "M월 d일 HH:mm"
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
        case .traditionalChinese:
            switch title {
            case "5h":
                return "5 小時"
            case "week":
                return "週"
            case "month":
                return "月"
            default:
                return title
            }
        case .japanese:
            switch title {
            case "5h":
                return "5 時間"
            case "week":
                return "週"
            case "month":
                return "月"
            default:
                return title
            }
        case .korean:
            switch title {
            case "5h":
                return "5시간"
            case "week":
                return "주"
            case "month":
                return "월"
            default:
                return title
            }
        }
    }

    static func quotaWindowDisplay(_ name: String, _ percentageText: String, language: AppLanguage = AppLanguageStore.shared.language) -> String {
        "\(quotaPeriodTitle(name, language: language)) \(percentageText)"
    }

    static func quotaWindowResetDisplay(
        _ name: String,
        _ percentageText: String,
        resetAt: Date?,
        language: AppLanguage = AppLanguageStore.shared.language
    ) -> String {
        let resetText = resetAt
            .map { format(.resetDate, shortDateTime($0, language: language), language: language) }
            ?? t(.resetNotExposed, language: language)
        return "\(quotaWindowDisplay(name, percentageText, language: language)) · \(resetText)"
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

    static func localizedCredentialNote(_ note: String, language: AppLanguage = AppLanguageStore.shared.language) -> String {
        let normalizedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if localizedValues(for: .importedFromEnv).contains(normalizedNote) {
            return t(.importedFromEnv, language: language)
        }
        if localizedValues(for: .importedFromClaude).contains(normalizedNote) {
            return t(.importedFromClaude, language: language)
        }
        if isBusinessInvocationQuotaDiagnostic(normalizedNote) {
            return t(.businessInvocationKeyQuotaInstruction, language: language)
        }
        return note
    }

    static func localizedValues(for key: Key) -> Set<String> {
        Set(AppLanguage.allCases.map { t(key, language: $0) })
    }

    private static func localizedExactQuotaLabel(_ label: String, language: AppLanguage) -> String? {
        let normalizedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)

        if isBusinessInvocationQuotaDiagnostic(normalizedLabel) {
            return t(.businessInvocationKeyQuotaInstruction, language: language)
        }
        if localizedValues(for: .businessInvocationKeyUnsupportedDiagnostic).contains(normalizedLabel) {
            return t(.businessInvocationKeyUnsupportedDiagnostic, language: language)
        }
        if localizedValues(for: .businessInvocationKeyQuotaInstruction).contains(normalizedLabel) {
            return t(.businessInvocationKeyQuotaInstruction, language: language)
        }
        if localizedValues(for: .businessInvocationKeySaved).contains(normalizedLabel) {
            return t(.businessInvocationKeySaved, language: language)
        }
        if localizedValues(for: .useDashboardCookie).contains(normalizedLabel) {
            return t(.useDashboardCookie, language: language)
        }

        let persistedStatusKeys: [Key] = [
            .quotaUnavailable,
            .noSubscribedPlan,
            .manualRefreshOnly,
            .unlimited,
            .usageLimitExceeded,
            .adminCredentialRequired,
            .credentialExpired,
            .cookieSaved,
            .usableUnknownQuota,
            .quotaCheckNotSupportedDiagnostic,
            .braveQuotaUnknownDiagnostic,
            .braveQuotaHeadersDiagnostic,
            .braveUsageLimitDiagnostic,
            .queritDashboardOnlyDiagnostic,
            .queritAccountDiagnostic,
            .exaServiceKeyDiagnostic,
            .anthropicDashboardOnlyDiagnostic,
            .quotaConsumingRefreshWarning,
            .quotaErrorInvalidResponse,
            .quotaErrorRateLimited,
            .quotaErrorInvalidAPIKey,
            .quotaErrorCooldown
        ]
        if let matchedKey = persistedStatusKeys.first(where: { localizedValues(for: $0).contains(normalizedLabel) }) {
            return t(matchedKey, language: language)
        }
        if let networkErrorKey = knownNetworkErrorKey(normalizedLabel) {
            return t(networkErrorKey, language: language)
        }
        if let networkErrorDetail = localizedNetworkErrorDetail(normalizedLabel) {
            return format(.quotaErrorNetworkFormat, networkErrorDetail, language: language)
        }

        switch normalizedLabel {
        case "Search OK · monthly quota not exposed":
            return t(.usableUnknownQuota, language: language)
        case "Usage limit exceeded":
            return t(.usageLimitExceeded, language: language)
        case "Unlimited free usage":
            return t(.unlimited, language: language)
        case "Unavailable":
            return t(.quotaUnavailable, language: language)
        case "No subscribed plan", "No subscription found":
            return t(.noSubscribedPlan, language: language)
        case "Manual refresh only":
            return t(.manualRefreshOnly, language: language)
        case "Admin credential required",
             "Management API credential required",
             "API Key required",
             "需要管理员凭据",
             "需要管理 API 凭据",
             "需要 API 密钥",
             "需要管理員憑證",
             "需要管理 API 憑證",
             "需要 API 金鑰",
             "管理者認証情報が必要",
             "管理 API 認証情報が必要",
             "API キーが必要",
             "관리자 자격 증명 필요",
             "관리 API 자격 증명 필요",
             "API 키 필요":
            return t(.adminCredentialRequired, language: language)
        case "Search works, but Brave did not expose monthly quota for this key.",
             "Search works, but monthly quota is hidden by Brave.":
            return t(.braveQuotaUnknownDiagnostic, language: language)
        case "Search works and Brave returned quota headers.":
            return t(.braveQuotaHeadersDiagnostic, language: language)
        case "Brave returned HTTP 402 usage limit exceeded.":
            return t(.braveUsageLimitDiagnostic, language: language)
        case "Querit account endpoint returned monthly request quota.",
             "Querit account endpoint returned monthly usage, but no plan quota limit.":
            return t(.queritAccountDiagnostic, language: language)
        case "Quota check not supported for this provider":
            return t(.quotaCheckNotSupportedDiagnostic, language: language)
        case "Business invocation keys cannot query quota; use a web login credential.",
             "Business invocation key is not used for quota monitoring. Add a dashboard Cookie credential instead.",
             "Business invocation key is not used for quota monitoring. Add a dashboard Cookie credential instead...":
            return t(.businessInvocationKeyQuotaInstruction, language: language)
        default:
            return nil
        }
    }

    private static func isBusinessInvocationQuotaDiagnostic(_ label: String) -> Bool {
        let normalized = label.lowercased()
        return normalized.contains("business invocation key")
            && normalized.contains("quota monitoring")
            && normalized.contains("dashboard")
            && normalized.contains("cookie")
    }

    private static var networkErrorPrefixes: [String] {
        AppLanguage.allCases
            .map { t(.quotaErrorNetworkFormat, language: $0) }
            .compactMap { template -> String? in
                guard let range = template.range(of: "%@") else { return nil }
                return String(template[..<range.lowerBound])
            }
            .filter { !$0.isEmpty }
    }

    static func localizedNetworkErrorDetail(_ label: String) -> String? {
        if knownNetworkErrorKey(label) != nil {
            return nil
        }

        for prefix in networkErrorPrefixes {
            guard label.hasPrefix(prefix) else { continue }
            let detail = String(label.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !detail.isEmpty else { continue }
            return detail
        }
        return nil
    }

    static func isTimeoutNetworkError(_ label: String) -> Bool {
        knownNetworkErrorKey(label) == .quotaErrorTimedOutNetwork
    }

    static func knownNetworkErrorKey(_ label: String) -> Key? {
        if let prefixedDetail = networkErrorPrefixedDetail(label) {
            return knownNetworkErrorKey(prefixedDetail)
        }

        let normalized = label
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".。"))
            .lowercased()
        switch normalized {
        case "the request timed out",
             "request timed out",
             "timed out",
             "请求超时",
             "請求超時",
             "リクエストがタイムアウトしました",
             "요청 시간이 초과되었습니다":
            return .quotaErrorTimedOutNetwork
        case "the internet connection appears to be offline",
             "network offline",
             "offline",
             "网络离线",
             "網路離線",
             "オフラインです",
             "オフライン",
             "오프라인":
            return .quotaErrorOfflineNetwork
        case "the network connection was lost",
             "network connection lost",
             "connection lost",
             "连接中断",
             "連線中斷",
             "接続が切断されました",
             "연결이 끊어졌습니다":
            return .quotaErrorConnectionLostNetwork
        case "a server with the specified hostname could not be found",
             "host not found",
             "找不到主机",
             "找不到主機",
             "ホストが見つかりません",
             "호스트를 찾을 수 없습니다":
            return .quotaErrorHostNotFoundNetwork
        case "could not connect to the server",
             "could not connect to server",
             "cannot connect to host",
             "无法连接服务器",
             "無法連線到伺服器",
             "サーバーに接続できません",
             "서버에 연결할 수 없습니다":
            return .quotaErrorCannotConnectNetwork
        default:
            return nil
        }
    }

    private static func networkErrorPrefixedDetail(_ label: String) -> String? {
        for prefix in networkErrorPrefixes {
            guard label.hasPrefix(prefix) else { continue }
            let detail = String(label.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !detail.isEmpty else { continue }
            return detail
        }
        return nil
    }

    private static func localizedStructuredQuotaLabel(_ label: String, language: AppLanguage) -> String? {
        if let match = regexCapture(label, pattern: #"^([0-9]+) / ([0-9]+) monthly credits$"#) {
            return format(.monthlyCreditsFormat, match[0], match[1], language: language)
        }
        if let match = regexCapture(label, pattern: #"^([0-9]+) / ([0-9]+) monthly requests$"#) {
            return format(.monthlyRequestsFormat, match[0], match[1], language: language)
        }
        if let match = regexCapture(label, pattern: #"^([0-9]+) monthly requests used$"#) {
            return format(.monthlyRequestsUsedFormat, match[0], language: language)
        }
        if let match = regexCapture(label, pattern: #"^([0-9]+) / ([0-9]+) tokens$"#) {
            return format(.tokenQuotaFormat, match[0], match[1], language: language)
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
            return format(.moneyAvailableFormat, localizedMoneyText(currency: match[0], amount: match[1], language: language), language: language)
        }
        if let match = regexCapture(label, pattern: #"^([A-Z]{3}) ([0-9]+(?:\.[0-9]+)?) balance$"#) {
            return format(.moneyBalanceFormat, localizedMoneyText(currency: match[0], amount: match[1], language: language), language: language)
        }
        if let match = regexCapture(label, pattern: #"^([A-Z]{3}) ([0-9]+(?:\.[0-9]+)?) used$"#) {
            return format(.moneyUsedFormat, localizedMoneyText(currency: match[0], amount: match[1], language: language), language: language)
        }
        return nil
    }

    static func localizedMoneyText(currency: String, amount: String, language: AppLanguage) -> String {
        guard currency == "CNY" else {
            return "\(currency) \(amount)"
        }

        switch language {
        case .simplifiedChinese:
            return "人民币 \(amount) 元"
        case .traditionalChinese:
            return "人民幣 \(amount) 元"
        case .english, .japanese, .korean:
            return "\(currency) \(amount)"
        }
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
        .settingsTab: "Settings",
        .settingsWindowTitle: "Quota Radar Settings",
        .apiKeysCount: "%d credentials",
        .apiKeyConfiguration: "Credential Configuration",
        .apiKeyConfigurationDescription: "Add API keys or web login authorizations. New credentials appear below by provider.",
        .importFromEnv: "Import from .env",
        .addKey: "Add Credential",
        .language: "Language",
        .languageTitle: "Language",
        .languageDescription: "Adjust app behavior, refresh cadence, language, and menu bar appearance.",
        .appLanguage: "App Language",
        .settingsGeneralSection: "General",
        .settingsRefreshSection: "Refresh",
        .settingsAppearanceSection: "Appearance",
        .statusBarTransparency: "Status Bar Transparency",
        .statusBarTransparencyDescription: "Adjust the frosted-glass menu transparency.",
        .launchAtLogin: "Open at Login",
        .launchAtLoginDescription: "Start Quota Radar automatically after signing in to macOS.",
        .autoRefreshInterval: "Refresh",
        .autoRefreshDescription: "Choose how often Quota Radar refreshes providers in the background.",
        .autoRefreshBraveWarning: "Automatic refresh skips Brave because each Brave check consumes one real search request.",
        .quotaConsumingAutoRefreshInterval: "Search Refresh",
        .quotaConsumingAutoRefreshWarning: "Enable only when you accept spending real search quota. These checks use a much longer refresh cadence.",
        .autoRefreshFiveMinutes: "Every 5 minutes",
        .autoRefreshFifteenMinutes: "Every 15 minutes",
        .autoRefreshThirtyMinutes: "Every 30 minutes",
        .autoRefreshOneHour: "Every hour",
        .quotaConsumingAutoRefreshSixHours: "Every 6 hours",
        .quotaConsumingAutoRefreshTwelveHours: "Every 12 hours",
        .quotaConsumingAutoRefreshOneDay: "Every day",
        .apiQuotaTitle: "Quota Radar",
        .noApiKeys: "No credentials",
        .noApiKeysMessage: "Import a .env file or add credentials on the Credentials page to show provider quotas here.",
        .openSettings: "Open Settings",
        .keys: "Keys",
        .providers: "Providers",
        .available: "Available",
        .failed: "Failed",
        .needsAttention: "Needs Attention",
        .noAttentionItems: "No credentials need attention",
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
        .noSubscribedPlan: "No subscribed plan",
        .remainingValue: "%d remaining",
        .addAPIKey: "Add Credential",
        .provider: "Provider",
        .keyName: "Credential Name",
        .apiKey: "API Key",
        .apiKeyForCopy: "API Key (optional)",
        .apiKeyForCopyHelp: "Stored only for display and copying. Quota checks still use web login authorization when this provider does not expose usage through the API key.",
        .apiKeySaved: "API key saved",
        .apiKeyStoredForCopyOnly: "Stored for copying only",
        .adminCredential: "API Key",
        .credentialValue: "Credential",
        .showCredential: "Show credential",
        .hideCredential: "Hide credential",
        .credentialHelp: "Use the provider's expected credential type. Some API keys are only for quota or usage APIs and differ from model/search invocation keys. Web login authorization is the short-lived in-app login permission used to read quota pages after you sign in.",
        .quotaMonitoringAuthorization: "Quota monitoring authorization",
        .quotaMonitoringAuthorizationHelp: "Used only by Quota Radar to read quota pages after you sign in. It is not shown or copied as an API key.",
        .pasteCurl: "Paste cURL",
        .curlImportFailed: "Could not parse credentials from cURL.",
        .noteOptional: "Note (optional)",
        .cancel: "Cancel",
        .add: "Add",
        .editAPIKey: "Edit Credential",
        .copyCredential: "Copy API Key",
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
        .version: "Version 0.3.0",
        .importNoKeys: "No supported API keys found in %@.",
        .importSummary: "Imported %d new and updated %d key(s).",
        .refreshAlreadyRunning: "Refresh already running",
        .refreshing: "Refreshing...",
        .refreshingProvider: "Refreshing %@...",
        .updatedJustNow: "Updated just now",
        .failedRefresh: "Failed to refresh %d key(s)",
        .resetDate: "Resets %@",
        .planEndsDate: "Plan ends %@",
        .resetsMonthlyDay1: "Resets monthly on day 1",
        .noResetCycle: "No reset cycle",
        .resetNotExposed: "Reset not exposed",
        .credentialExpired: "Credential expired",
        .reauthenticate: "Re-authenticate",
        .saveCookie: "Save login authorization",
        .cookieSaved: "Login authorization saved",
        .noCookiesFound: "No matching login data found",
        .missingRequiredCookies: "Missing required login data: %@",
        .reauthTitle: "Re-authenticate %@",
        .reauthDescription: "Log in to the provider dashboard. Quota Radar will save the required in-app login authorization automatically after login.",
        .autoCookieSaveHint: "Waiting for dashboard login. You can still save the authorization manually if needed.",
        .autoSavingCookie: "Saving web login authorization...",
        .checkingCookie: "Checking dashboard login...",
        .reauthStillUnauthorized: "Captured login data still returns Not logged in. Keep this window open, wait for the dashboard to finish loading, then save again.",
        .reauthValidationFailed: "Could not validate dashboard login: %@",
        .close: "Close",
        .unlimited: "Unlimited",
        .noKeyValue: "No key value",
        .adminCredentialRequired: "API Key required",
        .off: "Off",
        .ok: "OK",
        .expired: "Expired",
        .importPanelTitle: "Import credentials from .env",
        .importPanelMessage: "Choose a .env file containing supported API keys or web login authorizations.",
        .importedFromEnv: "Imported from .env",
        .importedFromClaude: "Imported from ~/.claude/settings.json",
        .dashboardSession: "Web login authorization",
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
        .exaServiceKeyDiagnostic: "Exa usage requires a service API key; a plain search API key cannot query quota.",
        .anthropicDashboardOnlyDiagnostic: "Anthropic does not expose this quota through a standard API-key usage endpoint. Open the dashboard to check usage.",
        .businessInvocationKeyUnsupportedDiagnostic: "Quota API pending.",
        .businessInvocationKeySaved: "Business key saved",
        .businessInvocationKeyQuotaInstruction: "Use web login authorization for quota monitoring",
        .businessInvocationKey: "Business key",
        .useDashboardCookie: "Use web login authorization",
        .quotaCheckNotSupportedDiagnostic: "This provider does not expose a supported quota-check endpoint.",
        .quotaConsumingRefreshWarning: "Manual refresh for this provider consumes one real search request.",
        .dashboardCookieCapabilityNote: "Uses web login authorization.",
        .quotaParsingNotImplementedCapabilityNote: "Credential can be stored, but quota parsing is not implemented yet.",
        .tencentCloudTokenPlanCredentialNote: "Requires Tencent Cloud API signing credentials and the Token Plan API key id.",
        .monthlyCreditsFormat: "%@ / %@ monthly credits",
        .monthlyRequestsFormat: "%@ / %@ monthly requests",
        .monthlyRequestsUsedFormat: "%@ monthly requests used",
        .searchesLeftFormat: "%@ searches left",
        .creditsLeftFormat: "%@ credits left",
        .noProviderCreditsAvailableFormat: "No %@ credits available",
        .moneyAvailableFormat: "%@ available",
        .moneyBalanceFormat: "%@ balance",
        .moneyUsedFormat: "%@ used",
        .tokenQuotaFormat: "%@ / %@ tokens",
        .manualRefreshOnly: "Manual refresh only",
        .zeroRemainingBadge: "0 left",
        .notAvailableShort: "N/A",
        .braveQuotaHeadersDiagnostic: "Search works and Brave returned quota headers.",
        .braveUsageLimitDiagnostic: "Brave returned HTTP 402 usage limit exceeded.",
        .queritAccountDiagnostic: "Querit account endpoint returned monthly usage, but no plan quota limit.",
        .exaBillingUsageDiagnostic: "Exa Team Management usage endpoint returned billing usage.",
        .quotaErrorInvalidResponse: "Invalid response from server",
        .quotaErrorNetworkFormat: "Network error: %@",
        .quotaErrorTimedOutDetail: "Request timed out",
        .quotaErrorTimedOutNetwork: "Network error: request timed out",
        .quotaErrorOfflineNetwork: "Network error: offline",
        .quotaErrorConnectionLostNetwork: "Network error: connection lost",
        .quotaErrorHostNotFoundNetwork: "Network error: host not found",
        .quotaErrorCannotConnectNetwork: "Network error: could not connect to server",
        .quotaErrorRateLimited: "Rate limit exceeded",
        .quotaErrorInvalidAPIKey: "Invalid API key",
        .quotaErrorCooldown: "Quota was checked recently",
    ]

    private static let simplifiedChinese: [Key: String] = [
        .apiKeysTab: "配置凭据",
        .providersTab: "额度监控",
        .diagnosticsTab: "诊断",
        .aboutTab: "关于",
        .settingsTab: "设置",
        .settingsWindowTitle: "Quota Radar 设置",
        .apiKeysCount: "%d 个凭据",
        .apiKeyConfiguration: "配置凭据",
        .apiKeyConfigurationDescription: "添加 API 密钥或网页登录授权。新增凭据会按服务商显示在下方。",
        .importFromEnv: "从 .env 导入",
        .addKey: "添加凭据",
        .language: "语言",
        .languageTitle: "语言",
        .languageDescription: "调整应用行为、刷新频率、语言和状态栏外观。",
        .appLanguage: "应用语言",
        .settingsGeneralSection: "通用",
        .settingsRefreshSection: "刷新",
        .settingsAppearanceSection: "外观",
        .statusBarTransparency: "状态栏透明度",
        .statusBarTransparencyDescription: "调整状态栏弹窗的磨砂玻璃透明程度。",
        .launchAtLogin: "开机自启动",
        .launchAtLoginDescription: "登录 macOS 后自动启动 Quota Radar。",
        .autoRefreshInterval: "刷新频率",
        .autoRefreshDescription: "选择 Quota Radar 在后台刷新服务商额度的频率。",
        .autoRefreshBraveWarning: "自动刷新会跳过 Brave，因为每次 Brave 检查都会消耗 1 次真实搜索请求。",
        .quotaConsumingAutoRefreshInterval: "检索刷新",
        .quotaConsumingAutoRefreshWarning: "仅在你接受消耗真实搜索额度时开启。这类检查使用更长的刷新周期。",
        .autoRefreshFiveMinutes: "每 5 分钟",
        .autoRefreshFifteenMinutes: "每 15 分钟",
        .autoRefreshThirtyMinutes: "每 30 分钟",
        .autoRefreshOneHour: "每小时",
        .quotaConsumingAutoRefreshSixHours: "每 6 小时",
        .quotaConsumingAutoRefreshTwelveHours: "每 12 小时",
        .quotaConsumingAutoRefreshOneDay: "每天",
        .apiQuotaTitle: "余量雷达",
        .noApiKeys: "没有凭据",
        .noApiKeysMessage: "导入 .env 文件或在凭据页添加凭据后，这里会显示各服务商的额度。",
        .openSettings: "打开设置",
        .keys: "密钥",
        .providers: "服务商",
        .available: "可用",
        .failed: "失败",
        .needsAttention: "需要关注",
        .noAttentionItems: "暂无需要关注的凭据",
        .low: "低额度",
        .categoryCounts: "%d 个服务商 · %d 个密钥",
        .activeCount: "%d 个可用",
        .providerKeyCount: "%d 个密钥",
        .noKeyConfigured: "未配置密钥",
        .openDashboard: "打开控制台",
        .updated: "%@ 更新",
        .pullToRefresh: "点击服务商刷新",
        .disabled: "停用",
        .quotaUnavailable: "额度不可用",
        .noSubscribedPlan: "未发现订阅套餐",
        .remainingValue: "剩余 %d",
        .addAPIKey: "添加凭据",
        .provider: "服务商",
        .keyName: "凭据名称",
        .apiKey: "API 密钥",
        .apiKeyForCopy: "API 密钥（可选）",
        .apiKeyForCopyHelp: "仅用于保存、展示和复制。该服务商不支持用此 API 密钥查询额度时，额度监控仍使用网页登录授权。",
        .apiKeySaved: "API key 已保存",
        .apiKeyStoredForCopyOnly: "仅保存用于复制",
        .adminCredential: "API 密钥",
        .credentialValue: "凭据内容",
        .showCredential: "显示凭据",
        .hideCredential: "隐藏凭据",
        .credentialHelp: "请按服务商要求填写凭据。有些 API 密钥专门用于用量查询或额度查询，不等同于模型或搜索调用 key。网页登录授权是登录后读取额度页面所需的短期应用内授权，通常会过期。",
        .quotaMonitoringAuthorization: "额度监控授权",
        .quotaMonitoringAuthorizationHelp: "仅供 Quota Radar 在你登录后读取额度页面，不会作为 API 密钥显示或复制。",
        .pasteCurl: "粘贴 cURL",
        .curlImportFailed: "无法从 cURL 中解析凭据。",
        .noteOptional: "备注（可选）",
        .cancel: "取消",
        .add: "添加",
        .editAPIKey: "编辑凭据",
        .copyCredential: "复制 API 密钥",
        .note: "备注",
        .active: "启用",
        .quotaStatus: "额度状态",
        .lastUpdated: "上次更新",
        .delete: "删除",
        .save: "保存",
        .providersHeader: "额度监控",
        .providersSupported: "已配置 %d 个 · 支持 %d 个",
        .total: "总量",
        .remaining: "剩余",
        .aboutSubtitle: "实时观察 API 额度",
        .featureSupport: "支持多个 API 服务商",
        .featureRealtime: "按服务商单独刷新额度",
        .featureGlass: "磨砂玻璃状态栏界面",
        .featureMenuBar: "状态栏快速访问",
        .version: "版本 0.3.0",
        .importNoKeys: "在 %@ 中没有找到支持的 API 密钥。",
        .importSummary: "已导入 %d 个，新更新 %d 个密钥。",
        .refreshAlreadyRunning: "刷新正在进行",
        .refreshing: "正在刷新...",
        .refreshingProvider: "正在刷新 %@...",
        .updatedJustNow: "刚刚已更新",
        .failedRefresh: "%d 个密钥刷新失败",
        .resetDate: "%@ 重置",
        .planEndsDate: "套餐 %@ 到期",
        .resetsMonthlyDay1: "每月 1 日重置",
        .noResetCycle: "无重置周期",
        .resetNotExposed: "未公开重置时间",
        .credentialExpired: "凭据已过期",
        .reauthenticate: "重新认证",
        .saveCookie: "保存登录授权",
        .cookieSaved: "登录授权已保存",
        .noCookiesFound: "没有找到匹配的登录信息",
        .missingRequiredCookies: "缺少必要登录信息：%@",
        .reauthTitle: "重新认证 %@",
        .reauthDescription: "登录服务商控制台后，Quota Radar 会自动保存应用内所需的登录授权。",
        .autoCookieSaveHint: "等待控制台登录完成；需要时仍可手动保存授权。",
        .autoSavingCookie: "正在保存网页登录授权...",
        .checkingCookie: "正在验证控制台登录...",
        .reauthStillUnauthorized: "已获取登录信息，但接口仍返回未登录。请保持窗口打开，等控制台完全加载后再手动保存。",
        .reauthValidationFailed: "无法验证控制台登录：%@",
        .close: "关闭",
        .unlimited: "无限",
        .noKeyValue: "没有密钥值",
        .adminCredentialRequired: "需要 API 密钥",
        .off: "关闭",
        .ok: "正常",
        .expired: "过期",
        .importPanelTitle: "从 .env 导入凭据",
        .importPanelMessage: "选择包含受支持 API Key 或网页登录授权的 .env 文件。",
        .importedFromEnv: "从 .env 导入",
        .importedFromClaude: "从 ~/.claude/settings.json 导入",
        .dashboardSession: "网页登录授权",
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
        .exaServiceKeyDiagnostic: "Exa 用量查询需要 service API key，普通搜索 API Key 不能查询额度。",
        .anthropicDashboardOnlyDiagnostic: "Anthropic 没有通过标准 API Key 用量接口公开该额度；请打开控制台查看。",
        .businessInvocationKeyUnsupportedDiagnostic: "额度接口待确认。",
        .businessInvocationKeySaved: "业务 key 已保存",
        .businessInvocationKeyQuotaInstruction: "额度监控请用网页登录授权",
        .businessInvocationKey: "业务调用 key",
        .useDashboardCookie: "请改用网页登录授权",
        .quotaCheckNotSupportedDiagnostic: "该服务商没有公开受支持的额度查询接口。",
        .quotaConsumingRefreshWarning: "手动刷新该服务商会消耗 1 次真实搜索请求。",
        .dashboardCookieCapabilityNote: "使用网页登录授权查询额度。",
        .quotaParsingNotImplementedCapabilityNote: "可以保存凭据，但暂未实现额度解析。",
        .tencentCloudTokenPlanCredentialNote: "需要腾讯云 API 签名凭据和 Token Plan API Key ID。",
        .monthlyCreditsFormat: "%@ / %@ 月度积分",
        .monthlyRequestsFormat: "%@ / %@ 月度请求",
        .monthlyRequestsUsedFormat: "已用 %@ 次月度请求",
        .searchesLeftFormat: "剩余 %@ 次搜索",
        .creditsLeftFormat: "剩余 %@ 积分",
        .noProviderCreditsAvailableFormat: "没有可用的 %@ 积分",
        .moneyAvailableFormat: "可用%@",
        .moneyBalanceFormat: "余额%@",
        .moneyUsedFormat: "已用 %@",
        .tokenQuotaFormat: "%@ / %@ 个 token",
        .manualRefreshOnly: "仅支持手动刷新",
        .zeroRemainingBadge: "剩余 0",
        .notAvailableShort: "未知",
        .braveQuotaHeadersDiagnostic: "搜索可用，Brave 返回了额度响应头。",
        .braveUsageLimitDiagnostic: "Brave 返回 HTTP 402，额度已用尽。",
        .queritAccountDiagnostic: "Querit 账户接口返回了月度已用请求，但没有返回套餐上限。",
        .exaBillingUsageDiagnostic: "Exa Team Management 用量接口返回了账单用量。",
        .quotaErrorInvalidResponse: "服务器响应无效",
        .quotaErrorNetworkFormat: "网络错误：%@",
        .quotaErrorTimedOutDetail: "请求超时",
        .quotaErrorTimedOutNetwork: "网络错误：请求超时",
        .quotaErrorOfflineNetwork: "网络错误：网络离线",
        .quotaErrorConnectionLostNetwork: "网络错误：连接中断",
        .quotaErrorHostNotFoundNetwork: "网络错误：找不到主机",
        .quotaErrorCannotConnectNetwork: "网络错误：无法连接服务器",
        .quotaErrorRateLimited: "请求频率受限",
        .quotaErrorInvalidAPIKey: "API Key 无效",
        .quotaErrorCooldown: "刚检查过额度",
    ]

    private static let traditionalChinese: [Key: String] = [
        .apiKeysTab: "配置憑證",
        .providersTab: "額度監控",
        .diagnosticsTab: "診斷",
        .settingsTab: "設定",
        .settingsWindowTitle: "Quota Radar 設定",
        .apiKeysCount: "%d 個憑證",
        .apiKeyConfiguration: "配置憑證",
        .apiKeyConfigurationDescription: "新增 API 金鑰或網頁登入授權。新增憑證會按服務商顯示在下方。",
        .addKey: "新增憑證",
        .languageDescription: "調整應用程式行為、刷新頻率、語言和狀態列外觀。",
        .settingsGeneralSection: "通用",
        .settingsRefreshSection: "刷新",
        .settingsAppearanceSection: "外觀",
        .statusBarTransparency: "狀態列透明度",
        .statusBarTransparencyDescription: "調整狀態列彈窗的磨砂玻璃透明程度。",
        .launchAtLogin: "登入時啟動",
        .launchAtLoginDescription: "登入 macOS 後自動啟動 Quota Radar。",
        .autoRefreshInterval: "刷新頻率",
        .autoRefreshDescription: "選擇 Quota Radar 在背景刷新服務商額度的頻率。",
        .autoRefreshBraveWarning: "自動刷新會跳過 Brave，因為每次 Brave 檢查都會消耗 1 次真實搜尋請求。",
        .quotaConsumingAutoRefreshInterval: "搜尋刷新",
        .quotaConsumingAutoRefreshWarning: "僅在你接受消耗真實搜尋額度時開啟。這類檢查使用更長的刷新週期。",
        .apiQuotaTitle: "餘量雷達",
        .noApiKeys: "沒有憑證",
        .noApiKeysMessage: "匯入 .env 檔案或在憑證頁新增憑證後，這裡會顯示各服務商的額度。",
        .keys: "金鑰",
        .available: "可用",
        .needsAttention: "需要關注",
        .noAttentionItems: "暫無需要關注的憑證",
        .noKeyConfigured: "未配置金鑰",
        .openDashboard: "開啟控制台",
        .disabled: "停用",
        .quotaUnavailable: "額度不可用",
        .noSubscribedPlan: "未發現訂閱套餐",
        .planEndsDate: "套餐 %@ 到期",
        .keyName: "憑證名稱",
        .apiKey: "API 金鑰",
        .apiKeyForCopy: "API 金鑰（可選）",
        .apiKeyForCopyHelp: "僅用於保存、顯示和複製。若此服務商不支援用 API 金鑰查詢額度，額度監控仍使用網頁登入授權。",
        .apiKeySaved: "API key 已儲存",
        .apiKeyStoredForCopyOnly: "僅保存用於複製",
        .adminCredential: "API 金鑰",
        .credentialValue: "憑證內容",
        .showCredential: "顯示憑證",
        .hideCredential: "隱藏憑證",
        .copyCredential: "複製 API 金鑰",
        .credentialHelp: "請按服務商要求填寫憑證。有些 API 金鑰專門用於用量/額度查詢，不等同於模型或搜尋調用 key。網頁登入授權是登入後讀取額度頁面所需的短期應用內授權，通常會過期。",
        .quotaMonitoringAuthorization: "額度監控授權",
        .quotaMonitoringAuthorizationHelp: "僅供 Quota Radar 在你登入後讀取額度頁面，不會作為 API 金鑰顯示或複製。",
        .pasteCurl: "貼上 cURL",
        .curlImportFailed: "無法從 cURL 中解析憑證。",
        .quotaStatus: "額度狀態",
        .lastUpdated: "上次更新",
        .providersHeader: "額度監控",
        .remaining: "剩餘",
        .version: "版本 0.3.0",
        .credentialExpired: "憑證已過期",
        .importedFromEnv: "從 .env 匯入",
        .importedFromClaude: "從 ~/.claude/settings.json 匯入",
        .adminCredentialRequired: "需要 API 金鑰",
        .reauthenticate: "重新認證",
        .dashboardSession: "網頁登入授權",
        .healthStatus: "健康狀態",
        .diagnosticMessage: "診斷資訊",
        .usableUnknownQuota: "可用 · 額度未知",
        .usageLimitExceeded: "額度已用盡",
        .quotaErrorTimedOutDetail: "請求超時",
        .quotaErrorTimedOutNetwork: "網路錯誤：請求超時",
        .quotaErrorOfflineNetwork: "網路錯誤：網路離線",
        .quotaErrorConnectionLostNetwork: "網路錯誤：連線中斷",
        .quotaErrorHostNotFoundNetwork: "網路錯誤：找不到主機",
        .quotaErrorCannotConnectNetwork: "網路錯誤：無法連線到伺服器",
        .businessInvocationKeyUnsupportedDiagnostic: "額度介面待確認。",
        .businessInvocationKeySaved: "業務 key 已儲存",
        .businessInvocationKeyQuotaInstruction: "額度監控請使用網頁登入授權",
        .businessInvocationKey: "業務調用 key",
        .useDashboardCookie: "請改用網頁登入授權",
        .quotaConsumingRefreshWarning: "手動刷新該服務商會消耗 1 次真實搜尋請求。",
        .monthlyCreditsFormat: "%@ / %@ 月度積分",
        .monthlyRequestsFormat: "%@ / %@ 月度請求",
        .monthlyRequestsUsedFormat: "已用 %@ 次月度請求",
        .searchesLeftFormat: "剩餘 %@ 次搜尋",
        .creditsLeftFormat: "剩餘 %@ 積分",
        .tokenQuotaFormat: "%@ / %@ 個 token",
        .zeroRemainingBadge: "剩餘 0",
        .braveQuotaHeadersDiagnostic: "搜尋可用，Brave 返回了額度回應標頭。",
    ]

    private static let japanese: [Key: String] = english.merging([
        .apiKeysTab: "認証情報",
        .providersTab: "クォータ監視",
        .diagnosticsTab: "診断",
        .aboutTab: "情報",
        .settingsTab: "設定",
        .settingsWindowTitle: "Quota Radar 設定",
        .apiKeysCount: "%d 件の認証情報",
        .apiKeyConfiguration: "認証情報の設定",
        .apiKeyConfigurationDescription: "API キーまたは Web ログイン認証を追加します。追加した認証情報はプロバイダー別に表示されます。",
        .importFromEnv: ".env からインポート",
        .importedFromEnv: ".env からインポート",
        .importedFromClaude: "~/.claude/settings.json からインポート",
        .addKey: "認証情報を追加",
        .language: "言語",
        .languageTitle: "言語",
        .languageDescription: "アプリの動作、更新間隔、言語、メニューバー表示を調整します。",
        .appLanguage: "アプリの言語",
        .settingsGeneralSection: "一般",
        .settingsRefreshSection: "更新",
        .settingsAppearanceSection: "外観",
        .statusBarTransparency: "メニューバー透明度",
        .statusBarTransparencyDescription: "メニューバーポップオーバーのフロストガラス透明度を調整します。",
        .launchAtLogin: "ログイン時に起動",
        .launchAtLoginDescription: "macOS にサインインした後、Quota Radar を自動的に起動します。",
        .autoRefreshInterval: "更新間隔",
        .autoRefreshDescription: "Quota Radar がバックグラウンドでプロバイダーのクォータを更新する頻度を選択します。",
        .autoRefreshBraveWarning: "Brave のチェックは実際の検索リクエストを 1 回消費するため、自動更新ではスキップされます。",
        .quotaConsumingAutoRefreshInterval: "検索更新",
        .quotaConsumingAutoRefreshWarning: "実際の検索クォータを消費してよい場合のみ有効にしてください。このチェックは長い更新間隔を使います。",
        .autoRefreshFiveMinutes: "5 分ごと",
        .autoRefreshFifteenMinutes: "15 分ごと",
        .autoRefreshThirtyMinutes: "30 分ごと",
        .autoRefreshOneHour: "1 時間ごと",
        .quotaConsumingAutoRefreshSixHours: "6 時間ごと",
        .quotaConsumingAutoRefreshTwelveHours: "12 時間ごと",
        .quotaConsumingAutoRefreshOneDay: "毎日",
        .apiQuotaTitle: "クォータレーダー",
        .noApiKeys: "認証情報がありません",
        .noApiKeysMessage: ".env をインポートするか、認証情報ページで追加すると、ここにプロバイダーのクォータが表示されます。",
        .openSettings: "設定を開く",
        .keys: "キー",
        .providers: "プロバイダー",
        .available: "利用可能",
        .failed: "失敗",
        .needsAttention: "要確認",
        .noAttentionItems: "確認が必要な認証情報はありません",
        .low: "低残量",
        .categoryCounts: "%d プロバイダー · %d キー",
        .activeCount: "%d 有効",
        .providerKeyCount: "%d キー",
        .noKeyConfigured: "キー未設定",
        .openDashboard: "ダッシュボードを開く",
        .updated: "%@ 更新",
        .pullToRefresh: "プロバイダーをクリックして更新",
        .disabled: "無効",
        .quotaUnavailable: "クォータ取得不可",
        .noSubscribedPlan: "契約中のプランなし",
        .remainingValue: "残り %d",
        .addAPIKey: "認証情報を追加",
        .provider: "プロバイダー",
        .keyName: "認証情報名",
        .apiKey: "API キー",
        .apiKeyForCopy: "API キー（任意）",
        .apiKeyForCopyHelp: "表示とコピーのためだけに保存します。このプロバイダーが API キーで使用量を公開しない場合、クォータ監視には Web ログイン認証を使います。",
        .apiKeySaved: "API キー保存済み",
        .apiKeyStoredForCopyOnly: "コピー用に保存済み",
        .adminCredential: "API キー",
        .credentialValue: "認証情報",
        .showCredential: "認証情報を表示",
        .hideCredential: "認証情報を隠す",
        .credentialHelp: "プロバイダーが要求する認証情報を入力してください。一部の API キーは使用量/クォータ確認専用で、モデルや検索の呼び出しキーとは異なります。Web ログイン認証はログイン後のクォータ画面を読むための短期的なアプリ内権限です。",
        .quotaMonitoringAuthorization: "クォータ監視認証",
        .quotaMonitoringAuthorizationHelp: "ログイン後のクォータページを読むために Quota Radar だけが使います。API キーとして表示またはコピーされません。",
        .pasteCurl: "cURL を貼り付け",
        .curlImportFailed: "cURL から認証情報を解析できませんでした。",
        .noteOptional: "メモ（任意）",
        .cancel: "キャンセル",
        .add: "追加",
        .editAPIKey: "認証情報を編集",
        .copyCredential: "API キーをコピー",
        .note: "メモ",
        .active: "有効",
        .quotaStatus: "クォータ状態",
        .lastUpdated: "最終更新",
        .delete: "削除",
        .save: "保存",
        .providersHeader: "クォータ監視",
        .providersSupported: "%d 設定済み · %d 対応",
        .total: "合計",
        .remaining: "残り",
        .aboutSubtitle: "API クォータをリアルタイムで監視",
        .featureSupport: "複数 API プロバイダー対応",
        .featureRealtime: "プロバイダー単位のクォータ更新",
        .featureGlass: "フロストガラスのメニューバー UI",
        .featureMenuBar: "メニューバーから素早くアクセス",
        .version: "バージョン 0.3.0",
        .importNoKeys: "%@ に対応する認証情報が見つかりません。",
        .importSummary: "%d 件を新規インポートし、%d 件を更新しました。",
        .refreshAlreadyRunning: "更新中です",
        .refreshing: "更新中...",
        .refreshingProvider: "%@ を更新中...",
        .updatedJustNow: "たった今更新しました",
        .failedRefresh: "%d 件のキー更新に失敗",
        .resetDate: "%@ にリセット",
        .planEndsDate: "プラン終了 %@",
        .resetsMonthlyDay1: "毎月 1 日にリセット",
        .noResetCycle: "リセット周期なし",
        .resetNotExposed: "リセット時刻は非公開",
        .credentialExpired: "認証情報の期限切れ",
        .reauthenticate: "再認証",
        .saveCookie: "ログイン認証を保存",
        .cookieSaved: "ログイン認証を保存しました",
        .noCookiesFound: "一致するログイン情報が見つかりません",
        .missingRequiredCookies: "不足しているログイン情報: %@",
        .reauthTitle: "%@ を再認証",
        .reauthDescription: "プロバイダーのダッシュボードにログインしてください。ログイン後、Quota Radar が必要なアプリ内ログイン認証を自動保存します。",
        .autoCookieSaveHint: "ダッシュボードのログイン待機中です。必要に応じて認証を手動保存できます。",
        .autoSavingCookie: "Web ログイン認証を保存中...",
        .checkingCookie: "ダッシュボードログインを確認中...",
        .reauthStillUnauthorized: "ログイン情報は取得できましたが、API はまだ未ログインを返しています。画面の読み込み完了後に再保存してください。",
        .reauthValidationFailed: "ダッシュボードログインを検証できません: %@",
        .close: "閉じる",
        .unlimited: "無制限",
        .noKeyValue: "キー値なし",
        .adminCredentialRequired: "API キーが必要",
        .off: "オフ",
        .ok: "正常",
        .expired: "期限切れ",
        .importPanelTitle: ".env から認証情報をインポート",
        .importPanelMessage: "対応する API キーまたは Web ログイン認証を含む .env ファイルを選択してください。",
        .dashboardSession: "Web ログイン認証",
        .diagnosticsDescription: "各認証情報の最新チェック結果、HTTP 状態、プロバイダー別診断を確認します。",
        .healthStatus: "ヘルス",
        .httpNotRequested: "未リクエスト",
        .diagnosticMessage: "診断",
        .notChecked: "未チェック",
        .usableUnknownQuota: "利用可 · クォータ不明",
        .usageLimitExceeded: "使用上限超過",
        .healthHealthy: "正常",
        .healthLow: "低残量",
        .healthExhausted: "使い切り",
        .healthFailed: "確認失敗",
        .healthUnknown: "不明",
        .braveQuotaUnknownDiagnostic: "検索は利用できますが、Brave はこのキーの月間クォータを公開していません。",
        .queritDashboardOnlyDiagnostic: "Querit は公開 API キー用の使用量エンドポイントを提供していません。ダッシュボードで確認してください。",
        .exaServiceKeyDiagnostic: "Exa の使用量確認には service API key が必要です。通常の検索 API キーではクォータを確認できません。",
        .anthropicDashboardOnlyDiagnostic: "Anthropic は標準の API キー使用量エンドポイントでこのクォータを公開していません。ダッシュボードで確認してください。",
        .businessInvocationKeyUnsupportedDiagnostic: "クォータ API 未確認",
        .businessInvocationKeySaved: "業務キーを保存済み",
        .businessInvocationKeyQuotaInstruction: "クォータ監視には Web ログイン認証を使用",
        .businessInvocationKey: "業務キー",
        .useDashboardCookie: "Web ログイン認証を使用",
        .quotaCheckNotSupportedDiagnostic: "このプロバイダーは対応するクォータ確認エンドポイントを公開していません。",
        .quotaConsumingRefreshWarning: "このプロバイダーの手動更新は実際の検索リクエストを 1 回消費します。",
        .dashboardCookieCapabilityNote: "Web ログイン認証でクォータを確認します。",
        .quotaParsingNotImplementedCapabilityNote: "認証情報は保存できますが、クォータ解析はまだ実装されていません。",
        .tencentCloudTokenPlanCredentialNote: "Tencent Cloud API 署名認証情報と Token Plan API キー ID が必要です。",
        .monthlyCreditsFormat: "%@ / %@ 月間クレジット",
        .monthlyRequestsFormat: "%@ / %@ 月間リクエスト",
        .monthlyRequestsUsedFormat: "%@ 件の月間リクエスト使用済み",
        .searchesLeftFormat: "残り %@ 検索",
        .creditsLeftFormat: "残り %@ クレジット",
        .noProviderCreditsAvailableFormat: "%@ の利用可能なクレジットはありません",
        .moneyAvailableFormat: "%@ 利用可能",
        .moneyBalanceFormat: "%@ 残高",
        .moneyUsedFormat: "%@ 使用済み",
        .tokenQuotaFormat: "%@ / %@ トークン",
        .manualRefreshOnly: "手動更新のみ",
        .zeroRemainingBadge: "残り 0",
        .notAvailableShort: "不明",
        .braveQuotaHeadersDiagnostic: "検索は利用でき、Brave からクォータヘッダーが返されました。",
        .braveUsageLimitDiagnostic: "Brave が HTTP 402 使用上限超過を返しました。",
        .queritAccountDiagnostic: "Querit アカウントエンドポイントから月間使用量は返されましたが、プラン上限は返されませんでした。",
        .exaBillingUsageDiagnostic: "Exa Team Management 使用量エンドポイントから請求使用量が返されました。",
        .quotaErrorInvalidResponse: "サーバー応答が無効です",
        .quotaErrorNetworkFormat: "ネットワークエラー：%@",
        .quotaErrorTimedOutDetail: "リクエストがタイムアウトしました",
        .quotaErrorTimedOutNetwork: "ネットワークエラー：リクエストがタイムアウトしました",
        .quotaErrorOfflineNetwork: "ネットワークエラー：オフラインです",
        .quotaErrorConnectionLostNetwork: "ネットワークエラー：接続が切断されました",
        .quotaErrorHostNotFoundNetwork: "ネットワークエラー：ホストが見つかりません",
        .quotaErrorCannotConnectNetwork: "ネットワークエラー：サーバーに接続できません",
        .quotaErrorRateLimited: "レート制限に達しました",
        .quotaErrorInvalidAPIKey: "API キーが無効です",
        .quotaErrorCooldown: "クォータは最近確認済みです",
    ]) { _, new in new }

    private static let korean: [Key: String] = english.merging([
        .apiKeysTab: "자격 증명",
        .providersTab: "할당량 모니터링",
        .diagnosticsTab: "진단",
        .aboutTab: "정보",
        .settingsTab: "설정",
        .settingsWindowTitle: "Quota Radar 설정",
        .apiKeysCount: "자격 증명 %d개",
        .apiKeyConfiguration: "자격 증명 설정",
        .apiKeyConfigurationDescription: "API 키 또는 웹 로그인 인증을 추가합니다. 새 자격 증명은 공급자별로 표시됩니다.",
        .importFromEnv: ".env에서 가져오기",
        .importedFromEnv: ".env에서 가져옴",
        .importedFromClaude: "~/.claude/settings.json에서 가져옴",
        .addKey: "자격 증명 추가",
        .language: "언어",
        .languageTitle: "언어",
        .languageDescription: "앱 동작, 새로 고침 주기, 언어 및 메뉴 막대 모양을 조정합니다.",
        .appLanguage: "앱 언어",
        .settingsGeneralSection: "일반",
        .settingsRefreshSection: "새로 고침",
        .settingsAppearanceSection: "모양",
        .statusBarTransparency: "메뉴 막대 투명도",
        .statusBarTransparencyDescription: "메뉴 막대 팝오버의 반투명 효과를 조정합니다.",
        .launchAtLogin: "로그인 시 열기",
        .launchAtLoginDescription: "macOS에 로그인한 후 Quota Radar를 자동으로 시작합니다.",
        .autoRefreshInterval: "새로 고침 주기",
        .autoRefreshDescription: "Quota Radar가 백그라운드에서 공급자 할당량을 새로 고치는 주기를 선택합니다.",
        .autoRefreshBraveWarning: "Brave 확인은 실제 검색 요청 1회를 소비하므로 자동 새로 고침에서 건너뜁니다.",
        .quotaConsumingAutoRefreshInterval: "검색 새로 고침",
        .quotaConsumingAutoRefreshWarning: "실제 검색 할당량을 소비해도 되는 경우에만 켜세요. 이 확인은 더 긴 주기를 사용합니다.",
        .autoRefreshFiveMinutes: "5분마다",
        .autoRefreshFifteenMinutes: "15분마다",
        .autoRefreshThirtyMinutes: "30분마다",
        .autoRefreshOneHour: "매시간",
        .quotaConsumingAutoRefreshSixHours: "6시간마다",
        .quotaConsumingAutoRefreshTwelveHours: "12시간마다",
        .quotaConsumingAutoRefreshOneDay: "매일",
        .apiQuotaTitle: "할당량 레이더",
        .noApiKeys: "자격 증명 없음",
        .noApiKeysMessage: ".env 파일을 가져오거나 자격 증명 페이지에서 추가하면 여기에 공급자 할당량이 표시됩니다.",
        .openSettings: "설정 열기",
        .keys: "키",
        .providers: "공급자",
        .available: "사용 가능",
        .failed: "실패",
        .needsAttention: "확인 필요",
        .noAttentionItems: "확인이 필요한 자격 증명이 없습니다",
        .low: "낮음",
        .categoryCounts: "공급자 %d개 · 키 %d개",
        .activeCount: "활성 %d개",
        .providerKeyCount: "키 %d개",
        .noKeyConfigured: "키가 설정되지 않음",
        .openDashboard: "대시보드 열기",
        .updated: "%@ 업데이트",
        .pullToRefresh: "공급자를 클릭하여 새로 고침",
        .disabled: "비활성화됨",
        .quotaUnavailable: "할당량을 사용할 수 없음",
        .noSubscribedPlan: "구독 플랜 없음",
        .remainingValue: "%d 남음",
        .addAPIKey: "자격 증명 추가",
        .provider: "공급자",
        .keyName: "자격 증명 이름",
        .apiKey: "API 키",
        .apiKeyForCopy: "API 키(선택 사항)",
        .apiKeyForCopyHelp: "표시와 복사용으로만 저장합니다. 이 공급자가 API 키로 사용량을 공개하지 않으면 할당량 모니터링은 웹 로그인 인증을 사용합니다.",
        .apiKeySaved: "API 키 저장됨",
        .apiKeyStoredForCopyOnly: "복사용으로 저장됨",
        .adminCredential: "API 키",
        .credentialValue: "자격 증명",
        .showCredential: "자격 증명 표시",
        .hideCredential: "자격 증명 숨기기",
        .credentialHelp: "공급자가 요구하는 자격 증명을 입력하세요. 일부 API 키는 사용량/할당량 조회 전용이며 모델 또는 검색 호출 키와 다릅니다. 웹 로그인 인증은 로그인 후 할당량 페이지를 읽기 위한 단기 앱 내 권한입니다.",
        .quotaMonitoringAuthorization: "할당량 모니터링 인증",
        .quotaMonitoringAuthorizationHelp: "로그인 후 할당량 페이지를 읽기 위해 Quota Radar만 사용합니다. API 키로 표시하거나 복사하지 않습니다.",
        .pasteCurl: "cURL 붙여넣기",
        .curlImportFailed: "cURL에서 자격 증명을 파싱할 수 없습니다.",
        .noteOptional: "메모(선택 사항)",
        .cancel: "취소",
        .add: "추가",
        .editAPIKey: "자격 증명 편집",
        .copyCredential: "API 키 복사",
        .note: "메모",
        .active: "활성",
        .quotaStatus: "할당량 상태",
        .lastUpdated: "마지막 업데이트",
        .delete: "삭제",
        .save: "저장",
        .providersHeader: "할당량 모니터링",
        .providersSupported: "설정됨 %d개 · 지원 %d개",
        .total: "전체",
        .remaining: "남음",
        .aboutSubtitle: "API 할당량을 실시간으로 모니터링",
        .featureSupport: "여러 API 공급자 지원",
        .featureRealtime: "공급자별 할당량 새로 고침",
        .featureGlass: "반투명 메뉴 막대 UI",
        .featureMenuBar: "메뉴 막대 빠른 접근",
        .version: "버전 0.3.0",
        .importNoKeys: "%@에서 지원되는 자격 증명을 찾을 수 없습니다.",
        .importSummary: "새로 %d개 가져오고 %d개 키를 업데이트했습니다.",
        .refreshAlreadyRunning: "새로 고침 중입니다",
        .refreshing: "새로 고치는 중...",
        .refreshingProvider: "%@ 새로 고치는 중...",
        .updatedJustNow: "방금 업데이트됨",
        .failedRefresh: "키 %d개 새로 고침 실패",
        .resetDate: "%@ 재설정",
        .planEndsDate: "%@ 플랜 종료",
        .resetsMonthlyDay1: "매월 1일 재설정",
        .noResetCycle: "재설정 주기 없음",
        .resetNotExposed: "재설정 시간이 공개되지 않음",
        .credentialExpired: "자격 증명 만료됨",
        .reauthenticate: "다시 인증",
        .saveCookie: "로그인 인증 저장",
        .cookieSaved: "로그인 인증 저장됨",
        .noCookiesFound: "일치하는 로그인 정보를 찾을 수 없음",
        .missingRequiredCookies: "누락된 필수 로그인 정보: %@",
        .reauthTitle: "%@ 다시 인증",
        .reauthDescription: "공급자 대시보드에 로그인하세요. 로그인 후 Quota Radar가 필요한 앱 내 로그인 인증을 자동 저장합니다.",
        .autoCookieSaveHint: "대시보드 로그인 대기 중입니다. 필요한 경우 인증을 수동으로 저장할 수 있습니다.",
        .autoSavingCookie: "웹 로그인 인증 저장 중...",
        .checkingCookie: "대시보드 로그인 확인 중...",
        .reauthStillUnauthorized: "로그인 정보를 가져왔지만 API가 아직 로그인되지 않았다고 응답합니다. 대시보드 로딩 후 다시 저장하세요.",
        .reauthValidationFailed: "대시보드 로그인을 검증할 수 없음: %@",
        .close: "닫기",
        .unlimited: "무제한",
        .noKeyValue: "키 값 없음",
        .adminCredentialRequired: "API 키 필요",
        .off: "끔",
        .ok: "정상",
        .expired: "만료됨",
        .importPanelTitle: ".env에서 자격 증명 가져오기",
        .importPanelMessage: "지원되는 API 키 또는 웹 로그인 인증이 포함된 .env 파일을 선택하세요.",
        .dashboardSession: "웹 로그인 인증",
        .diagnosticsDescription: "각 자격 증명의 최근 확인 결과, HTTP 상태 및 공급자별 진단을 검토합니다.",
        .healthStatus: "상태",
        .httpNotRequested: "요청 안 함",
        .diagnosticMessage: "진단",
        .notChecked: "확인 안 됨",
        .usableUnknownQuota: "사용 가능 · 할당량 알 수 없음",
        .usageLimitExceeded: "사용 한도 초과",
        .healthHealthy: "정상",
        .healthLow: "낮은 할당량",
        .healthExhausted: "소진됨",
        .healthFailed: "확인 실패",
        .healthUnknown: "알 수 없음",
        .braveQuotaUnknownDiagnostic: "검색은 가능하지만 Brave가 이 키의 월간 할당량을 공개하지 않았습니다.",
        .queritDashboardOnlyDiagnostic: "Querit은 공개 API 키 사용량 엔드포인트를 제공하지 않습니다. 사용량 대시보드에서 확인하세요.",
        .exaServiceKeyDiagnostic: "Exa 사용량 확인에는 service API key가 필요합니다. 일반 검색 API 키로는 할당량을 확인할 수 없습니다.",
        .anthropicDashboardOnlyDiagnostic: "Anthropic은 표준 API 키 사용량 엔드포인트로 이 할당량을 공개하지 않습니다. 대시보드에서 확인하세요.",
        .businessInvocationKeyUnsupportedDiagnostic: "할당량 API 확인 대기",
        .businessInvocationKeySaved: "업무 호출 키 저장됨",
        .businessInvocationKeyQuotaInstruction: "할당량 모니터링에는 웹 로그인 인증 사용",
        .businessInvocationKey: "업무 호출 키",
        .useDashboardCookie: "웹 로그인 인증 사용",
        .quotaCheckNotSupportedDiagnostic: "이 공급자는 지원되는 할당량 확인 엔드포인트를 공개하지 않습니다.",
        .quotaConsumingRefreshWarning: "이 공급자를 수동 새로 고침하면 실제 검색 요청 1회를 소비합니다.",
        .dashboardCookieCapabilityNote: "웹 로그인 인증으로 할당량을 확인합니다.",
        .quotaParsingNotImplementedCapabilityNote: "자격 증명은 저장할 수 있지만 할당량 파싱은 아직 구현되지 않았습니다.",
        .tencentCloudTokenPlanCredentialNote: "Tencent Cloud API 서명 자격 증명과 Token Plan API 키 ID가 필요합니다.",
        .monthlyCreditsFormat: "%@ / %@ 월간 크레딧",
        .monthlyRequestsFormat: "%@ / %@ 월간 요청",
        .monthlyRequestsUsedFormat: "월간 요청 %@회 사용됨",
        .searchesLeftFormat: "%@회 검색 남음",
        .creditsLeftFormat: "%@ 크레딧 남음",
        .noProviderCreditsAvailableFormat: "사용 가능한 %@ 크레딧 없음",
        .moneyAvailableFormat: "%@ 사용 가능",
        .moneyBalanceFormat: "%@ 잔액",
        .moneyUsedFormat: "%@ 사용됨",
        .tokenQuotaFormat: "%@ / %@ 토큰",
        .manualRefreshOnly: "수동 새로 고침만",
        .zeroRemainingBadge: "0 남음",
        .notAvailableShort: "알 수 없음",
        .braveQuotaHeadersDiagnostic: "검색이 가능하며 Brave가 할당량 헤더를 반환했습니다.",
        .braveUsageLimitDiagnostic: "Brave가 HTTP 402 사용 한도 초과를 반환했습니다.",
        .queritAccountDiagnostic: "Querit 계정 엔드포인트가 월간 사용량은 반환했지만 플랜 한도는 반환하지 않았습니다.",
        .exaBillingUsageDiagnostic: "Exa Team Management 사용량 엔드포인트가 청구 사용량을 반환했습니다.",
        .quotaErrorInvalidResponse: "서버 응답이 올바르지 않습니다",
        .quotaErrorNetworkFormat: "네트워크 오류: %@",
        .quotaErrorTimedOutDetail: "요청 시간이 초과되었습니다",
        .quotaErrorTimedOutNetwork: "네트워크 오류: 요청 시간이 초과되었습니다",
        .quotaErrorOfflineNetwork: "네트워크 오류: 오프라인",
        .quotaErrorConnectionLostNetwork: "네트워크 오류: 연결이 끊어졌습니다",
        .quotaErrorHostNotFoundNetwork: "네트워크 오류: 호스트를 찾을 수 없습니다",
        .quotaErrorCannotConnectNetwork: "네트워크 오류: 서버에 연결할 수 없습니다",
        .quotaErrorRateLimited: "요청 한도에 도달했습니다",
        .quotaErrorInvalidAPIKey: "API 키가 유효하지 않습니다",
        .quotaErrorCooldown: "할당량을 최근에 확인했습니다",
    ]) { _, new in new }

    private static func simplifiedChineseToTraditional(_ value: String) -> String {
        let replacements: [(String, String)] = [
            ("凭据", "憑證"),
            ("密钥", "金鑰"),
            ("额度", "額度"),
            ("设置", "設定"),
            ("状态栏", "狀態列"),
            ("状态", "狀態"),
            ("刷新", "刷新"),
            ("搜索", "搜尋"),
            ("请求", "請求"),
            ("积分", "積分"),
            ("可用", "可用"),
            ("过期", "過期"),
            ("失败", "失敗"),
            ("检查", "檢查"),
            ("健康", "健康"),
            ("低额度", "低額度"),
            ("已耗尽", "已耗盡"),
            ("耗尽", "耗盡"),
            ("未知", "未知"),
            ("尚未", "尚未"),
            ("公开", "公開"),
            ("账户", "帳戶"),
            ("余额", "餘額"),
            ("月度", "月度"),
            ("重置", "重置"),
            ("剩余", "剩餘"),
            ("选择", "選擇"),
            ("包含", "包含"),
            ("支持", "支援"),
            ("解析", "解析"),
            ("无法", "無法"),
            ("验证", "驗證"),
            ("登录", "登入"),
            ("诊断", "診斷"),
            ("信息", "資訊"),
            ("控制台", "控制台"),
            ("会话", "會話"),
            ("导入", "匯入"),
            ("打开", "開啟"),
            ("关闭", "關閉"),
            ("启用", "啟用"),
            ("已停用", "已停用"),
            ("服务商", "服務商"),
            ("语言", "語言"),
            ("自动", "自動"),
            ("后台", "背景"),
            ("真实", "真實"),
            ("简体中文", "簡體中文")
        ]
        return replacements.reduce(value) { partial, replacement in
            partial.replacingOccurrences(of: replacement.0, with: replacement.1)
        }
    }
}
