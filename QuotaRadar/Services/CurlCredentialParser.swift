import Foundation

struct ParsedCurlCredential {
    let provider: Provider
    let cookie: String
    let fields: [String: String]

    var serializedCredential: String {
        var object: [String: String] = fields
        object["cookie"] = cookie

        let options: JSONSerialization.WritingOptions
        if #available(macOS 10.13, *) {
            options = [.sortedKeys]
        } else {
            options = []
        }

        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: options),
              let value = String(data: data, encoding: .utf8) else {
            return cookie
        }
        return value
    }
}

enum CurlCredentialParserError: Error, LocalizedError {
    case missingCredentialMaterial

    var errorDescription: String? {
        switch self {
        case .missingCredentialMaterial:
            return L10n.t(.curlImportFailed)
        }
    }
}

struct CurlCredentialParser {
    static func parse(_ curl: String, provider: Provider) throws -> ParsedCurlCredential {
        let headers = parseHeaders(in: curl)
        let cookie = firstOptionValue(in: curl, optionNames: ["-b", "--cookie"])
            ?? headers["cookie"]
            ?? ""

        var fields: [String: String] = [:]

        switch provider {
        case .volcengineCodingPlan:
            if let csrfToken = headers["x-csrf-token"] ?? cookieValue(named: "csrfToken", in: cookie) {
                fields["csrfToken"] = csrfToken
            }
            if let webID = headers["x-web-id"] {
                fields["xWebId"] = webID
            }
            if let projectName = parseJSONBody(in: curl)["ProjectName"] {
                fields["projectName"] = projectName
            }
        case .opencodeGo:
            if let serverID = headers["x-server-id"] ?? URLComponents(string: firstURL(in: curl) ?? "")?.queryItems?.first(where: { $0.name == "id" })?.value {
                fields["serverID"] = serverID
            }
            if let serverInstance = headers["x-server-instance"] {
                fields["serverInstance"] = serverInstance
            }
            if let referer = headers["referer"],
               let workspaceID = firstRegexMatch(in: referer, pattern: #"/workspace/([^/?#]+)"#) {
                fields["workspaceID"] = workspaceID
            }
        case .kimiSubscription:
            if let authorization = headers["authorization"] {
                fields["accessToken"] = stripBearerPrefix(authorization)
            } else if let cookieToken = cookieValue(named: "kimi-auth", in: cookie) {
                fields["accessToken"] = cookieToken
            }
            if let deviceID = headers["x-msh-device-id"] {
                fields["deviceID"] = deviceID
            }
            if let sessionID = headers["x-msh-session-id"] {
                fields["sessionID"] = sessionID
            }
            if let trafficID = headers["x-traffic-id"] {
                fields["trafficID"] = trafficID
            }
        case .querit, .xfyunCodingPlan, .claudeSubscription, .anthropicCredits, .codexSubscription, .longcat:
            break
        case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .anthropic, .claudeAPIUsage, .codexAPIUsage, .deepseek, .xfyunTokenPlan, .volcengineTokenPlan, .aliyunCodingPlan, .aliyunTokenPlan, .tencentCloudCodingPlan, .tencentCloudTokenPlan:
            break
        }

        guard !cookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !fields.isEmpty else {
            throw CurlCredentialParserError.missingCredentialMaterial
        }

        return ParsedCurlCredential(provider: provider, cookie: cookie, fields: fields)
    }

    private static func parseHeaders(in text: String) -> [String: String] {
        var headers: [String: String] = [:]
        let patterns = [
            #"(?:-H|--header)\s+'([^']+)'"#,
            #"(?:"-H"|"--header")\s+"([^"]+)""#,
            #"(?:-H|--header)\s+"([^"]+)""#
        ]

        for pattern in patterns {
            for value in regexMatches(in: text, pattern: pattern) {
                let pieces = value.split(separator: ":", maxSplits: 1).map {
                    String($0).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                guard pieces.count == 2, !pieces[0].isEmpty else { continue }
                headers[pieces[0].lowercased()] = pieces[1]
            }
        }
        return headers
    }

    private static func firstOptionValue(in text: String, optionNames: [String]) -> String? {
        for optionName in optionNames {
            let escaped = NSRegularExpression.escapedPattern(for: optionName)
            let patterns = [
                "\(escaped)\\s+'([^']*)'",
                "\(escaped)\\s+\"([^\"]*)\"",
                "\(escaped)\\s+([^\\s\\\\]+)"
            ]
            for pattern in patterns {
                if let match = firstRegexMatch(in: text, pattern: pattern), !match.isEmpty {
                    return match
                }
            }
        }
        return nil
    }

    private static func parseJSONBody(in text: String) -> [String: String] {
        guard let rawBody = firstOptionValue(in: text, optionNames: ["--data-raw", "--data", "--data-binary"]),
              let data = rawBody.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }

        var fields: [String: String] = [:]
        for (key, value) in object {
            if let string = value as? String {
                fields[key] = string
            } else if let number = value as? NSNumber {
                fields[key] = number.stringValue
            }
        }
        return fields
    }

    private static func firstURL(in text: String) -> String? {
        firstRegexMatch(in: text, pattern: #"curl\s+'([^']+)'"#)
            ?? firstRegexMatch(in: text, pattern: #"curl\s+"([^"]+)""#)
            ?? firstRegexMatch(in: text, pattern: #"curl\s+([^\s\\]+)"#)
    }

    private static func cookieValue(named name: String, in cookie: String) -> String? {
        for part in cookie.split(separator: ";") {
            let pieces = part.split(separator: "=", maxSplits: 1).map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard pieces.count == 2, pieces[0] == name else { continue }
            return pieces[1]
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

    private static func firstRegexMatch(in text: String, pattern: String) -> String? {
        regexMatches(in: text, pattern: pattern).first
    }

    private static func regexMatches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let matchRange = Range(match.range(at: 1), in: text) else {
                return nil
            }
            return String(text[matchRange])
        }
    }
}
