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

final class AppAppearanceStore: ObservableObject {
    static let shared = AppAppearanceStore()
    static let statusBarTransparencyKey = "statusBarTransparency"
    static let autoRefreshIntervalKey = "autoRefreshInterval"

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

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Self.statusBarTransparencyKey) == nil {
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
    }

    private static func clamped(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
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
