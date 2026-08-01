import Foundation

struct LiveAcceptanceRow: Encodable {
    let provider: String
    let account: String
    let status: String
    let httpStatus: Int?
    let plan: String?
    let remaining: Int?
    let limit: Int?
    let availability: String?
    let resetAt: String?
    let planEndsAt: String?
    let checkedAt: String?
    let hasQuota: Bool
    let hasReset: Bool
    let hasPlanEnd: Bool
    let quotaWindowCount: Int
    let codexResetCredits: Int?
    let diagnostic: String?
    let calibrationStatus: String
    let lastVerifiedAt: String?
    let calibrationEvidence: String
    let fallbackBehavior: String
}

@main
struct QuotaRadarLiveAcceptance {
    static func main() async {
        do {
            let options = try LiveAcceptanceOptions.parse(CommandLine.arguments.dropFirst())
            let rows = try await LiveAcceptanceRunner(options: options).run()
            if options.outputJSON {
                try printJSON(rows)
            } else {
                printTable(rows, live: options.live)
            }
            if options.live,
               rows.contains(where: { $0.status == "failed" })
                || (options.hasProviderFilters && rows.contains(where: { $0.status == "missing" })) {
                Foundation.exit(1)
            }
        } catch {
            FileHandle.standardError.write(Data("Live acceptance failed: \(error.localizedDescription)\n".utf8))
            Foundation.exit(2)
        }
    }

    private static func printJSON(_ rows: [LiveAcceptanceRow]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(rows)
        guard let text = String(data: data, encoding: .utf8) else { return }
        print(text)
    }

    private static func printTable(_ rows: [LiveAcceptanceRow], live: Bool) {
        print(live ? "Quota Radar live acceptance matrix" : "Quota Radar live acceptance matrix (dry run)")
        print("No credential values, raw responses, or credential labels are printed.")
        print("provider | account | status | http | plan | remaining | limit | availability | reset at | plan ends at | checked at | quota | reset | plan end | windows | reset credits | diagnostic | calibration | verified | evidence | fallback")
        print("--- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---")

        for row in rows {
            var values: [String] = [row.provider, row.account, row.status]
            values.append(row.httpStatus.map(String.init) ?? "-")
            values.append(row.plan ?? "-")
            values.append(row.remaining.map(String.init) ?? "-")
            values.append(row.limit.map(String.init) ?? "-")
            values.append(row.availability ?? "-")
            values.append(row.resetAt ?? "-")
            values.append(row.planEndsAt ?? "-")
            values.append(row.checkedAt ?? "-")
            values.append(row.hasQuota ? "yes" : "no")
            values.append(row.hasReset ? "yes" : "no")
            values.append(row.hasPlanEnd ? "yes" : "no")
            values.append(String(row.quotaWindowCount))
            values.append(row.codexResetCredits.map(String.init) ?? "-")
            values.append(row.diagnostic ?? "-")
            values.append(row.calibrationStatus)
            values.append(row.lastVerifiedAt ?? "-")
            values.append(row.calibrationEvidence)
            values.append(row.fallbackBehavior)
            print(values.map(sanitizeCell).joined(separator: " | "))
        }
    }

    private static func sanitizeCell(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "|", with: "/")
    }
}

struct LiveAcceptanceOptions {
    var live = false
    var outputJSON = false
    var providerFilters: Set<String> = []

    var hasProviderFilters: Bool {
        !providerFilters.isEmpty
    }

