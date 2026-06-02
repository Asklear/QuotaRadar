import Foundation
import Combine

enum RefreshMode {
    case manual
    case automatic
}

@MainActor
class QuotaMonitor: ObservableObject {
    static let shared = QuotaMonitor()

    @Published var apiKeys: [APIKey] = []
    @Published var isRefreshing = false
    @Published var refreshingProviders: Set<Provider> = []
    @Published var lastError: String?
    @Published var refreshMessage: String?

    private let service = QuotaService()
    private let store: APIKeyStore
    private var cancellables = Set<AnyCancellable>()

    init(store: APIKeyStore = APIKeyStore()) {
        self.store = store
        loadKeys()
    }

    var providerStats: [ProviderStats] {
        let grouped = Dictionary(grouping: apiKeys) { $0.provider }
        let stats: [ProviderStats] = Provider.allCases.compactMap { provider in
            guard let keys = grouped[provider], !keys.isEmpty else { return nil }
            return ProviderStats(provider: provider, keys: keys)
        }
        return stats
    }

    var homeProviderStats: [ProviderStats] {
        let grouped = Dictionary(grouping: apiKeys) { $0.provider }
        let stats: [ProviderStats] = Provider.allCases.compactMap { provider in
            let keys = grouped[provider] ?? []
            guard !keys.isEmpty || provider.homeVisibleWithoutKeys else { return nil }
            return ProviderStats(provider: provider, keys: keys)
        }
        return stats
    }

    var homeCategoryStats: [ProviderCategoryStats] {
        let stats = homeProviderStats
        let grouped = Dictionary(grouping: stats) { $0.provider.statusBarCategoryTitle }
        let orderedTitles = ["AI Search", "LLM"]
        return orderedTitles.compactMap { title in
            guard let providerStats = grouped[title], !providerStats.isEmpty else { return nil }
            return ProviderCategoryStats(title: title, stats: providerStats)
        }
    }

    func refreshAll(mode: RefreshMode = .manual) {
        refresh(targetProviders: nil, mode: mode)
    }

    func refreshProvider(_ provider: Provider, mode: RefreshMode = .manual) {
        refresh(targetProviders: [provider], mode: mode)
    }

    private func refresh(targetProviders: Set<Provider>?, mode: RefreshMode) {
        guard !isRefreshing else {
            if mode == .manual {
                refreshMessage = L10n.t(.refreshAlreadyRunning)
            }
            return
        }
        isRefreshing = true
        refreshingProviders = targetProviders ?? Set(Provider.allCases)
        lastError = nil
        if mode == .manual {
            if let provider = targetProviders?.first, targetProviders?.count == 1 {
                refreshMessage = L10n.format(.refreshingProvider, provider.rawValue)
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
                if let targetProviders, !targetProviders.contains(key.provider) {
                    updatedKeys.append(key)
                    continue
                }

                foundTargetKey = true

                guard key.isActive, !key.key.isEmpty else {
                    updatedKeys.append(key)
                    continue
                }

                if mode == .automatic && key.provider.quotaCheckConsumesSearchQuota {
                    if key.lastUpdated == nil, key.quotaLabel == nil {
                        key.quotaLabel = "Manual refresh only"
                    }
                    key.lastDiagnosticMessage = L10n.t(.quotaConsumingRefreshWarning)
                    updatedKeys.append(key)
                    continue
                }

                do {
                    let result = try await service.checkQuota(for: key, bypassCooldown: mode == .manual)
                    key.remaining = result.remaining
                    key.limit = result.limit
                    key.resetAt = result.resetAt
                    key.quotaLabel = result.quotaLabel
                    key.lastHTTPStatus = result.httpStatus
                    key.lastDiagnosticMessage = result.diagnosticMessage
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
                        key.quotaLabel = key.provider.unsupportedQuotaLabel
                        key.lastHTTPStatus = nil
                        key.lastDiagnosticMessage = error.localizedDescription
                        key.lastUpdated = Date()
                    } else if case QuotaError.unauthorized = error {
                        key.remaining = nil
                        key.limit = nil
                        key.resetAt = nil
                        key.lastHTTPStatus = 401
                        if key.provider.supportsDashboardReauthentication {
                            key.quotaLabel = L10n.t(.credentialExpired)
                        } else {
                            key.quotaLabel = error.localizedDescription
                        }
                        key.lastDiagnosticMessage = error.localizedDescription
                        key.lastUpdated = Date()
                        failedKeys.append(key.name)
                    } else {
                        key.lastHTTPStatus = (error as? QuotaError)?.httpStatus
                        key.lastDiagnosticMessage = error.localizedDescription
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

    private func loadKeys() {
        let loadedKeys = store.load()
        var hydratedKeys = store.loadSecrets(for: loadedKeys)

        if !store.didAttemptClaudeSettingsImport {
            store.markClaudeSettingsImportAttempted()
        }

        let importedKeys = ClaudeSettingsImporter.parseDefaultSettings()
        if !importedKeys.isEmpty {
            let summary = mergeImportedKeys(importedKeys, into: &hydratedKeys)
            if summary.added > 0 || summary.updated > 0 {
                apiKeys = hydratedKeys
                saveKeys()
                return
            }
        }

        apiKeys = hydratedKeys
    }

    private func ensureSecretsLoaded() {
        var hydratedKeys = store.loadSecrets(for: apiKeys)
        let importedKeys = ClaudeSettingsImporter.parseDefaultSettings()
        if !importedKeys.isEmpty {
            let summary = mergeImportedKeys(importedKeys, into: &hydratedKeys)
            apiKeys = hydratedKeys
            if summary.added > 0 || summary.updated > 0 {
                saveKeys()
            }
            return
        }

        apiKeys = hydratedKeys
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
                replacement.lastUpdated = existingKey.lastUpdated
                replacement.lastHTTPStatus = existingKey.lastHTTPStatus
                replacement.lastDiagnosticMessage = existingKey.lastDiagnosticMessage
                replacement.quotaLabel = existingKey.quotaLabel
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
