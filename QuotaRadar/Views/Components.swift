import AppKit
import SwiftUI

private struct MenuGlassTransparencyKey: EnvironmentKey {
    static let defaultValue = 0.58
}

extension EnvironmentValues {
    var menuGlassTransparency: Double {
        get { self[MenuGlassTransparencyKey.self] }
        set { self[MenuGlassTransparencyKey.self] = min(max(newValue, 0.0), 1.0) }
    }
}

enum StatusBarGlassMetrics {
    private static func clamped(_ transparency: Double) -> Double {
        min(max(transparency, 0.0), 1.0)
    }

    static func menuSurfaceOpacity(for transparency: Double) -> Double {
        transparency <= 0 ? 1.0 : 0.62 + (1 - clamped(transparency)) * 0.30
    }

    static func materialOpacity(for transparency: Double) -> Double {
        transparency <= 0 ? 0.0 : 0.28 + (1 - clamped(transparency)) * 0.62
    }

    static func baseFillOpacity(for transparency: Double) -> Double {
        transparency <= 0 ? 1.0 : 0.08 + (1 - clamped(transparency)) * 0.42
    }

    static func leadingHighlightOpacity(for transparency: Double) -> Double {
        transparency <= 0 ? 0.0 : 0.04 + (1 - clamped(transparency)) * 0.10
    }

    static func trailingHighlightOpacity(for transparency: Double) -> Double {
        transparency <= 0 ? 0.0 : 0.02 + (1 - clamped(transparency)) * 0.06
    }

    static func headerFillOpacity(for transparency: Double) -> Double {
        transparency <= 0 ? 1.0 : 0.22 + (1 - clamped(transparency)) * 0.30
    }

    static func moduleMaterialOpacity(for transparency: Double) -> Double {
        transparency <= 0 ? 0.0 : 0.22 + (1 - clamped(transparency)) * 0.34
    }

    static func moduleFillOpacity(for transparency: Double) -> Double {
        transparency <= 0 ? 1.0 : 0.045 + (1 - clamped(transparency)) * 0.22
    }
}

// MARK: - App Mark

struct QuotaRadarMark: View {
    let size: CGFloat

    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - Glass Card View

struct GlassCard<Content: View>: View {
    @Environment(\.menuGlassTransparency) private var menuGlassTransparency
    @ViewBuilder var content: Content

    private var strokeOpacity: Double {
        0.16 + (1 - menuGlassTransparency) * 0.12
    }

    private var shadowOpacity: Double {
        0.10 + (1 - menuGlassTransparency) * 0.08
    }

    var body: some View {
        content
            .padding(16)
            .background(
                GlassBackground(transparency: menuGlassTransparency)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(strokeOpacity), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(shadowOpacity), radius: 10, x: 0, y: 4)
    }
}

struct GlassBackground: View {
    let transparency: Double

    private var materialOpacity: Double {
        StatusBarGlassMetrics.materialOpacity(for: transparency)
    }

    private var baseFillOpacity: Double {
        StatusBarGlassMetrics.baseFillOpacity(for: transparency)
    }

    private var leadingHighlightOpacity: Double {
        StatusBarGlassMetrics.leadingHighlightOpacity(for: transparency)
    }

    private var trailingHighlightOpacity: Double {
        StatusBarGlassMetrics.trailingHighlightOpacity(for: transparency)
    }

    var body: some View {
        ZStack {
            // 背景模糊
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .opacity(materialOpacity)

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(baseFillOpacity))

            // 微妙渐变覆盖
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(leadingHighlightOpacity),
                            Color.white.opacity(trailingHighlightOpacity)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

// MARK: - Provider Icon (Custom Image)

struct ProviderIcon: View {
    enum Style {
        case colorful
        case monochrome
        case compactBadge
    }

    let provider: Provider
    let size: CGFloat
    let style: Style

    init(provider: Provider, size: CGFloat, style: Style = .colorful) {
        self.provider = provider
        self.size = size
        self.style = style
    }

    var body: some View {
        if style == .compactBadge {
            compactBadgeIcon
        } else if style == .monochrome {
            monochromeIcon
        } else if let iconImage = customIcon {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(Color.white.opacity(0.08))

                Image(nsImage: iconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(size * 0.08)
            }
            .frame(width: size, height: size)
        } else {
            // Fallback to SF Symbol if custom icon not found
            Image(systemName: provider.icon)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .fill(provider.color.gradient)
                        .shadow(color: provider.color.opacity(0.4), radius: 4, x: 0, y: 2)
                )
        }
    }

    private var officialColorProviderIcon: Bool {
        switch provider {
        case .claudeAPIUsage, .claudeSubscription:
            return true
        case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .querit, .anthropic, .codexAPIUsage, .codexSubscription, .kimiSubscription, .deepseek, .xfyunCodingPlan, .xfyunTokenPlan, .volcengineCodingPlan, .volcengineTokenPlan, .opencodeGo, .aliyunCodingPlan, .aliyunTokenPlan, .tencentCloudCodingPlan, .tencentCloudTokenPlan:
            return false
        }
    }

    @ViewBuilder
    private var compactBadgeIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .fill(provider.color.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.6)
                )

