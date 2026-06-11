use serde::Deserialize;

use crate::domain::QuotaWindow;

use super::{ProviderClient, ProviderCredential, ProviderError, QuotaSnapshot};

const TAVILY_USAGE_FIXTURE: &str = r#"{
  "monthlyCredits": {
    "used": 80,
    "limit": 1000,
    "resetAt": "2026-07-01T00:00:00+08:00"
  }
}"#;

#[derive(Debug, Default)]
pub struct TavilyProvider;

impl ProviderClient for TavilyProvider {
    fn provider_id(&self) -> &'static str {
        "tavily"
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

        parse_tavily_usage(TAVILY_USAGE_FIXTURE)
    }
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct TavilyUsageFixture {
    monthly_credits: TavilyMonthlyCredits,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct TavilyMonthlyCredits {
    used: f64,
    limit: f64,
    reset_at: String,
}

fn parse_tavily_usage(value: &str) -> Result<QuotaSnapshot, ProviderError> {
    let usage: TavilyUsageFixture =
        serde_json::from_str(value).map_err(|error| ProviderError::Parse(error.to_string()))?;
    let remaining = (usage.monthly_credits.limit - usage.monthly_credits.used).max(0.0);
    let percent = if usage.monthly_credits.limit > 0.0 {
        remaining / usage.monthly_credits.limit * 100.0
    } else {
        0.0
    };

    Ok(QuotaSnapshot {
        provider_id: "tavily".to_string(),
        remaining: Some(remaining),
        limit: Some(usage.monthly_credits.limit),
        remaining_badge_text: format!(
            "{} / {}",
            remaining.round() as i64,
            usage.monthly_credits.limit.round() as i64
        ),
        quota_label: Some("credits".to_string()),
        quota_windows: vec![QuotaWindow::percent(
            "month",
            percent,
            &usage.monthly_credits.reset_at,
        )],
        reset_at: Some(usage.monthly_credits.reset_at),
        plan_ends_at: None,
    })
}
