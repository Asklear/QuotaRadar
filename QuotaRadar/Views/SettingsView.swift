import AppKit
import SwiftUI
import UniformTypeIdentifiers

private let settingsCollapseAnimation = Animation.easeInOut(duration: 0.16)

final class SettingsNavigationStore: ObservableObject {
    static let shared = SettingsNavigationStore()

    @Published var selection: SettingsDestination? = .providers
    @Published var focusedProvider: Provider?
    @Published var focusedCredentialID: UUID?
    @Published var focusedMenuSignalReason: MenuSignalReason?

    func select(_ destination: SettingsDestination) {
        selection = destination
    }

    func focusProvider(_ provider: Provider, credentialID: UUID?, reason: MenuSignalReason?) {
        selection = .providers
        focusedProvider = provider
        focusedCredentialID = credentialID
        focusedMenuSignalReason = reason
    }

    var focusedProviderScrollID: String? {
        focusedProvider.map(Self.providerScrollID)
    }

    static func providerScrollID(_ provider: Provider) -> String {
        "provider-\(provider.rawValue)"
    }
}

struct SettingsView: View {
    private static let sidebarWidth: CGFloat = 220
    private static let dividerWidth: CGFloat = 1

    @ObservedObject var monitor: QuotaMonitor
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @ObservedObject private var navigationStore = SettingsNavigationStore.shared

    init(monitor: QuotaMonitor) {
        self.monitor = monitor
    }

    private var currentSelection: SettingsDestination {
        navigationStore.selection ?? .providers
    }

    var body: some View {
        let currentLanguage = languageStore.language

        GeometryReader { geometry in
            let contentWidth = max(0, geometry.size.width - Self.sidebarWidth - Self.dividerWidth)

            HStack(spacing: 0) {
                SettingsSidebarView(monitor: monitor, selection: $navigationStore.selection)
                    .frame(width: Self.sidebarWidth, height: geometry.size.height, alignment: .topLeading)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)

                Divider()
                    .frame(width: Self.dividerWidth)
                    .overlay(Color.primary.opacity(0.08))

                selectedContent
                    .frame(width: contentWidth, height: geometry.size.height, alignment: .topLeading)
                    .background(ModernWindowBackground())
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(ModernWindowBackground())
        .id(currentLanguage)
        .onAppear {
            if navigationStore.selection == nil {
                navigationStore.selection = .providers
            }
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch currentSelection {
        case .apiKeys:
            KeysManagementView(monitor: monitor)
        case .providers:
            ProvidersView(monitor: monitor)
        case .diagnostics:
            DiagnosticsView(monitor: monitor)
        case .settings:
            AppSettingsView(monitor: monitor)
        case .about:
            AboutView()
        }
    }
}

enum SettingsDestination: String, CaseIterable, Identifiable, Hashable {
    case providers
    case apiKeys
    case diagnostics
    case settings
    case about

    var id: String { rawValue }

    static let navigationOrder: [SettingsDestination] = [.providers, .apiKeys, .diagnostics, .settings]

    var title: String {
        switch self {
        case .apiKeys:
            return L10n.t(.apiKeysTab)
        case .providers:
            return L10n.t(.providersTab)
        case .diagnostics:
            return L10n.t(.diagnosticsTab)
        case .settings:
            return L10n.t(.settingsTab)
        case .about:
            return L10n.t(.aboutTab)
        }
    }

    var icon: String {
        switch self {
        case .apiKeys:
            return "key.fill"
        case .providers:
            return "server.rack"
        case .diagnostics:
            return "stethoscope"
        case .settings:
            return "slider.horizontal.3"
        case .about:
            return "info.circle.fill"
        }
    }
}

struct SettingsSidebarView: View {
    @ObservedObject var monitor: QuotaMonitor
    @ObservedObject private var updater = GitHubReleaseUpdater.shared
    @Binding var selection: SettingsDestination?

    private var configuredProviders: Int {
        Set(monitor.apiKeys.map { $0.provider }).intersection(Set(Provider.visibleCases)).count
    }

    private var lowQuotaCount: Int {
        monitor.apiKeys.filter { $0.isLow || $0.isExhausted || $0.isCredentialExpired }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 11) {
                QuotaRadarMark(size: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Quota Radar")
                        .font(.system(size: 17, weight: .semibold))
                    Text(L10n.t(.apiQuotaTitle))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 24)

            VStack(spacing: 4) {
                ForEach(SettingsDestination.navigationOrder) { destination in
                    SidebarNavigationButton(destination: destination, selection: $selection)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.t(.sidebarStatistics))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 10)

                SidebarMetricRow(title: L10n.t(.keys), value: "\(monitor.apiKeys.count)")
                SidebarMetricRow(title: L10n.t(.providers), value: "\(configuredProviders)")
                SidebarMetricRow(
                    title: L10n.t(.low),
                    value: "\(lowQuotaCount)",
                    tint: lowQuotaCount > 0 ? .orange : .secondary
                )
            }

            Spacer()

            SidebarUpdateFooter(updater: updater)
        }
        .padding(.horizontal, 12)
        .navigationTitle("Quota Radar")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.thinMaterial)
    }
}

struct SidebarUpdateFooter: View {
    @ObservedObject var updater: GitHubReleaseUpdater

    private var isBusy: Bool {
        updater.isChecking || updater.isDownloading
    }

    private var statusText: String {
        updater.statusMessage ?? L10n.t(.checkForUpdates)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .overlay(Color.primary.opacity(0.08))

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t(.version))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(statusText)
                        .font(.caption2)
                        .foregroundStyle(isBusy ? .primary : .tertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 6)

                Button {
                    updater.checkForUpdatesFromUI()
                } label: {
                    ZStack {
                        if isBusy {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.66)
                        } else {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                .help(L10n.t(.checkForUpdatesDescription))
                .accessibilityLabel(L10n.t(.checkForUpdates))
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 12)
    }
}

struct SidebarNavigationButton: View {
    let destination: SettingsDestination
    @Binding var selection: SettingsDestination?

    private var isSelected: Bool {
        selection == destination
    }

    var body: some View {
        Button {
            selection = destination
        } label: {
            HStack(spacing: 10) {
                Image(systemName: destination.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 20)

                Text(destination.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
                    .truncationMode(.tail)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.accentColor.opacity(0.16) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .primary : .secondary)
    }
}

struct SidebarMetricRow: View {
    let title: String
    let value: String
    var tint: Color = .secondary

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
    }
}

struct ModernWindowBackground: View {
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .windowBackground, blendingMode: .behindWindow)
            Color(nsColor: .windowBackgroundColor)
                .opacity(0.76)
        }
        .ignoresSafeArea()
    }
}

struct ModernPage<Content: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let maxContentWidth: CGFloat
    let scrollTargetID: String?
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        maxContentWidth: CGFloat = 920,
        scrollTargetID: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.maxContentWidth = maxContentWidth
        self.scrollTargetID = scrollTargetID
        self.content = content()
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHeader(title: title, subtitle: subtitle, systemImage: systemImage)
                    content
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 22)
                .frame(maxWidth: maxContentWidth, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollContentBackground(.hidden)
            .onAppear {
                scrollToTargetIfNeeded(with: proxy)
            }
            .onChange(of: scrollTargetID) { _, _ in
                scrollToTargetIfNeeded(with: proxy)
            }
        }
    }

    private func scrollToTargetIfNeeded(with proxy: ScrollViewProxy) {
        guard let scrollTargetID else { return }
        DispatchQueue.main.async {
            withAnimation(settingsCollapseAnimation) {
                proxy.scrollTo(scrollTargetID, anchor: .top)
            }
        }
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String?
    let systemImage: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 24, weight: .semibold))

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }
}

struct MaterialPanel<Content: View>: View {
    var padding: CGFloat = 14
    let content: Content

