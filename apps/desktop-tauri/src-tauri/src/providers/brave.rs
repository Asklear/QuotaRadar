use serde::Deserialize;

use crate::domain::QuotaWindow;

use super::{
    ProviderClient, ProviderCredential, ProviderError, ProviderHttpRequest, ProviderHttpResponse,
    ProviderTransport, QuotaSnapshot,
};

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
            ProviderHttpRequest::get(
                "https://api.search.brave.com/res/v1/web/search?q=test&count=1",
            )
            .header("X-Subscription-Token", &credential.secret)
            .header("Accept", "application/json"),
        )?;
        if response.status == 401 || response.status == 403 {
            return Err(ProviderError::Unauthorized(
                "Brave API key is unauthorized".to_string(),
            ));
        }
        if response.status == 422 {
            return Err(ProviderError::Unauthorized(
                "Brave API key is invalid".to_string(),
            ));
        }
        if response.status != 200 {
            return Err(ProviderError::QuotaUnavailable(format!(
                "Brave Search endpoint returned HTTP {}",
                response.status
            )));
        }

        parse_brave_rate_limit_headers(&response)
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

    Ok(brave_snapshot(
        usage.monthly_requests.remaining,
        usage.monthly_requests.limit,
        usage.monthly_requests.reset_at,
    ))
}

fn parse_brave_rate_limit_headers(
    response: &ProviderHttpResponse,
) -> Result<QuotaSnapshot, ProviderError> {
    let remaining_values = header_numbers(
        response,
        &[
            "X-RateLimit-Requests-Left",
            "RateLimit-Remaining",
            "X-RateLimit-Remaining",
        ],
    );
    let limit_values = header_numbers(
        response,
        &[
            "X-RateLimit-Requests-Limit",
            "RateLimit-Limit",
            "X-RateLimit-Limit",
        ],
    );

    if remaining_values.is_empty() || limit_values.is_empty() {
        return Err(ProviderError::QuotaUnavailable(
            "Brave monthly request headers are unavailable".to_string(),
        ));
    }

    let count = remaining_values.len().min(limit_values.len());
    let policy_windows = header_value(response, &["X-RateLimit-Policy", "RateLimit-Policy"])
        .map(parse_brave_policy_windows)
        .unwrap_or_default();
    let index = if policy_windows.len() >= count {
        policy_windows
            .iter()
            .take(count)
            .enumerate()
            .max_by_key(|(_, window_seconds)| *window_seconds)
            .map(|(index, _)| index)
            .unwrap_or(count - 1)
    } else {
        count - 1
    };

    let remaining = remaining_values[index].max(0.0);
    let limit = limit_values[index].max(remaining);
    let reset_at = header_value(
        response,
        &[
            "X-RateLimit-Requests-Reset",
            "RateLimit-Reset",
            "X-RateLimit-Reset",
        ],
    )
    .and_then(|value| parse_brave_reset_header(value, index))
    .unwrap_or_else(next_month_start_utc);

    if limit <= 0.0 {
        return Ok(brave_unknown_quota_snapshot(reset_at));
    }

    Ok(brave_snapshot(remaining, limit, reset_at))
}

fn brave_snapshot(remaining: f64, limit: f64, reset_at: String) -> QuotaSnapshot {
    let percent = if limit > 0.0 {
        ((remaining / limit * 100.0) * 100.0).round() / 100.0
    } else {
        0.0
    };

    QuotaSnapshot {
        provider_id: "brave".to_string(),
        remaining: Some(remaining),
        limit: Some(limit),
        remaining_badge_text: format!("{} / {}", remaining.round() as i64, limit.round() as i64),
        quota_label: Some("requests".to_string()),
        quota_windows: vec![QuotaWindow::percent("month", percent, &reset_at)],
        reset_at: Some(reset_at),
        plan_ends_at: None,
    }
}

fn brave_unknown_quota_snapshot(reset_at: String) -> QuotaSnapshot {
    QuotaSnapshot {
        provider_id: "brave".to_string(),
        remaining: None,
        limit: None,
        remaining_badge_text: "OK".to_string(),
        quota_label: Some("quota hidden".to_string()),
        quota_windows: vec![],
        reset_at: Some(reset_at),
        plan_ends_at: None,
    }
}

fn header_numbers(response: &ProviderHttpResponse, names: &[&str]) -> Vec<f64> {
    header_value(response, names)
        .map(parse_comma_separated_numbers)
        .unwrap_or_default()
}

fn parse_comma_separated_numbers(value: &str) -> Vec<f64> {
    value
        .split(',')
        .filter_map(|part| part.trim().parse::<f64>().ok())
        .collect()
}

fn parse_brave_policy_windows(value: &str) -> Vec<i64> {
    value
        .split(',')
        .filter_map(|part| {
            part.split(';').find_map(|segment| {
                segment
                    .trim()
                    .strip_prefix("w=")
                    .and_then(|window| window.parse::<i64>().ok())
            })
        })
        .collect()
}

fn header_value<'a>(response: &'a ProviderHttpResponse, names: &[&str]) -> Option<&'a str> {
    names.iter().find_map(|name| response.header(name))
}

fn parse_brave_reset_header(value: &str, selected_index: usize) -> Option<String> {
    let parts: Vec<&str> = value.split(',').map(str::trim).collect();
    if parts.len() > 1 {
        return parts
            .get(selected_index)
            .and_then(|part| parse_reset_seconds_from_now(part));
    }

    parse_reset_header(value)
}

fn parse_reset_seconds_from_now(value: &str) -> Option<String> {
    let seconds = value.trim().parse::<i64>().ok()?.max(0);
    Some((chrono::Utc::now() + chrono::Duration::seconds(seconds)).to_rfc3339())
}

fn parse_reset_header(value: &str) -> Option<String> {
    let trimmed = value.trim();
    if let Ok(timestamp) = trimmed.parse::<i64>() {
        let seconds = if timestamp > 10_000_000_000 {
            timestamp / 1000
        } else {
            timestamp
        };
        return chrono::DateTime::<chrono::Utc>::from_timestamp(seconds, 0)
            .map(|date| date.to_rfc3339());
    }

    chrono::DateTime::parse_from_rfc3339(trimmed)
        .map(|date| date.to_rfc3339())
        .ok()
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
