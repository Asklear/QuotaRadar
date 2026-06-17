import Foundation
import CryptoKit

struct QuotaResult {
    let remaining: Int
    let limit: Int
    let resetAt: Date?
    var planEndsAt: Date?
    var planDisplayName: String?
    var quotaLabel: String? = nil
    var quotaText: LocalizedTextDescriptor? = nil
    var quotaWindows: [QuotaWindowText] = []
    var httpStatus: Int? = nil
    var diagnosticMessage: String? = nil
    var diagnosticText: LocalizedTextDescriptor? = nil

    init(
        remaining: Int,
        limit: Int,
        resetAt: Date?,
        planEndsAt: Date? = nil,
        planDisplayName: String? = nil,
        quotaLabel: String? = nil,
        quotaText: LocalizedTextDescriptor? = nil,
        quotaWindows: [QuotaWindowText] = [],
        httpStatus: Int? = nil,
        diagnosticMessage: String? = nil,
        diagnosticText: LocalizedTextDescriptor? = nil
    ) {
        self.remaining = remaining
        self.limit = limit
        self.resetAt = resetAt
        self.planEndsAt = planEndsAt
        self.planDisplayName = planDisplayName
        self.quotaLabel = quotaLabel
        self.quotaWindows = quotaWindows
        self.quotaText = quotaText
            ?? (!quotaWindows.isEmpty ? LocalizedTextDescriptor.quotaWindows(quotaWindows) : nil)
            ?? quotaLabel.flatMap(LocalizedTextDescriptor.fromLegacyLabel)
        self.httpStatus = httpStatus
        self.diagnosticMessage = diagnosticMessage
        self.diagnosticText = diagnosticText ?? diagnosticMessage.flatMap(LocalizedTextDescriptor.fromLegacyLabel)
    }
}

struct SubscriptionLifecycleInfo {
    var planEndsAt: Date?
    var planDisplayName: String?
}

struct ClaudeOrganizationContext {
    let id: String
    let planDisplayName: String?
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

