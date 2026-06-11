use crate::domain::ProviderDefinition;

use super::{
    anysearch::AnySearchProvider, bocha::BochaProvider, brave::BraveProvider,
    deepseek::DeepSeekProvider, exa::ExaProvider, serpapi::SerpApiProvider,
    serper::SerperProvider, tavily::TavilyProvider, wxmp::WxmpProvider, ProviderClient,
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
        Box::<DeepSeekProvider>::default(),
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
        ProviderDefinition::new_llm(
            "deepseek",
            "DeepSeek",
            "DeepSeek",
            "Balance",
            "deepseek",
            "https://platform.deepseek.com/usage",
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
        "deepseek",
    ]
}
