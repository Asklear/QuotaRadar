import Combine
import Foundation
import ServiceManagement

enum AutoRefreshIntervalOption: String, CaseIterable, Identifiable {
    case off
    case fiveMinutes
    case fifteenMinutes
    case thirtyMinutes
    case oneHour

    var id: String { rawValue }

    var timeInterval: TimeInterval? {
        switch self {
        case .off:
            return nil
        case .fiveMinutes:
            return 5 * 60
        case .fifteenMinutes:
            return 15 * 60
        case .thirtyMinutes:
            return 30 * 60
        case .oneHour:
            return 60 * 60
        }
    }

    var displayName: String {
        switch self {
        case .off:
            return L10n.t(.off)
        case .fiveMinutes:
            return L10n.t(.autoRefreshFiveMinutes)
        case .fifteenMinutes:
            return L10n.t(.autoRefreshFifteenMinutes)
        case .thirtyMinutes:
            return L10n.t(.autoRefreshThirtyMinutes)
        case .oneHour:
            return L10n.t(.autoRefreshOneHour)
        }
    }
}

enum QuotaConsumingAutoRefreshIntervalOption: String, CaseIterable, Identifiable {
    case off
    case sixHours
    case twelveHours
    case oneDay

    var id: String { rawValue }

    var timeInterval: TimeInterval? {
        switch self {
        case .off:
            return nil
        case .sixHours:
            return 6 * 60 * 60
        case .twelveHours:
            return 12 * 60 * 60
        case .oneDay:
            return 24 * 60 * 60
        }
    }

    var displayName: String {
        switch self {
        case .off:
            return L10n.t(.off)
        case .sixHours:
            return L10n.t(.quotaConsumingAutoRefreshSixHours)
        case .twelveHours:
            return L10n.t(.quotaConsumingAutoRefreshTwelveHours)
        case .oneDay:
            return L10n.t(.quotaConsumingAutoRefreshOneDay)
        }
    }
}

enum NetworkProxyModeOption: String, CaseIterable, Identifiable {
    case system
    case direct
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            return L10n.t(.networkProxySystem)
        case .direct:
            return L10n.t(.networkProxyDirect)
        case .custom:
            return L10n.t(.networkProxyCustom)
        }
    }
}

enum AppThemeModeOption: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            return L10n.t(.appearanceModeSystem)
        case .light:
            return L10n.t(.appearanceModeLight)
        case .dark:
            return L10n.t(.appearanceModeDark)
        }
    }
}

final class AppAppearanceStore: ObservableObject {
    static let shared = AppAppearanceStore()
    static let appearanceModeKey = "appearanceMode"
    static let statusBarTransparencyKey = "statusBarTransparency"
    static let autoRefreshIntervalKey = "autoRefreshInterval"
    static let quotaConsumingAutoRefreshIntervalKey = "quotaConsumingAutoRefreshInterval"
    static let networkProxyModeKey = "networkProxyMode"
    static let customProxyURLKey = "customProxyURL"
    static let automaticallyCheckForUpdatesKey = "automaticallyCheckForUpdates"

    @Published var appearanceMode: AppThemeModeOption {
        didSet {
            defaults.set(appearanceMode.rawValue, forKey: Self.appearanceModeKey)
        }
    }

    @Published var statusBarTransparency: Double {
        didSet {
            let value = Self.clamped(statusBarTransparency)
            if value != statusBarTransparency {
                statusBarTransparency = value
                return
            }
            defaults.set(value, forKey: Self.statusBarTransparencyKey)
        }
    }

    @Published var autoRefreshInterval: AutoRefreshIntervalOption {
        didSet {
            defaults.set(autoRefreshInterval.rawValue, forKey: Self.autoRefreshIntervalKey)
        }
    }

    @Published var quotaConsumingAutoRefreshInterval: QuotaConsumingAutoRefreshIntervalOption {
        didSet {
            defaults.set(quotaConsumingAutoRefreshInterval.rawValue, forKey: Self.quotaConsumingAutoRefreshIntervalKey)
        }
    }

    @Published var networkProxyMode: NetworkProxyModeOption {
        didSet {
            defaults.set(networkProxyMode.rawValue, forKey: Self.networkProxyModeKey)
        }
    }

    @Published var customProxyURL: String {
        didSet {
            defaults.set(customProxyURL, forKey: Self.customProxyURLKey)
        }
    }

