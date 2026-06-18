import AppKit
import SwiftUI

struct MenuContentView: View {
    static let menuSize = CGSize(width: 560, height: 740)
    private static let menuGlassCornerRadius: CGFloat = 20
    private static let contentHorizontalInset: CGFloat = 22
    private static let contentTopSafeInset: CGFloat = 18
    private static let contentBottomInset: CGFloat = 14

    @ObservedObject var monitor: QuotaMonitor
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @ObservedObject private var appearanceStore = AppAppearanceStore.shared
    @ObservedObject private var quoteStore = AIQuoteStore.shared

    private var statusBarTransparency: Double {
        appearanceStore.statusBarTransparency
    }

    private var menuSurfaceOpacity: Double {
        0.62 + (1 - statusBarTransparency) * 0.30
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
        let currentLanguage = languageStore.language
        let signalLayout = monitor.menuSignalLayout

        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .opacity(menuSurfaceOpacity)
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
                    failedCount: monitor.menuQuotaSummary.failedCount,
                    quoteText: quoteStore.currentQuoteText(),
                    onOpenSettings: { openSettings() }
                )

                if monitor.apiKeys.isEmpty {
                    EmptyQuotaStateView(onOpenSettings: { openAPIKeyConfiguration() })
                    Spacer(minLength: 0)
                } else {
                    MenuRiskSummaryCard(summary: monitor.menuQuotaSummary)

                    MenuWatchedProviderItemsView(monitor: monitor, items: signalLayout.watchedProviderItems)

                    MenuLowQuotaItemsView(items: signalLayout.lowQuotaItems)

                    MenuExpiringQuotaItemsView(items: signalLayout.expiringSoonItems)

                    MenuAttentionItemsView(monitor: monitor, items: signalLayout.attentionItems)

                    MenuRecentUsageItemsView(monitor: monitor, items: signalLayout.recentUsageItems)

                    MenuHiddenQuotaItemsView(
                        hiddenCount: signalLayout.hiddenItemCount,
                        onOpenProviders: { openProvidersOverview() }
                    )

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
        .id(currentLanguage)
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

    private func openProvidersOverview() {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.openPreferencesFromStatusPopover(destination: .providers)
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
    @Environment(\.menuGlassTransparency) private var menuGlassTransparency
    let lastError: String?
    let refreshMessage: String?
    let failedCount: Int
    let quoteText: String
    let onOpenSettings: () -> Void

    private var headerFillOpacity: Double {
        0.22 + (1 - menuGlassTransparency) * 0.30
    }

    private var headerStatusMessage: String? {
        if refreshMessage == L10n.t(.updatedJustNow) { return nil }
        return refreshMessage
    }

    private var hasSettingsAttention: Bool {
        lastError != nil || failedCount > 0
    }

    private var settingsHelpText: String {
        if let lastError, !lastError.isEmpty {
            return "\(L10n.t(.settingsTab))\n\(lastError)"
        }

        if failedCount > 0 {
            return "\(L10n.t(.settingsTab))\n\(failedCount) \(L10n.t(.failed))"
        }

        return L10n.t(.settingsTab)
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 7) {
                QuotaRadarMark(size: 22)

                Text(L10n.t(.apiQuotaTitle))
                    .font(.system(size: 15, weight: .semibold))
            }
            .layoutPriority(1)

            if lastError == nil, let headerStatusMessage {
                HeaderStatusPill(message: headerStatusMessage, tint: .secondary)
            }

            HeaderQuotePill(message: quoteText)

            Spacer(minLength: 4)

            ZStack(alignment: .topTrailing) {
                StatusHeaderIconButton(
                    systemName: "slider.horizontal.3",
                    helpText: settingsHelpText,
                    action: onOpenSettings
                )
                .frame(width: 32, height: 32)

                if hasSettingsAttention {
                    SettingsAttentionDot()
                        .offset(x: 1, y: -1)
                        .help(settingsHelpText)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
                .opacity(headerFillOpacity)
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                .allowsHitTesting(false)
        }
    }
}

struct SettingsAttentionDot: View {
    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 7, height: 7)
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.92), lineWidth: 1.2)
            }
            .shadow(color: Color.red.opacity(0.35), radius: 3, x: 0, y: 1)
            .allowsHitTesting(false)
    }
}

struct HeaderQuotePill: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.045))
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: 210, alignment: .leading)
    }
}

