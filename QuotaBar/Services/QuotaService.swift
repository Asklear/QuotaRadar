import Foundation

struct QuotaResult {
    let remaining: Int
    let limit: Int
    let resetAt: Date?
    var quotaLabel: String? = nil
    var httpStatus: Int? = nil
    var diagnosticMessage: String? = nil
}

enum QuotaParsers {
    static func parseTavilyUsage(_ data: Data) throws -> QuotaResult {
        struct UsageResponse: Decodable {
            struct KeyUsage: Decodable {
                let usage: Int
                let limit: Int?
            }

            struct AccountUsage: Decodable {
                let plan_usage: Int
                let plan_limit: Int?
            }

            let key: KeyUsage
            let account: AccountUsage
        }

        let usage = try JSONDecoder().decode(UsageResponse.self, from: data)

        if let keyLimit = usage.key.limit, keyLimit > 0 {
            let remaining = max(0, keyLimit - usage.key.usage)
            return QuotaResult(
                remaining: remaining,
                limit: keyLimit,
                resetAt: nextMonthStartLocal(),
                quotaLabel: "\(remaining) / \(keyLimit) monthly credits"
            )
        }

        guard let accountLimit = usage.account.plan_limit, accountLimit > 0 else {
            throw QuotaError.invalidResponse
        }

        let remaining = max(0, accountLimit - usage.account.plan_usage)
        return QuotaResult(
            remaining: remaining,
            limit: accountLimit,
            resetAt: nextMonthStartLocal(),
            quotaLabel: "\(remaining) / \(accountLimit) monthly credits"
        )
    }

    static func parseBraveRateLimit(
        limitHeader: String?,
        remainingHeader: String?,
        resetHeader: String?,
        policyHeader: String?
    ) throws -> QuotaResult {
        let limits = parseCommaSeparatedInts(limitHeader)
        let remaining = parseCommaSeparatedInts(remainingHeader)
        let resets = parseCommaSeparatedInts(resetHeader)
        let windows = parseBravePolicyWindows(policyHeader)

        guard !limits.isEmpty, !remaining.isEmpty else {
            throw QuotaError.invalidResponse
        }

        let count = min(limits.count, remaining.count)
        let index: Int
        if windows.count >= count, let monthlyIndex = windows.prefix(count).enumerated().max(by: { $0.element < $1.element })?.offset {
            index = monthlyIndex
        } else {
            index = count - 1
        }

        let resetAt: Date?
        if resets.indices.contains(index) {
            resetAt = Date(timeIntervalSinceNow: TimeInterval(resets[index]))
        } else {
            resetAt = nil
        }

        let limit = max(limits[index], remaining[index])
        let safeRemaining = max(0, remaining[index])
        if limit <= 0 {
            return QuotaResult(
                remaining: Int.max,
                limit: Int.max,
                resetAt: resetAt,
                quotaLabel: "Search OK · monthly quota not exposed"
            )
        }

        let label = "\(safeRemaining) / \(limit) monthly requests"
        return QuotaResult(
            remaining: safeRemaining,
            limit: limit,
            resetAt: resetAt,
            quotaLabel: label
        )
    }

    static func applyKnownBraveMonthlyQuotaIfNeeded(
        _ result: QuotaResult,
        knownRemaining: Int?,
        knownLimit: Int?
    ) -> QuotaResult {
        guard result.quotaLabel == "Search OK · monthly quota not exposed",
              let knownLimit,
              knownLimit > 0 else {
            return result
        }

        let baselineRemaining: Int
        if let knownRemaining,
           knownRemaining >= 0,
           knownRemaining < Int.max {
            baselineRemaining = knownRemaining
        } else {
            baselineRemaining = knownLimit
        }

        let refreshedRemaining = max(0, min(baselineRemaining, knownLimit) - 1)
        return QuotaResult(
            remaining: refreshedRemaining,
            limit: knownLimit,
            resetAt: result.resetAt,
            quotaLabel: "\(refreshedRemaining) / \(knownLimit) monthly requests"
        )
    }

