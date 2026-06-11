mod credential;
mod diagnostics;
mod provider;
mod quota;
mod settings;

pub use credential::{CredentialKind, CredentialStatus, CredentialView};
pub use provider::{ProviderCategory, ProviderDefinition};
pub use quota::QuotaWindow;
use serde::Serialize;

#[cfg(test)]
mod tests;

#[derive(Debug, Clone, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct AppState {
    pub providers: Vec<ProviderDefinition>,
    pub credentials: Vec<CredentialView>,
}

impl AppState {
    pub fn mock() -> Self {
        Self {
            providers: vec![
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
                    "bocha",
                    "Bocha",
                    "Bocha",
                    "bocha",
                    "https://open.bochaai.com",
                    false,
                ),
                ProviderDefinition::new_ai_search(
                    "exa",
                    "Exa",
                    "Exa",
                    "exa",
                    "https://dashboard.exa.ai",
                    false,
                ),
                ProviderDefinition::new_llm(
                    "claude",
                    "Claude",
                    "Anthropic",
                    "Pro",
                    "claude",
                    "https://claude.ai/settings/billing",
                ),
                ProviderDefinition::new_llm(
                    "codex",
                    "Codex",
                    "OpenAI",
                    "Pro",
                    "codex",
                    "https://chatgpt.com",
                ),
                ProviderDefinition::new_llm(
                    "kimi",
                    "Kimi",
                    "Moonshot",
                    "Membership",
                    "kimi",
                    "https://www.kimi.com/membership/subscription?tab=quota",
                ),
            ],
            credentials: vec![
                CredentialView::api_key(
                    "tavily-primary",
                    "tavily",
                    "Tavily Key 1",
                    "tvly••••9Q2a",
                    CredentialStatus::Healthy,
                    "920 / 1000",
                    Some(920.0),
                    Some(1000.0),
                    vec![QuotaWindow::percent("month", 92.0, "2026-07-01T00:00:00+08:00")],
                    Some("2026-07-01T00:00:00+08:00"),
                    Some("2026-06-11T10:00:00+08:00"),
                    Some(200),
                ),
                CredentialView::api_key(
                    "brave-low",
                    "brave",
                    "Brave Key 2",
                    "BSA••••82y2",
                    CredentialStatus::Healthy,
                    "80 / 1000",
                    Some(80.0),
                    Some(1000.0),
                    vec![QuotaWindow::percent("month", 8.0, "2026-07-01T00:00:00+08:00")],
                    Some("2026-07-01T00:00:00+08:00"),
                    Some("2026-06-11T10:02:00+08:00"),
                    Some(200),
                )
                .with_note("Manual refresh only because Brave checks consume search quota."),
                CredentialView::api_key(
                    "serpapi-primary",
                    "serpapi",
                    "SerpAPI Key",
                    "serp••••4d91",
                    CredentialStatus::Healthy,
                    "4100 / 5000",
                    Some(4100.0),
                    Some(5000.0),
                    vec![QuotaWindow::percent("month", 82.0, "2026-07-01T00:00:00+08:00")],
                    Some("2026-07-01T00:00:00+08:00"),
                    Some("2026-06-11T10:03:00+08:00"),
                    Some(200),
                ),
                CredentialView::api_key(
                    "bocha-balance",
                    "bocha",
                    "Bocha Balance",
                    "bc••••7E3f",
                    CredentialStatus::Healthy,
                    "¥128.40 / ¥200.00",
                    Some(128.4),
                    Some(200.0),
                    vec![QuotaWindow::percent("month", 64.2, "2026-07-01T00:00:00+08:00")],
                    Some("2026-07-01T00:00:00+08:00"),
                    Some("2026-06-11T10:04:00+08:00"),
                    Some(200),
                )
                .with_quota_label("CNY"),
                CredentialView::web_login(
                    "claude-web-pro",
                    "claude",
                    "Claude Pro Login",
                    "Web login saved",
                    CredentialStatus::Healthy,
                    "Week 40%",
                    vec![
                        QuotaWindow::percent("5h", 72.0, "2026-06-11T15:00:00+08:00"),
                        QuotaWindow::percent("week", 40.0, "2026-06-15T00:00:00+08:00"),
                    ],
                    Some("2026-07-09T00:00:00+08:00"),
                    Some("2026-06-11T10:05:00+08:00"),
                    Some(200),
                ),
                CredentialView::stored_api_key(
                    "claude-api-key",
                    "claude",
                    "Claude API Key",
                    "ANT••••9c2A",
                    "Saved",
                    Some("claude-web-pro"),
                    Some("2026-06-11T10:05:00+08:00"),
                ),
                CredentialView::web_login(
                    "codex-web-expired",
                    "codex",
                    "Codex Pro Login",
                    "Web login expired",
                    CredentialStatus::Expired,
                    "Login expired",
                    vec![
                        QuotaWindow::percent("5h", 0.0, "2026-06-11T15:00:00+08:00"),
                        QuotaWindow::percent("week", 0.0, "2026-06-15T00:00:00+08:00"),
                    ],
                    Some("2026-07-01T00:00:00+08:00"),
                    Some("2026-06-11T09:30:00+08:00"),
                    Some(401),
                )
                .with_diagnostic_message("Web login authorization expired."),
                CredentialView::stored_api_key(
                    "codex-api-key",
                    "codex",
                    "OpenAI API Key",
                    "OPENAI••••1A9b",
                    "Saved",
                    Some("codex-web-expired"),
                    Some("2026-06-11T09:30:00+08:00"),
                ),
                CredentialView::web_login(
                    "kimi-membership",
                    "kimi",
                    "Kimi Membership",
                    "Web login saved",
                    CredentialStatus::Healthy,
                    "Month 8.4%",
                    vec![QuotaWindow::percent("month", 8.4, "2026-06-15T16:54:48+08:00")],
                    Some("2026-06-15T16:54:48+08:00"),
                    Some("2026-06-11T10:06:00+08:00"),
                    Some(200),
                ),
            ],
        }
    }
}
