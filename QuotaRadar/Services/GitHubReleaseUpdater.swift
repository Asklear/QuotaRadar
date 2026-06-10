import AppKit
import Foundation

struct GitHubReleaseUpdate: Identifiable, Equatable {
    let tagName: String
    let version: String
    let releaseName: String
    let releaseNotes: String
    let releaseURL: URL
    let assetName: String
    let assetDownloadURL: URL

    var id: String { tagName }
}

@MainActor
final class GitHubReleaseUpdater: ObservableObject {
    static let shared = GitHubReleaseUpdater()

    @Published private(set) var isChecking = false
    @Published private(set) var isDownloading = false
    @Published private(set) var statusMessage: String?

    private static let latestReleaseEndpoint = URL(string: "https://api.github.com/repos/Asklear/QuotaRadar/releases/latest")!
    private static let latestReleaseRedirectURL = URL(string: "https://github.com/Asklear/QuotaRadar/releases/latest")!
    private static let releaseAssetName = "QuotaRadar.dmg"
    private static let lastUpdateCheckKey = "lastGitHubReleaseUpdateCheckAt"
    private static let skippedReleaseTagKey = "skippedGitHubReleaseUpdateTag"
    private let minimumLaunchCheckInterval: TimeInterval = 12 * 60 * 60
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    func checkForUpdatesFromUI() {
        Task {
            await checkForUpdates(userInitiated: true)
        }
    }

    func checkForUpdatesIfNeededOnLaunch() {
        guard AppAppearanceStore.shared.automaticallyCheckForUpdates else { return }

        let lastCheck = defaults.object(forKey: Self.lastUpdateCheckKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(lastCheck) >= minimumLaunchCheckInterval else { return }

        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await checkForUpdates(userInitiated: false)
        }
    }

    private func checkForUpdates(userInitiated: Bool) async {
        guard !isChecking, !isDownloading else { return }

        isChecking = true
        statusMessage = L10n.t(.checkingForUpdates)
        defaults.set(Date(), forKey: Self.lastUpdateCheckKey)

        do {
            let update = try await fetchLatestUpdate()
            isChecking = false

            guard let update else {
                statusMessage = userInitiated ? L10n.t(.noUpdatesAvailable) : nil
                if userInitiated {
                    presentNoUpdateAlert()
                }
                return
            }

            if !userInitiated,
               defaults.string(forKey: Self.skippedReleaseTagKey) == update.tagName {
                statusMessage = nil
                return
            }

            statusMessage = L10n.format(.updateAvailableStatus, update.version)
            await presentUpdatePrompt(update)
        } catch {
            isChecking = false
            if userInitiated {
                statusMessage = L10n.format(.updateDownloadFailed, error.localizedDescription)
                presentErrorAlert(error)
            } else {
                statusMessage = nil
            }
        }
    }

    private func fetchLatestUpdate() async throws -> GitHubReleaseUpdate? {
        do {
            return try await fetchLatestUpdateFromAPI()
        } catch GitHubReleaseUpdaterError.httpStatus(let statusCode) where statusCode == 403 {
            return try await fetchLatestUpdateFromRedirect()
        }
    }

    private func fetchLatestUpdateFromAPI() async throws -> GitHubReleaseUpdate? {
        var request = URLRequest(url: Self.latestReleaseEndpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("QuotaRadar/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let session = URLSession(configuration: AppAppearanceStore.configuredURLSessionConfiguration())
        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response)

        let release = try JSONDecoder().decode(GitHubReleaseResponse.self, from: data)
        guard release.draft != true, release.prerelease != true else { return nil }

        let latestVersion = Self.normalizedVersion(release.tagName)
        guard Self.isVersion(latestVersion, newerThan: currentVersion) else { return nil }

        guard let asset = release.assets.first(where: { $0.name == Self.releaseAssetName })
            ?? release.assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") }) else {
            throw GitHubReleaseUpdaterError.missingDMGAsset
        }

        return GitHubReleaseUpdate(
            tagName: release.tagName,
            version: latestVersion,
            releaseName: release.name ?? release.tagName,
            releaseNotes: release.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            releaseURL: release.htmlURL,
            assetName: asset.name,
            assetDownloadURL: asset.browserDownloadURL
        )
    }

