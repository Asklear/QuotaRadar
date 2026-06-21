import Foundation

enum QuotaSnapshotOutcome: String, Codable, Equatable {
    case success
    case unsupported
    case unauthorized
    case noSubscription
    case failed
    case skipped
}

struct QuotaWindowSnapshot: Codable, Equatable {
    var name: String
    var remainingPercent: Double
    var resetAt: Date?

    init(name: String, remainingPercent: Double, resetAt: Date? = nil) {
        self.name = name
        self.remainingPercent = max(0, min(100, remainingPercent))
        self.resetAt = resetAt
    }

    init?(_ window: QuotaWindowText) {
        guard let remainingPercent = Self.percent(from: window.percentText) else { return nil }
        self.init(name: window.name, remainingPercent: remainingPercent, resetAt: window.resetAt)
    }

    var normalizedName: String {
        Self.normalizedName(name)
    }

    static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func percent(from text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "%", with: "")
        return Double(normalized)
    }
}

struct QuotaSnapshot: Codable, Identifiable, Equatable {
    var id: UUID
    var keyID: UUID
    var provider: Provider
    var credentialName: String
    var recordedAt: Date
    var outcome: QuotaSnapshotOutcome
    var remaining: Int?
    var limit: Int?
    var resetAt: Date?
    var planEndsAt: Date?
    var planDisplayName: String?
    var quotaLabel: String?
    var httpStatus: Int?
    var quotaWindows: [QuotaWindowSnapshot]

    init(
        id: UUID = UUID(),
        keyID: UUID,
        provider: Provider,
        credentialName: String,
        recordedAt: Date = Date(),
        outcome: QuotaSnapshotOutcome,
        remaining: Int?,
        limit: Int?,
        resetAt: Date?,
        planEndsAt: Date?,
        planDisplayName: String?,
        quotaLabel: String?,
        httpStatus: Int?,
        quotaWindows: [QuotaWindowSnapshot] = []
    ) {
        self.id = id
        self.keyID = keyID
        self.provider = provider
        self.credentialName = credentialName
        self.recordedAt = recordedAt
        self.outcome = outcome
        self.remaining = remaining
        self.limit = limit
        self.resetAt = resetAt
        self.planEndsAt = planEndsAt
        self.planDisplayName = planDisplayName
        self.quotaLabel = quotaLabel
        self.httpStatus = httpStatus
        self.quotaWindows = quotaWindows
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case keyID
        case provider
        case credentialName
        case recordedAt
        case outcome
        case remaining
        case limit
        case resetAt
        case planEndsAt
        case planDisplayName
        case quotaLabel
        case httpStatus
        case quotaWindows
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        keyID = try container.decode(UUID.self, forKey: .keyID)
        provider = try container.decode(Provider.self, forKey: .provider)
        credentialName = try container.decode(String.self, forKey: .credentialName)
        recordedAt = try container.decode(Date.self, forKey: .recordedAt)
        outcome = try container.decode(QuotaSnapshotOutcome.self, forKey: .outcome)
        remaining = try container.decodeIfPresent(Int.self, forKey: .remaining)
        limit = try container.decodeIfPresent(Int.self, forKey: .limit)
        resetAt = try container.decodeIfPresent(Date.self, forKey: .resetAt)
        planEndsAt = try container.decodeIfPresent(Date.self, forKey: .planEndsAt)
        planDisplayName = try container.decodeIfPresent(String.self, forKey: .planDisplayName)
        quotaLabel = try container.decodeIfPresent(String.self, forKey: .quotaLabel)
        httpStatus = try container.decodeIfPresent(Int.self, forKey: .httpStatus)
        quotaWindows = try container.decodeIfPresent([QuotaWindowSnapshot].self, forKey: .quotaWindows) ?? []
    }

    var percentRemaining: Double? {
        guard let remaining, let limit, limit > 0 else { return nil }
        return max(0, min(100, (Double(remaining) / Double(limit)) * 100))
    }

    var consumed: Int? {
        guard let remaining, let limit, limit >= remaining else { return nil }
        return limit - remaining
    }

    var isComparableQuotaSnapshot: Bool {
        outcome == .success && percentRemaining != nil
    }

    func quotaWindow(named name: String) -> QuotaWindowSnapshot? {
        comparableQuotaWindows.first { $0.normalizedName == QuotaWindowSnapshot.normalizedName(name) }
    }

    private var comparableQuotaWindows: [QuotaWindowSnapshot] {
        guard outcome == .success else { return [] }
        if !quotaWindows.isEmpty { return quotaWindows }
        return Self.quotaWindows(from: quotaLabel)
    }

    private static func quotaWindows(from quotaLabel: String?) -> [QuotaWindowSnapshot] {
        guard let quotaLabel, !quotaLabel.isEmpty else { return [] }
        return quotaLabel
            .components(separatedBy: "·")
            .compactMap { component in
                let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let percentRange = trimmed.range(of: #"([0-9]+(?:\.[0-9]+)?)%"#, options: .regularExpression) else {
                    return nil
                }
                let percentText = String(trimmed[percentRange]).replacingOccurrences(of: "%", with: "")
                guard let percent = Double(percentText) else { return nil }
                let name = String(trimmed[..<percentRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return nil }
                return QuotaWindowSnapshot(name: name, remainingPercent: percent)
            }
    }
}

private func quotaResetMatches(_ lhs: Date?, _ rhs: Date?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil):
        return true
    case let (lhs?, rhs?):
        return abs(lhs.timeIntervalSince(rhs)) < 1
    default:
        return false
    }
}

private func latestQuotaResetSegment<Entry>(
    from entries: [Entry],
    resetAt: (Entry) -> Date?
) -> [Entry] {
    guard let latest = entries.last else { return [] }
    let latestResetAt = resetAt(latest)
    var segment: [Entry] = []

    for entry in entries.reversed() {
        guard quotaResetMatches(resetAt(entry), latestResetAt) else { break }
        segment.append(entry)
    }

    return segment.reversed()
}

private func hasQuotaResetBoundaryBeforeLatest<Entry>(
    in entries: [Entry],
    resetAt: (Entry) -> Date?
) -> Bool {
    guard entries.count >= 2, let latest = entries.last else { return false }
    guard let previous = entries.dropLast().last else { return false }
    return !quotaResetMatches(resetAt(previous), resetAt(latest))
}

private func matchesQuotaHistoryScope(_ snapshot: QuotaSnapshot, key: APIKey) -> Bool {
    snapshot.keyID == key.id && snapshot.provider == key.provider
}

struct QuotaSparklineSample: Equatable {
    static let maxSamples = 18
    static let minimumRenderableSamples = 3
    static let minimumRenderableSpan: TimeInterval = 30 * 60
    private static let minimumRenderableRange = 0.002

    var recordedAt: Date
    var value: Double
    var resetAt: Date? = nil
    var windowName: String? = nil

    static func shouldRenderSparkline(_ samples: [QuotaSparklineSample]) -> Bool {
        let orderedSamples = samples
            .filter { $0.value.isFinite }
            .sorted { $0.recordedAt < $1.recordedAt }
        guard orderedSamples.count >= minimumRenderableSamples,
              let first = orderedSamples.first,
              let last = orderedSamples.last else {
            return false
        }

        guard last.recordedAt.timeIntervalSince(first.recordedAt) >= minimumRenderableSpan else {
            return false
        }

        let values = orderedSamples.map { max(0, min(1, $0.value)) }
        guard let minimum = values.min(), let maximum = values.max() else {
            return false
        }
        return maximum - minimum >= minimumRenderableRange
    }

    static func samples(
        for key: APIKey,
        snapshots: [QuotaSnapshot],
        now: Date = Date()
    ) -> [QuotaSparklineSample] {
        if key.provider.usesMoneyBalance {
            let balanceSamples = samplesForMoneyBalance(for: key, snapshots: snapshots, now: now)
            if balanceSamples.count >= 2 {
                return balanceSamples
            }
        }

        if let windowName = largestQuotaWindowName(for: key) {
            return samples(for: key, snapshots: snapshots, windowName: windowName, now: now)
        }

        let comparableSnapshots = snapshots
            .filter { matchesQuotaHistoryScope($0, key: key) && $0.recordedAt <= now && $0.isComparableQuotaSnapshot }
            .sorted { $0.recordedAt < $1.recordedAt }
        let currentResetSegment = latestQuotaResetSegment(from: comparableSnapshots) { $0.resetAt }

        return selectedSnapshots(from: currentResetSegment, now: now)
            .compactMap { snapshot in
                snapshot.percentRemaining.map {
                    QuotaSparklineSample(
                        recordedAt: snapshot.recordedAt,
                        value: $0 / 100,
                        resetAt: snapshot.resetAt
                    )
                }
            }
    }

