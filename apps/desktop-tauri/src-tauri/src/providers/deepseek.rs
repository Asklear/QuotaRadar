use serde::Deserialize;

use crate::domain::QuotaWindow;

use super::{ProviderClient, ProviderCredential, ProviderError, QuotaSnapshot};

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
        quota_windows: vec![QuotaWindow::percent("month", percent, &usage.balance.reset_at)],
        reset_at: Some(usage.balance.reset_at),
    })
}
