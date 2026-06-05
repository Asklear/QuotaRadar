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
            VStack(spacing: 4) {
                ForEach(SettingsDestination.navigationOrder) { destination in
                    SidebarNavigationButton(destination: destination, selection: $selection)
                }
            }
            .padding(.top, 36)

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
        .navigationTitle("QuotaBar")
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
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
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
            .frame(maxWidth: 920, alignment: .topLeading)
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
        HStack(spacing: 13) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )

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
                    Text(provider.displayName())
                        .font(.system(size: 14, weight: .semibold))
                    Text(L10n.categoryTitle(provider.statusBarCategoryTitle))
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
                    Text(key.name)
                        .font(.system(size: 13, weight: .semibold))

                    Text(credentialTypeText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                }

                HStack(spacing: 6) {
                    Text(maskedKey)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fontDesign(.monospaced)

                    if let note = key.note, !note.isEmpty {
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
        key.maskedKey
    }

    private var credentialTypeText: String {
        key.provider.supportsDashboardReauthentication ? L10n.t(.dashboardSession) : L10n.t(.apiKey)
    }

    private var statusText: String {
        key.healthDisplayText
    }
}

// MARK: - Add Key Sheet

struct AddKeySheet: View {
    @ObservedObject var monitor: QuotaMonitor
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var key = ""
    @State private var provider: Provider = .tavily
    @State private var note = ""

    var body: some View {
        VStack(spacing: 20) {
            Text(L10n.t(.addAPIKey))
                .font(.title2)
                .fontWeight(.bold)

            Form {
                Picker(L10n.t(.provider), selection: $provider) {
                    ForEach(Provider.visibleCases) { p in
                        Label(p.displayName(), systemImage: p.icon)
                            .tag(p)
                    }
                }

                TextField(L10n.t(.keyName), text: $name)
                    .textFieldStyle(.roundedBorder)

                SecureField(L10n.t(.apiKey), text: $key)
                    .textFieldStyle(.roundedBorder)

                TextField(L10n.t(.noteOptional), text: $note)
                    .textFieldStyle(.roundedBorder)
            }
            .frame(width: 400)

            HStack {
                Button(L10n.t(.cancel)) { dismiss() }
                    .buttonStyle(.bordered)

                Button(L10n.t(.add)) {
                    let newKey = APIKey(
                        name: name.isEmpty ? "\(provider.displayName()) \(L10n.t(.keys))" : name,
                        key: key,
                        provider: provider,
                        note: note.isEmpty ? nil : note
                    )
                    monitor.addKey(newKey)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(key.isEmpty)
            }
        }
        .padding()
        .frame(width: 450, height: 300)
    }
}

// MARK: - Edit Key Sheet

struct EditKeySheet: View {
    @ObservedObject var monitor: QuotaMonitor
    @Environment(\.dismiss) private var dismiss
    let key: APIKey

    @State private var name: String
    @State private var keyValue: String
    @State private var note: String
    @State private var isActive: Bool
    @State private var showingReauth = false