    private static func samples(
        for key: APIKey,
        snapshots: [QuotaSnapshot],
        windowName: String,
        now: Date
    ) -> [QuotaSparklineSample] {
        let windowSnapshots = snapshots
            .filter { matchesQuotaHistoryScope($0, key: key) && $0.recordedAt <= now }
            .sorted { $0.recordedAt < $1.recordedAt }
            .compactMap { snapshot -> (snapshot: QuotaSnapshot, window: QuotaWindowSnapshot)? in
                snapshot.quotaWindow(named: windowName).map { (snapshot, $0) }
            }
        let currentResetSegment = latestQuotaResetSegment(from: windowSnapshots) { $0.window.resetAt }

        return selectedWindowSnapshots(from: currentResetSegment, now: now)
            .map { entry in
                QuotaSparklineSample(
                    recordedAt: entry.snapshot.recordedAt,
                    value: entry.window.remainingPercent / 100,
                    resetAt: entry.window.resetAt,
                    windowName: entry.window.name
                )
            }
    }

    private static func samplesForMoneyBalance(
        for key: APIKey,
        snapshots: [QuotaSnapshot],
        now: Date
    ) -> [QuotaSparklineSample] {
        let balanceSnapshots = snapshots
            .filter { snapshot in
                matchesQuotaHistoryScope(snapshot, key: key)
                    && snapshot.recordedAt <= now
                    && snapshot.outcome == .success
                    && snapshot.remaining != nil
            }
            .sorted { $0.recordedAt < $1.recordedAt }

        let selected = selectedSnapshots(from: balanceSnapshots, now: now)
        let balances = selected.compactMap(\.remaining)
        guard let maximumBalance = balances.max(), maximumBalance > 0 else {
            return []
        }

        return selected.compactMap { snapshot in
            guard let remaining = snapshot.remaining else { return nil }
            return QuotaSparklineSample(
                recordedAt: snapshot.recordedAt,
                value: Double(max(0, remaining)) / Double(maximumBalance),
                resetAt: snapshot.resetAt
            )
        }
    }

    private static func selectedSnapshots(from snapshots: [QuotaSnapshot], now: Date) -> [QuotaSnapshot] {
        let recentCutoff = now.addingTimeInterval(-QuotaTrendSummary.recentWindow)
        let recentSnapshots = snapshots.filter { $0.recordedAt >= recentCutoff }
        let selectedSnapshots = recentSnapshots.count >= 2
            ? recentSnapshots
            : Array(snapshots.suffix(maxSamples))
        return Array(selectedSnapshots.suffix(maxSamples))
    }

    private static func selectedWindowSnapshots(
        from snapshots: [(snapshot: QuotaSnapshot, window: QuotaWindowSnapshot)],
        now: Date
    ) -> [(snapshot: QuotaSnapshot, window: QuotaWindowSnapshot)] {
        let recentCutoff = now.addingTimeInterval(-QuotaTrendSummary.recentWindow)
        let recentSnapshots = snapshots.filter { $0.snapshot.recordedAt >= recentCutoff }
        let selectedSnapshots = recentSnapshots.count >= 2
            ? recentSnapshots
            : Array(snapshots.suffix(maxSamples))
        return Array(selectedSnapshots.suffix(maxSamples))
    }

    private static func largestQuotaWindowName(for key: APIKey) -> String? {
        key.quotaWindowDetails
            .compactMap { window -> (name: String, rank: Int)? in
                guard QuotaWindowSnapshot.percent(from: window.percentText) != nil else { return nil }
                return (window.name, quotaWindowDurationRank(window.name))
            }
            .max { lhs, rhs in
                if lhs.rank != rhs.rank {
                    return lhs.rank < rhs.rank
                }
                return lhs.name < rhs.name
            }?
            .name
    }

    private static func quotaWindowDurationRank(_ name: String) -> Int {
        switch QuotaWindowSnapshot.normalizedName(name) {
        case "month", "monthly", "package", "package-period", "package period", "total", "总", "月":
            return 300
        case "week", "weekly", "7d", "seven_day", "seven-day", "7-day", "周":
            return 200
        case "5h", "five_hour", "five-hour", "5-hour", "5hour", "5 小时", "5小时":
            return 100
        default:
            return 0
        }
    }
}

enum QuotaTrendDirection: String, Codable, Equatable {
    case unknown
    case stable
    case decreasing
    case replenished
}

struct QuotaTrendSummary: Equatable {
    static let recentWindow: TimeInterval = 7 * 24 * 60 * 60
    private static let stableThresholdPercentPoints = 1.0

    var keyID: UUID
    var provider: Provider
    var direction: QuotaTrendDirection
    var consumedPercentPoints: Double
    var consumedUnits: Int?
    var observationCount: Int
    var windowStart: Date?
    var windowEnd: Date?

    static func trendSummary(
        for key: APIKey,
        snapshots: [QuotaSnapshot],
        now: Date = Date()
    ) -> QuotaTrendSummary {
        let comparableSnapshots = snapshots
            .filter { matchesQuotaHistoryScope($0, key: key) && $0.recordedAt <= now && $0.isComparableQuotaSnapshot }
            .sorted { $0.recordedAt < $1.recordedAt }
        let currentResetSegment = latestQuotaResetSegment(from: comparableSnapshots) { $0.resetAt }

        let recentCutoff = now.addingTimeInterval(-recentWindow)
        let recentSnapshots = currentResetSegment.filter { $0.recordedAt >= recentCutoff }
        let selectedSnapshots: [QuotaSnapshot]
        if recentSnapshots.count >= 2 {
            selectedSnapshots = recentSnapshots
        } else {
            selectedSnapshots = Array(currentResetSegment.suffix(5))
        }

        guard
            selectedSnapshots.count >= 2,
            let firstSnapshot = selectedSnapshots.first,
            let lastSnapshot = selectedSnapshots.last,
            let firstPercent = firstSnapshot.percentRemaining,
            let lastPercent = lastSnapshot.percentRemaining
        else {
            let direction: QuotaTrendDirection = hasQuotaResetBoundaryBeforeLatest(in: comparableSnapshots) { $0.resetAt } ? .replenished : .unknown
            return QuotaTrendSummary(
                keyID: key.id,
                provider: key.provider,
                direction: direction,
                consumedPercentPoints: 0,
                consumedUnits: nil,
                observationCount: selectedSnapshots.count,
                windowStart: selectedSnapshots.first?.recordedAt,
                windowEnd: selectedSnapshots.last?.recordedAt
            )
        }

        let percentDelta = firstPercent - lastPercent
        let consumedUnits: Int?
        if firstSnapshot.limit == lastSnapshot.limit,
           let firstRemaining = firstSnapshot.remaining,
           let lastRemaining = lastSnapshot.remaining,
           firstRemaining >= lastRemaining {
            consumedUnits = firstRemaining - lastRemaining
        } else {
            consumedUnits = nil
        }

        let direction: QuotaTrendDirection
        if lastPercent - firstPercent >= stableThresholdPercentPoints {
            direction = .replenished
        } else if firstSnapshot.resetAt != lastSnapshot.resetAt,
                  let firstRemaining = firstSnapshot.remaining,
                  let lastRemaining = lastSnapshot.remaining,
                  lastRemaining >= firstRemaining {
            direction = .replenished
        } else if percentDelta >= stableThresholdPercentPoints {
            direction = .decreasing
        } else {
            direction = .stable
        }

        return QuotaTrendSummary(
            keyID: key.id,
            provider: key.provider,
            direction: direction,
            consumedPercentPoints: max(0, percentDelta),
            consumedUnits: consumedUnits,
            observationCount: selectedSnapshots.count,
            windowStart: firstSnapshot.recordedAt,
            windowEnd: lastSnapshot.recordedAt
        )
    }
}

