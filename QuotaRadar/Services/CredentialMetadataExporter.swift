import Foundation

struct CredentialMetadataExporter {
    struct Document: Codable {
        let app: String
        let schemaVersion: Int
        let generatedAt: Date
        let credentials: [CredentialRecord]
    }

    struct CredentialRecord: Codable {
        let id: UUID
        let name: String
        let provider: String
        let providerDisplayName: String
        let category: String
        let active: Bool
        let linkedMonitorID: UUID?
        let remaining: Int?
        let limit: Int?
        let resetAt: Date?
        let planEndsAt: Date?
        let planDisplayName: String?
        let codexResetCreditsRemaining: Int?
        let codexResetCreditsEarliestExpiresAt: Date?
        let lastUpdated: Date?
        let lastHTTPStatus: Int?
        let consecutiveFailureCount: Int
        let quotaDisplayText: String
        let quotaStatus: String
    }

    static func export(_ credentials: [APIKey], generatedAt: Date = Date()) throws -> Data {
        let document = Document(
            app: "Quota Radar",
            schemaVersion: 1,
            generatedAt: generatedAt,
            credentials: credentials.map(CredentialRecord.init)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(document)
    }
}

private extension CredentialMetadataExporter.CredentialRecord {
    init(_ credential: APIKey) {
        id = credential.id
        name = credential.name
        provider = credential.provider.rawValue
        providerDisplayName = credential.provider.displayName()
        category = credential.provider.statusBarCategoryTitle
        active = credential.isActive
        linkedMonitorID = credential.linkedAuthorizationID
        remaining = credential.remaining
        limit = credential.limit
        resetAt = credential.resetAt
        planEndsAt = credential.planEndsAt
        planDisplayName = credential.planDisplayName
        codexResetCreditsRemaining = credential.codexResetCreditsRemaining
        codexResetCreditsEarliestExpiresAt = credential.codexResetCreditsEarliestExpiresAt
        lastUpdated = credential.lastUpdated
        lastHTTPStatus = credential.lastHTTPStatus
        consecutiveFailureCount = credential.consecutiveFailureCount
        quotaDisplayText = credential.quotaDisplayText
        quotaStatus = credential.healthDisplayText
    }
}
