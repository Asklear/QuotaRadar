import SwiftUI

private let menuCollapseAnimation = Animation.easeInOut(duration: 0.16)

struct MenuContentView: View {
    static let menuSize = CGSize(width: 420, height: 560)
    private static let menuGlassCornerRadius: CGFloat = 20
    private static let contentHorizontalInset: CGFloat = 22

    @ObservedObject var monitor: QuotaMonitor
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @ObservedObject private var appearanceStore = AppAppearanceStore.shared

    private var statusBarTransparency: Double {
        appearanceStore.statusBarTransparency
    }

    private var blurOpacity: Double {
        0.18 + (1 - statusBarTransparency) * 0.72
    }

    private var glassOverlayOpacity: Double {
        0.02 + (1 - statusBarTransparency) * 0.42
    }

    private var borderOpacity: Double {
        0.08 + (1 - statusBarTransparency) * 0.28
    }

    private var shadowOpacity: Double {
        0.08 + (1 - statusBarTransparency) * 0.18
    }

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(blurOpacity)

            LinearGradient(
                colors: [
                    Color.white.opacity(glassOverlayOpacity),
                    Color.white.opacity(max(0.01, glassOverlayOpacity * 0.30))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // 顶部标题栏
                HeaderView(
                    lastError: monitor.lastError,
                    refreshMessage: monitor.refreshMessage,
                    onOpenSettings: { openSettings() }
                )

                    if monitor.apiKeys.isEmpty {
                        EmptyQuotaStateView(onOpenSettings: { openAPIKeyConfiguration() })
                    } else {
                        // 总体概览卡片
                        OverviewCard(stats: monitor.homeProviderStats)

                        // 按大类分组显示
                        ForEach(monitor.homeCategoryStats) { category in
                            ProviderCategorySection(category: category, monitor: monitor)
                        }

                        // 底部信息
                        FooterView(lastUpdated: monitor.apiKeys.compactMap { $0.lastUpdated }.max())
                    }
                }
                .padding(.horizontal, Self.contentHorizontalInset)
                .padding(.vertical, 16)
            }
        }
        .frame(width: Self.menuSize.width, height: Self.menuSize.height)
        .clipShape(RoundedRectangle(cornerRadius: Self.menuGlassCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Self.menuGlassCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(borderOpacity), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(shadowOpacity), radius: 24, x: 0, y: 12)
    }

    private func openSettings() {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.openPreferences(destination: .settings)
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func openAPIKeyConfiguration() {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.openPreferences(destination: .apiKeys)
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
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(L10n.t(.apiQuotaTitle))
                    .font(.system(size: 15, weight: .semibold))
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: onOpenSettings) {
                    Image(systemName: "gear")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(.thinMaterial)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 4)

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
}

// MARK: - Overview Card

struct OverviewCard: View {
    let stats: [ProviderStats]

    private var totalKeys: Int {
        stats.map { $0.keys.count }.reduce(0, +)
    }

    private var providersWithData: Int {
        stats.filter { $0.totalLimit > 0 }.count
    }

    private var lowQuotaCount: Int {
        stats.flatMap { $0.keys }.filter { $0.isLow }.count
    }

    var body: some View {
        GlassCard {
            HStack(spacing: 16) {
                StatItem(
                    value: "\(totalKeys)",
                    label: L10n.t(.keys)
                )

                Divider()
                    .frame(height: 30)
                    .background(Color.white.opacity(0.2))

                StatItem(
                    value: "\(stats.count)",
                    label: L10n.t(.providers)
                )

                Divider()
                    .frame(height: 30)
                    .background(Color.white.opacity(0.2))

                StatItem(
                    value: "\(lowQuotaCount)",
                    label: L10n.t(.low),
                    valueColor: lowQuotaCount > 0 ? .orange : .primary
                )
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

// MARK: - Provider Section

struct ProviderCategorySection: View {
    let category: ProviderCategoryStats
    @ObservedObject var monitor: QuotaMonitor
    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 10) {
            MenuCollapsibleBanner(
                title: L10n.categoryTitle(category.title),
                subtitle: L10n.format(.categoryCounts, category.providerCount, category.keyCount),
                systemImage: category.title == "AI Search" ? "magnifyingglass.circle.fill" : category.title == "LLM" ? "cpu.fill" : "square.grid.2x2.fill",
                accessory: category.activeKeyCount > 0 ? L10n.format(.activeCount, category.activeKeyCount) : nil,
                isExpanded: isExpanded
            ) {
                withAnimation(menuCollapseAnimation) { isExpanded.toggle() }
            }

            if isExpanded {
                VStack(spacing: 12) {
                    ForEach(category.stats) { stat in
                        ProviderSection(
                            stat: stat,
                            isRefreshing: monitor.refreshingProviders.contains(stat.provider),
                            onRefresh: { monitor.refreshProvider(stat.provider) }
                        )
                    }
                }
                .transition(.opacity)
            }
        }
    }
}

struct MenuCollapsibleBanner: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let accessory: String?
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(.thinMaterial))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let accessory {
                    Text(accessory)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.07), in: Capsule())
                }
            }
            .padding(.horizontal, 10)
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