enum QuotaActivityKind: String, Codable, Equatable {
    case none
    case fixedQuota
    case windowedQuota
    case moneyBalance
    case recovered
}

struct QuotaActivitySummary: Equatable {
    var kind: QuotaActivityKind
    var periodName: String?
    var currentText: String?
    var activityText: String?
    var deltaText: String?
    var consumedPercentPoints: Double?
    var consumedUnits: Int?
    var usedFraction: Double?
    var shouldRender: Bool

    static let empty = QuotaActivitySummary(
        kind: .none,
        periodName: nil,
        currentText: nil,
        activityText: nil,
        deltaText: nil,
        consumedPercentPoints: nil,
        consumedUnits: nil,
        usedFraction: nil,
        shouldRender: false
    )

    static func activitySummary(
        for key: APIKey,
        snapshots: [QuotaSnapshot],
        now: Date = Date(),
        language: AppLanguage = AppLanguageStore.shared.language
    ) -> QuotaActivitySummary {
        if key.provider.usesMoneyBalance {
            return moneyBalanceActivity(for: key, snapshots: snapshots, now: now, language: language)
        }

        let windowNames = activityWindowNames(for: key)
        if !windowNames.isEmpty {
            return windowedQuotaActivity(for: key, snapshots: snapshots, windowNames: windowNames, now: now, language: language)
        }

        return fixedQuotaActivity(for: key, snapshots: snapshots, now: now, language: language)
    }

    private static func fixedQuotaActivity(
        for key: APIKey,
        snapshots: [QuotaSnapshot],
        now: Date,
        language: AppLanguage
    ) -> QuotaActivitySummary {
        let comparableSnapshots = snapshots
            .filter { matchesQuotaHistoryScope($0, key: key) && $0.recordedAt <= now && $0.isComparableQuotaSnapshot }
            .sorted { $0.recordedAt < $1.recordedAt }
        let currentResetSegment = latestQuotaResetSegment(from: comparableSnapshots) { $0.resetAt }

        guard let latestSnapshot = comparableSnapshots.last,
              let latestPercent = latestSnapshot.percentRemaining else {
            return empty
        }

        guard currentResetSegment.count >= 2,
              let previousSnapshot = currentResetSegment.dropLast().last,
              let previousPercent = previousSnapshot.percentRemaining else {
            if hasQuotaResetBoundaryBeforeLatest(in: comparableSnapshots, resetAt: { $0.resetAt }) {
                return recoveredActivity(
                    periodName: nil,
                    currentText: key.remainingBadgeText,
                    activityText: L10n.t(.quotaRefreshDeltaRecovered, language: language),
                    language: language
                )
            }
            return empty
        }

        if latestPercent - previousPercent >= 1 {
            return recoveredActivity(
                periodName: nil,
                currentText: key.remainingBadgeText,
                activityText: L10n.t(.quotaRefreshDeltaRecovered, language: language),
                language: language
            )
        }

        let consumedPercentPoints = previousPercent - latestPercent
        guard consumedPercentPoints >= 1 else {
            return empty
        }

        let consumedUnits: Int?
        if previousSnapshot.limit == latestSnapshot.limit,
           let previousRemaining = previousSnapshot.remaining,
           let latestRemaining = latestSnapshot.remaining,
           previousRemaining >= latestRemaining {
            consumedUnits = previousRemaining - latestRemaining
        } else {
            consumedUnits = nil
        }

        let deltaText: String
        if let consumedUnits, consumedUnits > 0 {
            deltaText = "-\(consumedUnits)"
        } else {
            deltaText = "-\(L10n.percentPointDelta(consumedPercentPoints))"
        }

        let activityText: String
        if let consumedUnits, consumedUnits > 0 {
            activityText = L10n.format(.quotaRefreshDeltaConsumed, "\(consumedUnits)", language: language)
        } else {
            activityText = L10n.format(.quotaRefreshDeltaConsumed, L10n.percentPointDelta(consumedPercentPoints), language: language)
        }

        let usedFraction = max(0, min(1, 1 - latestPercent / 100))

        return QuotaActivitySummary(
            kind: .fixedQuota,
            periodName: nil,
            currentText: key.remainingBadgeText,
            activityText: activityText,
            deltaText: deltaText,
            consumedPercentPoints: consumedPercentPoints,
            consumedUnits: consumedUnits,
            usedFraction: usedFraction,
            shouldRender: true
        )
    }

    private static func windowedQuotaActivity(
        for key: APIKey,
        snapshots: [QuotaSnapshot],
        windowNames: [String],
        now: Date,
        language: AppLanguage
    ) -> QuotaActivitySummary {
        for windowName in windowNames {
            let summary = windowedQuotaActivity(for: key, snapshots: snapshots, windowName: windowName, now: now, language: language)
            if summary.shouldRender {
                return summary
            }
        }
        return empty
    }

    private static func windowedQuotaActivity(
        for key: APIKey,
        snapshots: [QuotaSnapshot],
        windowName: String,
        now: Date,
        language: AppLanguage
    ) -> QuotaActivitySummary {
        let windowSnapshots = snapshots
            .filter { matchesQuotaHistoryScope($0, key: key) && $0.recordedAt <= now && $0.outcome == .success }
            .sorted { $0.recordedAt < $1.recordedAt }
            .compactMap { snapshot -> (snapshot: QuotaSnapshot, window: QuotaWindowSnapshot)? in
                snapshot.quotaWindow(named: windowName).map { (snapshot, $0) }
            }

        guard let latest = windowSnapshots.last else { return empty }
        let periodName = latest.window.name
        let usedFraction = max(0, min(1, 1 - latest.window.remainingPercent / 100))
        let currentWindowText = L10n.percentPoints(latest.window.remainingPercent)
        let currentResetSegment = latestQuotaResetSegment(from: windowSnapshots) { $0.window.resetAt }

        guard currentResetSegment.count >= 2,
              let previous = currentResetSegment.dropLast().last else {
            if hasQuotaResetBoundaryBeforeLatest(in: windowSnapshots, resetAt: { $0.window.resetAt }) {
                return recoveredActivity(
                    periodName: periodName,
                    currentText: currentWindowText,
                    activityText: L10n.t(.quotaRefreshDeltaRecovered, language: language),
                    language: language
                )
            }
            return QuotaActivitySummary(
                kind: .windowedQuota,
                periodName: periodName,
                currentText: currentWindowText,
                activityText: nil,
                deltaText: nil,
                consumedPercentPoints: nil,
                consumedUnits: nil,
                usedFraction: usedFraction,
                shouldRender: false
            )
        }

        if latest.window.remainingPercent - previous.window.remainingPercent >= 1 {
            return recoveredActivity(
                periodName: periodName,
                currentText: currentWindowText,
                activityText: L10n.t(.quotaRefreshDeltaRecovered, language: language),
                language: language
            )
        }

        let consumedPercentPoints = previous.window.remainingPercent - latest.window.remainingPercent
        guard consumedPercentPoints >= 1 else {
            return QuotaActivitySummary(
                kind: .windowedQuota,
                periodName: periodName,
                currentText: currentWindowText,
                activityText: nil,
                deltaText: nil,
                consumedPercentPoints: nil,
                consumedUnits: nil,
                usedFraction: usedFraction,
                shouldRender: false
            )
        }

        let deltaText = "-\(L10n.percentPointDelta(consumedPercentPoints))"
        return QuotaActivitySummary(
            kind: .windowedQuota,
            periodName: periodName,
            currentText: currentWindowText,
            activityText: L10n.format(.quotaRefreshDeltaConsumed, L10n.percentPointDelta(consumedPercentPoints), language: language),
            deltaText: deltaText,
            consumedPercentPoints: consumedPercentPoints,
            consumedUnits: nil,
            usedFraction: usedFraction,
            shouldRender: true
        )
    }

