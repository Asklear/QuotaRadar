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

        if L10n.localizedValues(for: .cookieSaved).contains(normalized) {
            return .localized(.cookieSaved)
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
        case customProviderOrder
        case customProviderOrderDescription
        case configureProviderOrder
        case watchedProviders
        case watchedProvidersDescription
        case configureWatchedProviders
        case addWatchedProviderAction
        case removeWatchedProviderAction
        case watchedProvidersSheetTitle
        case watchedProvidersSheetHint
        case settingsGeneralSection
        case settingsRefreshSection
        case settingsNetworkSection
        case settingsAppearanceSection
        case settingsUpdateSection
        case automaticUpdateCheck
        case automaticUpdateCheckDescription
        case checkForUpdates
        case checkForUpdatesDescription
        case checkingForUpdates
        case updateAvailableStatus
        case updateAvailableTitle
        case updateAvailableMessage
        case releaseNotes
        case releaseNotesUnavailable
        case downloadAndInstallUpdate
        case later
        case openReleasePage
        case noUpdatesAvailable
        case noUpdatesAvailableDescription
        case updateCheckFailed
        case updateDownloadStarted
        case updateInstallPreparing
        case updateInstallingRelaunch
        case updateDownloadFailed
        case updateMissingDMGAsset
        case updateLatestReleaseUnavailable
        case updateHTTPStatusError
        case statusBarTransparency
        case statusBarTransparencyDescription
        case launchAtLogin
        case launchAtLoginDescription
        case autoRefreshInterval
        case autoRefreshDescription
        case autoRefreshBraveWarning
        case quotaConsumingAutoRefreshInterval
        case quotaConsumingAutoRefreshWarning
        case quotaConsumingManualOnlyWarning
        case autoRefreshFiveMinutes
        case autoRefreshFifteenMinutes
        case autoRefreshThirtyMinutes
        case autoRefreshOneHour
        case quotaConsumingAutoRefreshSixHours
        case quotaConsumingAutoRefreshTwelveHours
        case quotaConsumingAutoRefreshOneDay
        case networkProxy
        case networkProxyDescription
        case networkProxySystem
        case networkProxyDirect
        case networkProxyCustom
        case customProxyURL
        case customProxyPlaceholder
        case customProxyHelp
        case apiQuotaTitle
        case sidebarStatistics
        case noApiKeys
        case noApiKeysMessage
        case openSettings
        case keys
        case providers
        case quotaRiskToday
        case statusItemFailedCount
        case statusItemLowCount
        case available
        case failed
        case needsAttention
        case noAttentionItems
        case low
        case keyQuota
        case credentialPool
        case criticalTime
        case accountTiming
        case plan
        case lowQuotaProviders
        case expiringSoon
        case recentProviderUsage
        case recentUsageDetail
        case hiddenQuotaSignalCount
        case statusBarAccountCount
        case oneCredential
        case usableCredentialCount
        case attentionCredentialCount
        case categoryCounts
        case activeCount
        case providerKeyCount
        case oneCredentialGroup
        case credentialGroupCount
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
        case credential
        case apiKeyForCopy
        case apiKeyForCopyHelp
        case apiKeySaved
        case apiKeyStoredForCopyOnly
        case invocationAPIKeySaved
        case webLoginCredential
        case saved
        case includesInvocationAPIKey
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
        case providerOrder
        case providerOrderDescription
        case providerOrderLockedDescription
        case providerOrderSheetTitle
        case providerOrderSheetDescription
        case dragProviderOrderHint
        case resetProviderOrder
        case moveProviderUp
        case moveProviderDown
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
        case refreshQuotaAction
        case refreshingQuotaAction
        case refreshQuotaConsumesQuotaAction
        case testConnection
        case costlyConnectionTestTitle
        case costlyConnectionTestMessage
        case testConnectionConsumesQuota
        case reset
        case resetDate
        case planEndsDate
        case quotaActivity
        case quotaActivityRemaining
        case quotaTrend
        case quotaTrendReplenished
        case quotaTrendStable
        case quotaRefreshDeltaConsumed
        case quotaRefreshDeltaNoChange
        case quotaRefreshDeltaRecovered
        case quotaRefreshDeltaFailed
        case resetsMonthlyDay1
        case noResetCycle
        case resetNotExposed
        case credentialExpired
        case notificationLowQuotaTitle
        case notificationLowQuotaBody
        case notificationQuotaExhaustedTitle
        case notificationQuotaExhaustedBody
        case notificationCredentialExpiredTitle
        case notificationCredentialExpiredBody
        case notificationRepeatedFailuresTitle
        case notificationRepeatedFailuresBody
        case updateLoginAuthorizationAction
        case reauthenticate
        case saveCookie
        case cookieSaved
        case noCookiesFound
        case missingRequiredCookies
        case reauthTitle
        case reauthDescription
        case reauthSavingTo
        case reauthWillCreate
        case reauthMultipleCredentialHint
        case reauthTargetCredential
        case reauthCreateNewCredential
        case reauthSelectTarget
        case reauthSelectTargetBeforeSaving
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
        case credentialState
        case credentialStateNotConfigured
        case credentialStateConfiguredUntested
        case credentialStateUsable
        case credentialStateCredentialExpired
        case credentialStateQuotaUnavailable
        case credentialStateCheckConsumesQuota
        case credentialStateCheckFailed
        case requestProxyMode
        case automaticRefresh
        case automaticRefreshSkipped
        case diagnosticsDescription
        case healthStatus
        case lastHTTPStatus
        case httpNotRequested
        case diagnosticMessage
        case diagnosticDetails
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
        .lastHTTPStatus,
        .customProxyPlaceholder
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

    static func credentialCount(_ count: Int, language: AppLanguage = AppLanguageStore.shared.language) -> String {
        if count == 1 {
            return t(.oneCredential, language: language)
        }
        return format(.providerKeyCount, count, language: language)
    }

    static func shortDateTime(
        _ date: Date,
        language: AppLanguage = AppLanguageStore.shared.language,
        includesYear: Bool = false
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.rawValue)
        switch language {
        case .english:
            formatter.dateFormat = includesYear ? "MMM d, yyyy HH:mm" : "MMM d HH:mm"
        case .simplifiedChinese, .traditionalChinese, .japanese:
            formatter.dateFormat = includesYear ? "yyyy年M月d日 HH:mm" : "M月d日 HH:mm"
        case .korean:
            formatter.dateFormat = includesYear ? "yyyy년 M월 d일 HH:mm" : "M월 d일 HH:mm"
        }
        return formatter.string(from: date)
    }

    static func percentPoints(_ value: Double) -> String {
        let boundedValue = max(0, value)
        let roundedValue = boundedValue.rounded()
        if abs(roundedValue - boundedValue) < 0.05 {
            return "\(Int(roundedValue))%"
        }
        return String(format: "%.1f%%", locale: Locale(identifier: "en_US_POSIX"), boundedValue)
    }

    static func percentPointDelta(_ value: Double) -> String {
        percentPoints(value).replacingOccurrences(of: "%", with: "pt")
    }

    static func compactDeltaIndicator(_ deltaText: String) -> String {
        let trimmed = deltaText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else {
            return trimmed
        }

        let body = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        switch first {
        case "-", "−":
            return body.isEmpty ? trimmed : "↓\(body)"
        case "+":
            return body.isEmpty ? trimmed : "↑\(body)"
        default:
            return trimmed
        }
    }

    static func quotaPeriodTitle(_ title: String, language: AppLanguage = AppLanguageStore.shared.language) -> String {
        switch language {
        case .english:
            switch title {
            case "balance":
                return "Balance"
            default:
                return title
            }
        case .simplifiedChinese:
            switch title {
            case "5h":
                return "5 小时"
            case "week":
                return "周"
            case "month":
                return "月"
            case "balance":
                return "余额"
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
            case "balance":
                return "餘額"
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
            case "balance":
                return "残高"
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
            case "balance":
                return "잔액"
            default:
                return title
            }
        }
    }

    static func quotaPeriodCompactTitle(_ title: String, language: AppLanguage = AppLanguageStore.shared.language) -> String {
        switch title {
        case "5h":
            return "5h"
        case "week":
            switch language {
            case .english:
                return "wk"
            case .simplifiedChinese:
                return "周"
            case .traditionalChinese, .japanese:
                return "週"
            case .korean:
                return "주"
            }
        case "month":
            switch language {
            case .english:
                return "mo"
            case .simplifiedChinese, .traditionalChinese, .japanese:
                return "月"
            case .korean:
                return "월"
            }
        case "balance":
            switch language {
            case .english:
                return "bal"
            case .simplifiedChinese:
                return "余额"
            case .traditionalChinese:
                return "餘額"
            case .japanese:
                return "残高"
            case .korean:
                return "잔액"
            }
        default:
            return title
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

    static func isGeneratedQuotaAuthorizationNote(_ note: String) -> Bool {
        let normalizedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return localizedValues(for: .dashboardSession).contains(normalizedNote)
            || localizedValues(for: .quotaMonitoringAuthorization).contains(normalizedNote)
            || localizedValues(for: .cookieSaved).contains(normalizedNote)
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
        .customProviderOrder: "Custom Provider Order",
        .customProviderOrderDescription: "Unlock provider ordering. When off, Quota Radar keeps the product-defined order.",
        .configureProviderOrder: "Configure",
        .watchedProviders: "Favorites",
        .watchedProvidersDescription: "Pick up to two providers to keep near the top of the menu bar.",
        .configureWatchedProviders: "Configure",
        .addWatchedProviderAction: "Keep in Favorites",
        .removeWatchedProviderAction: "Remove from Favorites",
        .watchedProvidersSheetTitle: "Favorites",
        .watchedProvidersSheetHint: "Pick providers you want to keep handy. Quota reminders still appear below.",
        .settingsGeneralSection: "General",
        .settingsRefreshSection: "Refresh",
        .settingsNetworkSection: "Network",
        .settingsAppearanceSection: "Appearance",
        .settingsUpdateSection: "Updates",
        .automaticUpdateCheck: "Automatically Check for Updates",
        .automaticUpdateCheckDescription: "Check GitHub Releases in the background. New versions are shown with release notes, but nothing downloads until you confirm.",
        .checkForUpdates: "Check for Updates",
        .checkForUpdatesDescription: "Check GitHub Releases. Downloads and app replacement start only after you confirm.",
        .checkingForUpdates: "Checking for updates...",
        .updateAvailableStatus: "Version %@ available",
        .updateAvailableTitle: "Quota Radar %@ is available",
        .updateAvailableMessage: "You are running %@. If you continue, Quota Radar will download %@ from GitHub Releases, replace the installed app, clear quarantine, and relaunch.",
        .releaseNotes: "Release Notes",
        .releaseNotesUnavailable: "No release notes were provided for this version.",
        .downloadAndInstallUpdate: "Download and Install",
        .later: "Later",
        .openReleasePage: "Open Release Page",
        .noUpdatesAvailable: "Quota Radar is up to date",
        .noUpdatesAvailableDescription: "Version %@ is the latest available release.",
        .updateCheckFailed: "Could not check for updates",
        .updateDownloadStarted: "Downloading version %@...",
        .updateInstallPreparing: "Preparing installation...",
        .updateInstallingRelaunch: "Installing update and relaunching...",
        .updateDownloadFailed: "Update failed: %@",
        .updateMissingDMGAsset: "The latest release does not include QuotaRadar.dmg.",
        .updateLatestReleaseUnavailable: "Could not resolve the latest GitHub release.",
        .updateHTTPStatusError: "GitHub returned HTTP %d.",
        .statusBarTransparency: "Status Bar Transparency",
        .statusBarTransparencyDescription: "Adjust the frosted-glass menu transparency.",
        .launchAtLogin: "Open at Login",
        .launchAtLoginDescription: "Start Quota Radar automatically after signing in to macOS.",
        .autoRefreshInterval: "Refresh",
        .autoRefreshDescription: "Choose how often Quota Radar refreshes providers in the background.",
        .autoRefreshBraveWarning: "Automatic refresh skips Brave because each Brave check consumes one real search request.",
        .quotaConsumingAutoRefreshInterval: "Search Refresh",
        .quotaConsumingAutoRefreshWarning: "Enable only when you accept spending real search quota. These checks use a much longer refresh cadence.",
        .quotaConsumingManualOnlyWarning: "Costly checks require manual confirmation and are not run automatically.",
        .autoRefreshFiveMinutes: "Every 5 minutes",
        .autoRefreshFifteenMinutes: "Every 15 minutes",
        .autoRefreshThirtyMinutes: "Every 30 minutes",
        .autoRefreshOneHour: "Every hour",
        .quotaConsumingAutoRefreshSixHours: "Every 6 hours",
        .quotaConsumingAutoRefreshTwelveHours: "Every 12 hours",
        .quotaConsumingAutoRefreshOneDay: "Every day",
        .networkProxy: "Proxy",
        .networkProxyDescription: "Choose how quota checks connect to provider APIs.",
        .networkProxySystem: "System",
        .networkProxyDirect: "Direct",
        .networkProxyCustom: "Custom",
        .customProxyURL: "Proxy URL",
        .customProxyPlaceholder: "http://127.0.0.1:7890",
        .customProxyHelp: "Use Custom for local proxies such as Clash or Surge. System follows macOS network settings.",
        .apiQuotaTitle: "Quota Radar",
        .sidebarStatistics: "Statistics",
        .noApiKeys: "No credentials",
        .noApiKeysMessage: "Import a .env file or add credentials on the Credentials page to show provider quotas here.",
        .openSettings: "Open Settings",
        .keys: "Keys",
        .providers: "Providers",
        .quotaRiskToday: "Quota Risk Today",
        .statusItemFailedCount: "%d Failed",
        .statusItemLowCount: "%d Low",
        .available: "Available",
        .failed: "Failed",
        .needsAttention: "Heads Up",
        .noAttentionItems: "Nothing to flag",
        .low: "Low",
        .keyQuota: "Key Quota",
        .credentialPool: "Credential Pool",
        .criticalTime: "Critical Time",
        .accountTiming: "Timing",
        .plan: "Plan",
        .lowQuotaProviders: "Low Quota",
        .expiringSoon: "Expiring Soon",
        .recentProviderUsage: "Recent Change",
        .recentUsageDetail: "Remaining Δ",
        .hiddenQuotaSignalCount: "%d more items need attention",
        .statusBarAccountCount: "%d accounts",
        .oneCredential: "1 key",
        .usableCredentialCount: "%d usable",
        .attentionCredentialCount: "%d attention",
        .categoryCounts: "%d providers · %d keys",
        .activeCount: "%d active",
        .providerKeyCount: "%d keys",
        .oneCredentialGroup: "1 credential group",
        .credentialGroupCount: "%d credential groups",
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
        .credential: "Credential",
        .apiKeyForCopy: "API Key (optional)",
        .apiKeyForCopyHelp: "Stored only for display and copying. Quota checks still use web login authorization when this provider does not expose usage through the API key.",
        .apiKeySaved: "API key saved",
        .apiKeyStoredForCopyOnly: "Stored for copying only",
        .invocationAPIKeySaved: "Invocation API key saved",
        .webLoginCredential: "Web login",
        .saved: "Saved",
        .includesInvocationAPIKey: "includes invocation key",
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
        .providerOrder: "Provider Order",
        .providerOrderDescription: "Move providers to adjust the order used by quota monitoring, credentials, diagnostics, and the menu bar.",
        .providerOrderLockedDescription: "Provider order is locked in Settings. Turn on Custom Provider Order to move providers.",
        .providerOrderSheetTitle: "Provider Order",
        .providerOrderSheetDescription: "Drag providers to set the order shared by quota monitoring, credentials, diagnostics, and the menu bar.",
        .dragProviderOrderHint: "Drag a provider row and drop it where you want it. AI Search and LLM stay grouped.",
        .resetProviderOrder: "Reset Order",
        .moveProviderUp: "Move up",
        .moveProviderDown: "Move down",
        .providersSupported: "%d configured · %d supported",
        .total: "Total",
        .remaining: "Remaining",
        .aboutSubtitle: "Monitor your API quotas in real time",
        .featureSupport: "Support multiple API providers",
        .featureRealtime: "Provider-level quota refresh",
        .featureGlass: "Frosted glass menu bar UI",
        .featureMenuBar: "Menu bar quick access",
        .version: "Version 0.3.5",
        .importNoKeys: "No supported API keys found in %@.",
        .importSummary: "Imported %d new and updated %d key(s).",
        .refreshAlreadyRunning: "Refresh already running",
        .refreshing: "Refreshing...",
        .refreshingProvider: "Refreshing %@...",
        .updatedJustNow: "Updated just now",
        .failedRefresh: "Failed to refresh %d key(s)",
        .refreshQuotaAction: "Refresh quota",
        .refreshingQuotaAction: "Refreshing quota",
        .refreshQuotaConsumesQuotaAction: "Refresh quota (uses 1 request)",
        .testConnection: "Test connection",
        .costlyConnectionTestTitle: "This test consumes quota",
        .costlyConnectionTestMessage: "Testing this provider sends a real quota-consuming request. Continue only if you want to spend one request.",
        .testConnectionConsumesQuota: "Test and consume quota",
        .reset: "Reset",
        .resetDate: "Resets %@",
        .planEndsDate: "Plan ends %@",
        .quotaActivity: "Activity",
        .quotaActivityRemaining: "Remaining %@",
        .quotaTrend: "Trend",
        .quotaTrendReplenished: "Recovered",
        .quotaTrendStable: "Stable",
        .quotaRefreshDeltaConsumed: "Remaining -%@",
        .quotaRefreshDeltaNoChange: "Updated · no change",
        .quotaRefreshDeltaRecovered: "Reset",
        .quotaRefreshDeltaFailed: "Refresh failed",
        .resetsMonthlyDay1: "Resets monthly on day 1",
        .noResetCycle: "No reset cycle",
        .resetNotExposed: "Reset not exposed",
        .credentialExpired: "Credential expired",
        .notificationLowQuotaTitle: "Quota is low",
        .notificationLowQuotaBody: "%@ is down to %@.",
        .notificationQuotaExhaustedTitle: "Quota exhausted",
        .notificationQuotaExhaustedBody: "%@ has no quota remaining.",
        .notificationCredentialExpiredTitle: "Login authorization expired",
        .notificationCredentialExpiredBody: "%@ needs a new login authorization.",
        .notificationRepeatedFailuresTitle: "Quota check keeps failing",
        .notificationRepeatedFailuresBody: "%@ failed %d checks in a row.",
        .updateLoginAuthorizationAction: "Update login authorization",
        .reauthenticate: "Re-authenticate",
        .saveCookie: "Save login authorization",
        .cookieSaved: "Login authorization saved",
        .noCookiesFound: "No matching login data found",
        .missingRequiredCookies: "Missing required login data: %@",
        .reauthTitle: "Re-authenticate %@",
        .reauthDescription: "Log in to the provider dashboard. Quota Radar will save the required in-app login authorization automatically after login.",
        .reauthSavingTo: "Saving to %@",
        .reauthWillCreate: "Will create %@",
        .reauthMultipleCredentialHint: "Multiple saved login authorizations exist for this provider. This window updates the target shown above.",
        .reauthTargetCredential: "Save Target",
        .reauthCreateNewCredential: "Create new authorization",
        .reauthSelectTarget: "Select a credential",
        .reauthSelectTargetBeforeSaving: "Select which credential to update before saving.",
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
        .credentialState: "State",
        .credentialStateNotConfigured: "Not configured",
        .credentialStateConfiguredUntested: "Configured, untested",
        .credentialStateUsable: "Usable",
        .credentialStateCredentialExpired: "Credential expired",
        .credentialStateQuotaUnavailable: "Quota unavailable",
        .credentialStateCheckConsumesQuota: "Check consumes quota",
        .credentialStateCheckFailed: "Check failed",
        .requestProxyMode: "Proxy",
        .automaticRefresh: "Auto refresh",
        .automaticRefreshSkipped: "Skipped",
        .diagnosticsDescription: "Review each credential's latest check result, HTTP status, and provider-specific diagnostic note.",
        .healthStatus: "Health",
        .lastHTTPStatus: "HTTP",
        .httpNotRequested: "Not requested",
        .diagnosticMessage: "Diagnostic",
        .diagnosticDetails: "Details",
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
        .customProviderOrder: "自定义 Provider 顺序",
        .customProviderOrderDescription: "开启后可以调整服务商顺序；关闭时使用默认锁定顺序。",
        .configureProviderOrder: "调整顺序",
        .watchedProviders: "常看",
        .watchedProvidersDescription: "选择最多两个常看的服务商，它们会靠前显示在状态栏弹窗里。",
        .configureWatchedProviders: "设置",
        .addWatchedProviderAction: "加入常看",
        .removeWatchedProviderAction: "移出常看",
        .watchedProvidersSheetTitle: "常看",
        .watchedProvidersSheetHint: "把常看的服务商放到状态栏前面；系统提醒仍会在下面出现。",
        .settingsGeneralSection: "通用",
        .settingsRefreshSection: "刷新",
        .settingsNetworkSection: "网络",
        .settingsAppearanceSection: "外观",
        .settingsUpdateSection: "更新",
        .automaticUpdateCheck: "自动检查更新",
        .automaticUpdateCheckDescription: "在后台检查 GitHub Release。发现新版后会显示更新说明，但确认前不会下载。",
        .checkForUpdates: "检查更新",
        .checkForUpdatesDescription: "检查 GitHub Release。只有确认后才会开始下载并替换应用。",
        .checkingForUpdates: "正在检查更新...",
        .updateAvailableStatus: "%@ 可更新",
        .updateAvailableTitle: "Quota Radar %@ 可用",
        .updateAvailableMessage: "当前版本为 %@。如果继续，Quota Radar 会从 GitHub Release 下载 %@，覆盖已安装应用，清除 quarantine 后重新启动。",
        .releaseNotes: "更新说明",
        .releaseNotesUnavailable: "这个版本没有提供更新说明。",
        .downloadAndInstallUpdate: "下载并安装",
        .later: "稍后",
        .openReleasePage: "打开发布页",
        .noUpdatesAvailable: "Quota Radar 已是最新版本",
        .noUpdatesAvailableDescription: "版本 %@ 已是当前最新发布版本。",
        .updateCheckFailed: "无法检查更新",
        .updateDownloadStarted: "正在下载 %@...",
        .updateInstallPreparing: "正在准备安装...",
        .updateInstallingRelaunch: "正在安装并重新启动...",
        .updateDownloadFailed: "更新失败：%@",
        .updateMissingDMGAsset: "最新发布版本没有包含 QuotaRadar.dmg。",
        .updateLatestReleaseUnavailable: "无法解析 GitHub 最新发布版本。",
        .updateHTTPStatusError: "GitHub 返回 HTTP %d。",
        .statusBarTransparency: "状态栏透明度",
        .statusBarTransparencyDescription: "调整状态栏弹窗的磨砂玻璃透明程度。",
        .launchAtLogin: "开机自启动",
        .launchAtLoginDescription: "登录 macOS 后自动启动 Quota Radar。",
        .autoRefreshInterval: "刷新频率",
        .autoRefreshDescription: "选择 Quota Radar 在后台刷新服务商额度的频率。",
        .autoRefreshBraveWarning: "自动刷新会跳过 Brave，因为每次 Brave 检查都会消耗 1 次真实搜索请求。",
        .quotaConsumingAutoRefreshInterval: "检索刷新",
        .quotaConsumingAutoRefreshWarning: "仅在你接受消耗真实搜索额度时开启。这类检查使用更长的刷新周期。",
        .quotaConsumingManualOnlyWarning: "消耗真实额度的检查需要手动确认，不会自动运行。",
        .autoRefreshFiveMinutes: "每 5 分钟",
        .autoRefreshFifteenMinutes: "每 15 分钟",
        .autoRefreshThirtyMinutes: "每 30 分钟",
        .autoRefreshOneHour: "每小时",
        .quotaConsumingAutoRefreshSixHours: "每 6 小时",
        .quotaConsumingAutoRefreshTwelveHours: "每 12 小时",
        .quotaConsumingAutoRefreshOneDay: "每天",
        .networkProxy: "网络代理",
        .networkProxyDescription: "设置额度查询连接服务商接口时使用的网络路径。",
        .networkProxySystem: "跟随系统",
        .networkProxyDirect: "直连",
        .networkProxyCustom: "自定义",
        .customProxyURL: "代理地址",
        .customProxyPlaceholder: "http://127.0.0.1:7890",
        .customProxyHelp: "本地使用 Clash、Surge 等代理时选择自定义；跟随系统会使用 macOS 网络设置。",
        .apiQuotaTitle: "余量雷达",
        .sidebarStatistics: "统计",
        .noApiKeys: "没有凭据",
        .noApiKeysMessage: "导入 .env 文件或在凭据页添加凭据后，这里会显示各服务商的额度。",
        .openSettings: "打开设置",
        .keys: "密钥",
        .providers: "服务商",
        .quotaRiskToday: "今日额度风险",
        .statusItemFailedCount: "%d 失败",
        .statusItemLowCount: "%d 低",
        .available: "可用",
        .failed: "失败",
        .needsAttention: "提醒",
        .noAttentionItems: "暂无提醒",
        .low: "低额度",
        .keyQuota: "关键额度",
        .credentialPool: "凭据池",
        .criticalTime: "关键时间",
        .accountTiming: "时间",
        .plan: "套餐",
        .lowQuotaProviders: "额度紧张",
        .expiringSoon: "即将到期",
        .recentProviderUsage: "近期变化",
        .recentUsageDetail: "剩余变化",
        .hiddenQuotaSignalCount: "还有 %d 项需要关注",
        .statusBarAccountCount: "%d 个账号",
        .oneCredential: "1 个凭据",
        .usableCredentialCount: "%d 可用",
        .attentionCredentialCount: "%d 需关注",
        .categoryCounts: "%d 个服务商 · %d 个密钥",
        .activeCount: "%d 个可用",
        .providerKeyCount: "%d 个密钥",
        .oneCredentialGroup: "1 组凭据",
        .credentialGroupCount: "%d 组凭据",
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
        .credential: "凭据",
        .apiKeyForCopy: "API 密钥（可选）",
        .apiKeyForCopyHelp: "仅用于保存、展示和复制。该服务商不支持用此 API 密钥查询额度时，额度监控仍使用网页登录授权。",
        .apiKeySaved: "API key 已保存",
        .apiKeyStoredForCopyOnly: "仅保存用于复制",
        .invocationAPIKeySaved: "调用密钥已保存",
        .webLoginCredential: "网页登录",
        .saved: "已保存",
        .includesInvocationAPIKey: "含调用密钥",
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
        .providerOrder: "Provider 顺序",
        .providerOrderDescription: "调整服务商在额度监控、配置凭据、诊断和状态栏中的显示顺序。",
        .providerOrderLockedDescription: "Provider 顺序已在设置中锁定。开启自定义 Provider 顺序后即可移动。",
        .providerOrderSheetTitle: "Provider 顺序",
        .providerOrderSheetDescription: "拖动服务商，设置额度监控、配置凭据、诊断和状态栏共享的显示顺序。",
        .dragProviderOrderHint: "长按或拖动服务商行，放到目标位置。AI 搜索和 LLM 会保持分组。",
        .resetProviderOrder: "重置顺序",
        .moveProviderUp: "上移",
        .moveProviderDown: "下移",
        .providersSupported: "已配置 %d 个 · 支持 %d 个",
        .total: "总量",
        .remaining: "剩余",
        .aboutSubtitle: "实时观察 API 额度",
        .featureSupport: "支持多个 API 服务商",
        .featureRealtime: "按服务商单独刷新额度",
        .featureGlass: "磨砂玻璃状态栏界面",
        .featureMenuBar: "状态栏快速访问",
        .version: "版本 0.3.5",
        .importNoKeys: "在 %@ 中没有找到支持的 API 密钥。",
        .importSummary: "已导入 %d 个，新更新 %d 个密钥。",
        .refreshAlreadyRunning: "刷新正在进行",
        .refreshing: "正在刷新...",
        .refreshingProvider: "正在刷新 %@...",
        .updatedJustNow: "刚刚已更新",
        .failedRefresh: "%d 个密钥刷新失败",
        .refreshQuotaAction: "刷新额度",
        .refreshingQuotaAction: "正在刷新额度",
        .refreshQuotaConsumesQuotaAction: "刷新额度（消耗 1 次请求）",
        .testConnection: "测试连接",
        .costlyConnectionTestTitle: "该测试会消耗额度",
        .costlyConnectionTestMessage: "测试该服务商会发出一次真实请求并消耗额度。确认需要消耗 1 次请求后再继续。",
        .testConnectionConsumesQuota: "测试并消耗额度",
        .reset: "重置",
        .resetDate: "%@ 重置",
        .planEndsDate: "套餐 %@ 到期",
        .quotaActivity: "动态",
        .quotaActivityRemaining: "剩余 %@",
        .quotaTrend: "趋势",
        .quotaTrendReplenished: "已恢复",
        .quotaTrendStable: "稳定",
        .quotaRefreshDeltaConsumed: "剩余 -%@",
        .quotaRefreshDeltaNoChange: "刚刚更新 · 无变化",
        .quotaRefreshDeltaRecovered: "已重置",
        .quotaRefreshDeltaFailed: "刷新失败",
        .resetsMonthlyDay1: "每月 1 日重置",
        .noResetCycle: "无重置周期",
        .resetNotExposed: "未公开重置时间",
        .credentialExpired: "凭据已过期",
        .notificationLowQuotaTitle: "额度偏低",
        .notificationLowQuotaBody: "%@ 剩余 %@。",
        .notificationQuotaExhaustedTitle: "额度已耗尽",
        .notificationQuotaExhaustedBody: "%@ 已无可用额度。",
        .notificationCredentialExpiredTitle: "登录授权已过期",
        .notificationCredentialExpiredBody: "%@ 需要重新登录授权。",
        .notificationRepeatedFailuresTitle: "额度检查连续失败",
        .notificationRepeatedFailuresBody: "%@ 已连续 %d 次检查失败。",
        .updateLoginAuthorizationAction: "更新登录授权",
        .reauthenticate: "重新认证",
        .saveCookie: "保存登录授权",
        .cookieSaved: "登录授权已保存",
        .noCookiesFound: "没有找到匹配的登录信息",
        .missingRequiredCookies: "缺少必要登录信息：%@",
        .reauthTitle: "重新认证 %@",
        .reauthDescription: "登录服务商控制台后，Quota Radar 会自动保存应用内所需的登录授权。",
        .reauthSavingTo: "将更新 %@",
        .reauthWillCreate: "将创建 %@",
        .reauthMultipleCredentialHint: "该服务商已有多个登录授权，本窗口会更新上方显示的目标。",
        .reauthTargetCredential: "保存目标",
        .reauthCreateNewCredential: "创建新授权",
        .reauthSelectTarget: "选择一个凭据",
        .reauthSelectTargetBeforeSaving: "保存前请选择要更新的凭据。",
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
        .credentialState: "状态",
        .credentialStateNotConfigured: "未配置",
        .credentialStateConfiguredUntested: "已配置，待检测",
        .credentialStateUsable: "可用",
        .credentialStateCredentialExpired: "凭据已过期",
        .credentialStateQuotaUnavailable: "接口不可查询额度",
        .credentialStateCheckConsumesQuota: "检查会消耗额度",
        .credentialStateCheckFailed: "检查失败",
        .requestProxyMode: "代理",
        .automaticRefresh: "自动刷新",
        .automaticRefreshSkipped: "已跳过",
        .diagnosticsDescription: "查看每个凭据最近一次检查结果、HTTP 状态和服务商诊断信息。",
        .healthStatus: "健康状态",
        .lastHTTPStatus: "HTTP",
        .httpNotRequested: "未请求",
        .diagnosticMessage: "诊断信息",
        .diagnosticDetails: "详情",
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
        .customProviderOrder: "自訂 Provider 順序",
        .customProviderOrderDescription: "開啟後可以調整服務商順序；關閉時使用預設鎖定順序。",
        .configureProviderOrder: "調整順序",
        .watchedProviders: "常看",
        .watchedProvidersDescription: "選擇最多兩個常看的服務商，它們會靠前顯示在狀態列彈窗裡。",
        .configureWatchedProviders: "設定",
        .addWatchedProviderAction: "加入常看",
        .removeWatchedProviderAction: "移出常看",
        .watchedProvidersSheetTitle: "常看",
        .watchedProvidersSheetHint: "把常看的服務商放到狀態列前面；系統提醒仍會顯示在下方。",
        .settingsGeneralSection: "通用",
        .settingsRefreshSection: "刷新",
        .settingsAppearanceSection: "外觀",
        .settingsUpdateSection: "更新",
        .automaticUpdateCheck: "自動檢查更新",
        .automaticUpdateCheckDescription: "在背景檢查 GitHub Release。發現新版後會顯示更新說明，但確認前不會下載。",
        .checkForUpdates: "檢查更新",
        .checkForUpdatesDescription: "檢查 GitHub Release。只有確認後才會開始下載並替換應用程式。",
        .checkingForUpdates: "正在檢查更新...",
        .updateAvailableStatus: "%@ 可更新",
        .updateAvailableTitle: "Quota Radar %@ 可用",
        .updateAvailableMessage: "目前版本為 %@。如果繼續，Quota Radar 會從 GitHub Release 下載 %@，覆蓋已安裝應用程式，清除 quarantine 後重新啟動。",
        .releaseNotes: "更新說明",
        .releaseNotesUnavailable: "這個版本沒有提供更新說明。",
        .downloadAndInstallUpdate: "下載並安裝",
        .later: "稍後",
        .openReleasePage: "開啟發布頁",
        .noUpdatesAvailable: "Quota Radar 已是最新版本",
        .noUpdatesAvailableDescription: "版本 %@ 已是目前最新發布版本。",
        .updateCheckFailed: "無法檢查更新",
        .updateDownloadStarted: "正在下載 %@...",
        .updateInstallPreparing: "正在準備安裝...",
        .updateInstallingRelaunch: "正在安裝並重新啟動...",
        .updateDownloadFailed: "更新失敗：%@",
        .updateMissingDMGAsset: "最新發布版本沒有包含 QuotaRadar.dmg。",
        .updateLatestReleaseUnavailable: "無法解析 GitHub 最新發布版本。",
        .updateHTTPStatusError: "GitHub 返回 HTTP %d。",
        .statusBarTransparency: "狀態列透明度",
        .statusBarTransparencyDescription: "調整狀態列彈窗的磨砂玻璃透明程度。",
        .launchAtLogin: "登入時啟動",
        .launchAtLoginDescription: "登入 macOS 後自動啟動 Quota Radar。",
        .autoRefreshInterval: "刷新頻率",
        .autoRefreshDescription: "選擇 Quota Radar 在背景刷新服務商額度的頻率。",
        .autoRefreshBraveWarning: "自動刷新會跳過 Brave，因為每次 Brave 檢查都會消耗 1 次真實搜尋請求。",
        .quotaConsumingAutoRefreshInterval: "搜尋刷新",
        .quotaConsumingAutoRefreshWarning: "僅在你接受消耗真實搜尋額度時開啟。這類檢查使用更長的刷新週期。",
        .quotaConsumingManualOnlyWarning: "消耗真實額度的檢查需要手動確認，不會自動執行。",
        .apiQuotaTitle: "餘量雷達",
        .sidebarStatistics: "統計",
        .noApiKeys: "沒有憑證",
        .noApiKeysMessage: "匯入 .env 檔案或在憑證頁新增憑證後，這裡會顯示各服務商的額度。",
        .keys: "金鑰",
        .providers: "服務商",
        .quotaRiskToday: "今日額度風險",
        .statusItemFailedCount: "%d 失敗",
        .statusItemLowCount: "%d 低",
        .available: "可用",
        .failed: "失敗",
        .needsAttention: "提醒",
        .noAttentionItems: "暫無提醒",
        .low: "低額度",
        .keyQuota: "關鍵額度",
        .credentialPool: "憑證池",
        .criticalTime: "關鍵時間",
        .accountTiming: "時間",
        .plan: "套餐",
        .lowQuotaProviders: "額度緊張",
        .expiringSoon: "即將到期",
        .recentProviderUsage: "近期變化",
        .recentUsageDetail: "剩餘變化",
        .hiddenQuotaSignalCount: "還有 %d 項需要關注",
        .statusBarAccountCount: "%d 個帳號",
        .oneCredential: "1 個憑證",
        .usableCredentialCount: "%d 可用",
        .attentionCredentialCount: "%d 需關注",
        .categoryCounts: "%d 個服務商 · %d 個金鑰",
        .activeCount: "%d 個可用",
        .providerKeyCount: "%d 個金鑰",
        .oneCredentialGroup: "1 組憑證",
        .credentialGroupCount: "%d 組憑證",
        .noKeyConfigured: "未配置金鑰",
        .openDashboard: "開啟控制台",
        .refreshQuotaAction: "刷新額度",
        .refreshingQuotaAction: "正在刷新額度",
        .refreshQuotaConsumesQuotaAction: "刷新額度（消耗 1 次請求）",
        .testConnection: "測試連線",
        .costlyConnectionTestTitle: "此測試會消耗額度",
        .costlyConnectionTestMessage: "測試此服務商會發出一次真實請求並消耗額度。確認需要消耗 1 次請求後再繼續。",
        .testConnectionConsumesQuota: "測試並消耗額度",
        .disabled: "停用",
        .quotaUnavailable: "額度不可用",
        .noSubscribedPlan: "未發現訂閱套餐",
        .planEndsDate: "套餐 %@ 到期",
        .quotaActivity: "動態",
        .quotaActivityRemaining: "剩餘 %@",
        .quotaTrend: "趨勢",
        .quotaTrendReplenished: "已恢復",
        .quotaTrendStable: "穩定",
        .quotaRefreshDeltaConsumed: "剩餘 -%@",
        .quotaRefreshDeltaNoChange: "剛剛更新 · 無變化",
        .quotaRefreshDeltaRecovered: "已重置",
        .quotaRefreshDeltaFailed: "刷新失敗",
        .keyName: "憑證名稱",
        .apiKey: "API 金鑰",
        .apiKeyForCopy: "API 金鑰（可選）",
        .apiKeyForCopyHelp: "僅用於保存、顯示和複製。若此服務商不支援用 API 金鑰查詢額度，額度監控仍使用網頁登入授權。",
        .apiKeySaved: "API key 已儲存",
        .apiKeyStoredForCopyOnly: "僅保存用於複製",
        .invocationAPIKeySaved: "調用金鑰已保存",
        .webLoginCredential: "網頁登入",
        .saved: "已保存",
        .includesInvocationAPIKey: "含調用金鑰",
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
        .providerOrder: "Provider 順序",
        .providerOrderDescription: "調整服務商在額度監控、配置憑證、診斷和狀態列中的顯示順序。",
        .providerOrderLockedDescription: "Provider 順序已在設定中鎖定。開啟自訂 Provider 順序後即可移動。",
        .providerOrderSheetTitle: "Provider 順序",
        .providerOrderSheetDescription: "拖動服務商，設定額度監控、配置憑證、診斷和狀態列共用的顯示順序。",
        .dragProviderOrderHint: "長按或拖動服務商列，放到目標位置。AI 搜尋和 LLM 會保持分組。",
        .resetProviderOrder: "重設順序",
        .moveProviderUp: "上移",
        .moveProviderDown: "下移",
        .remaining: "剩餘",
        .version: "版本 0.3.5",
        .credentialExpired: "憑證已過期",
        .notificationLowQuotaTitle: "額度偏低",
        .notificationLowQuotaBody: "%@ 剩餘 %@。",
        .notificationQuotaExhaustedTitle: "額度已耗盡",
        .notificationQuotaExhaustedBody: "%@ 已無可用額度。",
        .notificationCredentialExpiredTitle: "登入授權已過期",
        .notificationCredentialExpiredBody: "%@ 需要重新登入授權。",
        .notificationRepeatedFailuresTitle: "額度檢查連續失敗",
        .notificationRepeatedFailuresBody: "%@ 已連續 %d 次檢查失敗。",
        .updateLoginAuthorizationAction: "更新登入授權",
        .importedFromEnv: "從 .env 匯入",
        .importedFromClaude: "從 ~/.claude/settings.json 匯入",
        .adminCredentialRequired: "需要 API 金鑰",
        .reauthenticate: "重新認證",
        .dashboardSession: "網頁登入授權",
        .credentialState: "狀態",
        .credentialStateNotConfigured: "未配置",
        .credentialStateConfiguredUntested: "已配置，待檢測",
        .credentialStateUsable: "可用",
        .credentialStateCredentialExpired: "憑證已過期",
        .credentialStateQuotaUnavailable: "介面不可查詢額度",
        .credentialStateCheckConsumesQuota: "檢查會消耗額度",
        .credentialStateCheckFailed: "檢查失敗",
        .requestProxyMode: "代理",
        .automaticRefresh: "自動刷新",
        .automaticRefreshSkipped: "已跳過",
        .healthStatus: "健康狀態",
        .diagnosticMessage: "診斷資訊",
        .diagnosticDetails: "詳情",
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
        .reset: "重設",
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
        .customProviderOrder: "プロバイダー順序をカスタム",
        .customProviderOrderDescription: "オンにするとプロバイダーの順序を変更できます。オフでは既定の順序を固定します。",
        .configureProviderOrder: "順序を調整",
        .watchedProviders: "よく見る",
        .watchedProvidersDescription: "メニューバーの上部に置くプロバイダーを最大 2 つ選びます。",
        .configureWatchedProviders: "設定",
        .addWatchedProviderAction: "よく見るに追加",
        .removeWatchedProviderAction: "よく見るから削除",
        .watchedProvidersSheetTitle: "よく見る",
        .watchedProvidersSheetHint: "よく見るプロバイダーをメニューバー上部に置きます。クォータのお知らせは下に表示されます。",
        .settingsGeneralSection: "一般",
        .settingsRefreshSection: "更新",
        .settingsNetworkSection: "ネットワーク",
        .settingsAppearanceSection: "外観",
        .settingsUpdateSection: "アップデート",
        .automaticUpdateCheck: "自動アップデート確認",
        .automaticUpdateCheckDescription: "バックグラウンドで GitHub Releases を確認します。新しいバージョンはリリースノート付きで表示されますが、確認するまでダウンロードされません。",
        .checkForUpdates: "アップデートを確認",
        .checkForUpdatesDescription: "GitHub Releases を確認します。ダウンロードとアプリの置き換えは確認後に開始されます。",
        .checkingForUpdates: "アップデートを確認中...",
        .updateAvailableStatus: "%@ が利用可能",
        .updateAvailableTitle: "Quota Radar %@ が利用可能です",
        .updateAvailableMessage: "現在のバージョンは %@ です。続行すると、Quota Radar は GitHub Releases から %@ をダウンロードし、インストール済みアプリを置き換え、quarantine を解除して再起動します。",
        .releaseNotes: "リリースノート",
        .releaseNotesUnavailable: "このバージョンのリリースノートはありません。",
        .downloadAndInstallUpdate: "ダウンロードしてインストール",
        .later: "後で",
        .openReleasePage: "リリースページを開く",
        .noUpdatesAvailable: "Quota Radar は最新です",
        .noUpdatesAvailableDescription: "バージョン %@ は現在利用可能な最新リリースです。",
        .updateCheckFailed: "アップデートを確認できません",
        .updateDownloadStarted: "%@ をダウンロード中...",
        .updateInstallPreparing: "インストールを準備中...",
        .updateInstallingRelaunch: "インストールして再起動中...",
        .updateDownloadFailed: "アップデート失敗：%@",
        .updateMissingDMGAsset: "最新リリースに QuotaRadar.dmg が含まれていません。",
        .updateLatestReleaseUnavailable: "最新の GitHub リリースを解決できませんでした。",
        .updateHTTPStatusError: "GitHub が HTTP %d を返しました。",
        .statusBarTransparency: "メニューバー透明度",
        .statusBarTransparencyDescription: "メニューバーポップオーバーのフロストガラス透明度を調整します。",
        .launchAtLogin: "ログイン時に起動",
        .launchAtLoginDescription: "macOS にサインインした後、Quota Radar を自動的に起動します。",
        .autoRefreshInterval: "更新間隔",
        .autoRefreshDescription: "Quota Radar がバックグラウンドでプロバイダーのクォータを更新する頻度を選択します。",
        .autoRefreshBraveWarning: "Brave のチェックは実際の検索リクエストを 1 回消費するため、自動更新ではスキップされます。",
        .quotaConsumingAutoRefreshInterval: "検索更新",
        .quotaConsumingAutoRefreshWarning: "実際の検索クォータを消費してよい場合のみ有効にしてください。このチェックは長い更新間隔を使います。",
        .quotaConsumingManualOnlyWarning: "コストのあるチェックは手動確認が必要で、自動実行されません。",
        .autoRefreshFiveMinutes: "5 分ごと",
        .autoRefreshFifteenMinutes: "15 分ごと",
        .autoRefreshThirtyMinutes: "30 分ごと",
        .autoRefreshOneHour: "1 時間ごと",
        .quotaConsumingAutoRefreshSixHours: "6 時間ごと",
        .quotaConsumingAutoRefreshTwelveHours: "12 時間ごと",
        .quotaConsumingAutoRefreshOneDay: "毎日",
        .networkProxy: "プロキシ",
        .networkProxyDescription: "クォータ確認がプロバイダー API へ接続する経路を選択します。",
        .networkProxySystem: "システム",
        .networkProxyDirect: "直接接続",
        .networkProxyCustom: "カスタム",
        .customProxyURL: "プロキシ URL",
        .customProxyPlaceholder: "http://127.0.0.1:7890",
        .customProxyHelp: "Clash や Surge などのローカルプロキシを使う場合はカスタムを選びます。システムは macOS のネットワーク設定に従います。",
        .apiQuotaTitle: "クォータレーダー",
        .sidebarStatistics: "統計",
        .noApiKeys: "認証情報がありません",
        .noApiKeysMessage: ".env をインポートするか、認証情報ページで追加すると、ここにプロバイダーのクォータが表示されます。",
        .openSettings: "設定を開く",
        .keys: "キー",
        .providers: "プロバイダー",
        .quotaRiskToday: "今日のクォータリスク",
        .statusItemFailedCount: "%d 失敗",
        .statusItemLowCount: "%d 低",
        .available: "利用可能",
        .failed: "失敗",
        .needsAttention: "お知らせ",
        .noAttentionItems: "お知らせはありません",
        .low: "低残量",
        .keyQuota: "重要クォータ",
        .credentialPool: "認証情報プール",
        .criticalTime: "重要時刻",
        .accountTiming: "時刻",
        .plan: "プラン",
        .lowQuotaProviders: "残量わずか",
        .expiringSoon: "期限間近",
        .recentProviderUsage: "最近の変化",
        .recentUsageDetail: "残量変化",
        .hiddenQuotaSignalCount: "ほか %d 件の確認項目",
        .statusBarAccountCount: "%d アカウント",
        .oneCredential: "1 キー",
        .usableCredentialCount: "%d 使用可",
        .attentionCredentialCount: "%d 要確認",
        .categoryCounts: "%d プロバイダー · %d キー",
        .activeCount: "%d 有効",
        .providerKeyCount: "%d キー",
        .oneCredentialGroup: "1 認証情報グループ",
        .credentialGroupCount: "%d 認証情報グループ",
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
        .credential: "認証情報",
        .apiKeyForCopy: "API キー（任意）",
        .apiKeyForCopyHelp: "表示とコピーのためだけに保存します。このプロバイダーが API キーで使用量を公開しない場合、クォータ監視には Web ログイン認証を使います。",
        .apiKeySaved: "API キー保存済み",
        .apiKeyStoredForCopyOnly: "コピー用に保存済み",
        .invocationAPIKeySaved: "呼び出し用 API キー保存済み",
        .webLoginCredential: "Web ログイン",
        .saved: "保存済み",
        .includesInvocationAPIKey: "呼び出しキーあり",
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
        .providerOrder: "プロバイダー順序",
        .providerOrderDescription: "クォータ監視、認証情報、診断、メニューバーで使うプロバイダー順序を調整します。",
        .providerOrderLockedDescription: "プロバイダー順序は設定でロックされています。カスタム順序をオンにすると移動できます。",
        .providerOrderSheetTitle: "プロバイダー順序",
        .providerOrderSheetDescription: "プロバイダーをドラッグして、クォータ監視、認証情報、診断、メニューバーで共有する順序を設定します。",
        .dragProviderOrderHint: "プロバイダー行を長押しまたはドラッグして目的の位置に置きます。AI 検索と LLM はグループのままです。",
        .resetProviderOrder: "順序をリセット",
        .moveProviderUp: "上へ移動",
        .moveProviderDown: "下へ移動",
        .providersSupported: "%d 設定済み · %d 対応",
        .total: "合計",
        .remaining: "残り",
        .aboutSubtitle: "API クォータをリアルタイムで監視",
        .featureSupport: "複数 API プロバイダー対応",
        .featureRealtime: "プロバイダー単位のクォータ更新",
        .featureGlass: "フロストガラスのメニューバー UI",
        .featureMenuBar: "メニューバーから素早くアクセス",
        .version: "バージョン 0.3.5",
        .importNoKeys: "%@ に対応する認証情報が見つかりません。",
        .importSummary: "%d 件を新規インポートし、%d 件を更新しました。",
        .refreshAlreadyRunning: "更新中です",
        .refreshing: "更新中...",
        .refreshingProvider: "%@ を更新中...",
        .updatedJustNow: "たった今更新しました",
        .failedRefresh: "%d 件のキー更新に失敗",
        .refreshQuotaAction: "クォータを更新",
        .refreshingQuotaAction: "クォータを更新中",
        .refreshQuotaConsumesQuotaAction: "クォータ更新（1 回消費）",
        .testConnection: "接続をテスト",
        .costlyConnectionTestTitle: "このテストはクォータを消費します",
        .costlyConnectionTestMessage: "このプロバイダーのテストは実際のリクエストを送信し、クォータを 1 回分消費します。続行しますか。",
        .testConnectionConsumesQuota: "テストして消費",
        .resetDate: "%@ にリセット",
        .planEndsDate: "プラン終了 %@",
        .quotaActivity: "使用状況",
        .quotaActivityRemaining: "残り %@",
        .quotaTrend: "推移",
        .quotaTrendReplenished: "回復",
        .quotaTrendStable: "安定",
        .quotaRefreshDeltaConsumed: "残り -%@",
        .quotaRefreshDeltaNoChange: "更新 · 変化なし",
        .quotaRefreshDeltaRecovered: "リセット",
        .quotaRefreshDeltaFailed: "更新失敗",
        .resetsMonthlyDay1: "毎月 1 日にリセット",
        .noResetCycle: "リセット周期なし",
        .resetNotExposed: "リセット時刻は非公開",
        .credentialExpired: "認証情報の期限切れ",
        .notificationLowQuotaTitle: "クォータ残量が低下",
        .notificationLowQuotaBody: "%@ の残量は %@ です。",
        .notificationQuotaExhaustedTitle: "クォータを使い切りました",
        .notificationQuotaExhaustedBody: "%@ のクォータ残量がありません。",
        .notificationCredentialExpiredTitle: "ログイン認証の期限切れ",
        .notificationCredentialExpiredBody: "%@ は再ログイン認証が必要です。",
        .notificationRepeatedFailuresTitle: "クォータ確認が連続失敗",
        .notificationRepeatedFailuresBody: "%@ は %d 回連続で確認に失敗しました。",
        .updateLoginAuthorizationAction: "ログイン認証を更新",
        .reauthenticate: "再認証",
        .saveCookie: "ログイン認証を保存",
        .cookieSaved: "ログイン認証を保存しました",
        .noCookiesFound: "一致するログイン情報が見つかりません",
        .missingRequiredCookies: "不足しているログイン情報: %@",
        .reauthTitle: "%@ を再認証",
        .reauthDescription: "プロバイダーのダッシュボードにログインしてください。ログイン後、Quota Radar が必要なアプリ内ログイン認証を自動保存します。",
        .reauthSavingTo: "%@ に保存",
        .reauthWillCreate: "%@ を作成",
        .reauthMultipleCredentialHint: "このプロバイダーには複数のログイン認証があります。このウィンドウは上に表示された対象を更新します。",
        .reauthTargetCredential: "保存先",
        .reauthCreateNewCredential: "新しい認証を作成",
        .reauthSelectTarget: "認証情報を選択",
        .reauthSelectTargetBeforeSaving: "保存する前に更新対象の認証情報を選択してください。",
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
        .credentialState: "状態",
        .credentialStateNotConfigured: "未設定",
        .credentialStateConfiguredUntested: "設定済み・未確認",
        .credentialStateUsable: "利用可",
        .credentialStateCredentialExpired: "認証情報の期限切れ",
        .credentialStateQuotaUnavailable: "クォータ取得不可",
        .credentialStateCheckConsumesQuota: "確認でクォータ消費",
        .credentialStateCheckFailed: "確認失敗",
        .requestProxyMode: "プロキシ",
        .automaticRefresh: "自動更新",
        .automaticRefreshSkipped: "スキップ",
        .diagnosticsDescription: "各認証情報の最新チェック結果、HTTP 状態、プロバイダー別診断を確認します。",
        .healthStatus: "ヘルス",
        .httpNotRequested: "未リクエスト",
        .diagnosticMessage: "診断",
        .diagnosticDetails: "詳細",
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
        .reset: "リセット",
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
        .customProviderOrder: "공급자 순서 사용자화",
        .customProviderOrderDescription: "켜면 공급자 순서를 조정할 수 있습니다. 끄면 기본 순서를 고정합니다.",
        .configureProviderOrder: "순서 조정",
        .watchedProviders: "자주 보는 항목",
        .watchedProvidersDescription: "메뉴 막대 위쪽에 둘 공급자를 최대 2개 선택합니다.",
        .configureWatchedProviders: "설정",
        .addWatchedProviderAction: "자주 보는 항목에 추가",
        .removeWatchedProviderAction: "자주 보는 항목에서 제거",
        .watchedProvidersSheetTitle: "자주 보는 항목",
        .watchedProvidersSheetHint: "자주 보는 공급자를 메뉴 막대 위쪽에 둡니다. 할당량 알림은 아래에 계속 표시됩니다.",
        .settingsGeneralSection: "일반",
        .settingsRefreshSection: "새로 고침",
        .settingsNetworkSection: "네트워크",
        .settingsAppearanceSection: "모양",
        .settingsUpdateSection: "업데이트",
        .automaticUpdateCheck: "자동 업데이트 확인",
        .automaticUpdateCheckDescription: "백그라운드에서 GitHub Releases를 확인합니다. 새 버전은 릴리스 노트와 함께 표시되지만 확인하기 전에는 다운로드하지 않습니다.",
        .checkForUpdates: "업데이트 확인",
        .checkForUpdatesDescription: "GitHub Releases를 확인합니다. 다운로드와 앱 교체는 확인 후에만 시작됩니다.",
        .checkingForUpdates: "업데이트 확인 중...",
        .updateAvailableStatus: "%@ 사용 가능",
        .updateAvailableTitle: "Quota Radar %@ 사용 가능",
        .updateAvailableMessage: "현재 버전은 %@입니다. 계속하면 Quota Radar가 GitHub Releases에서 %@를 다운로드하고 설치된 앱을 교체한 뒤 quarantine을 해제하고 다시 시작합니다.",
        .releaseNotes: "릴리스 노트",
        .releaseNotesUnavailable: "이 버전에는 릴리스 노트가 없습니다.",
        .downloadAndInstallUpdate: "다운로드 및 설치",
        .later: "나중에",
        .openReleasePage: "릴리스 페이지 열기",
        .noUpdatesAvailable: "Quota Radar가 최신 버전입니다",
        .noUpdatesAvailableDescription: "버전 %@은 현재 사용 가능한 최신 릴리스입니다.",
        .updateCheckFailed: "업데이트를 확인할 수 없음",
        .updateDownloadStarted: "%@ 다운로드 중...",
        .updateInstallPreparing: "설치 준비 중...",
        .updateInstallingRelaunch: "설치하고 다시 시작하는 중...",
        .updateDownloadFailed: "업데이트 실패: %@",
        .updateMissingDMGAsset: "최신 릴리스에 QuotaRadar.dmg가 포함되어 있지 않습니다.",
        .updateLatestReleaseUnavailable: "최신 GitHub 릴리스를 확인할 수 없습니다.",
        .updateHTTPStatusError: "GitHub가 HTTP %d를 반환했습니다.",
        .statusBarTransparency: "메뉴 막대 투명도",
        .statusBarTransparencyDescription: "메뉴 막대 팝오버의 반투명 효과를 조정합니다.",
        .launchAtLogin: "로그인 시 열기",
        .launchAtLoginDescription: "macOS에 로그인한 후 Quota Radar를 자동으로 시작합니다.",
        .autoRefreshInterval: "새로 고침 주기",
        .autoRefreshDescription: "Quota Radar가 백그라운드에서 공급자 할당량을 새로 고치는 주기를 선택합니다.",
        .autoRefreshBraveWarning: "Brave 확인은 실제 검색 요청 1회를 소비하므로 자동 새로 고침에서 건너뜁니다.",
        .quotaConsumingAutoRefreshInterval: "검색 새로 고침",
        .quotaConsumingAutoRefreshWarning: "실제 검색 할당량을 소비해도 되는 경우에만 켜세요. 이 확인은 더 긴 주기를 사용합니다.",
        .quotaConsumingManualOnlyWarning: "비용이 드는 확인은 수동 확인이 필요하며 자동으로 실행되지 않습니다.",
        .autoRefreshFiveMinutes: "5분마다",
        .autoRefreshFifteenMinutes: "15분마다",
        .autoRefreshThirtyMinutes: "30분마다",
        .autoRefreshOneHour: "매시간",
        .quotaConsumingAutoRefreshSixHours: "6시간마다",
        .quotaConsumingAutoRefreshTwelveHours: "12시간마다",
        .quotaConsumingAutoRefreshOneDay: "매일",
        .networkProxy: "프록시",
        .networkProxyDescription: "할당량 확인이 공급자 API에 연결하는 경로를 선택합니다.",
        .networkProxySystem: "시스템",
        .networkProxyDirect: "직접 연결",
        .networkProxyCustom: "사용자화",
        .customProxyURL: "프록시 URL",
        .customProxyPlaceholder: "http://127.0.0.1:7890",
        .customProxyHelp: "Clash 또는 Surge 같은 로컬 프록시는 사용자화를 선택하세요. 시스템은 macOS 네트워크 설정을 따릅니다.",
        .apiQuotaTitle: "할당량 레이더",
        .sidebarStatistics: "통계",
        .noApiKeys: "자격 증명 없음",
        .noApiKeysMessage: ".env 파일을 가져오거나 자격 증명 페이지에서 추가하면 여기에 공급자 할당량이 표시됩니다.",
        .openSettings: "설정 열기",
        .keys: "키",
        .providers: "공급자",
        .quotaRiskToday: "오늘의 할당량 위험",
        .statusItemFailedCount: "실패 %d개",
        .statusItemLowCount: "낮음 %d개",
        .available: "사용 가능",
        .failed: "실패",
        .needsAttention: "알림",
        .noAttentionItems: "알림 없음",
        .low: "낮음",
        .keyQuota: "핵심 할당량",
        .credentialPool: "자격 증명 풀",
        .criticalTime: "중요 시간",
        .accountTiming: "시간",
        .plan: "플랜",
        .lowQuotaProviders: "할당량 부족",
        .expiringSoon: "곧 만료",
        .recentProviderUsage: "최근 변화",
        .recentUsageDetail: "잔여 변화",
        .hiddenQuotaSignalCount: "추가 확인 항목 %d개",
        .statusBarAccountCount: "계정 %d개",
        .oneCredential: "키 1개",
        .usableCredentialCount: "사용 가능 %d개",
        .attentionCredentialCount: "확인 필요 %d개",
        .categoryCounts: "공급자 %d개 · 키 %d개",
        .activeCount: "활성 %d개",
        .providerKeyCount: "키 %d개",
        .oneCredentialGroup: "자격 증명 그룹 1개",
        .credentialGroupCount: "자격 증명 그룹 %d개",
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
        .credential: "자격 증명",
        .apiKeyForCopy: "API 키(선택 사항)",
        .apiKeyForCopyHelp: "표시와 복사용으로만 저장합니다. 이 공급자가 API 키로 사용량을 공개하지 않으면 할당량 모니터링은 웹 로그인 인증을 사용합니다.",
        .apiKeySaved: "API 키 저장됨",
        .apiKeyStoredForCopyOnly: "복사용으로 저장됨",
        .invocationAPIKeySaved: "호출 API 키 저장됨",
        .webLoginCredential: "웹 로그인",
        .saved: "저장됨",
        .includesInvocationAPIKey: "호출 키 포함",
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
        .providerOrder: "공급자 순서",
        .providerOrderDescription: "할당량 모니터링, 자격 증명, 진단 및 메뉴 막대에 사용할 공급자 순서를 조정합니다.",
        .providerOrderLockedDescription: "공급자 순서가 설정에서 잠겨 있습니다. 사용자 지정 순서를 켜면 이동할 수 있습니다.",
        .providerOrderSheetTitle: "공급자 순서",
        .providerOrderSheetDescription: "공급자를 드래그하여 할당량 모니터링, 자격 증명, 진단 및 메뉴 막대가 공유할 순서를 설정합니다.",
        .dragProviderOrderHint: "공급자 행을 길게 누르거나 드래그하여 원하는 위치에 놓습니다. AI 검색과 LLM은 그룹으로 유지됩니다.",
        .resetProviderOrder: "순서 재설정",
        .moveProviderUp: "위로 이동",
        .moveProviderDown: "아래로 이동",
        .providersSupported: "설정됨 %d개 · 지원 %d개",
        .total: "전체",
        .remaining: "남음",
        .aboutSubtitle: "API 할당량을 실시간으로 모니터링",
        .featureSupport: "여러 API 공급자 지원",
        .featureRealtime: "공급자별 할당량 새로 고침",
        .featureGlass: "반투명 메뉴 막대 UI",
        .featureMenuBar: "메뉴 막대 빠른 접근",
        .version: "버전 0.3.5",
        .importNoKeys: "%@에서 지원되는 자격 증명을 찾을 수 없습니다.",
        .importSummary: "새로 %d개 가져오고 %d개 키를 업데이트했습니다.",
        .refreshAlreadyRunning: "새로 고침 중입니다",
        .refreshing: "새로 고치는 중...",
        .refreshingProvider: "%@ 새로 고치는 중...",
        .updatedJustNow: "방금 업데이트됨",
        .failedRefresh: "키 %d개 새로 고침 실패",
        .refreshQuotaAction: "할당량 새로 고침",
        .refreshingQuotaAction: "할당량 새로 고침 중",
        .refreshQuotaConsumesQuotaAction: "할당량 새로 고침(요청 1회 사용)",
        .testConnection: "연결 테스트",
        .costlyConnectionTestTitle: "이 테스트는 할당량을 소비합니다",
        .costlyConnectionTestMessage: "이 공급자 테스트는 실제 요청을 보내 할당량 1회를 소비합니다. 계속하시겠습니까?",
        .testConnectionConsumesQuota: "테스트하고 할당량 소비",
        .resetDate: "%@ 재설정",
        .planEndsDate: "%@ 플랜 종료",
        .quotaActivity: "활동",
        .quotaActivityRemaining: "%@ 남음",
        .quotaTrend: "추세",
        .quotaTrendReplenished: "복구됨",
        .quotaTrendStable: "안정",
        .quotaRefreshDeltaConsumed: "남음 -%@",
        .quotaRefreshDeltaNoChange: "업데이트 · 변화 없음",
        .quotaRefreshDeltaRecovered: "재설정됨",
        .quotaRefreshDeltaFailed: "새로 고침 실패",
        .resetsMonthlyDay1: "매월 1일 재설정",
        .noResetCycle: "재설정 주기 없음",
        .resetNotExposed: "재설정 시간이 공개되지 않음",
        .credentialExpired: "자격 증명 만료됨",
        .notificationLowQuotaTitle: "할당량 부족",
        .notificationLowQuotaBody: "%@ 남은 할당량은 %@입니다.",
        .notificationQuotaExhaustedTitle: "할당량 소진",
        .notificationQuotaExhaustedBody: "%@에 남은 할당량이 없습니다.",
        .notificationCredentialExpiredTitle: "로그인 인증 만료",
        .notificationCredentialExpiredBody: "%@에 새 로그인 인증이 필요합니다.",
        .notificationRepeatedFailuresTitle: "할당량 확인 연속 실패",
        .notificationRepeatedFailuresBody: "%@ 확인이 %d회 연속 실패했습니다.",
        .updateLoginAuthorizationAction: "로그인 인증 업데이트",
        .reauthenticate: "다시 인증",
        .saveCookie: "로그인 인증 저장",
        .cookieSaved: "로그인 인증 저장됨",
        .noCookiesFound: "일치하는 로그인 정보를 찾을 수 없음",
        .missingRequiredCookies: "누락된 필수 로그인 정보: %@",
        .reauthTitle: "%@ 다시 인증",
        .reauthDescription: "공급자 대시보드에 로그인하세요. 로그인 후 Quota Radar가 필요한 앱 내 로그인 인증을 자동 저장합니다.",
        .reauthSavingTo: "%@에 저장",
        .reauthWillCreate: "%@ 생성 예정",
        .reauthMultipleCredentialHint: "이 공급자에는 저장된 로그인 인증이 여러 개 있습니다. 이 창은 위에 표시된 대상을 업데이트합니다.",
        .reauthTargetCredential: "저장 대상",
        .reauthCreateNewCredential: "새 인증 만들기",
        .reauthSelectTarget: "자격 증명 선택",
        .reauthSelectTargetBeforeSaving: "저장하기 전에 업데이트할 자격 증명을 선택하세요.",
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
        .credentialState: "상태",
        .credentialStateNotConfigured: "구성 안 됨",
        .credentialStateConfiguredUntested: "구성됨, 미확인",
        .credentialStateUsable: "사용 가능",
        .credentialStateCredentialExpired: "자격 증명 만료됨",
        .credentialStateQuotaUnavailable: "할당량 조회 불가",
        .credentialStateCheckConsumesQuota: "확인 시 할당량 소비",
        .credentialStateCheckFailed: "확인 실패",
        .requestProxyMode: "프록시",
        .automaticRefresh: "자동 새로 고침",
        .automaticRefreshSkipped: "건너뜀",
        .diagnosticsDescription: "각 자격 증명의 최근 확인 결과, HTTP 상태 및 공급자별 진단을 검토합니다.",
        .healthStatus: "상태",
        .httpNotRequested: "요청 안 함",
        .diagnosticMessage: "진단",
        .diagnosticDetails: "세부 정보",
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
        .reset: "재설정",
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
