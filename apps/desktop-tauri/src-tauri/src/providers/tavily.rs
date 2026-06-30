use serde::Deserialize;
use serde_json::Value;

use crate::domain::QuotaWindow;

use super::{
    ProviderClient, ProviderCredential, ProviderError, ProviderHttpRequest, ProviderTransport,
    QuotaSnapshot,
};

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
            ProviderHttpRequest::get("https://api.tavily.com/usage")
                .header("Authorization", &format!("Bearer {}", credential.secret))
                .header("Content-Type", "application/json"),
        )?;
        if response.status == 401 || response.status == 403 {
            return Err(ProviderError::Unauthorized(
                "Tavily API key is unauthorized".to_string(),
            ));
        }
        if response.status != 200 {
            return Err(ProviderError::QuotaUnavailable(format!(
                "Tavily usage endpoint returned HTTP {}",
                response.status
            )));
        }

        parse_tavily_usage(&response.body)
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
    if let Ok(parsed) = serde_json::from_str::<Value>(value) {
        if parsed.get("key").is_some() || parsed.get("account").is_some() {
            return parse_tavily_live_usage(&parsed);
        }
    }

    let usage: TavilyUsageFixture =
        serde_json::from_str(value).map_err(|error| ProviderError::Parse(error.to_string()))?;
    tavily_snapshot(
        (usage.monthly_credits.limit - usage.monthly_credits.used).max(0.0),
        usage.monthly_credits.limit,
        usage.monthly_credits.reset_at,
    )
}

fn parse_tavily_live_usage(value: &Value) -> Result<QuotaSnapshot, ProviderError> {
    let key_usage = value.get("key");
    let key_limit = key_usage.and_then(|key| number_at(key, "limit"));
    if let Some(limit) = key_limit.filter(|limit| *limit > 0.0) {
        let used = key_usage
            .and_then(|key| number_at(key, "usage"))
            .unwrap_or(0.0);
        return tavily_snapshot((limit - used).max(0.0), limit, next_month_start_utc());
    }

    let account_usage = value.get("account");
    let account_limit = account_usage.and_then(|account| number_at(account, "plan_limit"));
    if let Some(limit) = account_limit.filter(|limit| *limit > 0.0) {
        let used = account_usage
            .and_then(|account| number_at(account, "plan_usage"))
            .unwrap_or(0.0);
        return tavily_snapshot((limit - used).max(0.0), limit, next_month_start_utc());
    }

    Err(ProviderError::QuotaUnavailable(
        "Tavily usage quota is unavailable".to_string(),
    ))
}

fn tavily_snapshot(
    remaining: f64,
    limit: f64,
    reset_at: String,
) -> Result<QuotaSnapshot, ProviderError> {
    let percent = if limit > 0.0 {
        remaining / limit * 100.0
    } else {
        0.0
    };

    Ok(QuotaSnapshot {
        provider_id: "tavily".to_string(),
        remaining: Some(remaining),
        limit: Some(limit),
        remaining_badge_text: format!("{} / {}", remaining.round() as i64, limit.round() as i64),
        quota_label: Some("credits".to_string()),
        quota_windows: vec![QuotaWindow::percent("month", percent, &reset_at)],
        reset_at: Some(reset_at),
        plan_ends_at: None,
        codex_reset_credits_remaining: None,
        codex_reset_credits_earliest_expires_at: None,
    })
}

fn number_at(value: &Value, key: &str) -> Option<f64> {
    value.get(key).and_then(|value| {
        value
            .as_f64()
            .or_else(|| value.as_str()?.parse::<f64>().ok())
    })
}

fn next_month_start_utc() -> String {
    use chrono::{Datelike, Utc};

    let now = Utc::now();
    let (year, month) = if now.month() == 12 {
        (now.year() + 1, 1)
    } else {
        (now.year(), now.month() + 1)
    };
    format!("{year:04}-{month:02}-01T00:00:00Z")
}