    private func fetchLatestUpdateFromRedirect() async throws -> GitHubReleaseUpdate? {
        var request = URLRequest(url: Self.latestReleaseRedirectURL)
        request.httpMethod = "HEAD"
        request.setValue("QuotaRadar/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let session = URLSession(configuration: AppAppearanceStore.configuredURLSessionConfiguration())
        let (_, response) = try await session.data(for: request)
        try validateHTTPResponse(response)

        guard let resolvedURL = response.url,
              let tagName = releaseTag(from: resolvedURL) else {
            throw GitHubReleaseUpdaterError.latestReleaseUnavailable
        }

        let latestVersion = Self.normalizedVersion(tagName)
        guard Self.isVersion(latestVersion, newerThan: currentVersion) else { return nil }

        guard let assetDownloadURL = URL(
            string: "https://github.com/Asklear/QuotaRadar/releases/download/\(tagName)/\(Self.releaseAssetName)"
        ) else {
            throw GitHubReleaseUpdaterError.missingDMGAsset
        }

        return GitHubReleaseUpdate(
            tagName: tagName,
            version: latestVersion,
            releaseName: tagName,
            releaseNotes: "",
            releaseURL: resolvedURL,
            assetName: Self.releaseAssetName,
            assetDownloadURL: assetDownloadURL
        )
    }

    private func presentNoUpdateAlert() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L10n.t(.noUpdatesAvailable)
        alert.informativeText = L10n.format(.noUpdatesAvailableDescription, currentVersion)
        alert.addButton(withTitle: L10n.t(.ok))
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func presentErrorAlert(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.t(.updateCheckFailed)
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: L10n.t(.ok))
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func presentUpdatePrompt(_ update: GitHubReleaseUpdate) async {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L10n.format(.updateAvailableTitle, update.version)
        alert.informativeText = L10n.format(.updateAvailableMessage, currentVersion, update.assetName)
        alert.accessoryView = releaseNotesAccessoryView(notes: update.releaseNotes)
        alert.addButton(withTitle: L10n.t(.downloadAndInstallUpdate))
        alert.addButton(withTitle: L10n.t(.later))
        alert.addButton(withTitle: L10n.t(.openReleasePage))

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            await downloadAndInstall(update)
        case .alertSecondButtonReturn:
            defaults.set(update.tagName, forKey: Self.skippedReleaseTagKey)
            statusMessage = nil
        default:
            NSWorkspace.shared.open(update.releaseURL)
            statusMessage = nil
        }
    }