    static func parseSerpApiAccount(_ data: Data) throws -> QuotaResult {
        struct AccountResponse: Decodable {
            let searches_per_month: Int
            let this_month_usage: Int
            let plan_searches_left: Int?
            let extra_credits: Int?
            let total_searches_left: Int?
        }

        let account = try JSONDecoder().decode(AccountResponse.self, from: data)
        let remaining = account.total_searches_left
            ?? account.plan_searches_left
            ?? max(0, account.searches_per_month - account.this_month_usage)
        let limit = account.searches_per_month + (account.extra_credits ?? 0)

        return QuotaResult(
            remaining: max(0, remaining),
            limit: max(limit, remaining),
            resetAt: nextMonthStartUTC(),
            quotaLabel: "\(max(0, remaining)) searches left"
        )
    }

    static func parseSerperAccount(_ data: Data) throws -> QuotaResult {
        struct AccountResponse: Decodable {
            let balance: Int
            let rateLimit: Int?
        }

        let account = try JSONDecoder().decode(AccountResponse.self, from: data)
        let remaining = max(0, account.balance)
        let label = account.balance > 0
            ? "\(account.balance) credits left"
            : "No Serper credits available"

        return QuotaResult(
            remaining: remaining,
            limit: remaining,
            resetAt: nil,
            quotaLabel: label
        )
    }

    static func parseQueritAccount(_ data: Data) throws -> QuotaResult {
        struct FlexibleInt: Decodable {
            let value: Int

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let int = try? container.decode(Int.self) {
                    value = int
                } else if let double = try? container.decode(Double.self) {
                    value = Int(double.rounded(.down))
                } else if let string = try? container.decode(String.self),
                          let double = Double(string) {
                    value = Int(double.rounded(.down))
                } else {
                    throw QuotaError.invalidResponse
                }
            }
        }

        struct AccountResponse: Decodable {
            let ErrNo: Int?
            let Data: AccountData?
            let data: AccountData?
        }

        struct AccountData: Decodable {
            let current_plan: CurrentPlan?
        }

        struct CurrentPlan: Decodable {
            let free_usage_month: FlexibleInt?
            let coupon_quota: FlexibleInt?
            let coupon_used: FlexibleInt?
        }

        let response = try JSONDecoder().decode(AccountResponse.self, from: data)
        if let errNo = response.ErrNo, errNo != 200 {
            throw QuotaError.invalidResponse
        }
        guard let plan = (response.Data ?? response.data)?.current_plan else {
            throw QuotaError.invalidResponse
        }

        let couponQuota = max(0, plan.coupon_quota?.value ?? 0)
        let couponUsed = max(0, plan.coupon_used?.value ?? 0)
        let freeUsageMonth = max(0, plan.free_usage_month?.value ?? 0)
        let limit = 1_000 + couponQuota
        let used = freeUsageMonth + couponUsed
        let remaining = max(0, limit - used)