    init(padding: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
}

struct InlineStatusMessage: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
            Text(text)
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct EmptyContentPanel: View {
    let title: String
    let systemImage: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        MaterialPanel(padding: 24) {
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.headline)

                if let actionTitle, let action {
                    Button(action: action) {
                        Label(actionTitle, systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Keys Management

struct KeysManagementView: View {
    @ObservedObject var monitor: QuotaMonitor
    @State private var showingAddSheet = false
    @State private var editingKey: APIKey?
    @State private var importMessage: String?

    private var keyProviderCategories: [ProviderCategoryStats] {
        let stats: [ProviderStats] = monitor.orderedVisibleProviders.compactMap { provider in
            let providerKeys = APIKey.sortedByCurrentQuota(
                monitor.apiKeys.filter { $0.provider == provider }
            )
            guard !providerKeys.isEmpty else { return nil }
            return ProviderStats(provider: provider, keys: providerKeys)
        }
        let grouped = Dictionary(grouping: stats) { $0.provider.statusBarCategoryTitle }
        return Provider.categoryDisplayOrder.compactMap { title in
            guard let stats = grouped[title], !stats.isEmpty else { return nil }
            return ProviderCategoryStats(title: title, stats: stats)
        }
    }

    var body: some View {
        ModernPage(
            title: L10n.t(.apiKeysTab),
            subtitle: L10n.format(.apiKeysCount, monitor.apiKeys.count),
            systemImage: "key.fill"
        ) {
            if let importMessage {
                InlineStatusMessage(text: importMessage)
            }

            APIKeyConfigurationPanel(
                onAddKey: { showingAddSheet = true },
                onImportEnv: importEnvFile
            )

            if keyProviderCategories.isEmpty {
                EmptyContentPanel(
                    title: L10n.t(.noApiKeys),
                    systemImage: "key.slash",
                    actionTitle: L10n.t(.addKey),
                    action: { showingAddSheet = true }
                )
            } else {
                VStack(spacing: 14) {
                    ForEach(keyProviderCategories) { category in
                        KeyProviderCategorySection(
                            category: category,
                            monitor: monitor,
                            editingKey: $editingKey
                        )
                    }
                }
            }
        }
        .navigationTitle(L10n.t(.apiKeysTab))
        .sheet(isPresented: $showingAddSheet) {
            AddKeySheet(monitor: monitor)
        }
        .sheet(item: $editingKey) { key in
            EditKeySheet(monitor: monitor, key: key)
        }
    }

    private func importEnvFile() {
        let panel = NSOpenPanel()
        panel.title = L10n.t(.importPanelTitle)
        panel.message = L10n.t(.importPanelMessage)
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.allowedContentTypes = [.plainText, .data]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let importedKeys = EnvImporter.parseEnvFile(at: url)
        let summary = monitor.importKeys(importedKeys)

        if summary.added == 0, summary.updated == 0 {
            importMessage = L10n.format(.importNoKeys, url.lastPathComponent)
        } else {
            importMessage = L10n.format(.importSummary, summary.added, summary.updated)
        }
    }
}

struct APIKeyConfigurationPanel: View {
    let onAddKey: () -> Void
    let onImportEnv: () -> Void

    var body: some View {
        MaterialPanel(padding: 18) {
            HStack(spacing: 16) {
                Image(systemName: "key.radiowaves.forward.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 42, height: 42)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t(.apiKeyConfigurationDescription))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    Button(action: onImportEnv) {
                        Label(L10n.t(.importFromEnv), systemImage: "square.and.arrow.down")
                    }
                    .controlSize(.small)

                    Button(action: onAddKey) {
                        Label(L10n.t(.addKey), systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.t(.apiKeyConfiguration))
    }
}

struct KeyProviderCategorySection: View {
    let category: ProviderCategoryStats
    @ObservedObject var monitor: QuotaMonitor
    @Binding var editingKey: APIKey?
    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 10) {
            CollapsibleBanner(
                title: L10n.categoryTitle(category.title),
                subtitle: L10n.format(.categoryCounts, category.providerCount, category.keyCount),
                systemImage: category.title == "AI Search" ? "magnifyingglass.circle.fill" : "cpu.fill",
                accessory: L10n.format(.activeCount, category.activeKeyCount),
                isExpanded: isExpanded
            ) {
                withAnimation(settingsCollapseAnimation) { isExpanded.toggle() }
            }

            if isExpanded {
                VStack(spacing: 12) {
                    ForEach(category.stats) { stat in
                        ProviderKeyRowsSection(
                            stat: stat,
                            monitor: monitor,
                            editingKey: $editingKey
                        )
                    }
                }
                .transition(.opacity)
            }
        }
    }
}

struct CollapsibleBanner: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var accessory: String? = nil
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 28, height: 28)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let accessory {
                    Text(accessory)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.10), in: Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Color.primary.opacity(isExpanded ? 0.045 : 0.025),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(isExpanded ? 0.10 : 0.06), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct ProviderKeyRowsSection: View {
    let stat: ProviderStats
    @ObservedObject var monitor: QuotaMonitor
    @Binding var editingKey: APIKey?
    @State private var isExpanded = true

    var body: some View {
        MaterialPanel {
            VStack(spacing: 10) {
                APIKeyProviderBanner(
                    provider: stat.provider,
                    keyCount: stat.keys.count,
                    activeCount: stat.keys.filter { $0.isActive }.count,
                    isExpanded: isExpanded,
                    onToggle: {
                        withAnimation(settingsCollapseAnimation) { isExpanded.toggle() }
                    }
                )

                if isExpanded {
                    Divider()

                    VStack(spacing: 4) {
                        ForEach(stat.sortedKeysByCurrentQuota) { key in
                            APIKeyManagementRow(
                                key: key,
                                onSetActive: { isActive in
                                    var updated = key
                                    updated.isActive = isActive
                                    monitor.updateKey(updated)
                                },
                                onEdit: {
                                    editingKey = key
                                }
                            )
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
    }
}

struct APIKeyProviderBanner: View {
    private static let providerHeaderLeadingPadding: CGFloat = 24

    let provider: Provider
    let keyCount: Int
    let activeCount: Int
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                ProviderIcon(provider: provider, size: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(provider.providerFamilyDisplayName())
                        .font(.system(size: 14, weight: .semibold))
                    Text(provider.planTypeDisplayName() ?? L10n.categoryTitle(provider.statusBarCategoryTitle))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(L10n.format(.activeCount, activeCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.10), in: Capsule())

                Text(L10n.format(.providerKeyCount, keyCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.10), in: Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, Self.providerHeaderLeadingPadding)
            .padding(.trailing, 10)
            .padding(.vertical, 8)
            .background(
                Color.primary.opacity(isExpanded ? 0.045 : 0.025),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct APIKeyManagementRow: View {
    let key: APIKey
    let onSetActive: (Bool) -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(key.status.color)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(key.accountDisplayTitle)
                        .font(.system(size: 13, weight: .semibold))

                    if let credentialTypeText {
                        Text(credentialTypeText)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                    }
                }

                if let accountDisplaySubtitle = key.accountDisplaySubtitle {
                    Text(accountDisplaySubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .layoutPriority(1)

            Spacer()

            CredentialRowActionGroup(
                key: key,
                statusText: statusText,
                onSetActive: onSetActive,
                onEdit: onEdit,
                onCopy: copyCredentialToPasteboard
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .contentShape(Rectangle())
    }

    private var credentialTypeText: String? {
        key.managementCredentialTypeBadgeText
    }

    private func copyCredentialToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private var statusText: String {
        key.credentialConfigurationState.displayText
    }
}

struct CredentialRowActionGroup: View {
    private static let statusPillWidth: CGFloat = 126
    private static let toggleWidth: CGFloat = 42
    private static let actionButtonSize: CGFloat = 28

    let key: APIKey
    let statusText: String
    let onSetActive: (Bool) -> Void
    let onEdit: () -> Void
    let onCopy: (String) -> Void

    private var stateColor: Color {
        key.credentialConfigurationState.color
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(statusText)
                .font(.caption.weight(.medium))
                .foregroundStyle(stateColor)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(width: Self.statusPillWidth)
                .background(stateColor.opacity(0.12), in: Capsule())

            Toggle(isOn: Binding(get: { key.isActive }, set: { onSetActive($0) })) {
                Text(L10n.t(.active))
            }
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.mini)
            .frame(width: Self.toggleWidth)
            .help(L10n.t(.active))

            copyActionSlot

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: Self.actionButtonSize, height: Self.actionButtonSize)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .help(L10n.t(.editAPIKey))
        }
    }

    @ViewBuilder
    private var copyActionSlot: some View {
        ZStack {
            Color.clear

            if let copyableCredentialValue = key.copyableCredentialValue {
                Button(action: { onCopy(copyableCredentialValue) }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: Self.actionButtonSize, height: Self.actionButtonSize)
                        .background(.thinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .help(L10n.t(.copyCredential))
            }
        }
        .frame(width: Self.actionButtonSize, height: Self.actionButtonSize)
    }
}

// MARK: - Add Key Sheet

struct AddKeySheet: View {
    @ObservedObject var monitor: QuotaMonitor
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var key = ""
    @State private var companionAPIKey = ""
    @State private var provider: Provider = .tavily
    @State private var note = ""
    @State private var curlText = ""
    @State private var importError: String?
    @State private var showingReauth = false
    @State private var lastAutoFilledCredentialName = Provider.tavily.defaultCredentialName
    @State private var showCredentialValue = false
    @State private var showCompanionAPIKey = false

    private var credentialLabel: String {
        let credentialKind: CredentialKind = provider.capability.credentialKind
        switch credentialKind {
        case .apiKey:
            return L10n.t(.apiKey)
        case .dashboardCookie:
            return L10n.t(.dashboardSession)
        case .adminCredential:
            return L10n.t(.adminCredential)
        }
    }

    private var acceptsDashboardCookie: Bool {
        provider.capability.credentialKind == CredentialKind.dashboardCookie
    }

    private var canAddCredential: Bool {
        let hasPrimaryCredential = !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasCompanionAPIKey = provider.supportsCompanionAPIKeyStorage
            && !companionAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasPrimaryCredential || hasCompanionAPIKey
    }

    var body: some View {
        CredentialEditorShell(
            title: L10n.t(.addAPIKey),
            provider: $provider,
            providers: monitor.orderedVisibleProviders
        ) {
            AddCredentialDetailPane(
                provider: provider,
                credentialLabel: credentialLabel,
                acceptsDashboardCookie: acceptsDashboardCookie,
                companionAPIKey: $companionAPIKey,
                name: $name,
                key: $key,
                note: $note,
                curlText: $curlText,
                showCredentialValue: $showCredentialValue,
                showCompanionAPIKey: $showCompanionAPIKey,
                importError: importError,
                onImportCurl: importCurlCredential,
                onReauthenticate: { showingReauth = true }
            )
        } footer: {
            AddCredentialActionBar(
                canAdd: canAddCredential,
                onCancel: { dismiss() },
                onAdd: addCredential
            )
        }
        .frame(width: 760, height: 540)
        .background(.regularMaterial)
        .sheet(isPresented: $showingReauth) {
            DashboardReauthSheet(
                monitor: monitor,
                provider: provider,
                key: nil,
                onSaved: handleDashboardCredentialSaved
            )
        }
        .onChange(of: provider) { oldProvider, newProvider in
            syncDefaultCredentialName(for: newProvider, replacing: oldProvider)
            importError = nil
            curlText = ""
            if !newProvider.supportsCompanionAPIKeyStorage {
                companionAPIKey = ""
            }
        }
        .onAppear {
            syncDefaultCredentialName(for: provider)
        }
    }

    private func importCurlCredential() {
        do {
            let parsed = try CurlCredentialParser.parse(curlText, provider: provider)
            key = parsed.serializedCredential
            syncDefaultCredentialName(for: provider)
            importError = nil
        } catch {
            importError = L10n.t(.curlImportFailed)
        }
    }

    private func addCredential() {
        let trimmedCompanionAPIKey = companionAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCredential = key.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedCredential.isEmpty else {
            if provider.supportsCompanionAPIKeyStorage, !trimmedCompanionAPIKey.isEmpty {
                monitor.addKey(APIKey(
                    name: provider.copyableAPIKeyCredentialName,
                    key: trimmedCompanionAPIKey,
                    provider: provider
                ))
            }
            dismiss()
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameForSaving = trimmedName.isEmpty ? provider.defaultCredentialName : trimmedName
        let newKey = APIKey(
            name: nameForSaving,
            key: trimmedCredential,
            provider: provider,
            note: note.isEmpty ? nil : note
        )
        monitor.addKey(newKey)

        if provider.supportsCompanionAPIKeyStorage, !trimmedCompanionAPIKey.isEmpty {
            monitor.addKey(APIKey(
                name: provider.copyableAPIKeyCredentialName,
                key: trimmedCompanionAPIKey,
                provider: provider,
                linkedAuthorizationID: newKey.id
            ))
        }

        refreshProviderAfterSavingCredential(newKey)
        dismiss()
    }

    private func handleDashboardCredentialSaved(_ savedKey: APIKey) {
        saveCompanionAPIKeyIfNeeded(linkedTo: savedKey)
        showingReauth = false
        dismiss()
    }

    private func saveCompanionAPIKeyIfNeeded(linkedTo savedKey: APIKey) {
        guard savedKey.provider == provider,
              provider.supportsCompanionAPIKeyStorage else {
            return
        }

        let trimmedCompanionAPIKey = companionAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCompanionAPIKey.isEmpty else {
            return
        }

        if let existingCompanion = monitor.apiKeys.first(where: {
            $0.provider == provider
                && $0.isStoredAPIKeyOnlyCredential
                && ($0.linkedAuthorizationID == savedKey.id || $0.linkedAuthorizationID == nil)
        }) {
            var updatedCompanion = existingCompanion
            updatedCompanion.name = provider.copyableAPIKeyCredentialName
            updatedCompanion.key = trimmedCompanionAPIKey
            updatedCompanion.linkedAuthorizationID = savedKey.id
            monitor.updateKey(updatedCompanion)
        } else {
            monitor.addKey(APIKey(
                name: provider.copyableAPIKeyCredentialName,
                key: trimmedCompanionAPIKey,
                provider: provider,
                linkedAuthorizationID: savedKey.id
            ))
        }
    }

    private func refreshProviderAfterSavingCredential(_ savedKey: APIKey) {
        guard savedKey.isActive,
              !savedKey.isStoredAPIKeyOnlyCredential,
              savedKey.provider.supportsQuotaQuery,
              savedKey.provider.capability.quotaRefreshKind == .refreshQuota else {
            return
        }
        monitor.refreshProvider(provider)
    }

    private func syncDefaultCredentialName(for newProvider: Provider, replacing oldProvider: Provider? = nil) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let generatedNames = Set([
            lastAutoFilledCredentialName,
            oldProvider?.defaultCredentialName,
            newProvider.defaultCredentialName
        ].compactMap { $0 })

        guard trimmedName.isEmpty || generatedNames.contains(trimmedName) else {
            return
        }

        name = newProvider.defaultCredentialName
        lastAutoFilledCredentialName = newProvider.defaultCredentialName
    }
}

struct CredentialEditorShell<Content: View, Footer: View>: View {
    let title: String
    @Binding var provider: Provider
    let providers: [Provider]
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(spacing: 0) {
            AddCredentialHeader(title: title, provider: provider)

            Divider()

            HStack(spacing: 0) {
                AddCredentialProviderList(provider: $provider, providers: providers)
                    .frame(width: 220)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.42))

                Divider()

                ScrollView {
                    content
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.20))
            }

            Divider()

            footer
        }
    }
}

struct AddCredentialHeader: View {
    let title: String
    let provider: Provider

    var body: some View {
        HStack(spacing: 12) {
            ProviderIcon(provider: provider, size: 28, style: .compactBadge)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))

                HStack(spacing: 5) {
                    Text(provider.providerFamilyDisplayName())

                    if let planName = provider.planTypeDisplayName() {
                        Text(planName)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(provider.color.opacity(0.12), in: Capsule())
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct ProviderDashboardJumpButton: View {
    let provider: Provider
    var size: CGFloat = 28

    var body: some View {
        if let dashboard = provider.dashboardURL,
           let url = URL(string: dashboard) {
            Link(destination: url) {
                ProviderActionIcon(
                    systemName: "arrow.up.right.square",
                    tint: provider.color,
                    size: size
                )
            }
            .buttonStyle(.plain)
            .help(L10n.t(.openDashboard))
            .accessibilityLabel(L10n.t(.openDashboard))
        }
    }
}

struct ProviderReauthenticationButton: View {
    let provider: Provider
    var size: CGFloat = 28
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ProviderActionIcon(
                systemName: "person.badge.key.fill",
                tint: provider.color,
                size: size
            )
        }
        .buttonStyle(.plain)
        .help(L10n.t(.updateLoginAuthorizationAction))
        .accessibilityLabel(L10n.t(.updateLoginAuthorizationAction))
    }
}

struct ProviderActionIcon: View {
    let systemName: String
    let tint: Color
    let size: CGFloat

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.43, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(.thinMaterial, in: Circle())
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.6)
            )
    }
}

struct ProviderWatchedToggleButton: View {
    let isWatched: Bool
    let size: CGFloat
    let action: () -> Void

    private var helpText: String {
        isWatched ? L10n.t(.removeWatchedProviderAction) : L10n.t(.addWatchedProviderAction)
    }

    var body: some View {
        Button(action: action) {
            ProviderActionIcon(
                systemName: isWatched ? "star.fill" : "star",
                tint: isWatched ? .yellow : .secondary,
                size: size
            )
        }
        .buttonStyle(.plain)
        .help(helpText)
        .accessibilityLabel(helpText)
    }
}

struct ProviderQuotaActionGroup: View {
    let provider: Provider
    let isWatched: Bool
    let isRefreshing: Bool
    let canRefresh: Bool
    let onToggleWatched: () -> Void
    let onReauthenticate: () -> Void
    let onRefresh: () -> Void

    private let size: CGFloat = 20

    private var refreshActionLabel: String {
        isRefreshing ? L10n.t(.refreshingQuotaAction) :
            provider.capability.requiresCostlyConfirmation ? L10n.t(.refreshQuotaConsumesQuotaAction) :
            L10n.t(.refreshQuotaAction)
    }

    var body: some View {
        HStack(spacing: 2) {
            actionSlot {
                ProviderWatchedToggleButton(
                    isWatched: isWatched,
                    size: size,
                    action: onToggleWatched
                )
            }

            actionSlot {
                ProviderDashboardJumpButton(provider: provider, size: size)
            }

            actionSlot {
                if provider.supportsDashboardReauthentication {
                    ProviderReauthenticationButton(provider: provider, size: size, action: onReauthenticate)
                }
            }

            actionSlot {
                if canRefresh {
                    ProviderRefreshButton(
                        provider: provider,
                        isRefreshing: .constant(isRefreshing),
                        isEnabled: canRefresh,
                        size: size,
                        helpText: refreshActionLabel,
                        accessibilityLabelText: refreshActionLabel,
                        action: onRefresh
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func actionSlot<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.clear
            content()
        }
        .frame(width: size, height: size)
    }
}

struct AddCredentialProviderList: View {
    @Binding var provider: Provider
    let providers: [Provider]

    private var groupedProviders: [String: [Provider]] {
        Dictionary(grouping: providers) { $0.statusBarCategoryTitle }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Provider.categoryDisplayOrder, id: \.self) { category in
                        if let providers = groupedProviders[category], !providers.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.categoryTitle(category))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                    .padding(.horizontal, 10)

                                ForEach(providers) { option in
                                    Button {
                                        provider = option
                                    } label: {
                                        ProviderPickerRow(provider: option, isSelected: provider == option)
                                    }
                                    .buttonStyle(.plain)
                                    .id(option)
                                }
                            }
                        }
                    }
                }
                .padding(9)
            }
            .onAppear {
                proxy.scrollTo(provider, anchor: .center)
            }
            .onChange(of: provider) { _, newValue in
                withAnimation(.easeInOut(duration: 0.16)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
}

struct ProviderPickerRow: View {
    let provider: Provider
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ProviderIcon(provider: provider, size: 22, style: .compactBadge)

            VStack(alignment: .leading, spacing: 1) {
                Text(provider.providerFamilyDisplayName())
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                if let planName = provider.planTypeDisplayName() {
                    Text(planName)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

struct AddCredentialDetailPane: View {
    let provider: Provider
    let credentialLabel: String
    let acceptsDashboardCookie: Bool
    var credentialKind: CredentialKind? = nil
    var showsCompanionAPIKeyStorage = true
    @Binding var companionAPIKey: String
    @Binding var name: String
    @Binding var key: String
    @Binding var note: String
    @Binding var curlText: String
    @Binding var showCredentialValue: Bool
    @Binding var showCompanionAPIKey: Bool
    let importError: String?
    let onImportCurl: () -> Void
    let onReauthenticate: () -> Void

    private var monitoringCredentialLabel: String {
        showsCompanionAPIKeyStorage && provider.supportsCompanionAPIKeyStorage && acceptsDashboardCookie
            ? L10n.t(.quotaMonitoringAuthorization)
            : credentialLabel
    }

    private var activeCredentialKind: CredentialKind {
        credentialKind ?? provider.capability.credentialKind
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CredentialEditorSection {
                HStack(spacing: 12) {
                    ProviderIcon(provider: provider, size: 30, style: .compactBadge)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(provider.providerFamilyDisplayName())
                            .font(.system(size: 15, weight: .semibold))

                        Text(provider.planTypeDisplayName() ?? credentialLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if provider.supportsDashboardReauthentication {
                        ProviderReauthenticationButton(provider: provider, size: 28, action: onReauthenticate)
                    }
                }
            }

            CredentialEditorSection {
                AddCredentialField(label: L10n.t(.keyName)) {
                    TextField(L10n.t(.keyName), text: $name)
                        .textFieldStyle(.roundedBorder)
                }
            }

            if showsCompanionAPIKeyStorage && provider.supportsCompanionAPIKeyStorage {
                CredentialEditorSection {
                    AddCredentialField(label: L10n.t(.apiKeyForCopy)) {
                        CredentialSecretInput(
                            label: L10n.t(.apiKey),
                            text: $companionAPIKey,
                            showCredentialValue: $showCompanionAPIKey
                        )
                    }

                    Text(L10n.t(.apiKeyForCopyHelp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            CredentialEditorSection {
                AddCredentialField(label: monitoringCredentialLabel) {
                    switch activeCredentialKind {
                    case .apiKey, .adminCredential:
                        CredentialSecretInput(
                            label: monitoringCredentialLabel,
                            text: $key,
                            showCredentialValue: $showCredentialValue
                        )
                    case .dashboardCookie:
                        CredentialSecretInput(
                            label: monitoringCredentialLabel,
                            text: $key,
                            showCredentialValue: $showCredentialValue,
                            supportsMultiline: true,
                            minLines: 3,
                            maxLines: 6
                        )
                    }
                }

                Text(L10n.t(.credentialHelp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if acceptsDashboardCookie {
                    Text(L10n.t(.quotaMonitoringAuthorizationHelp))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if provider.capability.supportsCurlImport && acceptsDashboardCookie {
                    AddCredentialField(label: L10n.t(.pasteCurl)) {
                        TextField(L10n.t(.pasteCurl), text: $curlText, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack(spacing: 8) {
                        Button(action: onImportCurl) {
                            Label(L10n.t(.pasteCurl), systemImage: "doc.on.clipboard")
                        }
                        .controlSize(.small)
                        .disabled(curlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        if let importError {
                            Text(importError)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .lineLimit(1)
                        }
                    }
                }
            }

            CredentialEditorSection {
                AddCredentialField(label: L10n.t(.noteOptional)) {
                    TextField(L10n.t(.noteOptional), text: $note)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .padding(16)
    }
}

struct CredentialEditorSection<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.075), lineWidth: 1)
        )
    }
}

struct CredentialSecretInput: View {
    let label: String
    @Binding var text: String
    @Binding var showCredentialValue: Bool
    var supportsMultiline = false
    var minLines = 1
    var maxLines = 1

    var body: some View {
        HStack(alignment: supportsMultiline && showCredentialValue ? .top : .center, spacing: 8) {
            Group {
                if showCredentialValue {
                    if supportsMultiline {
                        TextField(label, text: $text, axis: .vertical)
                            .lineLimit(minLines...maxLines)
                    } else {
                        TextField(label, text: $text)
                    }
                } else {
                    SecureField(label, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 12, design: .monospaced))

            Button {
                showCredentialValue.toggle()
            } label: {
                Image(systemName: showCredentialValue ? "eye.slash" : "eye")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(showCredentialValue ? L10n.t(.hideCredential) : L10n.t(.showCredential))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, supportsMultiline && showCredentialValue ? 8 : 7)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.86), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
    }
}

struct AddCredentialField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            content
        }
    }
}

struct AddCredentialActionBar: View {
    let canAdd: Bool
    let onCancel: () -> Void
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Spacer()

            Button(L10n.t(.cancel), action: onCancel)
                .buttonStyle(.bordered)

            Button(L10n.t(.add), action: onAdd)
                .buttonStyle(.borderedProminent)
                .disabled(!canAdd)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.55))
    }
}

// MARK: - Edit Key Sheet

struct EditKeySheet: View {
    @ObservedObject var monitor: QuotaMonitor
    @Environment(\.dismiss) private var dismiss
    let key: APIKey

    @State private var provider: Provider
    @State private var name: String
    @State private var keyValue: String
    @State private var companionAPIKey: String
    @State private var note: String
    @State private var isActive: Bool
    @State private var showingReauth = false
    @State private var curlText = ""
    @State private var importError: String?
    @State private var showCredentialValue = false
    @State private var showCompanionAPIKey = false
    @State private var lastAutoFilledCredentialName: String

    init(monitor: QuotaMonitor, key: APIKey) {
        self.monitor = monitor
        self.key = key
        _provider = State(initialValue: key.provider)
        _name = State(initialValue: key.name)
        _keyValue = State(initialValue: key.key)
        _companionAPIKey = State(initialValue: monitor.apiKeys.first {
            $0.id != key.id && $0.provider == key.provider && $0.isStoredAPIKeyOnlyCredential
        }?.key ?? "")
        _note = State(initialValue: key.note ?? "")
        _isActive = State(initialValue: key.isActive)
        _lastAutoFilledCredentialName = State(initialValue: key.name)
    }

    var body: some View {
        CredentialEditorShell(
            title: L10n.t(.editAPIKey),
            provider: $provider,
            providers: monitor.orderedVisibleProviders
        ) {
            AddCredentialDetailPane(
                provider: provider,
                credentialLabel: editCredentialLabel,
                acceptsDashboardCookie: acceptsDashboardCookie,
                credentialKind: editCredentialKind,
                showsCompanionAPIKeyStorage: showsCompanionAPIKeyField,
                companionAPIKey: $companionAPIKey,
                name: $name,
                key: $keyValue,
                note: $note,
                curlText: $curlText,
                showCredentialValue: $showCredentialValue,
                showCompanionAPIKey: $showCompanionAPIKey,
                importError: importError,
                onImportCurl: importCurlCredential,
                onReauthenticate: { showingReauth = true }
            )

            CredentialEditorSection {
                Toggle(L10n.t(.active), isOn: $isActive)
                    .toggleStyle(.switch)

                if key.isUnlimitedQuota || key.quotaLabel != nil || key.remaining != nil || key.limit != nil {
                    HStack {
                        Text(L10n.t(.quotaStatus))
                        Spacer()
                        Text(key.quotaDisplayText)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)

                    if let updated = key.lastUpdated {
                        HStack {
                            Text(L10n.t(.lastUpdated))
                            Spacer()
                            Text(L10n.shortDateTime(updated))
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }
            }
        } footer: {
            HStack {
                Button(L10n.t(.delete), role: .destructive) {
                    monitor.removeKey(id: key.id)
                    dismiss()
                }

                Spacer()

                Button(L10n.t(.cancel)) { dismiss() }
                    .buttonStyle(.bordered)

                Button(L10n.t(.save)) {
                    saveCredential()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.55))
        }
        .frame(width: 760, height: 540)
        .background(.regularMaterial)
        .sheet(isPresented: $showingReauth) {
            DashboardReauthSheet(
                monitor: monitor,
                provider: provider,
                key: key.provider == provider && key.isQuotaMonitoringAuthorizationCredential ? key : nil
            )
        }
        .onChange(of: provider) { oldProvider, newProvider in
            syncDefaultCredentialName(for: newProvider, replacing: oldProvider)
            importError = nil
            curlText = ""
            companionAPIKey = companionAPIKeyCredential(for: newProvider)?.key ?? ""
        }
    }

    private var editCredentialLabel: String {
        switch editCredentialKind {
        case .apiKey:
            return L10n.t(.apiKey)
        case .dashboardCookie:
            return L10n.t(.quotaMonitoringAuthorization)
        case .adminCredential:
            return L10n.t(.adminCredential)
        }
    }

    private var editCredentialKind: CredentialKind {
        key.isStoredAPIKeyOnlyCredential ? .apiKey : provider.capability.credentialKind
    }

    private var acceptsDashboardCookie: Bool {
        editCredentialKind == .dashboardCookie
    }

    private var showsCompanionAPIKeyField: Bool {
        provider.supportsCompanionAPIKeyStorage && !key.isStoredAPIKeyOnlyCredential
    }

    private var companionAPIKeyCredentialForCurrentProvider: APIKey? {
        companionAPIKeyCredential(for: provider)
    }

    private func companionAPIKeyCredential(for provider: Provider) -> APIKey? {
        monitor.apiKeys.first {
            $0.id != key.id
                && $0.provider == provider
                && $0.isStoredAPIKeyOnlyCredential
                && $0.linkedAuthorizationID == key.id
        } ?? monitor.apiKeys.first {
            $0.id != key.id
                && $0.provider == provider
                && $0.isStoredAPIKeyOnlyCredential
                && $0.linkedAuthorizationID == nil
        }
    }

    private func importCurlCredential() {
        do {
            let parsed = try CurlCredentialParser.parse(curlText, provider: provider)
            keyValue = parsed.serializedCredential
            importError = nil
        } catch {
            importError = L10n.t(.curlImportFailed)
        }
    }

    private func saveCredential() {
        var updated = key
        let providerChanged = updated.provider != provider
        updated.provider = provider
        updated.name = savedCredentialName
        updated.key = keyValue
        updated.note = note.isEmpty ? nil : note
        updated.isActive = isActive
        if providerChanged {
            clearQuotaState(&updated)
        }
        monitor.updateKey(updated)
        saveCompanionAPIKeyIfNeeded(for: updated)
        refreshProviderAfterSavingCredential(updated)
    }

    private func refreshProviderAfterSavingCredential(_ savedKey: APIKey) {
        guard savedKey.isActive,
              !savedKey.isStoredAPIKeyOnlyCredential,
              savedKey.provider.supportsQuotaQuery,
              savedKey.provider.capability.quotaRefreshKind == .refreshQuota else {
            return
        }
        monitor.refreshProvider(provider)
    }

    private var savedCredentialName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty else { return trimmedName }
        return key.isStoredAPIKeyOnlyCredential ? provider.copyableAPIKeyCredentialName : provider.defaultCredentialName
    }

    private func saveCompanionAPIKeyIfNeeded(for authorizationKey: APIKey) {
        guard showsCompanionAPIKeyField else { return }
        let trimmedAPIKey = companionAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty else { return }

        if var existing = companionAPIKeyCredentialForCurrentProvider {
            existing.name = provider.copyableAPIKeyCredentialName
            existing.key = trimmedAPIKey
            existing.provider = provider
            existing.linkedAuthorizationID = authorizationKey.id
            existing.note = nil
            monitor.updateKey(existing)
        } else {
            monitor.addKey(APIKey(
                name: provider.copyableAPIKeyCredentialName,
                key: trimmedAPIKey,
                provider: provider,
                linkedAuthorizationID: authorizationKey.id
            ))
        }
    }

    private func clearQuotaState(_ updated: inout APIKey) {
        updated.remaining = nil
        updated.limit = nil
        updated.resetAt = nil
        updated.planEndsAt = nil
        updated.lastUpdated = nil
        updated.lastHTTPStatus = nil
        updated.lastDiagnosticMessage = nil
        updated.lastDiagnosticText = nil
        updated.consecutiveFailureCount = 0
        updated.quotaText = nil
        updated.quotaLabel = nil
    }

    private func syncDefaultCredentialName(for newProvider: Provider, replacing oldProvider: Provider? = nil) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let generatedNames = Set([
            lastAutoFilledCredentialName,
            oldProvider?.defaultCredentialName,
            oldProvider?.copyableAPIKeyCredentialName,
            newProvider.defaultCredentialName,
            newProvider.copyableAPIKeyCredentialName
        ].compactMap { $0 })

        guard trimmedName.isEmpty || generatedNames.contains(trimmedName) else {
            return
        }

        name = key.isStoredAPIKeyOnlyCredential
            ? newProvider.copyableAPIKeyCredentialName
            : newProvider.defaultCredentialName
        lastAutoFilledCredentialName = name
    }
}

// MARK: - Providers View

struct ProvidersView: View {
    @ObservedObject var monitor: QuotaMonitor
    @ObservedObject private var navigationStore = SettingsNavigationStore.shared

    private var providerCategories: [ProviderCategoryStats] {
        let stats = monitor.orderedVisibleProviders.compactMap { provider -> ProviderStats? in
            let stat = ProviderStats(
                provider: provider,
                keys: APIKey.sortedByCurrentQuota(monitor.apiKeys.filter { $0.provider == provider })
            )
            guard !stat.sortedMonitoringKeysByCurrentQuota.isEmpty else { return nil }
            return stat
        }
        let grouped = Dictionary(grouping: stats) { $0.provider.statusBarCategoryTitle }
        return Provider.categoryDisplayOrder.compactMap { title in
            guard let stats = grouped[title], !stats.isEmpty else { return nil }
            return ProviderCategoryStats(title: title, stats: stats)
        }
    }

    private var configuredProviders: Int {
        providerCategories.map(\.providerCount).reduce(0, +)
    }

    var body: some View {
        ModernPage(
            title: L10n.t(.providersHeader),
            subtitle: L10n.format(.providersSupported, configuredProviders, Provider.visibleCases.count),
            systemImage: "server.rack",
            maxContentWidth: 1080,
            scrollTargetID: navigationStore.focusedProviderScrollID
        ) {
            if providerCategories.isEmpty {
                EmptyContentPanel(
                    title: L10n.t(.noApiKeys),
                    systemImage: "server.rack",
                    actionTitle: nil,
                    action: nil
                )
            } else {
                VStack(spacing: 14) {
                    ForEach(providerCategories) { category in
                        ProviderSettingsCategorySection(category: category, monitor: monitor)
                    }
                }
            }
        }
        .navigationTitle(L10n.t(.providersHeader))
    }
}

struct ProviderSettingsCategorySection: View {
    let category: ProviderCategoryStats
    @ObservedObject var monitor: QuotaMonitor
    @ObservedObject private var navigationStore = SettingsNavigationStore.shared
    @State private var isExpanded = true

    private var containsFocusedProvider: Bool {
        guard let focusedProvider = navigationStore.focusedProvider else { return false }
        return category.stats.contains { $0.provider == focusedProvider }
    }

    var body: some View {
        VStack(spacing: 10) {
            CollapsibleBanner(
                title: L10n.categoryTitle(category.title),
                subtitle: L10n.format(.categoryCounts, category.providerCount, category.keyCount),
                systemImage: category.title == "AI Search" ? "magnifyingglass.circle.fill" : "cpu.fill",
                accessory: L10n.format(.activeCount, category.activeKeyCount),
                isExpanded: isExpanded
            ) {
                withAnimation(settingsCollapseAnimation) { isExpanded.toggle() }
            }

            if isExpanded {
                ProviderQuotaMonitorTable(stats: category.stats, monitor: monitor)
                    .transition(.opacity)
            }
        }
        .onAppear {
            if containsFocusedProvider {
                isExpanded = true
            }
        }
        .onChange(of: navigationStore.focusedProvider) { _, _ in
            if containsFocusedProvider {
                withAnimation(settingsCollapseAnimation) { isExpanded = true }
            }
        }
    }
}

struct ProviderQuotaMonitorTable: View {
    let stats: [ProviderStats]
    @ObservedObject var monitor: QuotaMonitor

    var body: some View {
        MaterialPanel(padding: 0) {
            VStack(spacing: 0) {
                ProviderQuotaMonitorTableHeader()

                Divider()

                ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                    if index > 0 {
                        Divider()
                            .padding(.leading, 12)
                    }

                    ProviderQuotaMonitorRow(stat: stat, monitor: monitor)
                        .id(SettingsNavigationStore.providerScrollID(stat.provider))
                }
            }
        }
    }
}

private enum ProviderQuotaOverviewLayout {
    static let providerIconSize: CGFloat = 28
    static let rowSpacing: CGFloat = 10
    static let rowHorizontalPadding: CGFloat = 14
    static let providerLabelWidth: CGFloat = 104
    static let providerColumnWidth: CGFloat = providerIconSize + rowSpacing + providerLabelWidth
    static let keyQuotaWidth: CGFloat = 126
    static let credentialPoolWidth: CGFloat = 104
    static let criticalTimeWidth: CGFloat = 122
    static let statusWidth: CGFloat = 68
    static let actionReserveWidth: CGFloat = 90
    static let totalWidthBudget: CGFloat = 704

    static func columnWidths(for contentWidth: CGFloat) -> ProviderQuotaOverviewColumnWidths {
        let spacingTotal = rowSpacing * 5
        let minimumDataWidth = providerColumnWidth
            + keyQuotaWidth
            + credentialPoolWidth
            + criticalTimeWidth
            + statusWidth
        let usableWidth = max(totalWidthBudget - spacingTotal, contentWidth - spacingTotal)
        let dataWidth = max(minimumDataWidth, usableWidth - actionReserveWidth)
        let extraWidth = max(0, dataWidth - minimumDataWidth)

        return ProviderQuotaOverviewColumnWidths(
            provider: providerColumnWidth,
            keyQuota: keyQuotaWidth,
            credentialPool: credentialPoolWidth + extraWidth * 0.30,
            criticalTime: criticalTimeWidth + extraWidth * 0.42,
            status: statusWidth + extraWidth * 0.28,
            actions: actionReserveWidth
        )
    }
}

private enum ProviderQuotaAccountLayout {
    static let rowSpacing: CGFloat = 10
    static let flexibleGapMinWidth: CGFloat = 0
    static let planWidth: CGFloat = 156
    static let remainingWidth: CGFloat = 78
    static let criticalTimeWidth: CGFloat = 210
    static let updatedWidth: CGFloat = 132

    static func columnWidths(for contentWidth: CGFloat) -> ProviderQuotaAccountColumnWidths {
        let spacingTotal = rowSpacing * 3
        let minimumDataWidth = planWidth
            + remainingWidth
            + criticalTimeWidth
            + updatedWidth
        let usableWidth = max(minimumDataWidth, contentWidth - spacingTotal)
        let extraWidth = max(0, usableWidth - minimumDataWidth)

        return ProviderQuotaAccountColumnWidths(
            plan: planWidth,
            remaining: remainingWidth,
            criticalTime: criticalTimeWidth + extraWidth * 0.62,
            updated: updatedWidth + extraWidth * 0.38
        )
    }
}

private struct ProviderQuotaAccountColumnWidths {
    let plan: CGFloat
    let remaining: CGFloat
    let criticalTime: CGFloat
    let updated: CGFloat
}

private struct ProviderQuotaOverviewColumnWidths {
    let provider: CGFloat
    let keyQuota: CGFloat
    let credentialPool: CGFloat
    let criticalTime: CGFloat
    let status: CGFloat
    let actions: CGFloat
}

struct ProviderQuotaAccountGridRow<PlanCell: View, RemainingCell: View, CriticalTimeCell: View, UpdatedCell: View>: View {
    let height: CGFloat
    let plan: PlanCell
    let remaining: RemainingCell
    let criticalTime: CriticalTimeCell
    let updated: UpdatedCell

    init(
        height: CGFloat,
        @ViewBuilder plan: () -> PlanCell,
        @ViewBuilder remaining: () -> RemainingCell,
        @ViewBuilder criticalTime: () -> CriticalTimeCell,
        @ViewBuilder updated: () -> UpdatedCell
    ) {
        self.height = height
        self.plan = plan()
        self.remaining = remaining()
        self.criticalTime = criticalTime()
        self.updated = updated()
    }

    var body: some View {
        GeometryReader { proxy in
            let widths = ProviderQuotaAccountLayout.columnWidths(for: proxy.size.width)
            HStack(spacing: ProviderQuotaAccountLayout.rowSpacing) {
                plan
                    .frame(width: widths.plan, height: height, alignment: .leading)

                remaining
                    .frame(width: widths.remaining, height: height, alignment: .leading)

                criticalTime
                    .frame(width: widths.criticalTime, height: height, alignment: .leading)

                updated
                    .frame(width: widths.updated, height: height, alignment: .leading)
            }
            .frame(width: proxy.size.width, height: height, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height)
    }
}

struct ProviderQuotaWindowDetailGridRow<PlanCell: View, RemainingCell: View, DetailCell: View>: View {
    let height: CGFloat
    let plan: PlanCell
    let remaining: RemainingCell
    let detail: DetailCell

    init(
        height: CGFloat,
        @ViewBuilder plan: () -> PlanCell,
        @ViewBuilder remaining: () -> RemainingCell,
        @ViewBuilder detail: () -> DetailCell
    ) {
        self.height = height
        self.plan = plan()
        self.remaining = remaining()
        self.detail = detail()
    }

    var body: some View {
        GeometryReader { proxy in
            let widths = ProviderQuotaAccountLayout.columnWidths(for: proxy.size.width)
            HStack(spacing: ProviderQuotaAccountLayout.rowSpacing) {
                plan
                    .frame(width: widths.plan, height: height, alignment: .leading)

                remaining
                    .frame(width: widths.remaining, height: height, alignment: .leading)

                detail
                    .frame(
                        width: widths.criticalTime + ProviderQuotaAccountLayout.rowSpacing + widths.updated,
                        height: height,
                        alignment: .leading
                    )
            }
            .frame(width: proxy.size.width, height: height, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height)
    }
}

struct ProviderQuotaOverviewGridRow<ProviderCell: View, KeyQuotaCell: View, CredentialPoolCell: View, CriticalTimeCell: View, StatusCell: View, ActionCell: View>: View {
    let height: CGFloat
    let provider: ProviderCell
    let keyQuota: KeyQuotaCell
    let credentialPool: CredentialPoolCell
    let criticalTime: CriticalTimeCell
    let status: StatusCell
    let actions: ActionCell

    init(
        height: CGFloat,
        @ViewBuilder provider: () -> ProviderCell,
        @ViewBuilder keyQuota: () -> KeyQuotaCell,
        @ViewBuilder credentialPool: () -> CredentialPoolCell,
        @ViewBuilder criticalTime: () -> CriticalTimeCell,
        @ViewBuilder status: () -> StatusCell,
        @ViewBuilder actions: () -> ActionCell
    ) {
        self.height = height
        self.provider = provider()
        self.keyQuota = keyQuota()
        self.credentialPool = credentialPool()
        self.criticalTime = criticalTime()
        self.status = status()
        self.actions = actions()
    }

    var body: some View {
        GeometryReader { proxy in
            let widths = ProviderQuotaOverviewLayout.columnWidths(for: proxy.size.width)
            HStack(spacing: ProviderQuotaOverviewLayout.rowSpacing) {
                provider
                    .frame(width: widths.provider, height: height, alignment: .leading)

                keyQuota
                    .frame(width: widths.keyQuota, height: height, alignment: .leading)

                credentialPool
                    .frame(width: widths.credentialPool, height: height, alignment: .trailing)

                criticalTime
                    .frame(width: widths.criticalTime, height: height, alignment: .trailing)

                status
                    .frame(width: widths.status, height: height, alignment: .trailing)

                actions
                    .frame(width: widths.actions, height: height, alignment: .trailing)
            }
            .frame(width: proxy.size.width, height: height, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height)
    }
}

struct ProviderQuotaMonitorTableHeader: View {
    var body: some View {
        ProviderQuotaOverviewGridRow(height: 18) {
            Text(L10n.t(.provider))
                .frame(maxWidth: .infinity, alignment: .leading)
        } keyQuota: {
            Text(L10n.t(.keyQuota))
                .frame(maxWidth: .infinity, alignment: .leading)
        } credentialPool: {
            Text(L10n.t(.credentialPool))
                .frame(maxWidth: .infinity, alignment: .trailing)
        } criticalTime: {
            Text(L10n.t(.criticalTime))
                .frame(maxWidth: .infinity, alignment: .trailing)
        } status: {
            Text(L10n.t(.quotaStatus))
                .frame(maxWidth: .infinity, alignment: .trailing)
        } actions: {
            Color.clear
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .textCase(.uppercase)
        .padding(.horizontal, ProviderQuotaOverviewLayout.rowHorizontalPadding)
        .padding(.vertical, 9)
    }
}

struct ProviderQuotaMonitorRow: View {
    let stat: ProviderStats
    @ObservedObject var monitor: QuotaMonitor
    @ObservedObject private var navigationStore = SettingsNavigationStore.shared
    @State private var isExpanded = false
    @State private var showingReauth = false

    private var provider: Provider { stat.provider }
    private var keys: [APIKey] { stat.sortedMonitoringKeysByCurrentQuota }
    private var isRefreshing: Bool { monitor.refreshingProviders.contains(provider) }
    private var canRefresh: Bool { keys.contains { $0.isActive && !$0.key.isEmpty } }

    private var keyQuotaText: String {
        keys.isEmpty ? L10n.t(.notAvailableShort) : stat.keyQuotaDisplayText
    }

    private var credentialPoolText: String {
        keys.isEmpty ? L10n.t(.noKeyConfigured) : stat.credentialPoolDisplayText
    }

    private var criticalTimeText: String {
        keys.isEmpty ? L10n.t(.notAvailableShort) : stat.criticalTimeDisplayText
    }

    private var statusText: String {
        guard !keys.isEmpty else { return L10n.t(.noKeyConfigured) }
        if keys.allSatisfy({ !$0.isActive }) { return L10n.t(.disabled) }
        if keys.contains(where: { $0.isCredentialExpired }) { return L10n.t(.credentialExpired) }
        if keys.contains(where: { $0.isUsageLimitExceeded }) { return L10n.t(.usageLimitExceeded) }
        if keys.contains(where: { $0.isExhausted || $0.isLow }) { return L10n.t(.low) }
        if keys.contains(where: { $0.status == .failed }) { return L10n.t(.healthFailed) }
        if keys.contains(where: { $0.isUsableWithUnknownQuota }) { return L10n.t(.ok) }
        return L10n.t(.healthHealthy)
    }

    private var quotaOverviewRiskColor: Color {
        quotaOverviewNeedsAttention ? .red : .green
    }

    private var quotaOverviewNeedsAttention: Bool {
        guard !keys.isEmpty else { return true }
        if keys.allSatisfy({ !$0.isActive }) { return true }
        return keys.contains {
            $0.isCredentialExpired
                || $0.isUsageLimitExceeded
                || $0.isExhausted
                || $0.isLow
                || $0.status == .failed
        }
    }

    private var providerActivitySummary: QuotaActivitySummary {
        let constrainedKeyID = stat.mostConstrainedActiveMonitoringKey?.id
        let rankedKeys = [
            stat.mostConstrainedActiveMonitoringKey
        ].compactMap { $0 } + keys.reversed().filter { $0.id != constrainedKeyID }

        for key in rankedKeys {
            let summary = monitor.activitySummary(for: key)
            if summary.shouldRender {
                return summary
            }
        }
        return stat.mostConstrainedActiveMonitoringKey
            .map { monitor.activitySummary(for: $0) }
            ?? keys.first.map { monitor.activitySummary(for: $0) }
            ?? .empty
    }

    private var providerSummaryRowBackground: Color {
        if navigationStore.focusedProvider == provider {
            return Color.accentColor.opacity(0.075)
        }
        return quotaOverviewNeedsAttention ? quotaOverviewRiskColor.opacity(0.038) : Color.clear
    }

    private var focusedMenuSignalReasonText: String? {
        guard navigationStore.focusedProvider == provider,
              let reason = navigationStore.focusedMenuSignalReason else {
            return nil
        }
        return reason.displayText
    }

    private var providerSubtitleText: String {
        focusedMenuSignalReasonText ?? provider.planTypeDisplayName() ?? L10n.categoryTitle(provider.statusBarCategoryTitle)
    }

    @ViewBuilder
    private var providerSummaryRiskAccent: some View {
        if quotaOverviewNeedsAttention {
            Capsule()
                .fill(quotaOverviewRiskColor.opacity(0.58))
                .frame(width: 3)
                .padding(.vertical, 10)
                .padding(.leading, 4)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            providerSummaryRow

            if isExpanded {
                if keys.isEmpty {
                    ProviderQuotaEmptyKeyRow()
                        .padding(.bottom, 10)
                        .transition(.opacity)
                } else {
                    VStack(spacing: 8) {
                        ForEach(keys, id: \.id) { key in
                            ProviderQuotaAccountGroup(
                                key: key,
                                isFocused: navigationStore.focusedCredentialID == key.id,
                                focusedReason: navigationStore.focusedMenuSignalReason
                            )
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                    .transition(.opacity)
                }
            }
        }
        .sheet(isPresented: $showingReauth) {
            DashboardReauthSheet(
                monitor: monitor,
                provider: provider,
                key: keys.first
            )
        }
    }

    private var providerSummaryRow: some View {
        ProviderQuotaOverviewGridRow(height: 34) {
            toggleCell(alignment: .leading) {
                HStack(spacing: ProviderQuotaOverviewLayout.rowSpacing) {
                    ProviderIcon(provider: provider, size: ProviderQuotaOverviewLayout.providerIconSize)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(provider.providerFamilyDisplayName())
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)

                        Text(providerSubtitleText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                }
            }
        } keyQuota: {
            toggleCell(alignment: .leading) {
                VStack(alignment: .leading, spacing: 1) {
                    ProviderQuotaColumnValue(value: keyQuotaText, tint: quotaOverviewRiskColor)
                    ProviderQuotaInlineActivity(summary: providerActivitySummary, tint: quotaOverviewRiskColor)
                }
            }
        } credentialPool: {
            toggleCell(alignment: .trailing) {
                ProviderQuotaColumnValue(value: credentialPoolText)
            }
        } criticalTime: {
            toggleCell(alignment: .trailing) {
                ProviderQuotaColumnValue(value: criticalTimeText)
            }
        } status: {
            toggleCell(alignment: .trailing) {
                ProviderQuotaStatusPill(text: statusText, tint: quotaOverviewRiskColor)
            }
        } actions: {
            ProviderQuotaActionGroup(
                provider: provider,
                isWatched: monitor.isMenuWatchedProvider(provider),
                isRefreshing: isRefreshing,
                canRefresh: canRefresh,
                onToggleWatched: { monitor.toggleMenuWatchedProvider(provider) },
                onReauthenticate: { showingReauth = true },
                onRefresh: { monitor.refreshProvider(provider) }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ProviderQuotaOverviewLayout.rowHorizontalPadding)
        .padding(.vertical, 11)
        .background(providerSummaryRowBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(alignment: .leading) {
            providerSummaryRiskAccent
        }
        .onAppear {
            if navigationStore.focusedProvider == provider {
                isExpanded = true
            }
        }
        .onChange(of: navigationStore.focusedProvider) { _, _ in
            if navigationStore.focusedProvider == provider {
                withAnimation(settingsCollapseAnimation) { isExpanded = true }
            }
        }
    }

    private func toggleCell<Content: View>(alignment: Alignment, @ViewBuilder content: () -> Content) -> some View {
        Button {
            withAnimation(settingsCollapseAnimation) { isExpanded.toggle() }
        } label: {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

}

struct ProviderQuotaColumnValue: View {
    let value: String
    var tint: Color = .primary

    var body: some View {
        Text(value)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.72)
    }
}

struct ProviderQuotaAccountValueText: View {
    let value: String
    var tint: Color = .secondary
    var weight: Font.Weight = .semibold
    var design: Font.Design = .default
    var minimumScaleFactor: CGFloat = 0.72

    var body: some View {
        Text(value)
            .font(.system(size: 12, weight: weight, design: design))
            .foregroundStyle(tint)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(minimumScaleFactor)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProviderQuotaInlineActivity: View {
    let summary: QuotaActivitySummary
    let tint: Color

    private var hasVisibleChange: Bool {
        guard let deltaText = summary.deltaText?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        return !deltaText.isEmpty
    }

    var body: some View {
        if summary.shouldRender && hasVisibleChange {
            QuotaActivityMeter(summary: summary, tint: tint)
        }
    }
}

struct QuotaActivityMeter: View {
    static let valueSpacing: CGFloat = 4

    let summary: QuotaActivitySummary
    let tint: Color

    private var periodLabel: String? {
        summary.periodName.map { L10n.quotaPeriodCompactTitle($0) }
    }

    private var currentValueText: String? {
        guard let currentText = summary.currentText,
              !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return currentText
    }

    private var changeIndicatorText: String? {
        guard let deltaText = summary.deltaText,
              !deltaText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return L10n.compactDeltaIndicator(deltaText)
    }

    var body: some View {
        Group {
            if summary.shouldRender {
                HStack(alignment: .center, spacing: Self.valueSpacing) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        if let changeIndicatorText {
                            Text(changeIndicatorText)
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.68)
                        }

                        if let periodLabel {
                            Text(periodLabel)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(tint.opacity(0.58))
                                .lineLimit(1)
                                .minimumScaleFactor(0.58)
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 10, alignment: .leading)
    }
}

struct ProviderQuotaStatusPill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

struct ProviderQuotaEmptyKeyRow: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "key.slash")
                .font(.system(size: 11, weight: .semibold))
            Text(L10n.t(.noKeyConfigured))
                .font(.caption)
            Spacer()
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ProviderQuotaOverviewLayout.rowHorizontalPadding)
        .padding(.vertical, 9)
        .background(Color.primary.opacity(0.028), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ProviderQuotaKeyTableHeader: View {
    var body: some View {
        ProviderQuotaAccountGridRow(height: 18) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 6, height: 6)

                Text(L10n.t(.plan))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } remaining: {
            Text(L10n.t(.remaining))
                .frame(maxWidth: .infinity, alignment: .leading)
        } criticalTime: {
            Text(L10n.t(.criticalTime))
                .frame(maxWidth: .infinity, alignment: .leading)
        } updated: {
            Text(L10n.t(.lastUpdated))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.tertiary)
        .textCase(.uppercase)
        .padding(.horizontal, ProviderQuotaOverviewLayout.rowHorizontalPadding)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .background(Color.primary.opacity(0.018), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ProviderQuotaKeyTableRow: View {
    let key: APIKey
    let isFocused: Bool
    let focusedReason: MenuSignalReason?

    private var updatedText: String {
        guard let lastUpdated = key.lastUpdated else { return L10n.t(.notChecked) }
        return L10n.shortDateTime(lastUpdated)
    }

    private var criticalTimeText: String {
        if !key.planEndSummary.isEmpty {
            return key.planEndSummary
        }
        if !key.visibleQuotaResetSummary.isEmpty {
            return key.visibleQuotaResetSummary
        }
        return L10n.t(.notAvailableShort)
    }

    private var rowBackground: Color {
        isFocused ? Color.accentColor.opacity(0.09) : Color.primary.opacity(0.022)
    }

    var body: some View {
        ProviderQuotaAccountGridRow(height: 44) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isFocused ? Color.accentColor : key.status.color)
                    .frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(key.accountDisplayTitle)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)

                        if isFocused, let focusedReason {
                            Text(focusedReason.displayText)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                                .lineLimit(1)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.accentColor.opacity(0.10), in: Capsule())
                        }
                    }
                }
            }
        } remaining: {
            ProviderQuotaAccountValueText(
                value: key.remainingBadgeText,
                tint: key.status.color,
                weight: .semibold,
                design: .rounded
            )
        } criticalTime: {
            ProviderQuotaAccountValueText(
                value: criticalTimeText,
                tint: isFocused ? .accentColor : .secondary,
                weight: .semibold
            )
        } updated: {
            ProviderQuotaAccountValueText(
                value: L10n.format(.updated, updatedText),
                tint: .secondary,
                weight: .medium,
                minimumScaleFactor: 0.62
            )
        }
        .padding(.horizontal, ProviderQuotaOverviewLayout.rowHorizontalPadding)
        .padding(.vertical, 8)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .leading) {
            if isFocused {
                Capsule()
                    .fill(Color.accentColor.opacity(0.65))
                    .frame(width: 3)
                    .padding(.vertical, 8)
                    .padding(.leading, 4)
            }
        }
    }
}

struct ProviderQuotaAccountWindowDetails: View {
    let windows: [QuotaWindowText]

    private var visibleWindows: [QuotaWindowText] {
        windows.filter { !$0.name.isEmpty && !$0.percentText.isEmpty }
    }

    var body: some View {
        if !visibleWindows.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(visibleWindows.enumerated()), id: \.offset) { index, window in
                    if index > 0 {
                        Divider()
                            .opacity(0.35)
                    }

                    ProviderQuotaWindowDetailGridRow(height: 28) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 6, height: 6)

                            ProviderQuotaAccountValueText(
                                value: L10n.quotaPeriodTitle(window.name),
                                tint: .secondary,
                                weight: .medium
                            )
                        }
                    } remaining: {
                        ProviderQuotaAccountValueText(
                            value: window.percentText,
                            tint: .primary,
                            weight: .semibold,
                            design: .rounded
                        )
                    } detail: {
                        ProviderQuotaAccountValueText(
                            value: window.detailValueText ?? "",
                            tint: .secondary,
                            weight: .medium,
                            minimumScaleFactor: 0.62
                        )
                    }
                }
            }
            .padding(.horizontal, ProviderQuotaOverviewLayout.rowHorizontalPadding)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.028), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

struct ProviderQuotaAccountGroup: View {
    let key: APIKey
    let isFocused: Bool
    let focusedReason: MenuSignalReason?

    private var updatedText: String {
        guard let lastUpdated = key.lastUpdated else { return L10n.t(.notChecked) }
        return L10n.shortDateTime(lastUpdated)
    }

    private var criticalTimeText: String {
        if !key.planEndSummary.isEmpty {
            return key.planEndSummary
        }
        if !key.visibleQuotaResetSummary.isEmpty {
            return key.visibleQuotaResetSummary
        }
        return L10n.t(.notAvailableShort)
    }

    private var fallbackQuotaDetailText: String? {
        key.visibleQuotaResetSummary.isEmpty ? nil : key.visibleQuotaResetSummary
    }

    private var rowBackground: Color {
        isFocused ? Color.accentColor.opacity(0.09) : Color.primary.opacity(0.026)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ProviderQuotaAccountIdentity(
                key: key,
                isFocused: isFocused,
                focusedReason: focusedReason
            )
            .frame(width: 166, alignment: .leading)

            ProviderQuotaAccountQuotaWindows(
                key: key,
                fallbackDetailText: fallbackQuotaDetailText
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            ProviderQuotaAccountMetaPanel(
                planEndText: key.planEndSummary.isEmpty ? nil : key.planEndSummary,
                updatedText: updatedText
            )
            .frame(width: 260, alignment: .trailing)
        }
        .padding(.horizontal, ProviderQuotaOverviewLayout.rowHorizontalPadding)
        .padding(.vertical, 12)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .leading) {
            if isFocused {
                Capsule()
                    .fill(Color.accentColor.opacity(0.65))
                    .frame(width: 3)
                    .padding(.vertical, 8)
                    .padding(.leading, 4)
            }
        }
    }
}

struct ProviderQuotaAccountIdentity: View {
    let key: APIKey
    let isFocused: Bool
    let focusedReason: MenuSignalReason?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(isFocused ? Color.accentColor : key.status.color)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(key.accountDisplayTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    if isFocused, let focusedReason {
                        Text(focusedReason.displayText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .lineLimit(1)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.10), in: Capsule())
                    }
                }

                Text(key.healthDisplayText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
        }
    }
}

struct ProviderQuotaAccountQuotaWindows: View {
    let key: APIKey
    let fallbackDetailText: String?

    private var visibleWindows: [QuotaWindowText] {
        key.quotaWindowDetails.filter { !$0.name.isEmpty && !$0.percentText.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if visibleWindows.isEmpty {
                ProviderQuotaAccountSingleQuotaRow(
                    valueText: key.remainingBadgeText,
                    detailText: fallbackDetailText,
                    tint: key.status.color
                )
            } else {
                ForEach(Array(visibleWindows.enumerated()), id: \.offset) { index, window in
                    if index > 0 {
                        Divider()
                            .opacity(0.45)
                    }

                    ProviderQuotaAccountQuotaWindowRow(
                        periodText: L10n.quotaPeriodTitle(window.name),
                        valueText: window.percentText,
                        detailText: window.detailValueText,
                        tint: key.status.color
                    )
                }
            }
        }
    }
}

struct ProviderQuotaAccountSingleQuotaRow: View {
    let valueText: String
    let detailText: String?
    let tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            ProviderQuotaAccountValueText(
                value: valueText,
                tint: tint,
                weight: .semibold,
                design: .rounded,
                minimumScaleFactor: 0.70
            )
            .frame(width: 84, alignment: .leading)

            ProviderQuotaAccountValueText(
                value: detailText ?? "",
                tint: .secondary,
                weight: .medium,
                minimumScaleFactor: 0.62
            )
        }
        .frame(minHeight: 20, alignment: .leading)
    }
}

struct ProviderQuotaAccountQuotaWindowRow: View {
    let periodText: String
    let valueText: String
    let detailText: String?
    let tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            ProviderQuotaAccountValueText(
                value: periodText,
                tint: .secondary,
                weight: .medium,
                minimumScaleFactor: 0.72
            )
            .frame(width: 62, alignment: .leading)

            ProviderQuotaAccountValueText(
                value: valueText,
                tint: tint,
                weight: .semibold,
                design: .rounded,
                minimumScaleFactor: 0.70
            )
            .frame(width: 72, alignment: .leading)

            ProviderQuotaAccountValueText(
                value: detailText ?? "",
                tint: .secondary,
                weight: .medium,
                minimumScaleFactor: 0.62
            )
        }
        .frame(minHeight: 20, alignment: .leading)
    }
}

struct ProviderQuotaAccountMetaPanel: View {
    let planEndText: String?
    let updatedText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let planEndText {
                metaRow(label: L10n.t(.criticalTime), value: planEndText)
            }
            metaRow(label: L10n.t(.lastUpdated), value: updatedText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func metaRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .frame(width: 56, alignment: .leading)

            ProviderQuotaAccountValueText(
                value: value,
                tint: .secondary,
                weight: .medium,
                minimumScaleFactor: 0.58
            )
        }
    }
}

struct ProviderQuotaTimingColumn: View {
    static let width: CGFloat = ProviderQuotaAccountLayout.updatedWidth

    let key: APIKey
    let updatedText: String

    @ViewBuilder
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            timingText(L10n.format(.updated, updatedText), style: .secondary, weight: .medium)
            if !key.planEndSummary.isEmpty {
                planEndText
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    @ViewBuilder
    private var planEndText: some View {
        let expiresSoon = key.visiblePlanEndsAt.map { $0.timeIntervalSinceNow < 14 * 24 * 60 * 60 } == true
        timingText(
            key.planEndSummary,
            style: expiresSoon ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary)
        )
    }

    private func timingText(_ text: String, style: AnyShapeStyle, weight: Font.Weight = .regular) -> some View {
        Text(text)
            .font(.caption2.weight(weight))
            .foregroundStyle(style)
            .lineLimit(1)
            .minimumScaleFactor(0.62)
    }

    private func timingText(_ text: String, style: HierarchicalShapeStyle, weight: Font.Weight = .regular) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(weight)
            .foregroundStyle(style)
            .lineLimit(1)
            .minimumScaleFactor(0.62)
    }
}

// MARK: - Diagnostics View

struct DiagnosticsView: View {
    @ObservedObject var monitor: QuotaMonitor

    private var stats: [ProviderStats] {
        monitor.orderedVisibleProviders.compactMap { provider -> ProviderStats? in
            let keys = APIKey.sortedByCurrentQuota(monitor.apiKeys.filter { $0.provider == provider })
            let stat = ProviderStats(provider: provider, keys: keys)
            guard !stat.credentialDiagnosticItems.isEmpty else { return nil }
            return stat
        }
    }

    var body: some View {
        ModernPage(
            title: L10n.t(.diagnosticsTab),
            subtitle: L10n.t(.diagnosticsDescription),
            systemImage: "stethoscope"
        ) {
            if stats.isEmpty {
                EmptyContentPanel(
                    title: L10n.t(.noApiKeys),
                    systemImage: "stethoscope",
                    actionTitle: nil,
                    action: nil
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(stats) { stat in
                        CredentialDiagnosticProviderSection(stat: stat)
                    }
                }
            }
        }
        .navigationTitle(L10n.t(.diagnosticsTab))
    }
}

struct CredentialDiagnosticProviderSection: View {
    let stat: ProviderStats

    var body: some View {
        MaterialPanel {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ProviderIcon(provider: stat.provider, size: 28)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(stat.provider.providerFamilyDisplayName())
                            .font(.system(size: 14, weight: .semibold))
                        Text(stat.provider.planTypeDisplayName() ?? L10n.categoryTitle(stat.provider.statusBarCategoryTitle))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(stat.diagnosticCredentialGroupCountText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.10), in: Capsule())
                }

                if stat.provider.capability.requiresCostlyConfirmation {
                    InlineStatusMessage(text: L10n.t(.quotaConsumingRefreshWarning))
                }

                VStack(spacing: 6) {
                    ForEach(stat.credentialDiagnosticItems) { item in
                        CredentialDiagnosticRow(item: item)
                    }
                }
            }
        }
    }
}

