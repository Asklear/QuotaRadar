import Foundation
import Combine

enum RefreshMode {
    case manual
    case automatic
    case quotaConsumingAutomatic
}

@MainActor
class QuotaMonitor: ObservableObject {
    static let shared = QuotaMonitor()
    private static let providerOrderDefaultsKey = "providerOrder"
    private static let customProviderOrderEnabledDefaultsKey = "customProviderOrderEnabled"

    @Published var apiKeys: [APIKey] = []
    @Published var isRefreshing = false
    @Published var refreshingProviders: Set<Provider> = []
    @Published var lastError: String?
    @Published var refreshMessage: String?
    @Published private(set) var providerOrder: [Provider] = []
    @Published var isCustomProviderOrderEnabled = false {
        didSet {
            defaults.set(isCustomProviderOrderEnabled, forKey: Self.customProviderOrderEnabledDefaultsKey)
        }
    }

    private let service = QuotaService()
    private let store: APIKeyStore
    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    init(store: APIKeyStore = APIKeyStore(), defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
        isCustomProviderOrderEnabled = defaults.bool(forKey: Self.customProviderOrderEnabledDefaultsKey)
        providerOrder = Provider.orderedVisibleCases(
            fromRawValues: defaults.stringArray(forKey: Self.providerOrderDefaultsKey) ?? []
        )
        loadKeys()
    }

    var orderedVisibleProviders: [Provider] {
        isCustomProviderOrderEnabled ? Provider.orderedVisibleCases(from: providerOrder) : Provider.visibleCases
    }

    var providerStats: [ProviderStats] {
        let grouped = Dictionary(grouping: apiKeys) { $0.provider }
        let stats: [ProviderStats] = orderedVisibleProviders.compactMap { provider in
            guard let keys = grouped[provider], !keys.isEmpty else { return nil }
            return ProviderStats(provider: provider, keys: keys)
        }
        return stats
    }

    var homeProviderStats: [ProviderStats] {
        let grouped = Dictionary(grouping: apiKeys) { $0.provider }
        let stats: [ProviderStats] = orderedVisibleProviders.compactMap { provider in
            let keys = grouped[provider] ?? []
            guard !keys.isEmpty || provider.homeVisibleWithoutKeys else { return nil }
            return ProviderStats(provider: provider, keys: keys)
        }
        return stats
    }

    var homeCategoryStats: [ProviderCategoryStats] {
        let stats = homeProviderStats
        return Provider.categoryDisplayOrder.compactMap { title in
            let providerStats = stats.filter { $0.provider.statusBarCategoryTitle == title }
            guard !providerStats.isEmpty else { return nil }
            return ProviderCategoryStats(title: title, stats: providerStats)
        }
    }

    var menuTopQuotaItems: [MenuQuotaItem] {
        MenuQuotaItem.topItems(from: homeProviderStats, limit: 3, providerOrder: orderedVisibleProviders)
    }

    var menuQuotaSummary: MenuQuotaSummary {
        MenuQuotaSummary(keys: apiKeys)
    }

    var menuAttentionQuotaItems: [MenuQuotaItem] {
        MenuQuotaItem.attentionItems(from: homeProviderStats, limit: 2, providerOrder: orderedVisibleProviders)
    }

    var menuLowQuotaItems: [MenuQuotaItem] {
        MenuQuotaItem.lowQuotaItems(from: homeProviderStats, limit: 3, providerOrder: orderedVisibleProviders)
    }

    var menuExpiringQuotaItems: [MenuQuotaItem] {
        MenuQuotaItem.expiringSoonItems(from: homeProviderStats, limit: 3, providerOrder: orderedVisibleProviders)
    }

    func moveProvider(_ provider: Provider, before targetProvider: Provider) {
        guard isCustomProviderOrderEnabled else { return }
        guard provider != targetProvider else { return }
        guard provider.statusBarCategoryTitle == targetProvider.statusBarCategoryTitle else { return }

        var nextOrder = orderedVisibleProviders
        guard
            let currentIndex = nextOrder.firstIndex(of: provider),
            let targetIndex = nextOrder.firstIndex(of: targetProvider)
        else {
            return
        }

        let movedProvider = nextOrder.remove(at: currentIndex)
        let adjustedTargetIndex = currentIndex < targetIndex ? targetIndex - 1 : targetIndex
        nextOrder.insert(movedProvider, at: adjustedTargetIndex)
        setProviderOrder(nextOrder)
    }

