import Foundation
import SwiftUI

enum Provider: String, Codable, CaseIterable, Identifiable {
    // 搜索 Providers
    case tavily = "Tavily"
    case brave = "Brave"
    case serpapi = "SerpAPI"
    case serper = "Serper"
    case exa = "Exa"
    case bocha = "Bocha"
    case anysearch = "AnySearch"
    case wxmp = "微信搜索"
    case querit = "Querit"

    // LLM Providers
    case anthropic = "Anthropic"
    case claudeAPIUsage = "Claude API Usage"
    case claudeSubscription = "Claude Subscription"
    case codexAPIUsage = "Codex API Usage"
    case codexSubscription = "Codex Subscription"
    case deepseek = "DeepSeek"
    case xfyunCodingPlan = "讯飞星火"
    case xfyunTokenPlan = "XFYun Spark Token Plan"
    case volcengineCodingPlan = "火山引擎"
    case volcengineTokenPlan = "Volcengine Token Plan"
    case opencodeGo = "OpenCode Go"
    case aliyunCodingPlan = "Aliyun Coding Plan"
    case aliyunTokenPlan = "Aliyun Token Plan"
    case tencentCloudCodingPlan = "Tencent Cloud Coding Plan"
    case tencentCloudTokenPlan = "Tencent Cloud Token Plan"

    var id: String { rawValue }

    static let pendingQuotaIntegrationCases: Set<Provider> = [
        .xfyunTokenPlan,
        .volcengineTokenPlan,
        .aliyunTokenPlan,
        .tencentCloudTokenPlan
    ]

    static var visibleCases: [Provider] {
        allCases.filter {
            $0 != .anthropic
                && $0 != .claudeAPIUsage
                && $0 != .codexAPIUsage
                && !pendingQuotaIntegrationCases.contains($0)
        }
    }

    static let categoryDisplayOrder = ["AI Search", "LLM"]

    func displayName(language: AppLanguage = AppLanguageStore.shared.language) -> String {
        switch language {
        case .english:
            switch self {
            case .wxmp:
                return "WeChat Search"
            case .xfyunCodingPlan:
                return "XFYun Spark Coding Plan"
            case .xfyunTokenPlan:
                return "XFYun Spark Token Plan"
            case .volcengineCodingPlan:
                return "Volcengine Coding Plan"
            case .volcengineTokenPlan:
                return "Volcengine Token Plan"
            case .aliyunCodingPlan:
                return "Aliyun Coding Plan"
            case .aliyunTokenPlan:
                return "Aliyun Token Plan"
            case .tencentCloudCodingPlan:
                return "Tencent Cloud Coding Plan"
            case .tencentCloudTokenPlan:
                return "Tencent Cloud Token Plan"
            case .claudeAPIUsage:
                return "Claude API Usage"
            case .claudeSubscription:
                return "Claude Subscription"
            case .codexAPIUsage:
                return "Codex API Usage"
            case .codexSubscription:
                return "Codex Subscription"
            case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .querit, .anthropic, .deepseek, .opencodeGo:
                return rawValue
            }
        case .simplifiedChinese:
            switch self {
            case .brave:
                return "Brave"
            case .serpapi:
                return "SerpAPI"
            case .serper:
                return "Serper"
            case .exa:
                return "Exa"
            case .bocha:
                return "博查"
            case .anysearch:
                return "AnySearch"
            case .querit:
                return "Querit"
            case .deepseek:
                return "Deepseek"
            case .claudeAPIUsage:
                return "Claude API 用量"
            case .claudeSubscription:
                return "Claude 订阅"
            case .codexAPIUsage:
                return "Codex API 用量"
            case .codexSubscription:
                return "Codex 订阅"
            case .xfyunCodingPlan:
                return "讯飞星火 coding plan"
            case .xfyunTokenPlan:
                return "讯飞星火 Token plan"
            case .volcengineCodingPlan:
                return "火山引擎 coding plan"
            case .volcengineTokenPlan:
                return "火山引擎 Token plan"
            case .aliyunCodingPlan:
                return "阿里云 coding plan"
            case .aliyunTokenPlan:
                return "阿里云 Token plan"
            case .tencentCloudCodingPlan:
                return "腾讯云 coding plan"
            case .tencentCloudTokenPlan:
                return "腾讯云 Token plan"
            case .tavily, .wxmp, .anthropic, .opencodeGo:
                return rawValue
            }
        case .traditionalChinese:
            switch self {
            case .wxmp:
                return "微信搜尋"
            case .xfyunCodingPlan:
                return "訊飛星火 coding plan"
            case .xfyunTokenPlan:
                return "訊飛星火 Token plan"
            case .volcengineCodingPlan:
                return "火山引擎 coding plan"
            case .volcengineTokenPlan:
                return "火山引擎 Token plan"
            case .bocha:
                return "博查"
            case .deepseek:
                return "Deepseek"
            case .claudeAPIUsage:
                return "Claude API 用量"
            case .claudeSubscription:
                return "Claude 訂閱"
            case .codexAPIUsage:
                return "Codex API 用量"
            case .codexSubscription:
                return "Codex 訂閱"
            case .aliyunCodingPlan:
                return "阿里雲 coding plan"
            case .aliyunTokenPlan:
                return "阿里雲 Token plan"
            case .tencentCloudCodingPlan:
                return "騰訊雲 coding plan"
            case .tencentCloudTokenPlan:
                return "騰訊雲 Token plan"
            case .tavily, .brave, .serpapi, .serper, .exa, .anysearch, .querit, .anthropic, .opencodeGo:
                return rawValue
            }
        case .japanese:
            switch self {
            case .wxmp:
                return "WeChat 検索"
            case .xfyunCodingPlan:
                return "XFYun Spark Coding Plan"
            case .xfyunTokenPlan:
                return "XFYun Spark Token Plan"
            case .volcengineCodingPlan:
                return "Volcengine Coding Plan"
            case .volcengineTokenPlan:
                return "Volcengine Token Plan"
            case .aliyunCodingPlan:
                return "Aliyun Coding Plan"
            case .aliyunTokenPlan:
                return "Aliyun Token Plan"
            case .tencentCloudCodingPlan:
                return "Tencent Cloud Coding Plan"
            case .tencentCloudTokenPlan:
                return "Tencent Cloud Token Plan"
            case .claudeAPIUsage:
                return "Claude API Usage"
            case .claudeSubscription:
                return "Claude Subscription"
            case .codexAPIUsage:
                return "Codex API Usage"
            case .codexSubscription:
                return "Codex Subscription"
            case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .querit, .anthropic, .deepseek, .opencodeGo:
                return rawValue
            }
        case .korean:
            switch self {
            case .wxmp:
                return "WeChat 검색"
            case .xfyunCodingPlan:
                return "XFYun Spark Coding Plan"
            case .xfyunTokenPlan:
                return "XFYun Spark Token Plan"
            case .volcengineCodingPlan:
                return "Volcengine Coding Plan"
            case .volcengineTokenPlan:
                return "Volcengine Token Plan"
            case .aliyunCodingPlan:
                return "Aliyun Coding Plan"
            case .aliyunTokenPlan:
                return "Aliyun Token Plan"
            case .tencentCloudCodingPlan:
                return "Tencent Cloud Coding Plan"
            case .tencentCloudTokenPlan:
                return "Tencent Cloud Token Plan"
            case .claudeAPIUsage:
                return "Claude API Usage"
            case .claudeSubscription:
                return "Claude Subscription"
            case .codexAPIUsage:
                return "Codex API Usage"
            case .codexSubscription:
                return "Codex Subscription"
            case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .querit, .anthropic, .deepseek, .opencodeGo:
                return rawValue
            }
        }
    }

    func providerFamilyDisplayName(language: AppLanguage = AppLanguageStore.shared.language) -> String {
        switch language {
        case .english:
            switch self {
            case .xfyunCodingPlan, .xfyunTokenPlan:
                return "XFYun Spark"
            case .volcengineCodingPlan, .volcengineTokenPlan:
                return "Volcengine"
            case .aliyunCodingPlan, .aliyunTokenPlan:
                return "Aliyun"
            case .tencentCloudCodingPlan, .tencentCloudTokenPlan:
                return "Tencent Cloud"
            case .claudeAPIUsage, .claudeSubscription:
                return "Claude"
            case .codexAPIUsage, .codexSubscription:
                return "Codex"
            case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .querit, .anthropic, .deepseek, .opencodeGo:
                return displayName(language: language)
            }
        case .simplifiedChinese:
            switch self {
            case .xfyunCodingPlan, .xfyunTokenPlan:
                return "讯飞星火"
            case .volcengineCodingPlan, .volcengineTokenPlan:
                return "火山引擎"
            case .aliyunCodingPlan, .aliyunTokenPlan:
                return "阿里云"
            case .tencentCloudCodingPlan, .tencentCloudTokenPlan:
                return "腾讯云"
            case .claudeAPIUsage, .claudeSubscription:
                return "Claude"
            case .codexAPIUsage, .codexSubscription:
                return "Codex"
            case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .querit, .anthropic, .deepseek, .opencodeGo:
                return displayName(language: language)
            }
        case .traditionalChinese:
            switch self {
            case .xfyunCodingPlan, .xfyunTokenPlan:
                return "訊飛星火"
            case .volcengineCodingPlan, .volcengineTokenPlan:
                return "火山引擎"
            case .aliyunCodingPlan, .aliyunTokenPlan:
                return "阿里雲"
            case .tencentCloudCodingPlan, .tencentCloudTokenPlan:
                return "騰訊雲"
            case .claudeAPIUsage, .claudeSubscription:
                return "Claude"
            case .codexAPIUsage, .codexSubscription:
                return "Codex"
            case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .querit, .anthropic, .deepseek, .opencodeGo:
                return displayName(language: language)
            }
        case .japanese, .korean:
            switch self {
            case .xfyunCodingPlan, .xfyunTokenPlan:
                return "XFYun Spark"
            case .volcengineCodingPlan, .volcengineTokenPlan:
                return "Volcengine"
            case .aliyunCodingPlan, .aliyunTokenPlan:
                return "Aliyun"
            case .tencentCloudCodingPlan, .tencentCloudTokenPlan:
                return "Tencent Cloud"
            case .claudeAPIUsage, .claudeSubscription:
                return "Claude"
            case .codexAPIUsage, .codexSubscription:
                return "Codex"
            case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .querit, .anthropic, .deepseek, .opencodeGo:
                return displayName(language: language)
            }
        }
    }