    @Published var automaticallyCheckForUpdates: Bool {
        didSet {
            defaults.set(automaticallyCheckForUpdates, forKey: Self.automaticallyCheckForUpdatesKey)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let rawValue = defaults.string(forKey: Self.appearanceModeKey),
           let mode = AppThemeModeOption(rawValue: rawValue) {
            appearanceMode = mode
        } else {
            appearanceMode = .system
        }

        if let visualQATransparency = Self.visualQAStatusBarTransparencyOverride {
            statusBarTransparency = visualQATransparency
        } else if defaults.object(forKey: Self.statusBarTransparencyKey) == nil {
            statusBarTransparency = 0.58
        } else {
            statusBarTransparency = Self.clamped(defaults.double(forKey: Self.statusBarTransparencyKey))
        }

        if let rawValue = defaults.string(forKey: Self.autoRefreshIntervalKey),
           let interval = AutoRefreshIntervalOption(rawValue: rawValue) {
            autoRefreshInterval = interval
        } else {
            autoRefreshInterval = .fifteenMinutes
        }

        if let rawValue = defaults.string(forKey: Self.quotaConsumingAutoRefreshIntervalKey),
           let interval = QuotaConsumingAutoRefreshIntervalOption(rawValue: rawValue) {
            quotaConsumingAutoRefreshInterval = interval
        } else {
            quotaConsumingAutoRefreshInterval = .off
        }

        if let rawValue = defaults.string(forKey: Self.networkProxyModeKey),
           let mode = NetworkProxyModeOption(rawValue: rawValue) {
            networkProxyMode = mode
        } else {
            networkProxyMode = .system
        }

        customProxyURL = defaults.string(forKey: Self.customProxyURLKey) ?? ""

        if defaults.object(forKey: Self.automaticallyCheckForUpdatesKey) == nil {
            automaticallyCheckForUpdates = true
        } else {
            automaticallyCheckForUpdates = defaults.bool(forKey: Self.automaticallyCheckForUpdatesKey)
        }
    }

    private static func clamped(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }

    private static var visualQAStatusBarTransparencyOverride: Double? {
        guard let rawValue = ProcessInfo.processInfo.environment["QUOTARADAR_VISUAL_QA_TRANSPARENCY"],
              let value = Double(rawValue) else {
            return nil
        }
        return clamped(value)
    }

    static func configuredURLSessionConfiguration(defaults: UserDefaults = .standard) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60

        let mode = defaults.string(forKey: networkProxyModeKey)
            .flatMap(NetworkProxyModeOption.init(rawValue:))
            ?? .system

        switch mode {
        case .system:
            break
        case .direct:
            config.connectionProxyDictionary = [:]
        case .custom:
            let rawURL = defaults.string(forKey: customProxyURLKey) ?? ""
            if let endpoint = NetworkProxyEndpoint(rawURL: rawURL) {
                config.connectionProxyDictionary = endpoint.connectionProxyDictionary
            }
        }

        return config
    }
}

private struct NetworkProxyEndpoint {
    let scheme: String
    let host: String
    let port: Int

    init?(rawURL: String) {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.contains("://") ? trimmed : "http://\(trimmed)"
        guard let components = URLComponents(string: normalized),
              let host = components.host,
              !host.isEmpty else {
            return nil
        }

        let scheme = (components.scheme ?? "http").lowercased()
        self.scheme = scheme
        self.host = host
        self.port = components.port ?? Self.defaultPort(for: scheme)
    }

    var connectionProxyDictionary: [AnyHashable: Any] {
        switch scheme {
        case "sock", "socks", "socks5":
            return [
                "SOCKSEnable": 1,
                "SOCKSProxy": host,
                "SOCKSPort": port,
            ]
        default:
            return [
                "HTTPEnable": 1,
                "HTTPProxy": host,
                "HTTPPort": port,
                "HTTPSEnable": 1,
                "HTTPSProxy": host,
                "HTTPSPort": port,
            ]
        }
    }

    private static func defaultPort(for scheme: String) -> Int {
        switch scheme {
        case "https":
            return 443
        case "sock", "socks", "socks5":
            return 1080
        default:
            return 80
        }
    }
}

final class LaunchAtLoginStore: ObservableObject {
    static let shared = LaunchAtLoginStore()

    @Published private(set) var isEnabled: Bool
    @Published var lastError: String?

    init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
            refresh()
        } catch {
            lastError = error.localizedDescription
            refresh()
        }
    }
}