            if let iconImage = customIcon {
                Image(nsImage: iconImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .padding(size * 0.13)
            } else {
                Image(systemName: provider.icon)
                    .font(.system(size: size * 0.56, weight: .semibold))
                    .foregroundStyle(provider.color)
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var monochromeIcon: some View {
        if let iconImage = customIcon {
            if officialColorProviderIcon {
                Image(nsImage: iconImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .padding(size * 0.10)
                    .frame(width: size, height: size)
            } else {
                Image(nsImage: iconImage)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.primary)
                    .padding(size * 0.10)
                    .frame(width: size, height: size)
            }
        } else {
            Image(systemName: provider.icon)
                .font(.system(size: size * 0.70, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: size, height: size)
        }
    }

    private var customIcon: NSImage? {
        if let icon = NSImage(named: provider.iconAssetName) {
            return icon
        }

        let folderName = provider.iconAssetName.replacingOccurrences(of: "ProviderIcons/", with: "")
        let subdirectory = "Assets.xcassets/ProviderIcons/\(folderName).iconset"
        guard let bundle = swiftPMResourceBundle,
              let url = bundle.url(
            forResource: "icon_32x32@2x",
            withExtension: "png",
            subdirectory: subdirectory
        ) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    private var swiftPMResourceBundle: Bundle? {
        let bundleName = "QuotaRadar_QuotaRadar.bundle"
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent(bundleName),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/\(bundleName)")
        ]

        for url in candidates.compactMap({ $0 }) {
            if let bundle = Bundle(url: url) {
                return bundle
            }
        }

        return nil
    }
}

struct QuotaWindowDetails: View {
    let windows: [QuotaWindowText]
    var compact: Bool = false

    private var visibleWindows: [QuotaWindowText] {
        windows.filter { !$0.name.isEmpty && !$0.percentText.isEmpty }
    }

    var body: some View {
        if !visibleWindows.isEmpty {
            VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                ForEach(Array(visibleWindows.enumerated()), id: \.offset) { _, window in
                    HStack(spacing: 8) {
                        Text(window.displayText)
                            .font(.system(size: compact ? 10 : 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Spacer(minLength: 8)

                        if let detailValueText = window.detailValueText {
                            Text(detailValueText)
                                .font(.system(size: compact ? 10 : 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.70)
                        }
                    }
                }
            }
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.vertical, compact ? 6 : 8)
            .background(Color.primary.opacity(compact ? 0.028 : 0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

// MARK: - Progress Ring

struct ProgressRing: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat

    private var normalizedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            // 背景圆环
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)

            // 进度圆环
            Circle()
                .trim(from: 0, to: normalizedProgress)
                .stroke(
                    color.gradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: normalizedProgress)
        }
    }
}

// MARK: - Usage Bar

struct UsageBar: View {
    let percentage: Double
    let color: Color

    private var normalized: Double {
        min(max(percentage, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.1))

                // 进度条
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * normalized)
                    .animation(.easeInOut(duration: 0.5), value: normalized)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Glass Button

struct GlassButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.thinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Refresh Button

struct RefreshButton: View {
    @Binding var isRefreshing: Bool
    var isEnabled = true
    var size: CGFloat = 32
    var helpText: String? = nil
    var accessibilityLabelText: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(.thinMaterial)
                )
                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                .animation(
                    isRefreshing ?
                        Animation.linear(duration: 1).repeatForever(autoreverses: false) :
                        .default,
                    value: isRefreshing
                )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isRefreshing || !isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .help(helpText ?? L10n.t(.refreshQuotaAction))
        .accessibilityLabel(accessibilityLabelText ?? L10n.t(.refreshQuotaAction))
    }
}

struct ProviderRefreshButton: View {
    let provider: Provider
    @Binding var isRefreshing: Bool
    var isEnabled = true
    var size: CGFloat = 32
    var helpText: String? = nil
    var accessibilityLabelText: String? = nil
    let action: () -> Void

    @State private var showingCostlyRefreshConfirmation = false

    var body: some View {
        RefreshButton(
            isRefreshing: $isRefreshing,
            isEnabled: isEnabled,
            size: size,
            helpText: helpText,
            accessibilityLabelText: accessibilityLabelText,
            action: requestRefresh
        )
        .confirmationDialog(L10n.t(.costlyQuotaRefreshTitle), isPresented: $showingCostlyRefreshConfirmation, titleVisibility: .visible) {
            Button(L10n.t(.refreshQuotaConsumesQuotaAction), role: .destructive, action: action)
            Button(L10n.t(.cancel), role: .cancel) {}
        } message: {
            Text(L10n.t(.costlyQuotaRefreshMessage))
        }
    }

    private func requestRefresh() {
        guard provider.capability.requiresCostlyConfirmation else {
            action()
            return
        }
        showingCostlyRefreshConfirmation = true
    }
}