    private static func moneyBalanceActivity(
        for key: APIKey,
        snapshots: [QuotaSnapshot],
        now: Date,
        language: AppLanguage
    ) -> QuotaActivitySummary {
        let balanceSnapshots = snapshots
            .filter { matchesQuotaHistoryScope($0, key: key) && $0.recordedAt <= now && $0.outcome == .success && $0.remaining != nil }
            .sorted { $0.recordedAt < $1.recordedAt }

        let recentCutoff = now.addingTimeInterval(-QuotaTrendSummary.recentWindow)
        let recentSnapshots = balanceSnapshots.filter { $0.recordedAt >= recentCutoff }
        let activitySnapshots = recentSnapshots.count >= 2 ? recentSnapshots : balanceSnapshots

        guard activitySnapshots.count >= 2,
              let latestRemaining = activitySnapshots.last?.remaining else {
            return empty
        }

        let topUpThresholdCents = 100
        var latestLargeTopUp: (previous: Int, replenished: Int)?
        for (previous, latest) in zip(activitySnapshots, activitySnapshots.dropFirst()) {
            guard let previousRemaining = previous.remaining,
                  let latestRemaining = latest.remaining else { continue }
            let replenished = latestRemaining - previousRemaining
            if replenished >= topUpThresholdCents {
                latestLargeTopUp = (previousRemaining, latestRemaining)
            }
        }

        if let latestLargeTopUp {
            let spentSinceTopUp = max(0, latestLargeTopUp.replenished - latestRemaining)
            let meaningfulPostTopUpSpend = max(
                topUpThresholdCents,
                Int((Double(latestLargeTopUp.replenished) * 0.01).rounded(.up))
            )
            if spentSinceTopUp < meaningfulPostTopUpSpend {
                return recoveredActivity(periodName: "balance", currentText: key.remainingBadgeText, language: language)
            }
            if spentSinceTopUp > 0 {
                let spentText = moneyText(cents: spentSinceTopUp, language: language)
                return QuotaActivitySummary(
                    kind: .moneyBalance,
                    periodName: "balance",
                    currentText: key.remainingBadgeText,
                    activityText: L10n.format(.quotaRefreshDeltaConsumed, spentText, language: language),
                    deltaText: "-\(spentText)",
                    consumedPercentPoints: nil,
                    consumedUnits: spentSinceTopUp,
                    usedFraction: nil,
                    shouldRender: true
                )
            }
        }

        guard let latestChange = zip(activitySnapshots, activitySnapshots.dropFirst()).reversed().first(where: { previous, latest in
            previous.remaining != latest.remaining
        }),
              let previousRemaining = latestChange.0.remaining,
              let changedRemaining = latestChange.1.remaining else {
            return empty
        }

        let spent = previousRemaining - changedRemaining
        guard spent > 0 else {
            if changedRemaining > previousRemaining {
                return recoveredActivity(periodName: "balance", currentText: key.remainingBadgeText, language: language)
            }
            return empty
        }

        let spentText = moneyText(cents: spent, language: language)
        return QuotaActivitySummary(
            kind: .moneyBalance,
            periodName: "balance",
            currentText: key.remainingBadgeText,
            activityText: L10n.format(.quotaRefreshDeltaConsumed, spentText, language: language),
            deltaText: "-\(spentText)",
            consumedPercentPoints: nil,
            consumedUnits: spent,
            usedFraction: nil,
            shouldRender: true
        )
    }

    private static func recoveredActivity(
        periodName: String?,
        currentText: String?,
        activityText: String? = nil,
        language: AppLanguage
    ) -> QuotaActivitySummary {
        QuotaActivitySummary(
            kind: .recovered,
            periodName: periodName,
            currentText: currentText,
            activityText: activityText ?? L10n.t(.quotaTrendReplenished, language: language),
            deltaText: nil,
            consumedPercentPoints: nil,
            consumedUnits: nil,
            usedFraction: nil,
            shouldRender: true
        )
    }

    private static func activityWindowNames(for key: APIKey) -> [String] {
        var seenNormalizedNames = Set<String>()
        return key.quotaWindowDetails
            .compactMap { window -> (name: String, normalizedName: String, rank: Int)? in
                guard QuotaWindowSnapshot.percent(from: window.percentText) != nil else { return nil }
                return (window.name, QuotaWindowSnapshot.normalizedName(window.name), quotaWindowDurationRank(window.name))
            }
            .sorted { lhs, rhs in
                if lhs.rank != rhs.rank {
                    return lhs.rank > rhs.rank
                }
                return lhs.name < rhs.name
            }
            .compactMap { window in
                guard !seenNormalizedNames.contains(window.normalizedName) else { return nil }
                seenNormalizedNames.insert(window.normalizedName)
                return window.name
            }
    }

    private static func quotaWindowDurationRank(_ name: String) -> Int {
        switch QuotaWindowSnapshot.normalizedName(name) {
        case "month", "monthly", "package", "package-period", "package period", "total", "总", "月":
            return 300
        case "week", "weekly", "7d", "seven_day", "seven-day", "7-day", "周":
            return 200
        case "5h", "five_hour", "five-hour", "5-hour", "5hour", "5 小时", "5小时":
            return 100
        default:
            return 0
        }
    }

    private static func moneyText(cents: Int, language: AppLanguage) -> String {
        switch language {
        case .english:
            return String(format: "CNY %.2f", Double(cents) / 100.0)
        case .simplifiedChinese, .traditionalChinese, .japanese, .korean:
            return APIKey.formatCNYCents(cents)
        }
    }

}

struct QuotaConsumptionSpeedSummary: Equatable {
    private static let lowQuotaThresholdPercent = 20.0
    private static let minimumConsumedPercentPoints = 10.0
    private static let minimumPercentPointsPerDay = 8.0
    private static let maximumProjectedDaysToLowQuota = 3.0
    private static let minimumObservationSpan: TimeInterval = 30 * 60

    var periodName: String?
    var hintText: String?
    var consumedPercentPoints: Double
    var percentPointsPerDay: Double
    var projectedDaysToLowQuota: Double?
    var observationCount: Int
    var shouldRender: Bool

    static let empty = QuotaConsumptionSpeedSummary(
        periodName: nil,
        hintText: nil,
        consumedPercentPoints: 0,
        percentPointsPerDay: 0,
        projectedDaysToLowQuota: nil,
        observationCount: 0,
        shouldRender: false
    )

    static func speedSummary(
        for key: APIKey,
        snapshots: [QuotaSnapshot],
        now: Date = Date(),
        language: AppLanguage = AppLanguageStore.shared.language
    ) -> QuotaConsumptionSpeedSummary {
        guard !key.provider.usesMoneyBalance else { return empty }

        let windowNames = speedWindowNames(for: key)
        if !windowNames.isEmpty {
            for windowName in windowNames {
                let summary = windowedSpeedSummary(
                    for: key,
                    snapshots: snapshots,
                    windowName: windowName,
                    now: now,
                    language: language
                )
                if summary.shouldRender {
                    return summary
                }
            }
            return empty
        }

        return fixedSpeedSummary(for: key, snapshots: snapshots, now: now, language: language)
    }

    private static func fixedSpeedSummary(
        for key: APIKey,
        snapshots: [QuotaSnapshot],
        now: Date,
        language: AppLanguage
    ) -> QuotaConsumptionSpeedSummary {
        let comparableSnapshots = snapshots
            .filter { matchesQuotaHistoryScope($0, key: key) && $0.recordedAt <= now && $0.isComparableQuotaSnapshot }
            .sorted { $0.recordedAt < $1.recordedAt }
        let currentResetSegment = latestQuotaResetSegment(from: comparableSnapshots) { $0.resetAt }
        let selectedSnapshots = selectedComparableSnapshots(from: currentResetSegment, now: now)

        guard selectedSnapshots.count >= 2,
              let firstSnapshot = selectedSnapshots.first,
              let latestSnapshot = selectedSnapshots.last,
              let firstPercent = firstSnapshot.percentRemaining,
              let latestPercent = latestSnapshot.percentRemaining else {
            return empty
        }

        return projectedSpeedSummary(
            periodName: nil,
            firstRecordedAt: firstSnapshot.recordedAt,
            latestRecordedAt: latestSnapshot.recordedAt,
            firstPercent: firstPercent,
            latestPercent: latestPercent,
            observationCount: selectedSnapshots.count,
            language: language
        )
    }

