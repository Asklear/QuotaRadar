use serde::Deserialize;

use super::{
    ProviderClient, ProviderCredential, ProviderError, ProviderHttpRequest, ProviderTransport,
    QuotaSnapshot,
};

const EXA_USAGE_FIXTURE: &str = r#"{
  "total_cost_usd": 45.67
}"#;

const EXA_CAMEL_CASE_USAGE_FIXTURE: &str = r#"{
  "totalCostUsd": 12.5
}"#;

const EXA_UNAUTHORIZED_FIXTURE: &str = r#"{
  "message": "Invalid service key"
}"#;

const EXA_QUOTA_UNAVAILABLE_FIXTURE: &str = r#"{
  "usage": []
}"#;

#[derive(Debug, Default)]
pub struct ExaProvider;

impl ExaProvider {
    pub fn check_camel_case_usage_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, 200, EXA_CAMEL_CASE_USAGE_FIXTURE)
    }

    pub fn check_unauthorized_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, 401, EXA_UNAUTHORIZED_FIXTURE)
    }

    pub fn check_quota_unavailable_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, 200, EXA_QUOTA_UNAVAILABLE_FIXTURE)
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

        let _credential = ExaManagementCredential::from_secret(&credential.secret)?;
        parse_exa_usage(http_status, value)
    }
}

impl ProviderClient for ExaProvider {
    fn provider_id(&self) -> &'static str {
        "exa"
    }

    fn consumes_quota_on_check(&self) -> bool {
        false
    }

    fn check_quota(
        &self,
        credential: ProviderCredential,
        transport: &dyn ProviderTransport,
    ) -> Result<QuotaSnapshot, ProviderError> {
        if credential.provider_id != self.provider_id() {
            return Err(ProviderError::Unsupported(format!(
                "credential belongs to {}",
                credential.provider_id
            )));
        }

        let management_credential = ExaManagementCredential::from_secret(&credential.secret)?;
        let response = transport.send(
            ProviderHttpRequest::get(&format!(
                "https://admin-api.exa.ai/team-management/api-keys/{}/usage?numDays={}",
                management_credential.api_key_id,
                management_credential.days()
            ))
            .header("x-api-key", &management_credential.service_key)
            .header("Accept", "application/json"),
        )?;

        if response.status == 401 || response.status == 403 {
            return Err(ProviderError::Unauthorized(
                "Exa service key is unauthorized".to_string(),
            ));
        }
        if response.status != 200 {
            return Err(ProviderError::QuotaUnavailable(format!(
                "Exa management usage endpoint returned HTTP {}",
                response.status
            )));
        }

        parse_exa_usage(response.status, &response.body)
    }

    fn check_fixture_quota(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, 200, EXA_USAGE_FIXTURE)
    }
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ExaManagementCredential {
    #[serde(
        alias = "service_key",
        alias = "adminApiKey",
        alias = "admin_api_key",
        alias = "adminKey"
    )]
    service_key: String,
    #[serde(
        alias = "apiKeyID",
        alias = "api_key_id",
        alias = "keyID",
        alias = "keyId",
        alias = "id"
    )]
    api_key_id: String,
    #[serde(default, alias = "numDays", alias = "num_days")]
    days: Option<u16>,
}

impl ExaManagementCredential {
    fn from_secret(secret: &str) -> Result<Self, ProviderError> {
        let credential: Self = serde_json::from_str(secret).map_err(|_| {
            ProviderError::Unsupported(
                "Exa usage requires a service key and target API key id".to_string(),
            )
        })?;

        if credential.service_key.trim().is_empty() || credential.api_key_id.trim().is_empty() {
            return Err(ProviderError::Unsupported(
                "Exa usage requires a service key and target API key id".to_string(),
            ));
        }

        Ok(credential)
    }

    fn days(&self) -> u16 {
        self.days.unwrap_or(30).clamp(1, 365)
    }
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ExaUsageFixture {
    #[serde(alias = "total_cost_usd")]
    total_cost_usd: Option<f64>,
    message: Option<String>,
}

fn parse_exa_usage(http_status: u16, value: &str) -> Result<QuotaSnapshot, ProviderError> {
    let response: ExaUsageFixture =
        serde_json::from_str(value).map_err(|error| ProviderError::Parse(error.to_string()))?;

    if http_status == 401 || http_status == 403 {
        return Err(ProviderError::Unauthorized(
            response
                .message
                .unwrap_or_else(|| "Invalid service key".to_string()),
        ));
    }

    let total_cost = response
        .total_cost_usd
        .filter(|value| *value >= 0.0)
        .ok_or_else(|| ProviderError::QuotaUnavailable("Exa usage is unavailable".to_string()))?;

    Ok(QuotaSnapshot {
        provider_id: "exa".to_string(),
        remaining: None,
        limit: None,
        remaining_badge_text: format!("USD {total_cost:.2} used"),
        quota_label: Some("usage".to_string()),
        quota_windows: vec![],
        reset_at: None,
        plan_ends_at: None,
        codex_reset_credits_remaining: None,
        codex_reset_credits_earliest_expires_at: None,
    })
}