struct CredentialDiagnosticRow: View {
    let item: CredentialDiagnosticItem

    private var key: APIKey { item.key }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Circle()
                    .fill(item.diagnosticStatusColor)
                    .frame(width: 7, height: 7)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.credentialTitle)
                        .font(.system(size: 13, weight: .semibold))
                    HStack(spacing: 6) {
                        Text(item.credentialSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let planName = item.planDisplayName,
                           planName != item.credentialTitle {
                            Text(planName)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.primary.opacity(0.06), in: Capsule())
                        }
                    }
                }

                Spacer()

                DiagnosticPill(title: L10n.t(.healthStatus), value: item.diagnosticStatusText, tint: item.diagnosticStatusColor)
            }

            if let connectionDiagnosticSummary = item.connectionDiagnosticSummary {
                DiagnosticMessageRow(text: connectionDiagnosticSummary)
            }

            DiagnosticDebugDisclosure(item: item)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

struct DiagnosticDebugDisclosure: View {
    let item: CredentialDiagnosticItem

    var body: some View {
        DisclosureGroup {
            VStack(spacing: 5) {
                DiagnosticDebugRow(title: L10n.t(.lastHTTPStatus), value: item.httpStatusText)
                DiagnosticDebugRow(title: L10n.t(.requestProxyMode), value: item.requestProxyModeText)
                DiagnosticDebugRow(title: L10n.t(.reset), value: item.resetDiagnosticText)
                DiagnosticDebugRow(title: L10n.t(.lastUpdated), value: item.lastCheckedText)

                if let autoRefreshSkipText = item.autoRefreshSkipText {
                    DiagnosticDebugRow(title: L10n.t(.automaticRefresh), value: autoRefreshSkipText)
                }
            }
            .padding(.top, 4)
        } label: {
            Text(L10n.t(.diagnosticDetails))
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .font(.caption2)
        .tint(.secondary)
    }
}

struct DiagnosticDebugRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .foregroundStyle(.tertiary)
                .frame(width: 82, alignment: .leading)

            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
    }
}