    func planTypeDisplayName(language: AppLanguage = AppLanguageStore.shared.language) -> String? {
        switch self {
        case .xfyunCodingPlan, .volcengineCodingPlan, .aliyunCodingPlan, .tencentCloudCodingPlan:
            switch language {
            case .english:
                return "Coding Plan"
            case .simplifiedChinese, .traditionalChinese, .japanese, .korean:
                return "coding plan"
            }
        case .xfyunTokenPlan, .volcengineTokenPlan, .aliyunTokenPlan, .tencentCloudTokenPlan:
            switch language {
            case .english:
                return "Token Plan"
            case .simplifiedChinese, .traditionalChinese, .japanese, .korean:
                return "Token plan"
            }
        case .claudeAPIUsage, .codexAPIUsage:
            switch language {
            case .english:
                return "API Usage"
            case .simplifiedChinese:
                return "API 用量"
            case .traditionalChinese:
                return "API 用量"
            case .japanese:
                return "API 使用量"
            case .korean:
                return "API 사용량"
            }
        case .claudeSubscription, .codexSubscription:
            switch language {
            case .english:
                return "Subscription"
            case .simplifiedChinese:
                return "订阅"
            case .traditionalChinese:
                return "訂閱"
            case .japanese:
                return "サブスクリプション"
            case .korean:
                return "구독"
            }
        case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .querit, .anthropic, .deepseek, .opencodeGo:
            return nil
        }
    }

    /// Asset catalog name for custom icon
    var iconAssetName: String {
        switch self {
        case .aliyunCodingPlan, .aliyunTokenPlan:
            return "ProviderIcons/aliyun"
        case .tencentCloudCodingPlan, .tencentCloudTokenPlan:
            return "ProviderIcons/tencentCloud"
        case .volcengineCodingPlan, .volcengineTokenPlan:
            return "ProviderIcons/volcengine"
        case .xfyunCodingPlan, .xfyunTokenPlan:
            return "ProviderIcons/xfyun"
        case .claudeAPIUsage, .claudeSubscription:
            return "ProviderIcons/claude"
        case .codexAPIUsage, .codexSubscription:
            return "ProviderIcons/codex"
        case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .querit, .anthropic, .deepseek, .opencodeGo:
            return "ProviderIcons/\(self)"
        }
    }

    var quotaCheckConsumesSearchQuota: Bool {
        switch self {
        case .brave:
            return true
        case .tavily, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .querit, .anthropic, .claudeAPIUsage, .claudeSubscription, .codexAPIUsage, .codexSubscription, .deepseek, .xfyunCodingPlan, .xfyunTokenPlan, .volcengineCodingPlan, .volcengineTokenPlan, .opencodeGo, .aliyunCodingPlan, .aliyunTokenPlan, .tencentCloudCodingPlan, .tencentCloudTokenPlan:
            return false
        }
    }

    var usesMoneyBalance: Bool {
        switch self {
        case .deepseek, .bocha, .wxmp:
            return true
        case .tavily, .brave, .serpapi, .serper, .exa, .anysearch, .querit, .anthropic, .claudeAPIUsage, .claudeSubscription, .codexAPIUsage, .codexSubscription, .xfyunCodingPlan, .xfyunTokenPlan, .volcengineCodingPlan, .volcengineTokenPlan, .opencodeGo, .aliyunCodingPlan, .aliyunTokenPlan, .tencentCloudCodingPlan, .tencentCloudTokenPlan:
            return false
        }
    }

    /// SF Symbol fallback name
    var icon: String {
        switch self {
        case .tavily: return "magnifyingglass.circle.fill"
        case .brave: return "shield.lefthalf.fill"
        case .serpapi: return "network"
        case .serper: return "safari.fill"
        case .exa: return "bolt.circle.fill"
        case .bocha: return "search.circle.fill"
        case .anysearch: return "globe"
        case .wxmp: return "message.circle.fill"
        case .querit: return "magnifyingglass"
        case .anthropic: return "brain.head.profile"
        case .claudeAPIUsage: return "chart.line.uptrend.xyaxis"
        case .claudeSubscription: return "clock.badge.checkmark"
        case .codexAPIUsage: return "chevron.left.forwardslash.chevron.right"
        case .codexSubscription: return "terminal.fill"
        case .deepseek: return "sparkles"
        case .xfyunCodingPlan: return "waveform.path.ecg"
        case .xfyunTokenPlan: return "waveform.path.badge.plus"
        case .volcengineCodingPlan: return "flame.fill"
        case .volcengineTokenPlan: return "flame.circle.fill"
        case .opencodeGo: return "terminal.fill"
        case .aliyunCodingPlan: return "cloud.fill"
        case .aliyunTokenPlan: return "cloud.circle.fill"
        case .tencentCloudCodingPlan: return "cloud.bolt.fill"
        case .tencentCloudTokenPlan: return "key.radiowaves.forward.fill"
        }
    }

    var color: Color {
        switch self {
        case .tavily: return .blue
        case .brave: return .orange
        case .serpapi: return .green
        case .serper: return .mint
        case .exa: return .pink
        case .bocha: return .cyan
        case .anysearch: return .purple
        case .wxmp: return .green
        case .querit: return .indigo
        case .anthropic: return Color(hex: "191919")
        case .claudeAPIUsage, .claudeSubscription: return Color(hex: "D97757")
        case .codexAPIUsage, .codexSubscription: return Color(hex: "111827")
        case .deepseek: return Color(hex: "4D6BFA") // DeepSeek blue
        case .xfyunCodingPlan: return Color(hex: "E23B3B")
        case .xfyunTokenPlan: return Color(hex: "C81E1E")
        case .volcengineCodingPlan: return Color(hex: "2F6BFF")
        case .volcengineTokenPlan: return Color(hex: "155EEF")
        case .opencodeGo: return Color(hex: "111827")
        case .aliyunCodingPlan: return Color(hex: "FF6A00")
        case .aliyunTokenPlan: return Color(hex: "F15A24")
        case .tencentCloudCodingPlan: return Color(hex: "006EFF")
        case .tencentCloudTokenPlan: return Color(hex: "0052D9")
        }
    }

    var category: String {
        switch self {
        case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .querit:
            return "Search"
        case .anthropic, .claudeAPIUsage, .claudeSubscription, .codexAPIUsage, .codexSubscription, .deepseek, .xfyunCodingPlan, .xfyunTokenPlan, .volcengineCodingPlan, .volcengineTokenPlan, .opencodeGo, .aliyunCodingPlan, .aliyunTokenPlan, .tencentCloudCodingPlan, .tencentCloudTokenPlan:
            return "LLM"
        }
    }

    var statusBarCategoryTitle: String {
        switch category {
        case "Search":
            return "AI Search"
        default:
            return category
        }
    }

    var homeVisibleWithoutKeys: Bool {
        switch self {
        case .deepseek, .xfyunCodingPlan, .volcengineCodingPlan, .opencodeGo:
            return true
        case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .querit, .anthropic, .claudeAPIUsage, .claudeSubscription, .codexAPIUsage, .codexSubscription, .xfyunTokenPlan, .volcengineTokenPlan, .aliyunCodingPlan, .aliyunTokenPlan, .tencentCloudCodingPlan, .tencentCloudTokenPlan:
            return false
        }
    }

    var supportsDashboardReauthentication: Bool {
        switch self {
        case .querit, .xfyunCodingPlan, .volcengineCodingPlan, .opencodeGo, .aliyunCodingPlan, .tencentCloudCodingPlan, .claudeSubscription, .codexSubscription:
            return true
        case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .anthropic, .claudeAPIUsage, .codexAPIUsage, .deepseek, .xfyunTokenPlan, .volcengineTokenPlan, .aliyunTokenPlan, .tencentCloudTokenPlan:
            return false
        }
    }