        return QuotaResult(
            remaining: remaining,
            limit: limit,
            resetAt: nextMonthStartUTC(),
            quotaLabel: "\(remaining) / \(limit) monthly requests"
        )
    }

    static func parseDeepSeekBalance(_ data: Data) throws -> QuotaResult {
        struct BalanceResponse: Decodable {
            struct BalanceInfo: Decodable {
                let currency: String
                let total_balance: String
            }

            let balance_infos: [BalanceInfo]
            let is_available: Bool
        }

        let response = try JSONDecoder().decode(BalanceResponse.self, from: data)
        guard response.is_available, let balance = response.balance_infos.first else {
            return QuotaResult(remaining: 0, limit: 0, resetAt: nil, quotaLabel: "Unavailable")
        }

        guard let value = Decimal(string: balance.total_balance) else {
            throw QuotaError.invalidResponse
        }

        let cents = NSDecimalNumber(decimal: value * Decimal(100)).intValue
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.minimumIntegerDigits = 1
        let labelValue = formatter.string(from: NSDecimalNumber(decimal: value))
            ?? NSDecimalNumber(decimal: value).stringValue
        return QuotaResult(
            remaining: max(0, cents),
            limit: max(0, cents),
            resetAt: nil,
            quotaLabel: "\(balance.currency) \(labelValue) available"
        )
    }

    static func parseDajialaRemainMoney(_ data: Data) throws -> QuotaResult {
        struct RemainMoneyResponse: Decodable {
            struct FlexibleDecimal: Decodable {
                let value: Decimal

                init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    if let decimal = try? container.decode(Decimal.self) {
                        value = decimal
                    } else if let string = try? container.decode(String.self),
                              let decimal = Decimal(string: string) {
                        value = decimal
                    } else {
                        throw QuotaError.invalidResponse
                    }
                }
            }

            let code: Int
            let remain_money: FlexibleDecimal?
        }

        let response = try JSONDecoder().decode(RemainMoneyResponse.self, from: data)
        guard response.code == 0, let remainMoney = response.remain_money?.value else {
            throw QuotaError.invalidResponse
        }

        let cents = NSDecimalNumber(decimal: remainMoney * Decimal(100)).intValue
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.minimumIntegerDigits = 1
        let labelValue = formatter.string(from: NSDecimalNumber(decimal: remainMoney))
            ?? NSDecimalNumber(decimal: remainMoney).stringValue

        return QuotaResult(
            remaining: max(0, cents),
            limit: max(0, cents),
            resetAt: nil,
            quotaLabel: "CNY \(labelValue) available"
        )
    }

    static func parseBochaRemainingFund(_ data: Data) throws -> QuotaResult {
        struct RemainingFundResponse: Decodable {
            struct FundData: Decodable {
                let remaining: Decimal
            }

            let success: Bool?
            let code: String?
            let data: FundData?
        }

        let response = try JSONDecoder().decode(RemainingFundResponse.self, from: data)
        guard response.success == true,
              response.code == "200",
              let remaining = response.data?.remaining else {
            throw QuotaError.invalidResponse
        }

        let cents = NSDecimalNumber(decimal: remaining * Decimal(100)).intValue
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.minimumIntegerDigits = 1
        let labelValue = formatter.string(from: NSDecimalNumber(decimal: remaining))
            ?? NSDecimalNumber(decimal: remaining).stringValue

        return QuotaResult(
            remaining: max(0, cents),
            limit: max(0, cents),
            resetAt: nil,
            quotaLabel: "CNY \(labelValue) balance"
        )
    }

    static func parseXFYunCodingPlanList(_ data: Data) throws -> QuotaResult {
        struct CodingPlanListResponse: Decodable {
            struct PageData: Decodable {
                let rows: [Plan]
            }

            struct Plan: Decodable {
                let name: String?
                let expiresAt: String?
                let status: Int?
                let codingPlanUsageDTO: Usage?
            }

            struct Usage: Decodable {
                let packageLeft: Int?
                let packageLimit: Int?
                let packageUsage: Int?
                let rp5hLimit: Int?
                let rp5hUsage: Int?
                let rpwLimit: Int?
                let rpwUsage: Int?
            }

            let code: Int?
            let data: PageData?
            let succeed: Bool?
            let failed: Bool?
        }

        let response = try JSONDecoder().decode(CodingPlanListResponse.self, from: data)
        if response.code == 4001 || response.failed == true {
            throw QuotaError.unauthorized
        }
        guard response.code == 0 || response.succeed == true,
              let rows = response.data?.rows,
              let plan = rows.first(where: { $0.status == 1 && $0.codingPlanUsageDTO != nil }) ?? rows.first(where: { $0.codingPlanUsageDTO != nil }),
              let usage = plan.codingPlanUsageDTO else {
            throw QuotaError.invalidResponse
        }

        var windows: [(name: String, left: Int, limit: Int)] = []
        if let limit = usage.rp5hLimit, limit > 0 {
            windows.append(("5h", max(0, limit - (usage.rp5hUsage ?? 0)), limit))
        }
        if let limit = usage.rpwLimit, limit > 0 {
            windows.append(("week", max(0, limit - (usage.rpwUsage ?? 0)), limit))
        }
        if let limit = usage.packageLimit, limit > 0 {
            let left = usage.packageLeft ?? max(0, limit - (usage.packageUsage ?? 0))
            windows.append(("month", max(0, left), limit))
        }

        guard !windows.isEmpty else {
            throw QuotaError.invalidResponse
        }

        let percentWindows = windows.map { window in
            (
                name: window.name,
                remainingPercent: Double(window.left) / Double(window.limit) * 100
            )
        }
        let basisPoints = percentWindows
            .map { Int(($0.remainingPercent * 100).rounded(.down)) }
            .min() ?? 0
        let label = percentWindows
            .map { window in "\(window.name) \(formatPercent(window.remainingPercent))" }
            .joined(separator: " · ")

        return QuotaResult(
            remaining: max(0, min(10_000, basisPoints)),
            limit: 10_000,
            resetAt: parseLocalDateTime(plan.expiresAt),
            quotaLabel: label
        )
    }

    static func parseVolcengineCodingPlanUsage(_ data: Data) throws -> QuotaResult {
        struct CodingPlanUsageResponse: Decodable {
            struct ResultData: Decodable {
                let Status: String?
                let QuotaUsage: [UsageWindow]
            }

            struct UsageWindow: Decodable {
                let Level: String
                let Percent: Double
                let ResetTimestamp: Int?
            }

            let Result: ResultData?
        }

        let response = try JSONDecoder().decode(CodingPlanUsageResponse.self, from: data)
        guard let usage = response.Result?.QuotaUsage, !usage.isEmpty else {
            throw QuotaError.invalidResponse
        }

        let windows = usage.map { item -> PercentQuotaWindow in
            let name: String
            switch item.Level.lowercased() {
            case "session", "rolling", "five_hour", "5h":
                name = "5h"
            case "weekly", "week":
                name = "week"
            case "monthly", "month":
                name = "month"
            default:
                name = item.Level
            }
            let resetAt = item.ResetTimestamp.flatMap { $0 > 0 ? Date(timeIntervalSince1970: TimeInterval($0)) : nil }
            return PercentQuotaWindow(
                name: name,
                remainingPercent: max(0, 100 - item.Percent),
                resetAt: resetAt
            )
        }

        let orderedWindows = orderPercentWindows(windows)
        return percentQuotaResult(
            windows: orderedWindows,
            label: orderedWindows
                .map { window in "\(window.name) \(formatPercent(window.remainingPercent))" }
                .joined(separator: " · ")
        )
    }

    static func parseOpenCodeGoUsage(_ data: Data) throws -> QuotaResult {
        guard let text = String(data: data, encoding: .utf8) else {
            throw QuotaError.invalidResponse
        }
        if text.contains("/auth/authorize") {
            throw QuotaError.unauthorized
        }

        let specs = [
            (field: "rollingUsage", name: "5h"),
            (field: "weeklyUsage", name: "week"),
            (field: "monthlyUsage", name: "month"),
        ]

        let windows = specs.compactMap { spec -> PercentQuotaWindow? in
            guard let block = firstRegexMatch(
                in: text,
                pattern: "\(spec.field):[^\\{]*\\{([^}]*)\\}"
            ),
            let usagePercent = firstDouble(in: block, field: "usagePercent") else {
                return nil
            }

            let resetInSec = firstDouble(in: block, field: "resetInSec")
            let resetAt = resetInSec.flatMap { $0 > 0 ? Date(timeIntervalSinceNow: TimeInterval($0)) : nil }
            return PercentQuotaWindow(
                name: spec.name,
                remainingPercent: max(0, 100 - usagePercent),
                resetAt: resetAt
            )
        }

        guard windows.count == specs.count else {
            throw QuotaError.invalidResponse
        }

        return percentQuotaResult(
            windows: windows,
            label: windows
                .map { window in "\(window.name) \(formatPercent(window.remainingPercent))" }
                .joined(separator: " · ")
        )
    }

    private static func parseCommaSeparatedInts(_ header: String?) -> [Int] {
        header?
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        ?? []
    }

    private struct PercentQuotaWindow {
        let name: String
        let remainingPercent: Double
        let resetAt: Date?
    }

    private static func percentQuotaResult(windows: [PercentQuotaWindow], label: String) -> QuotaResult {
        let tightest = windows.min { lhs, rhs in
            lhs.remainingPercent < rhs.remainingPercent
        }
        let remainingPercent = tightest?.remainingPercent ?? 0
        let basisPoints = Int((max(0, min(100, remainingPercent)) * 100).rounded(.down))
        let resetAt = windows
            .sorted { lhs, rhs in lhs.remainingPercent < rhs.remainingPercent }
            .first { $0.resetAt != nil }?
            .resetAt

        return QuotaResult(
            remaining: max(0, min(10_000, basisPoints)),
            limit: 10_000,
            resetAt: resetAt,
            quotaLabel: label
        )
    }

    private static func orderPercentWindows(_ windows: [PercentQuotaWindow]) -> [PercentQuotaWindow] {
        let order = ["5h": 0, "week": 1, "month": 2]
        return windows.sorted {
            (order[$0.name] ?? Int.max, $0.name) < (order[$1.name] ?? Int.max, $1.name)
        }
    }

    private static func formatPercent(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if abs(rounded.rounded() - rounded) < 0.0001 {
            return "\(Int(rounded.rounded()))%"
        }
        return String(format: "%.1f%%", locale: Locale(identifier: "en_US_POSIX"), rounded)
    }

    private static func parseLocalDateTime(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: value)
    }

    private static func firstDouble(in text: String, field: String) -> Double? {
        firstRegexMatch(in: text, pattern: "\(field):(-?[0-9]+(?:\\.[0-9]+)?)")
            .flatMap(Double.init)
    }

    private static func firstRegexMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let matchRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return String(text[matchRange])
    }

    private static func parseBravePolicyWindows(_ header: String?) -> [Int] {
        header?
            .split(separator: ",")
            .compactMap { part in
                part
                    .split(separator: ";")
                    .first { $0.trimmingCharacters(in: .whitespaces).hasPrefix("w=") }
                    .flatMap { Int($0.trimmingCharacters(in: .whitespaces).dropFirst(2)) }
            }
        ?? []
    }

    private static func nextMonthStartUTC() -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let startOfCurrentMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: Date())
        )
        return startOfCurrentMonth.flatMap {
            calendar.date(byAdding: DateComponents(month: 1), to: $0)
        }
    }

    private static func nextMonthStartLocal() -> Date? {
        let calendar = Calendar.current
        let startOfCurrentMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: Date())
        )
        return startOfCurrentMonth.flatMap {
            calendar.date(byAdding: DateComponents(month: 1), to: $0)
        }
    }
}

