use serde::Deserialize;

use crate::domain::QuotaWindow;

use super::{ProviderClient, ProviderCredential, ProviderError, QuotaSnapshot};

const SERPAPI_USAGE_FIXTURE: &str = r#"{
  "account": {
    "total_searches_left": 4100,
    "monthly_searches_limit": 5000,
    "reset_at": "2026-07-01T00:00:00+08:00"
  }
}"#;

const SERPAPI_UNAUTHORIZED_FIXTURE: &str = r#"{
  "error": "Invalid API key"
}"#;

const SERPAPI_QUOTA_UNAVAILABLE_FIXTURE: &str = r#"{
  "account": {
    "plan": "free"
  }
}"#;

#[derive(Debug, Default)]
pub struct SerpApiProvider;

impl SerpApiProvider {
    pub fn check_unauthorized_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, 401, SERPAPI_UNAUTHORIZED_FIXTURE)
    }

    pub fn check_quota_unavailable_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, 200, SERPAPI_QUOTA_UNAVAILABLE_FIXTURE)
    }

    pub fn map_network_error(message: &str) -> ProviderError {
        ProviderError::Network(message.to_string())
    }

    fn check_response_fixture(
        &self,
        credential: ProviderCredential,
        http_status: u16,
        value: &str,
    ) -> Result<QuotaSnapshot, ProviderError> {
        if credential.provider_id != self.provider_id() {
            return Err(ProviderError::Unsupported(format!(
                "credential belongs to {}",
                credential.provider_id
            )));
        }

        parse_serpapi_usage(http_status, value)
    }
}

impl ProviderClient for SerpApiProvider {
    fn provider_id(&self) -> &'static str {
        "serpapi"
    }

    fn consumes_quota_on_check(&self) -> bool {
        false
    }

    fn check_fixture_quota(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, 200, SERPAPI_USAGE_FIXTURE)
    }
}

#[derive(Debug, Deserialize)]
struct SerpApiResponseFixture {
    error: Option<String>,
    account: Option<SerpApiAccount>,
}

#[derive(Debug, Deserialize)]
struct SerpApiAccount {
    total_searches_left: Option<f64>,
    monthly_searches_limit: Option<f64>,
    reset_at: Option<String>,
}

fn parse_serpapi_usage(http_status: u16, value: &str) -> Result<QuotaSnapshot, ProviderError> {
    let response: SerpApiResponseFixture =
        serde_json::from_str(value).map_err(|error| ProviderError::Parse(error.to_string()))?;

    if http_status == 401 {
        return Err(ProviderError::Unauthorized(
            response.error.unwrap_or_else(|| "Invalid API key".to_string()),
        ));
    }

    let account = response.account.ok_or_else(|| {
        ProviderError::QuotaUnavailable("SerpAPI monthly searches are unavailable".to_string())
    })?;
    let remaining = account.total_searches_left.ok_or_else(|| {
        ProviderError::QuotaUnavailable("SerpAPI monthly searches are unavailable".to_string())
    })?;
    let limit = account.monthly_searches_limit.ok_or_else(|| {
        ProviderError::QuotaUnavailable("SerpAPI monthly searches are unavailable".to_string())
    })?;
    let reset_at = account
        .reset_at
        .unwrap_or_else(|| "2026-07-01T00:00:00+08:00".to_string());
    let percent = if limit > 0.0 {
        remaining / limit * 100.0
    } else {
        0.0
    };

    Ok(QuotaSnapshot {
        provider_id: "serpapi".to_string(),
        remaining: Some(remaining),
        limit: Some(limit),
        remaining_badge_text: format!("{} / {}", remaining.round() as i64, limit.round() as i64),
        quota_label: Some("searches".to_string()),
        quota_windows: vec![QuotaWindow::percent("month", percent, &reset_at)],
        reset_at: Some(reset_at),
        plan_ends_at: None,
    })
}