    var cookieDomains: [String] {
        switch self {
        case .xfyunCodingPlan, .xfyunTokenPlan:
            return ["xfyun.cn", "maas.xfyun.cn"]
        case .volcengineCodingPlan, .volcengineTokenPlan:
            return ["volcengine.com", "console.volcengine.com"]
        case .opencodeGo:
            return ["opencode.ai"]
        case .querit:
            return ["querit.ai"]
        case .claudeSubscription:
            return ["claude.ai"]
        case .codexSubscription:
            return ["chatgpt.com"]
        case .aliyunCodingPlan, .aliyunTokenPlan:
            return ["aliyun.com", "bailian.console.aliyun.com"]
        case .tencentCloudCodingPlan:
            return ["cloud.tencent.com", "console.cloud.tencent.com"]
        case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .anthropic, .claudeAPIUsage, .codexAPIUsage, .deepseek, .tencentCloudTokenPlan:
            return []
        }
    }

    var dashboardAuthenticationCookieNames: [String] {
        switch self {
        case .querit:
            return ["osduss", "passOsRefreshTk", "osfuid"]
        case .xfyunCodingPlan, .xfyunTokenPlan:
            return ["ssoSessionId", "tenantToken", "atp-auth-token", "account_id"]
        case .volcengineCodingPlan, .volcengineTokenPlan:
            return ["digest", "AccountID", "csrfToken"]
        case .opencodeGo:
            return ["auth"]
        case .claudeSubscription:
            return ["sessionKey"]
        case .codexSubscription:
            return ["__Secure-next-auth.session-token|__Secure-next-auth.session-token.*|__search-next-auth"]
        case .aliyunCodingPlan, .aliyunTokenPlan:
            return ["login_aliyunid_ticket", "aliyun_lang", "cna"]
        case .tencentCloudCodingPlan:
            return ["uin", "skey"]
        case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .anthropic, .claudeAPIUsage, .codexAPIUsage, .deepseek, .tencentCloudTokenPlan:
            return []
        }
    }

    var defaultCredentialName: String {
        switch self {
        case .xfyunCodingPlan:
            return "XFYUN_CODING_PLAN_COOKIE"
        case .xfyunTokenPlan:
            return "XFYUN_TOKEN_PLAN_COOKIE"
        case .volcengineCodingPlan:
            return "VOLCENGINE_CODING_PLAN_COOKIE"
        case .volcengineTokenPlan:
            return "VOLCENGINE_TOKEN_PLAN_COOKIE"
        case .opencodeGo:
            return "OPENCODE_GO_COOKIE"
        case .aliyunCodingPlan:
            return "ALIYUN_CODING_PLAN_COOKIE"
        case .aliyunTokenPlan:
            return "ALIYUN_TOKEN_PLAN_COOKIE"
        case .tencentCloudCodingPlan:
            return "TENCENT_CLOUD_CODING_PLAN_COOKIE"
        case .tencentCloudTokenPlan:
            return "TENCENT_CLOUD_TOKEN_PLAN_CREDENTIAL"
        case .claudeAPIUsage:
            return "ANTHROPIC_API_KEY"
        case .claudeSubscription:
            return "CLAUDE_SUBSCRIPTION_SESSION"
        case .codexAPIUsage:
            return "OPENAI_API_KEY"
        case .codexSubscription:
            return "CODEX_SUBSCRIPTION_SESSION"
        case .tavily:
            return "TAVILY_API_KEY"
        case .brave:
            return "BRAVE_API_KEY"
        case .serpapi:
            return "SERPAPI_API_KEY"
        case .serper:
            return "SERPER_API_KEY"
        case .exa:
            return "EXA_API_KEY"
        case .bocha:
            return "BOCHA_API_KEY"
        case .anysearch:
            return "ANYSEARCH_API_KEY"
        case .wxmp:
            return "WECHAT_API_KEY"
        case .querit:
            return "QUERIT_COOKIE"
        case .anthropic:
            return "ANTHROPIC_API_KEY"
        case .deepseek:
            return "DEEPSEEK_API_KEY"
        }
    }

    var supportsCompanionAPIKeyStorage: Bool {
        switch self {
        case .querit, .xfyunCodingPlan, .volcengineCodingPlan, .opencodeGo, .aliyunCodingPlan, .tencentCloudCodingPlan:
            return true
        case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .anthropic, .claudeAPIUsage, .claudeSubscription, .codexAPIUsage, .codexSubscription, .deepseek, .xfyunTokenPlan, .volcengineTokenPlan, .aliyunTokenPlan, .tencentCloudTokenPlan:
            return false
        }
    }

    var copyableAPIKeyCredentialName: String {
        switch self {
        case .querit:
            return "QUERIT_API_KEY"
        case .xfyunCodingPlan:
            return "XFYUN_CODING_PLAN_API_KEY"
        case .volcengineCodingPlan:
            return "VOLCENGINE_CODING_PLAN_API_KEY"
        case .opencodeGo:
            return "OPENCODE_GO_API_KEY"
        case .aliyunCodingPlan:
            return "ALIYUN_CODING_PLAN_API_KEY"
        case .tencentCloudCodingPlan:
            return "TENCENT_CLOUD_CODING_PLAN_API_KEY"
        case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .anthropic, .claudeAPIUsage, .claudeSubscription, .codexAPIUsage, .codexSubscription, .deepseek, .xfyunTokenPlan, .volcengineTokenPlan, .aliyunTokenPlan, .tencentCloudTokenPlan:
            return defaultCredentialName
        }
    }

    /// 是否支持主动查询 quota（通过 API endpoint）
    var supportsQuotaQuery: Bool {
        switch self {
        case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .querit, .deepseek, .xfyunCodingPlan, .volcengineCodingPlan, .opencodeGo, .aliyunCodingPlan, .tencentCloudCodingPlan, .tencentCloudTokenPlan, .codexSubscription:
            return true
        case .anthropic, .claudeAPIUsage, .claudeSubscription, .codexAPIUsage, .xfyunTokenPlan, .volcengineTokenPlan, .aliyunTokenPlan:
            return false // 只能通过 response header、dashboard，或未公开 quota API
        }
    }

    func localizedUnsupportedQuotaLabel(language: AppLanguage = AppLanguageStore.shared.language) -> String {
        switch self {
        case .querit, .anthropic, .claudeSubscription:
            return dashboardURL == nil ? L10n.t(.quotaUnavailable, language: language) : L10n.t(.openDashboard, language: language)
        case .exa:
            return L10n.t(.adminCredentialRequired, language: language)
        case .tavily, .brave, .serpapi, .serper, .bocha, .anysearch, .wxmp, .deepseek, .claudeAPIUsage, .codexAPIUsage, .xfyunCodingPlan, .xfyunTokenPlan, .volcengineCodingPlan, .volcengineTokenPlan, .opencodeGo, .aliyunCodingPlan, .aliyunTokenPlan, .tencentCloudCodingPlan, .tencentCloudTokenPlan:
            return L10n.t(.quotaUnavailable, language: language)
        case .codexSubscription:
            return L10n.t(.openDashboard, language: language)
        }
    }

    func unsupportedQuotaDiagnosticMessage(language: AppLanguage = AppLanguageStore.shared.language) -> String {
        switch self {
        case .querit:
            return L10n.t(.queritDashboardOnlyDiagnostic, language: language)
        case .exa:
            return L10n.t(.exaServiceKeyDiagnostic, language: language)
        case .anthropic:
            return L10n.t(.anthropicDashboardOnlyDiagnostic, language: language)
        case .claudeAPIUsage, .codexAPIUsage:
            return L10n.t(.quotaCheckNotSupportedDiagnostic, language: language)
        case .claudeSubscription, .codexSubscription:
            return L10n.t(.businessInvocationKeyUnsupportedDiagnostic, language: language)
        case .aliyunCodingPlan:
            return L10n.t(.businessInvocationKeyUnsupportedDiagnostic, language: language)
        case .tavily, .brave, .serpapi, .serper, .bocha, .anysearch, .wxmp, .deepseek, .xfyunCodingPlan, .xfyunTokenPlan, .volcengineCodingPlan, .volcengineTokenPlan, .opencodeGo, .aliyunTokenPlan, .tencentCloudCodingPlan, .tencentCloudTokenPlan:
            return L10n.t(.quotaCheckNotSupportedDiagnostic, language: language)
        }
    }

