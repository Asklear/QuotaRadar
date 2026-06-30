use serde::Deserialize;
use serde_json::Value;

use crate::domain::QuotaWindow;

use super::{
    ProviderClient, ProviderCredential, ProviderError, ProviderHttpRequest, ProviderTransport,
    QuotaSnapshot,
};

const DEEPSEEK_BALANCE_FIXTURE: &str = r#"{
  "balance": {
    "availableCny": 128.4,
    "monthlyBudgetCny": 200.0,
    "resetAt": "2026-07-01T00:00:00+08:00"
  }
}"#;

#[derive(Debug, Default)]
pub struct DeepSeekProvider;

impl ProviderClient for DeepSeekProvider {
    fn provider_id(&self) -> &'static str {
        "deepseek"
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
            ProviderHttpRequest::get("https://api.deepseek.com/user/balance")
                .header("Authorization", &format!("Bearer {}", credential.secret)),
        )?;
        if response.status == 401 || response.status == 403 {
            return Err(ProviderError::Unauthorized(
                "DeepSeek API key is unauthorized".to_string(),
            ));
        }
        if response.status != 200 {
            return Err(ProviderError::QuotaUnavailable(format!(
                "DeepSeek balance endpoint returned HTTP {}",
                response.status
            )));
        }

        parse_deepseek_balance(&response.body)
    }

    fn check_fixture_quota(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        if credential.provider_id != self.provider_id() {
            return Err(ProviderError::Unsupported(format!(
                "credential belongs to {}",
                credential.provider_id
            )));
        }

        parse_deepseek_balance(DEEPSEEK_BALANCE_FIXTURE)
    }
}

#[derive(Debug, Deserialize)]
struct DeepSeekBalanceFixture {
    balance: DeepSeekBalance,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct DeepSeekBalance {
    available_cny: f64,
    monthly_budget_cny: f64,
    reset_at: String,
}

fn parse_deepseek_balance(value: &str) -> Result<QuotaSnapshot, ProviderError> {
    if let Ok(parsed) = serde_json::from_str::<Value>(value) {
        if parsed.get("balance_infos").is_some() {
            return parse_deepseek_live_balance(&parsed);
        }
    }

    let usage: DeepSeekBalanceFixture =
        serde_json::from_str(value).map_err(|error| ProviderError::Parse(error.to_string()))?;
    let percent = if usage.balance.monthly_budget_cny > 0.0 {
        usage.balance.available_cny / usage.balance.monthly_budget_cny * 100.0
    } else {
        0.0
    };

    Ok(QuotaSnapshot {
        provider_id: "deepseek".to_string(),
        remaining: Some(usage.balance.available_cny),
        limit: Some(usage.balance.monthly_budget_cny),
        remaining_badge_text: format!(
            "¥{:.2} / ¥{:.2}",
            usage.balance.available_cny, usage.balance.monthly_budget_cny
        ),
        quota_label: Some("CNY".to_string()),
        quota_windows: vec![QuotaWindow::percent(
            "month",
            percent,
            &usage.balance.reset_at,
        )],
        reset_at: Some(usage.balance.reset_at),
        plan_ends_at: None,
        codex_reset_credits_remaining: None,
        codex_reset_credits_earliest_expires_at: None,
    })
}

fn parse_deepseek_live_balance(value: &Value) -> Result<QuotaSnapshot, ProviderError> {
    if value.get("is_available").and_then(Value::as_bool) != Some(true) {
        return Ok(QuotaSnapshot {
            provider_id: "deepseek".to_string(),
            remaining: Some(0.0),
            limit: Some(0.0),
            remaining_badge_text: "Unavailable".to_string(),
            quota_label: Some("CNY".to_string()),
            quota_windows: Vec::new(),
            reset_at: None,
            plan_ends_at: None,
            codex_reset_credits_remaining: None,
            codex_reset_credits_earliest_expires_at: None,
        });
    }

    let balance = value
        .get("balance_infos")
        .and_then(Value::as_array)
        .and_then(|balances| balances.first())
        .ok_or_else(|| {
            ProviderError::QuotaUnavailable("DeepSeek balance is unavailable".to_string())
        })?;
    let currency = balance
        .get("currency")
        .and_then(Value::as_str)
        .unwrap_or("CNY");
    let amount = balance
        .get("total_balance")
        .and_then(|value| {
            value
                .as_str()
                .and_then(|text| text.parse::<f64>().ok())
                .or_else(|| value.as_f64())
        })
        .ok_or_else(|| {
            ProviderError::QuotaUnavailable("DeepSeek balance is unavailable".to_string())
        })?;
    let cents = (amount * 100.0).round().max(0.0);

    Ok(QuotaSnapshot {
        provider_id: "deepseek".to_string(),
        remaining: Some(cents),
        limit: Some(cents),
        remaining_badge_text: format!("{currency} {amount:.2} available"),
        quota_label: Some(currency.to_string()),
        quota_windows: Vec::new(),
        reset_at: None,
        plan_ends_at: None,
        codex_reset_credits_remaining: None,
        codex_reset_credits_earliest_expires_at: None,
    })
}