struct ProviderSection: View {
    let stat: ProviderStats
    let isRefreshing: Bool
    let onRefresh: () -> Void
    @State private var isExpanded = true

    private var canRefresh: Bool {
        stat.keys.contains { $0.isActive && !$0.key.isEmpty }
    }

    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                MenuProviderBanner(
                    stat: stat,
                    isExpanded: isExpanded,
                    isRefreshing: isRefreshing,
                    canRefresh: canRefresh,
                    onToggle: {
                        withAnimation(menuCollapseAnimation) { isExpanded.toggle() }
                    },
                    onRefresh: onRefresh
                )

                if isExpanded {
                    VStack(spacing: 12) {
                        Divider()
                            .background(Color.white.opacity(0.15))

                        VStack(spacing: 10) {
                            if stat.sortedKeysByCurrentQuota.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "key.slash")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(L10n.t(.noKeyConfigured))
                                        .font(.caption2)
                                    Spacer()
                                }
                                .foregroundStyle(.secondary)
                            } else {
                                ForEach(stat.sortedKeysByCurrentQuota) { key in
                                    KeyRow(key: key)
                                }
                            }
                        }

                        if let dashboard = stat.provider.dashboardURL,
                           let url = URL(string: dashboard) {
                            Divider()
                                .background(Color.white.opacity(0.12))

                            Link(destination: url) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.system(size: 10, weight: .semibold))
                                    Text(L10n.t(.openDashboard))
                                        .font(.caption)
                                    Spacer()
                                }
                                .foregroundStyle(stat.provider.color)
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
    }
}

struct MenuProviderBanner: View {
    private static let trailingControlReserve: CGFloat = 42

    let stat: ProviderStats
    let isExpanded: Bool
    let isRefreshing: Bool
    let canRefresh: Bool
    let onToggle: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    ProviderIcon(provider: stat.provider, size: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(stat.provider.rawValue)
                            .font(.system(size: 14, weight: .semibold))

                        Text(stat.headerSubtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if stat.hasUnlimitedQuota {
                        Text("∞")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(stat.provider.color)
                            .frame(width: 28, height: 28)
                            .background(stat.provider.color.opacity(0.12))
                            .clipShape(Circle())
                    } else if stat.totalLimit > 0 {
                        ZStack {
                            ProgressRing(
                                progress: stat.overallUsage,
                                color: stat.provider.color,
                                lineWidth: 3
                            )
                            .frame(width: 28, height: 28)

                            Text("\(Int((1 - stat.overallUsage) * 100))")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(stat.provider.color)
                        }
                    } else {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }

                    Color.clear
                        .frame(width: Self.trailingControlReserve)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
                .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(.plain)

            RefreshButton(isRefreshing: .constant(isRefreshing), isEnabled: canRefresh, action: onRefresh)
                .padding(.trailing, 2)
        }
    }
}

// MARK: - Key Row

struct KeyRow: View {
    let key: APIKey

    var body: some View {
        HStack(spacing: 10) {
            // 状态指示器
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 3) {
                Text(key.maskedKey)
                    .font(.system(size: 12, weight: .medium))
                    .fontDesign(.monospaced)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(quotaSummary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let updated = key.lastUpdated {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Text(timeAgo(from: updated))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Text(key.resetSummary)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Text(key.remainingBadgeText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(statusColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .frame(minWidth: 42)
                .background(statusColor.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private var quotaSummary: String {
        key.quotaDisplayText
    }

    private var statusColor: Color {
        key.status.color
    }

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Footer

struct FooterView: View {
    let lastUpdated: Date?

    var body: some View {
        HStack {
            Spacer()

            if let date = lastUpdated {
                Text(L10n.format(.updated, timeAgo(from: date)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Text(L10n.t(.pullToRefresh))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.top, 4)
    }

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
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
