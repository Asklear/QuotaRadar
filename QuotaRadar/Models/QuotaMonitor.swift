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
    private static let menuWatchedProvidersDefaultsKey = "menuWatchedProviders"
    private static let menuSignalItemLimit = 4
    private static let menuWatchedProviderLimit = 2

    @Published var apiKeys: [APIKey] = []
    @Published var isRefreshing = false
    @Published var refreshingProviders: Set<Provider> = []
    @Published var resettingCodexQuotaKeyIDs: Set<UUID> = []
    @Published var lastError: String?
    @Published var refreshMessage: String?
    @Published private(set) var providerOrder: [Provider] = []
    @Published private(set) var menuWatchedProviders: [Provider] = []
    @Published private(set) var quotaSnapshots: [QuotaSnapshot] = []
    @Published var isCustomProviderOrderEnabled = false {
        didSet {
            defaults.set(isCustomProviderOrderEnabled, forKey: Self.customProviderOrderEnabledDefaultsKey)
        }
    }

    private let service = QuotaService()
    private let store: APIKeyStore
    private let historyStore: QuotaHistoryStore
    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    init(
        store: APIKeyStore = APIKeyStore(),
        historyStore: QuotaHistoryStore = QuotaHistoryStore(),
        defaults: UserDefaults = .standard
    ) {
        self.store = store
        self.historyStore = historyStore
        self.defaults = defaults
        isCustomProviderOrderEnabled = defaults.bool(forKey: Self.customProviderOrderEnabledDefaultsKey)
        providerOrder = Provider.orderedVisibleCases(
            fromRawValues: defaults.stringArray(forKey: Self.providerOrderDefaultsKey) ?? []
        )
        menuWatchedProviders = Self.sanitizedMenuWatchedProviders(
            defaults.stringArray(forKey: Self.menuWatchedProvidersDefaultsKey) ?? []
        )

        if Self.usesVisualQAFixtures {
            let fixtures = Self.visualQAFixtures(now: Date())
            providerOrder = Provider.visibleCases
            menuWatchedProviders = [.deepseek, .brave]
            quotaSnapshots = fixtures.snapshots
            apiKeys = fixtures.keys
            return
        }

        quotaSnapshots = historyStore.load()
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

    var menuSignalLayout: MenuQuotaSignalLayout {
        MenuQuotaSignalLayout.make(
            from: homeProviderStats,
            snapshots: quotaSnapshots,
            visibleLimit: Self.menuSignalItemLimit,
            providerOrder: orderedVisibleProviders,
            watchedProviders: menuWatchedProviders
        )
    }

    var menuWatchedProviderItems: [MenuQuotaItem] {
        menuSignalLayout.watchedProviderItems
    }

    var menuAttentionQuotaItems: [MenuQuotaItem] {
        menuSignalLayout.attentionItems
    }

    var menuLowQuotaItems: [MenuQuotaItem] {
        menuSignalLayout.lowQuotaItems
    }

    var menuExpiringQuotaItems: [MenuQuotaItem] {
        menuSignalLayout.expiringSoonItems
    }

    var menuRecentUsageQuotaItems: [MenuQuotaItem] {
        menuSignalLayout.recentUsageItems
    }

    var menuHiddenQuotaSignalCount: Int {
        menuSignalLayout.hiddenItemCount
    }

    func trendSummary(for key: APIKey) -> QuotaTrendSummary {
        QuotaTrendSummary.trendSummary(for: key, snapshots: quotaSnapshots)
    }

    func refreshDeltaText(for key: APIKey) -> String? {
        QuotaRefreshDeltaSummary.refreshDeltaText(for: key, snapshots: quotaSnapshots)
    }

    func refreshHistoryItems(for key: APIKey) -> [QuotaRefreshHistoryItem] {
        QuotaRefreshHistoryItem.items(for: key, snapshots: quotaSnapshots)
    }

    func activitySummary(for key: APIKey) -> QuotaActivitySummary {
        QuotaActivitySummary.activitySummary(for: key, snapshots: quotaSnapshots)
    }

    func consumptionSpeedSummary(for key: APIKey) -> QuotaConsumptionSpeedSummary {
        QuotaConsumptionSpeedSummary.speedSummary(for: key, snapshots: quotaSnapshots)
    }

    func sparklineSamples(for key: APIKey) -> [QuotaSparklineSample] {
        QuotaSparklineSample.samples(for: key, snapshots: quotaSnapshots)
    }

    func setMenuWatchedProviders(_ providers: [Provider]) {
        let sanitized = Self.sanitizedMenuWatchedProviders(providers.map(\.rawValue))
        menuWatchedProviders = sanitized
        if sanitized.isEmpty {
            defaults.removeObject(forKey: Self.menuWatchedProvidersDefaultsKey)
        } else {
            defaults.set(sanitized.map(\.rawValue), forKey: Self.menuWatchedProvidersDefaultsKey)
        }
    }

    func toggleMenuWatchedProvider(_ provider: Provider) {
        guard Provider.visibleCases.contains(provider) else { return }
        var nextProviders = menuWatchedProviders
        if nextProviders.contains(provider) {
            nextProviders.removeAll { $0 == provider }
        } else {
            nextProviders.append(provider)
        }
        setMenuWatchedProviders(nextProviders)
    }

    func isMenuWatchedProvider(_ provider: Provider) -> Bool {
        menuWatchedProviders.contains(provider)
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

    private static func sanitizedMenuWatchedProviders(_ rawValues: [String]) -> [Provider] {
        var providers: [Provider] = []
        for rawValue in rawValues {
            guard
                let provider = Provider(rawValue: rawValue),
                Provider.visibleCases.contains(provider),
                !providers.contains(provider)
            else {
                continue
            }
            providers.append(provider)
        }
        return Array(providers.prefix(Self.menuWatchedProviderLimit))
    }

    func refreshAll(mode: RefreshMode = .manual) {
        refresh(targetProviders: nil, mode: mode)
    }

    func refreshProvider(_ provider: Provider, mode: RefreshMode = .manual) {
        refresh(targetProviders: [provider], mode: mode)
    }

    func resetCodexQuota(for keyID: UUID) {
        guard !resettingCodexQuotaKeyIDs.contains(keyID) else { return }
        ensureSecretsLoaded()
        guard let index = apiKeys.firstIndex(where: { $0.id == keyID }),
              apiKeys[index].canResetCodexQuota else {
            return
        }

        resettingCodexQuotaKeyIDs.insert(keyID)
        refreshMessage = nil
        lastError = nil
        let resetKey = apiKeys[index]

        Task {
            do {
                let result = try await service.resetCodexSubscriptionQuota(key: resetKey)
                guard let currentIndex = self.apiKeys.firstIndex(where: { $0.id == keyID }) else {
                    self.resettingCodexQuotaKeyIDs.remove(keyID)
                    return
                }
                var updatedKey = self.apiKeys[currentIndex]
                self.applySuccessfulQuotaResult(result, to: &updatedKey, now: Date())
                self.apiKeys[currentIndex] = updatedKey
                self.recordQuotaSnapshot(for: updatedKey, outcome: .success)
                self.refreshMessage = L10n.t(.updatedJustNow)
                self.lastError = nil
                self.saveKeys()
                QuotaThresholdNotificationService.shared.notifyIfNeeded(
                    for: self.apiKeys,
                    snapshots: self.quotaSnapshots
                )
            } catch {
                if let currentIndex = self.apiKeys.firstIndex(where: { $0.id == keyID }) {
                    self.apiKeys[currentIndex].lastHTTPStatus = (error as? QuotaError)?.httpStatus
                    self.apiKeys[currentIndex].lastDiagnosticMessage = error.localizedDescription
                    self.apiKeys[currentIndex].lastDiagnosticText = (error as? QuotaError)?.localizedTextDescriptor
                    self.apiKeys[currentIndex].consecutiveFailureCount += 1
                    self.apiKeys[currentIndex].lastUpdated = Date()
                    self.recordQuotaSnapshot(for: self.apiKeys[currentIndex], outcome: .failed)
                    self.saveKeys()
                }
                self.refreshMessage = nil
                self.lastError = error.localizedDescription
            }
            self.resettingCodexQuotaKeyIDs.remove(keyID)
        }
    }

    func refreshQuotaConsumingProviders(mode: RefreshMode = .quotaConsumingAutomatic) {
        let providers = Set(Provider.visibleCases.filter {
            $0.capability.matchesAutomaticRefreshLane(consumesSearchQuota: true)
        })
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

    nonisolated static func refreshCandidateKeys(
        from keys: [APIKey],
        targetProviders: Set<Provider>?
    ) -> [APIKey] {
        var candidates = keys

        for provider in Provider.visibleCases {
            if let targetProviders, !targetProviders.contains(provider) {
                continue
            }
            guard let sourceProvider = sharedDashboardAuthorizationSourceProvider(for: provider) else {
                continue
            }
            let hasDirectMonitoringCredential = keys.contains {
                $0.provider == provider && !$0.isStoredAPIKeyOnlyCredential
            }
            guard !hasDirectMonitoringCredential else {
                continue
            }

            let sourceCredentials = keys.filter {
                $0.provider == sourceProvider
                    && $0.isActive
                    && !$0.isStoredAPIKeyOnlyCredential
                    && !$0.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }

            for (index, sourceCredential) in sourceCredentials.enumerated() {
                candidates.append(
                    derivedDashboardCredential(
                        from: sourceCredential,
                        provider: provider,
                        ordinal: index + 1,
                        sourceCount: sourceCredentials.count
                    )
                )
            }
        }

        return candidates
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

            for var key in Self.refreshCandidateKeys(from: apiKeys, targetProviders: targetProviders) {
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

                if mode == .automatic && !key.provider.capability.allowsAutomaticRefresh {
                    if key.lastUpdated == nil, key.quotaLabel == nil {
                        key.quotaLabel = "Manual refresh only"
                        key.quotaText = LocalizedTextDescriptor.localized(.manualRefreshOnly)
                    }
                    key.lastDiagnosticMessage = L10n.t(.quotaConsumingRefreshWarning)
                    key.lastDiagnosticText = LocalizedTextDescriptor.localized(.quotaConsumingRefreshWarning)
                    key.lastHTTPStatus = nil
                    recordQuotaSnapshot(for: key, outcome: .skipped)
                    updatedKeys.append(key)
                    continue
                }

                do {
                    let result = try await service.checkQuota(for: key, bypassCooldown: mode == .manual)
                    applySuccessfulQuotaResult(result, to: &key, now: Date())
                    recordQuotaSnapshot(for: key, outcome: .success)
                    updatedKeys.append(key)
                } catch {
                    print("Failed to check quota for \(key.name): \(error)")
                    let outcome: QuotaSnapshotOutcome
                    if case QuotaError.cooldown = error {
                        updatedKeys.append(key)
                        continue
                    } else if case QuotaError.notSupported = error {
                        key.remaining = nil
                        key.limit = nil
                        key.resetAt = nil
                        key.planEndsAt = nil
                        key.planDisplayName = nil
                        key.codexResetCreditsRemaining = nil
                        key.quotaLabel = key.provider.localizedUnsupportedQuotaLabel()
                        key.quotaText = LocalizedTextDescriptor.localized(.quotaUnavailable)
                        key.lastHTTPStatus = nil
                        key.lastDiagnosticMessage = key.provider.unsupportedQuotaDiagnosticMessage()
                        key.lastDiagnosticText = LocalizedTextDescriptor.localized(
                            key.isBusinessInvocationCredential
                                ? .businessInvocationKeyQuotaInstruction
                                : .quotaCheckNotSupportedDiagnostic
                        )
                        key.consecutiveFailureCount = 0
                        key.lastUpdated = Date()
                        outcome = .unsupported
                    } else if case QuotaError.noSubscription = error {
                        key.remaining = nil
                        key.limit = nil
                        key.resetAt = nil
                        key.planEndsAt = nil
                        key.planDisplayName = nil
                        key.codexResetCreditsRemaining = nil
                        key.quotaLabel = "No subscribed plan"
                        key.quotaText = LocalizedTextDescriptor.localized(.noSubscribedPlan)
                        key.lastHTTPStatus = 200
                        key.lastDiagnosticMessage = "No subscribed plan"
                        key.lastDiagnosticText = LocalizedTextDescriptor.localized(.noSubscribedPlan)
                        key.consecutiveFailureCount = 0
                        key.lastUpdated = Date()
                        outcome = .noSubscription
                    } else if case QuotaError.unauthorized = error {
                        key.remaining = nil
                        key.limit = nil
                        key.resetAt = nil
                        key.planEndsAt = nil
                        key.planDisplayName = nil
                        key.codexResetCreditsRemaining = nil
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
                        key.consecutiveFailureCount = 0
                        key.lastUpdated = Date()
                        failedKeys.append(key.name)
                        outcome = .unauthorized
                    } else if case QuotaError.invalidAPIKey = error {
                        key.remaining = nil
                        key.limit = nil
                        key.resetAt = nil
                        key.planEndsAt = nil
                        key.planDisplayName = nil
                        key.codexResetCreditsRemaining = nil
                        key.lastHTTPStatus = (error as? QuotaError)?.httpStatus
                        key.quotaLabel = error.localizedDescription
                        key.quotaText = LocalizedTextDescriptor.localized(.quotaErrorInvalidAPIKey)
                        key.lastDiagnosticMessage = error.localizedDescription
                        key.lastDiagnosticText = LocalizedTextDescriptor.localized(.quotaErrorInvalidAPIKey)
                        key.consecutiveFailureCount += 1
                        key.lastUpdated = Date()
                        failedKeys.append(key.name)
                        outcome = .unauthorized
                    } else {
                        key.lastHTTPStatus = (error as? QuotaError)?.httpStatus
                        key.lastDiagnosticMessage = error.localizedDescription
                        key.lastDiagnosticText = (error as? QuotaError)?.localizedTextDescriptor
                        key.consecutiveFailureCount += 1
                        key.lastUpdated = Date()
                        failedKeys.append(key.name)
                        outcome = .failed
                    }
                    recordQuotaSnapshot(for: key, outcome: outcome)
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
            QuotaThresholdNotificationService.shared.notifyIfNeeded(
                for: self.apiKeys,
                snapshots: self.quotaSnapshots
            )
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
        quotaSnapshots = historyStore.deleteSnapshots(for: id, existing: quotaSnapshots)
        historyStore.save(quotaSnapshots)
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
        if Self.usesVisualQAFixtures {
            return
        }
        store.save(apiKeys)
    }

    private func applySuccessfulQuotaResult(_ result: QuotaResult, to key: inout APIKey, now: Date) {
        key.remaining = result.remaining
        key.limit = result.limit
        key.resetAt = result.resetAt
        key.planEndsAt = result.planEndsAt
        key.planDisplayName = result.planDisplayName
        key.codexResetCreditsRemaining = result.codexResetCreditsRemaining
        key.quotaLabel = result.quotaLabel
        key.quotaText = result.quotaText
        key.lastHTTPStatus = result.httpStatus
        key.lastDiagnosticMessage = result.diagnosticMessage
        key.lastDiagnosticText = result.diagnosticText
        key.consecutiveFailureCount = 0
        key.lastUpdated = now
    }

    private func recordQuotaSnapshot(for key: APIKey, outcome: QuotaSnapshotOutcome) {
        if Self.usesVisualQAFixtures {
            return
        }
        let snapshot = QuotaSnapshot(
            keyID: key.id,
            provider: key.provider,
            credentialName: key.name,
            outcome: outcome,
            remaining: key.remaining,
            limit: key.limit,
            resetAt: key.resetAt,
            planEndsAt: key.planEndsAt,
            planDisplayName: key.planDisplayName,
            quotaLabel: key.quotaLabel,
            httpStatus: key.lastHTTPStatus,
            quotaWindows: key.quotaWindowDetails.compactMap(QuotaWindowSnapshot.init)
        )
        quotaSnapshots = historyStore.append(snapshot, existing: quotaSnapshots)
        historyStore.save(quotaSnapshots)
    }

    private nonisolated static func sharedDashboardAuthorizationSourceProvider(for provider: Provider) -> Provider? {
        switch provider {
        case .anthropicCredits:
            return .claudeSubscription
        case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .querit, .anthropic, .claudeAPIUsage, .claudeSubscription, .codexAPIUsage, .codexSubscription, .kimiSubscription, .deepseek, .xfyunCodingPlan, .xfyunTokenPlan, .volcengineCodingPlan, .volcengineTokenPlan, .opencodeGo, .aliyunCodingPlan, .aliyunTokenPlan, .tencentCloudCodingPlan, .tencentCloudTokenPlan:
            return nil
        }
    }

    private nonisolated static func derivedDashboardCredential(
        from sourceCredential: APIKey,
        provider: Provider,
        ordinal: Int,
        sourceCount: Int
    ) -> APIKey {
        var credential = sourceCredential
        credential.id = UUID()
        credential.name = sourceCount == 1
            ? provider.defaultCredentialName
            : "\(provider.defaultCredentialName)_\(ordinal)"
        credential.provider = provider
        credential.note = sourceCredential.name == sourceCredential.provider.defaultCredentialName
            ? nil
            : sourceCredential.name
        credential.linkedAuthorizationID = sourceCredential.id
        credential.remaining = nil
        credential.limit = nil
        credential.resetAt = nil
        credential.planEndsAt = nil
        credential.planDisplayName = nil
        credential.codexResetCreditsRemaining = nil
        credential.lastUpdated = nil
        credential.lastHTTPStatus = nil
        credential.lastDiagnosticMessage = nil
        credential.lastDiagnosticText = nil
        credential.consecutiveFailureCount = 0
        credential.quotaText = nil
        credential.quotaLabel = nil
        credential.usageCount = 0
        credential.lastUsed = nil
        return credential
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
        if Self.usesVisualQAFixtures {
            return
        }
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
                replacement.planDisplayName = existingKey.planDisplayName
                replacement.codexResetCreditsRemaining = existingKey.codexResetCreditsRemaining
                replacement.lastUpdated = existingKey.lastUpdated
                replacement.lastHTTPStatus = existingKey.lastHTTPStatus
                replacement.lastDiagnosticMessage = existingKey.lastDiagnosticMessage
                replacement.lastDiagnosticText = existingKey.lastDiagnosticText
                replacement.consecutiveFailureCount = existingKey.consecutiveFailureCount
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

extension QuotaMonitor {
    private static var usesVisualQAFixtures: Bool {
        ProcessInfo.processInfo.environment["QUOTARADAR_VISUAL_QA_FIXTURES"] == "1"
    }

    private static func visualQAFixtureKeys(now: Date) -> [APIKey] {
        visualQAFixtures(now: now).keys
    }

    private static func visualQAFixtures(now: Date) -> (keys: [APIKey], snapshots: [QuotaSnapshot]) {
        let calendar = Calendar(identifier: .gregorian)
        let hourReset = calendar.date(byAdding: .hour, value: 4, to: now) ?? now
        let weekReset = calendar.date(byAdding: .day, value: 3, to: now) ?? now
        let monthReset = calendar.date(byAdding: .day, value: 22, to: now) ?? now
        let soonPlanEnd = calendar.date(byAdding: .day, value: 6, to: now) ?? now
        let annualPlanEnd = calendar.date(byAdding: .month, value: 8, to: now) ?? now
        let recentPast = now.addingTimeInterval(-90 * 60)

        let claudeID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let volcengineLowID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
        let volcengineHealthyID = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
        let codexID = UUID(uuidString: "10000000-0000-0000-0000-000000000004")!
        let xfyunID = UUID(uuidString: "10000000-0000-0000-0000-000000000005")!
        let deepseekID = UUID(uuidString: "10000000-0000-0000-0000-000000000006")!
        let braveID = UUID(uuidString: "10000000-0000-0000-0000-000000000007")!
        let tencentID = UUID(uuidString: "10000000-0000-0000-0000-000000000008")!

        let keys = [
            visualQAFixtureKey(
                id: claudeID,
                name: "Claude Pro authorization with an intentionally long diagnostic message",
                key: "claude-session-visual-qa",
                provider: .claudeSubscription,
                lastUpdated: now,
                lastHTTPStatus: 503,
                lastDiagnosticMessage: "Dashboard usage endpoint returned an unusually long upstream error summary after authentication, proxy negotiation, and organization selection; this should truncate without overlapping adjacent controls."
            ),
            visualQAFixtureKey(
                id: volcengineLowID,
                name: "Volcengine Lite primary account",
                key: "volcengine-cookie-visual-qa-1",
                provider: .volcengineCodingPlan,
                remaining: 70,
                limit: 1000,
                planDisplayName: "Lite 权益",
                lastUpdated: now,
                quotaText: .quotaWindows([
                    QuotaWindowText(name: "5h", percentText: "7%", resetAt: hourReset, remainingText: "420 / 6000"),
                    QuotaWindowText(name: "week", percentText: "42%", resetAt: weekReset, remainingText: "42000 / 100000"),
                    QuotaWindowText(name: "month", percentText: "64%", resetAt: monthReset, remainingText: "640000 / 1000000"),
                ])
            ),
            visualQAFixtureKey(
                id: volcengineHealthyID,
                name: "Volcengine Lite backup account",
                key: "volcengine-cookie-visual-qa-2",
                provider: .volcengineCodingPlan,
                remaining: 740,
                limit: 1000,
                planDisplayName: "Lite 权益",
                lastUpdated: now,
                quotaText: .quotaWindows([
                    QuotaWindowText(name: "5h", percentText: "74%", resetAt: hourReset, remainingText: "4440 / 6000"),
                    QuotaWindowText(name: "week", percentText: "82%", resetAt: weekReset, remainingText: "82000 / 100000"),
                    QuotaWindowText(name: "month", percentText: "91%", resetAt: monthReset, remainingText: "910000 / 1000000"),
                ])
            ),
            visualQAFixtureKey(
                id: codexID,
                name: "Codex Pro authorization",
                key: "codex-session-visual-qa",
                provider: .codexSubscription,
                remaining: 860,
                limit: 1000,
                planEndsAt: soonPlanEnd,
                planDisplayName: "Pro",
                codexResetCreditsRemaining: 3,
                lastUpdated: now,
                quotaText: .quotaWindows([
                    QuotaWindowText(name: "5h", percentText: "96%", resetAt: hourReset, remainingText: "96 / 100"),
                    QuotaWindowText(name: "week", percentText: "86%", resetAt: weekReset, remainingText: "860 / 1000"),
                ])
            ),
            visualQAFixtureKey(
                id: xfyunID,
                name: "XFYun Spark Pro monthly package account",
                key: "xfyun-cookie-visual-qa",
                provider: .xfyunCodingPlan,
                remaining: 430,
                limit: 1000,
                planEndsAt: annualPlanEnd,
                planDisplayName: "Pro 资源包月套餐",
                lastUpdated: now,
                quotaText: .quotaWindows([
                    QuotaWindowText(name: "5h", percentText: "53%", resetAt: hourReset, remainingText: "3180 / 6000"),
                    QuotaWindowText(name: "week", percentText: "62%", resetAt: weekReset, remainingText: "62000 / 100000"),
                    QuotaWindowText(name: "month", percentText: "43%", resetAt: monthReset, remainingText: "430000 / 1000000"),
                ])
            ),
            visualQAFixtureKey(
                id: deepseekID,
                name: "DeepSeek balance account",
                key: "deepseek-key-visual-qa",
                provider: .deepseek,
                remaining: 128800,
                lastUpdated: now,
                quotaLabel: "CNY 1288.00 available"
            ),
            visualQAFixtureKey(
                id: braveID,
                name: "Brave Search response-header key",
                key: "brave-key-visual-qa",
                provider: .brave,
                remaining: Int.max,
                limit: Int.max,
                lastUpdated: now,
                lastHTTPStatus: 200,
                lastDiagnosticMessage: "Search works, but monthly quota is hidden by Brave."
            ),
            visualQAFixtureKey(
                id: tencentID,
                name: "Tencent Cloud Coding Plan enterprise package with long credential label",
                key: "tencent-cloud-cookie-visual-qa",
                provider: .tencentCloudCodingPlan,
                remaining: 880,
                limit: 1000,
                planEndsAt: annualPlanEnd,
                planDisplayName: "高效版-包月",
                lastUpdated: now,
                quotaText: .quotaWindows([
                    QuotaWindowText(name: "5h", percentText: "88%", resetAt: hourReset, remainingText: "880 / 1000"),
                    QuotaWindowText(name: "week", percentText: "91%", resetAt: weekReset, remainingText: "9100 / 10000"),
                    QuotaWindowText(name: "month", percentText: "94%", resetAt: monthReset, remainingText: "94000 / 100000"),
                ])
            ),
        ] + visualQADenseAccountFixtureKeys(now: now)

        let snapshots: [QuotaSnapshot] = [
            visualQAFixtureSnapshot(
                keyID: xfyunID,
                provider: .xfyunCodingPlan,
                credentialName: "XFYun Spark Pro monthly package account",
                recordedAt: recentPast,
                remaining: 500,
                limit: 1000,
                planEndsAt: annualPlanEnd,
                planDisplayName: "Pro 资源包月套餐",
                quotaWindows: [
                    QuotaWindowSnapshot(name: "5h", remainingPercent: 61, resetAt: hourReset),
                    QuotaWindowSnapshot(name: "week", remainingPercent: 66, resetAt: weekReset),
                    QuotaWindowSnapshot(name: "month", remainingPercent: 50, resetAt: monthReset),
                ]
            ),
            visualQAFixtureSnapshot(
                keyID: xfyunID,
                provider: .xfyunCodingPlan,
                credentialName: "XFYun Spark Pro monthly package account",
                recordedAt: now,
                remaining: 430,
                limit: 1000,
                planEndsAt: annualPlanEnd,
                planDisplayName: "Pro 资源包月套餐",
                quotaWindows: [
                    QuotaWindowSnapshot(name: "5h", remainingPercent: 53, resetAt: hourReset),
                    QuotaWindowSnapshot(name: "week", remainingPercent: 62, resetAt: weekReset),
                    QuotaWindowSnapshot(name: "month", remainingPercent: 43, resetAt: monthReset),
                ]
            ),
            visualQAFixtureSnapshot(
                keyID: deepseekID,
                provider: .deepseek,
                credentialName: "DeepSeek balance account",
                recordedAt: recentPast,
                remaining: 130100,
                limit: nil,
                quotaLabel: "CNY 1301.00 available"
            ),
            visualQAFixtureSnapshot(
                keyID: deepseekID,
                provider: .deepseek,
                credentialName: "DeepSeek balance account",
                recordedAt: now,
                remaining: 128800,
                limit: nil,
                quotaLabel: "CNY 1288.00 available"
            ),
        ]

        return (keys, snapshots)
    }

    private static func visualQAFixtureKey(
        id: UUID,
        name: String,
        key: String,
        provider: Provider,
        remaining: Int? = nil,
        limit: Int? = nil,
        resetAt: Date? = nil,
        planEndsAt: Date? = nil,
        planDisplayName: String? = nil,
        codexResetCreditsRemaining: Int? = nil,
        lastUpdated: Date? = nil,
        lastHTTPStatus: Int? = nil,
        lastDiagnosticMessage: String? = nil,
        quotaText: LocalizedTextDescriptor? = nil,
        quotaLabel: String? = nil
    ) -> APIKey {
        var apiKey = APIKey(name: name, key: key, provider: provider)
        apiKey.id = id
        apiKey.remaining = remaining
        apiKey.limit = limit
        apiKey.resetAt = resetAt
        apiKey.planEndsAt = planEndsAt
        apiKey.planDisplayName = planDisplayName
        apiKey.codexResetCreditsRemaining = codexResetCreditsRemaining
        apiKey.lastUpdated = lastUpdated
        apiKey.lastHTTPStatus = lastHTTPStatus
        apiKey.lastDiagnosticMessage = lastDiagnosticMessage
        apiKey.quotaText = quotaText
        apiKey.quotaLabel = quotaLabel
        return apiKey
    }

    private static func visualQADenseAccountFixtureKeys(now: Date) -> [APIKey] {
        let calendar = Calendar(identifier: .gregorian)
        let hourReset = calendar.date(byAdding: .hour, value: 4, to: now) ?? now
        let weekReset = calendar.date(byAdding: .day, value: 3, to: now) ?? now
        let monthReset = calendar.date(byAdding: .day, value: 22, to: now) ?? now
        let annualPlanEnd = calendar.date(byAdding: .month, value: 8, to: now) ?? now
        let denseIDs = [
            "10000000-0000-0000-0000-000000000009",
            "10000000-0000-0000-0000-000000000010",
            "10000000-0000-0000-0000-000000000011",
            "10000000-0000-0000-0000-000000000012",
            "10000000-0000-0000-0000-000000000013",
            "10000000-0000-0000-0000-000000000014",
            "10000000-0000-0000-0000-000000000015",
            "10000000-0000-0000-0000-000000000016",
        ]
        let definitions: [(name: String, remaining: Int, plan: String)] = [
            ("Volcengine dense workspace 01 · Global research account with long localized label", 930, "高效版-包月 · 企业协作长名称套餐"),
            ("Volcengine dense workspace 02 · Backup automation account", 880, "Lite 权益"),
            ("Volcengine dense workspace 03 · Product experiments and batch tasks", 760, "Pro 权益包月"),
            ("Volcengine dense workspace 04 · Design QA and prompt regression checks", 690, "高效版-包月"),
            ("Volcengine dense workspace 05 · Nightly quota audit credential", 540, "Lite 权益"),
            ("Volcengine dense workspace 06 · Customer support sandbox", 420, "Pro 权益包月"),
            ("Volcengine dense workspace 07 · Long-running evaluation lane", 260, "高效版-包月 · 跨团队共享额度包"),
            ("Volcengine dense workspace 08 · Near-limit fallback account", 140, "Lite 权益"),
        ]

        return definitions.enumerated().map { index, definition in
            let remainingText = "\(definition.remaining * 1000) / 1000000"
            return visualQAFixtureKey(
                id: UUID(uuidString: denseIDs[index])!,
                name: definition.name,
                key: "volcengine-visual-qa-dense-\(index + 1)",
                provider: .volcengineCodingPlan,
                remaining: definition.remaining,
                limit: 1000,
                planEndsAt: annualPlanEnd,
                planDisplayName: definition.plan,
                lastUpdated: now,
                quotaText: .quotaWindows([
                    QuotaWindowText(name: "5h", percentText: "\(max(8, definition.remaining / 12))%", resetAt: hourReset, remainingText: "\(definition.remaining * 6) / 6000"),
                    QuotaWindowText(name: "week", percentText: "\(max(12, definition.remaining / 10))%", resetAt: weekReset, remainingText: "\(definition.remaining * 100) / 100000"),
                    QuotaWindowText(name: "month", percentText: "\(definition.remaining / 10)%", resetAt: monthReset, remainingText: remainingText),
                ])
            )
        }
    }

    private static func visualQAFixtureSnapshot(
        keyID: UUID,
        provider: Provider,
        credentialName: String,
        recordedAt: Date,
        remaining: Int?,
        limit: Int?,
        planEndsAt: Date? = nil,
        planDisplayName: String? = nil,
        quotaLabel: String? = nil,
        quotaWindows: [QuotaWindowSnapshot] = []
    ) -> QuotaSnapshot {
        QuotaSnapshot(
            keyID: keyID,
            provider: provider,
            credentialName: credentialName,
            recordedAt: recordedAt,
            outcome: .success,
            remaining: remaining,
            limit: limit,
            resetAt: nil,
            planEndsAt: planEndsAt,
            planDisplayName: planDisplayName,
            quotaLabel: quotaLabel,
            httpStatus: 200,
            quotaWindows: quotaWindows
        )
    }
}

// 示例数据（用于预览）
struct SampleData {
    static let keys: [APIKey] = [
        APIKey(name: "TAVILY_API_KEY", key: "demo", provider: .tavily, remaining: 850, limit: 1000, lastUpdated: Date()),
        APIKey(name: "BRAVE_API_KEY", key: "demo", provider: .brave, remaining: 1800, limit: 2000, lastUpdated: Date()),
    ]
}