    func resetProviderOrder() {
        providerOrder = Provider.visibleCases
        defaults.removeObject(forKey: Self.providerOrderDefaultsKey)
    }

    func refreshAll(mode: RefreshMode = .manual) {
        refresh(targetProviders: nil, mode: mode)
    }

    func refreshProvider(_ provider: Provider, mode: RefreshMode = .manual) {
        refresh(targetProviders: [provider], mode: mode)
    }

    func refreshQuotaConsumingProviders(mode: RefreshMode = .quotaConsumingAutomatic) {
        let providers = Set(Provider.visibleCases.filter { $0.quotaCheckConsumesSearchQuota })
        guard !providers.isEmpty else { return }
        refresh(targetProviders: providers, mode: mode)
    }

    func refreshProvidersDueForAutomaticRefresh(
        interval: TimeInterval,
        consumesSearchQuota: Bool,
        mode: RefreshMode
    ) {
        let providers = Self.providersDueForAutomaticRefresh(
            in: apiKeys,
            interval: interval,
            consumesSearchQuota: consumesSearchQuota
        )
        guard !providers.isEmpty else { return }
        refresh(targetProviders: providers, mode: mode)
    }

    static func providersDueForAutomaticRefresh(
        in keys: [APIKey],
        interval: TimeInterval,
        consumesSearchQuota: Bool,
        now: Date = Date()
    ) -> Set<Provider> {
        Provider.providersDueForAutomaticRefresh(
            in: keys,
            interval: interval,
            consumesSearchQuota: consumesSearchQuota,
            now: now
        )
    }

