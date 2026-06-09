import SwiftUI
import AppKit
import WebKit

struct DashboardReauthSheet: View {
    @ObservedObject var monitor: QuotaMonitor
    @Environment(\.dismiss) private var dismiss

    let provider: Provider
    let key: APIKey?

    @State private var statusMessage: String?
    @State private var isSaving = false
    @State private var didAutoSave = false

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
                }

                Spacer()
            }

            if let config {
                DashboardWebView(
                    url: config.loginURL,
                    cookieDomains: config.cookieDomains,
                    requiredCookieNames: config.requiredCookieNames,
                    onCookiesAvailable: { cookieHeader in
                        autoSaveCookies(cookieHeader)
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
        isSaving = true
        statusMessage = L10n.t(.autoSavingCookie)

        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            let cookieHeader = DashboardCookieBuilder.cookieHeader(
                from: cookies,
                domains: config.cookieDomains
            )

            DispatchQueue.main.async {
                persistCookies(cookieHeader, allowEmptyStatus: true, dismissAfterSave: true)
            }
        }
    }

    private func autoSaveCookies(_ cookieHeader: String) {
        guard !didAutoSave, !isSaving else { return }
        isSaving = true
        statusMessage = L10n.t(.autoSavingCookie)
        persistCookies(cookieHeader, allowEmptyStatus: false, dismissAfterSave: false)
    }

    private func persistCookies(_ cookieHeader: String, allowEmptyStatus: Bool, dismissAfterSave: Bool) {
        guard let config else {
            isSaving = false
            return
        }

        guard !cookieHeader.isEmpty else {
            isSaving = false
            if allowEmptyStatus {
                statusMessage = L10n.t(.noCookiesFound)
            }
            return
        }

        let missingCookieNames = DashboardCookieBuilder.missingRequiredCookieNames(
            inCookieHeader: cookieHeader,
            requiredNames: config.requiredCookieNames
        )
        guard missingCookieNames.isEmpty else {
            isSaving = false
            statusMessage = L10n.format(.missingRequiredCookies, missingCookieNames.joined(separator: ", "))
            return
        }

        validateAndPersistCookies(cookieHeader, config: config, dismissAfterSave: dismissAfterSave)
    }

    private func validateAndPersistCookies(_ cookieHeader: String, config: DashboardReauthConfig, dismissAfterSave: Bool) {
        didAutoSave = true
        statusMessage = L10n.t(.checkingCookie)

        let existingKey = key ?? monitor.apiKeys.first(where: { $0.provider == provider })
        let candidateKey: APIKey
        if var updatedKey = key ?? monitor.apiKeys.first(where: { $0.provider == provider }) {
            updatedKey.key = DashboardCookieBuilder.reauthenticatedSecret(
                cookieHeader: cookieHeader,
                existingSecret: updatedKey.key
            )
            if updatedKey.name.isEmpty || updatedKey.isBusinessInvocationCredential {
                updatedKey.name = config.defaultKeyName
            }
            updatedKey.note = updatedKey.note ?? L10n.t(.dashboardSession)
            updatedKey.quotaLabel = L10n.t(.cookieSaved)
            updatedKey.quotaText = LocalizedTextDescriptor.localized(.cookieSaved)
            updatedKey.lastUpdated = Date()
            candidateKey = updatedKey
        } else {
            candidateKey = APIKey(
                name: config.defaultKeyName,
                key: cookieHeader,
                provider: provider,
                note: L10n.t(.dashboardSession),
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
                    verifiedKey.quotaLabel = result.quotaLabel
                    verifiedKey.quotaText = result.quotaText
                    verifiedKey.lastHTTPStatus = result.httpStatus
                    verifiedKey.lastDiagnosticMessage = result.diagnosticMessage
                    verifiedKey.lastDiagnosticText = result.diagnosticText
                    verifiedKey.lastUpdated = Date()

                    if existingKey == nil {
                        monitor.addKey(verifiedKey)
                    } else {
                        monitor.updateKey(verifiedKey)
                    }

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
            } catch {
                await MainActor.run {
                    isSaving = false
                    didAutoSave = false
                    statusMessage = L10n.format(.reauthValidationFailed, error.localizedDescription)
                }
            }
        }
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
    let url: URL
    let cookieDomains: [String]
    let requiredCookieNames: [String]
    let onCookiesAvailable: (String) -> Void

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
            cookieDomains: cookieDomains,
            requiredCookieNames: requiredCookieNames,
            onCookiesAvailable: onCookiesAvailable
        )
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKHTTPCookieStoreObserver, NSWindowDelegate {
        private let cookieDomains: [String]
        private let requiredCookieNames: [String]
        private let onCookiesAvailable: (String) -> Void
        private var didEmitCookies = false
        private weak var webView: WKWebView?
        private var observedCookieStore: WKHTTPCookieStore?
        private var oauthPopupWindows: [ObjectIdentifier: OAuthPopupWindow] = [:]
        private(set) var hasStartedLoading = false

        init(cookieDomains: [String], requiredCookieNames: [String], onCookiesAvailable: @escaping (String) -> Void) {
            self.cookieDomains = cookieDomains
            self.requiredCookieNames = requiredCookieNames
            self.onCookiesAvailable = onCookiesAvailable
        }

        deinit {
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

            captureCookiesIfReady()
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
            captureCookiesIfReady()
        }

        private func captureCookiesIfReady() {
            guard !didEmitCookies,
                  let webView,
                  let host = webView.url?.host,
                  matchesAllowedDomain(host) else {
                return
            }

            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self, !self.didEmitCookies else { return }
                let cookieHeader = DashboardCookieBuilder.cookieHeader(
                    from: cookies,
                    domains: self.cookieDomains
                )
                guard !cookieHeader.isEmpty else { return }
                guard DashboardCookieBuilder.containsRequiredCookie(
                    from: cookies,
                    domains: self.cookieDomains,
                    requiredNames: self.requiredCookieNames
                ) else {
                    return
                }

                self.didEmitCookies = true
                DispatchQueue.main.async {
                    self.onCookiesAvailable(cookieHeader)
                }
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