    private func releaseNotesAccessoryView(notes: String) -> NSView {
        let label = NSTextField(labelWithString: L10n.t(.releaseNotes))
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.frame = NSRect(x: 0, y: 248, width: 540, height: 18)

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 540, height: 238))
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textColor = .labelColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.string = notes.isEmpty ? L10n.t(.releaseNotesUnavailable) : notes

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 540, height: 238))
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.documentView = textView

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 540, height: 270))
        container.addSubview(label)
        container.addSubview(scrollView)
        return container
    }

    func downloadAndInstall(_ update: GitHubReleaseUpdate) async {
        guard !isDownloading else { return }

        isDownloading = true
        statusMessage = L10n.format(.updateDownloadStarted, update.version)

        do {
            let dmgURL = try await downloadReleaseAsset(update)
            statusMessage = L10n.t(.updateInstallPreparing)
            try launchInstallerScript(dmgURL: dmgURL, update: update)
            statusMessage = L10n.t(.updateInstallingRelaunch)
            NSApp.terminate(nil)
        } catch {
            isDownloading = false
            statusMessage = L10n.format(.updateDownloadFailed, error.localizedDescription)
            presentErrorAlert(error)
        }
    }

    private func downloadReleaseAsset(_ update: GitHubReleaseUpdate) async throws -> URL {
        var request = URLRequest(url: update.assetDownloadURL)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        request.setValue("QuotaRadar/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let session = URLSession(configuration: AppAppearanceStore.configuredURLSessionConfiguration())
        let (downloadedURL, response) = try await session.download(for: request)
        try validateHTTPResponse(response)

        let sanitizedTag = update.tagName.replacingOccurrences(of: "/", with: "-")
        let targetURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuotaRadar-\(sanitizedTag)-\(UUID().uuidString).dmg")
        try FileManager.default.moveItem(at: downloadedURL, to: targetURL)
        return targetURL
    }

    private func launchInstallerScript(dmgURL: URL, update: GitHubReleaseUpdate) throws {
        let targetAppURL = targetApplicationURL()
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("quotaradar-update-\(UUID().uuidString).sh")
        let script = installerScript(
            dmgPath: dmgURL.path,
            targetAppPath: targetAppURL.path,
            version: update.version
        )

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path]
        try process.run()
    }

    private func targetApplicationURL() -> URL {
        let bundleURL = Bundle.main.bundleURL
        if bundleURL.pathExtension == "app",
           bundleURL.path.contains("/Applications/") {
            return bundleURL
        }
        return URL(fileURLWithPath: "/Applications/Quota Radar.app")
    }

    private func installerScript(dmgPath: String, targetAppPath: String, version: String) -> String {
        let escapedDMG = Self.shellEscaped(dmgPath)
        let escapedTargetApp = Self.shellEscaped(targetAppPath)
        let escapedVersion = Self.shellEscaped(version)

        return """
        #!/bin/bash
        set -euo pipefail

        LOG_FILE="$HOME/Library/Logs/QuotaRadarUpdater.log"
        mkdir -p "$(dirname "$LOG_FILE")"
        exec >>"$LOG_FILE" 2>&1

        DMG_PATH=\(escapedDMG)
        TARGET_APP=\(escapedTargetApp)
        UPDATE_VERSION=\(escapedVersion)
        MOUNT_POINT="$(mktemp -d /tmp/quotaradar-update-mount.XXXXXX)"
        TMP_APP="${TARGET_APP}.updating"
        BACKUP_APP="${TARGET_APP}.previous"

        cleanup() {
            local status="$1"
            hdiutil detach "$MOUNT_POINT" -quiet || true
            rm -f "$DMG_PATH" || true
            if [ "$status" -ne 0 ]; then
                rm -rf "$TMP_APP" || true
                if [ -d "$BACKUP_APP" ] && [ ! -d "$TARGET_APP" ]; then
                    mv "$BACKUP_APP" "$TARGET_APP" || true
                fi
                /usr/bin/osascript -e 'display notification "Update failed. See ~/Library/Logs/QuotaRadarUpdater.log" with title "Quota Radar"' || true
                if [ -d "$TARGET_APP" ]; then
                    open -a "$TARGET_APP" || open "$TARGET_APP" || true
                fi
            else
                rm -rf "$BACKUP_APP" || true
            fi
            rm -f "$0" || true
            exit "$status"
        }
        trap 'cleanup $?' EXIT

        echo "Installing Quota Radar ${UPDATE_VERSION}"
        sleep 1.5
        hdiutil attach "$DMG_PATH" -mountpoint "$MOUNT_POINT" -nobrowse -quiet

        SOURCE_APP="$MOUNT_POINT/Quota Radar.app"
        if [ ! -d "$SOURCE_APP" ]; then
            SOURCE_APP="$(find "$MOUNT_POINT" -maxdepth 3 -name 'Quota Radar.app' -type d -print -quit)"
        fi
        if [ -z "${SOURCE_APP:-}" ] || [ ! -d "$SOURCE_APP" ]; then
            echo "Could not find Quota Radar.app in mounted DMG"
            exit 1
        fi

        rm -rf "$TMP_APP" "$BACKUP_APP"
        ditto "$SOURCE_APP" "$TMP_APP"

        if [ -d "$TARGET_APP" ]; then
            mv "$TARGET_APP" "$BACKUP_APP"
        fi
        mv "$TMP_APP" "$TARGET_APP"

        xattr -dr com.apple.quarantine "$TARGET_APP" || true
        spctl --add --label "Quota Radar" "$TARGET_APP" || true
        open -a "$TARGET_APP" || open "$TARGET_APP"
        """
    }

    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw GitHubReleaseUpdaterError.httpStatus(httpResponse.statusCode)
        }
    }

    private func releaseTag(from url: URL) -> String? {
        let components = url.pathComponents
        guard let tagIndex = components.firstIndex(of: "tag"),
              components.indices.contains(components.index(after: tagIndex)) else {
            return nil
        }
        return components[components.index(after: tagIndex)]
    }

    static func normalizedVersion(_ rawVersion: String) -> String {
        rawVersion
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingPrefix("v")
            .trimmingPrefix("V")
    }

    static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let candidateParts = versionComponents(candidate)
        let currentParts = versionComponents(current)
        let count = max(candidateParts.count, currentParts.count)

        for index in 0..<count {
            let lhs = index < candidateParts.count ? candidateParts[index] : 0
            let rhs = index < currentParts.count ? currentParts[index] : 0
            if lhs != rhs {
                return lhs > rhs
            }
        }

        return false
    }

    private static func versionComponents(_ version: String) -> [Int] {
        normalizedVersion(version)
            .split { !$0.isNumber }
            .map { Int($0) ?? 0 }
    }

    private static func shellEscaped(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

private struct GitHubReleaseResponse: Decodable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: URL
    let draft: Bool?
    let prerelease: Bool?
    let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case name
        case body
        case draft
        case prerelease
        case assets
    }
}

private struct GitHubReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: URL

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

private enum GitHubReleaseUpdaterError: LocalizedError {
    case missingDMGAsset
    case latestReleaseUnavailable
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .missingDMGAsset:
            return L10n.t(.updateMissingDMGAsset)
        case .latestReleaseUnavailable:
            return L10n.t(.updateLatestReleaseUnavailable)
        case .httpStatus(let statusCode):
            return L10n.format(.updateHTTPStatusError, statusCode)
        }
    }
}

private extension String {
    func trimmingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else { return self }
        return String(dropFirst(prefix.count))
    }
}
