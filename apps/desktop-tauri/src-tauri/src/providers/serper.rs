use serde::Deserialize;

use super::{ProviderClient, ProviderCredential, ProviderError, QuotaSnapshot};

const SERPER_USAGE_FIXTURE: &str = r#"{
  "balance": 2400,
  "rateLimit": 2500
}"#;

const SERPER_ZERO_BALANCE_FIXTURE: &str = r#"{
  "balance": 0,
  "rateLimit": 2500
}"#;

const SERPER_UNAUTHORIZED_FIXTURE: &str = r#"{
  "message": "Invalid API key"
}"#;

const SERPER_QUOTA_UNAVAILABLE_FIXTURE: &str = r#"{
  "rateLimit": 2500
}"#;

#[derive(Debug, Default)]
pub struct SerperProvider;

impl SerperProvider {
    pub fn check_zero_balance_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, 200, SERPER_ZERO_BALANCE_FIXTURE)
    }

    pub fn check_unauthorized_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, 401, SERPER_UNAUTHORIZED_FIXTURE)
    }

    pub fn check_quota_unavailable_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, 200, SERPER_QUOTA_UNAVAILABLE_FIXTURE)
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

        parse_serper_account(http_status, value)
    }
}

impl ProviderClient for SerperProvider {
    fn provider_id(&self) -> &'static str {
        "serper"
    }

    fn consumes_quota_on_check(&self) -> bool {
        false
    }

    fn check_fixture_quota(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, 200, SERPER_USAGE_FIXTURE)
    }
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct SerperAccountFixture {
    balance: Option<f64>,
    message: Option<String>,
}

fn parse_serper_account(http_status: u16, value: &str) -> Result<QuotaSnapshot, ProviderError> {
    let response: SerperAccountFixture =
        serde_json::from_str(value).map_err(|error| ProviderError::Parse(error.to_string()))?;

    if http_status == 401 || http_status == 403 {
        return Err(ProviderError::Unauthorized(
            response
                .message
                .unwrap_or_else(|| "Invalid API key".to_string()),
        ));
    }

    let balance = response.balance.ok_or_else(|| {
        ProviderError::QuotaUnavailable("Serper credits are unavailable".to_string())
    })?;
    let remaining = balance.max(0.0);
    let remaining_badge_text = if balance > 0.0 {
        format!("{} credits", balance.round() as i64)
    } else {
        "No Serper credits available".to_string()
    };

    Ok(QuotaSnapshot {
        provider_id: "serper".to_string(),
        remaining: Some(remaining),
        limit: Some(remaining),
        remaining_badge_text,
        quota_label: Some("credits".to_string()),
        quota_windows: vec![],
        reset_at: None,
        plan_ends_at: None,
    })
}