    private func refresh(targetProviders: Set<Provider>?, mode: RefreshMode) {
        guard !isRefreshing else {
            if mode == .manual {
                refreshMessage = L10n.t(.refreshAlreadyRunning)
            }
            return
        }
        isRefreshing = true
        refreshingProviders = targetProviders ?? Set(Provider.visibleCases)
        lastError = nil
        if mode == .manual {
            if let provider = targetProviders?.first, targetProviders?.count == 1 {
                refreshMessage = L10n.format(.refreshingProvider, provider.displayName())
            } else {
                refreshMessage = L10n.t(.refreshing)
            }
        } else {
            refreshMessage = nil
        }

        Task {
            self.ensureSecretsLoaded()

            var updatedKeys: [APIKey] = []
            var failedKeys: [String] = []
            var foundTargetKey = false

            for var key in apiKeys {
                guard Provider.visibleCases.contains(key.provider) else {
                    updatedKeys.append(key)
                    continue
                }

                if let targetProviders, !targetProviders.contains(key.provider) {
                    updatedKeys.append(key)
                    continue
                }

                guard key.isActive, !key.key.isEmpty else {
                    updatedKeys.append(key)
                    continue
                }

                if key.isStoredAPIKeyOnlyCredential {
                    updatedKeys.append(key)
                    continue
                }

                foundTargetKey = true

                if mode == .automatic && key.provider.quotaCheckConsumesSearchQuota {
                    if key.lastUpdated == nil, key.quotaLabel == nil {
                        key.quotaLabel = "Manual refresh only"
                        key.quotaText = LocalizedTextDescriptor.localized(.manualRefreshOnly)
                    }
                    key.lastDiagnosticMessage = L10n.t(.quotaConsumingRefreshWarning)
                    key.lastDiagnosticText = LocalizedTextDescriptor.localized(.quotaConsumingRefreshWarning)
                    updatedKeys.append(key)
                    continue
                }

                do {
                    let result = try await service.checkQuota(for: key, bypassCooldown: mode == .manual)
                    key.remaining = result.remaining
                    key.limit = result.limit
                    key.resetAt = result.resetAt
                    key.planEndsAt = result.planEndsAt
                    key.quotaLabel = result.quotaLabel
                    key.quotaText = result.quotaText
                    key.lastHTTPStatus = result.httpStatus
                    key.lastDiagnosticMessage = result.diagnosticMessage
                    key.lastDiagnosticText = result.diagnosticText
                    key.lastUpdated = Date()
                    updatedKeys.append(key)
                } catch {
                    print("Failed to check quota for \(key.name): \(error)")
                    if case QuotaError.cooldown = error {
                        updatedKeys.append(key)
                        continue
                    } else if case QuotaError.notSupported = error {
                        key.remaining = nil
                        key.limit = nil
                        key.resetAt = nil
                        key.planEndsAt = nil
                        key.quotaLabel = key.provider.localizedUnsupportedQuotaLabel()
                        key.quotaText = LocalizedTextDescriptor.localized(.quotaUnavailable)
                        key.lastHTTPStatus = nil
                        key.lastDiagnosticMessage = key.provider.unsupportedQuotaDiagnosticMessage()
                        key.lastDiagnosticText = LocalizedTextDescriptor.localized(
                            key.isBusinessInvocationCredential
                                ? .businessInvocationKeyQuotaInstruction
                                : .quotaCheckNotSupportedDiagnostic
                        )
                        key.lastUpdated = Date()
                    } else if case QuotaError.noSubscription = error {
                        key.remaining = nil
                        key.limit = nil
                        key.resetAt = nil
                        key.planEndsAt = nil
                        key.quotaLabel = "No subscribed plan"
                        key.quotaText = LocalizedTextDescriptor.localized(.noSubscribedPlan)
                        key.lastHTTPStatus = 200
                        key.lastDiagnosticMessage = "No subscribed plan"
                        key.lastDiagnosticText = LocalizedTextDescriptor.localized(.noSubscribedPlan)
                        key.lastUpdated = Date()
                    } else if case QuotaError.unauthorized = error {
                        key.remaining = nil
                        key.limit = nil
                        key.resetAt = nil
                        key.planEndsAt = nil
                        key.lastHTTPStatus = (error as? QuotaError)?.httpStatus ?? 401
                        if key.provider.supportsDashboardReauthentication {
                            key.quotaLabel = L10n.t(.credentialExpired)
                            key.quotaText = LocalizedTextDescriptor.localized(.credentialExpired)
                        } else {
                            key.quotaLabel = error.localizedDescription
                            key.quotaText = LocalizedTextDescriptor.localized(.quotaErrorInvalidAPIKey)
                        }
                        key.lastDiagnosticMessage = key.provider.supportsDashboardReauthentication ? L10n.t(.credentialExpired) : error.localizedDescription
                        key.lastDiagnosticText = key.provider.supportsDashboardReauthentication
                            ? LocalizedTextDescriptor.localized(.credentialExpired)
                            : LocalizedTextDescriptor.localized(.quotaErrorInvalidAPIKey)
                        key.lastUpdated = Date()
                        failedKeys.append(key.name)
                    } else if case QuotaError.invalidAPIKey = error {
                        key.remaining = nil
                        key.limit = nil
                        key.resetAt = nil
                        key.planEndsAt = nil
                        key.lastHTTPStatus = (error as? QuotaError)?.httpStatus
                        key.quotaLabel = error.localizedDescription
                        key.quotaText = LocalizedTextDescriptor.localized(.quotaErrorInvalidAPIKey)
                        key.lastDiagnosticMessage = error.localizedDescription
                        key.lastDiagnosticText = LocalizedTextDescriptor.localized(.quotaErrorInvalidAPIKey)
                        key.lastUpdated = Date()
                        failedKeys.append(key.name)
                    } else {
                        key.lastHTTPStatus = (error as? QuotaError)?.httpStatus
                        key.lastDiagnosticMessage = error.localizedDescription
                        key.lastDiagnosticText = (error as? QuotaError)?.localizedTextDescriptor
                        key.lastUpdated = Date()
                        failedKeys.append(key.name)
                    }
                    updatedKeys.append(key)
                }
            }

            self.apiKeys = updatedKeys
            if let targetProviders, !foundTargetKey, targetProviders.count == 1 {
                self.refreshMessage = L10n.t(.noKeyConfigured)
                self.lastError = nil
            } else if !failedKeys.isEmpty {
                self.lastError = L10n.format(.failedRefresh, failedKeys.count)
                self.refreshMessage = nil
            } else if mode == .manual {
                self.refreshMessage = L10n.t(.updatedJustNow)
            } else {
                self.refreshMessage = nil
            }
            self.saveKeys()
            self.refreshingProviders = []
            self.isRefreshing = false
        }
    }