    private static func windowedSpeedSummary(
        for key: APIKey,
        snapshots: [QuotaSnapshot],
        windowName: String,
        now: Date,
        language: AppLanguage
    ) -> QuotaConsumptionSpeedSummary {
        let windowSnapshots = snapshots
            .filter { matchesQuotaHistoryScope($0, key: key) && $0.recordedAt <= now && $0.outcome == .success }
            .sorted { $0.recordedAt < $1.recordedAt }
            .compactMap { snapshot -> (snapshot: QuotaSnapshot, window: QuotaWindowSnapshot)? in
                snapshot.quotaWindow(named: windowName).map { (snapshot, $0) }
            }
        let currentResetSegment = latestQuotaResetSegment(from: windowSnapshots) { $0.window.resetAt }
        let selectedSnapshots = selectedWindowSnapshots(from: currentResetSegment, now: now)

        guard selectedSnapshots.count >= 2,
              let first = selectedSnapshots.first,
              let latest = selectedSnapshots.last else {
            return empty
        }

        return projectedSpeedSummary(
            periodName: latest.window.name,
            firstRecordedAt: first.snapshot.recordedAt,
            latestRecordedAt: latest.snapshot.recordedAt,
            firstPercent: first.window.remainingPercent,
            latestPercent: latest.window.remainingPercent,
            observationCount: selectedSnapshots.count,
            language: language
        )
    }

    private static func projectedSpeedSummary(
        periodName: String?,
        firstRecordedAt: Date,
        latestRecordedAt: Date,
        firstPercent: Double,
        latestPercent: Double,
        observationCount: Int,
        language: AppLanguage
    ) -> QuotaConsumptionSpeedSummary {
        let observationSpan = latestRecordedAt.timeIntervalSince(firstRecordedAt)
        guard observationSpan >= minimumObservationSpan else { return empty }

        let consumedPercentPoints = firstPercent - latestPercent
        guard consumedPercentPoints >= minimumConsumedPercentPoints else { return empty }

        let days = max(observationSpan / (24 * 60 * 60), 1.0 / 24.0)
        let percentPointsPerDay = consumedPercentPoints / days
        guard percentPointsPerDay >= minimumPercentPointsPerDay else { return empty }

        let projectedDaysToLowQuota: Double?
        if latestPercent > lowQuotaThresholdPercent {
            projectedDaysToLowQuota = (latestPercent - lowQuotaThresholdPercent) / percentPointsPerDay
        } else {
            projectedDaysToLowQuota = 0
        }

        guard let projectedDaysToLowQuota,
              projectedDaysToLowQuota <= maximumProjectedDaysToLowQuota else {
            return empty
        }

        return QuotaConsumptionSpeedSummary(
            periodName: periodName,
            hintText: L10n.t(.quotaSpeedFastUse, language: language),
            consumedPercentPoints: consumedPercentPoints,
            percentPointsPerDay: percentPointsPerDay,
            projectedDaysToLowQuota: projectedDaysToLowQuota,
            observationCount: observationCount,
            shouldRender: true
        )
    }

    private static func selectedComparableSnapshots(from snapshots: [QuotaSnapshot], now: Date) -> [QuotaSnapshot] {
        let recentCutoff = now.addingTimeInterval(-QuotaTrendSummary.recentWindow)
        let recentSnapshots = snapshots.filter { $0.recordedAt >= recentCutoff }
        let selected = recentSnapshots.count >= 2 ? recentSnapshots : Array(snapshots.suffix(5))
        return selected
    }

    private static func selectedWindowSnapshots(
        from snapshots: [(snapshot: QuotaSnapshot, window: QuotaWindowSnapshot)],
        now: Date
    ) -> [(snapshot: QuotaSnapshot, window: QuotaWindowSnapshot)] {
        let recentCutoff = now.addingTimeInterval(-QuotaTrendSummary.recentWindow)
        let recentSnapshots = snapshots.filter { $0.snapshot.recordedAt >= recentCutoff }
        let selected = recentSnapshots.count >= 2 ? recentSnapshots : Array(snapshots.suffix(5))
        return selected
    }

    private static func speedWindowNames(for key: APIKey) -> [String] {
        var seenNormalizedNames = Set<String>()
        return key.quotaWindowDetails
            .compactMap { window -> (name: String, normalizedName: String, rank: Int)? in
                guard QuotaWindowSnapshot.percent(from: window.percentText) != nil else { return nil }
                return (window.name, QuotaWindowSnapshot.normalizedName(window.name), quotaWindowDurationRank(window.name))
            }
            .sorted { lhs, rhs in
                if lhs.rank != rhs.rank {
                    return lhs.rank > rhs.rank
                }
                return lhs.name < rhs.name
            }
            .compactMap { window in
                guard !seenNormalizedNames.contains(window.normalizedName) else { return nil }
                seenNormalizedNames.insert(window.normalizedName)
                return window.name
            }
    }

    private static func quotaWindowDurationRank(_ name: String) -> Int {
        switch QuotaWindowSnapshot.normalizedName(name) {
        case "month", "monthly", "package", "package-period", "package period", "total", "总", "月":
            return 300
        case "week", "weekly", "7d", "seven_day", "seven-day", "7-day", "周":
            return 200
        case "5h", "five_hour", "five-hour", "5-hour", "5hour", "5 小时", "5小时":
            return 100
        default:
            return 0
        }
    }
}

struct QuotaRefreshDeltaSummary: Equatable {
    static let recentRefreshWindow: TimeInterval = 15 * 60

    let refreshDeltaText: String

    static func refreshDeltaText(
        for key: APIKey,
        snapshots: [QuotaSnapshot],
        now: Date = Date(),
        language: AppLanguage = AppLanguageStore.shared.language
    ) -> String? {
        refreshDeltaSummary(for: key, snapshots: snapshots, now: now, language: language)?.refreshDeltaText
    }

    static func refreshDeltaSummary(
        for key: APIKey,
        snapshots: [QuotaSnapshot],
        now: Date = Date(),
        language: AppLanguage = AppLanguageStore.shared.language
    ) -> QuotaRefreshDeltaSummary? {
        let keySnapshots = snapshots
            .filter { matchesQuotaHistoryScope($0, key: key) && $0.recordedAt <= now }
            .sorted { $0.recordedAt < $1.recordedAt }

        guard let latestSnapshot = keySnapshots.last,
              now.timeIntervalSince(latestSnapshot.recordedAt) <= recentRefreshWindow else {
            return nil
        }

        guard latestSnapshot.outcome == .success else {
            return QuotaRefreshDeltaSummary(
                refreshDeltaText: L10n.t(.quotaRefreshDeltaFailed, language: language)
            )
        }

        guard let previousSnapshot = keySnapshots.dropLast().last,
              previousSnapshot.isComparableQuotaSnapshot,
              latestSnapshot.isComparableQuotaSnapshot,
              let previousPercent = previousSnapshot.percentRemaining,
              let latestPercent = latestSnapshot.percentRemaining else {
            return nil
        }

        if latestPercent - previousPercent >= 1 {
            return QuotaRefreshDeltaSummary(
                refreshDeltaText: L10n.t(.quotaRefreshDeltaRecovered, language: language)
            )
        }

        if previousSnapshot.resetAt != latestSnapshot.resetAt,
           let previousRemaining = previousSnapshot.remaining,
           let latestRemaining = latestSnapshot.remaining,
           latestRemaining >= previousRemaining {
            return QuotaRefreshDeltaSummary(
                refreshDeltaText: L10n.t(.quotaRefreshDeltaRecovered, language: language)
            )
        }

        if previousSnapshot.limit == latestSnapshot.limit,
           let previousRemaining = previousSnapshot.remaining,
           let latestRemaining = latestSnapshot.remaining,
           previousRemaining > latestRemaining {
            return QuotaRefreshDeltaSummary(
                refreshDeltaText: L10n.format(
                    .quotaRefreshDeltaConsumed,
                    "\(previousRemaining - latestRemaining)",
                    language: language
                )
            )
        }

        let consumedPercentPoints = previousPercent - latestPercent
        if consumedPercentPoints >= 1 {
            return QuotaRefreshDeltaSummary(
                refreshDeltaText: L10n.format(
                    .quotaRefreshDeltaConsumed,
                    L10n.percentPointDelta(consumedPercentPoints),
                    language: language
                )
            )
        }

        return QuotaRefreshDeltaSummary(
            refreshDeltaText: L10n.t(.quotaRefreshDeltaNoChange, language: language)
        )
    }
}

