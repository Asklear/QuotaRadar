import Foundation

struct DashboardReauthConfig {
    let provider: Provider
    let loginURL: URL
    let cookieDomains: [String]
    let requiredCookieNames: [String]
    let defaultKeyName: String

    init?(provider: Provider) {
        guard provider.supportsDashboardReauthentication,
              let dashboardURL = provider.dashboardURL,
              let url = URL(string: dashboardURL) else {
            return nil
        }

        self.provider = provider
        self.loginURL = url
        self.cookieDomains = provider.cookieDomains
        self.requiredCookieNames = provider.dashboardAuthenticationCookieNames
        self.defaultKeyName = provider.defaultCredentialName
    }
}

struct DashboardCapturedCredential {
    let provider: Provider
    let cookieHeader: String
    let fields: [String: String]

    init(provider: Provider, cookieHeader: String, webStorageFields: [String: String] = [:]) {
        self.provider = provider
        self.cookieHeader = cookieHeader
        self.fields = Self.normalizedFields(
            provider: provider,
            cookieHeader: cookieHeader,
            webStorageFields: webStorageFields
        )
    }

    var hasCredentialMaterial: Bool {
        !cookieHeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !fields.isEmpty
    }

    var captureIdentity: Int {
        var hasher = Hasher()
        hasher.combine(provider)
        if provider == .tencentCloudCodingPlan {
            for name in ["uin", "skey", "p_skey", "ownerUin"] {
                hasher.combine(name)
                hasher.combine(DashboardCookieBuilder.cookieValue(named: name, in: cookieHeader))
            }
            return hasher.finalize()
        }
        hasher.combine(cookieHeader)
        for (name, value) in fields.sorted(by: { $0.key < $1.key }) {
            hasher.combine(name)
            hasher.combine(value)
        }
        return hasher.finalize()
    }

    func reauthenticatedSecret(existingSecret: String?) -> String {
        DashboardCookieBuilder.reauthenticatedSecret(
            cookieHeader: cookieHeader,
            fields: fields,
            existingSecret: existingSecret
        )
    }

