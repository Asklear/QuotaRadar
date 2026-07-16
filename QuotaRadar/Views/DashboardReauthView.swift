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
    @State private var validationLifecycle = DashboardReauthValidationLifecycle()
    @State private var automaticCaptureResetRequestID = 0
    @State private var manualCaptureRequestID = 0

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
                    automaticCaptureResetRequestID: automaticCaptureResetRequestID,
                    manualCaptureRequestID: manualCaptureRequestID,
                    onCredentialAvailable: { credential in
                        autoSaveCredential(credential)
                    },
                    onManualCredentialCaptured: { capturedCredential in
                        persistCredential(capturedCredential, allowEmptyStatus: true, dismissAfterSave: true)
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
        guard config != nil else { return }
        guard !requiresAuthorizationTargetSelection || selectedAuthorizationTargetID != nil else {
            statusMessage = L10n.t(.reauthSelectTargetBeforeSaving)
            return
        }

        isSaving = true
        statusMessage = L10n.t(.autoSavingCookie)
        manualCaptureRequestID += 1
    }

    private func autoSaveCredential(_ credential: DashboardCapturedCredential) {
        guard !didAutoSave, !isSaving else { return }
        guard !requiresAuthorizationTargetSelection || selectedAuthorizationTargetID != nil else {
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

        let missingCookieNames = DashboardCredentialCapturePolicy.missingRequiredCredentialNames(
            capturedCredential,
            requiredNames: config.requiredCookieNames
        )
        guard missingCookieNames.isEmpty else {
            isSaving = false
            statusMessage = missingCredentialStatusMessage(
                missingCookieNames: missingCookieNames,
                capturedCredential: capturedCredential
            )
            return
        }

        validateAndPersistCredential(capturedCredential, config: config, dismissAfterSave: dismissAfterSave)
    }

    private func missingCredentialStatusMessage(
        missingCookieNames: [String],
        capturedCredential: DashboardCapturedCredential
    ) -> String {
        let displayMissingNames = DashboardCredentialDisplayNames.missingRequiredNames(
            missingCookieNames,
            provider: provider
        )
        let missingMessage = L10n.format(.missingRequiredCookies, displayMissingNames.joined(separator: ", "))
        let capturedDisplayNames = DashboardCredentialDisplayNames.capturedNames(for: capturedCredential)

        guard !capturedDisplayNames.isEmpty else { return missingMessage }
        return [
            missingMessage,
            L10n.format(.capturedLoginFields, capturedDisplayNames.joined(separator: ", "))
        ].joined(separator: " · ")
    }

    private func validateAndPersistCredential(_ capturedCredential: DashboardCapturedCredential, config: DashboardReauthConfig, dismissAfterSave: Bool) {
        guard validationLifecycle.beginValidation() else { return }
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

        if provider == .longcat {
            validateAndPersistLongCatCredential(
                candidateKey,
                capturedCredential: capturedCredential,
                existingKey: existingKey,
                dismissAfterSave: dismissAfterSave
            )
            return
        }

        guard provider.supportsQuotaQuery else {
            guard validationLifecycle.finishValidation(succeeded: true) == .persist else { return }
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
                    guard validationLifecycle.finishValidation(succeeded: true) == .persist else { return }
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
                    handleValidationFailure(message: L10n.t(.reauthStillUnauthorized))
                }
            } catch QuotaError.noSubscription {
                await MainActor.run {
                    guard validationLifecycle.finishValidation(succeeded: true) == .persist else { return }
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
                    handleValidationFailure(
                        message: L10n.format(.reauthValidationFailed, error.localizedDescription)
                    )
                }
            }
        }
    }

    private func validateAndPersistLongCatCredential(
        _ candidateKey: APIKey,
        capturedCredential: DashboardCapturedCredential,
        existingKey: APIKey?,
        dismissAfterSave: Bool
    ) {
        Task {
            let service = QuotaService()
            do {
                if capturedCredential.fields["longcatLoginStatus"] != "1" {
                    try await service.validateLongCatDashboardLogin(for: candidateKey)
                }

                var verifiedKey = candidateKey
                do {
                    let result = try await service.checkQuota(for: candidateKey, bypassCooldown: true)
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
                } catch {
                    verifiedKey.lastDiagnosticMessage = error.localizedDescription
                    verifiedKey.lastDiagnosticText = LocalizedTextDescriptor.localized(.quotaErrorSchemaDrift)
                }

                await MainActor.run {
                    guard validationLifecycle.finishValidation(succeeded: true) == .persist else { return }
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
                    handleValidationFailure(message: L10n.t(.reauthStillUnauthorized))
                }
            } catch {
                await MainActor.run {
                    handleValidationFailure(
                        message: L10n.format(.reauthValidationFailed, error.localizedDescription)
                    )
                }
            }
        }
    }

    private func handleValidationFailure(message: String) {
        guard validationLifecycle.finishValidation(succeeded: false) == .recapture else { return }
        isSaving = false
        didAutoSave = false
        statusMessage = message
        automaticCaptureResetRequestID += 1
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
    let automaticCaptureResetRequestID: Int
    let manualCaptureRequestID: Int
    let onCredentialAvailable: (DashboardCapturedCredential) -> Void
    let onManualCredentialCaptured: (DashboardCapturedCredential) -> Void

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
        context.coordinator.handleAutomaticCaptureResetRequest(automaticCaptureResetRequestID)
        context.coordinator.handleManualCaptureRequest(manualCaptureRequestID)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            provider: provider,
            cookieDomains: cookieDomains,
            requiredCookieNames: requiredCookieNames,
            initialAutomaticCaptureResetRequestID: automaticCaptureResetRequestID,
            initialManualCaptureRequestID: manualCaptureRequestID,
            onCredentialAvailable: onCredentialAvailable,
            onManualCredentialCaptured: onManualCredentialCaptured
        )
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKHTTPCookieStoreObserver, NSWindowDelegate {
        private let provider: Provider
        private let cookieDomains: [String]
        private let requiredCookieNames: [String]
        private let onCredentialAvailable: (DashboardCapturedCredential) -> Void
        private let onManualCredentialCaptured: (DashboardCapturedCredential) -> Void
        private var captureLifecycle: DashboardCredentialCaptureLifecycle
        private var lastManualCaptureRequestID: Int
        private weak var webView: WKWebView?
        private var observedCookieStore: WKHTTPCookieStore?
        private var oauthPopupWindows: [ObjectIdentifier: OAuthPopupWindow] = [:]
        private var pendingCookieCaptureWorkItem: DispatchWorkItem?
        private(set) var hasStartedLoading = false

        init(
            provider: Provider,
            cookieDomains: [String],
            requiredCookieNames: [String],
            initialAutomaticCaptureResetRequestID: Int,
            initialManualCaptureRequestID: Int,
            onCredentialAvailable: @escaping (DashboardCapturedCredential) -> Void,
            onManualCredentialCaptured: @escaping (DashboardCapturedCredential) -> Void
        ) {
            self.provider = provider
            self.cookieDomains = cookieDomains
            self.requiredCookieNames = requiredCookieNames
            self.captureLifecycle = DashboardCredentialCaptureLifecycle(
                initialResetRequestID: initialAutomaticCaptureResetRequestID
            )
            self.lastManualCaptureRequestID = initialManualCaptureRequestID
            self.onCredentialAvailable = onCredentialAvailable
            self.onManualCredentialCaptured = onManualCredentialCaptured
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
            hasStartedLoading = true
            webView.load(URLRequest(url: url))
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !captureLifecycle.hasEmittedAutomaticCredential,
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

        func handleManualCaptureRequest(_ requestID: Int) {
            guard requestID != lastManualCaptureRequestID else { return }
            lastManualCaptureRequestID = requestID
            captureCredentialForManualSave(completedRetryCount: 0)
        }

        func handleAutomaticCaptureResetRequest(_ requestID: Int) {
            guard captureLifecycle.consumeResetRequest(requestID) else { return }
            scheduleCookieCaptureRetry(completedRetryCount: 0)
        }

        private func scheduleCookieCaptureRetry(completedRetryCount: Int, delay: TimeInterval = 0) {
            guard !captureLifecycle.hasEmittedAutomaticCredential else { return }
            pendingCookieCaptureWorkItem?.cancel()

            let workItem = DispatchWorkItem { [weak self] in
                self?.captureCredentialIfReady(completedRetryCount: completedRetryCount)
            }
            pendingCookieCaptureWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }

        private func captureCredentialIfReady(completedRetryCount: Int) {
            guard !captureLifecycle.hasEmittedAutomaticCredential, let webView else {
                return
            }

            captureCredential(from: webView) { [weak self] capturedCredential in
                guard let self, !self.captureLifecycle.hasEmittedAutomaticCredential else { return }
                guard DashboardCredentialCapturePolicy.isCredentialReady(
                    capturedCredential,
                    requiredNames: self.requiredCookieNames
                ) else {
                    guard let delay = DashboardCredentialCapturePolicy.nextAutomaticRetryDelay(
                        for: self.provider,
                        completedRetryCount: completedRetryCount
                    ) else {
                        return
                    }

                    DispatchQueue.main.async {
                        self.scheduleCookieCaptureRetry(
                            completedRetryCount: completedRetryCount + 1,
                            delay: delay
                        )
                    }
                    return
                }

                let emissionDecision = self.captureLifecycle.automaticEmissionDecision(
                    credentialIdentity: capturedCredential.captureIdentity
                )
                switch emissionDecision {
                case .emit:
                    break
                case .unchanged:
                    guard let delay = DashboardCredentialCapturePolicy.nextAutomaticRetryDelay(
                        for: self.provider,
                        completedRetryCount: completedRetryCount
                    ) else { return }
                    DispatchQueue.main.async {
                        self.scheduleCookieCaptureRetry(
                            completedRetryCount: completedRetryCount + 1,
                            delay: delay
                        )
                    }
                    return
                case .blocked:
                    return
                }
                self.pendingCookieCaptureWorkItem?.cancel()
                DispatchQueue.main.async {
                    self.onCredentialAvailable(capturedCredential)
                }
            }
        }

        private func captureCredentialForManualSave(completedRetryCount: Int) {
            guard let webView else {
                DispatchQueue.main.async {
                    self.onManualCredentialCaptured(DashboardCapturedCredential(provider: self.provider, cookieHeader: ""))
                }
                return
            }

            captureCredential(from: webView) { [weak self] capturedCredential in
                guard let self else { return }
                if DashboardCredentialCapturePolicy.shouldRetryCapture(
                    capturedCredential,
                    requiredNames: self.requiredCookieNames,
                    completedRetryCount: completedRetryCount,
                    retryDelays: DashboardCredentialCapturePolicy.manualRetryDelays
                ) {
                    let delay = DashboardCredentialCapturePolicy.manualRetryDelays[completedRetryCount]
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.captureCredentialForManualSave(completedRetryCount: completedRetryCount + 1)
                    }
                    return
                }

                DispatchQueue.main.async {
                    self.onManualCredentialCaptured(capturedCredential)
                }
            }
        }

        private func captureCredential(from webView: WKWebView, completion: @escaping (DashboardCapturedCredential) -> Void) {
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self, weak webView] cookies in
                guard let self, let webView else { return }
                let cookieHeader = DashboardCookieBuilder.cookieHeader(
                    from: cookies,
                    domains: self.cookieDomains
                )

                self.captureWebStorageFieldsIfAllowed(from: webView) { [weak self] webStorageFields in
                    guard let self else { return }
                    let capturedCredential = DashboardCapturedCredential(
                        provider: self.provider,
                        cookieHeader: self.mergedCookieHeader(cookieHeader, with: webStorageFields),
                        webStorageFields: webStorageFields
                    )

                    completion(capturedCredential)
                }
            }
        }

        private func captureWebStorageFieldsIfAllowed(from webView: WKWebView, completion: @escaping ([String: String]) -> Void) {
            guard let host = webView.url?.host, matchesAllowedDomain(host) else {
                completion([:])
                return
            }

            captureWebStorageFields(from: webView, completion: completion)
        }

        private func captureWebStorageFields(from webView: WKWebView, completion: @escaping ([String: String]) -> Void) {
            let script = """
              const keys = [
                'kimi-auth', 'accessToken', 'access_token', 'authorization', 'bearerToken', 'bearer_token', 'token',
                'deviceID', 'deviceId', 'x-msh-device-id',
                'sessionID', 'sessionId', 'x-msh-session-id',
                'trafficID', 'trafficId', 'x-traffic-id',
                'userTicket', 'user_ticket', 'userticket',
                'uuid',
                'passport_uuid', 'passportUuid', 'passportUUID', 'passport-uuid',
                'passpoart_uuid', 'passpoartUuid', 'passpoartUUID', 'passpoart-uuid',
                'lt', 'loginTicket', 'login_ticket'
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
              try {
                if (location.hostname === 'anysearch.com' || location.hostname.endsWith('.anysearch.com')) {
                  const authState = JSON.parse(localStorage.getItem('search-template-auth-state') || '{}');
                  const state = authState && authState.state;
                  if (state && typeof state.accessToken === 'string') output.anysearchAccessToken = state.accessToken;
                  if (state && typeof state.refreshToken === 'string') output.anysearchRefreshToken = state.refreshToken;
                  if (state && Number.isInteger(state.expiresAt)) output.anysearchExpiresAt = String(state.expiresAt);
                }
              } catch (_) {}
              try {
                if (document.cookie) output.documentCookie = document.cookie;
              } catch (_) {}
              const cookieValue = (name) => {
                try {
                  const match = document.cookie.match(new RegExp('(^| )' + name + '=([^;]+)'));
                  return match ? match[2] : '';
                } catch (_) {
                  return '';
                }
              };
              const isLongCatHost = (() => {
                try {
                  return location.hostname === 'longcat.chat' || location.hostname.endsWith('.longcat.chat');
                } catch (_) {
                  return false;
                }
              })();
              if (isLongCatHost) {
                let uuid = cookieValue('uuid') || cookieValue('passport_uuid');
                if (!uuid) {
                  try {
                    const randomText = (crypto.randomUUID ? crypto.randomUUID() : String(Math.random()).slice(2) + String(Date.now()))
                      .replaceAll('-', '')
                      .slice(0, 20);
                    uuid = `${randomText}.${String(Date.now()).slice(0, 10)}.1.0.0`;
                    document.cookie = `passport_uuid=${uuid}; path=/`;
                  } catch (_) {}
                }
                if (uuid && !output.uuid && !output.passport_uuid) output.passport_uuid = uuid;
                try {
                  const response = await fetch('/api/v1/user-current', {
                    method: 'GET',
                    credentials: 'same-origin',
                    headers: {
                      'x-requested-with': 'XMLHttpRequest',
                      'X-Client-Language': 'zh'
                    }
                  });
                  if (response.ok) {
                    const body = await response.json();
                    const data = body && (body.data || body.result || body.Data || body.Result);
                    if (data) {
                      if (data.token) output.longcatUserCurrentToken = String(data.token);
                      if (data.loginStatus !== undefined && data.loginStatus !== null) output.longcatLoginStatus = String(data.loginStatus);
                      if (data.userId !== undefined && data.userId !== null) output.longcatUserId = String(data.userId);
                    }
                  }
                } catch (_) {}
              }
              return output;
            """

            webView.callAsyncJavaScript(script, arguments: [:], in: nil, in: .page) { result in
                let value: Any?
                switch result {
                case .success(let resultValue):
                    value = resultValue
                case .failure:
                    value = nil
                }
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

        private func mergedCookieHeader(_ cookieHeader: String, with webStorageFields: [String: String]) -> String {
            guard let documentCookie = webStorageFields["documentCookie"]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !documentCookie.isEmpty else {
                return cookieHeader
            }

            var existingNames = Set<String>()
            var cookieParts: [String] = []
            for part in cookieHeader.split(separator: ";") {
                let trimmed = String(part).trimmingCharacters(in: .whitespacesAndNewlines)
                guard let name = trimmed.split(separator: "=", maxSplits: 1).first, !trimmed.isEmpty else {
                    continue
                }
                existingNames.insert(String(name))
                cookieParts.append(trimmed)
            }

            for part in documentCookie.split(separator: ";") {
                let trimmed = String(part).trimmingCharacters(in: .whitespacesAndNewlines)
                let pieces = trimmed.split(separator: "=", maxSplits: 1)
                guard pieces.count == 2 else { continue }
                let name = String(pieces[0])
                guard !existingNames.contains(name) else { continue }
                existingNames.insert(name)
                cookieParts.append(trimmed)
            }

            return cookieParts.joined(separator: "; ")
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