    /// Dashboard URL 用于手动查看
    var dashboardURL: String? {
        switch self {
        case .tavily:
            return "https://app.tavily.com/home"
        case .brave:
            return "https://api.search.brave.com/app/dashboard"
        case .serpapi:
            return "https://serpapi.com/dashboard"
        case .serper:
            return "https://serper.dev/api-key"
        case .exa:
            return "https://dashboard.exa.ai/"
        case .bocha:
            return nil
        case .anysearch:
            return nil
        case .wxmp:
            return "https://www.dajiala.com/main/interface?actnav=1"
        case .querit:
            return "https://www.querit.ai/en/dashboard/usage"
        case .anthropic:
            return "https://console.anthropic.com/settings/usage"
        case .claudeAPIUsage:
            return "https://console.anthropic.com/settings/usage"
        case .claudeSubscription:
            return "https://claude.ai/settings/usage"
        case .codexAPIUsage:
            return "https://platform.openai.com/usage"
        case .codexSubscription:
            return "https://chatgpt.com"
        case .deepseek:
            return "https://platform.deepseek.com/usage"
        case .xfyunCodingPlan:
            return "https://maas.xfyun.cn/packageSubscription"
        case .xfyunTokenPlan:
            return "https://maas.xfyun.cn/packageSubscription"
        case .volcengineCodingPlan:
            return "https://console.volcengine.com/ark/region:ark+cn-beijing/openManagement?LLM=%7B%7D&advancedActiveKey=subscribe&projectName=default"
        case .volcengineTokenPlan:
            return "https://console.volcengine.com/ark/region:ark+cn-beijing/openManagement?LLM=%7B%7D&advancedActiveKey=subscribe&projectName=default"
        case .opencodeGo:
            return "https://opencode.ai/workspace/wrk_01KSKR4K4WDJY0JZSCJTMRZ5CV/go"
        case .aliyunCodingPlan:
            return "https://bailian.console.aliyun.com/"
        case .aliyunTokenPlan:
            return "https://bailian.console.aliyun.com/"
        case .tencentCloudCodingPlan:
            return "https://console.cloud.tencent.com/tokenhub/codingplan"
        case .tencentCloudTokenPlan:
            return "https://console.cloud.tencent.com/tokenhub/tokenplan"
        }
    }

    var capability: ProviderCapability {
        switch self {
        case .exa:
            return ProviderCapability(
                credentialKind: .adminCredential,
                usageSource: .officialAPI,
                resetCycle: .notExposed,
                consumesQuota: quotaCheckConsumesSearchQuota,
                supportsCurlImport: false,
                canTestConnection: supportsQuotaQuery,
                notes: L10n.t(.exaServiceKeyDiagnostic)
            )
        case .querit:
            return ProviderCapability(
                credentialKind: .dashboardCookie,
                usageSource: .dashboardAPI,
                resetCycle: .notExposed,
                consumesQuota: quotaCheckConsumesSearchQuota,
                supportsCurlImport: true,
                canTestConnection: supportsQuotaQuery,
                notes: L10n.t(.dashboardCookieCapabilityNote)
            )
        case .xfyunCodingPlan, .volcengineCodingPlan, .opencodeGo, .aliyunCodingPlan, .tencentCloudCodingPlan:
            return ProviderCapability(
                credentialKind: .dashboardCookie,
                usageSource: supportsQuotaQuery ? .dashboardAPI : .unavailable,
                resetCycle: .dashboard,
                consumesQuota: quotaCheckConsumesSearchQuota,
                supportsCurlImport: true,
                canTestConnection: supportsQuotaQuery,
                notes: L10n.t(.dashboardCookieCapabilityNote)
            )
        case .xfyunTokenPlan, .volcengineTokenPlan, .aliyunTokenPlan:
            return ProviderCapability(
                credentialKind: .dashboardCookie,
                usageSource: .unavailable,
                resetCycle: .dashboard,
                consumesQuota: false,
                supportsCurlImport: true,
                canTestConnection: false,
                notes: L10n.t(.businessInvocationKeyUnsupportedDiagnostic)
            )
        case .tencentCloudTokenPlan:
            return ProviderCapability(
                credentialKind: .adminCredential,
                usageSource: .officialAPI,
                resetCycle: .monthly,
                consumesQuota: false,
                supportsCurlImport: false,
                canTestConnection: true,
                notes: L10n.t(.tencentCloudTokenPlanCredentialNote)
            )
        case .anthropic, .claudeAPIUsage, .codexAPIUsage:
            return ProviderCapability(
                credentialKind: .apiKey,
                usageSource: .unavailable,
                resetCycle: .notExposed,
                consumesQuota: quotaCheckConsumesSearchQuota,
                supportsCurlImport: false,
                canTestConnection: false,
                notes: L10n.t(.anthropicDashboardOnlyDiagnostic)
            )
        case .claudeSubscription:
            return ProviderCapability(
                credentialKind: .dashboardCookie,
                usageSource: .unavailable,
                resetCycle: .notExposed,
                consumesQuota: false,
                supportsCurlImport: true,
                canTestConnection: false,
                notes: L10n.t(.businessInvocationKeyUnsupportedDiagnostic)
            )
        case .codexSubscription:
            return ProviderCapability(
                credentialKind: .dashboardCookie,
                usageSource: .dashboardAPI,
                resetCycle: .dashboard,
                consumesQuota: false,
                supportsCurlImport: true,
                canTestConnection: true,
                notes: L10n.t(.dashboardCookieCapabilityNote)
            )
        case .tavily, .brave, .serpapi, .serper, .bocha, .anysearch, .wxmp, .deepseek:
            return ProviderCapability(
                credentialKind: .apiKey,
                usageSource: quotaDataCapabilitySource,
                resetCycle: providerResetCycle,
                consumesQuota: quotaCheckConsumesSearchQuota,
                supportsCurlImport: false,
                canTestConnection: supportsQuotaQuery,
                notes: quotaCheckConsumesSearchQuota ? L10n.t(.quotaConsumingRefreshWarning) : nil
            )
        }
    }

    private var quotaDataCapabilitySource: ProviderCapability.UsageSource {
        switch self {
        case .brave:
            return .responseHeader
        case .anysearch:
            return .localPolicy
        case .tavily, .serpapi, .serper, .bocha, .wxmp, .deepseek:
            return .officialAPI
        case .querit, .xfyunCodingPlan, .xfyunTokenPlan, .volcengineCodingPlan, .volcengineTokenPlan, .opencodeGo, .aliyunCodingPlan, .aliyunTokenPlan, .tencentCloudCodingPlan:
            return .dashboardAPI
        case .exa, .tencentCloudTokenPlan:
            return .officialAPI
        case .anthropic, .claudeAPIUsage, .claudeSubscription, .codexAPIUsage:
            return .unavailable
        case .codexSubscription:
            return .dashboardAPI
        }
    }

    private var providerResetCycle: ProviderCapability.ResetCycle {
        switch self {
        case .tavily, .serpapi, .tencentCloudTokenPlan:
            return .monthly
        case .xfyunCodingPlan, .xfyunTokenPlan, .volcengineCodingPlan, .volcengineTokenPlan, .opencodeGo, .aliyunCodingPlan, .aliyunTokenPlan, .tencentCloudCodingPlan:
            return .dashboard
        case .deepseek, .bocha, .wxmp, .anysearch:
            return .none
        case .brave, .serper, .exa, .querit, .anthropic, .claudeAPIUsage, .claudeSubscription, .codexAPIUsage:
            return .notExposed
        case .codexSubscription:
            return .dashboard
        }
    }
}

struct ProviderCapability: Equatable {
    enum CredentialKind: String, Equatable {
        case apiKey
        case dashboardCookie
        case adminCredential
    }

    enum UsageSource: String, Equatable {
        case officialAPI
        case dashboardAPI
        case responseHeader
        case localPolicy
        case unavailable
    }

    enum ResetCycle: String, Equatable {
        case none
        case monthly
        case dashboard
        case notExposed
    }

    let credentialKind: CredentialKind
    let usageSource: UsageSource
    let resetCycle: ResetCycle
    let consumesQuota: Bool
    let supportsCurlImport: Bool
    let canTestConnection: Bool
    let notes: String?
}

typealias CredentialKind = ProviderCapability.CredentialKind

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Quota Presentation

enum QuotaDataSource: String, Equatable {
    case officialAPI
    case dashboardAPI
    case responseHeader
    case localPolicy
    case unavailable

    var displayName: String {
        displayName(language: AppLanguageStore.shared.language)
    }

    func displayName(language: AppLanguage) -> String {
        switch (self, language) {
        case (.officialAPI, .english):
            return "Official API"
        case (.officialAPI, .simplifiedChinese):
            return "官方 API"
        case (.officialAPI, .traditionalChinese):
            return "官方 API"
        case (.officialAPI, .japanese):
            return "公式 API"
        case (.officialAPI, .korean):
            return "공식 API"
        case (.dashboardAPI, .english):
            return "Dashboard API"
        case (.dashboardAPI, .simplifiedChinese):
            return "控制台接口"
        case (.dashboardAPI, .traditionalChinese):
            return "控制台介面"
        case (.dashboardAPI, .japanese):
            return "ダッシュボード API"
        case (.dashboardAPI, .korean):
            return "대시보드 API"
        case (.responseHeader, .english):
            return "Response Header"
        case (.responseHeader, .simplifiedChinese):
            return "响应头"
        case (.responseHeader, .traditionalChinese):
            return "回應標頭"
        case (.responseHeader, .japanese):
            return "レスポンスヘッダー"
        case (.responseHeader, .korean):
            return "응답 헤더"
        case (.localPolicy, .english):
            return "Local Policy"
        case (.localPolicy, .simplifiedChinese):
            return "本地规则"
        case (.localPolicy, .traditionalChinese):
            return "本地規則"
        case (.localPolicy, .japanese):
            return "ローカルルール"
        case (.localPolicy, .korean):
            return "로컬 규칙"
        case (.unavailable, .english):
            return "Not Exposed"
        case (.unavailable, .simplifiedChinese):
            return "未公开"
        case (.unavailable, .traditionalChinese):
            return "未公開"
        case (.unavailable, .japanese):
            return "非公開"
        case (.unavailable, .korean):
            return "비공개"
        }
    }
}