    static func parseBraveHTTPResponse(
        statusCode: Int,
        limitHeader: String?,
        remainingHeader: String?,
        resetHeader: String?,
        policyHeader: String?,
        knownRemaining: Int?,
        knownLimit: Int?
    ) throws -> QuotaResult {
        if statusCode == 401 || statusCode == 403 {
            throw QuotaError.unauthorized
        }

        if statusCode == 422 {
            throw QuotaError.invalidAPIKey(statusCode: statusCode)
        }

        if statusCode == 429 {
            let resetAt = parseCommaSeparatedInts(resetHeader).last.map {
                Date(timeIntervalSinceNow: TimeInterval(max(0, $0)))
            }
            throw QuotaError.rateLimited(resetAt: resetAt)
        }

        if statusCode == 402 {
            return QuotaResult(
                remaining: 0,
                limit: max(knownLimit ?? 0, knownRemaining ?? 0),
                resetAt: nil,
                quotaLabel: "Usage limit exceeded",
                quotaText: LocalizedTextDescriptor.localized(.usageLimitExceeded),
                httpStatus: statusCode,
                diagnosticMessage: "Brave returned HTTP 402 usage limit exceeded.",
                diagnosticText: LocalizedTextDescriptor.localized(.braveUsageLimitDiagnostic)
            )
        }

        guard (200...299).contains(statusCode) else {
            throw QuotaError.invalidResponse
        }

        var result = try parseBraveRateLimit(
            limitHeader: limitHeader,
            remainingHeader: remainingHeader,
            resetHeader: resetHeader,
            policyHeader: policyHeader
        )
        result = applyKnownBraveMonthlyQuotaIfNeeded(
            result,
            knownRemaining: knownRemaining,
            knownLimit: knownLimit
        )
        result.httpStatus = statusCode
        if result.quotaLabel == "Search OK · monthly quota not exposed" {
            result.diagnosticMessage = "Search works, but Brave did not expose monthly quota for this key."
            result.diagnosticText = LocalizedTextDescriptor.localized(.braveQuotaUnknownDiagnostic)
        } else {
            result.diagnosticMessage = "Search works and Brave returned quota headers."
            result.diagnosticText = LocalizedTextDescriptor.localized(.braveQuotaHeadersDiagnostic)
        }
        return result
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
            planEndsAt: result.planEndsAt,
            planDisplayName: result.planDisplayName,
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

    static func parseExaUsage(_ data: Data) throws -> QuotaResult {
        struct UsageResponse: Decodable {
            let total_cost_usd: Double?
            let totalCostUsd: Double?

            var totalCost: Double? {
                total_cost_usd ?? totalCostUsd
            }
        }

        let usage = try JSONDecoder().decode(UsageResponse.self, from: data)
        guard let totalCost = usage.totalCost, totalCost >= 0 else {
            throw QuotaError.invalidResponse
        }

        return QuotaResult(
            remaining: Int.max,
            limit: Int.max,
            resetAt: nil,
            quotaLabel: "USD \(String(format: "%.2f", totalCost)) used"
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
            let paid_usage_month: FlexibleInt?
            let enterprise_usage_month: FlexibleInt?
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
        let paidUsageMonth = max(0, plan.paid_usage_month?.value ?? 0)
        let enterpriseUsageMonth = max(0, plan.enterprise_usage_month?.value ?? 0)
        let used = freeUsageMonth + paidUsageMonth + enterpriseUsageMonth + couponUsed

        guard couponQuota > 0 else {
            return QuotaResult(
                remaining: Int.max,
                limit: Int.max,
                resetAt: nil,
                quotaLabel: "\(used) monthly requests used",
                quotaText: .localized(.monthlyRequestsUsedFormat, String(used)),
                diagnosticMessage: "Querit account endpoint returned monthly usage, but no plan quota limit.",
                diagnosticText: .localized(.usableUnknownQuota)
            )
        }

        let limit = couponQuota
        let remaining = max(0, limit - couponUsed)

        return QuotaResult(
            remaining: remaining,
            limit: limit,
            resetAt: nil,
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

    static func parseXFYunCodingPlanList(_ data: Data, now: Date = Date()) throws -> QuotaResult {
        struct CodingPlanListResponse: Decodable {
            struct PageData: Decodable {
                let rows: [Plan]
            }

            struct Plan: Decodable {
                let name: String?
                let validFrom: String?
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

        let validFrom = parseLocalDateTime(plan.validFrom)
        let planEndsAt = parseLocalDateTime(plan.expiresAt)
        var windows: [(name: String, remaining: Int, limit: Int, resetAt: Date?)] = []
        func clampedReportedUsed(limit: Int, used: Int?) -> Int {
            min(limit, max(0, used ?? 0))
        }
        func clampedReportedRemaining(limit: Int, remaining: Int?) -> Int {
            min(limit, max(0, remaining ?? limit))
        }

        if let limit = usage.rp5hLimit, limit > 0 {
            let used = clampedReportedUsed(limit: limit, used: usage.rp5hUsage)
            windows.append((
                "5h",
                limit - used,
                limit,
                inferredXFYunWindowReset(startedAt: validFrom, interval: 5 * 60 * 60, now: now)
            ))
        }
        if let limit = usage.rpwLimit, limit > 0 {
            let used = clampedReportedUsed(limit: limit, used: usage.rpwUsage)
            windows.append((
                "week",
                limit - used,
                limit,
                inferredXFYunWindowReset(startedAt: validFrom, interval: 7 * 24 * 60 * 60, now: now)
            ))
        }
        if let limit = usage.packageLimit, limit > 0 {
            if let packageUsage = usage.packageUsage {
                let used = clampedReportedUsed(limit: limit, used: packageUsage)
                windows.append(("month", limit - used, limit, planEndsAt))
            } else {
                let remaining = clampedReportedRemaining(limit: limit, remaining: usage.packageLeft)
                windows.append(("month", remaining, limit, planEndsAt))
            }
        }

        guard !windows.isEmpty else {
            throw QuotaError.invalidResponse
        }

        let percentWindows = windows.map { window in
            PercentQuotaWindow(
                name: window.name,
                remainingPercent: Double(window.remaining) / Double(window.limit) * 100,
                resetAt: window.resetAt,
                remainingText: "\(window.remaining) / \(window.limit)"
            )
        }
        let label = percentWindows
            .map { window in "\(window.name) \(formatPercent(window.remainingPercent))" }
            .joined(separator: " · ")

        return percentQuotaResult(
            windows: percentWindows,
            planEndsAt: planEndsAt,
            planDisplayName: normalizedPlanDisplayName(plan.name),
            label: label
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

    static func parseVolcengineCodingPlanSubscription(_ data: Data) throws -> SubscriptionLifecycleInfo {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw QuotaError.invalidResponse
        }
        let result = object["Result"] as? [String: Any] ?? object
        let infoList = result["InfoList"] as? [[String: Any]]
            ?? result["infoList"] as? [[String: Any]]
            ?? result["items"] as? [[String: Any]]
            ?? result["data"] as? [[String: Any]]
            ?? []
        let codingPlanItems = infoList.filter { item in
            let resourceType = stringValue(item["ResourceType"] ?? item["resourceType"])?.lowercased()
            return resourceType == nil || resourceType == "codingplan"
        }
        guard let selected = codingPlanItems.first(where: { item in
            let status = stringValue(item["Status"] ?? item["status"])?.lowercased()
            return status == "running" || status == "active" || status == "valid"
        }) ?? codingPlanItems.first else {
            throw QuotaError.noSubscription
        }

        return SubscriptionLifecycleInfo(
            planEndsAt: firstDateValue(
                in: selected,
                keys: ["EndTime", "endTime", "ExpireTime", "expireTime", "expiresAt", "expires_at"]
            ),
            planDisplayName: planDisplayName(from: selected)
                ?? normalizedPlanDisplayName(stringValue(selected["BizInfo"] ?? selected["bizInfo"]))
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

    static func parseCodexWhamUsage(_ data: Data) throws -> QuotaResult {
        struct UsageResponse: Decodable {
            struct RateLimit: Decodable {
                let allowed: Bool?
                let limit_reached: Bool?
                let primary_window: UsageWindow?
                let secondary_window: UsageWindow?
            }

            struct UsageWindow: Decodable {
                let used_percent: Double?
                let limit_window_seconds: Int?
                let reset_after_seconds: Double?
                let reset_at: Double?
            }

            let rate_limit: RateLimit?
        }

        let response = try JSONDecoder().decode(UsageResponse.self, from: data)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let rateLimit = response.rate_limit else {
            throw QuotaError.invalidResponse
        }

        var windows: [PercentQuotaWindow] = []
        if let primaryWindow = rateLimit.primary_window {
            let windowName = quotaWindowName(seconds: primaryWindow.limit_window_seconds) ?? "5h"
            if let parsed = codexPercentQuotaWindow(
                name: windowName,
                usedPercent: primaryWindow.used_percent,
                resetAt: primaryWindow.reset_at,
                resetAfterSeconds: primaryWindow.reset_after_seconds
            ) {
                windows.append(parsed)
            }
        }
        if let secondaryWindow = rateLimit.secondary_window {
            let windowName = quotaWindowName(seconds: secondaryWindow.limit_window_seconds) ?? "week"
            if let parsed = codexPercentQuotaWindow(
                name: windowName,
                usedPercent: secondaryWindow.used_percent,
                resetAt: secondaryWindow.reset_at,
                resetAfterSeconds: secondaryWindow.reset_after_seconds
            ) {
                windows.append(parsed)
            }
        }

        guard !windows.isEmpty else {
            throw QuotaError.invalidResponse
        }

        let orderedWindows = orderPercentWindows(windows)
        return percentQuotaResult(
            windows: orderedWindows,
            planDisplayName: object.flatMap(planDisplayName),
            label: orderedWindows
                .map { window in "\(window.name) \(formatPercent(window.remainingPercent))" }
                .joined(separator: " · ")
        )
    }

    static func parseCodexSubscriptionLifecycle(_ data: Data) throws -> SubscriptionLifecycleInfo {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw QuotaError.invalidResponse
        }

        return SubscriptionLifecycleInfo(
            planEndsAt: firstDateValue(
                in: object,
                keys: [
                    "active_until",
                    "activeUntil",
                    "current_period_end",
                    "currentPeriodEnd",
                    "expires_at",
                    "expiresAt",
                ]
            ),
            planDisplayName: planDisplayName(from: object)
        )
    }

    static func parseClaudeOrganizationID(_ data: Data) throws -> String {
        try parseClaudeOrganizationContext(data).id
    }

    static func parseClaudeOrganizationContext(_ data: Data) throws -> ClaudeOrganizationContext {
        let object = try JSONSerialization.jsonObject(with: data)
        let candidates = claudeOrganizationCandidates(from: object)
        guard !candidates.isEmpty else {
            throw QuotaError.invalidResponse
        }

        let selected = candidates.first { $0.isActive == true }
            ?? candidates.first { $0.isDefault == true }
            ?? candidates.first
        guard let id = selected?.id, !id.isEmpty else {
            throw QuotaError.invalidResponse
        }

        return ClaudeOrganizationContext(
            id: id,
            planDisplayName: selected?.planDisplayName
        )
    }

    static func parseClaudeSubscriptionUsage(_ data: Data) throws -> QuotaResult {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw QuotaError.invalidResponse
        }

        let usage = object["usage"] as? [String: Any] ?? object
        let specs = [
            (field: "five_hour", name: "5h"),
            (field: "seven_day", name: "week"),
        ]
        let windows = specs.compactMap { spec -> PercentQuotaWindow? in
            guard let window = usage[spec.field] as? [String: Any],
                  let usedPercent = firstDoubleValue(
                    in: window,
                    keys: ["utilization", "used_percentage", "usedPercent"]
                  ) else {
                return nil
            }

            return PercentQuotaWindow(
                name: spec.name,
                remainingPercent: max(0, 100 - usedPercent),
                resetAt: firstDateValue(
                    in: window,
                    keys: ["resets_at", "reset_at", "resetsAt", "resetAt"]
                )
            )
        }

        guard !windows.isEmpty else {
            throw QuotaError.invalidResponse
        }

        let orderedWindows = orderPercentWindows(windows)
        return percentQuotaResult(
            windows: orderedWindows,
            planDisplayName: planDisplayName(from: object),
            label: orderedWindows
                .map { window in "\(window.name) \(formatPercent(window.remainingPercent))" }
                .joined(separator: " · ")
        )
    }

    static func parseClaudeSubscriptionDetails(_ data: Data) throws -> SubscriptionLifecycleInfo {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw QuotaError.invalidResponse
        }

        let nestedSubscription = object["subscription"] as? [String: Any]

        return SubscriptionLifecycleInfo(
            planEndsAt: firstDateValue(
                in: object,
                keys: [
                    "next_charge_at",
                    "next_charge_date",
                    "current_period_end",
                    "active_until",
                    "expires_at",
                    "ends_at",
                ]
            )
            ?? nestedSubscription.flatMap {
                firstDateValue(
                    in: $0,
                    keys: [
                        "next_charge_at",
                        "next_charge_date",
                        "current_period_end",
                        "active_until",
                        "expires_at",
                        "ends_at",
                    ]
                )
            },
            planDisplayName: planDisplayName(from: object)
                ?? nestedSubscription.flatMap(planDisplayName)
        )
    }

    static func parseKimiSubscriptionUsage(subscriptionData: Data, usageData: Data?) throws -> QuotaResult {
        guard let subscription = try JSONSerialization.jsonObject(with: subscriptionData) as? [String: Any] else {
            throw QuotaError.invalidResponse
        }
        let usage = try usageData.flatMap { data -> [String: Any]? in
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        }

        let planEndsAt = kimiPlanEndDate(from: subscription)
            ?? usage.flatMap(kimiPlanEndDate)
        let detectedPlanDisplayName = planDisplayName(from: subscription)
            ?? usage.flatMap { planDisplayName(from: $0) }

        var windows: [PercentQuotaWindow] = []
        if let usage {
            windows.append(contentsOf: kimiUsageWindows(from: usage))
        }
        if let balanceWindow = kimiSubscriptionBalanceWindow(from: subscription, planEndsAt: planEndsAt)
            ?? usage.flatMap({ kimiSubscriptionBalanceWindow(from: $0, planEndsAt: planEndsAt) }) {
            windows.append(balanceWindow)
        }

        if !windows.isEmpty {
            let orderedWindows = orderPercentWindows(windows)
            return percentQuotaResult(
                windows: orderedWindows,
                planEndsAt: planEndsAt,
                planDisplayName: detectedPlanDisplayName,
                label: orderedWindows
                    .map { window in "\(window.name) \(formatPercent(window.remainingPercent))" }
                    .joined(separator: " · ")
            )
        }

        if let subscribed = subscription["subscribed"] as? Bool, subscribed == false {
            throw QuotaError.noSubscription
        }

        return QuotaResult(
            remaining: Int.max,
            limit: Int.max,
            resetAt: nil,
            planEndsAt: planEndsAt,
            planDisplayName: detectedPlanDisplayName,
            quotaLabel: "Usable · quota unknown",
            quotaText: .localized(.usableUnknownQuota),
            diagnosticMessage: "Kimi membership endpoint returned subscription status, but quota was not exposed.",
            diagnosticText: .localized(.usableUnknownQuota)
        )
    }

    static func parseTencentCloudCodingPlanDescribePkg(_ data: Data) throws -> QuotaResult {
        struct ResponseEnvelope: Decodable {
            let code: Int?
            let mccode: Int?
            let msg: String?
            let uiMsg: String?
            let data: OuterData?
            let Response: ResponseBody?
        }

        struct OuterData: Decodable {
            let code: Int?
            let cgwerrorCode: Int?
            let msg: String?
            let uiMsg: String?
            let data: InnerData?
            let Response: ResponseBody?
        }

        struct InnerData: Decodable {
            let Response: ResponseBody?
        }

        struct ResponseBody: Decodable {
            let Error: TencentCloudError?
            let PkgList: [Package]?
            let TotalCount: FlexibleDouble?
        }

        struct TencentCloudError: Decodable {
            let Code: String?
            let Message: String?
        }

        struct Package: Decodable {
            let PkgName: String?
            let PackageName: String?
            let Name: String?
            let ResourceName: String?
            let ProductName: String?
            let Title: String?
            let Status: String?
            let EndTime: String?
            let RemainingDays: Int?
            let UsageDetail: UsageDetail?
        }

        struct UsageDetail: Decodable {
            let PerFiveHour: UsageWindow?
            let PerWeek: UsageWindow?
            let PerMonth: UsageWindow?
        }

        struct UsageWindow: Decodable {
            let Used: FlexibleDouble?
            let Total: FlexibleDouble?
            let UsagePercent: FlexibleDouble?
            let EndTime: String?
        }

        struct FlexibleDouble: Decodable {
            let value: Double

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let double = try? container.decode(Double.self) {
                    value = double
                } else if let int = try? container.decode(Int.self) {
                    value = Double(int)
                } else if let string = try? container.decode(String.self),
                          let double = Double(string) {
                    value = double
                } else {
                    throw QuotaError.invalidResponse
                }
            }
        }

        let envelope = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        if let code = envelope.code, code != 0 {
            if isTencentCloudUnauthorized(code: code, message: envelope.msg ?? envelope.uiMsg) {
                throw QuotaError.unauthorized
            }
            throw QuotaError.invalidResponse
        }
        if let mccode = envelope.mccode, mccode != 0 {
            if isTencentCloudUnauthorized(code: mccode, message: envelope.msg ?? envelope.uiMsg) {
                throw QuotaError.unauthorized
            }
            throw QuotaError.invalidResponse
        }
        if let code = envelope.data?.code, code != 0 {
            if isTencentCloudUnauthorized(code: code, message: envelope.data?.msg ?? envelope.data?.uiMsg) {
                throw QuotaError.unauthorized
            }
            throw QuotaError.invalidResponse
        }
        if let cgwerrorCode = envelope.data?.cgwerrorCode, cgwerrorCode != 0 {
            if isTencentCloudUnauthorized(code: cgwerrorCode, message: envelope.data?.msg ?? envelope.data?.uiMsg) {
                throw QuotaError.unauthorized
            }
            throw QuotaError.invalidResponse
        }

        let response = envelope.data?.data?.Response
            ?? envelope.data?.Response
            ?? envelope.Response
        guard let response else {
            throw QuotaError.invalidResponse
        }
        if response.Error != nil {
            throw QuotaError.invalidResponse
        }

        guard let packages = response.PkgList else {
            if response.TotalCount?.value == 0 {
                throw QuotaError.noSubscription
            }
            throw QuotaError.invalidResponse
        }
        guard !packages.isEmpty else {
            throw QuotaError.noSubscription
        }

        let package = packages.first {
            $0.Status?.localizedCaseInsensitiveContains("normal") == true && $0.UsageDetail != nil
        } ?? packages.first { $0.UsageDetail != nil }
        guard let usage = package?.UsageDetail else {
            throw QuotaError.invalidResponse
        }

        let windowSpecs: [(name: String, usage: UsageWindow?)] = [
            ("5h", usage.PerFiveHour),
            ("week", usage.PerWeek),
            ("month", usage.PerMonth),
        ]
        let windows = windowSpecs.compactMap { spec -> PercentQuotaWindow? in
            guard let usage = spec.usage else { return nil }
            let remainingPercent: Double
            let remainingText: String?
            if let usagePercent = usage.UsagePercent?.value {
                remainingPercent = max(0, 100 - usagePercent)
                if let used = usage.Used?.value,
                   let total = usage.Total?.value,
                   total > 0 {
                    remainingText = "\(Int(max(0, total - used).rounded(.down))) / \(Int(total.rounded(.down)))"
                } else {
                    remainingText = nil
                }
            } else if let used = usage.Used?.value,
                      let total = usage.Total?.value,
                      total > 0 {
                remainingPercent = max(0, (total - used) / total * 100)
                remainingText = "\(Int(max(0, total - used).rounded(.down))) / \(Int(total.rounded(.down)))"
            } else {
                return nil
            }

            return PercentQuotaWindow(
                name: spec.name,
                remainingPercent: remainingPercent,
                resetAt: parseLocalDateTime(usage.EndTime),
                remainingText: remainingText
            )
        }

        guard !windows.isEmpty else {
            throw QuotaError.invalidResponse
        }

        let orderedWindows = orderPercentWindows(windows)
        let planDisplayName = package.flatMap {
            normalizedPlanDisplayName(
                $0.PkgName
                    ?? $0.PackageName
                    ?? $0.Name
                    ?? $0.ResourceName
                    ?? $0.ProductName
                    ?? $0.Title
            )
        }
        return percentQuotaResult(
            windows: orderedWindows,
            planEndsAt: parseLocalDateTime(package?.EndTime),
            planDisplayName: planDisplayName,
            label: orderedWindows
                .map { window in "\(window.name) \(formatPercent(window.remainingPercent))" }
                .joined(separator: " · ")
        )
    }

    private static func isTencentCloudUnauthorized(code: Int, message: String?) -> Bool {
        guard code == 7 || code == 401 || code == 403 else { return false }
        let normalizedMessage = message?.lowercased() ?? ""
        return normalizedMessage.isEmpty
            || normalizedMessage.contains("uin_or_skey_missing")
            || normalizedMessage.contains("login")
            || normalizedMessage.contains("unauthorized")
            || normalizedMessage.contains("登录")
            || normalizedMessage.contains("重新登录")
    }

    static func parseAliyunCodingPlanStatus(_ data: Data) throws -> QuotaResult {
        guard let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw QuotaError.invalidResponse
        }

        if let code = envelope["code"] {
            let codeString = String(describing: code)
            guard codeString == "200" || codeString == "0" else {
                throw QuotaError.invalidResponse
            }
        }

        guard let payload = aliyunDataPayload(from: envelope) else {
            throw QuotaError.invalidResponse
        }

        if let instanceInfos = payload["codingPlanInstanceInfos"] as? [[String: Any]] {
            return try parseAliyunCodingPlanInstanceInfos(instanceInfos)
        }

        if let hasCodingPlan = payload["hasCodingPlan"] as? Bool,
           !hasCodingPlan {
            throw QuotaError.noSubscription
        }

        guard let codingPlanInfo = payload["codingPlanInfo"] as? [String: Any] else {
            throw QuotaError.invalidResponse
        }

        let status = stringValue(codingPlanInfo["status"])?.uppercased()
        if status == "INVALID" {
            throw QuotaError.noSubscription
        }

        if let windows = aliyunCodingPlanUsageWindows(from: codingPlanInfo),
           !windows.isEmpty {
            let orderedWindows = orderPercentWindows(windows)
            return percentQuotaResult(
                windows: orderedWindows,
                planEndsAt: aliyunTimestampDate(codingPlanInfo["endTime"]),
                planDisplayName: planDisplayName(from: codingPlanInfo),
                label: orderedWindows
                    .map { window in "\(window.name) \(formatPercent(window.remainingPercent))" }
                    .joined(separator: " · ")
            )
        }

        return QuotaResult(
            remaining: Int.max,
            limit: Int.max,
            resetAt: nil,
            planEndsAt: aliyunTimestampDate(codingPlanInfo["endTime"]),
            planDisplayName: planDisplayName(from: codingPlanInfo),
            quotaLabel: "Usable · quota unknown",
            quotaText: .localized(.usableUnknownQuota),
            diagnosticMessage: "Aliyun Coding Plan returned subscription status, but usage quota was not exposed.",
            diagnosticText: .localized(.usableUnknownQuota)
        )
    }

    private static func parseAliyunCodingPlanInstanceInfos(_ instanceInfos: [[String: Any]]) throws -> QuotaResult {
        guard !instanceInfos.isEmpty else {
            throw QuotaError.noSubscription
        }

        let usableInstances = instanceInfos.filter { instance in
            guard let status = stringValue(instance["status"])?.uppercased() else {
                return true
            }
            return ["VALID", "NORMAL", "ACTIVE"].contains(status)
        }

        guard let selected = usableInstances.first(where: { aliyunCodingPlanQuotaInfo(from: $0) != nil }) ?? usableInstances.first else {
            throw QuotaError.noSubscription
        }

        guard let quotaInfo = aliyunCodingPlanQuotaInfo(from: selected) else {
            throw QuotaError.invalidResponse
        }

        let windows = aliyunCodingPlanInstanceWindows(from: quotaInfo)
        guard !windows.isEmpty else {
            throw QuotaError.invalidResponse
        }

        let orderedWindows = orderPercentWindows(windows)
        return percentQuotaResult(
            windows: orderedWindows,
            planEndsAt: aliyunTimestampDate(
                selected["instanceEndTime"]
                    ?? selected["endTime"]
                    ?? selected["EndTime"]
                    ?? selected["expireTime"]
                    ?? selected["expirationTime"]
            ),
            planDisplayName: planDisplayName(from: selected),
            label: orderedWindows
                .map { window in "\(window.name) \(formatPercent(window.remainingPercent))" }
                .joined(separator: " · ")
        )
    }

    static func parseTencentCloudTokenPlanApiKey(_ data: Data) throws -> QuotaResult {
        struct ResponseEnvelope: Decodable {
            let Response: ResponseBody
        }

        struct ResponseBody: Decodable {
            let Balance: Balance?
            let Error: TencentCloudError?
        }

        struct TencentCloudError: Decodable {
            let Code: String
            let Message: String
        }

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

        struct Balance: Decodable {
            let ExclusiveQuota: FlexibleInt?
            let ExclusiveRemain: FlexibleInt?
            let SharedQuota: FlexibleInt?
            let SharedRemain: FlexibleInt?
            let Status: Int?
        }

        let envelope = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        if envelope.Response.Error != nil {
            throw QuotaError.invalidResponse
        }
        guard let balance = envelope.Response.Balance else {
            throw QuotaError.invalidResponse
        }

        let exclusiveQuota = max(0, balance.ExclusiveQuota?.value ?? 0)
        let exclusiveRemain = max(0, balance.ExclusiveRemain?.value ?? 0)
        let sharedQuota = max(0, balance.SharedQuota?.value ?? 0)
        let sharedRemain = max(0, balance.SharedRemain?.value ?? 0)
        let limit = exclusiveQuota + sharedQuota
        let remaining = exclusiveRemain + sharedRemain

        guard limit > 0 || remaining > 0 else {
            throw QuotaError.invalidResponse
        }

        return QuotaResult(
            remaining: remaining,
            limit: max(limit, remaining),
            resetAt: nil,
            quotaLabel: "\(remaining) / \(max(limit, remaining)) tokens"
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
        var remainingText: String? = nil
    }

    private static func percentQuotaResult(
        windows: [PercentQuotaWindow],
        planEndsAt: Date? = nil,
        planDisplayName: String? = nil,
        label: String
    ) -> QuotaResult {
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
            planEndsAt: planEndsAt,
            planDisplayName: planDisplayName,
            quotaLabel: label,
            quotaWindows: orderPercentWindows(windows).map(quotaWindowText)
        )
    }

    private static func quotaWindowText(_ window: PercentQuotaWindow) -> QuotaWindowText {
        QuotaWindowText(
            name: window.name,
            percentText: formatPercent(window.remainingPercent),
            resetAt: window.resetAt,
            remainingText: window.remainingText
        )
    }

    private static func codexPercentQuotaWindow(
        name: String,
        usedPercent: Double?,
        resetAt: Double?,
        resetAfterSeconds: Double?
    ) -> PercentQuotaWindow? {
        guard let usedPercent else { return nil }
        let resetDate: Date?
        if let resetAt, resetAt > 0 {
            resetDate = Date(timeIntervalSince1970: resetAt)
        } else if let resetAfterSeconds, resetAfterSeconds > 0 {
            resetDate = Date(timeIntervalSinceNow: resetAfterSeconds)
        } else {
            resetDate = nil
        }
        return PercentQuotaWindow(
            name: name,
            remainingPercent: max(0, 100 - usedPercent),
            resetAt: resetDate
        )
    }

    private static func quotaWindowName(seconds: Int?) -> String? {
        guard let seconds else { return nil }
        switch seconds {
        case 18_000:
            return "5h"
        case 604_800:
            return "week"
        case 2_419_200...2_678_400:
            return "month"
        default:
            return nil
        }
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

    private static func inferredXFYunWindowReset(
        startedAt start: Date?,
        interval: TimeInterval,
        now: Date
    ) -> Date? {
        guard let start, interval > 0 else { return nil }
        if now < start {
            return start
        }

        let elapsed = now.timeIntervalSince(start)
        let completedWindows = floor(elapsed / interval) + 1
        return start.addingTimeInterval(completedWindows * interval)
    }

    private static func parseISO8601Date(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) {
            return date
        }

        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dayFormatter.dateFormat = "yyyy-MM-dd"
        return dayFormatter.date(from: value)
    }

    private static func aliyunDataPayload(from envelope: [String: Any]) -> [String: Any]? {
        if let hasCodingPlan = envelope["hasCodingPlan"] as? Bool {
            return hasCodingPlan || envelope["codingPlanInfo"] != nil ? envelope : nil
        }

        let data = envelope["data"] as? [String: Any]
        let dataV2 = data?["DataV2"] as? [String: Any]
        let inner = dataV2?["data"] as? [String: Any]
        if let success = inner?["success"] as? Bool,
           !success {
            return nil
        }
        return inner?["data"] as? [String: Any]
    }

    private static func aliyunCodingPlanUsageWindows(from codingPlanInfo: [String: Any]) -> [PercentQuotaWindow]? {
        let usageContainers = [
            codingPlanInfo["usageDetail"],
            codingPlanInfo["usage"],
            codingPlanInfo["quotaUsage"],
            codingPlanInfo["codingPlanUsageDTO"],
            codingPlanInfo["codingPlanUsage"],
        ].compactMap { $0 as? [String: Any] }

        let sources = usageContainers.isEmpty ? [codingPlanInfo] : usageContainers
        for source in sources {
            let windows = [
                aliyunCodingPlanWindow(
                    name: "5h",
                    source: source,
                    objectKeys: ["perFiveHour", "PerFiveHour", "rp5h", "fiveHour", "five_hour", "rolling"],
                    leftKeys: ["rp5hLeft", "rp5hRemaining", "perFiveHourLeft", "fiveHourLeft"],
                    limitKeys: ["rp5hLimit", "perFiveHourLimit", "fiveHourLimit"],
                    usageKeys: ["rp5hUsage", "perFiveHourUsage", "fiveHourUsage"]
                ),
                aliyunCodingPlanWindow(
                    name: "week",
                    source: source,
                    objectKeys: ["perWeek", "PerWeek", "rpw", "week", "weekly"],
                    leftKeys: ["rpwLeft", "rpwRemaining", "perWeekLeft", "weekLeft", "weeklyLeft"],
                    limitKeys: ["rpwLimit", "perWeekLimit", "weekLimit", "weeklyLimit"],
                    usageKeys: ["rpwUsage", "perWeekUsage", "weekUsage", "weeklyUsage"]
                ),
                aliyunCodingPlanWindow(
                    name: "month",
                    source: source,
                    objectKeys: ["perMonth", "PerMonth", "package", "month", "monthly"],
                    leftKeys: ["packageLeft", "packageRemaining", "perMonthLeft", "monthLeft", "monthlyLeft"],
                    limitKeys: ["packageLimit", "perMonthLimit", "monthLimit", "monthlyLimit"],
                    usageKeys: ["packageUsage", "perMonthUsage", "monthUsage", "monthlyUsage"]
                ),
            ].compactMap { $0 }

            if !windows.isEmpty {
                return windows
            }
        }

        return nil
    }

    private static func aliyunCodingPlanQuotaInfo(from instance: [String: Any]) -> [String: Any]? {
        firstDictionary(
            in: instance,
            keys: [
                "codingPlanQuotaInfo",
                "quotaInfo",
                "usageDetail",
                "codingPlanUsageDTO",
                "codingPlanUsage",
            ]
        )
    }

    private static func aliyunCodingPlanInstanceWindows(from quotaInfo: [String: Any]) -> [PercentQuotaWindow] {
        [
            aliyunCodingPlanFlatWindow(
                name: "5h",
                source: quotaInfo,
                usedKeys: ["per5HourUsedQuota", "perFiveHourUsedQuota", "rp5hUsage", "perFiveHourUsage", "fiveHourUsage"],
                totalKeys: ["per5HourTotalQuota", "perFiveHourTotalQuota", "rp5hLimit", "perFiveHourLimit", "fiveHourLimit"],
                resetKeys: ["per5HourQuotaNextRefreshTime", "perFiveHourQuotaNextRefreshTime", "rp5hNextRefreshTime", "perFiveHourNextRefreshTime"]
            ),
            aliyunCodingPlanFlatWindow(
                name: "week",
                source: quotaInfo,
                usedKeys: ["perWeekUsedQuota", "rpwUsage", "perWeekUsage", "weekUsage", "weeklyUsage"],
                totalKeys: ["perWeekTotalQuota", "rpwLimit", "perWeekLimit", "weekLimit", "weeklyLimit"],
                resetKeys: ["perWeekQuotaNextRefreshTime", "rpwNextRefreshTime", "perWeekNextRefreshTime", "weekNextRefreshTime"]
            ),
            aliyunCodingPlanFlatWindow(
                name: "month",
                source: quotaInfo,
                usedKeys: ["perBillMonthUsedQuota", "perMonthUsedQuota", "packageUsage", "perMonthUsage", "monthUsage", "monthlyUsage"],
                totalKeys: ["perBillMonthTotalQuota", "perMonthTotalQuota", "packageLimit", "perMonthLimit", "monthLimit", "monthlyLimit"],
                resetKeys: ["perBillMonthQuotaNextRefreshTime", "perMonthQuotaNextRefreshTime", "packageNextRefreshTime", "monthNextRefreshTime"]
            ),
        ].compactMap { $0 }
    }

    private static func aliyunCodingPlanFlatWindow(
        name: String,
        source: [String: Any],
        usedKeys: [String],
        totalKeys: [String],
        resetKeys: [String]
    ) -> PercentQuotaWindow? {
        guard let total = firstDoubleValue(in: source, keys: totalKeys),
              total > 0 else {
            return nil
        }

        let used = firstDoubleValue(in: source, keys: usedKeys) ?? 0
        let remaining = max(0, total - used)
        return PercentQuotaWindow(
            name: name,
            remainingPercent: remaining / total * 100,
            resetAt: firstTimestampDate(in: source, keys: resetKeys),
            remainingText: "\(Int(remaining.rounded(.down))) / \(Int(total.rounded(.down)))"
        )
    }

    private static func aliyunCodingPlanWindow(
        name: String,
        source: [String: Any],
        objectKeys: [String],
        leftKeys: [String],
        limitKeys: [String],
        usageKeys: [String]
    ) -> PercentQuotaWindow? {
        let object = firstDictionary(in: source, keys: objectKeys)
        let limit = firstDoubleValue(in: object ?? source, keys: ["total", "Total", "limit", "Limit", "quota", "Quota"] + limitKeys)
        guard let limit, limit > 0 else { return nil }

        let used = firstDoubleValue(in: object ?? source, keys: ["used", "Used", "usage", "Usage"] + usageKeys)
        let explicitLeft = firstDoubleValue(in: object ?? source, keys: ["left", "Left", "remaining", "Remaining", "remain", "Remain"] + leftKeys)
        let remaining = explicitLeft ?? (limit - (used ?? 0))
        let safeRemaining = max(0, remaining)

        return PercentQuotaWindow(
            name: name,
            remainingPercent: safeRemaining / limit * 100,
            resetAt: nil,
            remainingText: "\(Int(safeRemaining.rounded(.down))) / \(Int(limit.rounded(.down)))"
        )
    }

    private static func kimiPlanEndDate(from object: [String: Any]) -> Date? {
        firstDateValue(
            in: object,
            keys: [
                "next_billing_time",
                "nextBillingTime",
                "expire_time",
                "expireTime",
                "expires_at",
                "expiresAt",
                "end_time",
                "endTime",
            ]
        )
        ?? firstDictionary(in: object, keys: ["subscription", "purchase_subscription", "purchaseSubscription"]).flatMap(kimiPlanEndDate)
        ?? (object["balances"] as? [[String: Any]])?.compactMap { balance in
            firstDateValue(in: balance, keys: ["expire_time", "expireTime", "upcoming_expiration", "upcomingExpiration"])
        }.first
        ?? firstDictionary(in: object, keys: ["subscription_balance", "subscriptionBalance"]).flatMap { balance in
            firstDateValue(in: balance, keys: ["expire_time", "expireTime", "upcoming_expiration", "upcomingExpiration"])
        }
    }

    private static func kimiRateLimitWindows(from object: [String: Any]) -> [PercentQuotaWindow] {
        [
            firstKimiRateLimitWindow(
                name: "5h",
                object: object,
                primaryKeys: ["ratelimit_5h", "rate_limit_5h", "rateLimit5h", "ratelimit5h"],
                fallbackKeys: ["ratelimit_code_5h", "rate_limit_code_5h", "rateLimitCode5h", "ratelimitCode5h"]
            ),
            firstKimiRateLimitWindow(
                name: "week",
                object: object,
                primaryKeys: ["ratelimit_7d", "rate_limit_7d", "rateLimit7d", "ratelimit7d"],
                fallbackKeys: ["ratelimit_code_7d", "rate_limit_code_7d", "rateLimitCode7d", "ratelimitCode7d"]
            ),
        ].compactMap { $0 }
    }

    private static func kimiUsageWindows(from object: [String: Any]) -> [PercentQuotaWindow] {
        var windows: [PercentQuotaWindow] = []

        if let summary = firstDictionary(in: object, keys: ["usage", "detail"]) {
            if let window = kimiUsageDetailWindow(name: "week", source: summary) {
                windows.append(window)
            }
        }

        if let limits = object["limits"] as? [[String: Any]] {
            windows.append(contentsOf: limits.compactMap(kimiUsageLimitWindow))
        }

        if let usages = object["usages"] as? [[String: Any]] {
            let selected = usages.first { usage in
                stringValue(usage["scope"])?.uppercased() == "FEATURE_CODING"
            } ?? usages.first

            if let selected {
                if let detail = firstDictionary(in: selected, keys: ["detail", "usage"]),
                   let window = kimiUsageDetailWindow(name: "week", source: detail) {
                    windows.append(window)
                }
                if let limits = selected["limits"] as? [[String: Any]] {
                    windows.append(contentsOf: limits.compactMap(kimiUsageLimitWindow))
                }
            }
        }

        if windows.isEmpty {
            windows.append(contentsOf: kimiRateLimitWindows(from: object))
        }

        var seen = Set<String>()
        return windows.filter { window in
            seen.insert(window.name).inserted
        }
    }

    private static func kimiUsageLimitWindow(from item: [String: Any]) -> PercentQuotaWindow? {
        let detail = firstDictionary(in: item, keys: ["detail", "usage"]) ?? item
        let window = firstDictionary(in: item, keys: ["window"]) ?? [:]
        let name = kimiUsageWindowName(item: item, detail: detail, window: window)
        return kimiUsageDetailWindow(name: name, source: detail)
    }

    private static func kimiUsageDetailWindow(name: String, source: [String: Any]) -> PercentQuotaWindow? {
        guard let limit = firstDoubleValue(in: source, keys: ["limit", "total", "quota", "amount"]),
              limit > 0 else {
            return nil
        }
        let remaining = firstDoubleValue(in: source, keys: ["remaining", "remain", "left", "amountLeft", "amount_left"])
            ?? firstDoubleValue(in: source, keys: ["used", "usage", "amountUsed"]).map { max(0, limit - $0) }
        guard let remaining else {
            return nil
        }
        let safeRemaining = max(0, min(limit, remaining))
        return PercentQuotaWindow(
            name: name,
            remainingPercent: safeRemaining / limit * 100,
            resetAt: firstDateValue(
                in: source,
                keys: ["resetTime", "resetAt", "reset_time", "reset_at"]
            ),
            remainingText: "\(compactNumber(safeRemaining)) / \(compactNumber(limit))"
        )
    }

    private static func kimiUsageWindowName(
        item: [String: Any],
        detail: [String: Any],
        window: [String: Any]
    ) -> String {
        for source in [item, detail] {
            for key in ["name", "title", "scope"] {
                if let normalized = normalizedKimiUsageWindowName(stringValue(source[key])) {
                    return normalized
                }
            }
        }

        let duration = firstDoubleValue(in: window, keys: ["duration"])
            ?? firstDoubleValue(in: item, keys: ["duration"])
            ?? firstDoubleValue(in: detail, keys: ["duration"])
        let unit = (
            stringValue(window["timeUnit"])
            ?? stringValue(item["timeUnit"])
            ?? stringValue(detail["timeUnit"])
            ?? ""
        ).uppercased()

        guard let duration else { return "week" }
        if unit.contains("MINUTE") {
            if duration == 300 { return "5h" }
            if duration >= 10_000 && duration <= 10_200 { return "week" }
            if duration >= 40_000 && duration <= 45_000 { return "month" }
        }
        if unit.contains("HOUR") {
            if duration == 5 { return "5h" }
            if duration == 168 { return "week" }
            if duration >= 672 && duration <= 744 { return "month" }
        }
        if unit.contains("DAY") {
            if duration == 7 { return "week" }
            if duration >= 28 && duration <= 31 { return "month" }
        }
        if unit.contains("SECOND"), let name = quotaWindowName(seconds: Int(duration)) {
            return name
        }
        return "week"
    }

    private static func normalizedKimiUsageWindowName(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains("5h") || normalized.contains("five") || normalized.contains("300") {
            return "5h"
        }
        if normalized.contains("week") || normalized.contains("weekly") || normalized.contains("7d") {
            return "week"
        }
        if normalized.contains("month") || normalized.contains("monthly") {
            return "month"
        }
        return nil
    }

    private static func firstKimiRateLimitWindow(
        name: String,
        object: [String: Any],
        primaryKeys: [String],
        fallbackKeys: [String]
    ) -> PercentQuotaWindow? {
        let source = firstDictionary(in: object, keys: primaryKeys)
            ?? firstDictionary(in: object, keys: fallbackKeys)
        return source.flatMap { kimiRateLimitWindow(name: name, source: $0) }
    }

    private static func kimiRateLimitWindow(name: String, source: [String: Any]) -> PercentQuotaWindow? {
        if let enabled = boolValue(source["enabled"]), !enabled {
            return nil
        }
        guard let ratio = firstDoubleValue(
            in: source,
            keys: ["ratio", "used_ratio", "usedRatio", "usage_ratio", "usageRatio", "utilization"]
        ) else {
            return nil
        }

        return PercentQuotaWindow(
            name: name,
            remainingPercent: max(0, 100 - normalizedKimiUsedPercent(ratio)),
            resetAt: firstDateValue(in: source, keys: ["reset_time", "resetTime", "reset_at", "resetAt"])
        )
    }

    private static func kimiSubscriptionBalanceWindow(from object: [String: Any], planEndsAt: Date?) -> PercentQuotaWindow? {
        if let balance = firstDictionary(in: object, keys: ["subscription_balance", "subscriptionBalance", "creditBalance"]) {
            return kimiBalanceWindow(from: balance, planEndsAt: planEndsAt)
        }

        guard let balances = object["balances"] as? [[String: Any]] else {
            return nil
        }
        let selected = balances.first { balance in
            let type = stringValue(balance["type"])?.lowercased() ?? ""
            return type.contains("subscription") && firstDoubleValue(in: balance, keys: ["amount", "total", "quota", "limit"]) != nil
        }
        ?? balances.first { firstDoubleValue(in: $0, keys: ["amount", "total", "quota", "limit"]) != nil }

        return selected.flatMap { kimiBalanceWindow(from: $0, planEndsAt: planEndsAt) }
    }

    private static func kimiBalanceWindow(from source: [String: Any], planEndsAt: Date?) -> PercentQuotaWindow? {
        let amount = firstDoubleValue(in: source, keys: ["amount", "total", "quota", "limit"])
        let amountLeft = firstDoubleValue(
            in: source,
            keys: ["amount_left", "amountLeft", "left", "remaining", "remain"]
        )
        let usedRatio = firstDoubleValue(
            in: source,
            keys: ["amount_used_ratio", "amountUsedRatio", "used_ratio", "usedRatio", "usage_ratio", "usageRatio"]
        )

        let remainingPercent: Double
        let remainingText: String?
        if let amount, amount > 0 {
            let remaining = amountLeft ?? usedRatio.map { amount * max(0, 1 - normalizedKimiUsedPercent($0) / 100) }
            guard let remaining else { return nil }
            remainingPercent = max(0, remaining / amount * 100)
            remainingText = "\(compactNumber(remaining)) / \(compactNumber(amount))"
        } else if let usedRatio {
            remainingPercent = max(0, 100 - normalizedKimiUsedPercent(usedRatio))
            remainingText = nil
        } else {
            return nil
        }

        return PercentQuotaWindow(
            name: "month",
            remainingPercent: remainingPercent,
            resetAt: firstDateValue(
                in: source,
                keys: ["reset_time", "resetTime", "expire_time", "expireTime", "upcoming_expiration", "upcomingExpiration"]
            ) ?? planEndsAt,
            remainingText: remainingText
        )
    }

    private static func normalizedKimiUsedPercent(_ ratio: Double) -> Double {
        abs(ratio) <= 1 ? ratio * 100 : ratio
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        if let bool = value as? Bool {
            return bool
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        if let string = value as? String {
            switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1", "yes":
                return true
            case "false", "0", "no":
                return false
            default:
                return nil
            }
        }
        return nil
    }

    private static func compactNumber(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.0001 {
            return "\(Int(rounded))"
        }
        return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func firstDictionary(in source: [String: Any], keys: [String]) -> [String: Any]? {
        for key in keys {
            if let value = source[key] as? [String: Any] {
                return value
            }
        }
        return nil
    }

    private static func firstTimestampDate(in source: [String: Any], keys: [String]) -> Date? {
        for key in keys {
            if let date = aliyunTimestampDate(source[key]) {
                return date
            }
        }
        return nil
    }

    private static func firstDoubleValue(in source: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = doubleValue(source[key]) {
                return value
            }
        }
        return nil
    }

    private static func aliyunTimestampDate(_ value: Any?) -> Date? {
        let numericValue: Double?
        numericValue = doubleValue(value)

        guard let numericValue, numericValue > 0 else {
            return nil
        }
        let seconds = numericValue > 10_000_000_000 ? numericValue / 1000 : numericValue
        return Date(timeIntervalSince1970: seconds)
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let string = value as? String {
            return Double(string)
        }
        return nil
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let string = value as? String {
            return string
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    private static func planDisplayName(from source: [String: Any]) -> String? {
        let nameKeys = [
            "planDisplayName",
            "plan_display_name",
            "displayName",
            "display_name",
            "planName",
            "plan_name",
            "planType",
            "plan_type",
            "subscriptionType",
            "subscription_type",
            "tier",
            "tierName",
            "tier_name",
            "packageName",
            "package_name",
            "pkgName",
            "PkgName",
            "Name",
            "name",
            "title",
            "Title",
            "productName",
            "product_name",
            "commodityName",
            "commodity_name",
            "goodsName",
            "goods_name",
            "membershipName",
            "membership_name",
            "instanceName",
            "instance_name",
            "instanceType",
            "instance_type",
        ]
        for key in nameKeys {
            if let value = normalizedPlanDisplayName(stringValue(source[key])) {
                return value
            }
        }

        let nestedKeys = [
            "subscription",
            "plan",
            "package",
            "pkg",
            "goods",
            "product",
            "membership",
            "current_plan",
            "currentPlan",
            "codingPlanInfo",
        ]
        for key in nestedKeys {
            if let nested = source[key] as? [String: Any],
               let value = planDisplayName(from: nested) {
                return value
            }
        }
        return nil
    }

    private static func normalizedPlanDisplayName(_ value: String?) -> String? {
        guard let value else { return nil }
        let collapsed = value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty, collapsed.count <= 80 else { return nil }
        let lowercased = collapsed.lowercased()
        let canonicalPlanNames = [
            "free": "Free",
            "lite": "Lite",
            "plus": "Plus",
            "pro": "Pro",
            "max": "Max",
            "team": "Team",
            "business": "Business",
            "enterprise": "Enterprise",
            "starter": "Starter",
            "standard": "Standard",
            "premium": "Premium",
            "ultra": "Ultra",
        ]
        if let canonicalPlanName = canonicalPlanNames[lowercased] {
            return canonicalPlanName
        }
        guard !["normal", "valid", "active", "invalid", "true", "false"].contains(lowercased) else {
            return nil
        }
        guard collapsed.range(of: #"^\d+$"#, options: .regularExpression) == nil else {
            return nil
        }
        return collapsed
    }

    private struct ClaudeOrganizationCandidate {
        let id: String?
        let isActive: Bool?
        let isDefault: Bool?
        let planDisplayName: String?
    }

    private static func claudeOrganizationCandidates(from object: Any) -> [ClaudeOrganizationCandidate] {
        if let organizations = object as? [[String: Any]] {
            return organizations.flatMap(claudeOrganizationCandidates)
        }

        guard let dictionary = object as? [String: Any] else {
            return []
        }

        let id = stringValue(dictionary["uuid"])
            ?? stringValue(dictionary["id"])
            ?? stringValue(dictionary["organization_uuid"])
            ?? stringValue(dictionary["organizationUuid"])
        var candidates: [ClaudeOrganizationCandidate] = []
        if id != nil {
            candidates.append(
                ClaudeOrganizationCandidate(
                    id: id,
                    isActive: dictionary["active"] as? Bool ?? dictionary["is_active"] as? Bool,
                    isDefault: dictionary["default"] as? Bool ?? dictionary["is_default"] as? Bool,
                    planDisplayName: claudeOrganizationPlanDisplayName(from: dictionary)
                )
            )
        }

        for key in ["organizations", "data", "results", "items"] {
            if let nested = dictionary[key] {
                candidates.append(contentsOf: claudeOrganizationCandidates(from: nested))
            }
        }

        return candidates
    }

    private static func claudeOrganizationPlanDisplayName(from source: [String: Any]) -> String? {
        if let capabilities = source["capabilities"] as? [Any] {
            let capabilityNames = capabilities.compactMap(stringValue).map { $0.lowercased() }
            let capabilityPlans = [
                "claude_pro": "Pro",
                "claude_max": "Max",
                "claude_team": "Team",
                "claude_enterprise": "Enterprise",
            ]
            for capabilityName in capabilityNames {
                if let plan = capabilityPlans[capabilityName] {
                    return plan
                }
            }
        }

        let planKeys = [
            "planDisplayName",
            "plan_display_name",
            "planName",
            "plan_name",
            "planType",
            "plan_type",
            "subscriptionType",
            "subscription_type",
            "tier",
            "tierName",
            "tier_name",
        ]
        for key in planKeys {
            if let value = normalizedPlanDisplayName(stringValue(source[key])) {
                return value
            }
        }
        return nil
    }

    private static func firstDateValue(in source: [String: Any], keys: [String]) -> Date? {
        for key in keys {
            if let date = dateValue(source[key]) {
                return date
            }
        }
        return nil
    }

    private static func dateValue(_ value: Any?) -> Date? {
        if let date = value as? Date {
            return date
        }
        if let number = value as? NSNumber {
            let seconds = number.doubleValue > 10_000_000_000 ? number.doubleValue / 1000 : number.doubleValue
            return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
        }
        if let dictionary = value as? [String: Any] {
            if let timestamp = firstDateValue(in: dictionary, keys: ["timestamp", "time", "date"]) {
                return timestamp
            }
            if let seconds = doubleValue(dictionary["seconds"] ?? dictionary["_seconds"]), seconds > 0 {
                let nanos = doubleValue(dictionary["nanos"] ?? dictionary["_nanos"]) ?? 0
                return Date(timeIntervalSince1970: seconds + nanos / 1_000_000_000)
            }
        }
        if let string = value as? String {
            if let timestamp = Double(string) {
                let seconds = timestamp > 10_000_000_000 ? timestamp / 1000 : timestamp
                return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
            }
            return parseISO8601Date(string)
        }
        return nil
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
    case invalidAPIKey(statusCode: Int)
    case notSupported
    case noSubscription
    case cooldown

    var errorDescription: String? {
        localizedTextDescriptor.render()
    }

    var localizedTextDescriptor: LocalizedTextDescriptor {
        switch self {
        case .invalidResponse:
            return .localized(.quotaErrorInvalidResponse)
        case .networkError(let error):
            if let networkErrorKey = Self.knownNetworkErrorKey(error) {
                return .localized(networkErrorKey)
            }
            return .localized(.quotaErrorNetworkFormat, error.localizedDescription)
        case .rateLimited:
            return .localized(.quotaErrorRateLimited)
        case .unauthorized:
            return .localized(.quotaErrorInvalidAPIKey)
        case .invalidAPIKey:
            return .localized(.quotaErrorInvalidAPIKey)
        case .notSupported:
            return .localized(.quotaCheckNotSupportedDiagnostic)
        case .noSubscription:
            return .localized(.noSubscribedPlan)
        case .cooldown:
            return .localized(.quotaErrorCooldown)
        }
    }

    private static func knownNetworkErrorKey(_ error: Error) -> L10n.Key? {
        if let urlError = error as? URLError,
           let key = knownNetworkErrorKey(for: urlError.code) {
            return key
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            let urlErrorCode = URLError.Code(rawValue: nsError.code)
            if let key = knownNetworkErrorKey(for: urlErrorCode) {
                return key
            }
        }

        return L10n.knownNetworkErrorKey(error.localizedDescription)
    }

    private static func knownNetworkErrorKey(for code: URLError.Code) -> L10n.Key? {
        switch code {
        case .timedOut:
            return .quotaErrorTimedOutNetwork
        case .notConnectedToInternet:
            return .quotaErrorOfflineNetwork
        case .networkConnectionLost:
            return .quotaErrorConnectionLostNetwork
        case .cannotFindHost, .dnsLookupFailed:
            return .quotaErrorHostNotFoundNetwork
        case .cannotConnectToHost:
            return .quotaErrorCannotConnectNetwork
        default:
            return nil
        }
    }

    var httpStatus: Int? {
        switch self {
        case .unauthorized:
            return 401
        case .invalidAPIKey(let statusCode):
            return statusCode
        case .rateLimited:
            return 429
        case .invalidResponse, .networkError, .notSupported, .noSubscription, .cooldown:
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

private struct ExaAdminCredential {
    let serviceKey: String
    let apiKeyID: String
    let days: Int

    init?(_ raw: String) {
        let credential = DashboardCredential(raw)
        guard let serviceKey = credential.value(for: ["serviceKey", "service_key", "adminApiKey", "admin_api_key", "adminKey"]),
              let apiKeyID = credential.value(for: ["apiKeyID", "apiKeyId", "api_key_id", "keyID", "keyId", "id"]) else {
            return nil
        }

        self.serviceKey = serviceKey
        self.apiKeyID = apiKeyID
        if let rawDays = credential.value(for: ["days", "numDays", "num_days"]),
           let parsedDays = Int(rawDays),
           parsedDays > 0 {
            self.days = parsedDays
        } else {
            self.days = 30
        }
    }
}

private struct ChatGPTSessionContext {
    let accessToken: String
    let accountID: String?
}

private struct KimiDashboardCredential {
    let accessToken: String
    let cookie: String?
    let deviceID: String?
    let sessionID: String?
    let trafficID: String?

    init?(_ raw: String) {
        let credential = DashboardCredential(raw)
        let cookieHeader = credential.cookie
        let fieldToken = credential.value(
            for: ["accessToken", "access_token", "authorization", "bearerToken", "bearer_token", "token"]
        )
        let token = fieldToken
            ?? credential.cookieValue(named: "kimi-auth")
            ?? (cookieHeader.contains("=") ? nil : cookieHeader)
        guard let token, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        self.accessToken = Self.stripBearerPrefix(token)
        self.cookie = cookieHeader.contains("=") ? cookieHeader : nil
        self.deviceID = credential.value(for: ["deviceID", "deviceId", "x-msh-device-id"])
        self.sessionID = credential.value(for: ["sessionID", "sessionId", "x-msh-session-id"])
        self.trafficID = credential.value(for: ["trafficID", "trafficId", "x-traffic-id"])
    }

    private static func stripBearerPrefix(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("bearer ") {
            return String(trimmed.dropFirst("Bearer ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }
}

actor QuotaService {
    private var lastCheck: [String: Date] = [:]

    private var session: URLSession {
        URLSession(configuration: AppAppearanceStore.configuredURLSessionConfiguration())
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
        case .claudeAPIUsage, .codexAPIUsage:
            throw QuotaError.notSupported
        case .claudeSubscription:
            return try await checkClaudeSubscriptionQuota(key: key, bypassCooldown: bypassCooldown)
        case .codexSubscription:
            return try await checkCodexSubscriptionQuota(key: key)
        case .kimiSubscription:
            return try await checkKimiSubscriptionQuota(key: key)
        case .deepseek:
            return try await checkDeepSeekQuota(key: key)
        case .xfyunCodingPlan:
            return try await checkXFYunCodingPlanQuota(key: key)
        case .volcengineCodingPlan:
            return try await checkVolcengineCodingPlanQuota(key: key, bypassCooldown: bypassCooldown)
        case .opencodeGo:
            return try await checkOpenCodeGoQuota(key: key)
        case .aliyunCodingPlan:
            return try await checkAliyunCodingPlanQuota(key: key)
        case .tencentCloudCodingPlan:
            return try await checkTencentCloudCodingPlanQuota(key: key)
        case .xfyunTokenPlan, .volcengineTokenPlan, .aliyunTokenPlan:
            throw QuotaError.notSupported
        case .tencentCloudTokenPlan:
            return try await checkTencentCloudTokenPlanQuota(key: key)
        case .wxmp:
            return try await checkWxmpQuota(key: key)
        }
    }

    private func withHTTPStatus(
        _ result: QuotaResult,
        from response: HTTPURLResponse,
        diagnosticMessage: String? = nil
    ) -> QuotaResult {
        var result = result
        result.httpStatus = response.statusCode
        if let diagnosticMessage {
            result.diagnosticMessage = diagnosticMessage
            result.diagnosticText = LocalizedTextDescriptor.fromLegacyLabel(diagnosticMessage)
        }
        return result
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

        return try withHTTPStatus(
            QuotaParsers.parseTavilyUsage(data),
            from: httpResponse
        )
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

        return try QuotaParsers.parseBraveHTTPResponse(
            statusCode: httpResponse.statusCode,
            limitHeader: httpResponse.value(forHTTPHeaderField: "X-RateLimit-Limit"),
            remainingHeader: httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
            resetHeader: httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset"),
            policyHeader: httpResponse.value(forHTTPHeaderField: "X-RateLimit-Policy"),
            knownRemaining: key.remaining,
            knownLimit: key.limit
        )
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

        return try withHTTPStatus(
            QuotaParsers.parseSerpApiAccount(data),
            from: httpResponse
        )
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

        return try withHTTPStatus(
            QuotaParsers.parseSerperAccount(data),
            from: httpResponse
        )
    }

    /// Exa Admin API requires a service key and the target API key id.
    /// A plain Exa search API key cannot call the Team Management usage endpoint.
    private func checkExaQuota(key: APIKey) async throws -> QuotaResult {
        guard let credential = ExaAdminCredential(key.key),
              let encodedKeyID = credential.apiKeyID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              var components = URLComponents(string: "https://admin-api.exa.ai/team-management/api-keys/\(encodedKeyID)/usage") else {
            throw QuotaError.notSupported
        }

        components.queryItems = [
            URLQueryItem(name: "numDays", value: String(credential.days))
        ]
        guard let url = components.url else {
            throw QuotaError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(credential.serviceKey, forHTTPHeaderField: "x-api-key")
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

        return try withHTTPStatus(
            QuotaParsers.parseExaUsage(data),
            from: httpResponse,
            diagnosticMessage: "Exa Team Management usage endpoint returned billing usage."
        )
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

        return try withHTTPStatus(
            QuotaParsers.parseBochaRemainingFund(data),
            from: httpResponse
        )
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

        return try withHTTPStatus(
            QuotaParsers.parseDajialaRemainMoney(data),
            from: httpResponse
        )
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

        return try withHTTPStatus(
            QuotaParsers.parseQueritAccount(data),
            from: httpResponse
        )
    }

    // MARK: - LLM Providers

    /// Anthropic: 通过 API 获取 usage
    /// https://docs.anthropic.com/en/api/rate-limits
    private func checkAnthropicQuota(key: APIKey) async throws -> QuotaResult {
        throw QuotaError.notSupported
    }

    /// Claude Subscription: claude.ai organization dashboard usage endpoint.
    /// The secret is a Claude web login Cookie header captured by reauthentication.
    private func checkClaudeSubscriptionQuota(key: APIKey, bypassCooldown: Bool) async throws -> QuotaResult {
        let credential = DashboardCredential(key.key)
        guard !credential.cookie.isEmpty else {
            throw QuotaError.unauthorized
        }

        let organizationContext = try await fetchClaudeOrganizationContext(cookie: credential.cookie)
        guard let encodedOrganizationID = organizationContext.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw QuotaError.invalidResponse
        }

        var request = URLRequest(url: URL(string: "https://claude.ai/api/organizations/\(encodedOrganizationID)/usage")!)
        request.httpMethod = "GET"
        applyClaudeDashboardHeaders(
            to: &request,
            cookie: credential.cookie,
            referer: "https://claude.ai/settings/usage"
        )

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

        var result = try QuotaParsers.parseClaudeSubscriptionUsage(data)
        result.planEndsAt = key.planEndsAt ?? result.planEndsAt
        result.planDisplayName = organizationContext.planDisplayName ?? key.planDisplayName ?? result.planDisplayName
        if shouldRefreshLowChurnAccountMetadata(for: key, bypassCooldown: bypassCooldown),
           let lifecycle = try? await fetchClaudeSubscriptionLifecycle(
                cookie: credential.cookie,
                organizationID: encodedOrganizationID
           ) {
            result.planEndsAt = lifecycle.planEndsAt ?? result.planEndsAt
            result.planDisplayName = lifecycle.planDisplayName ?? result.planDisplayName
        }

        return withHTTPStatus(result, from: httpResponse)
    }

    private func fetchClaudeOrganizationContext(cookie: String) async throws -> ClaudeOrganizationContext {
        var request = URLRequest(url: URL(string: "https://claude.ai/api/organizations")!)
        request.httpMethod = "GET"
        applyClaudeDashboardHeaders(
            to: &request,
            cookie: cookie,
            referer: "https://claude.ai/settings/usage"
        )

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

        return try QuotaParsers.parseClaudeOrganizationContext(data)
    }

    private func fetchClaudeSubscriptionLifecycle(cookie: String, organizationID: String) async throws -> SubscriptionLifecycleInfo {
        var request = URLRequest(url: URL(string: "https://claude.ai/api/organizations/\(organizationID)/subscription_details")!)
        request.httpMethod = "GET"
        applyClaudeDashboardHeaders(
            to: &request,
            cookie: cookie,
            referer: "https://claude.ai/settings/usage"
        )

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

        return try QuotaParsers.parseClaudeSubscriptionDetails(data)
    }

    private func applyClaudeDashboardHeaders(to request: inout URLRequest, cookie: String, referer: String) {
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue("\"Chromium\";v=\"148\", \"Google Chrome\";v=\"148\", \"Not/A)Brand\";v=\"99\"", forHTTPHeaderField: "sec-ch-ua")
        request.setValue("?0", forHTTPHeaderField: "sec-ch-ua-mobile")
        request.setValue("\"macOS\"", forHTTPHeaderField: "sec-ch-ua-platform")
        request.setValue("empty", forHTTPHeaderField: "sec-fetch-dest")
        request.setValue("cors", forHTTPHeaderField: "sec-fetch-mode")
        request.setValue("same-origin", forHTTPHeaderField: "sec-fetch-site")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
    }

    /// Kimi Subscription: Kimi membership and billing dashboard endpoints.
    /// The secret is either a JSON credential with accessToken/cookie/x-msh metadata,
    /// a raw kimi-auth Cookie header, or a raw Bearer token.
    private func checkKimiSubscriptionQuota(key: APIKey) async throws -> QuotaResult {
        guard let credential = KimiDashboardCredential(key.key) else {
            throw QuotaError.unauthorized
        }

        let usageData: Data?
        do {
            usageData = try await fetchKimiBillingUsage(
                credential: credential
            ).data
        } catch QuotaError.invalidResponse {
            usageData = nil
        }

        let subscriptionResponse = try await fetchKimiMembershipEndpoint(
            "GetSubscription",
            credential: credential
        )
        var result = try QuotaParsers.parseKimiSubscriptionUsage(
            subscriptionData: subscriptionResponse.data,
            usageData: usageData
        )
        result.httpStatus = subscriptionResponse.response.statusCode
        return result
    }

    private func fetchKimiBillingUsage(
        credential: KimiDashboardCredential
    ) async throws -> (data: Data, response: HTTPURLResponse) {
        let url = URL(string: "https://www.kimi.com/apiv2/kimi.gateway.billing.v1.BillingService/GetUsages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyKimiMembershipHeaders(to: &request, credential: credential)
        request.setValue("https://www.kimi.com/code/console", forHTTPHeaderField: "Referer")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["scope": ["FEATURE_CODING"]])

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
        return (data, httpResponse)
    }

    private func fetchKimiMembershipEndpoint(
        _ method: String,
        credential: KimiDashboardCredential
    ) async throws -> (data: Data, response: HTTPURLResponse) {
        let endpointPath: String
        switch method {
        case "GetSubscription":
            endpointPath = "MembershipService/GetSubscription"
        default:
            throw QuotaError.invalidResponse
        }
        let url = URL(string: "https://www.kimi.com/apiv2/kimi.gateway.membership.v2.\(endpointPath)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyKimiMembershipHeaders(to: &request, credential: credential)
        request.httpBody = Data("{}".utf8)

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
        return (data, httpResponse)
    }

    private func applyKimiMembershipHeaders(to request: inout URLRequest, credential: KimiDashboardCredential) {
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("Bearer \(credential.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("1", forHTTPHeaderField: "connect-protocol-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://www.kimi.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.kimi.com/membership/subscription?tab=quota", forHTTPHeaderField: "Referer")
        request.setValue(TimeZone.current.identifier, forHTTPHeaderField: "r-timezone")
        request.setValue("zh-CN", forHTTPHeaderField: "x-language")
        request.setValue("web", forHTTPHeaderField: "x-msh-platform")
        request.setValue("1.0.0", forHTTPHeaderField: "x-msh-version")
        request.setValue("\"Chromium\";v=\"148\", \"Google Chrome\";v=\"148\", \"Not/A)Brand\";v=\"99\"", forHTTPHeaderField: "sec-ch-ua")
        request.setValue("?0", forHTTPHeaderField: "sec-ch-ua-mobile")
        request.setValue("\"macOS\"", forHTTPHeaderField: "sec-ch-ua-platform")
        request.setValue("empty", forHTTPHeaderField: "sec-fetch-dest")
        request.setValue("cors", forHTTPHeaderField: "sec-fetch-mode")
        request.setValue("same-origin", forHTTPHeaderField: "sec-fetch-site")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        if let cookie = credential.cookie {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        if let deviceID = credential.deviceID {
            request.setValue(deviceID, forHTTPHeaderField: "x-msh-device-id")
        }
        if let sessionID = credential.sessionID {
            request.setValue(sessionID, forHTTPHeaderField: "x-msh-session-id")
        }
        if let trafficID = credential.trafficID {
            request.setValue(trafficID, forHTTPHeaderField: "x-traffic-id")
        }
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

        return try withHTTPStatus(
            QuotaParsers.parseDeepSeekBalance(data),
            from: httpResponse
        )
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

        return try withHTTPStatus(
            QuotaParsers.parseXFYunCodingPlanList(data),
            from: httpResponse
        )
    }

    /// 火山引擎 Coding Plan: console session endpoint.
    /// The secret can be a raw Cookie header, or JSON with cookie/csrfToken/projectName/xWebId.
    private func checkVolcengineCodingPlanQuota(key: APIKey, bypassCooldown: Bool) async throws -> QuotaResult {
        let credential = DashboardCredential(key.key)
        guard !credential.cookie.isEmpty else {
            throw QuotaError.unauthorized
        }

        let projectName = credential.value(for: ["projectName", "project"]) ?? "default"
        var request = URLRequest(url: URL(string: "https://console.volcengine.com/api/top/ark/cn-beijing/2024-01-01/GetCodingPlanUsage?")!)
        request.httpMethod = "POST"
        applyVolcengineDashboardHeaders(to: &request, credential: credential, projectName: projectName)
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

        var result = try QuotaParsers.parseVolcengineCodingPlanUsage(data)
        result.planEndsAt = key.planEndsAt ?? result.planEndsAt
        result.planDisplayName = key.planDisplayName ?? result.planDisplayName
        if shouldRefreshLowChurnAccountMetadata(for: key, bypassCooldown: bypassCooldown),
           let lifecycle = try? await fetchVolcengineCodingPlanSubscription(
                credential: credential,
                projectName: projectName
           ) {
            result.planEndsAt = lifecycle.planEndsAt ?? result.planEndsAt
            result.planDisplayName = lifecycle.planDisplayName ?? result.planDisplayName
        }

        return withHTTPStatus(result, from: httpResponse)
    }

    private func fetchVolcengineCodingPlanSubscription(
        credential: DashboardCredential,
        projectName: String
    ) async throws -> SubscriptionLifecycleInfo {
        var request = URLRequest(url: URL(string: "https://console.volcengine.com/api/top/ark/cn-beijing/2024-01-01/ListSubscribeTrade?")!)
        request.httpMethod = "POST"
        applyVolcengineDashboardHeaders(to: &request, credential: credential, projectName: projectName)
        request.httpBody = try JSONSerialization.data(
            withJSONObject: [
                "ResourceTypes": ["CodingPlan"],
                "ResourceNames": [""],
                "BizInfos": ["lite", "pro"],
            ]
        )

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

        return try QuotaParsers.parseVolcengineCodingPlanSubscription(data)
    }

    private func applyVolcengineDashboardHeaders(
        to request: inout URLRequest,
        credential: DashboardCredential,
        projectName: String
    ) {
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
    }

    private func shouldRefreshLowChurnAccountMetadata(for key: APIKey, bypassCooldown: Bool) -> Bool {
        if bypassCooldown {
            return true
        }
        if key.planDisplayName == nil && key.planEndsAt == nil {
            return true
        }
        guard let lastUpdated = key.lastUpdated else {
            return true
        }
        return !Calendar.current.isDate(lastUpdated, inSameDayAs: Date())
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

        return try withHTTPStatus(
            QuotaParsers.parseOpenCodeGoUsage(data),
            from: httpResponse
        )
    }

    private func checkAliyunCodingPlanQuota(key: APIKey) async throws -> QuotaResult {
        guard !key.isBusinessInvocationCredential else {
            throw QuotaError.notSupported
        }

        let credential = DashboardCredential(key.key)
        guard !credential.cookie.isEmpty else {
            throw QuotaError.unauthorized
        }

        let region = credential.value(for: ["region", "aliyunRegion"]) ?? "cn-beijing"
        let secToken = try await fetchAliyunConsoleSecToken(cookie: credential.cookie)
        let api = "zeldaEasy.broadscope-bailian.codingPlan.queryCodingPlanInstanceInfoV2"

        var components = URLComponents(string: "https://bailian-cs.console.aliyun.com/data/api.json")!
        components.queryItems = [
            URLQueryItem(name: "action", value: "BroadScopeAspnGateway"),
            URLQueryItem(name: "product", value: "sfm_bailian"),
            URLQueryItem(name: "api", value: api),
            URLQueryItem(name: "_v", value: "undefined"),
        ]
        guard let url = components.url else {
            throw QuotaError.invalidResponse
        }

        let params: [String: Any] = [
            "Api": api,
            "V": "1.0",
            "Data": [
                "cornerstoneParam": [:] as [String: Any],
                "queryCodingPlanInstanceInfoRequest": [
                    "commodityCode": "sfm_codingplan_public",
                    "onlyLatestOne": true,
                ] as [String: Any],
            ],
        ]
        let paramsData = try JSONSerialization.data(withJSONObject: params)
        guard let paramsString = String(data: paramsData, encoding: .utf8) else {
            throw QuotaError.invalidResponse
        }

        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "params", value: paramsString),
            URLQueryItem(name: "sec_token", value: secToken),
            URLQueryItem(name: "region", value: region),
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(credential.cookie, forHTTPHeaderField: "Cookie")
        request.setValue("https://bailian.console.aliyun.com", forHTTPHeaderField: "Origin")
        request.setValue("https://bailian.console.aliyun.com/cn-beijing?tab=model#/efm/coding_plan", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
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

        return try withHTTPStatus(
            QuotaParsers.parseAliyunCodingPlanStatus(data),
            from: httpResponse
        )
    }

    /// Codex Subscription: ChatGPT Codex Cloud usage endpoint.
    /// The secret is a ChatGPT web login Cookie header captured by reauthentication.
    private func checkCodexSubscriptionQuota(key: APIKey) async throws -> QuotaResult {
        let credential = DashboardCredential(key.key)
        guard !credential.cookie.isEmpty else {
            throw QuotaError.unauthorized
        }
        let sessionContext = try await fetchChatGPTSessionContext(cookie: credential.cookie)

        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue(credential.cookie, forHTTPHeaderField: "Cookie")
        request.setValue("https://chatgpt.com/codex", forHTTPHeaderField: "Referer")
        request.setValue("\"Chromium\";v=\"148\", \"Google Chrome\";v=\"148\", \"Not/A)Brand\";v=\"99\"", forHTTPHeaderField: "sec-ch-ua")
        request.setValue("?0", forHTTPHeaderField: "sec-ch-ua-mobile")
        request.setValue("\"macOS\"", forHTTPHeaderField: "sec-ch-ua-platform")
        request.setValue("empty", forHTTPHeaderField: "sec-fetch-dest")
        request.setValue("cors", forHTTPHeaderField: "sec-fetch-mode")
        request.setValue("same-origin", forHTTPHeaderField: "sec-fetch-site")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("Bearer \(sessionContext.accessToken)", forHTTPHeaderField: "Authorization")

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

        var result = try QuotaParsers.parseCodexWhamUsage(data)
        if let accountID = sessionContext.accountID,
           let lifecycle = try? await fetchCodexSubscriptionLifecycle(
                cookie: credential.cookie,
                accessToken: sessionContext.accessToken,
                accountID: accountID
           ) {
            result.planEndsAt = lifecycle.planEndsAt
            result.planDisplayName = lifecycle.planDisplayName ?? result.planDisplayName
        }

        return withHTTPStatus(result, from: httpResponse)
    }

    private func fetchChatGPTSessionContext(cookie: String) async throws -> ChatGPTSessionContext {
        var request = URLRequest(url: URL(string: "https://chatgpt.com/api/auth/session")!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.setValue("https://chatgpt.com/codex", forHTTPHeaderField: "Referer")
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

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = object["accessToken"] as? String,
              !accessToken.isEmpty else {
            throw QuotaError.unauthorized
        }
        let account = object["account"] as? [String: Any]
        return ChatGPTSessionContext(
            accessToken: accessToken,
            accountID: account?["id"] as? String
        )
    }

    private func fetchCodexSubscriptionLifecycle(
        cookie: String,
        accessToken: String,
        accountID: String
    ) async throws -> SubscriptionLifecycleInfo {
        guard let encodedAccountID = accountID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw QuotaError.invalidResponse
        }
        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/subscriptions?account_id=\(encodedAccountID)")!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.setValue("https://chatgpt.com/codex", forHTTPHeaderField: "Referer")
        request.setValue("\"Chromium\";v=\"148\", \"Google Chrome\";v=\"148\", \"Not/A)Brand\";v=\"99\"", forHTTPHeaderField: "sec-ch-ua")
        request.setValue("?0", forHTTPHeaderField: "sec-ch-ua-mobile")
        request.setValue("\"macOS\"", forHTTPHeaderField: "sec-ch-ua-platform")
        request.setValue("empty", forHTTPHeaderField: "sec-fetch-dest")
        request.setValue("cors", forHTTPHeaderField: "sec-fetch-mode")
        request.setValue("same-origin", forHTTPHeaderField: "sec-fetch-site")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

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
        return try QuotaParsers.parseCodexSubscriptionLifecycle(data)
    }

    private func fetchAliyunConsoleSecToken(cookie: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://bailian.console.aliyun.com/tool/user/info.json")!)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.setValue("https://bailian.console.aliyun.com/?tab=plan#/efm/subscription/coding-plan", forHTTPHeaderField: "Referer")
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

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let userData = object["data"] as? [String: Any],
              let secToken = userData["secToken"] as? String,
              !secToken.isEmpty else {
            throw QuotaError.unauthorized
        }

        return secToken
    }

    private func checkTencentCloudCodingPlanQuota(key: APIKey) async throws -> QuotaResult {
        let credential = DashboardCredential(key.key)
        guard !credential.cookie.isEmpty,
              let uin = numericTencentCookie(
                credential.value(for: ["uin"]) ?? credential.cookieValue(named: "uin")
              ),
              let csrfToken = credential.value(for: ["skey", "p_skey", "pSkey"])
                ?? credential.cookieValue(named: "skey")
                ?? credential.cookieValue(named: "p_skey") else {
            throw QuotaError.unauthorized
        }

        let ownerUin = numericTencentCookie(
            credential.value(for: ["ownerUin", "owneruin", "owner_uin"]) ?? credential.cookieValue(named: "ownerUin")
        ) ?? uin
        let csrfCode = tencentCloudCSRFCode(from: csrfToken)
        let timestampMs = Int(Date().timeIntervalSince1970 * 1000)

        var components = URLComponents(string: "https://console.cloud.tencent.com/cgi/capi")!
        components.queryItems = [
            URLQueryItem(name: "cmd", value: "DescribePkg"),
            URLQueryItem(name: "action", value: "delegate"),
            URLQueryItem(name: "serviceType", value: "hunyuan"),
            URLQueryItem(name: "secure", value: "1"),
            URLQueryItem(name: "version", value: "3"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "dictId", value: "3216"),
            URLQueryItem(name: "sts", value: "1"),
            URLQueryItem(name: "t", value: String(timestampMs)),
            URLQueryItem(name: "uin", value: uin),
            URLQueryItem(name: "ownerUin", value: ownerUin),
            URLQueryItem(name: "csrfCode", value: csrfCode),
        ]
        guard let url = components.url else {
            throw QuotaError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(credential.cookie, forHTTPHeaderField: "Cookie")
        request.setValue("https://console.cloud.tencent.com", forHTTPHeaderField: "Origin")
        request.setValue("https://console.cloud.tencent.com/tokenhub/codingplan", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "regionId": 1,
            "serviceType": "hunyuan",
            "cmd": "DescribePkg",
            "data": [
                "Version": "2023-09-01",
                "Language": "zh-CN",
            ],
        ])

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

        return try withHTTPStatus(
            QuotaParsers.parseTencentCloudCodingPlanDescribePkg(data),
            from: httpResponse
        )
    }

    private func numericTencentCookie(_ value: String?) -> String? {
        guard let value else { return nil }
        let digits = value.filter(\.isNumber)
        return digits.isEmpty ? nil : digits
    }

    private func tencentCloudCSRFCode(from token: String) -> String {
        var hash: UInt32 = 5381
        for unit in token.utf16 {
            hash = hash &+ (hash << 5) &+ UInt32(unit)
        }
        return String(hash & 0x7fffffff)
    }

    private func checkTencentCloudTokenPlanQuota(key: APIKey) async throws -> QuotaResult {
        guard let credential = TencentCloudTokenPlanCredential(key.key) else {
            throw QuotaError.notSupported
        }

        var request = try TencentCloudAPIRequestBuilder.describeTokenPlanApiKey(credential: credential)
        request.timeoutInterval = 30
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

        return try withHTTPStatus(
            QuotaParsers.parseTencentCloudTokenPlanApiKey(data),
            from: httpResponse
        )
    }

}

private struct TencentCloudTokenPlanCredential {
    let secretID: String
    let secretKey: String
    let apiKeyID: String
    let region: String

    init?(_ raw: String) {
        let credential = DashboardCredential(raw)
        guard let secretID = credential.value(for: ["secretID", "secretId", "secret_id"]),
              let secretKey = credential.value(for: ["secretKey", "secret_key"]),
              let apiKeyID = credential.value(for: ["apiKeyID", "apiKeyId", "api_key_id", "keyID", "keyId", "id"]) else {
            return nil
        }

        self.secretID = secretID
        self.secretKey = secretKey
        self.apiKeyID = apiKeyID
        self.region = credential.value(for: ["region"]) ?? "ap-guangzhou"
    }
}

private enum TencentCloudAPIRequestBuilder {
    static func describeTokenPlanApiKey(credential: TencentCloudTokenPlanCredential, date: Date = Date()) throws -> URLRequest {
        let endpoint = "tokenhub.tencentcloudapi.com"
        let service = "tokenhub"
        let action = "DescribeTokenPlanApiKey"
        let version = "2025-05-29"
        let payload = #"{"ApiKeyId":"\#(credential.apiKeyID)"}"#
        let timestamp = Int(date.timeIntervalSince1970)
        let dateString = utcDateString(from: date)

        let canonicalHeaders = "content-type:application/json; charset=utf-8\nhost:\(endpoint)\nx-tc-action:\(action.lowercased())\n"
        let signedHeaders = "content-type;host;x-tc-action"
        let hashedRequestPayload = sha256Hex(payload)
        let canonicalRequest = [
            "POST",
            "/",
            "",
            canonicalHeaders,
            signedHeaders,
            hashedRequestPayload
        ].joined(separator: "\n")

        let credentialScope = "\(dateString)/\(service)/tc3_request"
        let stringToSign = [
            "TC3-HMAC-SHA256",
            String(timestamp),
            credentialScope,
            sha256Hex(canonicalRequest)
        ].joined(separator: "\n")

        let secretDate = hmacSHA256(data: dateString, key: Data("TC3\(credential.secretKey)".utf8))
        let secretService = hmacSHA256(data: service, key: secretDate)
        let secretSigning = hmacSHA256(data: "tc3_request", key: secretService)
        let signature = hmacSHA256Hex(data: stringToSign, key: secretSigning)
        let authorization = "TC3-HMAC-SHA256 Credential=\(credential.secretID)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"

        var request = URLRequest(url: URL(string: "https://\(endpoint)")!)
        request.httpMethod = "POST"
        request.httpBody = Data(payload.utf8)
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(endpoint, forHTTPHeaderField: "Host")
        request.setValue(action, forHTTPHeaderField: "X-TC-Action")
        request.setValue(version, forHTTPHeaderField: "X-TC-Version")
        request.setValue(credential.region, forHTTPHeaderField: "X-TC-Region")
        request.setValue(String(timestamp), forHTTPHeaderField: "X-TC-Timestamp")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        return request
    }

    private static func utcDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func sha256Hex(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func hmacSHA256(data: String, key: Data) -> Data {
        let key = SymmetricKey(data: key)
        let signature = HMAC<SHA256>.authenticationCode(for: Data(data.utf8), using: key)
        return Data(signature)
    }

    private static func hmacSHA256Hex(data: String, key: Data) -> String {
        hmacSHA256(data: data, key: key).map { String(format: "%02x", $0) }.joined()
    }
}