    init(monitor: QuotaMonitor, key: APIKey) {
        self.monitor = monitor
        self.key = key
        _name = State(initialValue: key.name)
        _keyValue = State(initialValue: key.key)
        _note = State(initialValue: key.note ?? "")
        _isActive = State(initialValue: key.isActive)
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                ProviderIcon(provider: key.provider, size: 40)
                Text(L10n.t(.editAPIKey))
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Form {
                TextField(L10n.t(.keyName), text: $name)
                    .textFieldStyle(.roundedBorder)

                SecureField(L10n.t(.apiKey), text: $keyValue)
                    .textFieldStyle(.roundedBorder)

                TextField(L10n.t(.note), text: $note)
                    .textFieldStyle(.roundedBorder)

                Toggle(L10n.t(.active), isOn: $isActive)

                if key.isUnlimitedQuota {
                    HStack {
                        Text(L10n.t(.quotaStatus))
                        Spacer()
                        Text(key.quotaDisplayText)
                            .foregroundStyle(.secondary)
                    }
                } else if key.quotaLabel != nil || key.remaining != nil || key.limit != nil {
                    HStack {
                        Text(L10n.t(.quotaStatus))
                        Spacer()
                        Text(key.quotaDisplayText)
                            .foregroundStyle(.secondary)
                    }

                    if let updated = key.lastUpdated {
                        HStack {
                            Text(L10n.t(.lastUpdated))
                            Spacer()
                            Text(updated, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let dashboard = key.provider.dashboardURL {
                    Link(L10n.t(.openDashboard), destination: URL(string: dashboard)!)
                }

                if key.provider.supportsDashboardReauthentication {
                    Button {
                        showingReauth = true
                    } label: {
                        Label(L10n.t(.reauthenticate), systemImage: "person.badge.key.fill")
                    }
                }
            }
            .frame(width: 400)

            HStack {
                Button(L10n.t(.delete), role: .destructive) {
                    monitor.removeKey(id: key.id)
                    dismiss()
                }

                Spacer()

                Button(L10n.t(.cancel)) { dismiss() }
                    .buttonStyle(.bordered)

                Button(L10n.t(.save)) {
                    var updated = key
                    updated.name = name
                    updated.key = keyValue
                    updated.note = note.isEmpty ? nil : note
                    updated.isActive = isActive
                    monitor.updateKey(updated)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 450, height: 400)
        .sheet(isPresented: $showingReauth) {
            DashboardReauthSheet(monitor: monitor, provider: key.provider, key: key)
        }
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
            systemImage: "server.rack"
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
                VStack(spacing: 12) {
                    ForEach(category.stats) { stat in
                        ProviderCard(provider: stat.provider, monitor: monitor)
                    }
                }
                .transition(.opacity)
            }
        }
    }
}

struct ProviderCard: View {
    let provider: Provider
    @ObservedObject var monitor: QuotaMonitor
    @State private var isExpanded = true
    @State private var showingReauth = false

    var keys: [APIKey] {
        APIKey.sortedByCurrentQuota(monitor.apiKeys.filter { $0.provider == provider })
    }

    private var stats: ProviderStats {
        ProviderStats(provider: provider, keys: keys)
    }

    private var isRefreshing: Bool {
        monitor.refreshingProviders.contains(provider)
    }

    private var canRefresh: Bool {
        keys.contains { $0.isActive && !$0.key.isEmpty }
    }

    var body: some View {
        MaterialPanel {
            VStack(alignment: .leading, spacing: 12) {
                ProviderCardBanner(
                    provider: provider,
                    keyCount: keys.count,
                    isExpanded: isExpanded,
                    isRefreshing: isRefreshing,
                    canRefresh: canRefresh,
                    onToggle: {
                        withAnimation(settingsCollapseAnimation) { isExpanded.toggle() }
                    },
                    onRefresh: { monitor.refreshProvider(provider) }
                )

                if isExpanded {
                    Divider()

                    HStack(spacing: 12) {
                        StatBadge(
                            label: L10n.t(.total),
                            value: stats.totalLimitDisplayText
                        )

                        StatBadge(
                            label: L10n.t(.remaining),
                            value: stats.totalRemainingDisplayText
                        )

                        StatBadge(
                            label: L10n.t(.active),
                            value: "\(keys.filter { $0.isActive }.count)"
                        )
                    }

                    if !keys.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(stats.sortedKeysByCurrentQuota) { key in
                                ProviderKeySummaryRow(key: key)
                            }
                        }
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "key.slash")
                                .font(.system(size: 11, weight: .semibold))
                            Text(L10n.t(.noKeyConfigured))
                                .font(.caption)
                            Spacer()
                        }
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                    }

                    HStack(spacing: 14) {
                        if let dashboard = provider.dashboardURL {
                            Link(destination: URL(string: dashboard)!) {
                                Label(L10n.t(.openDashboard), systemImage: "arrow.up.right.square")
                                    .font(.caption)
                            }
                            .foregroundStyle(provider.color)
                        }

                        if provider.supportsDashboardReauthentication {
                            Button {
                                showingReauth = true
                            } label: {
                                Label(L10n.t(.reauthenticate), systemImage: "person.badge.key.fill")
                                    .font(.caption)
                            }
                            .foregroundStyle(provider.color)
                            .buttonStyle(.plain)
                        }
                    }
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
}

struct ProviderCardBanner: View {
    private static let trailingControlReserve: CGFloat = 44

    let provider: Provider
    let keyCount: Int
    let isExpanded: Bool
    let isRefreshing: Bool
    let canRefresh: Bool
    let onToggle: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    ProviderIcon(provider: provider, size: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(provider.displayName())
                            .font(.system(size: 15, weight: .semibold))

                        Text(L10n.categoryTitle(provider.statusBarCategoryTitle))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(L10n.format(.providerKeyCount, keyCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.10), in: Capsule())

                    Color.clear
                        .frame(width: Self.trailingControlReserve)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
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

            RefreshButton(
                isRefreshing: .constant(isRefreshing),
                isEnabled: canRefresh,
                action: onRefresh
            )
            .scaleEffect(0.86)
            .padding(.trailing, 10)
        }
    }
}

struct ProviderKeySummaryRow: View {
    let key: APIKey

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(key.status.color)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(key.maskedKey)
                    .font(.system(size: 12, weight: .medium))
                    .fontDesign(.monospaced)
                    .lineLimit(1)

                Text(key.quotaDisplayText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(key.remainingBadgeText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(key.status.color)
                    .monospacedDigit()

                Text(key.resetSummary)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

struct StatBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                        Text(stat.provider.displayName())
                            .font(.system(size: 14, weight: .semibold))
                        Text(L10n.categoryTitle(stat.provider.statusBarCategoryTitle))
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
                    ForEach(stat.sortedKeysByCurrentQuota) { key in
                        CredentialDiagnosticRow(key: key)
                    }
                }
            }
        }
    }
}

struct CredentialDiagnosticRow: View {
    let key: APIKey

