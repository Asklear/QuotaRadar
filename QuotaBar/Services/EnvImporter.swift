import Foundation

struct EnvImporter {
    static func parseEnvFile(at url: URL) -> [APIKey] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }

        return parseEnvContent(content)
    }

    static func parseEnvContent(_ content: String) -> [APIKey] {
        var keys: [APIKey] = []
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            var trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip comments and empty lines
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            if trimmed.hasPrefix("export ") {
                trimmed.removeFirst("export ".count)
            }

            // Parse KEY=value format
            let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }

            let keyName = parts[0].trimmingCharacters(in: .whitespaces)
            let keyValue = parts[1].trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

            guard !keyValue.isEmpty, keyValue != "xxx" else { continue }

            // Try to match with provider
            if let provider = detectProvider(from: keyName) {
                let apiKey = APIKey(
                    name: keyName,
                    key: keyValue,
                    provider: provider,
                    note: L10n.t(.importedFromEnv)
                )
                keys.append(apiKey)
            }
        }

        return keys
    }

    static func parseEnvironment(_ environment: [String: String], note: String) -> [APIKey] {
        environment.compactMap { keyName, keyValue in
            let trimmedValue = keyValue.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

            guard !trimmedValue.isEmpty, trimmedValue != "xxx",
                  let provider = detectProvider(from: keyName) else {
                return nil
            }

            return APIKey(
                name: keyName,
                key: trimmedValue,
                provider: provider,
                note: note
            )
        }
        .sorted { lhs, rhs in
            if lhs.provider.rawValue == rhs.provider.rawValue {
                return lhs.name < rhs.name
            }
            return lhs.provider.rawValue < rhs.provider.rawValue
        }
    }

    private static func detectProvider(from keyName: String) -> Provider? {
        let uppercased = keyName.uppercased()

        if uppercased.contains("TAVILY") {
            return .tavily
        } else if uppercased.contains("BRAVE") {
            return .brave
        } else if uppercased.contains("SERPAPI") {
            return .serpapi
        } else if uppercased.contains("SERPER") {
            return .serper
        } else if uppercased.contains("EXA") {
            return .exa
        } else if uppercased.contains("BOCHA") {
            return .bocha
        } else if uppercased.contains("ANYSEARCH") {
            return .anysearch
        } else if uppercased.contains("QUERIT")
                    && (uppercased.contains("COOKIE") || uppercased.contains("SESSION")) {
            return .querit
        } else if uppercased.contains("WX") && uppercased.contains("SEARCH") {
            return .wxmp
        } else if uppercased.contains("WECHAT") {
            return .wxmp
        } else if uppercased.contains("DEEPSEEK") && uppercased.contains("API_KEY") && !uppercased.contains("WEB_SEARCH_PRO") {
            return .deepseek
        } else if (uppercased.contains("XFYUN") || uppercased.contains("IFLYTEK") || uppercased.contains("SPARK"))
                    && (uppercased.contains("CODING") || uppercased.contains("COOKIE") || uppercased.contains("SESSION")) {
            return .xfyunCodingPlan
        } else if (uppercased.contains("VOLCENGINE") || uppercased.contains("VOLC") || uppercased.contains("ARK"))
                    && (uppercased.contains("CODING") || uppercased.contains("COOKIE") || uppercased.contains("SESSION")) {
            return .volcengineCodingPlan
        } else if uppercased.contains("OPENCODE")
                    && (uppercased.contains("GO") || uppercased.contains("COOKIE") || uppercased.contains("SESSION")) {
            return .opencodeGo
        }

        return nil
    }
}
