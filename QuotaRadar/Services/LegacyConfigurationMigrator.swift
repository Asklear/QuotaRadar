import Foundation

enum LegacyConfigurationMigrator {
    static let legacyDefaultsSuiteName = "com.gaorongvc.quotabar"
    static let migrationMarkerKey = "didMigrateQuotaBarDefaultsToQuotaRadar"
    static let apiKeyMetadataClearedByUserKey = "apiKeyMetadataClearedByUser"

    private static let migratedKeys = [
        "apiKeyMetadata",
        "apiKeys",
        "didAttemptClaudeSettingsImport",
        "appLanguage",
        "statusBarTransparency",
        "autoRefreshInterval",
        "quotaConsumingAutoRefreshInterval",
        "aiQuoteIndex",
    ]

    static func migrateUserDefaultsIfNeeded(
        defaults: UserDefaults = .standard,
        legacyDefaults: UserDefaults? = UserDefaults(suiteName: legacyDefaultsSuiteName)
    ) {
        guard let legacyDefaults else {
            return
        }

        if !defaults.bool(forKey: migrationMarkerKey) {
            for key in migratedKeys where defaults.object(forKey: key) == nil {
                if let value = legacyDefaults.object(forKey: key) {
                    defaults.set(value, forKey: key)
                }
            }

            defaults.set(true, forKey: migrationMarkerKey)
        }

        recoverLegacyAPIKeyMetadataIfNeeded(defaults: defaults, legacyDefaults: legacyDefaults)
    }

    private static func recoverLegacyAPIKeyMetadataIfNeeded(
        defaults: UserDefaults,
        legacyDefaults: UserDefaults
    ) {
        guard !defaults.bool(forKey: apiKeyMetadataClearedByUserKey),
              let currentMetadata = defaults.data(forKey: "apiKeyMetadata"),
              currentMetadata.trimmingASCIIWhitespace() == Data("[]".utf8),
              let legacyMetadata = legacyDefaults.data(forKey: "apiKeyMetadata"),
              legacyMetadata.trimmingASCIIWhitespace() != Data("[]".utf8) else {
            return
        }

        defaults.set(legacyMetadata, forKey: "apiKeyMetadata")
    }
}

private extension Data {
    func trimmingASCIIWhitespace() -> Data {
        let whitespace = Set(" \n\r\t".utf8)
        var start = startIndex
        var end = endIndex

        while start < end, whitespace.contains(self[start]) {
            start = index(after: start)
        }

        while end > start {
            let previous = index(before: end)
            guard whitespace.contains(self[previous]) else {
                break
            }
            end = previous
        }

        return self[start..<end]
    }
}
