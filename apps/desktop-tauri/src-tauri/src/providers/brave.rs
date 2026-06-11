use serde::Deserialize;

use crate::domain::QuotaWindow;

use super::{ProviderClient, ProviderCredential, ProviderError, QuotaSnapshot};

const BRAVE_USAGE_FIXTURE: &str = r#"{
  "monthlyRequests": {
    "remaining": 742,
    "limit": 1000,
    "resetAt": "2026-07-01T00:00:00+08:00"
  }
}"#;

#[derive(Debug, Default)]
pub struct BraveProvider;

impl ProviderClient for BraveProvider {
    fn provider_id(&self) -> &'static str {
        "brave"
    }

    fn consumes_quota_on_check(&self) -> bool {
        true
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

        parse_brave_usage(BRAVE_USAGE_FIXTURE)
    }
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct BraveUsageFixture {
    monthly_requests: BraveMonthlyRequests,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct BraveMonthlyRequests {
    remaining: f64,
    limit: f64,
    reset_at: String,
}

fn parse_brave_usage(value: &str) -> Result<QuotaSnapshot, ProviderError> {
    let usage: BraveUsageFixture =
        serde_json::from_str(value).map_err(|error| ProviderError::Parse(error.to_string()))?;
    let percent = if usage.monthly_requests.limit > 0.0 {
        usage.monthly_requests.remaining / usage.monthly_requests.limit * 100.0
    } else {
        0.0
    };

    Ok(QuotaSnapshot {
        provider_id: "brave".to_string(),
        remaining: Some(usage.monthly_requests.remaining),
        limit: Some(usage.monthly_requests.limit),
        remaining_badge_text: format!(
            "{} / {}",
            usage.monthly_requests.remaining.round() as i64,
            usage.monthly_requests.limit.round() as i64
        ),
        quota_label: Some("requests".to_string()),
        quota_windows: vec![QuotaWindow::percent(
            "month",
            percent,
            &usage.monthly_requests.reset_at,
        )],
        reset_at: Some(usage.monthly_requests.reset_at),
        plan_ends_at: None,
    })
}