    private static func normalizedFields(
        provider: Provider,
        cookieHeader: String,
        webStorageFields: [String: String]
    ) -> [String: String] {
        let storage = Dictionary(
            uniqueKeysWithValues: webStorageFields.map { key, value in
                (key.trimmingCharacters(in: .whitespacesAndNewlines), value.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        )

        switch provider {
        case .kimiSubscription:
            return normalizedKimiFields(cookieHeader: cookieHeader, storage: storage)
        case .longcat:
            return normalizedLongCatFields(cookieHeader: cookieHeader, storage: storage)
        case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .querit, .anthropic, .anthropicCredits, .claudeAPIUsage, .claudeSubscription, .codexAPIUsage, .codexSubscription, .deepseek, .xfyunCodingPlan, .xfyunTokenPlan, .volcengineCodingPlan, .volcengineTokenPlan, .opencodeGo, .aliyunCodingPlan, .aliyunTokenPlan, .tencentCloudCodingPlan, .tencentCloudTokenPlan:
            return [:]
        }
    }

    private static func normalizedKimiFields(cookieHeader: String, storage: [String: String]) -> [String: String] {
        var fields: [String: String] = [:]

        if let token = firstNonEmptyValue(
            in: storage,
            keys: ["accessToken", "access_token", "authorization", "bearerToken", "bearer_token", "token", "kimi-auth"]
        ) ?? DashboardCookieBuilder.cookieValue(named: "kimi-auth", in: cookieHeader) {
            fields["accessToken"] = stripBearerPrefix(token)
        }

        if let deviceID = firstNonEmptyValue(in: storage, keys: ["deviceID", "deviceId", "x-msh-device-id"]) {
            fields["deviceID"] = deviceID
        }
        if let sessionID = firstNonEmptyValue(in: storage, keys: ["sessionID", "sessionId", "x-msh-session-id"]) {
            fields["sessionID"] = sessionID
        }
        if let trafficID = firstNonEmptyValue(in: storage, keys: ["trafficID", "trafficId", "x-traffic-id"]) {
            fields["trafficID"] = trafficID
        }

        return fields
    }

    private static func normalizedLongCatFields(cookieHeader: String, storage: [String: String]) -> [String: String] {
        var fields: [String: String] = [:]
        let documentCookie = firstNonEmptyValue(in: storage, keys: ["documentCookie"])
        let combinedCookieHeader = [cookieHeader, documentCookie]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "; ")

        if let token = firstNonEmptyValue(
            in: storage,
            keys: ["token", "longcatUserCurrentToken", "userCurrentToken", "accessToken", "access_token", "authorization", "bearerToken", "bearer_token", "loginToken", "login_token"]
        ) ?? DashboardCookieBuilder.cookieValue(named: "token", in: combinedCookieHeader) {
            fields["token"] = stripBearerPrefix(token)
        }
        if let userTicket = firstNonEmptyValue(
            in: storage,
            keys: ["userTicket", "user_ticket", "userticket"]
        ) ?? DashboardCookieBuilder.cookieValue(named: "userTicket", in: combinedCookieHeader) {
            fields["userTicket"] = userTicket
        }
        if let uuid = firstNonEmptyValue(in: storage, keys: ["uuid"]) ?? DashboardCookieBuilder.cookieValue(named: "uuid", in: combinedCookieHeader) {
            fields["uuid"] = uuid
        }
        if let passportUUID = firstNonEmptyValue(
            in: storage,
            keys: ["passport_uuid", "passportUuid", "passportUUID", "passport-uuid", "passpoart_uuid", "passpoartUuid", "passpoartUUID", "passpoart-uuid"]
        ) ?? DashboardCookieBuilder.cookieValue(named: "passport_uuid", in: combinedCookieHeader)
            ?? DashboardCookieBuilder.cookieValue(named: "passpoart_uuid", in: combinedCookieHeader) {
            fields["passport_uuid"] = passportUUID
        }
        if let lt = firstNonEmptyValue(in: storage, keys: ["lt", "loginTicket", "login_ticket"]) ?? DashboardCookieBuilder.cookieValue(named: "lt", in: combinedCookieHeader) {
            fields["lt"] = lt
        }
        if let loginStatus = firstNonEmptyValue(in: storage, keys: ["longcatLoginStatus", "loginStatus", "login_status"]) {
            fields["longcatLoginStatus"] = loginStatus
        }
        if let userID = firstNonEmptyValue(in: storage, keys: ["longcatUserId", "userId", "user_id"]) {
            fields["longcatUserId"] = userID
        }

        return fields
    }

    private static func firstNonEmptyValue(in fields: [String: String], keys: [String]) -> String? {
        for key in keys {
            guard let value = fields[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else {
                continue
            }
            return value
        }
        return nil
    }

    private static func stripBearerPrefix(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("bearer ") {
            return String(trimmed.dropFirst("Bearer ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }
}

enum DashboardAutomaticCredentialEmissionDecision: Equatable {
    case emit
    case unchanged
    case blocked
}

struct DashboardCredentialCaptureLifecycle {
    private(set) var hasEmittedAutomaticCredential = false
    private var lastResetRequestID: Int
    private var lastEmittedCredentialIdentity: Int?

    init(initialResetRequestID: Int) {
        self.lastResetRequestID = initialResetRequestID
    }

    mutating func automaticEmissionDecision(
        credentialIdentity: Int
    ) -> DashboardAutomaticCredentialEmissionDecision {
        guard !hasEmittedAutomaticCredential else {
            return .blocked
        }
        guard credentialIdentity != lastEmittedCredentialIdentity else {
            return .unchanged
        }
        hasEmittedAutomaticCredential = true
        lastEmittedCredentialIdentity = credentialIdentity
        return .emit
    }

    mutating func consumeResetRequest(_ requestID: Int) -> Bool {
        guard requestID != lastResetRequestID else { return false }
        lastResetRequestID = requestID
        hasEmittedAutomaticCredential = false
        return true
    }
}

enum DashboardReauthValidationDisposition: Equatable {
    case persist
    case recapture
}

struct DashboardReauthValidationLifecycle {
    private(set) var isValidationInFlight = false

    mutating func beginValidation() -> Bool {
        guard !isValidationInFlight else { return false }
        isValidationInFlight = true
        return true
    }

    mutating func finishValidation(succeeded: Bool) -> DashboardReauthValidationDisposition {
        isValidationInFlight = false
        return succeeded ? .persist : .recapture
    }
}

enum DashboardCredentialCapturePolicy {
    static let manualRetryDelays: [TimeInterval] = [0.25, 0.75, 1.5]

    static func automaticRetryDelays(for provider: Provider) -> [TimeInterval] {
        switch provider {
        case .volcengineCodingPlan, .volcengineTokenPlan:
            return [0.35, 1.0, 2.0, 4.0, 7.0]
        default:
            return [0.35, 1.0, 2.0]
        }
    }

    static func nextAutomaticRetryDelay(
        for provider: Provider,
        completedRetryCount: Int
    ) -> TimeInterval? {
        let retryDelays = automaticRetryDelays(for: provider)
        if completedRetryCount < retryDelays.count {
            return retryDelays[completedRetryCount]
        }

        switch provider {
        case .kimiSubscription, .longcat, .tencentCloudCodingPlan:
            return 5.0
        default:
            return nil
        }
    }

    static func isCredentialReady(
        _ credential: DashboardCapturedCredential,
        requiredNames: [String]
    ) -> Bool {
        credential.hasCredentialMaterial
            && missingRequiredCredentialNames(credential, requiredNames: requiredNames).isEmpty
    }

    static func missingRequiredCredentialNames(
        _ credential: DashboardCapturedCredential,
        requiredNames: [String]
    ) -> [String] {
        if credential.provider == .longcat {
            return missingLongCatCredentialNames(credential)
        }

        return DashboardCookieBuilder.missingRequiredCredentialNames(
            cookieHeader: credential.cookieHeader,
            fields: credential.fields,
            requiredNames: requiredNames
        )
    }

    static func shouldRetryCapture(
        _ credential: DashboardCapturedCredential,
        requiredNames: [String],
        completedRetryCount: Int,
        retryDelays: [TimeInterval]
    ) -> Bool {
        !isCredentialReady(credential, requiredNames: requiredNames)
            && completedRetryCount < retryDelays.count
    }

    private static func missingLongCatCredentialNames(_ credential: DashboardCapturedCredential) -> [String] {
        let names = DashboardCookieBuilder.credentialNames(
            cookieHeader: credential.cookieHeader,
            fields: credential.fields
        )
        if credential.fields["longcatLoginStatus"] == "1" {
            return []
        }
        if names.contains("longcat_session") {
            return []
        }

        let hasToken = names.contains("token")
        let hasUUID = names.contains("uuid")
            || names.contains("passport_uuid")
            || names.contains("passpoart_uuid")
        if hasToken && hasUUID {
            return []
        }

        var missingNames: [String] = []
        if !hasToken {
            missingNames.append("token")
        }
        if !hasUUID {
            missingNames.append("uuid|passport_uuid")
        }
        return names.isEmpty ? ["longcat_session"] + missingNames : missingNames
    }
}

enum DashboardCredentialDisplayNames {
    static func missingRequiredNames(
        _ rawNames: [String],
        provider: Provider,
        language: AppLanguage = AppLanguageStore.shared.language
    ) -> [String] {
        localizedNames(from: rawNames, provider: provider, language: language)
    }

    static func capturedNames(
        for credential: DashboardCapturedCredential,
        language: AppLanguage = AppLanguageStore.shared.language
    ) -> [String] {
        let rawNames = DashboardCookieBuilder.credentialNames(
            cookieHeader: credential.cookieHeader,
            fields: credential.fields
        )
        return localizedNames(from: Array(rawNames), provider: credential.provider, language: language)
    }

    private static func localizedNames(
        from rawNames: [String],
        provider: Provider,
        language: AppLanguage
    ) -> [String] {
        switch provider {
        case .longcat:
            return orderedUnique(
                longCatDisplayKeys(from: rawNames).map { L10n.t($0, language: language) }
            )
        default:
            return orderedUnique(
                rawNames
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .sorted()
            )
        }
    }

    private static func longCatDisplayKeys(from rawNames: [String]) -> [L10n.Key] {
        var keys: [L10n.Key] = []
        let normalizedNames = rawNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let loweredNames = Set(normalizedNames.map { $0.lowercased() })
        if loweredNames.contains("longcatloginstatus")
            || loweredNames.contains("loginstatus")
            || loweredNames.contains("login_status") {
            keys.append(.longCatLoginState)
        }

        if normalizedNames.contains(where: isLongCatAuthorizationName) {
            keys.append(.longCatLoginAuthorization)
        }
        if normalizedNames.contains(where: isLongCatBrowserIdentityName) {
            keys.append(.longCatBrowserIdentity)
        }
        if normalizedNames.contains(where: isLongCatAccountIdentityName) {
            keys.append(.longCatAccountIdentity)
        }

        for name in normalizedNames
            where !isIgnoredLongCatName(name)
                && !isLongCatAuthorizationName(name)
                && !isLongCatBrowserIdentityName(name)
                && !isLongCatAccountIdentityName(name)
                && !isLongCatLoginStateName(name) {
            keys.append(.longCatLoginAuthorization)
        }

        return orderedUnique(keys)
    }

    private static func isLongCatLoginStateName(_ name: String) -> Bool {
        ["longcatloginstatus", "loginstatus", "login_status"].contains(name.lowercased())
    }

    private static func isLongCatAuthorizationName(_ name: String) -> Bool {
        [
            "longcat_session",
            "token",
            "longcatusercurrenttoken",
            "usercurrenttoken",
            "accesstoken",
            "access_token",
            "authorization",
            "bearertoken",
            "bearer_token",
            "logintoken",
            "login_token",
            "userticket",
            "user_ticket",
            "lt",
            "loginticket",
            "login_ticket"
        ].contains(name.lowercased())
    }

    private static func isLongCatBrowserIdentityName(_ name: String) -> Bool {
        [
            "uuid",
            "passport_uuid",
            "passportuuid",
            "passport-uuid",
            "passpoart_uuid",
            "passpoartuuid",
            "passpoart-uuid",
            "uuid|passport_uuid"
        ].contains(name.lowercased())
    }

    private static func isLongCatAccountIdentityName(_ name: String) -> Bool {
        ["longcatuserid", "userid", "user_id"].contains(name.lowercased())
    }

    private static func isIgnoredLongCatName(_ name: String) -> Bool {
        [
            "cookie",
            "cookies",
            "documentcookie",
            "locale",
            "locale_mode",
            "lang",
            "language"
        ].contains(name.lowercased())
    }

    private static func orderedUnique<T: Hashable>(_ values: [T]) -> [T] {
        var seen = Set<T>()
        var result: [T] = []
        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }
        return result
    }
}

enum DashboardCookieBuilder {
    static func cookieHeader(from cookies: [HTTPCookie], domains: [String]) -> String {
        let normalizedDomains = domains.map(normalizeDomain)
        let pairs = cookies
            .filter { cookie in
                let cookieDomain = normalizeDomain(cookie.domain)
                return normalizedDomains.contains { allowedDomain in
                    cookieDomain == allowedDomain || cookieDomain.hasSuffix(".\(allowedDomain)")
                }
            }
            .sorted { lhs, rhs in
                if lhs.name == rhs.name {
                    return lhs.domain < rhs.domain
                }
                return lhs.name < rhs.name
            }
            .map { "\($0.name)=\($0.value)" }

        return pairs.joined(separator: "; ")
    }

    static func containsRequiredCookie(from cookies: [HTTPCookie], domains: [String], requiredNames: [String]) -> Bool {
        missingRequiredCookieNames(from: cookies, domains: domains, requiredNames: requiredNames).isEmpty
    }

    static func missingRequiredCookieNames(from cookies: [HTTPCookie], domains: [String], requiredNames: [String]) -> [String] {
        let normalizedDomains = domains.map(normalizeDomain)
        guard !requiredNames.isEmpty else { return [] }

        let matchingCookieNames = Set(cookies.compactMap { cookie -> String? in
            let cookieDomain = normalizeDomain(cookie.domain)
            let matchesDomain = normalizedDomains.contains { allowedDomain in
                cookieDomain == allowedDomain || cookieDomain.hasSuffix(".\(allowedDomain)")
            }
            return matchesDomain ? cookie.name : nil
        })

        return requiredNames
            .filter { !matchesRequirement($0, cookieNames: matchingCookieNames) }
            .map(displayNameForRequirement)
    }

    static func missingRequiredCookieNames(inCookieHeader cookieHeader: String, requiredNames: [String]) -> [String] {
        missingRequiredCredentialNames(cookieHeader: cookieHeader, fields: [:], requiredNames: requiredNames)
    }

    static func missingRequiredCredentialNames(
        cookieHeader: String,
        fields: [String: String],
        requiredNames: [String]
    ) -> [String] {
        guard !requiredNames.isEmpty else { return [] }

        return requiredNames
            .filter { !matchesRequirement($0, cookieNames: credentialNames(cookieHeader: cookieHeader, fields: fields)) }
            .map(displayNameForRequirement)
    }

    static func containsRequiredCookie(inCookieHeader cookieHeader: String, requiredNames: [String]) -> Bool {
        missingRequiredCookieNames(inCookieHeader: cookieHeader, requiredNames: requiredNames).isEmpty
    }

    static func reauthenticatedSecret(cookieHeader: String, existingSecret: String?) -> String {
        reauthenticatedSecret(cookieHeader: cookieHeader, fields: [:], existingSecret: existingSecret)
    }

    static func reauthenticatedSecret(
        cookieHeader: String,
        fields: [String: String],
        existingSecret: String?
    ) -> String {
        guard let existingSecret = existingSecret?.trimmingCharacters(in: .whitespacesAndNewlines),
              !existingSecret.isEmpty,
              let data = existingSecret.data(using: .utf8),
              var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            guard !fields.isEmpty else { return cookieHeader }
            var object: [String: Any] = fields
            if !cookieHeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                object["cookie"] = cookieHeader
            }
            return serializedCredentialObject(object) ?? cookieHeader
        }

        for (key, value) in fields {
            object[key] = value
        }

        let trimmedCookieHeader = cookieHeader.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCookieHeader.isEmpty, fields.isEmpty {
            return existingSecret
        }

        if !trimmedCookieHeader.isEmpty {
            object["cookie"] = cookieHeader
            if object.keys.contains("cookies") {
                object["cookies"] = cookieHeader
            }
        }

        if let csrfToken = cookieValue(named: "csrfToken", in: cookieHeader) {
            for key in object.keys where ["csrftoken", "csrf", "xcsrftoken"].contains(key.lowercased()) {
                object[key] = csrfToken
            }
        }

        let hasCredentialMetadata = object.keys.contains { key in
            let normalizedKey = key.lowercased()
            return normalizedKey != "cookie" && normalizedKey != "cookies"
        }
        guard hasCredentialMetadata else {
            return cookieHeader
        }

        return serializedCredentialObject(object) ?? cookieHeader
    }

    static func cookieValue(named name: String, in cookieHeader: String) -> String? {
        for part in cookieHeader.split(separator: ";") {
            let pieces = part.split(separator: "=", maxSplits: 1).map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard pieces.count == 2 else { continue }
            if pieces[0] == name {
                return pieces[1]
            }
        }
        return nil
    }

    static func credentialNames(cookieHeader: String, fields: [String: String]) -> Set<String> {
        var names = Set(cookieHeader
            .split(separator: ";")
            .compactMap { part -> String? in
                let pieces = part.split(separator: "=", maxSplits: 1).map {
                    String($0).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                guard pieces.count == 2, !pieces[0].isEmpty else {
                    return nil
                }
                return pieces[0]
            })

        for key in fields.keys {
            names.insert(key)
        }
        for cookieField in ["cookie", "cookies"] {
            guard let fieldCookieHeader = fields[cookieField] else { continue }
            for part in fieldCookieHeader.split(separator: ";") {
                let pieces = part.split(separator: "=", maxSplits: 1).map {
                    String($0).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                guard pieces.count == 2, !pieces[0].isEmpty else {
                    continue
                }
                names.insert(pieces[0])
            }
        }
        if fields.keys.contains("accessToken") {
            names.insert("access_token")
            names.insert("authorization")
        }
        if fields.keys.contains("access_token") {
            names.insert("accessToken")
            names.insert("authorization")
        }

        return names
    }

    private static func serializedCredentialObject(_ object: [String: Any]) -> String? {
        let options: JSONSerialization.WritingOptions
        if #available(macOS 10.13, *) {
            options = [.sortedKeys]
        } else {
            options = []
        }

        guard JSONSerialization.isValidJSONObject(object),
              let mergedData = try? JSONSerialization.data(withJSONObject: object, options: options),
              let mergedSecret = String(data: mergedData, encoding: .utf8) else {
            return nil
        }
        return mergedSecret
    }

    private static func normalizeDomain(_ domain: String) -> String {
        domain
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
    }

    private static func matchesRequirement(_ requirement: String, cookieNames: Set<String>) -> Bool {
        requirement
            .split(separator: "|")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .contains { candidate in
                if candidate.hasSuffix("*") {
                    let prefix = String(candidate.dropLast())
                    return cookieNames.contains { $0.hasPrefix(prefix) }
                }
                return cookieNames.contains(candidate)
            }
    }

    private static func displayNameForRequirement(_ requirement: String) -> String {
        requirement
            .split(separator: "|")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { candidate in
                candidate.hasSuffix(".*") ? String(candidate.dropLast(2)) : candidate
            }
            .removingDuplicates()
            .joined(separator: " / ")
    }

}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
