import AppKit
import SwiftUI

struct MenuContentView: View {
    static let menuSize = CGSize(width: 560, height: 680)
    private static let menuGlassCornerRadius: CGFloat = 20
    private static let contentHorizontalInset: CGFloat = 22
    private static let contentTopSafeInset: CGFloat = 26
    private static let contentBottomInset: CGFloat = 14

    @ObservedObject var monitor: QuotaMonitor
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @ObservedObject private var appearanceStore = AppAppearanceStore.shared

    private var statusBarTransparency: Double {
        appearanceStore.statusBarTransparency
    }

    private var blurOpacity: Double {
        0.32 + (1 - statusBarTransparency) * 0.58
    }

    private var backdropTintOpacity: Double {
        0.04 + (1 - statusBarTransparency) * 0.44
    }

    private var glassHighlightOpacity: Double {
        0.08 + (1 - statusBarTransparency) * 0.08
    }

    private var borderOpacity: Double {
        0.12 + (1 - statusBarTransparency) * 0.18
    }

    private var shadowOpacity: Double {
        0.10 + (1 - statusBarTransparency) * 0.16
    }

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
                .opacity(blurOpacity)
                .allowsHitTesting(false)

            Color(nsColor: .windowBackgroundColor)
                .opacity(backdropTintOpacity)
                .allowsHitTesting(false)

            LinearGradient(
                colors: [
                    Color.white.opacity(glassHighlightOpacity),
                    Color.primary.opacity(0.025)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .allowsHitTesting(false)

            VStack(spacing: 12) {
                HeaderView(
                    lastError: monitor.lastError,
                    refreshMessage: monitor.refreshMessage,
                    onOpenSettings: { openSettings() }
                )

                if monitor.apiKeys.isEmpty {
                    EmptyQuotaStateView(onOpenSettings: { openAPIKeyConfiguration() })
                    Spacer(minLength: 0)
                } else {
                    MenuMetricStrip(summary: monitor.menuQuotaSummary)

                    MenuProviderOverviewCard(monitor: monitor)

                    MenuAttentionItemsView(monitor: monitor)

                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, Self.contentHorizontalInset)
            .padding(.top, Self.contentTopSafeInset)
            .padding(.bottom, Self.contentBottomInset)
        }
        .frame(width: Self.menuSize.width, height: Self.menuSize.height)
        .clipShape(RoundedRectangle(cornerRadius: Self.menuGlassCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Self.menuGlassCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(borderOpacity), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .environment(\.menuGlassTransparency, statusBarTransparency)
        .shadow(color: Color.black.opacity(shadowOpacity), radius: 24, x: 0, y: 12)
    }

    private func openSettings() {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.openPreferencesFromStatusPopover(destination: .settings)
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func openAPIKeyConfiguration() {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.openPreferencesFromStatusPopover(destination: .apiKeys)
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

// MARK: - Empty State

struct EmptyQuotaStateView: View {
    let onOpenSettings: () -> Void

    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: "key.horizontal")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(.thinMaterial))

                Text(L10n.t(.noApiKeys))
                    .font(.system(size: 15, weight: .semibold))

                Text(L10n.t(.noApiKeysMessage))
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onOpenSettings) {
                    Label(L10n.t(.openSettings), systemImage: "gear")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Header View

struct HeaderView: View {
    let lastError: String?
    let refreshMessage: String?
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "battery.75percent")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(L10n.t(.apiQuotaTitle))
                        .font(.system(size: 15, weight: .semibold))
                }

                Spacer()

                StatusHeaderIconButton(
                    systemName: "slider.horizontal.3",
                    helpText: L10n.t(.settingsTab),
                    action: onOpenSettings
                )
                .frame(width: 32, height: 32)
            }

            if let error = lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .lineLimit(2)
            } else if let refreshMessage {
                Text(refreshMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 4)
    }
}

struct StatusHeaderIconButton: NSViewRepresentable {
    let systemName: String
    let helpText: String
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeNSView(context: Context) -> StatusHeaderActionButton {
        let button = StatusHeaderActionButton(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
        configure(button, coordinator: context.coordinator)
        return button
    }

    func updateNSView(_ button: StatusHeaderActionButton, context: Context) {
        context.coordinator.action = action
        configure(button, coordinator: context.coordinator)
    }

    private func configure(_ button: StatusHeaderActionButton, coordinator: Coordinator) {
        let image = NSImage(systemSymbolName: systemName, accessibilityDescription: helpText)
        image?.isTemplate = true

        button.image = image
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.setButtonType(.momentaryChange)
        button.focusRingType = .none
        button.contentTintColor = .labelColor
        button.toolTip = helpText
        button.setAccessibilityLabel(helpText)
        button.target = coordinator
        button.action = #selector(Coordinator.performAction)
        button.sendAction(on: [.leftMouseDown])
        button.wantsLayer = true
        button.layer?.cornerRadius = 16
        button.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.18).cgColor
        button.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        button.layer?.borderWidth = 0.5
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func performAction() {
            action()
        }
    }
}

final class StatusHeaderActionButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

// MARK: - Menu Summary

struct MonitorModule<Content: View>: View {
    @Environment(\.menuGlassTransparency) private var menuGlassTransparency
    var spacing: CGFloat = 10
    @ViewBuilder var content: Content