struct DiagnosticMessageRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "text.bubble")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}

struct DiagnosticPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - App Settings View

struct AppSettingsView: View {
    @ObservedObject var monitor: QuotaMonitor
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @ObservedObject private var appearanceStore = AppAppearanceStore.shared
    @ObservedObject private var launchAtLoginStore = LaunchAtLoginStore.shared
    @State private var showingProviderOrderSheet = false
    @State private var showingWatchedProvidersSheet = false

    private var supportsQuotaConsumingAutomaticRefresh: Bool {
        Provider.visibleCases.contains {
            $0.capability.matchesAutomaticRefreshLane(consumesSearchQuota: true)
        }
    }

    private var transparencyText: String {
        "\(Int((appearanceStore.statusBarTransparency * 100).rounded()))%"
    }

    var body: some View {
        ModernPage(
            title: L10n.t(.settingsTab),
            subtitle: L10n.t(.languageDescription),
            systemImage: "gearshape.fill",
            maxContentWidth: 760
        ) {
            SettingsFormSection(title: L10n.t(.settingsGeneralSection)) {
                SettingsPreferenceRow(
                    icon: "globe",
                    title: L10n.t(.language)
                ) {
                    Picker(L10n.t(.language), selection: $languageStore.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName)
                                .tag(language)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 430)
                }

                SettingsDivider()

                SettingsPreferenceRow(
                    icon: "star.circle",
                    title: L10n.t(.watchedProviders),
                    subtitle: L10n.t(.watchedProvidersDescription)
                ) {
                    Button(L10n.t(.configureWatchedProviders)) {
                        showingWatchedProvidersSheet = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                SettingsDivider()

                SettingsPreferenceRow(
                    icon: "arrow.up.arrow.down",
                    title: L10n.t(.customProviderOrder),
                    subtitle: L10n.t(.customProviderOrderDescription)
                ) {
                    HStack(spacing: 10) {
                        Toggle("", isOn: $monitor.isCustomProviderOrderEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)

                        Button(L10n.t(.configureProviderOrder)) {
                            showingProviderOrderSheet = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(!monitor.isCustomProviderOrderEnabled)
                    }
                }

                SettingsDivider()

                SettingsPreferenceRow(
                    icon: "power",
                    title: L10n.t(.launchAtLogin),
                    subtitle: L10n.t(.launchAtLoginDescription)
                ) {
                    Toggle("", isOn: Binding(
                        get: { launchAtLoginStore.isEnabled },
                        set: { launchAtLoginStore.setEnabled($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }

                if let error = launchAtLoginStore.lastError {
                    SettingsFootnote(icon: "exclamationmark.triangle.fill", text: error, tint: .red)
                }

                SettingsDivider()

                SettingsPreferenceRow(
                    icon: "arrow.down.circle",
                    title: L10n.t(.automaticUpdateCheck),
                    subtitle: L10n.t(.automaticUpdateCheckDescription)
                ) {
                    Toggle("", isOn: $appearanceStore.automaticallyCheckForUpdates)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            SettingsFormSection(title: L10n.t(.settingsRefreshSection)) {
                SettingsPreferenceRow(
                    icon: "arrow.clockwise",
                    title: L10n.t(.autoRefreshInterval),
                    subtitle: L10n.t(.autoRefreshDescription)
                ) {
                    SettingsCenteredMenuPicker(selection: $appearanceStore.autoRefreshInterval,
                        options: AutoRefreshIntervalOption.allCases,
                        title: \.displayName
                    )
                }

                SettingsFootnote(
                    icon: "exclamationmark.triangle.fill",
                    text: L10n.t(.autoRefreshBraveWarning)
                )

                SettingsDivider()

                if supportsQuotaConsumingAutomaticRefresh {
                    SettingsPreferenceRow(
                        icon: "magnifyingglass",
                        title: L10n.t(.quotaConsumingAutoRefreshInterval),
                        subtitle: L10n.t(.quotaConsumingAutoRefreshWarning)
                    ) {
                        SettingsCenteredMenuPicker(selection: $appearanceStore.quotaConsumingAutoRefreshInterval,
                            options: QuotaConsumingAutoRefreshIntervalOption.allCases,
                            title: \.displayName
                        )
                    }
                } else {
                    SettingsFootnote(
                        icon: "hand.raised.fill",
                        text: L10n.t(.quotaConsumingManualOnlyWarning)
                    )
                }
            }

            SettingsFormSection(title: L10n.t(.settingsNetworkSection)) {
                SettingsPreferenceRow(
                    icon: "network",
                    title: L10n.t(.networkProxy),
                    subtitle: L10n.t(.networkProxyDescription)
                ) {
                    SettingsCenteredMenuPicker(selection: $appearanceStore.networkProxyMode,
                        options: NetworkProxyModeOption.allCases,
                        title: \.displayName
                    )
                }

                if appearanceStore.networkProxyMode == .custom {
                    SettingsDivider()

                    SettingsPreferenceRow(
                        icon: "link",
                        title: L10n.t(.customProxyURL),
                        subtitle: nil
                    ) {
                        TextField(L10n.t(.customProxyPlaceholder), text: $appearanceStore.customProxyURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(width: 250)
                    }

                    SettingsFootnote(
                        icon: "info.circle",
                        text: L10n.t(.customProxyHelp)
                    )
                }
            }

            SettingsFormSection(title: L10n.t(.settingsAppearanceSection)) {
                SettingsPreferenceRow(
                    icon: "circle.lefthalf.filled",
                    title: L10n.t(.statusBarTransparency),
                    subtitle: L10n.t(.statusBarTransparencyDescription)
                ) {
                    HStack(spacing: 10) {
                        Text(transparencyText)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(width: 42, alignment: .trailing)

                        Slider(value: $appearanceStore.statusBarTransparency, in: 0.0...1.0)
                            .controlSize(.small)
                            .frame(width: 170)
                    }
                }
            }
        }
        .navigationTitle(L10n.t(.settingsTab))
        .sheet(isPresented: $showingProviderOrderSheet) {
            ProviderOrderSheet(monitor: monitor)
        }
        .sheet(isPresented: $showingWatchedProvidersSheet) {
            WatchedProvidersSheet(monitor: monitor)
        }
    }
}

struct WatchedProvidersSheet: View {
    @ObservedObject var monitor: QuotaMonitor
    @Environment(\.dismiss) private var dismiss

    private var watchedCount: Int {
        monitor.menuWatchedProviders.count
    }

    var body: some View {
        VStack(spacing: 0) {
            WatchedProvidersSheetToolbar(
                watchedCount: watchedCount,
                onClose: { dismiss() }
            )

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Provider.categoryDisplayOrder, id: \.self) { category in
                        let providers = providers(in: category)
                        if !providers.isEmpty {
                            WatchedProviderCategoryCard(
                                title: L10n.categoryTitle(category),
                                providers: providers,
                                watchedProviders: monitor.menuWatchedProviders,
                                onToggle: { monitor.toggleMenuWatchedProvider($0) }
                            )
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
        }
        .frame(width: 460, height: 500)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.84))
    }

    private func providers(in category: String) -> [Provider] {
        monitor.orderedVisibleProviders.filter { $0.statusBarCategoryTitle == category }
    }
}

struct WatchedProvidersSheetToolbar: View {
    let watchedCount: Int
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t(.watchedProvidersSheetTitle))
                    .font(.system(size: 14, weight: .semibold))
                Text(L10n.t(.watchedProvidersSheetHint))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(watchedCount)/2")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.05), in: Capsule())

            Button(L10n.t(.close), action: onClose)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

struct WatchedProviderCategoryCard: View {
    let title: String
    let providers: [Provider]
    let watchedProviders: [Provider]
    let onToggle: (Provider) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ProviderOrderCategoryHeader(title: title, count: providers.count)

            Divider()
                .padding(.leading, 12)

            ForEach(Array(providers.enumerated()), id: \.element.id) { index, provider in
                let isWatched = watchedProviders.contains(provider)
                WatchedProviderToggleRow(
                    provider: provider,
                    isWatched: isWatched,
                    isDisabled: !isWatched && watchedProviders.count >= 2,
                    onToggle: { onToggle(provider) }
                )

                if index < providers.count - 1 {
                    Divider()
                        .padding(.leading, 54)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct WatchedProviderToggleRow: View {
    let provider: Provider
    let isWatched: Bool
    let isDisabled: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                ProviderIcon(provider: provider, size: 21, style: .compactBadge)

                VStack(alignment: .leading, spacing: 1) {
                    Text(provider.providerFamilyDisplayName())
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)

                    if let planName = provider.planTypeDisplayName() {
                        Text(planName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: isWatched ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isWatched ? Color.accentColor : Color.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .opacity(isDisabled ? 0.45 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

struct ProviderOrderSheet: View {
    @ObservedObject var monitor: QuotaMonitor
    @Environment(\.dismiss) private var dismiss
    @State private var draggedProvider: Provider?

    var body: some View {
        VStack(spacing: 0) {
            ProviderOrderSheetToolbar(
                onReset: {
                    withAnimation(settingsCollapseAnimation) {
                        monitor.resetProviderOrder()
                    }
                },
                onClose: { dismiss() }
            )

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Provider.categoryDisplayOrder, id: \.self) { category in
                        let providers = providers(in: category)
                        if !providers.isEmpty {
                            ProviderOrderCategoryCard(
                                title: L10n.categoryTitle(category),
                                providers: providers,
                                draggedProvider: $draggedProvider,
                                onMove: move
                            )
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
        }
        .frame(width: 460, height: 500)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.84))
    }

    private func providers(in category: String) -> [Provider] {
        monitor.orderedVisibleProviders.filter { $0.statusBarCategoryTitle == category }
    }

    private func move(_ sourceProvider: Provider?, before targetProvider: Provider) -> Bool {
        guard let sourceProvider else { return false }
        withAnimation(settingsCollapseAnimation) {
            monitor.moveProvider(sourceProvider, before: targetProvider)
        }
        draggedProvider = nil
        return true
    }
}

struct ProviderOrderSheetToolbar: View {
    let onReset: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t(.providerOrderSheetTitle))
                    .font(.system(size: 14, weight: .semibold))
                Text(L10n.t(.dragProviderOrderHint))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(L10n.t(.resetProviderOrder), action: onReset)
                .buttonStyle(.bordered)
                .controlSize(.small)

            Button(L10n.t(.close), action: onClose)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

struct ProviderOrderCategoryCard: View {
    let title: String
    let providers: [Provider]
    @Binding var draggedProvider: Provider?
    let onMove: (Provider?, Provider) -> Bool

    var body: some View {
        VStack(spacing: 0) {
            ProviderOrderCategoryHeader(title: title, count: providers.count)

            Divider()
                .padding(.leading, 12)

            ForEach(Array(providers.enumerated()), id: \.element.id) { index, provider in
                ProviderOrderDragRow(provider: provider, isDragging: draggedProvider == provider)
                    .onDrag {
                        draggedProvider = provider
                        return NSItemProvider(object: provider.rawValue as NSString)
                    }
                    .onDrop(of: [UTType.text], isTargeted: nil) { _ in
                        onMove(draggedProvider, provider)
                    }

                if index < providers.count - 1 {
                    Divider()
                        .padding(.leading, 54)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct ProviderOrderCategoryHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Spacer()

            Text("\(count)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.025))
    }
}

struct ProviderOrderDragRow: View {
    let provider: Provider
    let isDragging: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 16)

            ProviderIcon(provider: provider, size: 21, style: .compactBadge)

            VStack(alignment: .leading, spacing: 1) {
                Text(provider.providerFamilyDisplayName())
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                if let planName = provider.planTypeDisplayName() {
                    Text(planName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            (isDragging ? Color.accentColor.opacity(0.12) : Color.clear),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isDragging ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

struct SettingsFormSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 2)

            MaterialPanel(padding: 0) {
                VStack(spacing: 0) {
                    content
                }
            }
        }
    }
}

struct SettingsPreferenceRow<Control: View>: View {
    let icon: String
    let title: String
    let subtitle: String?
    let control: Control

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder control: () -> Control
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 16)

            control
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct SettingsCenteredMenuPicker<Option: Identifiable & Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    let title: (Option) -> String
    var width: CGFloat = 170

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    selection = option
                } label: {
                    HStack {
                        Text(title(option))
                        Spacer()
                        if option == selection {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            ZStack {
                Text(title(selection))
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack {
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: width, height: 24)
            .padding(.horizontal, 8)
            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title(selection)))
    }
}

struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 52)
    }
}

struct SettingsFootnote: View {
    let icon: String
    let text: String
    var tint: Color = .secondary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 14)

            Text(text)
                .font(.caption)
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .padding(.leading, 38)
    }
}

// MARK: - About View

struct AboutView: View {
    @ObservedObject private var updater = GitHubReleaseUpdater.shared

    var body: some View {
        ModernPage(
            title: "Quota Radar",
            subtitle: L10n.t(.aboutSubtitle),
            systemImage: "gauge.with.dots.needle.67percent"
        ) {
            MaterialPanel(padding: 22) {
                HStack(spacing: 18) {
                    QuotaRadarMark(size: 76)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quota Radar")
                            .font(.system(size: 28, weight: .semibold))

                        Text(L10n.t(.version))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        updater.checkForUpdatesFromUI()
                    } label: {
                        HStack(spacing: 6) {
                            if updater.isChecking || updater.isDownloading {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.72)
                            }
                            Text(L10n.t(.checkForUpdates))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(updater.isChecking || updater.isDownloading)
                }
            }

            MaterialPanel {
                VStack(alignment: .leading, spacing: 10) {
                    FeatureRow(icon: "checkmark.circle.fill", text: L10n.t(.featureSupport))
                    FeatureRow(icon: "checkmark.circle.fill", text: L10n.t(.featureRealtime))
                    FeatureRow(icon: "checkmark.circle.fill", text: L10n.t(.featureGlass))
                    FeatureRow(icon: "checkmark.circle.fill", text: L10n.t(.featureMenuBar))
                }
            }
        }
        .navigationTitle("Quota Radar")
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.green)
            Text(text)
                .font(.subheadline)
        }
    }
}