enum QuotaRefreshHistoryKind: String, Codable, Equatable {
    case noChange
    case consumed
    case recovered
    case failed
    case unauthorized
    case unsupported
    case noSubscription
    case skipped
}

struct QuotaRefreshHistoryItem: Equatable, Identifiable {
    var recordedAt: Date
    var kind: QuotaRefreshHistoryKind
    var primaryText: String
    var valueText: String?
    var deltaText: String?
    var detailText: String?
    var httpStatusText: String?
    var repeatCount: Int = 1

    var id: String {
        "\(recordedAt.timeIntervalSince1970)-\(kind.rawValue)-\(primaryText)-\(repeatCount)"
    }

    static func items(
        for key: APIKey,
        snapshots: [QuotaSnapshot],
        limit: Int = 4,
        now: Date = Date(),
        language: AppLanguage = AppLanguageStore.shared.language
    ) -> [QuotaRefreshHistoryItem] {
        let orderedSnapshots = snapshots
            .filter { matchesQuotaHistoryScope($0, key: key) && $0.recordedAt <= now }
            .sorted { $0.recordedAt < $1.recordedAt }

        var previousSuccess: QuotaSnapshot?
        var chronologicalItems: [QuotaRefreshHistoryItem] = []

        for snapshot in orderedSnapshots {
            if snapshot.outcome == .success {
                guard let previousSuccessSnapshot = previousSuccess else {
                    previousSuccess = snapshot
                    continue
                }
                chronologicalItems.append(
                    successItem(
                        current: snapshot,
                        previous: previousSuccessSnapshot,
                        key: key,
                        language: language
                    )
                )
                previousSuccess = snapshot
            } else {
                chronologicalItems.append(nonSuccessItem(for: snapshot, key: key, language: language))
            }
        }

        let collapsedItems = collapseNoChangeRuns(chronologicalItems)
        return Array(collapsedItems.reversed().prefix(max(0, limit)))
    }

    private static func collapseNoChangeRuns(_ items: [QuotaRefreshHistoryItem]) -> [QuotaRefreshHistoryItem] {
        var collapsed: [QuotaRefreshHistoryItem] = []

        for item in items {
            if item.kind == .noChange,
               let lastIndex = collapsed.indices.last,
               collapsed[lastIndex].kind == .noChange {
                collapsed[lastIndex].recordedAt = item.recordedAt
                collapsed[lastIndex].valueText = item.valueText
                collapsed[lastIndex].detailText = item.detailText
                collapsed[lastIndex].httpStatusText = item.httpStatusText
                collapsed[lastIndex].repeatCount += item.repeatCount
            } else {
                collapsed.append(item)
            }
        }

        return collapsed
    }

    private static func successItem(
        current: QuotaSnapshot,
        previous: QuotaSnapshot,
        key: APIKey,
        language: AppLanguage
    ) -> QuotaRefreshHistoryItem {
        let valueText = refreshedValueText(for: current, key: key, language: language)

        if isRecovered(current: current, previous: previous, key: key) {
            return QuotaRefreshHistoryItem(
                recordedAt: current.recordedAt,
                kind: .recovered,
                primaryText: L10n.t(.quotaRefreshDeltaRecovered, language: language),
                valueText: valueText,
                detailText: current.quotaLabel,
                httpStatusText: httpStatusText(for: current, language: language)
            )
        }

        if let deltaText = consumedDeltaText(current: current, previous: previous, key: key, language: language) {
            return QuotaRefreshHistoryItem(
                recordedAt: current.recordedAt,
                kind: .consumed,
                primaryText: L10n.format(
                    .quotaRefreshDeltaConsumed,
                    String(deltaText.dropFirst()),
                    language: language
                ),
                valueText: valueText,
                deltaText: deltaText,
                detailText: current.quotaLabel,
                httpStatusText: httpStatusText(for: current, language: language)
            )
        }

        return QuotaRefreshHistoryItem(
            recordedAt: current.recordedAt,
            kind: .noChange,
            primaryText: L10n.t(.quotaRefreshDeltaNoChange, language: language),
            valueText: valueText,
            detailText: current.quotaLabel,
            httpStatusText: httpStatusText(for: current, language: language)
        )
    }

    private static func nonSuccessItem(
        for snapshot: QuotaSnapshot,
        key: APIKey,
        language: AppLanguage
    ) -> QuotaRefreshHistoryItem {
        let kind: QuotaRefreshHistoryKind
        let primaryText: String

        switch snapshot.outcome {
        case .success:
            kind = .noChange
            primaryText = L10n.t(.quotaRefreshDeltaNoChange, language: language)
        case .unsupported:
            kind = .unsupported
            primaryText = L10n.t(.quotaUnavailable, language: language)
        case .unauthorized:
            kind = .unauthorized
            primaryText = key.provider.supportsDashboardReauthentication
                ? L10n.t(.credentialExpired, language: language)
                : L10n.t(.quotaErrorInvalidAPIKey, language: language)
        case .noSubscription:
            kind = .noSubscription
            primaryText = L10n.t(.noSubscribedPlan, language: language)
        case .failed:
            kind = .failed
            primaryText = L10n.t(.quotaRefreshDeltaFailed, language: language)
        case .skipped:
            kind = .skipped
            primaryText = L10n.t(.automaticRefreshSkipped, language: language)
        }

        return QuotaRefreshHistoryItem(
            recordedAt: snapshot.recordedAt,
            kind: kind,
            primaryText: primaryText,
            valueText: refreshedValueText(for: snapshot, key: key, language: language),
            detailText: snapshot.quotaLabel,
            httpStatusText: httpStatusText(for: snapshot, language: language)
        )
    }

    private static func isRecovered(current: QuotaSnapshot, previous: QuotaSnapshot, key: APIKey) -> Bool {
        if quotaResetBoundaryChanged(current: current, previous: previous, key: key) {
            return true
        }

        if key.provider.usesMoneyBalance,
           let currentRemaining = current.remaining,
           let previousRemaining = previous.remaining {
            return currentRemaining > previousRemaining
        }

        if let currentWindow = selectedWindowSnapshot(from: current, key: key),
           let previousWindow = previous.quotaWindow(named: currentWindow.name) {
            return currentWindow.remainingPercent - previousWindow.remainingPercent >= 1
        }

        if let currentPercent = current.percentRemaining,
           let previousPercent = previous.percentRemaining {
            return currentPercent - previousPercent >= 1
        }

        return false
    }

    private static func consumedDeltaText(
        current: QuotaSnapshot,
        previous: QuotaSnapshot,
        key: APIKey,
        language: AppLanguage
    ) -> String? {
        if key.provider.usesMoneyBalance,
           let currentRemaining = current.remaining,
           let previousRemaining = previous.remaining,
           previousRemaining > currentRemaining {
            return "-\(moneyText(cents: previousRemaining - currentRemaining, language: language))"
        }

        if let currentWindow = selectedWindowSnapshot(from: current, key: key),
           let previousWindow = previous.quotaWindow(named: currentWindow.name) {
            let consumedPercentPoints = previousWindow.remainingPercent - currentWindow.remainingPercent
            if consumedPercentPoints >= 1 {
                return "-\(L10n.percentPointDelta(consumedPercentPoints))"
            }
        }

        if current.limit == previous.limit,
           let currentRemaining = current.remaining,
           let previousRemaining = previous.remaining,
           previousRemaining > currentRemaining {
            return "-\(previousRemaining - currentRemaining)"
        }

        if let currentPercent = current.percentRemaining,
           let previousPercent = previous.percentRemaining {
            let consumedPercentPoints = previousPercent - currentPercent
            if consumedPercentPoints >= 1 {
                return "-\(L10n.percentPointDelta(consumedPercentPoints))"
            }
        }

        return nil
    }

    private static func quotaResetBoundaryChanged(
        current: QuotaSnapshot,
        previous: QuotaSnapshot,
        key: APIKey
    ) -> Bool {
        if !quotaResetMatches(previous.resetAt, current.resetAt) {
            return true
        }

        guard let currentWindow = selectedWindowSnapshot(from: current, key: key),
              let previousWindow = previous.quotaWindow(named: currentWindow.name) else {
            return false
        }

        return !quotaResetMatches(previousWindow.resetAt, currentWindow.resetAt)
    }

