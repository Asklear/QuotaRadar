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
        guard provider == .kimiSubscription else { return [:] }

        var fields: [String: String] = [:]
        let storage = Dictionary(
            uniqueKeysWithValues: webStorageFields.map { key, value in
                (key.trimmingCharacters(in: .whitespacesAndNewlines), value.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        )

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

enum DashboardCredentialCapturePolicy {
    static let automaticRetryDelays: [TimeInterval] = [0.35, 1.0, 2.0]
    static let manualRetryDelays: [TimeInterval] = [0.25, 0.75, 1.5]

    static func isCredentialReady(
        _ credential: DashboardCapturedCredential,
        requiredNames: [String]
    ) -> Bool {
        credential.hasCredentialMaterial
            && DashboardCookieBuilder.missingRequiredCredentialNames(
                cookieHeader: credential.cookieHeader,
                fields: credential.fields,
                requiredNames: requiredNames
            ).isEmpty
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

    private static func credentialNames(cookieHeader: String, fields: [String: String]) -> Set<String> {
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
