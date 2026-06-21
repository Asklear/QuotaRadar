import Foundation
import UserNotifications

enum QuotaThresholdNotificationKind: String, Codable, Equatable {
    case credentialExpired
    case quotaExhausted
    case repeatedFailures
    case lowQuota
    case quotaRecovered
}

struct QuotaThresholdNotificationEvent: Identifiable, Equatable {
    let kind: QuotaThresholdNotificationKind
    let keyID: UUID
    let provider: Provider
    let title: String
    let body: String

    var id: String {
        "\(kind.rawValue):\(keyID.uuidString)"
    }
}

struct QuotaThresholdNotificationStore {
    private let defaults: UserDefaults
    private let deliveredEventIDsKey = "quotaThresholdNotificationDeliveredEventIDs"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func freshEvents(from activeEvents: [QuotaThresholdNotificationEvent]) -> [QuotaThresholdNotificationEvent] {
        let deliveredIDs = Set(defaults.stringArray(forKey: deliveredEventIDsKey) ?? [])
        return activeEvents.filter { !deliveredIDs.contains($0.id) }
    }

    func markDelivered(
        _ deliveredEvents: [QuotaThresholdNotificationEvent],
        retainingActive activeEvents: [QuotaThresholdNotificationEvent]
    ) {
        let activeIDs = Set(activeEvents.map(\.id))
        let deliveredIDs = Set(defaults.stringArray(forKey: deliveredEventIDsKey) ?? [])
        let nextIDs = deliveredIDs
            .intersection(activeIDs)
            .union(deliveredEvents.map(\.id))
        defaults.set(Array(nextIDs), forKey: deliveredEventIDsKey)
    }

    func clearResolvedEvents(retainingActive activeEvents: [QuotaThresholdNotificationEvent]) {
        let activeIDs = Set(activeEvents.map(\.id))
        let deliveredIDs = Set(defaults.stringArray(forKey: deliveredEventIDsKey) ?? [])
        defaults.set(Array(deliveredIDs.intersection(activeIDs)), forKey: deliveredEventIDsKey)
    }
}

final class QuotaThresholdNotificationService {
    static let shared = QuotaThresholdNotificationService()

    private static let lowQuotaThreshold = 0.20
    private static let repeatedFailureThreshold = 3

    private let center: UNUserNotificationCenter
    private let store: QuotaThresholdNotificationStore

    init(
        center: UNUserNotificationCenter = .current(),
        store: QuotaThresholdNotificationStore = QuotaThresholdNotificationStore()
    ) {
        self.center = center
        self.store = store
    }