    private var moduleFillOpacity: Double {
        0.045 + (1 - menuGlassTransparency) * 0.22
    }

    private var moduleStrokeOpacity: Double {
        0.12 + (1 - menuGlassTransparency) * 0.10
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(.regularMaterial)
                .opacity(0.22 + (1 - menuGlassTransparency) * 0.34)
        )
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(moduleFillOpacity))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(moduleStrokeOpacity), lineWidth: 0.8)
        )
    }
}

struct MenuSectionHeader: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            if let detail {
                Text(detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct MenuMetricStrip: View {
    let summary: MenuQuotaSummary

    var body: some View {
        MonitorModule(spacing: 0) {
            HStack(spacing: 0) {
                CompactMetricItem(value: "\(summary.availableCount)", label: L10n.t(.available), valueColor: .green)

                Divider()
                    .frame(height: 28)
                    .background(Color.white.opacity(0.18))

                CompactMetricItem(value: "\(summary.lowCount)", label: L10n.t(.low), valueColor: summary.lowCount > 0 ? .orange : .secondary)

                Divider()
                    .frame(height: 28)
                    .background(Color.white.opacity(0.18))

                CompactMetricItem(value: "\(summary.failedCount)", label: L10n.t(.failed), valueColor: summary.failedCount > 0 ? .red : .secondary)
            }
        }
    }
}

struct CompactMetricItem: View {
    let value: String
    let label: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Provider Overview

struct MenuProviderOverviewCard: View {
    @ObservedObject var monitor: QuotaMonitor

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        MonitorModule(spacing: 8) {
            VStack(alignment: .leading, spacing: 9) {
                MenuSectionHeader(title: L10n.t(.providers), detail: L10n.t(.quotaStatus))

                ForEach(monitor.homeCategoryStats) { category in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.categoryTitle(category.title))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)

                        LazyVGrid(columns: columns, alignment: .leading, spacing: 7) {
                            ForEach(category.stats) { stat in
                                MenuProviderQuotaCell(stat: stat)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct MenuProviderQuotaCell: View {
    let stat: ProviderStats

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                ProviderIcon(provider: stat.provider, size: 16)

                Text(stat.provider.displayName())
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            HStack(spacing: 4) {
                Text(stat.statusBarProviderQuotaText)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Spacer(minLength: 2)

                Text(stat.statusBarProviderBadgeText)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(stat.statusBarProviderStatusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.primary.opacity(0.045), lineWidth: 0.8)
        )
    }
}

// MARK: - Attention Quota Items

struct MenuAttentionItemsView: View {
    @ObservedObject var monitor: QuotaMonitor

    var body: some View {
        MonitorModule(spacing: 9) {
            VStack(alignment: .leading, spacing: 10) {
                MenuSectionHeader(title: L10n.t(.needsAttention), detail: L10n.t(.quotaStatus))

                if monitor.menuAttentionQuotaItems.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(L10n.t(.noAttentionItems))
                            .font(.caption2)
                        Spacer()
                    }
                    .foregroundStyle(.green)
                } else {
                    ForEach(monitor.menuAttentionQuotaItems) { item in
                        MenuQuotaItemRow(
                            item: item,
                            isRefreshing: monitor.refreshingProviders.contains(item.provider),
                            onRefresh: { monitor.refreshProvider(item.provider) }
                        )
                    }
                }
            }
        }
    }
}

struct MenuQuotaItemRow: View {
    let item: MenuQuotaItem
    let isRefreshing: Bool
    let onRefresh: () -> Void

    private var key: APIKey {
        item.key
    }

    private var presentation: QuotaPresentation {
        key.quotaPresentation
    }

    var body: some View {
        HStack(spacing: 10) {
            ProviderIcon(provider: item.provider, size: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.provider.displayName())
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)

                    Text(key.statusBarCredentialLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(presentation.primaryText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(presentation.resetText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)

                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Text(presentation.sourceText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                if !presentation.diagnosticText.isEmpty && presentation.diagnosticText != L10n.t(.notChecked) {
                    Text(presentation.diagnosticText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(presentation.badgeText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(key.status.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .frame(minWidth: 42)
                .background(key.status.color.opacity(0.12), in: Capsule())

            RefreshButton(isRefreshing: .constant(isRefreshing), isEnabled: item.canRefresh, action: onRefresh)
                .scaleEffect(0.82)
                .frame(width: 28, height: 28)
        }
    }
}

// MARK: - Visual Effect Blur

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