struct QuotaPresentation: Equatable {
    let primaryText: String
    let badgeText: String
    let resetText: String
    let planEndText: String
    let percentRemaining: Double?
    let dataSource: QuotaDataSource
    let diagnosticText: String

    var sourceText: String {
        dataSource.displayName
    }

    func sourceText(language: AppLanguage) -> String {
        dataSource.displayName(language: language)
    }
}

struct MenuQuotaSummary: Equatable {
    let availableCount: Int
    let lowCount: Int
    let failedCount: Int

    init(keys: [APIKey]) {
        let activeKeys = keys.filter { $0.isActive && !$0.key.isEmpty && !$0.isStoredAPIKeyOnlyCredential }
        availableCount = activeKeys.filter { key in
            switch key.status {
            case .healthy, .low, .usableUnknown:
                return true
            case .exhausted, .expired, .failed, .disabled, .unknown:
                return false
            }
        }.count
        lowCount = activeKeys.filter { $0.isLow || $0.isExhausted }.count
        failedCount = activeKeys.filter { $0.status == .failed || $0.isCredentialExpired }.count
    }
}

struct MenuQuotaItem: Identifiable, Equatable {
    let provider: Provider
    let key: APIKey

    var id: UUID { key.id }

    var presentation: QuotaPresentation {
        key.quotaPresentation
    }

    var canRefresh: Bool {
        key.isActive && !key.key.isEmpty
    }

    static func topItems(from stats: [ProviderStats], limit: Int = 5) -> [MenuQuotaItem] {
        Array(
            stats
                .flatMap { stat in
                    stat.keys
                        .filter { !$0.isStoredAPIKeyOnlyCredential }
                        .map { MenuQuotaItem(provider: stat.provider, key: $0) }
                }
                .filter { $0.key.isActive }
                .sorted(by: shouldRankBefore)
                .prefix(limit)
        )
    }

    static func attentionItems(from stats: [ProviderStats], limit: Int = 5) -> [MenuQuotaItem] {
        Array(
            stats
                .flatMap { stat in
                    stat.keys
                        .filter { !$0.isStoredAPIKeyOnlyCredential }
                        .map { MenuQuotaItem(provider: stat.provider, key: $0) }
                }
                .filter { $0.key.isActive && $0.key.needsStatusBarAttention }
                .sorted(by: shouldRankBefore)
                .prefix(limit)
        )
    }

    private static func shouldRankBefore(_ lhs: MenuQuotaItem, _ rhs: MenuQuotaItem) -> Bool {
        let lhsKey = lhs.priorityKey
        let rhsKey = rhs.priorityKey

        if lhsKey.severity != rhsKey.severity {
            return lhsKey.severity < rhsKey.severity
        }

        if lhsKey.percentRemaining != rhsKey.percentRemaining {
            return lhsKey.percentRemaining < rhsKey.percentRemaining
        }

        if lhsKey.remaining != rhsKey.remaining {
            return lhsKey.remaining < rhsKey.remaining
        }

        let lhsProviderIndex = Provider.visibleCases.firstIndex(of: lhs.provider) ?? Int.max
        let rhsProviderIndex = Provider.visibleCases.firstIndex(of: rhs.provider) ?? Int.max
        if lhsProviderIndex != rhsProviderIndex {
            return lhsProviderIndex < rhsProviderIndex
        }

        return lhs.key.name.localizedStandardCompare(rhs.key.name) == .orderedAscending
    }

    private var priorityKey: (severity: Int, percentRemaining: Double, remaining: Int) {
        let severity: Int
        if key.isCredentialExpired {
            severity = 0
        } else if key.isUsageLimitExceeded {
            severity = 1
        } else if key.isExhausted {
            severity = 2
        } else if key.status == .failed {
            severity = 3
        } else if key.quotaPresentation.percentRemaining != nil {
            severity = 4
        } else if key.isUsableWithUnknownQuota {
            severity = 5
        } else if key.isUnlimitedQuota {
            severity = 7
        } else {
            severity = 6
        }

        let percent = key.quotaPresentation.percentRemaining ?? Double.greatestFiniteMagnitude
        let remaining = key.remaining ?? Int.max
        return (severity, percent, remaining)
    }
}

// MARK: - API Key Model