    func notifyIfNeeded(for keys: [APIKey], snapshots: [QuotaSnapshot] = [], now: Date = Date()) {
        let activeEvents = Self.events(for: keys, snapshots: snapshots, now: now)
        store.clearResolvedEvents(retainingActive: activeEvents)
        let freshEvents = store.freshEvents(from: activeEvents)
        guard !freshEvents.isEmpty else { return }

        center.getNotificationSettings { [center, store] settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                Self.deliver(freshEvents, center: center)
                store.markDelivered(freshEvents, retainingActive: activeEvents)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    guard granted else { return }
                    Self.deliver(freshEvents, center: center)
                    store.markDelivered(freshEvents, retainingActive: activeEvents)
                }
            case .denied:
                return
            @unknown default:
                return
            }
        }
    }

    static func events(
        for keys: [APIKey],
        snapshots: [QuotaSnapshot] = [],
        now: Date = Date()
    ) -> [QuotaThresholdNotificationEvent] {
        (keys.compactMap(notificationEvent) + recoveryEvents(for: keys, snapshots: snapshots, now: now))
            .sorted { lhs, rhs in
                if lhs.kind.priority != rhs.kind.priority {
                    return lhs.kind.priority < rhs.kind.priority
                }
                return lhs.provider.displayName().localizedStandardCompare(rhs.provider.displayName()) == .orderedAscending
            }
    }

    private static func notificationEvent(for key: APIKey) -> QuotaThresholdNotificationEvent? {
        guard key.isActive,
              !key.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !key.isStoredAPIKeyOnlyCredential else {
            return nil
        }

        if key.isCredentialExpired {
            return event(kind: .credentialExpired, key: key)
        }

        if key.isUsageLimitExceeded || key.isExhausted {
            return event(kind: .quotaExhausted, key: key)
        }

        if key.consecutiveFailureCount >= repeatedFailureThreshold {
            return event(kind: .repeatedFailures, key: key)
        }

        if isBelowLowQuotaThreshold(key) {
            return event(kind: .lowQuota, key: key)
        }

        return nil
    }

    private static func recoveryEvents(
        for keys: [APIKey],
        snapshots: [QuotaSnapshot],
        now: Date
    ) -> [QuotaThresholdNotificationEvent] {
        guard !snapshots.isEmpty else { return [] }

        return keys.compactMap { key in
            guard key.isActive,
                  !key.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !key.isStoredAPIKeyOnlyCredential else {
                return nil
            }

            guard let latestRefreshItem = QuotaRefreshHistoryItem.items(
                for: key,
                snapshots: snapshots,
                limit: 1,
                now: now
            ).first,
                  latestRefreshItem.kind == .recovered,
                  now.timeIntervalSince(latestRefreshItem.recordedAt) <= QuotaRefreshDeltaSummary.recentRefreshWindow else {
                return nil
            }

            return event(kind: .quotaRecovered, key: key)
        }
    }

    private static func isBelowLowQuotaThreshold(_ key: APIKey) -> Bool {
        guard let remaining = key.remaining,
              let limit = key.limit,
              limit > 0,
              remaining > 0,
              remaining != Int.max,
              limit != Int.max else {
            return false
        }
        return Double(remaining) / Double(limit) <= lowQuotaThreshold
    }

    private static func event(kind: QuotaThresholdNotificationKind, key: APIKey) -> QuotaThresholdNotificationEvent {
        QuotaThresholdNotificationEvent(
            kind: kind,
            keyID: key.id,
            provider: key.provider,
            title: kind.title,
            body: kind.body(for: key)
        )
    }

    private static func deliver(_ events: [QuotaThresholdNotificationEvent], center: UNUserNotificationCenter) {
        for event in events {
            let content = UNMutableNotificationContent()
            content.title = event.title
            content.body = event.body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "quotaradar.\(event.id)",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}

private extension QuotaThresholdNotificationKind {
    var priority: Int {
        switch self {
        case .credentialExpired:
            return 0
        case .quotaExhausted:
            return 1
        case .repeatedFailures:
            return 2
        case .lowQuota:
            return 3
        case .quotaRecovered:
            return 4
        }
    }

    var title: String {
        switch self {
        case .credentialExpired:
            return L10n.t(.notificationCredentialExpiredTitle)
        case .quotaExhausted:
            return L10n.t(.notificationQuotaExhaustedTitle)
        case .repeatedFailures:
            return L10n.t(.notificationRepeatedFailuresTitle)
        case .lowQuota:
            return L10n.t(.notificationLowQuotaTitle)
        case .quotaRecovered:
            return L10n.t(.notificationQuotaRecoveredTitle)
        }
    }

    func body(for key: APIKey) -> String {
        let providerName = key.provider.displayName()
        switch self {
        case .credentialExpired:
            return L10n.format(.notificationCredentialExpiredBody, providerName)
        case .quotaExhausted:
            return L10n.format(.notificationQuotaExhaustedBody, providerName)
        case .repeatedFailures:
            return L10n.format(.notificationRepeatedFailuresBody, providerName, key.consecutiveFailureCount)
        case .lowQuota:
            return L10n.format(.notificationLowQuotaBody, providerName, key.remainingBadgeText)
        case .quotaRecovered:
            return L10n.format(.notificationQuotaRecoveredBody, providerName)
        }
    }
}
