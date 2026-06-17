import SwiftUI
import AppKit
import WebKit

struct DashboardReauthSheet: View {
    @ObservedObject var monitor: QuotaMonitor
    @Environment(\.dismiss) private var dismiss

    let provider: Provider
    let key: APIKey?
    let onSaved: ((APIKey) -> Void)?

    @State private var selectedAuthorizationTargetID: UUID?
    @State private var statusMessage: String?
    @State private var isSaving = false
    @State private var didAutoSave = false
    @State private var latestCapturedCredential: DashboardCapturedCredential?

    init(monitor: QuotaMonitor, provider: Provider, key: APIKey?, onSaved: ((APIKey) -> Void)? = nil) {
        self.monitor = monitor
        self.provider = provider
        self.key = key
        self.onSaved = onSaved
        _selectedAuthorizationTargetID = State(initialValue: key?.isQuotaMonitoringAuthorizationCredential == true ? key?.id : nil)
    }

    private var config: DashboardReauthConfig? {
        DashboardReauthConfig(provider: provider)
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ProviderIcon(provider: provider, size: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.format(.reauthTitle, provider.displayName()))
                        .font(.headline)

                    Text(L10n.t(.reauthDescription))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(reauthTargetSummary)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if multipleAuthorizationKeys.count > 1 {
                        Text(L10n.t(.reauthMultipleCredentialHint))
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }

            if shouldShowAuthorizationTargetPicker {
                Picker(L10n.t(.reauthTargetCredential), selection: $selectedAuthorizationTargetID) {
                    if !requiresAuthorizationTargetSelection {
                        Text(L10n.t(.reauthCreateNewCredential))
                            .tag(Optional<UUID>.none)
                    } else {
                        Text(L10n.t(.reauthSelectTarget))
                            .tag(Optional<UUID>.none)
                    }

                    ForEach(multipleAuthorizationKeys) { authorizationKey in
                        Text(authorizationKey.reauthTargetDisplayText)
                            .tag(Optional(authorizationKey.id))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let config {
                DashboardWebView(
                    provider: provider,
                    url: config.loginURL,
                    cookieDomains: config.cookieDomains,
                    requiredCookieNames: config.requiredCookieNames,
                    onCredentialAvailable: { credential in
                        latestCapturedCredential = credential
                        autoSaveCredential(credential)
                    }
                )
                    .frame(width: 760, height: 520)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                    )
            } else {
                ContentUnavailableView(
                    L10n.t(.quotaUnavailable),
                    systemImage: "exclamationmark.triangle"
                )
                .frame(width: 760, height: 520)
            }

            HStack {
                Text(statusMessage ?? L10n.t(.autoCookieSaveHint))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(L10n.t(.close)) {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button(action: saveCookies) {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(L10n.t(.saveCookie), systemImage: "key.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(config == nil || isSaving)
            }
        }
        .padding(18)
        .frame(width: 800)
    }

    private func saveCookies() {
        guard let config else { return }
        guard !requiresAuthorizationTargetSelection || selectedAuthorizationTargetID != nil else {
            statusMessage = L10n.t(.reauthSelectTargetBeforeSaving)
            return
        }

        if let latestCapturedCredential,
           DashboardCredentialCapturePolicy.isCredentialReady(latestCapturedCredential,
               requiredNames: config.requiredCookieNames
           ) {
            isSaving = true
            statusMessage = L10n.t(.autoSavingCookie)
            persistCredential(latestCapturedCredential, allowEmptyStatus: true, dismissAfterSave: true)
            return
        }

        latestCapturedCredential = nil
        isSaving = true
        statusMessage = L10n.t(.autoSavingCookie)
        readCookiesForManualSave(config: config, completedRetryCount: 0)
    }

    private func readCookiesForManualSave(config: DashboardReauthConfig, completedRetryCount: Int) {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            let cookieHeader = DashboardCookieBuilder.cookieHeader(
                from: cookies,
                domains: config.cookieDomains
            )

            DispatchQueue.main.async {
                let capturedCredential = DashboardCapturedCredential(
                    provider: provider,
                    cookieHeader: cookieHeader
                )

                if DashboardCredentialCapturePolicy.shouldRetryCapture(
                    capturedCredential,
                    requiredNames: config.requiredCookieNames,
                    completedRetryCount: completedRetryCount,
                    retryDelays: DashboardCredentialCapturePolicy.manualRetryDelays
                ) {
                    let delay = DashboardCredentialCapturePolicy.manualRetryDelays[completedRetryCount]
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        guard isSaving else { return }
                        readCookiesForManualSave(config: config, completedRetryCount: completedRetryCount + 1)
                    }
                    return
                }

                if DashboardCredentialCapturePolicy.isCredentialReady(
                    capturedCredential,
                    requiredNames: config.requiredCookieNames
                ) {
                    latestCapturedCredential = capturedCredential
                }
                persistCredential(capturedCredential, allowEmptyStatus: true, dismissAfterSave: true)
            }
        }
    }

    private func autoSaveCredential(_ credential: DashboardCapturedCredential) {
        guard !didAutoSave, !isSaving else { return }
        guard !requiresAuthorizationTargetSelection || selectedAuthorizationTargetID != nil else {
            latestCapturedCredential = credential
            statusMessage = L10n.t(.reauthSelectTargetBeforeSaving)
            return
        }
        isSaving = true
        statusMessage = L10n.t(.autoSavingCookie)
        persistCredential(credential, allowEmptyStatus: false, dismissAfterSave: false)
    }

    private func persistCredential(_ capturedCredential: DashboardCapturedCredential, allowEmptyStatus: Bool, dismissAfterSave: Bool) {
        guard let config else {
            isSaving = false
            return
        }

        guard capturedCredential.hasCredentialMaterial else {
            isSaving = false
            if allowEmptyStatus {
                statusMessage = L10n.t(.noCookiesFound)
            }
            return
        }

        let missingCookieNames = DashboardCookieBuilder.missingRequiredCredentialNames(
            cookieHeader: capturedCredential.cookieHeader,
            fields: capturedCredential.fields,
            requiredNames: config.requiredCookieNames
        )
        guard missingCookieNames.isEmpty else {
            isSaving = false
            statusMessage = L10n.format(.missingRequiredCookies, missingCookieNames.joined(separator: ", "))
            return
        }

        validateAndPersistCredential(capturedCredential, config: config, dismissAfterSave: dismissAfterSave)
    }

    private func validateAndPersistCredential(_ capturedCredential: DashboardCapturedCredential, config: DashboardReauthConfig, dismissAfterSave: Bool) {
        didAutoSave = true
        statusMessage = L10n.t(.checkingCookie)

        let existingKey = existingQuotaAuthorizationKey
        let candidateKey: APIKey
        if var updatedKey = existingKey {
            updatedKey.key = capturedCredential.reauthenticatedSecret(
                existingSecret: updatedKey.key
            )
            if updatedKey.name.isEmpty || updatedKey.isBusinessInvocationCredential {
                updatedKey.name = config.defaultKeyName
            }
            updatedKey.quotaLabel = L10n.t(.cookieSaved)
            updatedKey.quotaText = LocalizedTextDescriptor.localized(.cookieSaved)
            updatedKey.lastUpdated = Date()
            candidateKey = updatedKey
        } else {
            candidateKey = APIKey(
                name: config.defaultKeyName,
                key: capturedCredential.reauthenticatedSecret(existingSecret: nil),
                provider: provider,
                note: nil,
                lastUpdated: Date(),
                quotaText: LocalizedTextDescriptor.localized(.cookieSaved),
                quotaLabel: L10n.t(.cookieSaved)
            )
        }

        guard provider.supportsQuotaQuery else {
            if existingKey == nil {
                monitor.addKey(candidateKey)
            } else {
                monitor.updateKey(candidateKey)
            }
            onSaved?(candidateKey)
            isSaving = false
            statusMessage = L10n.t(.cookieSaved)
            if dismissAfterSave {
                dismiss()
            }
            return
        }

        Task {
            do {
                let result = try await QuotaService().checkQuota(for: candidateKey, bypassCooldown: true)
                await MainActor.run {
                    var verifiedKey = candidateKey
                    verifiedKey.remaining = result.remaining
                    verifiedKey.limit = result.limit
                    verifiedKey.resetAt = result.resetAt
                    verifiedKey.planEndsAt = result.planEndsAt
                    verifiedKey.planDisplayName = result.planDisplayName
                    verifiedKey.quotaLabel = result.quotaLabel
                    verifiedKey.quotaText = result.quotaText
                    verifiedKey.lastHTTPStatus = result.httpStatus
                    verifiedKey.lastDiagnosticMessage = result.diagnosticMessage
                    verifiedKey.lastDiagnosticText = result.diagnosticText
                    verifiedKey.consecutiveFailureCount = 0
                    verifiedKey.lastUpdated = Date()

                    if existingKey == nil {
                        monitor.addKey(verifiedKey)
                    } else {
                        monitor.updateKey(verifiedKey)
                    }

                    onSaved?(verifiedKey)
                    isSaving = false
                    statusMessage = L10n.t(.cookieSaved)
                    if dismissAfterSave {
                        dismiss()
                    }
                }
            } catch QuotaError.unauthorized {
                await MainActor.run {
                    isSaving = false
                    didAutoSave = false
                    statusMessage = L10n.t(.reauthStillUnauthorized)
                }
            } catch QuotaError.noSubscription {
                await MainActor.run {
                    var verifiedKey = candidateKey
                    verifiedKey.remaining = nil
                    verifiedKey.limit = nil
                    verifiedKey.resetAt = nil
                    verifiedKey.planEndsAt = nil
                    verifiedKey.planDisplayName = nil
                    verifiedKey.quotaLabel = "No subscribed plan"
                    verifiedKey.quotaText = LocalizedTextDescriptor.localized(.noSubscribedPlan)
                    verifiedKey.lastHTTPStatus = 200
                    verifiedKey.lastDiagnosticMessage = "No subscribed plan"
                    verifiedKey.lastDiagnosticText = LocalizedTextDescriptor.localized(.noSubscribedPlan)
                    verifiedKey.consecutiveFailureCount = 0
                    verifiedKey.lastUpdated = Date()

                    if existingKey == nil {
                        monitor.addKey(verifiedKey)
                    } else {
                        monitor.updateKey(verifiedKey)
                    }

                    onSaved?(verifiedKey)
                    isSaving = false
                    statusMessage = L10n.t(.cookieSaved)
                    if dismissAfterSave {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    didAutoSave = false
                    statusMessage = L10n.format(.reauthValidationFailed, error.localizedDescription)
                }
            }
        }
    }

    private var selectedQuotaAuthorizationKey: APIKey? {
        guard let key,
              key.provider == provider,
              key.isQuotaMonitoringAuthorizationCredential else {
            return nil
        }
        return key
    }

    private var existingQuotaAuthorizationKey: APIKey? {
        if let selectedAuthorizationTargetID {
            return monitor.apiKeys.first {
                $0.id == selectedAuthorizationTargetID
                    && $0.provider == provider
                    && $0.isQuotaMonitoringAuthorizationCredential
            }
        }

        if let selectedQuotaAuthorizationKey {
            return selectedQuotaAuthorizationKey
        }

        if multipleAuthorizationKeys.count == 1 {
            return multipleAuthorizationKeys.first
        }

        return nil
    }

    private var multipleAuthorizationKeys: [APIKey] {
        monitor.apiKeys.filter {
            $0.provider == provider && $0.isQuotaMonitoringAuthorizationCredential
        }
    }

    private var reauthTargetSummary: String {
        if let existingQuotaAuthorizationKey {
            return L10n.format(.reauthSavingTo, existingQuotaAuthorizationKey.managementDisplayName)
        }

        if requiresAuthorizationTargetSelection {
            return L10n.t(.reauthSelectTarget)
        }

        let defaultName = config?.defaultKeyName ?? provider.defaultCredentialName
        return L10n.format(.reauthWillCreate, defaultName)
    }

    private var shouldShowAuthorizationTargetPicker: Bool {
        multipleAuthorizationKeys.count > 1
    }

    private var requiresAuthorizationTargetSelection: Bool {
        multipleAuthorizationKeys.count > 1 && selectedQuotaAuthorizationKey == nil
    }
}

final class OAuthPopupWindow: NSWindow {
    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        self.contentView = contentView
        self.isReleasedWhenClosed = false
        self.animationBehavior = .none
    }
}

struct DashboardWebView: NSViewRepresentable {
    let provider: Provider
    let url: URL
    let cookieDomains: [String]
    let requiredCookieNames: [String]
    let onCredentialAvailable: (DashboardCapturedCredential) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.start(webView: webView, url: url)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if webView.url == nil, !context.coordinator.hasStartedLoading {
            context.coordinator.start(webView: webView, url: url)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            provider: provider,
            cookieDomains: cookieDomains,
            requiredCookieNames: requiredCookieNames,
            onCredentialAvailable: onCredentialAvailable
        )
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKHTTPCookieStoreObserver, NSWindowDelegate {
        private let provider: Provider
        private let cookieDomains: [String]
        private let requiredCookieNames: [String]
        private let onCredentialAvailable: (DashboardCapturedCredential) -> Void
        private var didEmitCookies = false
        private weak var webView: WKWebView?
        private var observedCookieStore: WKHTTPCookieStore?
        private var oauthPopupWindows: [ObjectIdentifier: OAuthPopupWindow] = [:]
        private var pendingCookieCaptureWorkItem: DispatchWorkItem?
        private(set) var hasStartedLoading = false

        init(
            provider: Provider,
            cookieDomains: [String],
            requiredCookieNames: [String],
            onCredentialAvailable: @escaping (DashboardCapturedCredential) -> Void
        ) {
            self.provider = provider
            self.cookieDomains = cookieDomains
            self.requiredCookieNames = requiredCookieNames
            self.onCredentialAvailable = onCredentialAvailable
        }

        deinit {
            pendingCookieCaptureWorkItem?.cancel()
            observedCookieStore?.remove(self)
            closeAllOAuthPopups()
        }

        func start(webView: WKWebView, url: URL) {
            guard !hasStartedLoading else { return }
            self.webView = webView

            let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
            observedCookieStore = cookieStore
            cookieStore.add(self)
            clearProviderCookiesBeforeLoading(webView: webView, cookieStore: cookieStore, url: url)
        }

        private func clearProviderCookiesBeforeLoading(webView: WKWebView, cookieStore: WKHTTPCookieStore, url: URL) {
            cookieStore.getAllCookies { [weak self, weak webView] cookies in
                guard let self, let webView else { return }

                let staleCookies = cookies.filter { self.matchesAllowedCookieDomain($0.domain) }
                guard !staleCookies.isEmpty else {
                    DispatchQueue.main.async {
                        self.hasStartedLoading = true
                        webView.load(URLRequest(url: url))
                    }
                    return
                }

                let group = DispatchGroup()
                for cookie in staleCookies {
                    group.enter()
                    cookieStore.delete(cookie) {
                        group.leave()
                    }
                }

                group.notify(queue: .main) { [weak self, weak webView] in
                    guard let self, let webView else { return }
                    self.hasStartedLoading = true
                    webView.load(URLRequest(url: url))
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !didEmitCookies,
                  let host = webView.url?.host,
                  matchesAllowedDomain(host) else {
                return
            }

            scheduleCookieCaptureRetry(completedRetryCount: 0)
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            guard navigationAction.targetFrame == nil,
                  navigationAction.request.url != nil else {
                return nil
            }

            let popupWebView = WKWebView(frame: NSRect(x: 0, y: 0, width: 520, height: 640), configuration: configuration)
            popupWebView.navigationDelegate = self
            popupWebView.uiDelegate = self
            popupWebView.allowsBackForwardNavigationGestures = true

            let popupWindow = OAuthPopupWindow(contentView: popupWebView)
            popupWindow.title = "Quota Radar"
            popupWindow.delegate = self
            popupWindow.center()
            popupWindow.makeKeyAndOrderFront(nil)
            oauthPopupWindows[ObjectIdentifier(popupWebView)] = popupWindow

            return popupWebView
        }

        func webViewDidClose(_ webView: WKWebView) {
            closeOAuthPopup(for: webView)
        }

        private func closeOAuthPopup(for webView: WKWebView) {
            let key = ObjectIdentifier(webView)
            guard let popupWindow = oauthPopupWindows.removeValue(forKey: key) else { return }
            detachOAuthPopupWebView(webView)
            popupWindow.delegate = nil
            popupWindow.orderOut(nil)
            retainOAuthPopupUntilNextRunLoop(popupWindow, webView: webView)
        }

        func windowWillClose(_ notification: Notification) {
            guard let popupWindow = notification.object as? OAuthPopupWindow else { return }
            let matchingKeys = oauthPopupWindows
                .filter { $0.value === popupWindow }
                .map(\.key)
            for key in matchingKeys {
                guard let managedWindow = oauthPopupWindows.removeValue(forKey: key) else { continue }
                if let popupWebView = managedWindow.contentView as? WKWebView {
                    detachOAuthPopupWebView(popupWebView)
                    retainOAuthPopupUntilNextRunLoop(managedWindow, webView: popupWebView)
                } else {
                    retainOAuthPopupUntilNextRunLoop(managedWindow, webView: nil)
                }
            }
            popupWindow.delegate = nil
        }

        private func closeAllOAuthPopups() {
            let managedPopups = oauthPopupWindows
            oauthPopupWindows.removeAll()
            for (_, popupWindow) in managedPopups {
                if let popupWebView = popupWindow.contentView as? WKWebView {
                    detachOAuthPopupWebView(popupWebView)
                    retainOAuthPopupUntilNextRunLoop(popupWindow, webView: popupWebView)
                } else {
                    retainOAuthPopupUntilNextRunLoop(popupWindow, webView: nil)
                }
                popupWindow.delegate = nil
                popupWindow.orderOut(nil)
            }
        }

        private func detachOAuthPopupWebView(_ webView: WKWebView) {
            webView.stopLoading()
            webView.navigationDelegate = nil
            webView.uiDelegate = nil
        }

        private func retainOAuthPopupUntilNextRunLoop(_ popupWindow: OAuthPopupWindow, webView: WKWebView?) {
            DispatchQueue.main.async {
                _ = popupWindow
                _ = webView
            }
        }

        func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            scheduleCookieCaptureRetry(completedRetryCount: 0)
        }

        private func scheduleCookieCaptureRetry(completedRetryCount: Int, delay: TimeInterval = 0) {
            guard !didEmitCookies else { return }
            pendingCookieCaptureWorkItem?.cancel()

            let workItem = DispatchWorkItem { [weak self] in
                self?.captureCredentialIfReady(completedRetryCount: completedRetryCount)
            }
            pendingCookieCaptureWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }

        private func captureCredentialIfReady(completedRetryCount: Int) {
            guard !didEmitCookies,
                  let webView,
                  let host = webView.url?.host,
                  matchesAllowedDomain(host) else {
                return
            }

            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self, weak webView] cookies in
                guard let self, let webView, !self.didEmitCookies else { return }
                let cookieHeader = DashboardCookieBuilder.cookieHeader(
                    from: cookies,
                    domains: self.cookieDomains
                )

                self.captureWebStorageFields(from: webView) { [weak self] webStorageFields in
                    guard let self, !self.didEmitCookies else { return }
                    let capturedCredential = DashboardCapturedCredential(
                        provider: self.provider,
                        cookieHeader: cookieHeader,
                        webStorageFields: webStorageFields
                    )

                    guard DashboardCredentialCapturePolicy.isCredentialReady(
                        capturedCredential,
                        requiredNames: self.requiredCookieNames
                    ) else {
                        guard DashboardCredentialCapturePolicy.shouldRetryCapture(
                            capturedCredential,
                            requiredNames: self.requiredCookieNames,
                            completedRetryCount: completedRetryCount,
                            retryDelays: DashboardCredentialCapturePolicy.automaticRetryDelays
                        ) else {
                            return
                        }

                        let delay = DashboardCredentialCapturePolicy.automaticRetryDelays[completedRetryCount]
                        DispatchQueue.main.async {
                            self.scheduleCookieCaptureRetry(
                                completedRetryCount: completedRetryCount + 1,
                                delay: delay
                            )
                        }
                        return
                    }

                    self.didEmitCookies = true
                    self.pendingCookieCaptureWorkItem?.cancel()
                    DispatchQueue.main.async {
                        self.onCredentialAvailable(capturedCredential)
                    }
                }
            }
        }

        private func captureWebStorageFields(from webView: WKWebView, completion: @escaping ([String: String]) -> Void) {
            let script = """
            (() => {
              const keys = [
                'kimi-auth', 'accessToken', 'access_token', 'authorization', 'bearerToken', 'bearer_token', 'token',
                'deviceID', 'deviceId', 'x-msh-device-id',
                'sessionID', 'sessionId', 'x-msh-session-id',
                'trafficID', 'trafficId', 'x-traffic-id'
              ];
              const output = {};
              for (const storageName of ['localStorage', 'sessionStorage']) {
                try {
                  const storage = window[storageName];
                  if (!storage) continue;
                  for (const key of keys) {
                    const value = storage.getItem(key);
                    if (value && !output[key]) output[key] = value;
                  }
                } catch (_) {}
              }
              return output;
            })();
            """

            webView.evaluateJavaScript(script) { value, _ in
                guard let object = value as? [String: Any] else {
                    completion([:])
                    return
                }
                let fields = object.reduce(into: [String: String]()) { result, item in
                    guard let value = item.value as? String,
                          !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return
                    }
                    result[item.key] = value
                }
                completion(fields)
            }
        }

        private func matchesAllowedDomain(_ host: String) -> Bool {
            let normalizedHost = normalizeDomain(host)
            return normalizedCookieDomains.contains { allowedDomain in
                normalizedHost == allowedDomain || normalizedHost.hasSuffix(".\(allowedDomain)")
            }
        }

        private func matchesAllowedCookieDomain(_ domain: String) -> Bool {
            let normalizedCookieDomain = normalizeDomain(domain)
            return normalizedCookieDomains.contains { allowedDomain in
                normalizedCookieDomain == allowedDomain || normalizedCookieDomain.hasSuffix(".\(allowedDomain)")
            }
        }

        private var normalizedCookieDomains: [String] {
            cookieDomains.map(normalizeDomain)
        }

        private func normalizeDomain(_ domain: String) -> String {
            domain
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                .lowercased()
        }
    }
}
