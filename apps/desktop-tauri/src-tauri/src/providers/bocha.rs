use serde::Deserialize;

use super::{
    ProviderClient, ProviderCredential, ProviderError, ProviderHttpRequest, ProviderTransport,
    QuotaSnapshot,
};

const BOCHA_BALANCE_FIXTURE: &str = r#"{
  "success": true,
  "code": "200",
  "data": {
    "remaining": 12.34
  }
}"#;

const BOCHA_UNAUTHORIZED_FIXTURE: &str = r#"{
  "success": false,
  "code": "401",
  "message": "Invalid API key"
}"#;

const BOCHA_QUOTA_UNAVAILABLE_FIXTURE: &str = r#"{
  "success": true,
  "code": "200",
  "data": {}
}"#;

#[derive(Debug, Default)]
pub struct BochaProvider;

impl BochaProvider {
    pub fn check_unauthorized_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, 401, BOCHA_UNAUTHORIZED_FIXTURE)
    }

    pub fn check_quota_unavailable_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, 200, BOCHA_QUOTA_UNAVAILABLE_FIXTURE)
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

        parse_bocha_balance(http_status, value)
    }
}

impl ProviderClient for BochaProvider {
    fn provider_id(&self) -> &'static str {
        "bocha"
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

        let response = transport.send(
            ProviderHttpRequest::get("https://api.bochaai.com/v1/fund/remaining")
                .header("Authorization", &format!("Bearer {}", credential.secret)),
        )?;
        if response.status == 401 || response.status == 403 {
            return parse_bocha_balance(response.status, &response.body);
        }
        if response.status != 200 {
            return Err(ProviderError::QuotaUnavailable(format!(
                "Bocha balance endpoint returned HTTP {}",
                response.status
            )));
        }

        parse_bocha_balance(response.status, &response.body)
    }

    fn check_fixture_quota(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, 200, BOCHA_BALANCE_FIXTURE)
    }
}

#[derive(Debug, Deserialize)]
struct BochaBalanceFixture {
    success: Option<bool>,
    code: Option<String>,
    message: Option<String>,
    data: Option<BochaBalanceData>,
}

#[derive(Debug, Deserialize)]
struct BochaBalanceData {
    remaining: Option<f64>,
}

fn parse_bocha_balance(http_status: u16, value: &str) -> Result<QuotaSnapshot, ProviderError> {
    let response: BochaBalanceFixture =
        serde_json::from_str(value).map_err(|error| ProviderError::Parse(error.to_string()))?;

    if http_status == 401 || http_status == 403 {
        return Err(ProviderError::Unauthorized(
            response
                .message
                .unwrap_or_else(|| "Invalid API key".to_string()),
        ));
    }

    if response.success != Some(true) || response.code.as_deref() != Some("200") {
        return Err(ProviderError::QuotaUnavailable(
            "Bocha balance is unavailable".to_string(),
        ));
    }

    let remaining = response
        .data
        .and_then(|data| data.remaining)
        .ok_or_else(|| ProviderError::QuotaUnavailable("Bocha balance is unavailable".to_string()))?
        .max(0.0);

    Ok(QuotaSnapshot {
        provider_id: "bocha".to_string(),
        remaining: Some(remaining),
        limit: Some(remaining),
        remaining_badge_text: format!("¥{remaining:.2}"),
        quota_label: Some("CNY".to_string()),
        quota_windows: vec![],
        reset_at: None,
        plan_ends_at: None,
        codex_reset_credits_remaining: None,
        codex_reset_credits_earliest_expires_at: None,
    })
}