    private static func selectedWindowSnapshot(from snapshot: QuotaSnapshot, key: APIKey) -> QuotaWindowSnapshot? {
        if let preferredName = largestQuotaWindowName(for: key),
           let preferredWindow = snapshot.quotaWindow(named: preferredName) {
            return preferredWindow
        }

        return snapshot.quotaWindows
            .filter { $0.remainingPercent.isFinite }
            .max { lhs, rhs in
                let lhsRank = quotaWindowDurationRank(lhs.name)
                let rhsRank = quotaWindowDurationRank(rhs.name)
                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }
                return lhs.name < rhs.name
            }
    }

    private static func largestQuotaWindowName(for key: APIKey) -> String? {
        key.quotaWindowDetails
            .compactMap { window -> (name: String, rank: Int)? in
                guard QuotaWindowSnapshot.percent(from: window.percentText) != nil else { return nil }
                return (window.name, quotaWindowDurationRank(window.name))
            }
            .max { lhs, rhs in
                if lhs.rank != rhs.rank {
                    return lhs.rank < rhs.rank
                }
                return lhs.name < rhs.name
            }?
            .name
    }

    private static func quotaWindowDurationRank(_ name: String) -> Int {
        switch QuotaWindowSnapshot.normalizedName(name) {
        case "month", "monthly", "package", "package-period", "package period", "total", "总", "月":
            return 300
        case "week", "weekly", "7d", "seven_day", "seven-day", "7-day", "周":
            return 200
        case "5h", "five_hour", "five-hour", "5-hour", "5hour", "5 小时", "5小时":
            return 100
        default:
            return 0
        }
    }

    private static func refreshedValueText(for snapshot: QuotaSnapshot, key: APIKey, language: AppLanguage) -> String? {
        if key.provider.usesMoneyBalance, let remaining = snapshot.remaining {
            return moneyText(cents: remaining, language: language)
        }

        if let window = selectedWindowSnapshot(from: snapshot, key: key) {
            return L10n.percentPoints(window.remainingPercent)
        }

        if let remaining = snapshot.remaining, let limit = snapshot.limit {
            return "\(remaining) / \(limit)"
        }

        if let remaining = snapshot.remaining {
            return "\(remaining)"
        }

        return snapshot.quotaLabel
    }

    private static func httpStatusText(for snapshot: QuotaSnapshot, language: AppLanguage) -> String? {
        if let httpStatus = snapshot.httpStatus {
            return "HTTP \(httpStatus)"
        }
        if snapshot.outcome == .skipped {
            return L10n.t(.httpNotRequested, language: language)
        }
        return nil
    }

    private static func moneyText(cents: Int, language: AppLanguage) -> String {
        switch language {
        case .english:
            return String(format: "CNY %.2f", Double(cents) / 100.0)
        case .simplifiedChinese, .traditionalChinese, .japanese, .korean:
            return APIKey.formatCNYCents(cents)
        }
    }
}

struct MenuQuotaSignalLayout: Equatable {
    let watchedProviderItems: [MenuQuotaItem]
    let attentionItems: [MenuQuotaItem]
    let lowQuotaItems: [MenuQuotaItem]
    let expiringSoonItems: [MenuQuotaItem]
    let recentUsageItems: [MenuQuotaItem]
    let hiddenItemCount: Int

    var visibleItems: [MenuQuotaItem] {
        attentionItems + lowQuotaItems + expiringSoonItems + recentUsageItems
    }

    static func make(
        from stats: [ProviderStats],
        snapshots: [QuotaSnapshot],
        visibleLimit: Int,
        providerOrder: [Provider] = Provider.visibleCases,
        watchedProviders: [Provider] = [],
        now: Date = Date()
    ) -> MenuQuotaSignalLayout {
        let boundedLimit = max(0, visibleLimit)
        let watchedProviderItems = MenuQuotaItem.watchedProviderItems(
            from: stats,
            watchedProviders: watchedProviders,
            limit: 2,
            providerOrder: providerOrder
        )
        let watchedProviderIDs = Set(watchedProviderItems.map(\.provider))

        let attentionCandidates = MenuQuotaItem.attentionItems(
            from: stats,
            limit: Int.max,
            providerOrder: providerOrder
        )
        .filter { !watchedProviderIDs.contains($0.provider) }
        .sorted { shouldRankSignal($0, before: $1, providerOrder: providerOrder) }
        let groupedAttentionCandidates = collapseProviderSignalGroups(attentionCandidates)
        let attentionIDs = Set(groupedAttentionCandidates.map(\.id))
        let attentionProviderIDs = Set(groupedAttentionCandidates.map(\.provider))

        let lowQuotaCandidates = MenuQuotaItem.lowQuotaItems(
            from: stats,
            limit: Int.max,
            providerOrder: providerOrder
        )
        .filter { !watchedProviderIDs.contains($0.provider) && !attentionProviderIDs.contains($0.provider) }
        let groupedLowQuotaCandidates = collapseProviderSignalGroups(lowQuotaCandidates)
        let lowQuotaIDs = Set(groupedLowQuotaCandidates.map(\.id))
        let lowQuotaProviderIDs = Set(groupedLowQuotaCandidates.map(\.provider))

        let expiringSoonCandidates = MenuQuotaItem.expiringSoonItems(
            from: stats,
            limit: Int.max,
            providerOrder: providerOrder
        )
        .filter {
            !watchedProviderIDs.contains($0.provider)
                && !attentionProviderIDs.contains($0.provider)
                && !lowQuotaProviderIDs.contains($0.provider)
        }
        let groupedExpiringSoonCandidates = collapseProviderSignalGroups(expiringSoonCandidates)
        let expiringSoonIDs = Set(groupedExpiringSoonCandidates.map(\.id))
        let expiringSoonProviderIDs = Set(groupedExpiringSoonCandidates.map(\.provider))

        let riskCandidateIDs = attentionIDs.union(lowQuotaIDs).union(expiringSoonIDs)
        let riskProviderIDs = attentionProviderIDs
            .union(lowQuotaProviderIDs)
            .union(expiringSoonProviderIDs)
            .union(watchedProviderIDs)
        let recentUsageCandidates = MenuQuotaItem.recentProviderUsageItems(
            from: stats,
            snapshots: snapshots,
            limit: Int.max,
            providerOrder: providerOrder,
            excluding: riskCandidateIDs,
            excludingProviders: riskProviderIDs,
            now: now
        )

        var remainingSlots = boundedLimit
        let visibleAttentionItems = takeVisible(groupedAttentionCandidates, remainingSlots: &remainingSlots)
        let visibleLowQuotaItems = takeVisible(groupedLowQuotaCandidates, remainingSlots: &remainingSlots)
        let visibleExpiringSoonItems = takeVisible(groupedExpiringSoonCandidates, remainingSlots: &remainingSlots)
        let visibleRecentUsageItems = takeVisible(recentUsageCandidates, remainingSlots: &remainingSlots)

        let totalCandidateCount = groupedAttentionCandidates.count
            + groupedLowQuotaCandidates.count
            + groupedExpiringSoonCandidates.count
            + recentUsageCandidates.count
        let visibleCount = visibleAttentionItems.count
            + visibleLowQuotaItems.count
            + visibleExpiringSoonItems.count
            + visibleRecentUsageItems.count

        return MenuQuotaSignalLayout(
            watchedProviderItems: watchedProviderItems,
            attentionItems: visibleAttentionItems,
            lowQuotaItems: visibleLowQuotaItems,
            expiringSoonItems: visibleExpiringSoonItems,
            recentUsageItems: visibleRecentUsageItems,
            hiddenItemCount: Swift.max(0, totalCandidateCount - visibleCount)
        )
    }