    private var httpStatusText: String {
        key.lastHTTPStatus.map(String.init) ?? L10n.t(.httpNotRequested)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Circle()
                    .fill(key.status.color)
                    .frame(width: 7, height: 7)

                VStack(alignment: .leading, spacing: 2) {
                    Text(key.name)
                        .font(.system(size: 13, weight: .semibold))
                    Text(key.maskedKey)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                DiagnosticPill(title: L10n.t(.healthStatus), value: key.healthDisplayText, tint: key.status.color)
                DiagnosticPill(title: L10n.t(.lastHTTPStatus), value: httpStatusText, tint: .secondary)
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                Text(key.diagnosticSummary)
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
            systemImage: "gearshape.fill"
        ) {
            MaterialPanel {
                VStack(alignment: .leading, spacing: 14) {
                    Picker(L10n.t(.language), selection: $languageStore.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName)
                                .tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            MaterialPanel {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isOn: Binding(
                        get: { launchAtLoginStore.isEnabled },
                        set: { launchAtLoginStore.setEnabled($0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.t(.launchAtLogin))
                                .font(.system(size: 14, weight: .semibold))

                            Text(L10n.t(.launchAtLoginDescription))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    if let error = launchAtLoginStore.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Divider()

                    Picker(L10n.t(.autoRefreshInterval), selection: $appearanceStore.autoRefreshInterval) {
                        ForEach(AutoRefreshIntervalOption.allCases) { option in
                            Text(option.displayName)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(L10n.t(.autoRefreshDescription))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label(L10n.t(.autoRefreshBraveWarning), systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()

                    Picker(L10n.t(.quotaConsumingAutoRefreshInterval), selection: $appearanceStore.quotaConsumingAutoRefreshInterval) {
                        ForEach(QuotaConsumingAutoRefreshIntervalOption.allCases) { option in
                            Text(option.displayName)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    Label(L10n.t(.quotaConsumingAutoRefreshWarning), systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            MaterialPanel {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "circle.lefthalf.filled")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 28, height: 28)
                            .background(.thinMaterial, in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.t(.statusBarTransparency))
                                .font(.system(size: 14, weight: .semibold))

                            Text(L10n.t(.statusBarTransparencyDescription))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(transparencyText)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Slider(value: $appearanceStore.statusBarTransparency, in: 0.0...1.0)
                        .controlSize(.small)
                }
            }
        }
        .navigationTitle(L10n.t(.settingsTab))
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        ModernPage(
            title: "QuotaBar",
            subtitle: L10n.t(.aboutSubtitle),
            systemImage: "gauge.with.dots.needle.67percent"
        ) {
            MaterialPanel(padding: 22) {
                HStack(spacing: 18) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 76, height: 76)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("QuotaBar")
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
        .navigationTitle("QuotaBar")
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
