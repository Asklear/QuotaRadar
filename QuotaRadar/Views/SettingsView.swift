import AppKit
import SwiftUI
import UniformTypeIdentifiers

private let settingsCollapseAnimation = Animation.easeInOut(duration: 0.16)

final class SettingsNavigationStore: ObservableObject {
    static let shared = SettingsNavigationStore()

    @Published var selection: SettingsDestination? = .providers

    func select(_ destination: SettingsDestination) {
        selection = destination
    }
}

struct SettingsView: View {
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

        NavigationSplitView {
            SettingsSidebarView(monitor: monitor, selection: $navigationStore.selection)
                .navigationSplitViewColumnWidth(min: 190, ideal: 216, max: 250)
        } detail: {
            selectedContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ModernWindowBackground())
        }
        .navigationSplitViewStyle(.balanced)
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
            AppSettingsView()
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
                Text(L10n.t(.apiQuotaTitle))
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
        }
        .padding(.horizontal, 12)
        .navigationTitle("Quota Radar")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.thinMaterial)
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
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        maxContentWidth: CGFloat = 920,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.maxContentWidth = maxContentWidth
        self.content = content()
    }

    var body: some View {
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
        let stats: [ProviderStats] = Provider.visibleCases.compactMap { provider in
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
                    Text(key.managementDisplayName)
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

                HStack(spacing: 6) {
                    Text(maskedKey)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fontDesign(.monospaced)

                    if let note = key.displayNote {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            .layoutPriority(1)

            Spacer()

            Text(statusText)
                .font(.caption.weight(.medium))
                .foregroundStyle(key.status.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(key.status.color.opacity(0.12), in: Capsule())

            Toggle(isOn: Binding(get: { key.isActive }, set: { onSetActive($0) })) {
                Text(L10n.t(.active))
            }
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.mini)
            .help(L10n.t(.active))

            if let copyableCredentialValue = key.copyableCredentialValue {
                Button(action: { copyCredentialToPasteboard(copyableCredentialValue) }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .background(.thinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .help(L10n.t(.copyCredential))
            }

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .help(L10n.t(.editAPIKey))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .contentShape(Rectangle())
    }

    private var maskedKey: String {
        key.managementCredentialValueText
    }

    private var credentialTypeText: String? {
        key.managementCredentialTypeBadgeText
    }

    private func copyCredentialToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private var statusText: String {
        if key.isBusinessInvocationCredential {
            return L10n.t(.useDashboardCookie)
        }
        return key.healthDisplayText
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
            provider: $provider
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
            DashboardReauthSheet(monitor: monitor, provider: provider, key: nil)
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
        if provider.supportsCompanionAPIKeyStorage, !trimmedCompanionAPIKey.isEmpty {
            monitor.addKey(APIKey(
                name: provider.copyableAPIKeyCredentialName,
                key: trimmedCompanionAPIKey,
                provider: provider
            ))
        }

        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            dismiss()
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameForSaving = trimmedName.isEmpty ? provider.defaultCredentialName : trimmedName
        let newKey = APIKey(
            name: nameForSaving,
            key: key,
            provider: provider,
            note: note.isEmpty ? nil : note
        )
        monitor.addKey(newKey)
        dismiss()
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
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(spacing: 0) {
            AddCredentialHeader(title: title, provider: provider)

            Divider()

            HStack(spacing: 0) {
                AddCredentialProviderList(provider: $provider)
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

struct AddCredentialProviderList: View {
    @Binding var provider: Provider

    private var groupedProviders: [String: [Provider]] {
        Dictionary(grouping: Provider.visibleCases) { $0.statusBarCategoryTitle }
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
                        Button(action: onReauthenticate) {
                            Label(L10n.t(.reauthenticate), systemImage: "person.badge.key.fill")
                        }
                        .controlSize(.small)
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
            provider: $provider
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

                HStack(spacing: 10) {
                    if let dashboard = provider.dashboardURL,
                       let dashboardURL = URL(string: dashboard) {
                        Link(L10n.t(.openDashboard), destination: dashboardURL)
                            .controlSize(.small)
                    }

                    if provider.supportsDashboardReauthentication && !key.isStoredAPIKeyOnlyCredential {
                        Button {
                            showingReauth = true
                        } label: {
                            Label(L10n.t(.reauthenticate), systemImage: "person.badge.key.fill")
                        }
                        .controlSize(.small)
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
                key: key.provider == provider ? key : nil
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
            $0.id != key.id && $0.provider == provider && $0.isStoredAPIKeyOnlyCredential
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
        saveCompanionAPIKeyIfNeeded()
    }

    private var savedCredentialName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty else { return trimmedName }
        return key.isStoredAPIKeyOnlyCredential ? provider.copyableAPIKeyCredentialName : provider.defaultCredentialName
    }

    private func saveCompanionAPIKeyIfNeeded() {
        guard showsCompanionAPIKeyField else { return }
        let trimmedAPIKey = companionAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty else { return }

        if var existing = companionAPIKeyCredentialForCurrentProvider {
            existing.name = provider.copyableAPIKeyCredentialName
            existing.key = trimmedAPIKey
            existing.provider = provider
            existing.note = nil
            monitor.updateKey(existing)
        } else {
            monitor.addKey(APIKey(
                name: provider.copyableAPIKeyCredentialName,
                key: trimmedAPIKey,
                provider: provider
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

    private var providerCategories: [ProviderCategoryStats] {
        let stats = Provider.visibleCases.map { provider in
            ProviderStats(
                provider: provider,
                keys: APIKey.sortedByCurrentQuota(monitor.apiKeys.filter { $0.provider == provider })
            )
        }
        let grouped = Dictionary(grouping: stats) { $0.provider.statusBarCategoryTitle }
        return Provider.categoryDisplayOrder.compactMap { title in
            guard let stats = grouped[title], !stats.isEmpty else { return nil }
            return ProviderCategoryStats(title: title, stats: stats)
        }
    }

    private var configuredProviders: Int {
        Set(monitor.apiKeys.map { $0.provider }).count
    }

    var body: some View {
        ModernPage(
            title: L10n.t(.providersHeader),
            subtitle: L10n.format(.providersSupported, configuredProviders, Provider.visibleCases.count),
            systemImage: "server.rack",
            maxContentWidth: 1080
        ) {
            VStack(spacing: 14) {
                ForEach(providerCategories) { category in
                    ProviderSettingsCategorySection(category: category, monitor: monitor)
                }
            }
        }
        .navigationTitle(L10n.t(.providersHeader))
    }
}

struct ProviderSettingsCategorySection: View {
    let category: ProviderCategoryStats
    @ObservedObject var monitor: QuotaMonitor
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
                ProviderQuotaMonitorTable(stats: category.stats, monitor: monitor)
                    .transition(.opacity)
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
                }
            }
        }
    }
}

struct ProviderQuotaMonitorTableHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Text(L10n.t(.provider))
                .frame(minWidth: 150, maxWidth: .infinity, alignment: .leading)

            Text(L10n.t(.remaining))
                .frame(width: 94, alignment: .trailing)

            Text(L10n.t(.total))
                .frame(width: 82, alignment: .trailing)

            Text(L10n.t(.quotaStatus))
                .frame(width: 100, alignment: .trailing)

            Color.clear
                .frame(width: 104)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .textCase(.uppercase)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}

struct ProviderQuotaMonitorRow: View {
    private static let trailingControlReserve: CGFloat = 104

    let stat: ProviderStats
    @ObservedObject var monitor: QuotaMonitor
    @State private var isExpanded = false
    @State private var showingReauth = false

    private var provider: Provider { stat.provider }
    private var keys: [APIKey] { stat.sortedMonitoringKeysByCurrentQuota }
    private var activeCount: Int { keys.filter { $0.isActive }.count }
    private var isRefreshing: Bool { monitor.refreshingProviders.contains(provider) }
    private var canRefresh: Bool { keys.contains { $0.isActive && !$0.key.isEmpty } }

    private var remainingText: String {
        keys.isEmpty ? L10n.t(.notAvailableShort) : stat.totalRemainingDisplayText
    }

    private var totalText: String {
        keys.isEmpty ? L10n.t(.notAvailableShort) : stat.totalLimitDisplayText
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

    private var statusColor: Color {
        stat.statusBarProviderStatusColor
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .trailing) {
                Button {
                    withAnimation(settingsCollapseAnimation) { isExpanded.toggle() }
                } label: {
                    providerSummaryRow
                }
                .buttonStyle(.plain)

                HStack(spacing: 7) {
                    if let dashboard = provider.dashboardURL,
                       let url = URL(string: dashboard) {
                        Link(destination: url) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 28, height: 28)
                                .background(.thinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(provider.color)
                        .help(L10n.t(.openDashboard))
                    }

                    if provider.supportsDashboardReauthentication {
                        Button {
                            showingReauth = true
                        } label: {
                            Image(systemName: "person.badge.key.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 28, height: 28)
                                .background(.thinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(provider.color)
                        .help(L10n.t(.reauthenticate))
                    }

                    RefreshButton(
                        isRefreshing: .constant(isRefreshing),
                        isEnabled: canRefresh,
                        action: { monitor.refreshProvider(provider) }
                    )
                    .scaleEffect(0.82)
                }
                .padding(.trailing, 10)
            }

            if isExpanded {
                if keys.isEmpty {
                    ProviderQuotaEmptyKeyRow()
                        .padding(.leading, 56)
                        .padding(.trailing, 14)
                        .padding(.bottom, 10)
                        .transition(.opacity)
                } else {
                    VStack(spacing: 0) {
                        VStack(spacing: 0) {
                            ProviderQuotaKeyTableHeader()

                            ForEach(Array(keys.enumerated()), id: \.element.id) { index, key in
                                if index > 0 {
                                    Divider()
                                        .padding(.leading, 12)
                                }

                                ProviderQuotaKeyTableRow(key: key)
                            }
                        }

                        if let detailKey = keys.first(where: { !$0.quotaWindowDetails.isEmpty }) {
                            QuotaWindowDetails(windows: detailKey.quotaWindowDetails)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.leading, 56)
                    .padding(.trailing, 14)
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
        HStack(spacing: 12) {
            ProviderIcon(provider: provider, size: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.providerFamilyDisplayName())
                    .font(.system(size: 13, weight: .semibold))

                HStack(spacing: 12) {
                    if let planName = provider.planTypeDisplayName() {
                        Text(planName)
                    }
                    Text(L10n.format(.providerKeyCount, keyCount))
                    Text(L10n.format(.activeCount, activeCount))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)

            ProviderQuotaColumnValue(value: remainingText, tint: statusColor)
                .frame(width: 94, alignment: .trailing)

            ProviderQuotaColumnValue(value: totalText)
                .frame(width: 82, alignment: .trailing)

            ProviderQuotaStatusPill(text: statusText, tint: statusColor)
                .frame(width: 100, alignment: .trailing)

            Color.clear
                .frame(width: Self.trailingControlReserve)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private var keyCount: Int {
        keys.count
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
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.primary.opacity(0.028), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ProviderQuotaKeyTableHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Text(L10n.t(.apiKey))
                .frame(minWidth: 160, maxWidth: .infinity, alignment: .leading)

            Text(L10n.t(.remaining))
                .frame(width: 86, alignment: .trailing)

            Text(L10n.t(.quotaStatus))
                .frame(width: 112, alignment: .trailing)

            Text(L10n.t(.lastUpdated))
                .frame(width: ProviderQuotaTimingColumn.width, alignment: .trailing)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.tertiary)
        .textCase(.uppercase)
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .background(Color.primary.opacity(0.018), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ProviderQuotaKeyTableRow: View {
    let key: APIKey

    private var updatedText: String {
        guard let lastUpdated = key.lastUpdated else { return L10n.t(.notChecked) }
        return L10n.shortDateTime(lastUpdated)
    }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(key.status.color)
                    .frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(key.maskedKey)
                        .font(.system(size: 12, weight: .medium))
                        .fontDesign(.monospaced)
                        .lineLimit(1)

                    Text(key.quotaPresentation.primaryText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 160, maxWidth: .infinity, alignment: .leading)

            Text(key.remainingBadgeText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(key.status.color)
                .monospacedDigit()
                .lineLimit(1)
                .frame(width: 86, alignment: .trailing)

            ProviderQuotaStatusPill(text: key.healthDisplayText, tint: key.status.color)
                .frame(width: 112, alignment: .trailing)

            ProviderQuotaTimingColumn(key: key, updatedText: updatedText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.022), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ProviderQuotaTimingColumn: View {
    static let width: CGFloat = 188

    let key: APIKey
    let updatedText: String

    @ViewBuilder
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            timingText(updatedText, style: .secondary, weight: .medium)
            if !key.visibleQuotaResetSummary.isEmpty {
                timingText(key.visibleQuotaResetSummary, style: .tertiary)
            }

            if !key.planEndSummary.isEmpty {
                planEndText
            }
        }
        .frame(width: Self.width, alignment: .trailing)
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
        Provider.visibleCases.compactMap { provider in
            let keys = APIKey.sortedByCurrentQuota(monitor.apiKeys.filter { $0.provider == provider })
            guard !keys.isEmpty else { return nil }
            return ProviderStats(provider: provider, keys: keys)
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

                    Text(L10n.format(.providerKeyCount, stat.keys.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.10), in: Capsule())
                }

                if stat.provider.quotaCheckConsumesSearchQuota {
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
                    .fill(item.status.color)
                    .frame(width: 7, height: 7)

                VStack(alignment: .leading, spacing: 2) {
                    Text(key.managementDisplayName)
                        .font(.system(size: 13, weight: .semibold))
                    Text(key.maskedKey)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                DiagnosticPill(title: L10n.t(.healthStatus), value: item.healthDisplayText, tint: item.status.color)
                DiagnosticPill(title: L10n.t(.lastHTTPStatus), value: item.httpStatusText, tint: .secondary)
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                Text(item.diagnosticSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
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
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @ObservedObject private var appearanceStore = AppAppearanceStore.shared
    @ObservedObject private var launchAtLoginStore = LaunchAtLoginStore.shared

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
            }

            SettingsFormSection(title: L10n.t(.settingsRefreshSection)) {
                SettingsPreferenceRow(
                    icon: "arrow.clockwise",
                    title: L10n.t(.autoRefreshInterval),
                    subtitle: L10n.t(.autoRefreshDescription)
                ) {
                    Picker("", selection: $appearanceStore.autoRefreshInterval) {
                        ForEach(AutoRefreshIntervalOption.allCases) { option in
                            Text(option.displayName)
                                .tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 170)
                }

                SettingsFootnote(
                    icon: "exclamationmark.triangle.fill",
                    text: L10n.t(.autoRefreshBraveWarning)
                )

                SettingsDivider()

                SettingsPreferenceRow(
                    icon: "magnifyingglass",
                    title: L10n.t(.quotaConsumingAutoRefreshInterval),
                    subtitle: L10n.t(.quotaConsumingAutoRefreshWarning)
                ) {
                    Picker("", selection: $appearanceStore.quotaConsumingAutoRefreshInterval) {
                        ForEach(QuotaConsumingAutoRefreshIntervalOption.allCases) { option in
                            Text(option.displayName)
                                .tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 170)
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