enum QuotaError: Error, LocalizedError {
    case invalidResponse
    case networkError(Error)
    case rateLimited(resetAt: Date?)
    case unauthorized
    case notSupported
    case cooldown

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimited:
            return "Rate limit exceeded"
        case .unauthorized:
            return "Invalid API key"
        case .notSupported:
            return "Quota check not supported for this provider"
        case .cooldown:
            return "Quota was checked recently"
        }
    }

    var httpStatus: Int? {
        switch self {
        case .unauthorized:
            return 401
        case .rateLimited:
            return 429
        case .invalidResponse, .networkError, .notSupported, .cooldown:
            return nil
        }
    }
}

private struct DashboardCredential {
    private let raw: String
    private let fields: [String: String]

    init(_ raw: String) {
        self.raw = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = self.raw.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            var parsedFields: [String: String] = [:]
            for (key, value) in object {
                if let string = value as? String {
                    parsedFields[key.lowercased()] = string
                } else if let number = value as? NSNumber {
                    parsedFields[key.lowercased()] = number.stringValue
                }
            }
            fields = parsedFields
        } else {
            fields = [:]
        }
    }

    var cookie: String {
        if let value = value(for: ["cookie", "cookies"]) {
            return value
        }

        let prefixes = ["cookie:", "Cookie:"]
        for prefix in prefixes where raw.hasPrefix(prefix) {
            return String(raw.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return raw
    }

    func value(for names: [String]) -> String? {
        for name in names {
            if let value = fields[name.lowercased()], !value.isEmpty {
                return value
            }
        }
        return nil
    }

    func cookieValue(named name: String) -> String? {
        for part in cookie.split(separator: ";") {
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

actor QuotaService {
    private let session: URLSession
    private var lastCheck: [String: Date] = [:]

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    func checkQuota(for key: APIKey, bypassCooldown: Bool = false) async throws -> QuotaResult {
        // 检查冷却时间（30秒内不重复请求）
        let cacheKey = "\(key.provider.rawValue)_\(key.name)"
        if !bypassCooldown,
           let lastCheck = lastCheck[cacheKey],
           Date().timeIntervalSince(lastCheck) < 30 {
            throw QuotaError.cooldown
        }
        lastCheck[cacheKey] = Date()

        switch key.provider {
        case .tavily:
            return try await checkTavilyQuota(key: key)
        case .brave:
            return try await checkBraveQuota(key: key)
        case .serpapi:
            return try await checkSerpApiQuota(key: key)
        case .serper:
            return try await checkSerperQuota(key: key)
        case .exa:
            return try await checkExaQuota(key: key)
        case .bocha:
            return try await checkBochaQuota(key: key)
        case .anysearch:
            return try await checkAnySearchQuota(key: key)
        case .querit:
            return try await checkQueritQuota(key: key)
        case .anthropic:
            return try await checkAnthropicQuota(key: key)
        case .deepseek:
            return try await checkDeepSeekQuota(key: key)
        case .xfyunCodingPlan:
            return try await checkXFYunCodingPlanQuota(key: key)
        case .volcengineCodingPlan:
            return try await checkVolcengineCodingPlanQuota(key: key)
        case .opencodeGo:
            return try await checkOpenCodeGoQuota(key: key)
        case .wxmp:
            return try await checkWxmpQuota(key: key)
        }
    }

    // MARK: - Search Providers

    /// Tavily: 通过轻量搜索请求获取 quota header
    /// GET /usage returns key-level usage when a per-key limit exists, otherwise account plan usage.
    private func checkTavilyQuota(key: APIKey) async throws -> QuotaResult {
        var request = URLRequest(url: URL(string: "https://api.tavily.com/usage")!)
        request.setValue("Bearer \(key.key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuotaError.invalidResponse
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw QuotaError.unauthorized
        }
        guard httpResponse.statusCode == 200 else {
            throw QuotaError.invalidResponse
        }

        return try QuotaParsers.parseTavilyUsage(data)
    }

    /// Brave Search: 通过轻量搜索获取 quota header
    /// Headers: X-RateLimit-Limit, X-RateLimit-Remaining
    private func checkBraveQuota(key: APIKey) async throws -> QuotaResult {
        var request = URLRequest(url: URL(string: "https://api.search.brave.com/res/v1/web/search?q=test&count=1")!)
        request.setValue(key.key, forHTTPHeaderField: "X-Subscription-Token")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuotaError.invalidResponse
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw QuotaError.unauthorized
        }

        var result = try QuotaParsers.parseBraveRateLimit(
            limitHeader: httpResponse.value(forHTTPHeaderField: "X-RateLimit-Limit"),
            remainingHeader: httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
            resetHeader: httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset"),
            policyHeader: httpResponse.value(forHTTPHeaderField: "X-RateLimit-Policy")
        )
        if httpResponse.statusCode == 402 {
            result.httpStatus = httpResponse.statusCode
            result.quotaLabel = "Usage limit exceeded"
            result.diagnosticMessage = "Brave returned HTTP 402 usage limit exceeded."
        } else {
            result = QuotaParsers.applyKnownBraveMonthlyQuotaIfNeeded(
                result,
                knownRemaining: key.remaining,
                knownLimit: key.limit
            )
            result.httpStatus = httpResponse.statusCode
            if result.quotaLabel == "Search OK · monthly quota not exposed" {
                result.diagnosticMessage = "Search works, but Brave did not expose monthly quota for this key."
            } else {
                result.diagnosticMessage = "Search works and Brave returned quota headers."
            }
        }
        return result
    }

    /// SerpAPI: 有专门的 account endpoint
    /// GET https://serpapi.com/account?api_key=xxx
    private func checkSerpApiQuota(key: APIKey) async throws -> QuotaResult {
        let url = URL(string: "https://serpapi.com/account.json?api_key=\(key.key)")!
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw QuotaError.invalidResponse
        }

        return try QuotaParsers.parseSerpApiAccount(data)
    }

    /// Serper: account endpoint returns credit balance without issuing a search.
    private func checkSerperQuota(key: APIKey) async throws -> QuotaResult {
        var request = URLRequest(url: URL(string: "https://google.serper.dev/account")!)
        request.httpMethod = "GET"
        request.setValue(key.key, forHTTPHeaderField: "X-API-KEY")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuotaError.invalidResponse
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw QuotaError.unauthorized
        }
        guard httpResponse.statusCode == 200 else {
            throw QuotaError.invalidResponse
        }

        return try QuotaParsers.parseSerperAccount(data)
    }

    /// Exa Admin API requires a service key and the target API key id.
    /// A plain Exa search API key cannot call the Team Management usage endpoint.
    private func checkExaQuota(key: APIKey) async throws -> QuotaResult {
        throw QuotaError.notSupported
    }

    /// Bocha: 查询账户资源包 / 余额。
    private func checkBochaQuota(key: APIKey) async throws -> QuotaResult {
        var request = URLRequest(url: URL(string: "https://api.bochaai.com/v1/fund/remaining")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key.key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuotaError.invalidResponse
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw QuotaError.unauthorized
        }
        guard httpResponse.statusCode == 200 else {
            throw QuotaError.invalidResponse
        }

        return try QuotaParsers.parseBochaRemainingFund(data)
    }

    /// AnySearch: 当前免费使用，没有公开 quota 上限。
    private func checkAnySearchQuota(key: APIKey) async throws -> QuotaResult {
        QuotaResult(
            remaining: Int.max,
            limit: Int.max,
            resetAt: nil,
            quotaLabel: "Unlimited free usage"
        )
    }

    /// 微信搜索 / 极致了数据：查询账户剩余金额，不消耗搜索调用额度。
    private func checkWxmpQuota(key: APIKey) async throws -> QuotaResult {
        var request = URLRequest(url: URL(string: "https://www.dajiala.com/fbmain/monitor/v3/get_remain_money")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var form = URLComponents()
        form.queryItems = [URLQueryItem(name: "key", value: key.key)]
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuotaError.invalidResponse
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw QuotaError.unauthorized
        }
        guard httpResponse.statusCode == 200 else {
            throw QuotaError.invalidResponse
        }

        return try QuotaParsers.parseDajialaRemainMoney(data)
    }

    /// Querit: dashboard account endpoint returns monthly request usage when authenticated by session cookie.
    private func checkQueritQuota(key: APIKey) async throws -> QuotaResult {
        var request = URLRequest(url: URL(string: "https://www.querit.ai/api/v1/user/account")!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue(key.key, forHTTPHeaderField: "Cookie")
        request.setValue("https://www.querit.ai/zh/dashboard/home", forHTTPHeaderField: "Referer")
        request.setValue("\"Chromium\";v=\"148\", \"Google Chrome\";v=\"148\", \"Not/A)Brand\";v=\"99\"", forHTTPHeaderField: "sec-ch-ua")
        request.setValue("?0", forHTTPHeaderField: "sec-ch-ua-mobile")
        request.setValue("\"macOS\"", forHTTPHeaderField: "sec-ch-ua-platform")
        request.setValue("empty", forHTTPHeaderField: "sec-fetch-dest")
        request.setValue("cors", forHTTPHeaderField: "sec-fetch-mode")
        request.setValue("same-origin", forHTTPHeaderField: "sec-fetch-site")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuotaError.invalidResponse
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw QuotaError.unauthorized
        }
        guard httpResponse.statusCode == 200 else {
            throw QuotaError.invalidResponse
        }

        var result = try QuotaParsers.parseQueritAccount(data)
        result.httpStatus = httpResponse.statusCode
        result.diagnosticMessage = "Querit account endpoint returned monthly request quota."
        return result
    }

    // MARK: - LLM Providers

    /// Anthropic: 通过 API 获取 usage
    /// https://docs.anthropic.com/en/api/rate-limits
    private func checkAnthropicQuota(key: APIKey) async throws -> QuotaResult {
        throw QuotaError.notSupported
    }

    /// DeepSeek: 通过 API 获取 quota
    private func checkDeepSeekQuota(key: APIKey) async throws -> QuotaResult {
        var request = URLRequest(url: URL(string: "https://api.deepseek.com/user/balance")!)
        request.setValue("Bearer \(key.key)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw QuotaError.invalidResponse
        }

        return try QuotaParsers.parseDeepSeekBalance(data)
    }

    /// 讯飞星火 Coding Plan: dashboard session endpoint.
    /// The secret should be the logged-in Cookie header, or JSON: {"cookie":"..."}.
    private func checkXFYunCodingPlanQuota(key: APIKey) async throws -> QuotaResult {
        let credential = DashboardCredential(key.key)
        guard !credential.cookie.isEmpty else {
            throw QuotaError.unauthorized
        }

        var request = URLRequest(url: URL(string: "https://maas.xfyun.cn/api/v1/gpt-finetune/coding-plan/list?page=1&size=6")!)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue(credential.cookie, forHTTPHeaderField: "Cookie")
        request.setValue("https://maas.xfyun.cn/packageSubscription", forHTTPHeaderField: "Referer")
        request.setValue("", forHTTPHeaderField: "x-auth-source")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuotaError.invalidResponse
        }
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw QuotaError.unauthorized
        }
        guard httpResponse.statusCode == 200 else {
            throw QuotaError.invalidResponse
        }

        return try QuotaParsers.parseXFYunCodingPlanList(data)
    }

    /// 火山引擎 Coding Plan: console session endpoint.
    /// The secret can be a raw Cookie header, or JSON with cookie/csrfToken/projectName/xWebId.
    private func checkVolcengineCodingPlanQuota(key: APIKey) async throws -> QuotaResult {
        let credential = DashboardCredential(key.key)
        guard !credential.cookie.isEmpty else {
            throw QuotaError.unauthorized
        }

        let projectName = credential.value(for: ["projectName", "project"]) ?? "default"
        var request = URLRequest(url: URL(string: "https://console.volcengine.com/api/top/ark/cn-beijing/2024-01-01/GetCodingPlanUsage?")!)
        request.httpMethod = "POST"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(credential.cookie, forHTTPHeaderField: "Cookie")
        request.setValue("https://console.volcengine.com", forHTTPHeaderField: "Origin")
        request.setValue("https://console.volcengine.com/ark/region:ark+cn-beijing/openManagement?LLM=%7B%7D&advancedActiveKey=subscribe&projectName=\(projectName)", forHTTPHeaderField: "Referer")

        if let csrfToken = credential.value(for: ["csrfToken", "csrf", "xCsrfToken"]) ?? credential.cookieValue(named: "csrfToken") {
            request.setValue(csrfToken, forHTTPHeaderField: "x-csrf-token")
        }
        if let webID = credential.value(for: ["xWebId", "x-web-id", "webId"]) {
            request.setValue(webID, forHTTPHeaderField: "x-web-id")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: ["ProjectName": projectName])

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuotaError.invalidResponse
        }
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw QuotaError.unauthorized
        }
        guard httpResponse.statusCode == 200 else {
            throw QuotaError.invalidResponse
        }

        return try QuotaParsers.parseVolcengineCodingPlanUsage(data)
    }

    /// OpenCode Go: dashboard server function endpoint.
    /// The secret can be a raw Cookie header, or JSON with cookie/workspaceID/serverID/serverInstance.
    private func checkOpenCodeGoQuota(key: APIKey) async throws -> QuotaResult {
        let credential = DashboardCredential(key.key)
        guard !credential.cookie.isEmpty else {
            throw QuotaError.unauthorized
        }

        let workspaceID = credential.value(for: ["workspaceID", "workspaceId", "workspace"])
            ?? "wrk_01KSKR4K4WDJY0JZSCJTMRZ5CV"
        let serverID = credential.value(for: ["serverID", "serverId"])
            ?? "c7389bd0e731f80f49593e5ee53835475f4e28594dd6bd83eb229bab753498cd"
        let serverInstance = credential.value(for: ["serverInstance"])
            ?? "server-fn:11"
        let args: [String: Any] = [
            "t": [
                "t": 9,
                "i": 0,
                "l": 1,
                "a": [["t": 1, "s": workspaceID]],
                "o": 0,
            ],
            "f": 31,
            "m": [],
        ]
        let argsData = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsData, encoding: .utf8) ?? ""

        var components = URLComponents(string: "https://opencode.ai/_server")!
        components.queryItems = [
            URLQueryItem(name: "id", value: serverID),
            URLQueryItem(name: "args", value: argsString),
        ]
        guard let url = components.url else {
            throw QuotaError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("u=1, i", forHTTPHeaderField: "Priority")
        request.setValue(credential.cookie, forHTTPHeaderField: "Cookie")
        request.setValue("https://opencode.ai/workspace/\(workspaceID)", forHTTPHeaderField: "Referer")
        request.setValue("\"Chromium\";v=\"148\", \"Google Chrome\";v=\"148\", \"Not/A)Brand\";v=\"99\"", forHTTPHeaderField: "sec-ch-ua")
        request.setValue("?0", forHTTPHeaderField: "sec-ch-ua-mobile")
        request.setValue("\"macOS\"", forHTTPHeaderField: "sec-ch-ua-platform")
        request.setValue("empty", forHTTPHeaderField: "sec-fetch-dest")
        request.setValue("cors", forHTTPHeaderField: "sec-fetch-mode")
        request.setValue("same-origin", forHTTPHeaderField: "sec-fetch-site")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue(serverID, forHTTPHeaderField: "x-server-id")
        request.setValue(serverInstance, forHTTPHeaderField: "x-server-instance")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuotaError.invalidResponse
        }
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw QuotaError.unauthorized
        }
        guard httpResponse.statusCode == 200 else {
            throw QuotaError.invalidResponse
        }

        return try QuotaParsers.parseOpenCodeGoUsage(data)
    }
}
