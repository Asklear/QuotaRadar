use crate::domain::ProviderDefinition;

use super::{
    aliyun_coding_plan::AliyunCodingPlanProvider, anthropic_credits::AnthropicCreditsProvider,
    anysearch::AnySearchProvider, bocha::BochaProvider, brave::BraveProvider,
    claude_subscription::ClaudeSubscriptionProvider, codex_subscription::CodexSubscriptionProvider,
    deepseek::DeepSeekProvider, exa::ExaProvider, kimi_subscription::KimiSubscriptionProvider,
    opencode_go::OpenCodeGoProvider, querit::QueritProvider, serpapi::SerpApiProvider,
    serper::SerperProvider, tavily::TavilyProvider,
    tencent_cloud_coding_plan::TencentCloudCodingPlanProvider,
    volcengine_coding_plan::VolcengineCodingPlanProvider, wxmp::WxmpProvider,
    xfyun_coding_plan::XfyunCodingPlanProvider, ProviderClient,
};

pub fn provider_clients() -> Vec<Box<dyn ProviderClient>> {
    vec![
        Box::<TavilyProvider>::default(),
        Box::<BraveProvider>::default(),
        Box::<SerpApiProvider>::default(),
        Box::<SerperProvider>::default(),
        Box::<ExaProvider>::default(),
        Box::<BochaProvider>::default(),
        Box::<AnySearchProvider>::default(),
        Box::<WxmpProvider>::default(),
        Box::<QueritProvider>::default(),
        Box::<DeepSeekProvider>::default(),
        Box::<ClaudeSubscriptionProvider>::default(),
        Box::<AnthropicCreditsProvider>::default(),
        Box::<CodexSubscriptionProvider>::default(),
        Box::<KimiSubscriptionProvider>::default(),
        Box::<OpenCodeGoProvider>::default(),
        Box::<XfyunCodingPlanProvider>::default(),
        Box::<VolcengineCodingPlanProvider>::default(),
        Box::<AliyunCodingPlanProvider>::default(),
        Box::<TencentCloudCodingPlanProvider>::default(),
    ]
}

pub fn registered_provider_ids() -> Vec<&'static str> {
    provider_clients()
        .iter()
        .map(|client| client.provider_id())
        .collect()
}

pub fn visible_provider_definitions() -> Vec<ProviderDefinition> {
    vec![
        ProviderDefinition::new_ai_search(
            "tavily",
            "Tavily",
            "Tavily",
            "tavily",
            "https://app.tavily.com/home",
            false,
        ),
        ProviderDefinition::new_ai_search(
            "brave",
            "Brave",
            "Brave",
            "brave",
            "https://api.search.brave.com/app/dashboard",
            true,
        ),
        ProviderDefinition::new_ai_search(
            "serpapi",
            "SerpAPI",
            "SerpAPI",
            "serpapi",
            "https://serpapi.com/dashboard",
            false,
        ),
        ProviderDefinition::new_ai_search(
            "serper",
            "Serper",
            "Serper",
            "serper",
            "https://serper.dev/api-key",
            false,
        ),
        ProviderDefinition::new_ai_search(
            "exa",
            "Exa",
            "Exa",
            "exa",
            "https://dashboard.exa.ai/",
            false,
        ),
        ProviderDefinition::new_ai_search(
            "bocha",
            "Bocha",
            "Bocha",
            "bocha",
            "https://open.bochaai.com/dashboard",
            false,
        ),
        ProviderDefinition::new_ai_search(
            "anysearch",
            "AnySearch",
            "AnySearch",
            "anysearch",
            "https://app.anysearch.ai/login",
            false,
        ),
        ProviderDefinition::new_ai_search(
            "wxmp",
            "WeChat Search",
            "WeChat Search",
            "wxmp",
            "https://www.dajiala.com/main/interface?actnav=1",
            false,
        ),
        ProviderDefinition {
            supports_reauth: true,
            ..ProviderDefinition::new_ai_search(
                "querit",
                "Querit",
                "Querit",
                "querit",
                "https://www.querit.ai/en/dashboard/usage",
                false,
            )
        },
        ProviderDefinition {
            supports_reauth: false,
            ..ProviderDefinition::new_llm(
                "deepseek",
                "DeepSeek",
                "DeepSeek",
                "Balance",
                "deepseek",
                "https://platform.deepseek.com/usage",
            )
        },
        ProviderDefinition::new_llm(
            "claude",
            "Claude",
            "Anthropic",
            "Subscription",
            "claude",
            "https://claude.ai/settings/usage",
        ),
        ProviderDefinition::new_llm(
            "anthropic_credits",
            "Anthropic Credits",
            "Anthropic",
            "Credits",
            "anthropic",
            "https://claude.ai/settings/billing",
        ),
        ProviderDefinition::new_llm(
            "codex",
            "Codex",
            "OpenAI",
            "Subscription",
            "codex",
            "https://chatgpt.com/codex",
        ),
        ProviderDefinition::new_llm(
            "kimi",
            "Kimi",
            "Moonshot",
            "Membership",
            "kimi",
            "https://www.kimi.com/membership/subscription?tab=quota",
        ),
        ProviderDefinition::new_llm(
            "opencode_go",
            "OpenCode Go",
            "OpenCode",
            "Subscription",
            "opencode",
            "https://opencode.ai/docs/zh-cn/go",
        ),
        ProviderDefinition::new_llm(
            "xfyun_coding_plan",
            "XFYun Spark",
            "XFYun Spark",
            "Coding Plan",
            "xfyun",
            "https://maas.xfyun.cn/packageSubscription",
        ),
        ProviderDefinition::new_llm(
            "volcengine_coding_plan",
            "Volcengine",
            "Volcengine",
            "Coding Plan",
            "volcengine",
            "https://console.volcengine.com/ark/region:ark+cn-beijing/openManagement",
        ),
        ProviderDefinition::new_llm(
            "aliyun_coding_plan",
            "Aliyun",
            "Aliyun",
            "Coding Plan",
            "aliyun",
            "https://bailian.console.aliyun.com/cn-beijing?tab=model#/efm/coding_plan",
        ),
        ProviderDefinition::new_llm(
            "tencent_cloud_coding_plan",
            "Tencent Cloud",
            "Tencent Cloud",
            "Coding Plan",
            "tencent",
            "https://console.cloud.tencent.com/tokenhub/codingplan",
        ),
    ]
}

pub fn visible_provider_ids() -> Vec<&'static str> {
    vec![
        "tavily",
        "brave",
        "serpapi",
        "serper",
        "exa",
        "bocha",
        "anysearch",
        "wxmp",
        "querit",
        "deepseek",
        "claude",
        "anthropic_credits",
        "codex",
        "kimi",
        "opencode_go",
        "xfyun_coding_plan",
        "volcengine_coding_plan",
        "aliyun_coding_plan",
        "tencent_cloud_coding_plan",
    ]
}
