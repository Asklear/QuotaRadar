use serde::Serialize;

#[derive(Debug, Clone, Serialize, PartialEq)]
pub enum ProviderCategory {
    #[serde(rename = "AI Search")]
    AiSearch,
    #[serde(rename = "LLM")]
    Llm,
}

#[derive(Debug, Clone, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ProviderDefinition {
    pub id: String,
    pub display_name: String,
    pub family_name: String,
    pub category: ProviderCategory,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub plan_type: Option<String>,
    pub icon: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub dashboard_url: Option<String>,
    pub supports_reauth: bool,
    pub supports_refresh: bool,
    pub quota_check_consumes_search_quota: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub hidden: Option<bool>,
}

impl ProviderDefinition {
    pub fn new_ai_search(
        id: &str,
        display_name: &str,
        family_name: &str,
        icon: &str,
        dashboard_url: &str,
        quota_check_consumes_search_quota: bool,
    ) -> Self {
        Self {
            id: id.to_string(),
            display_name: display_name.to_string(),
            family_name: family_name.to_string(),
            category: ProviderCategory::AiSearch,
            plan_type: None,
            icon: icon.to_string(),
            dashboard_url: Some(dashboard_url.to_string()),
            supports_reauth: false,
            supports_refresh: true,
            quota_check_consumes_search_quota,
            hidden: None,
        }
    }

    pub fn new_llm(
        id: &str,
        display_name: &str,
        family_name: &str,
        plan_type: &str,
        icon: &str,
        dashboard_url: &str,
    ) -> Self {
        Self {
            id: id.to_string(),
            display_name: display_name.to_string(),
            family_name: family_name.to_string(),
            category: ProviderCategory::Llm,
            plan_type: Some(plan_type.to_string()),
            icon: icon.to_string(),
            dashboard_url: Some(dashboard_url.to_string()),
            supports_reauth: true,
            supports_refresh: true,
            quota_check_consumes_search_quota: false,
            hidden: None,
        }
    }
}
