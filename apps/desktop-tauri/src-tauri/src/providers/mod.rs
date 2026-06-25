pub mod aliyun_coding_plan;
pub mod anthropic_credits;
pub mod anysearch;
pub mod bocha;
pub mod brave;
pub mod claude_subscription;
pub mod codex_subscription;
pub mod deepseek;
pub mod exa;
pub mod http;
pub mod kimi_subscription;
pub mod opencode_go;
pub mod querit;
pub mod registry;
pub mod serpapi;
pub mod serper;
pub mod tavily;
pub mod tencent_cloud_coding_plan;
pub mod volcengine_coding_plan;
pub mod wxmp;
pub mod xfyun_coding_plan;

use crate::domain::QuotaWindow;

pub use http::{
    ProviderHttpRequest, ProviderHttpResponse, ProviderTransport, ReqwestProviderTransport,
};

#[cfg(test)]
mod aliyun_coding_plan_tests;
#[cfg(test)]
mod anthropic_credits_tests;
#[cfg(test)]
mod anysearch_tests;
#[cfg(test)]
mod bocha_tests;
#[cfg(test)]
mod brave_tests;
#[cfg(test)]
mod claude_subscription_tests;
#[cfg(test)]
mod codex_subscription_tests;
#[cfg(test)]
mod exa_tests;
#[cfg(test)]
mod kimi_subscription_tests;
#[cfg(test)]
mod opencode_go_tests;
#[cfg(test)]
mod querit_tests;
#[cfg(test)]
mod serpapi_tests;
#[cfg(test)]
mod serper_tests;
#[cfg(test)]
mod tencent_cloud_coding_plan_tests;
#[cfg(test)]
mod tests;
#[cfg(test)]
mod volcengine_coding_plan_tests;
#[cfg(test)]
mod wxmp_tests;
#[cfg(test)]
mod xfyun_coding_plan_tests;

#[derive(Debug, Clone, PartialEq)]
pub struct ProviderCredential {
    pub provider_id: String,
    pub secret: String,
}

impl ProviderCredential {
    pub fn fake_api_key(provider_id: &str, secret: &str) -> Self {
        Self {
            provider_id: provider_id.to_string(),
            secret: secret.to_string(),
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct QuotaSnapshot {
    pub provider_id: String,
    pub remaining: Option<f64>,
    pub limit: Option<f64>,
    pub remaining_badge_text: String,
    pub quota_label: Option<String>,
    pub quota_windows: Vec<QuotaWindow>,
    pub reset_at: Option<String>,
    pub plan_ends_at: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub enum ProviderError {
    Parse(String),
    Unsupported(String),
    Unauthorized(String),
    QuotaUnavailable(String),
    NoSubscribedPlan(String),
    Network(String),
}

impl std::fmt::Display for ProviderError {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Parse(message) => write!(formatter, "Provider fixture parse failed: {message}"),
            Self::Unsupported(message) => write!(formatter, "Provider unsupported: {message}"),
            Self::Unauthorized(message) => {
                write!(formatter, "Provider authorization failed: {message}")
            }
            Self::QuotaUnavailable(message) => {
                write!(formatter, "Provider quota unavailable: {message}")
            }
            Self::NoSubscribedPlan(message) => {
                write!(formatter, "Provider has no subscribed plan: {message}")
            }
            Self::Network(message) => write!(formatter, "Provider network failed: {message}"),
        }
    }
}

impl std::error::Error for ProviderError {}

pub trait ProviderClient: Send + Sync {
    fn provider_id(&self) -> &'static str;
    fn consumes_quota_on_check(&self) -> bool;
    fn check_quota(
        &self,
        credential: ProviderCredential,
        transport: &dyn ProviderTransport,
    ) -> Result<QuotaSnapshot, ProviderError> {
        let _ = transport;
        self.check_fixture_quota(credential)
    }
    fn check_fixture_quota(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError>;
}
