import Foundation

struct ImportSummary: Equatable {
    let added: Int
    let updated: Int
    let skipped: Int

    var isEmpty: Bool {
        added == 0 && updated == 0 && skipped == 0
    }
}

struct APIKeyStore {
    private struct StoredAPIKey: Codable {
        var id: UUID
        var name: String
        var provider: Provider
        var isActive: Bool
        var note: String?
        var remaining: Int?
        var limit: Int?
        var resetAt: Date?
        var lastUpdated: Date?
        var lastHTTPStatus: Int?
        var lastDiagnosticMessage: String?
        var quotaLabel: String?
        var usageCount: Int
        var lastUsed: Date?

        init(_ key: APIKey) {
            id = key.id
            name = key.name
            provider = key.provider
            isActive = key.isActive
            note = key.note
            remaining = key.remaining
            limit = key.limit
            resetAt = key.resetAt
            lastUpdated = key.lastUpdated
            lastHTTPStatus = key.lastHTTPStatus
            lastDiagnosticMessage = key.lastDiagnosticMessage
            quotaLabel = key.quotaLabel
            usageCount = key.usageCount
            lastUsed = key.lastUsed
        }

        func hydrate(with secret: String) -> APIKey {
            let normalizedQuotaLabel: String?
            if provider == .brave,
               remaining == 0,
               limit == 0,
               quotaLabel == "No monthly quota remaining" || quotaLabel == "No monthly quota configured" {
                normalizedQuotaLabel = "Search OK · monthly quota not exposed"
            } else {
                normalizedQuotaLabel = quotaLabel
            }

            let normalizedRemaining: Int?
            let normalizedLimit: Int?
            if provider == .brave,
               remaining == 0,
               limit == 0,
               normalizedQuotaLabel == "Search OK · monthly quota not exposed" {
                normalizedRemaining = Int.max
                normalizedLimit = Int.max
            } else {
                normalizedRemaining = remaining
                normalizedLimit = limit
            }

            return APIKey(
                id: id,
                name: name,
                key: secret,
                provider: provider,
                isActive: isActive,
                note: note,
                remaining: normalizedRemaining,
                limit: normalizedLimit,
                resetAt: resetAt,
                lastUpdated: lastUpdated,
                lastHTTPStatus: lastHTTPStatus,
                lastDiagnosticMessage: lastDiagnosticMessage,
                quotaLabel: normalizedQuotaLabel,
                usageCount: usageCount,
                lastUsed: lastUsed
            )
        }
    }

    private let defaults: UserDefaults
    private let secretStore: FileSecretStore
    private let metadataKey = "apiKeyMetadata"
    private let legacyKey = "apiKeys"
    private let claudeSettingsImportAttemptedKey = "didAttemptClaudeSettingsImport"

    init(defaults: UserDefaults = .standard, secretStore: FileSecretStore = FileSecretStore()) {
        self.defaults = defaults
        self.secretStore = secretStore
    }

    func load() -> [APIKey] {
        if let data = defaults.data(forKey: metadataKey),
           let metadata = try? JSONDecoder().decode([StoredAPIKey].self, from: data) {
            let migrated = removeStaleQueritAPIKeyRecords(from: metadata)
            if migrated.count != metadata.count {
                save(migrated.map { $0.hydrate(with: "") })
            }
            return migrated.map { item in item.hydrate(with: "") }
        }

        if let legacyData = defaults.data(forKey: legacyKey),
           let legacyKeys = try? JSONDecoder().decode([APIKey].self, from: legacyData) {
            save(legacyKeys)
            defaults.removeObject(forKey: legacyKey)
            return legacyKeys
        }

        return []
    }

    func loadSecrets(for keys: [APIKey]) -> [APIKey] {
        keys.map { key in
            var hydratedKey = key
            if let secret = try? secretStore.read(account: key.id.uuidString) {
                hydratedKey.key = secret
            }
            return hydratedKey
        }
    }

    var didAttemptClaudeSettingsImport: Bool {
        defaults.bool(forKey: claudeSettingsImportAttemptedKey)
    }

    func markClaudeSettingsImportAttempted() {
        defaults.set(true, forKey: claudeSettingsImportAttemptedKey)
    }

    func save(_ keys: [APIKey]) {
        for key in keys where !key.key.isEmpty {
            try? secretStore.save(key.key, account: key.id.uuidString)
        }

        let metadata = keys.map(StoredAPIKey.init)
        if let data = try? JSONEncoder().encode(metadata) {
            defaults.set(data, forKey: metadataKey)
        }
        defaults.removeObject(forKey: legacyKey)
    }

    func delete(id: UUID) {
        secretStore.delete(account: id.uuidString)
    }

    private func removeStaleQueritAPIKeyRecords(from metadata: [StoredAPIKey]) -> [StoredAPIKey] {
        metadata.filter { item in
            let uppercasedName = item.name.uppercased()
            let isStaleQueritAPIKey = item.provider == .querit
                && uppercasedName.contains("API_KEY")
                && !uppercasedName.contains("COOKIE")
                && !uppercasedName.contains("SESSION")
            if isStaleQueritAPIKey {
                secretStore.delete(account: item.id.uuidString)
            }
            return !isStaleQueritAPIKey
        }
    }
}
