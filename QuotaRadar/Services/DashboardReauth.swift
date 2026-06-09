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
        guard !requiredNames.isEmpty else { return [] }

        let presentNames = Set(cookieHeader
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

        return requiredNames
            .filter { !matchesRequirement($0, cookieNames: presentNames) }
            .map(displayNameForRequirement)
    }

    static func containsRequiredCookie(inCookieHeader cookieHeader: String, requiredNames: [String]) -> Bool {
        missingRequiredCookieNames(inCookieHeader: cookieHeader, requiredNames: requiredNames).isEmpty
    }

    static func reauthenticatedSecret(cookieHeader: String, existingSecret: String?) -> String {
        guard let existingSecret = existingSecret?.trimmingCharacters(in: .whitespacesAndNewlines),
              !existingSecret.isEmpty,
              let data = existingSecret.data(using: .utf8),
              var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return cookieHeader
        }

        let hasCredentialMetadata = object.keys.contains { key in
            let normalizedKey = key.lowercased()
            return normalizedKey != "cookie" && normalizedKey != "cookies"
        }
        guard hasCredentialMetadata else {
            return cookieHeader
        }

        object["cookie"] = cookieHeader
        if object.keys.contains("cookies") {
            object["cookies"] = cookieHeader
        }

        if let csrfToken = cookieValue(named: "csrfToken", in: cookieHeader) {
            for key in object.keys where ["csrftoken", "csrf", "xcsrftoken"].contains(key.lowercased()) {
                object[key] = csrfToken
            }
        }

        let options: JSONSerialization.WritingOptions
        if #available(macOS 10.13, *) {
            options = [.sortedKeys]
        } else {
            options = []
        }

        guard JSONSerialization.isValidJSONObject(object),
              let mergedData = try? JSONSerialization.data(withJSONObject: object, options: options),
              let mergedSecret = String(data: mergedData, encoding: .utf8) else {
            return cookieHeader
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

    private static func cookieValue(named name: String, in cookieHeader: String) -> String? {
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
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