struct HeaderStatusPill: View {
    let message: String
    let tint: Color

    var body: some View {
        Text(message)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(tint)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.10))
                    .allowsHitTesting(false)
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(tint.opacity(0.14), lineWidth: 0.5)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: 260, alignment: .leading)
    }
}

struct StatusHeaderIconButton: NSViewRepresentable {
    let systemName: String
    let helpText: String
    let action: () -> Void

    func makeNSView(context: Context) -> StatusHeaderActionButton {
        let button = StatusHeaderActionButton(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
        configure(button)
        return button
    }

    func updateNSView(_ button: StatusHeaderActionButton, context: Context) {
        configure(button)
    }

    private func configure(_ button: StatusHeaderActionButton) {
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
        button.actionHandler = action
        button.target = button
        button.action = #selector(StatusHeaderActionButton.performHeaderAction(_:))
        button.wantsLayer = true
        button.layer?.cornerRadius = 16
        button.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.18).cgColor
        button.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        button.layer?.borderWidth = 0.5
    }
}

final class StatusHeaderActionButton: NSButton {
    var actionHandler: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        highlight(true)
        DispatchQueue.main.async { [weak self] in
            self?.highlight(false)
        }
        performHeaderAction(self)
    }

    override func performClick(_ sender: Any?) {
        performHeaderAction(sender)
    }

    @objc func performHeaderAction(_ sender: Any?) {
        let handler = actionHandler
        DispatchQueue.main.async {
            handler?()
        }
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

struct MenuRiskSummaryCard: View {
    let summary: MenuQuotaSummary

    var body: some View {
        MonitorModule(spacing: 9) {
            VStack(alignment: .leading, spacing: 10) {
                MenuSectionHeader(title: L10n.t(.sidebarStatistics), detail: L10n.t(.quotaStatus))

                HStack(spacing: 0) {
                    CompactMetricItem(value: "\(summary.lowCount)", label: L10n.t(.low), valueColor: summary.lowCount > 0 ? .orange : .secondary)

                    Divider()
                        .frame(height: 28)
                        .background(Color.white.opacity(0.18))

                    CompactMetricItem(value: "\(summary.failedCount)", label: L10n.t(.failed), valueColor: summary.failedCount > 0 ? .red : .secondary)

                    Divider()
                        .frame(height: 28)
                        .background(Color.white.opacity(0.18))

                    CompactMetricItem(value: "\(summary.availableCount)", label: L10n.t(.available), valueColor: .green)
                }
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
    private let providerOverviewMaxHeight: CGFloat = 318

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

                MenuBoundedScrollRegion {
                    VStack(alignment: .leading, spacing: 9) {
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
                .frame(maxHeight: providerOverviewMaxHeight)
            }
        }
    }
}

struct MenuBoundedScrollRegion<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(.vertical) {
            content
                .padding(.trailing, 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

struct MenuProviderQuotaCell: View {
    let stat: ProviderStats

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                ProviderIcon(provider: stat.provider, size: 16)

                VStack(alignment: .leading, spacing: 0) {
                    Text(stat.provider.providerFamilyDisplayName())
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    if let planType = stat.provider.planTypeDisplayName() {
                        Text(planType)
                            .font(.system(size: 7.5, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
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

struct MenuWatchedProviderItemsView: View {
    @ObservedObject var monitor: QuotaMonitor
    let items: [MenuQuotaItem]

    var body: some View {
        if !items.isEmpty {
            MonitorModule(spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    MenuSectionHeader(title: L10n.t(.watchedProviders), detail: L10n.t(.keyQuota))

                    ForEach(items) { item in
                        MenuWatchedProviderItemRow(
                            item: item,
                            isRefreshing: monitor.refreshingProviders.contains(item.provider),
                            onRefresh: { monitor.refreshProvider(item.provider) },
                            onOpenProvider: { openProvider(item) }
                        )
                    }
                }
            }
        }
    }

    private func openProvider(_ item: MenuQuotaItem) {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.openProviderFromStatusPopover(item.provider, credentialID: item.key.id, reason: item.signalReason)
        }
    }
}

struct MenuLowQuotaItemsView: View {
    let items: [MenuQuotaItem]

    var body: some View {
        if !items.isEmpty {
            MonitorModule(spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    MenuSectionHeader(title: L10n.t(.lowQuotaProviders), detail: L10n.t(.keyQuota))

                    ForEach(items) { item in
                        MenuCompactQuotaItemRow(
                            item: item,
                            onOpenProvider: { openProvider(item) }
                        )
                    }
                }
            }
        }
    }

    private func openProvider(_ item: MenuQuotaItem) {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.openProviderFromStatusPopover(item.provider, credentialID: item.key.id, reason: item.signalReason)
        }
    }
}

struct MenuExpiringQuotaItemsView: View {
    let items: [MenuQuotaItem]

    var body: some View {
        if !items.isEmpty {
            MonitorModule(spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    MenuSectionHeader(title: L10n.t(.expiringSoon), detail: L10n.t(.criticalTime))

                    ForEach(items) { item in
                        MenuExpiringQuotaItemRow(
                            item: item,
                            onOpenProvider: { openProvider(item) }
                        )
                    }
                }
            }
        }
    }

    private func openProvider(_ item: MenuQuotaItem) {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.openProviderFromStatusPopover(item.provider, credentialID: item.key.id, reason: item.signalReason)
        }
    }
}

struct MenuAttentionItemsView: View {
    @ObservedObject var monitor: QuotaMonitor
    let items: [MenuQuotaItem]

    var body: some View {
        if !items.isEmpty {
            MonitorModule(spacing: 9) {
                VStack(alignment: .leading, spacing: 10) {
                    MenuSectionHeader(title: L10n.t(.needsAttention), detail: L10n.t(.quotaStatus))

                    ForEach(items) { item in
                        MenuQuotaItemRow(
                            item: item,
                            isRefreshing: monitor.refreshingProviders.contains(item.provider),
                            onRefresh: { monitor.refreshProvider(item.provider) },
                            onOpenProvider: { openProvider(item) }
                        )
                    }
                }
            }
        }
    }

    private func openProvider(_ item: MenuQuotaItem) {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.openProviderFromStatusPopover(item.provider, credentialID: item.key.id, reason: item.signalReason)
        }
    }
}

struct MenuRecentUsageItemsView: View {
    @ObservedObject var monitor: QuotaMonitor
    let items: [MenuQuotaItem]

    var body: some View {
        if !items.isEmpty {
            MonitorModule(spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    MenuSectionHeader(title: L10n.t(.recentProviderUsage), detail: L10n.t(.recentUsageDetail))

                    ForEach(items) { item in
                        MenuRecentUsageItemRow(
                            item: item,
                            activitySummary: monitor.activitySummary(for: item.key),
                            isRefreshing: monitor.refreshingProviders.contains(item.provider),
                            onRefresh: { monitor.refreshProvider(item.provider) },
                            onOpenProvider: { openProvider(item) }
                        )
                    }
                }
            }
        }
    }

    private func openProvider(_ item: MenuQuotaItem) {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.openProviderFromStatusPopover(item.provider, credentialID: item.key.id, reason: item.signalReason)
        }
    }
}

struct MenuHiddenQuotaItemsView: View {
    let hiddenCount: Int
    let onOpenProviders: () -> Void

    var body: some View {
        if hiddenCount > 0 {
            Button(action: onOpenProviders) {
                HStack(spacing: 8) {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text(L10n.format(.hiddenQuotaSignalCount, hiddenCount))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.055), lineWidth: 0.8)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

struct MenuExpiringQuotaItemRow: View {
    let item: MenuQuotaItem
    let onOpenProvider: () -> Void

    private var key: APIKey {
        item.key
    }

    var body: some View {
        Button(action: onOpenProvider) {
            HStack(spacing: 8) {
                ProviderIcon(provider: item.provider, size: 20)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(item.provider.displayName())
                            .font(.system(size: 11.5, weight: .semibold))
                            .lineLimit(1)

                        if let contextLabel = item.statusBarAccountContextLabel {
                            Text(contextLabel)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Text(key.planEndSummary)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 24, height: 24)
                    .background(Color.orange.opacity(0.12), in: Circle())
            }
        }
        .buttonStyle(.plain)
    }
}

struct MenuWatchedProviderItemRow: View {
    let item: MenuQuotaItem
    let isRefreshing: Bool
    let onRefresh: () -> Void
    let onOpenProvider: () -> Void

    private var key: APIKey {
        item.key
    }

    private var presentation: QuotaPresentation {
        key.quotaPresentation
    }

    var body: some View {
        HStack(spacing: 8) {
            ProviderIcon(provider: item.provider, size: 20)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(item.provider.displayName())
                        .font(.system(size: 11.5, weight: .semibold))
                        .lineLimit(1)

                    if let contextLabel = item.statusBarAccountContextLabel {
                        Text(contextLabel)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Text(presentation.primaryText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Text(presentation.badgeText)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(key.status.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .frame(minWidth: 38)
                .background(key.status.color.opacity(0.12), in: Capsule())

            RefreshButton(isRefreshing: .constant(isRefreshing), isEnabled: item.canRefresh, action: onRefresh)
                .scaleEffect(0.72)
                .frame(width: 22, height: 22)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpenProvider)
    }
}

struct MenuRecentUsageItemRow: View {
    let item: MenuQuotaItem
    let activitySummary: QuotaActivitySummary
    let isRefreshing: Bool
    let onRefresh: () -> Void
    let onOpenProvider: () -> Void

    private var key: APIKey {
        item.key
    }

    private var trendText: String {
        if let deltaText = activitySummary.deltaText {
            return L10n.compactDeltaIndicator(deltaText)
        }
        if activitySummary.kind == .recovered {
            return L10n.t(.quotaTrendReplenished)
        }
        return key.quotaPresentation.primaryText
    }

    private var trendTint: Color {
        activitySummary.deltaText == nil ? .secondary : .orange
    }

    private var detailText: String {
        guard let activityText = activitySummary.activityText,
              !activityText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return key.quotaPresentation.primaryText
        }
        return "\(key.quotaPresentation.primaryText) · \(activityText)"
    }

    var body: some View {
        HStack(spacing: 8) {
            ProviderIcon(provider: item.provider, size: 20)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(item.provider.displayName())
                        .font(.system(size: 11.5, weight: .semibold))
                        .lineLimit(1)

                    if let contextLabel = item.statusBarAccountContextLabel {
                        Text(contextLabel)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Text(detailText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Text(trendText)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(trendTint)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .frame(minWidth: 42)
                .background(Color.orange.opacity(activitySummary.deltaText == nil ? 0.06 : 0.12), in: Capsule())

            RefreshButton(isRefreshing: .constant(isRefreshing), isEnabled: item.canRefresh, action: onRefresh)
                .scaleEffect(0.72)
                .frame(width: 22, height: 22)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpenProvider)
    }
}

struct MenuCompactQuotaItemRow: View {
    let item: MenuQuotaItem
    let onOpenProvider: () -> Void

    private var key: APIKey {
        item.key
    }

    private var presentation: QuotaPresentation {
        key.quotaPresentation
    }

    var body: some View {
        Button(action: onOpenProvider) {
            HStack(spacing: 8) {
                ProviderIcon(provider: item.provider, size: 20)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(item.provider.displayName())
                            .font(.system(size: 11.5, weight: .semibold))
                            .lineLimit(1)

                        if let contextLabel = item.statusBarAccountContextLabel {
                            Text(contextLabel)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Text(presentation.primaryText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Text(presentation.badgeText)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .frame(minWidth: 38)
                    .background(Color.orange.opacity(0.12), in: Capsule())
            }
        }
        .buttonStyle(.plain)
    }
}

struct MenuQuotaItemRow: View {
    let item: MenuQuotaItem
    let isRefreshing: Bool
    let onRefresh: () -> Void
    let onOpenProvider: () -> Void

    private var key: APIKey {
        item.key
    }

    private var presentation: QuotaPresentation {
        key.quotaPresentation
    }

    private var compactDiagnosticText: String {
        let diagnosticText = presentation.diagnosticText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !diagnosticText.isEmpty,
            diagnosticText != L10n.t(.notChecked),
            presentation.diagnosticText != presentation.primaryText
        else {
            return ""
        }
        return diagnosticText
    }

    var body: some View {
        HStack(spacing: 10) {
            ProviderIcon(provider: item.provider, size: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.provider.displayName())
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)

                    if let contextLabel = item.statusBarAccountContextLabel {
                        Text(contextLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Text(presentation.primaryText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                let metadataItems = [
                    presentation.resetText,
                    presentation.planEndText,
                    presentation.sourceText
                ].filter { !$0.isEmpty }

                if !metadataItems.isEmpty {
                    Text(metadataItems.joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                if !compactDiagnosticText.isEmpty {
                    Text(compactDiagnosticText)
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
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpenProvider)
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
