import Foundation

struct QuotaHistoryStore {
    static let maxSnapshotsPerKey = 60
    static let retentionInterval: TimeInterval = 45 * 24 * 60 * 60

    private let fileURL: URL
    private let fileManager: FileManager

    init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)
    }

    func load() -> [QuotaSnapshot] {
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              !data.isEmpty,
              let snapshots = try? JSONDecoder().decode([QuotaSnapshot].self, from: data) else {
            return []
        }
        return prune(snapshots)
    }

    func append(_ snapshot: QuotaSnapshot, existing snapshots: [QuotaSnapshot]) -> [QuotaSnapshot] {
        prune(snapshots + [snapshot])
    }

    func save(_ snapshots: [QuotaSnapshot]) {
        let prunedSnapshots = prune(snapshots)
        let directory = fileURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(prunedSnapshots)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save quota history: \(error)")
        }
    }

    func deleteSnapshots(for keyID: UUID, existing snapshots: [QuotaSnapshot]) -> [QuotaSnapshot] {
        prune(snapshots.filter { $0.keyID != keyID })
    }

    private static func defaultFileURL(fileManager: FileManager) -> URL {
        let quotaRadarSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("QuotaRadar", isDirectory: true)
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Application Support/QuotaRadar", isDirectory: true)
        return quotaRadarSupportURL
            .appendingPathComponent("quota-history.json")
    }

    private func prune(_ snapshots: [QuotaSnapshot], now: Date = Date()) -> [QuotaSnapshot] {
        let cutoff = now.addingTimeInterval(-Self.retentionInterval)
        let recentSnapshots = snapshots
            .filter { $0.recordedAt >= cutoff }
            .sorted { lhs, rhs in
                if lhs.keyID != rhs.keyID {
                    return lhs.keyID.uuidString < rhs.keyID.uuidString
                }
                return lhs.recordedAt < rhs.recordedAt
            }

        var grouped: [UUID: [QuotaSnapshot]] = [:]
        for snapshot in recentSnapshots {
            grouped[snapshot.keyID, default: []].append(snapshot)
        }

        return grouped.values
            .flatMap { Array($0.suffix(Self.maxSnapshotsPerKey)) }
            .sorted { $0.recordedAt < $1.recordedAt }
    }
}
