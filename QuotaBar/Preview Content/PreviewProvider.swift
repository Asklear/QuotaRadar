import SwiftUI

// MARK: - Preview Data

struct PreviewData {
    static let sampleKeys: [APIKey] = SampleData.keys.map { key in
        var mutable = key
        // 为预览添加一些随机数据
        mutable.remaining = Int.random(in: 100...key.key.count * 10)
        mutable.limit = key.key.count * 10
        mutable.lastUpdated = Date().addingTimeInterval(Double.random(in: -3600...0))
        return mutable
    }
}

// MARK: - Preview Monitor

class PreviewMonitor: QuotaMonitor {
    override init() {
        super.init()
        self.apiKeys = PreviewData.sampleKeys
    }
}

// MARK: - View Previews (Debug Only)

#if DEBUG
#Preview("Menu Content") {
    MenuContentView(monitor: PreviewMonitor())
        .frame(width: 360, height: 520)
}

#Preview("Settings - Keys") {
    KeysManagementView(monitor: PreviewMonitor())
        .frame(width: 600, height: 500)
}

#Preview("Glass Card") {
    GlassCard {
        VStack(spacing: 12) {
            HStack {
                ProviderIcon(provider: .tavily, size: 32)
                VStack(alignment: .leading) {
                    Text("Tavily")
                        .font(.headline)
                    Text("2 keys")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            HStack {
                Text("850/1000")
                    .font(.caption)
                Spacer()
                UsageBar(percentage: 0.15, color: .green)
                    .frame(width: 100)
            }
        }
    }
    .frame(width: 300)
    .padding()
}

#Preview("Provider Icon") {
    HStack(spacing: 16) {
        ForEach(Provider.visibleCases.prefix(4)) { provider in
            ProviderIcon(provider: provider, size: 40)
        }
    }
    .padding()
}
#endif