    func addKey(_ key: APIKey) {
        apiKeys.append(key)
        saveKeys()
    }

    func removeKey(id: UUID) {
        apiKeys.removeAll { $0.id == id }
        store.delete(id: id)
        saveKeys()
    }

    func updateKey(_ key: APIKey) {
        if let index = apiKeys.firstIndex(where: { $0.id == key.id }) {
            apiKeys[index] = key
            saveKeys()
        }
    }

    @discardableResult
    func importKeys(_ importedKeys: [APIKey]) -> ImportSummary {
        guard !importedKeys.isEmpty else {
            return ImportSummary(added: 0, updated: 0, skipped: 0)
        }

        var mergedKeys = apiKeys
        let summary = mergeImportedKeys(importedKeys, into: &mergedKeys)
        apiKeys = mergedKeys
        if summary.added > 0 || summary.updated > 0 {
            saveKeys()
        }
        return summary
    }

    // MARK: - Persistence

    private func saveKeys() {
        store.save(apiKeys)
    }

    private func setProviderOrder(_ order: [Provider]) {
        providerOrder = Provider.orderedVisibleCases(from: order)
        defaults.set(providerOrder.map(\.rawValue), forKey: Self.providerOrderDefaultsKey)
    }

    private func loadKeys() {
        let loadedKeys = store.load()
        var hydratedKeys = store.loadSecrets(for: loadedKeys)

        if !store.didAttemptClaudeSettingsImport {
            let importedKeys = ClaudeSettingsImporter.parseDefaultSettings()
            store.markClaudeSettingsImportAttempted()

            if !importedKeys.isEmpty {
                let summary = mergeImportedKeys(importedKeys, into: &hydratedKeys)
                if summary.added > 0 || summary.updated > 0 {
                    apiKeys = hydratedKeys
                    saveKeys()
                    return
                }
            }
        }

        apiKeys = hydratedKeys
    }

    private func ensureSecretsLoaded() {
        apiKeys = store.loadSecrets(for: apiKeys)
    }

    private func mergeImportedKeys(_ importedKeys: [APIKey], into existingKeys: inout [APIKey]) -> ImportSummary {
        var added = 0
        var updated = 0
        var skipped = 0

        for importedKey in importedKeys {
            guard !importedKey.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                skipped += 1
                continue
            }

            if let index = existingKeys.firstIndex(where: {
                $0.provider == importedKey.provider && $0.name == importedKey.name
            }) {
                let existingKey = existingKeys[index]

                guard existingKey.key != importedKey.key || existingKey.note != importedKey.note else {
                    skipped += 1
                    continue
                }

                var replacement = importedKey
                replacement.id = existingKey.id
                replacement.isActive = existingKey.isActive
                replacement.remaining = existingKey.remaining
                replacement.limit = existingKey.limit
                replacement.resetAt = existingKey.resetAt
                replacement.planEndsAt = existingKey.planEndsAt
                replacement.lastUpdated = existingKey.lastUpdated
                replacement.lastHTTPStatus = existingKey.lastHTTPStatus
                replacement.lastDiagnosticMessage = existingKey.lastDiagnosticMessage
                replacement.lastDiagnosticText = existingKey.lastDiagnosticText
                replacement.quotaLabel = existingKey.quotaLabel
                replacement.quotaText = existingKey.quotaText
                replacement.usageCount = existingKey.usageCount
                replacement.lastUsed = existingKey.lastUsed
                existingKeys[index] = replacement
                updated += 1
            } else {
                existingKeys.append(importedKey)
                added += 1
            }
        }

        return ImportSummary(added: added, updated: updated, skipped: skipped)
    }
}

// Keep first launch empty. Users import their own .env or add keys manually.
struct DefaultKeys {
    static let keys: [APIKey] = []
}

// 示例数据（用于预览）
struct SampleData {
    static let keys: [APIKey] = [
        APIKey(name: "TAVILY_API_KEY", key: "demo", provider: .tavily, remaining: 850, limit: 1000, lastUpdated: Date()),
        APIKey(name: "BRAVE_API_KEY", key: "demo", provider: .brave, remaining: 1800, limit: 2000, lastUpdated: Date()),
    ]
}