struct APIKey: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var key: String
    var provider: Provider
    var isActive: Bool = true
    var note: String? = nil

    // Quota 信息
    var remaining: Int?
    var limit: Int?
    var resetAt: Date?
    var planEndsAt: Date?
    var lastUpdated: Date?
    var lastHTTPStatus: Int?
    var lastDiagnosticMessage: String?
    var lastDiagnosticText: LocalizedTextDescriptor?
    var quotaText: LocalizedTextDescriptor?
    var quotaLabel: String?

    // 使用量统计（本地记录）
    var usageCount: Int = 0
    var lastUsed: Date?

    var usagePercentage: Double {
        guard !isUnlimitedQuota else { return 0 }
        guard let remaining = remaining, let limit = limit, limit > 0 else { return 0 }
        return Double(limit - remaining) / Double(limit)
    }

    var isLow: Bool {
        guard !isUnlimitedQuota else { return false }
        guard !isUsableWithUnknownQuota else { return false }
        guard !isUsageLimitExceeded else { return false }
        guard let remaining = remaining else { return false }
        return remaining < 100
    }

    var isExhausted: Bool {
        guard !isUnlimitedQuota else { return false }
        if isUsageLimitExceeded { return true }
        guard !isUsableWithUnknownQuota else { return false }
        guard let remaining = remaining else { return false }
        return remaining <= 0
    }

    var isUnlimitedQuota: Bool {
        guard provider == .anysearch else { return false }
        if remaining == Int.max || limit == Int.max {
            return true
        }
        return quotaText?.key == .unlimited || quotaLabel?.localizedCaseInsensitiveContains("unlimited") == true
    }

    var isCredentialExpired: Bool {
        if quotaText?.key == .credentialExpired {
            return true
        }
        guard let quotaLabel else { return false }
        return L10n.localizedValues(for: .credentialExpired).contains(quotaLabel.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var isUsableWithUnknownQuota: Bool {
        if quotaText?.key == .usableUnknownQuota || quotaLabel == "Search OK · monthly quota not exposed" {
            return true
        }
        if provider == .brave,
           lastHTTPStatus == 200,
           remaining == Int.max,
           limit == Int.max {
            return true
        }
        return provider == .exa
            && quotaLabel?.range(of: #"^[A-Z]{3} [0-9]+(?:\.[0-9]+)? used$"#, options: .regularExpression) != nil
    }

    var isUsageLimitExceeded: Bool {
        if lastHTTPStatus == 402 {
            return true
        }
        return quotaText?.key == .usageLimitExceeded
            || quotaLabel.map { L10n.localizedValues(for: .usageLimitExceeded).contains($0.trimmingCharacters(in: .whitespacesAndNewlines)) } == true
    }

    var isNoSubscribedPlan: Bool {
        if quotaText?.key == .noSubscribedPlan {
            return true
        }
        guard let quotaLabel else { return false }
        return L10n.localizedValues(for: .noSubscribedPlan).contains(quotaLabel.trimmingCharacters(in: .whitespacesAndNewlines))
            || quotaLabel == "No subscription found"
    }

    var managementDisplayName: String {
        if isBusinessInvocationCredential {
            return L10n.t(.businessInvocationKey)
        }

        if isStoredAPIKeyOnlyCredential {
            return L10n.t(.apiKey)
        }

        if isQuotaMonitoringAuthorizationCredential {
            return L10n.t(.quotaMonitoringAuthorization)
        }

        if usesGeneratedCredentialName {
            return credentialKindDisplayName
        }

        return name
    }

    var managementCredentialValueText: String {
        if isBusinessInvocationCredential {
            return maskedKey
        }

        if isStoredAPIKeyOnlyCredential {
            return maskedKey
        }

        if isQuotaMonitoringAuthorizationCredential {
            return L10n.t(.dashboardSession)
        }

        switch provider.capability.credentialKind {
        case .apiKey:
            return maskedKey
        case .dashboardCookie:
            return maskedKey
        case .adminCredential:
            return L10n.t(.adminCredential)
        }
    }

    var credentialKindDisplayName: String {
        switch provider.capability.credentialKind {
        case .apiKey:
            return L10n.t(.apiKey)
        case .dashboardCookie:
            return L10n.t(.dashboardSession)
        case .adminCredential:
            return L10n.t(.adminCredential)
        }
    }

    var managementCredentialTypeBadgeText: String? {
        guard !isBusinessInvocationCredential else { return nil }
        guard !isStoredAPIKeyOnlyCredential else { return nil }
        guard !isQuotaMonitoringAuthorizationCredential else { return nil }
        let typeName = credentialKindDisplayName
        return managementDisplayName == typeName ? nil : typeName
    }

    var displayNote: String? {
        guard let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let localizedNote = L10n.localizedCredentialNote(note)
        if isBusinessInvocationCredential,
           (localizedNote == L10n.t(.businessInvocationKeyUnsupportedDiagnostic)
            || localizedNote == L10n.t(.businessInvocationKeyQuotaInstruction)
            || localizedNote == L10n.t(.businessInvocationKeySaved)) {
            return nil
        }
        return localizedNote
    }

    private var usesGeneratedCredentialName: Bool {
        let normalizedName = normalizedCredentialName(name)
        let normalizedDefaultName = normalizedCredentialName(provider.defaultCredentialName)
        if normalizedName == normalizedDefaultName {
            return true
        }

        switch provider.capability.credentialKind {
        case .apiKey:
            return normalizedName.contains("API_KEY")
        case .dashboardCookie:
            if provider.supportsCompanionAPIKeyStorage,
               normalizedName == normalizedCredentialName(provider.copyableAPIKeyCredentialName) {
                return true
            }
            return normalizedName.contains("COOKIE") || normalizedName.contains("SESSION")
        case .adminCredential:
            return normalizedName.contains("CREDENTIAL") || normalizedName.contains("SECRET")
        }
    }

    var isStoredAPIKeyOnlyCredential: Bool {
        guard provider.supportsCompanionAPIKeyStorage else { return false }
        let normalizedName = normalizedCredentialName(name)
        if normalizedName == normalizedCredentialName(provider.copyableAPIKeyCredentialName) {
            return true
        }
        return normalizedName.contains("API_KEY")
            && !normalizedName.contains("COOKIE")
            && !normalizedName.contains("SESSION")
    }

    var isQuotaMonitoringAuthorizationCredential: Bool {
        provider.capability.credentialKind == .dashboardCookie && !isStoredAPIKeyOnlyCredential
    }

    var copyableCredentialValue: String? {
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        guard !isQuotaMonitoringAuthorizationCredential else {
            return nil
        }
        return key
    }

    var isBusinessInvocationCredential: Bool {
        guard provider == .aliyunCodingPlan || provider == .aliyunTokenPlan || provider == .tencentCloudCodingPlan else {
            return false
        }
        let normalizedName = normalizedCredentialName(name)
        if normalizedName.contains("API_KEY") {
            return true
        }
        return key.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("sk-sp-")
    }

    private func normalizedCredentialName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    var quotaDisplayText: String {
        guard isActive else { return L10n.t(.disabled) }
        if isBusinessInvocationCredential { return L10n.t(.businessInvocationKeySaved) }
        if isStoredAPIKeyOnlyCredential { return L10n.t(.apiKeySaved) }
        if isUnlimitedQuota { return L10n.t(.unlimited) }
        if isUsageLimitExceeded { return L10n.t(.usageLimitExceeded) }

        if let quotaText {
            return quotaText.render()
        }

        if let quotaLabel, !quotaLabel.isEmpty {
            return L10n.localizedQuotaLabel(quotaLabel)
        }

        if isUsableWithUnknownQuota { return L10n.t(.usableUnknownQuota) }

        if let remaining, let limit, limit > 0 {
            return "\(remaining) / \(limit)"
        }

        if let remaining {
            return "\(remaining)"
        }

        return L10n.t(.quotaUnavailable)
    }

    var quotaPresentation: QuotaPresentation {
        QuotaPresentation(
            primaryText: quotaPresentationPrimaryText,
            badgeText: remainingBadgeText,
            resetText: visibleQuotaResetSummary,
            planEndText: planEndSummary,
            percentRemaining: percentRemaining,
            dataSource: quotaDataSource,
            diagnosticText: diagnosticSummary
        )
    }

    private var quotaPresentationPrimaryText: String {
        if isUsableWithUnknownQuota {
            switch AppLanguageStore.shared.language {
            case .english:
                return "Search OK · monthly quota not exposed"
            case .simplifiedChinese:
                return "搜索可用 · 未公开月度额度"
            case .traditionalChinese:
                return "搜尋可用 · 未公開月度額度"
            case .japanese:
                return "検索利用可 · 月間クォータ非公開"
            case .korean:
                return "검색 가능 · 월간 할당량 비공개"
            }
        }
        return quotaDisplayText
    }

    private var percentRemaining: Double? {
        if provider.usesMoneyBalance {
            return nil
        }
        guard isActive,
              !isUnlimitedQuota,
              !isUsableWithUnknownQuota,
              let remaining,
              let limit,
              limit > 0,
              remaining != Int.max,
              limit != Int.max else {
            return nil
        }
        return max(0, min(1, Double(remaining) / Double(limit)))
    }

    private var quotaDataSource: QuotaDataSource {
        guard isActive else { return .unavailable }
        if isUnlimitedQuota { return .localPolicy }

        switch provider {
        case .brave:
            return .responseHeader
        case .querit, .xfyunCodingPlan, .volcengineCodingPlan, .opencodeGo, .tencentCloudCodingPlan:
            return .dashboardAPI
        case .tencentCloudTokenPlan:
            return .officialAPI
        case .tavily, .serpapi, .serper, .exa, .bocha, .wxmp, .deepseek:
            return .officialAPI
        case .anysearch:
            return .localPolicy
        case .anthropic, .claudeAPIUsage, .claudeSubscription, .codexAPIUsage, .codexSubscription, .xfyunTokenPlan, .volcengineTokenPlan, .aliyunCodingPlan, .aliyunTokenPlan:
            return .unavailable
        }
    }

    var maskedKey: String {
        guard !key.isEmpty else { return L10n.t(.noKeyValue) }
        guard key.count > 8 else { return "***" }
        return "\(key.prefix(4))••••\(key.suffix(4))"
    }

    var statusBarCredentialLabel: String {
        if isBusinessInvocationCredential { return maskedKey }
        if isStoredAPIKeyOnlyCredential { return maskedKey }
        return provider.capability.credentialKind == .dashboardCookie ? L10n.t(.dashboardSession) : maskedKey
    }

    var needsStatusBarAttention: Bool {
        guard isActive, !key.isEmpty else { return false }
        guard !isStoredAPIKeyOnlyCredential else { return false }
        return isCredentialExpired || isUsageLimitExceeded || isExhausted || isLow || status == .failed
    }

    var resetSummary: String {
        quotaResetSummary
    }

    var quotaResetSummary: String {
        guard isActive else { return L10n.t(.disabled) }

        if let resetAt {
            return L10n.format(.resetDate, L10n.shortDateTime(resetAt))
        }

        switch provider {
        case .tavily:
            return L10n.t(.resetsMonthlyDay1)
        case .deepseek, .wxmp, .bocha, .anysearch:
            return L10n.t(.noResetCycle)
        case .brave, .serpapi, .serper, .exa, .querit, .anthropic, .claudeAPIUsage, .claudeSubscription, .codexAPIUsage, .codexSubscription, .xfyunCodingPlan, .xfyunTokenPlan, .volcengineCodingPlan, .volcengineTokenPlan, .opencodeGo, .aliyunCodingPlan, .aliyunTokenPlan, .tencentCloudCodingPlan, .tencentCloudTokenPlan:
            return L10n.t(.resetNotExposed)
        }
    }

    var visibleQuotaResetSummary: String {
        guard isActive else { return "" }
        if provider == .codexSubscription, !quotaWindowDetails.isEmpty {
            return ""
        }
        if derivesPlanEndFromMonthlyQuotaReset,
           let resetAt,
           let monthlyResetAt = monthlyQuotaWindowResetAt,
           abs(resetAt.timeIntervalSince(monthlyResetAt)) < 1 {
            return ""
        }
        if resetAt != nil { return quotaResetSummary }

        switch provider {
        case .tavily, .deepseek, .wxmp, .bocha, .anysearch:
            return quotaResetSummary
        case .brave, .serpapi, .serper, .exa, .querit, .anthropic, .claudeAPIUsage, .claudeSubscription, .codexAPIUsage, .codexSubscription, .xfyunCodingPlan, .xfyunTokenPlan, .volcengineCodingPlan, .volcengineTokenPlan, .opencodeGo, .aliyunCodingPlan, .aliyunTokenPlan, .tencentCloudCodingPlan, .tencentCloudTokenPlan:
            return ""
        }
    }

    var quotaWindowDetails: [QuotaWindowText] {
        guard isActive, quotaText?.kind == .quotaWindows else { return [] }
        return quotaText?.quotaWindows ?? []
    }

    var planEndSummary: String {
        guard isActive, let visiblePlanEndsAt else { return "" }
        return L10n.format(.planEndsDate, L10n.shortDateTime(visiblePlanEndsAt))
    }

    var visiblePlanEndsAt: Date? {
        planEndsAt ?? derivedPlanEndFromMonthlyQuotaReset
    }

    private var derivedPlanEndFromMonthlyQuotaReset: Date? {
        guard derivesPlanEndFromMonthlyQuotaReset else { return nil }
        return monthlyQuotaWindowResetAt
    }

    private var derivesPlanEndFromMonthlyQuotaReset: Bool {
        provider == .volcengineCodingPlan || provider == .opencodeGo
    }

    private var monthlyQuotaWindowResetAt: Date? {
        quotaWindowDetails.first { window in
            let normalizedName = window.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return normalizedName == "month" || normalizedName == "monthly"
        }?.resetAt
    }

    var remainingBadgeText: String {
        guard isActive else { return L10n.t(.off) }

        if isCredentialExpired {
            return L10n.t(.expired)
        }

        if isUsageLimitExceeded {
            return L10n.t(.zeroRemainingBadge)
        }

        if isUsableWithUnknownQuota {
            return L10n.t(.ok)
        }

        if isUnlimitedQuota {
            return "∞"
        }

        if isNoSubscribedPlan {
            return "N/A"
        }

        if provider.usesMoneyBalance, let remaining {
            return Self.formatCNYCents(remaining)
        }

        guard let remaining else { return L10n.t(.notAvailableShort) }

        if let limit, limit > 0 {
            guard remaining > 0 else { return L10n.t(.zeroRemainingBadge) }
            let percentage = Double(remaining) / Double(limit) * 100
            if percentage < 1 {
                return "<1%"
            }
            return "\(Int(percentage))%"
        }

        return remaining <= 0 ? L10n.t(.zeroRemainingBadge) : "\(remaining)"
    }

    static func formatCNYCents(_ cents: Int) -> String {
        let amount = Decimal(max(0, cents)) / Decimal(100)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.minimumIntegerDigits = 1
        let value = formatter.string(from: NSDecimalNumber(decimal: amount))
            ?? NSDecimalNumber(decimal: amount).stringValue
        return "¥\(value)"
    }

    private var currentQuotaSortValue: Int {
        guard isActive, let remaining else { return Int.min }
        if isUnlimitedQuota { return Int.max }
        if isUsableWithUnknownQuota { return 1 }
        if isUsageLimitExceeded { return -1 }
        return remaining
    }

    static func sortedByCurrentQuota(_ keys: [APIKey]) -> [APIKey] {
        keys.sorted { lhs, rhs in
            if lhs.currentQuotaSortValue != rhs.currentQuotaSortValue {
                return lhs.currentQuotaSortValue > rhs.currentQuotaSortValue
            }

            let lhsLimit = lhs.limit ?? Int.min
            let rhsLimit = rhs.limit ?? Int.min
            if lhsLimit != rhsLimit {
                return lhsLimit > rhsLimit
            }

            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    var status: KeyStatus {
        guard isActive else { return .disabled }
        if isStoredAPIKeyOnlyCredential { return .unknown }
        if isCredentialExpired { return .expired }
        if isExhausted { return .exhausted }
        if isUsableWithUnknownQuota { return .usableUnknown }
        if isLow { return .low }
        if isBusinessInvocationCredential || isUnsupportedQuotaCheckState { return .unknown }
        if remaining != nil || lastHTTPStatus == 200 { return .healthy }
        if lastHTTPStatus != nil || lastDiagnosticMessage != nil { return .failed }
        return .unknown
    }

    var healthDisplayText: String {
        if isBusinessInvocationCredential {
            return L10n.t(.businessInvocationKeySaved)
        }
        if isStoredAPIKeyOnlyCredential {
            return L10n.t(.apiKeySaved)
        }
        if isUnsupportedQuotaCheckState {
            return quotaDisplayText
        }

        switch status {
        case .healthy:
            return L10n.t(.healthHealthy)
        case .low:
            return L10n.t(.healthLow)
        case .exhausted:
            return isUsageLimitExceeded ? L10n.t(.usageLimitExceeded) : L10n.t(.healthExhausted)
        case .expired:
            return L10n.t(.expired)
        case .usableUnknown:
            return L10n.t(.usableUnknownQuota)
        case .failed:
            return L10n.t(.healthFailed)
        case .disabled:
            return L10n.t(.disabled)
        case .unknown:
            return L10n.t(.healthUnknown)
        }
    }

    var diagnosticSummary: String {
        if isBusinessInvocationCredential {
            return L10n.t(.businessInvocationKeyQuotaInstruction)
        }
        if isStoredAPIKeyOnlyCredential {
            return L10n.t(.apiKeyStoredForCopyOnly)
        }
        if isUsageLimitExceeded {
            return L10n.t(.usageLimitExceeded)
        }
        if isUsableWithUnknownQuota {
            if let lastDiagnosticText {
                return lastDiagnosticText.render()
            }
            if let lastDiagnosticMessage, !lastDiagnosticMessage.isEmpty {
                return L10n.localizedQuotaLabel(lastDiagnosticMessage)
            }
            return provider == .brave ? L10n.t(.braveQuotaUnknownDiagnostic) : L10n.t(.usableUnknownQuota)
        }
        if let lastDiagnosticText {
            return lastDiagnosticText.render()
        }
        if let lastDiagnosticMessage, !lastDiagnosticMessage.isEmpty {
            return L10n.localizedQuotaLabel(lastDiagnosticMessage)
        }
        if let quotaText {
            return quotaText.render()
        }
        if let quotaLabel, !quotaLabel.isEmpty {
            return L10n.localizedQuotaLabel(quotaLabel)
        }
        return L10n.t(.notChecked)
    }

    private var isUnsupportedQuotaCheckState: Bool {
        guard !provider.supportsQuotaQuery,
              lastHTTPStatus == nil,
              lastDiagnosticMessage != nil || quotaLabel != nil else {
            return false
        }
        return true
    }
}

enum KeyStatus: String {
    case healthy = "正常"
    case low = "不足"
    case exhausted = "耗尽"
    case expired = "过期"
    case usableUnknown = "可用但额度未知"
    case failed = "异常"
    case disabled = "停用"
    case unknown = "未知"

    var color: Color {
        switch self {
        case .healthy: return .green
        case .low: return .orange
        case .exhausted: return .red
        case .expired: return .orange
        case .usableUnknown: return .blue
        case .failed: return .red
        case .disabled: return .gray
        case .unknown: return .gray
        }
    }
}

// MARK: - Provider Stats

struct ProviderStats: Identifiable {
    let provider: Provider
    let keys: [APIKey]

    var id: String { provider.id }

    var sortedKeysByCurrentQuota: [APIKey] {
        APIKey.sortedByCurrentQuota(keys)
    }

    var sortedMonitoringKeysByCurrentQuota: [APIKey] {
        APIKey.sortedByCurrentQuota(monitoredKeys)
    }

    var credentialDiagnosticItems: [CredentialDiagnosticItem] {
        sortedKeysByCurrentQuota.map { key in
            CredentialDiagnosticItem(
                key: key,
                statusKey: key.isStoredAPIKeyOnlyCredential
                    ? primaryMonitoringKey ?? key
                    : key
            )
        }
    }

    var totalRemaining: Int {
        finiteQuotaKeys.compactMap { $0.remaining }.reduce(0, +)
    }

    var hasKnownQuota: Bool {
        monitoredKeys.contains { $0.isActive && $0.remaining != nil }
    }

    var hasUnlimitedQuota: Bool {
        monitoredKeys.contains { $0.isUnlimitedQuota }
    }

    var totalLimit: Int {
        finiteQuotaKeys.compactMap { $0.limit }.reduce(0, +)
    }

    var totalRemainingDisplayText: String {
        if hasUnlimitedQuota { return L10n.t(.unlimited) }
        if provider.usesMoneyBalance {
            return APIKey.formatCNYCents(totalRemaining)
        }
        if usesPercentageQuota {
            return tightestQuotaWindowDisplay ?? formatProviderPercent(totalRemainingPercent)
        }
        return "\(totalRemaining)"
    }

    var totalLimitDisplayText: String {
        if hasUnlimitedQuota { return L10n.t(.unlimited) }
        if provider.usesMoneyBalance {
            return L10n.t(.noResetCycle)
        }
        if usesPercentageQuota {
            return monthlyQuotaWindowDisplay
                ?? longestQuotaWindowDisplay
                ?? L10n.quotaWindowDisplay("month", formatProviderPercent(totalRemainingPercent))
        }
        return "\(totalLimit)"
    }

    var overallUsage: Double {
        guard totalLimit > 0 else { return 0 }
        return Double(totalLimit - totalRemaining) / Double(totalLimit)
    }

    var availableKeys: Int {
        keys.filter { !$0.isExhausted }.count
    }

    var headerSubtitle: String {
        guard !keys.isEmpty else { return L10n.t(.noKeyConfigured) }
        return "\(L10n.format(.providerKeyCount, keys.count)) · \(L10n.format(.activeCount, availableKeys))"
    }

    var statusBarProviderQuotaText: String {
        guard !activeCredentialKeys.isEmpty else { return L10n.t(.noKeyConfigured) }
        if activeCredentialKeys.contains(where: { $0.isUnlimitedQuota }) {
            return L10n.t(.unlimited)
        }
        if usesPercentageQuota {
            if let allQuotaWindowsDisplay {
                return allQuotaWindowsDisplay
            }
            if hasActiveKnownFiniteQuota {
                return totalRemainingDisplayText
            }
            return activeCredentialKeys.first?.quotaPresentation.primaryText ?? L10n.t(.quotaUnavailable)
        }
        if provider.usesMoneyBalance {
            return totalRemainingDisplayText
        }
        if activeCredentialKeys.count == 1, let key = activeCredentialKeys.first {
            return key.quotaPresentation.primaryText
        }
        if activeFiniteQuotaKeys.reduce(0, { $0 + ($1.limit ?? 0) }) > 0 {
            let remaining = activeFiniteQuotaKeys.compactMap { $0.remaining }.reduce(0, +)
            let limit = activeFiniteQuotaKeys.compactMap { $0.limit }.reduce(0, +)
            return "\(remaining) / \(limit)"
        }
        if let firstKnown = sortedKeysByCurrentQuota.first(where: { $0.isActive && !$0.key.isEmpty }) {
            return firstKnown.quotaPresentation.primaryText
        }
        return L10n.t(.quotaUnavailable)
    }

    var statusBarProviderBadgeText: String {
        guard !activeCredentialKeys.isEmpty else { return L10n.t(.notAvailableShort) }
        if activeCredentialKeys.contains(where: { $0.isUnlimitedQuota }) {
            return "∞"
        }
        if usesPercentageQuota {
            guard monthlyQuotaWindowDisplay != nil || hasActiveKnownFiniteQuota else {
                return activeCredentialKeys.first?.remainingBadgeText ?? L10n.t(.notAvailableShort)
            }
            return tightestQuotaWindowDisplay ?? totalRemainingDisplayText
        }
        if provider.usesMoneyBalance {
            return totalRemainingDisplayText
        }
        if let percent = statusBarProviderPercentRemaining {
            if percent <= 0 {
                return L10n.t(.zeroRemainingBadge)
            }
            if percent < 1 {
                return "<1%"
            }
            return "\(Int(percent.rounded(.down)))%"
        }
        if activeCredentialKeys.allSatisfy({ $0.isExhausted || $0.isUsageLimitExceeded }) {
            return L10n.t(.zeroRemainingBadge)
        }
        if activeCredentialKeys.contains(where: { $0.isUsableWithUnknownQuota }) {
            return L10n.t(.ok)
        }
        return L10n.t(.notAvailableShort)
    }

    var statusBarProviderStatusColor: Color {
        guard !activeCredentialKeys.isEmpty else { return .gray }
        if activeCredentialKeys.allSatisfy({ $0.status == .failed || $0.isCredentialExpired || $0.isExhausted }) {
            return .red
        }
        if activeCredentialKeys.contains(where: { $0.isLow || $0.isExhausted || $0.isCredentialExpired || $0.status == .failed }) {
            return .orange
        }
        if activeCredentialKeys.contains(where: { $0.isUsableWithUnknownQuota }) {
            return .blue
        }
        return .green
    }

    private var usesPercentageQuota: Bool {
        switch provider {
        case .xfyunCodingPlan, .volcengineCodingPlan, .opencodeGo, .tencentCloudCodingPlan, .tencentCloudTokenPlan, .codexSubscription:
            return true
        case .tavily, .brave, .serpapi, .serper, .exa, .bocha, .anysearch, .wxmp, .querit, .anthropic, .claudeAPIUsage, .claudeSubscription, .codexAPIUsage, .deepseek, .xfyunTokenPlan, .volcengineTokenPlan, .aliyunCodingPlan, .aliyunTokenPlan:
            return false
        }
    }

    private var totalRemainingPercent: Double {
        let percentageKeys = finiteQuotaKeys.filter { ($0.limit ?? 0) > 0 && $0.remaining != nil }
        guard !percentageKeys.isEmpty else { return 0 }

        let percentages = percentageKeys.map { key -> Double in
            let remaining = Double(key.remaining ?? 0)
            let limit = Double(key.limit ?? 1)
            return max(0, min(100, remaining / limit * 100))
        }
        return percentages.reduce(0, +) / Double(percentages.count)
    }

    private var percentageQuotaWindows: [(name: String, percent: Double)] {
        finiteQuotaKeys
            .flatMap { key -> [(name: String, percent: Double)] in
                if key.quotaText?.kind == .quotaWindows {
                    return key.quotaText?.quotaWindows.compactMap { window in
                        Self.parsePercentWindow(name: window.name, percentText: window.percentText)
                    } ?? []
                }
                return key.quotaLabel
                    .map(Self.parsePercentWindows)
                    ?? []
            }
    }

    private static func parsePercentWindows(_ label: String) -> [(name: String, percent: Double)] {
        label
            .components(separatedBy: " · ")
            .compactMap { part in
                let pieces = part.split(separator: " ", maxSplits: 1).map(String.init)
                guard pieces.count == 2 else { return nil }
                return parsePercentWindow(name: pieces[0], percentText: pieces[1])
            }
    }

    private static func parsePercentWindow(name: String, percentText: String) -> (name: String, percent: Double)? {
        let normalizedPercent = percentText.trimmingCharacters(in: CharacterSet(charactersIn: "%"))
        guard let percent = Double(normalizedPercent) else { return nil }
        return (name: name, percent: max(0, min(100, percent)))
    }

    private var monthlyQuotaWindowDisplay: String? {
        percentageQuotaWindows
            .filter { $0.name == "month" }
            .min { lhs, rhs in lhs.percent < rhs.percent }
            .map { L10n.quotaWindowDisplay($0.name, formatProviderPercent($0.percent)) }
    }

    private var longestQuotaWindowDisplay: String? {
        let grouped = Dictionary(grouping: percentageQuotaWindows) { $0.name }
        for name in ["week", "5h"] {
            if let window = grouped[name]?.min(by: { lhs, rhs in lhs.percent < rhs.percent }) {
                return L10n.quotaWindowDisplay(window.name, formatProviderPercent(window.percent))
            }
        }
        return nil
    }

    private var allQuotaWindowsDisplay: String? {
        let orderedWindows = orderedBestQuotaWindows
        guard !orderedWindows.isEmpty else { return nil }
        return orderedWindows
            .map { L10n.quotaWindowDisplay($0.name, formatProviderPercent($0.percent)) }
            .joined(separator: " · ")
    }

    private var tightestQuotaWindowDisplay: String? {
        percentageQuotaWindows
            .min { lhs, rhs in lhs.percent < rhs.percent }
            .map { L10n.quotaWindowDisplay($0.name, formatProviderPercent($0.percent)) }
    }

    private var orderedBestQuotaWindows: [(name: String, percent: Double)] {
        let grouped = Dictionary(grouping: percentageQuotaWindows) { $0.name }
        let order = ["5h", "week", "month"]
        return order.compactMap { name in
            grouped[name]?.min { lhs, rhs in lhs.percent < rhs.percent }
        }
    }

    private func formatProviderPercent(_ value: Double) -> String {
        let clamped = max(0, min(100, value))
        if abs(clamped.rounded() - clamped) < 0.05 {
            return "\(Int(clamped.rounded()))%"
        }
        return String(format: "%.1f%%", clamped)
    }

    private var finiteQuotaKeys: [APIKey] {
        monitoredKeys.filter {
            !$0.isUnlimitedQuota &&
            $0.remaining != Int.max &&
            $0.limit != Int.max
        }
    }

    private var activeCredentialKeys: [APIKey] {
        monitoredKeys.filter { $0.isActive && !$0.key.isEmpty }
    }

    private var monitoredKeys: [APIKey] {
        keys.filter { !$0.isStoredAPIKeyOnlyCredential }
    }

    private var primaryMonitoringKey: APIKey? {
        sortedMonitoringKeysByCurrentQuota.first
    }

    private var activeFiniteQuotaKeys: [APIKey] {
        activeCredentialKeys.filter {
            !$0.isUnlimitedQuota &&
            $0.remaining != Int.max &&
            $0.limit != Int.max
        }
    }

    private var hasActiveKnownFiniteQuota: Bool {
        activeFiniteQuotaKeys.contains { key in
            key.remaining != nil && (key.limit ?? 0) > 0
        }
    }

    private var statusBarProviderPercentRemaining: Double? {
        let quotaKeys = activeFiniteQuotaKeys.filter { ($0.limit ?? 0) > 0 && $0.remaining != nil }
        let totalLimit = quotaKeys.compactMap { $0.limit }.reduce(0, +)
        guard totalLimit > 0 else { return nil }
        let totalRemaining = quotaKeys.compactMap { $0.remaining }.reduce(0, +)
        return max(0, min(100, Double(totalRemaining) / Double(totalLimit) * 100))
    }
}

struct CredentialDiagnosticItem: Identifiable, Equatable {
    let key: APIKey
    let statusKey: APIKey

    var id: UUID { key.id }

    var status: KeyStatus {
        statusKey.status
    }

    var healthDisplayText: String {
        statusKey.healthDisplayText
    }

    var httpStatusText: String {
        statusKey.lastHTTPStatus.map(String.init) ?? L10n.t(.httpNotRequested)
    }

    var diagnosticSummary: String {
        statusKey.diagnosticSummary
    }
}

struct ProviderCategoryStats: Identifiable {
    let title: String
    let stats: [ProviderStats]

    var id: String { title }

    var providerCount: Int {
        stats.count
    }

    var keyCount: Int {
        stats.map { $0.keys.count }.reduce(0, +)
    }

    var activeKeyCount: Int {
        stats.flatMap { $0.keys }.filter { $0.isActive && !$0.isExhausted }.count
    }
}