    static func parse(_ arguments: ArraySlice<String>) throws -> LiveAcceptanceOptions {
        var options = LiveAcceptanceOptions()
        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--live":
                options.live = true
            case "--json":
                options.outputJSON = true
            case "--provider":
                guard let value = iterator.next(), !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw LiveAcceptanceError.missingProviderFilter
                }
                options.providerFilters.insert(Self.normalizedProviderFilter(value))
            default:
                throw LiveAcceptanceError.unknownArgument(argument)
            }
        }
        return options
    }

    func includes(_ provider: Provider) -> Bool {
        guard !providerFilters.isEmpty else { return true }
        return providerFilters.contains(Self.normalizedProviderFilter(provider.rawValue))
            || providerFilters.contains(Self.normalizedProviderFilter(provider.displayName(language: .english)))
    }

    private static func normalizedProviderFilter(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

enum LiveAcceptanceError: LocalizedError {
    case missingProviderFilter
    case unknownArgument(String)

    var errorDescription: String? {
        switch self {
        case .missingProviderFilter:
            return "--provider requires a provider name"
        case .unknownArgument(let argument):
            return "unknown argument \(argument)"
        }
    }
}

struct LiveAcceptanceRunner {
    let options: LiveAcceptanceOptions
    private let store: APIKeyStore
    private let service = QuotaService()

    init(options: LiveAcceptanceOptions) {
        self.options = options
        let appDefaults = UserDefaults(suiteName: "com.gaorongvc.quotaradar") ?? .standard
        self.store = APIKeyStore(defaults: appDefaults)
    }

    func run() async throws -> [LiveAcceptanceRow] {
        let metadata = store.load()
        let hydratedCredentials = store.loadSecrets(for: metadata)
        let candidates = options.hasProviderFilters ? Provider.visibleCases : Provider.visibleCases.filter { $0.supportsDashboardReauthentication }
        let providers = candidates
            .filter(options.includes)

        var rows: [LiveAcceptanceRow] = []
        for provider in providers {
            let credentials = monitoredCredentials(for: provider, in: hydratedCredentials)
            if credentials.isEmpty {
                rows.append(missingRow(for: provider))
                continue
            }

            for (index, credential) in credentials.enumerated() {
                if options.live {
                    rows.append(await liveRow(for: credential, ordinal: index + 1))
                } else {
                    rows.append(dryRunRow(for: credential, ordinal: index + 1))
                }
            }
        }
        return rows
    }

    private func monitoredCredentials(for provider: Provider, in credentials: [APIKey]) -> [APIKey] {
        let candidates = QuotaMonitor.refreshCandidateKeys(
            from: credentials,
            targetProviders: Set([provider])
        )
        return candidates.filter { credential in
            credential.provider == provider
                && credential.isActive
                && !credential.isStoredAPIKeyOnlyCredential
                && !credential.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func missingRow(for provider: Provider) -> LiveAcceptanceRow {
        let calibration = provider.trustCalibration
        return LiveAcceptanceRow(
            provider: provider.displayName(language: .english),
            account: "-",
            status: "missing",
            httpStatus: nil,
            plan: nil,
            remaining: nil,
            limit: nil,
            availability: nil,
            resetAt: nil,
            planEndsAt: nil,
            checkedAt: nil,
            hasQuota: false,
            hasReset: false,
            hasPlanEnd: false,
            quotaWindowCount: 0,
            codexResetCredits: nil,
            diagnostic: calibration.status.rawValue,
            calibrationStatus: calibration.status.rawValue,
            lastVerifiedAt: calibration.lastVerifiedAt,
            calibrationEvidence: calibration.evidence,
            fallbackBehavior: calibration.fallbackBehavior
        )
    }

    private func dryRunRow(for credential: APIKey, ordinal: Int) -> LiveAcceptanceRow {
        let calibration = credential.provider.trustCalibration
        return LiveAcceptanceRow(
            provider: credential.provider.displayName(language: .english),
            account: "account \(ordinal)",
            status: "ready",
            httpStatus: credential.lastHTTPStatus,
            plan: credential.realPlanDisplayName,
            remaining: credential.remaining,
            limit: credential.limit,
            availability: credential.quotaAvailability?.rawValue,
            resetAt: Self.iso8601(credential.resetAt),
            planEndsAt: Self.iso8601(credential.planEndsAt),
            checkedAt: Self.iso8601(credential.lastUpdated),
            hasQuota: credential.remaining != nil || credential.quotaText != nil || credential.quotaLabel != nil,
            hasReset: credential.resetAt != nil || credential.quotaWindowDetails.contains { $0.resetAt != nil },
            hasPlanEnd: credential.planEndsAt != nil,
            quotaWindowCount: credential.quotaWindowDetails.count,
            codexResetCredits: credential.codexResetCreditCount,
            diagnostic: credential.lastDiagnosticText?.key?.rawValue,
            calibrationStatus: calibration.status.rawValue,
            lastVerifiedAt: calibration.lastVerifiedAt,
            calibrationEvidence: calibration.evidence,
            fallbackBehavior: calibration.fallbackBehavior
        )
    }

    private func liveRow(for credential: APIKey, ordinal: Int) async -> LiveAcceptanceRow {
        let calibration = credential.provider.trustCalibration
        do {
            let result = try await service.checkQuota(for: credential, bypassCooldown: true)
            return LiveAcceptanceRow(
                provider: credential.provider.displayName(language: .english),
                account: "account \(ordinal)",
                status: "passed",
                httpStatus: result.httpStatus,
                plan: APIKey.normalizedPlanDisplayName(result.planDisplayName) ?? credential.realPlanDisplayName,
                remaining: result.remaining,
                limit: result.limit,
                availability: result.quotaAvailability.rawValue,
                resetAt: Self.iso8601(result.resetAt),
                planEndsAt: Self.iso8601(result.planEndsAt),
                checkedAt: Self.iso8601(Date()),
                hasQuota: result.limit > 0 && result.remaining >= 0 && result.remaining <= result.limit || result.quotaText != nil,
                hasReset: result.resetAt != nil || result.quotaWindows.contains { $0.resetAt != nil },
                hasPlanEnd: result.planEndsAt != nil,
                quotaWindowCount: result.quotaWindows.count,
                codexResetCredits: result.codexResetCreditsRemaining,
                diagnostic: result.diagnosticText?.key?.rawValue,
                calibrationStatus: calibration.status.rawValue,
                lastVerifiedAt: calibration.lastVerifiedAt,
                calibrationEvidence: calibration.evidence,
                fallbackBehavior: calibration.fallbackBehavior
            )
        } catch {
            let quotaError = error as? QuotaError
            return LiveAcceptanceRow(
                provider: credential.provider.displayName(language: .english),
                account: "account \(ordinal)",
                status: "failed",
                httpStatus: quotaError?.httpStatus,
                plan: credential.realPlanDisplayName,
                remaining: credential.remaining,
                limit: credential.limit,
                availability: credential.quotaAvailability?.rawValue,
                resetAt: Self.iso8601(credential.resetAt),
                planEndsAt: Self.iso8601(credential.planEndsAt),
                checkedAt: Self.failureEvidenceUpdatedAt(for: credential),
                hasQuota: false,
                hasReset: false,
                hasPlanEnd: false,
                quotaWindowCount: 0,
                codexResetCredits: nil,
                diagnostic: quotaError?.localizedTextDescriptor.key?.rawValue ?? "request_failed",
                calibrationStatus: calibration.status.rawValue,
                lastVerifiedAt: calibration.lastVerifiedAt,
                calibrationEvidence: calibration.evidence,
                fallbackBehavior: calibration.fallbackBehavior
            )
        }
    }

    private static func iso8601(_ date: Date?) -> String? {
        guard let date else { return nil }
        return ISO8601DateFormatter().string(from: date)
    }

    private static func failureEvidenceUpdatedAt(for credential: APIKey) -> String? {
        iso8601(credential.lastUpdated)
    }
}
