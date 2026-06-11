use serde::Deserialize;

use super::{
    ProviderClient, ProviderCredential, ProviderError, ProviderHttpRequest, ProviderTransport,
    QuotaSnapshot,
};

const WXMP_BALANCE_FIXTURE: &str = r#"{
  "code": 0,
  "remain_money": 161.8
}"#;

const WXMP_STRING_BALANCE_FIXTURE: &str = r#"{
  "code": 0,
  "remain_money": "8.50"
}"#;

const WXMP_UNAUTHORIZED_FIXTURE: &str = r#"{
  "code": 401,
  "message": "Invalid API key"
}"#;

const WXMP_QUOTA_UNAVAILABLE_FIXTURE: &str = r#"{
  "code": 0
}"#;

#[derive(Debug, Default)]
pub struct WxmpProvider;

impl WxmpProvider {
    pub fn check_string_balance_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, 200, WXMP_STRING_BALANCE_FIXTURE)
    }

    pub fn check_unauthorized_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, 401, WXMP_UNAUTHORIZED_FIXTURE)
    }

    pub fn check_quota_unavailable_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, 200, WXMP_QUOTA_UNAVAILABLE_FIXTURE)
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

        parse_wxmp_balance(http_status, value)
    }
}

impl ProviderClient for WxmpProvider {
    fn provider_id(&self) -> &'static str {
        "wxmp"
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
            ProviderHttpRequest::post("https://www.dajiala.com/fbmain/monitor/v3/get_remain_money")
                .header("Content-Type", "application/x-www-form-urlencoded")
                .body(&format!("key={}", credential.secret)),
        )?;
        if response.status == 401 || response.status == 403 {
            return parse_wxmp_balance(response.status, &response.body);
        }
        if response.status != 200 {
            return Err(ProviderError::QuotaUnavailable(format!(
                "WeChat Search balance endpoint returned HTTP {}",
                response.status
            )));
        }

        parse_wxmp_balance(response.status, &response.body)
    }

    fn check_fixture_quota(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, 200, WXMP_BALANCE_FIXTURE)
    }
}

#[derive(Debug, Deserialize)]
struct WxmpBalanceFixture {
    code: i64,
    remain_money: Option<serde_json::Value>,
    message: Option<String>,
}

fn parse_wxmp_balance(http_status: u16, value: &str) -> Result<QuotaSnapshot, ProviderError> {
    let response: WxmpBalanceFixture =
        serde_json::from_str(value).map_err(|error| ProviderError::Parse(error.to_string()))?;

    if http_status == 401 || http_status == 403 {
        return Err(ProviderError::Unauthorized(
            response
                .message
                .unwrap_or_else(|| "Invalid API key".to_string()),
        ));
    }

    if response.code != 0 {
        return Err(ProviderError::QuotaUnavailable(
            "WeChat Search balance is unavailable".to_string(),
        ));
    }

    let remaining = response
        .remain_money
        .and_then(|value| match value {
            serde_json::Value::Number(number) => number.as_f64(),
            serde_json::Value::String(string) => string.parse::<f64>().ok(),
            _ => None,
        })
        .ok_or_else(|| {
            ProviderError::QuotaUnavailable("WeChat Search balance is unavailable".to_string())
        })?
        .max(0.0);

    Ok(QuotaSnapshot {
        provider_id: "wxmp".to_string(),
        remaining: Some(remaining),
        limit: Some(remaining),
        remaining_badge_text: format!("¥{remaining:.2}"),
        quota_label: Some("CNY".to_string()),
        quota_windows: vec![],
        reset_at: None,
        plan_ends_at: None,
    })
}
