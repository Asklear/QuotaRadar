import SwiftUI

struct MenuContentView: View {
    static let menuSize = CGSize(width: 420, height: 460)
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
        0.10 + (1 - statusBarTransparency) * 0.82
    }

    private var glassOverlayOpacity: Double {
        0.01 + (1 - statusBarTransparency) * 0.52
    }

    private var borderOpacity: Double {
        0.04 + (1 - statusBarTransparency) * 0.34
    }

    private var shadowOpacity: Double {
        0.06 + (1 - statusBarTransparency) * 0.22
    }

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(blurOpacity)
                .allowsHitTesting(false)

            LinearGradient(
                colors: [
                    Color.white.opacity(glassOverlayOpacity),
                    Color.white.opacity(max(0.01, glassOverlayOpacity * 0.30))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .allowsHitTesting(false)

            VStack(spacing: 14) {
                HeaderView(
                    lastError: monitor.lastError,
                    refreshMessage: monitor.refreshMessage,
                    onOpenDashboard: { openDashboard() },
                    onOpenSettings: { openSettings() }
                )

                if monitor.apiKeys.isEmpty {
                    EmptyQuotaStateView(onOpenSettings: { openAPIKeyConfiguration() })
                    Spacer(minLength: 0)
                } else {
                    MenuAttentionSummaryCard(summary: monitor.menuQuotaSummary)

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

    private func openDashboard() {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.openPreferencesFromStatusPopover(destination: .providers)
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
    let onOpenDashboard: () -> Void
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

                HeaderIconButton(
                    systemName: "rectangle.grid.1x2",
                    helpText: L10n.t(.providersHeader),
                    action: onOpenDashboard
                )

                HeaderIconButton(
                    systemName: "gear",
                    helpText: L10n.t(.settingsTab),
                    action: onOpenSettings
                )
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

struct HeaderIconButton: View {
    let systemName: String
    let helpText: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(.thinMaterial))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(helpText)
        .accessibilityLabel(helpText)
    }
}

// MARK: - Menu Summary

struct MenuAttentionSummaryCard: View {
    let summary: MenuQuotaSummary

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                StatItem(value: "\(summary.availableCount)", label: L10n.t(.available), valueColor: .green)

                Divider()
                    .frame(height: 30)
                    .background(Color.white.opacity(0.18))

                StatItem(value: "\(summary.lowCount)", label: L10n.t(.low), valueColor: summary.lowCount > 0 ? .orange : .secondary)

                Divider()
                    .frame(height: 30)
                    .background(Color.white.opacity(0.18))

                StatItem(value: "\(summary.failedCount)", label: L10n.t(.failed), valueColor: summary.failedCount > 0 ? .red : .secondary)
            }
        }
    }
}

struct StatItem: View {
    let value: String
    let label: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Attention Quota Items

struct MenuAttentionItemsView: View {
    @ObservedObject var monitor: QuotaMonitor

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(L10n.t(.needsAttention))
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                    Text(L10n.t(.quotaStatus))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

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