    private static func collapseProviderSignalGroups(_ candidates: [MenuQuotaItem]) -> [MenuQuotaItem] {
        var representatives: [MenuQuotaItem] = []
        var representativeIndexByProvider: [Provider: Int] = [:]
        var countByProvider: [Provider: Int] = [:]

        for candidate in candidates {
            countByProvider[candidate.provider, default: 0] += 1
            guard representativeIndexByProvider[candidate.provider] == nil else {
                continue
            }

            representativeIndexByProvider[candidate.provider] = representatives.count
            representatives.append(candidate)
        }

        return representatives.map { item in
            item.withProviderSignalCount(countByProvider[item.provider] ?? 1)
        }
    }

    private static func takeVisible(_ items: [MenuQuotaItem], remainingSlots: inout Int) -> [MenuQuotaItem] {
        guard remainingSlots > 0, !items.isEmpty else { return [] }
        let visibleCount = min(items.count, remainingSlots)
        remainingSlots -= visibleCount
        return Array(items.prefix(visibleCount))
    }

    private static func shouldRankSignal(
        _ lhs: MenuQuotaItem,
        before rhs: MenuQuotaItem,
        providerOrder: [Provider]
    ) -> Bool {
        let lhsSeverity = signalSeverity(lhs)
        let rhsSeverity = signalSeverity(rhs)
        if lhsSeverity != rhsSeverity {
            return lhsSeverity < rhsSeverity
        }

        let lhsPercent = lhs.presentation.percentRemaining ?? Double.greatestFiniteMagnitude
        let rhsPercent = rhs.presentation.percentRemaining ?? Double.greatestFiniteMagnitude
        if lhsPercent != rhsPercent {
            return lhsPercent < rhsPercent
        }

        let lhsRemaining = lhs.key.remaining ?? Int.max
        let rhsRemaining = rhs.key.remaining ?? Int.max
        if lhsRemaining != rhsRemaining {
            return lhsRemaining < rhsRemaining
        }

        let lhsProviderIndex = providerOrder.firstIndex(of: lhs.provider) ?? Int.max
        let rhsProviderIndex = providerOrder.firstIndex(of: rhs.provider) ?? Int.max
        if lhsProviderIndex != rhsProviderIndex {
            return lhsProviderIndex < rhsProviderIndex
        }

        return lhs.key.name.localizedStandardCompare(rhs.key.name) == .orderedAscending
    }

    private static func signalSeverity(_ item: MenuQuotaItem) -> Int {
        if item.key.isCredentialExpired { return 0 }
        if item.key.status == .failed { return 1 }
        if item.key.isUsageLimitExceeded { return 2 }
        if item.key.isExhausted { return 3 }
        if item.key.isLow { return 4 }
        if item.key.expiresSoonForStatusBar { return 5 }
        if item.signalReason == .recentActivity { return 6 }
        return 7
    }
}

extension MenuQuotaItem {
    private static let minimumMenuRecentUsagePercentPoints = 3.0
    private static let minimumMenuRecentMoneyBalanceCents = 1

    static func watchedProviderItems(
        from stats: [ProviderStats],
        watchedProviders: [Provider],
        limit: Int = 3,
        providerOrder: [Provider] = Provider.visibleCases
    ) -> [MenuQuotaItem] {
        guard limit > 0, !watchedProviders.isEmpty else { return [] }
        let watchedSet = Set(watchedProviders)
        let orderedWatchedProviders = providerOrder.filter { watchedSet.contains($0) }
        let statByProvider = Dictionary(uniqueKeysWithValues: stats.map { ($0.provider, $0) })

        return orderedWatchedProviders
            .compactMap { provider -> MenuQuotaItem? in
                guard
                    let stat = statByProvider[provider],
                    let key = stat.mostConstrainedActiveMonitoringKey,
                    !key.isStoredAPIKeyOnlyCredential
                else {
                    return nil
                }
                return MenuQuotaItem(provider: provider, key: key)
            }
            .prefix(limit)
            .map { $0 }
    }

    static func recentProviderUsageItems(
        from stats: [ProviderStats],
        snapshots: [QuotaSnapshot],
        limit: Int = 3,
        providerOrder: [Provider] = Provider.visibleCases,
        excluding excludedKeyIDs: Set<UUID> = [],
        excludingProviders excludedProviders: Set<Provider> = [],
        now: Date = Date()
    ) -> [MenuQuotaItem] {
        var bestCandidateByProvider: [Provider: RecentProviderUsageCandidate] = [:]
        var countByProvider: [Provider: Int] = [:]

        for stat in stats {
            guard !excludedProviders.contains(stat.provider) else { continue }

            for key in stat.keys where key.isActive && !key.isStoredAPIKeyOnlyCredential && !excludedKeyIDs.contains(key.id) {
                let activitySummary = QuotaActivitySummary.activitySummary(
                    for: key,
                    snapshots: snapshots,
                    now: now,
                    language: .english
                )
                let candidateMetrics = recentActivityMetrics(from: activitySummary)
                guard let candidateMetrics else { continue }
                countByProvider[stat.provider, default: 0] += 1

                let candidate = RecentProviderUsageCandidate(
                    provider: stat.provider,
                    key: key,
                    consumedPercentPoints: candidateMetrics.consumedPercentPoints,
                    consumedUnits: candidateMetrics.consumedUnits,
                    latestActivity: candidateMetrics.latestActivity
                )

                if let existingCandidate = bestCandidateByProvider[stat.provider] {
                    if shouldRankRecentUsage(candidate, before: existingCandidate, providerOrder: providerOrder) {
                        bestCandidateByProvider[stat.provider] = candidate
                    }
                } else {
                    bestCandidateByProvider[stat.provider] = candidate
                }
            }
        }

        return Array(
            bestCandidateByProvider.values
                .sorted { shouldRankRecentUsage($0, before: $1, providerOrder: providerOrder) }
                .prefix(limit)
                .map {
                    MenuQuotaItem(provider: $0.provider, key: $0.key)
                        .withProviderSignalCount(countByProvider[$0.provider] ?? 1)
                }
        )
    }

    private static func recentActivityMetrics(
        from summary: QuotaActivitySummary
    ) -> (consumedPercentPoints: Double, consumedUnits: Int, latestActivity: Date?)? {
        guard summary.shouldRender,
              summary.kind != .recovered,
              let deltaText = summary.deltaText,
              deltaText.hasPrefix("-") else {
            return nil
        }

        if summary.kind == .moneyBalance {
            let cents = summary.consumedUnits ?? moneyDeltaCents(from: deltaText)
            guard cents >= minimumMenuRecentMoneyBalanceCents else { return nil }
            return (0, cents, nil)
        }

        let consumedPercentPoints = summary.consumedPercentPoints ?? 0
        guard consumedPercentPoints >= minimumMenuRecentUsagePercentPoints else {
            return nil
        }
        return (consumedPercentPoints, summary.consumedUnits ?? 0, nil)
    }

    private static func shouldRankRecentUsage(
        _ lhs: RecentProviderUsageCandidate,
        before rhs: RecentProviderUsageCandidate,
        providerOrder: [Provider]
    ) -> Bool {
        if abs(lhs.consumedPercentPoints - rhs.consumedPercentPoints) >= 0.001 {
            return lhs.consumedPercentPoints > rhs.consumedPercentPoints
        }

        if lhs.consumedUnits != rhs.consumedUnits {
            return lhs.consumedUnits > rhs.consumedUnits
        }

        let lhsLatestActivity = lhs.latestActivity ?? .distantPast
        let rhsLatestActivity = rhs.latestActivity ?? .distantPast
        if lhsLatestActivity != rhsLatestActivity {
            return lhsLatestActivity > rhsLatestActivity
        }

        let lhsProviderIndex = providerOrder.firstIndex(of: lhs.provider) ?? Int.max
        let rhsProviderIndex = providerOrder.firstIndex(of: rhs.provider) ?? Int.max
        if lhsProviderIndex != rhsProviderIndex {
            return lhsProviderIndex < rhsProviderIndex
        }

        return lhs.key.name.localizedStandardCompare(rhs.key.name) == .orderedAscending
    }

    private static func moneyDeltaCents(from text: String) -> Int {
        let normalized = text
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "CNY", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Decimal(string: normalized) else { return 0 }
        return NSDecimalNumber(decimal: value * 100).intValue
    }
}

private struct RecentProviderUsageCandidate {
    let provider: Provider
    let key: APIKey
    let consumedPercentPoints: Double
    let consumedUnits: Int
    let latestActivity: Date?
}
