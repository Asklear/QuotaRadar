use chrono::{DateTime, SecondsFormat, Utc};
use serde::Deserialize;
use serde_json::Value;

use crate::domain::QuotaWindow;

use super::{
    ProviderClient, ProviderCredential, ProviderError, ProviderHttpRequest, ProviderTransport,
    QuotaSnapshot,
};

const VOLCENGINE_CODING_PLAN_USAGE_URL: &str =
    "https://console.volcengine.com/api/top/ark/cn-beijing/2024-01-01/GetCodingPlanUsage?";

const VOLCENGINE_CODING_PLAN_FIXTURE: &str = r#"{
  "ResponseMetadata": {
    "Action": "GetCodingPlanUsage"
  },
  "Result": {
    "Status": "Running",
    "QuotaUsage": [
      {
        "Level": "session",
        "Percent": 0,
        "ResetTimestamp": -1
      },
      {
        "Level": "weekly",
        "Percent": 10.814960999999998,
        "ResetTimestamp": 1780848000
      },
      {
        "Level": "monthly",
        "Percent": 5.407480499999999,
        "ResetTimestamp": 1782921599
      }
    ]
  }
}"#;

const VOLCENGINE_EMPTY_USAGE_FIXTURE: &str = r#"{
  "ResponseMetadata": {
    "Action": "GetCodingPlanUsage"
  },
  "Result": {
    "Status": "Running",
    "QuotaUsage": []
  }
}"#;

#[derive(Debug, Default)]
pub struct VolcengineCodingPlanProvider;

impl VolcengineCodingPlanProvider {
    pub fn check_empty_usage_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, VOLCENGINE_EMPTY_USAGE_FIXTURE)
    }

    fn check_response_fixture(
        &self,
        credential: ProviderCredential,
        value: &str,
    ) -> Result<QuotaSnapshot, ProviderError> {
        if credential.provider_id != self.provider_id() {
            return Err(ProviderError::Unsupported(format!(
                "credential belongs to {}",
                credential.provider_id
            )));
        }

        VolcengineCredential::from_secret(&credential.secret)?;
        parse_volcengine_coding_plan(value)
    }
}

impl ProviderClient for VolcengineCodingPlanProvider {
    fn provider_id(&self) -> &'static str {
        "volcengine_coding_plan"
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

        let volcengine_credential = VolcengineCredential::from_secret(&credential.secret)?;
        let response = transport.send(volcengine_usage_request(&volcengine_credential))?;
        if response.status == 401 || response.status == 403 {
            return Err(volcengine_login_required());
        }
        if response.status != 200 {
            return Err(ProviderError::QuotaUnavailable(format!(
                "Volcengine coding plan endpoint returned HTTP {}",
                response.status
            )));
        }

        parse_volcengine_coding_plan(&response.body)
    }

    fn check_fixture_quota(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, VOLCENGINE_CODING_PLAN_FIXTURE)
    }
}

struct VolcengineCredential {
    cookie_header: String,
    csrf_token: Option<String>,
    project_name: String,
    x_web_id: Option<String>,
}

impl VolcengineCredential {
    fn from_secret(secret: &str) -> Result<Self, ProviderError> {
        let trimmed = secret.trim();
        if trimmed.is_empty() || trimmed == "{}" {
            return Err(volcengine_login_required());
        }

        let parsed = serde_json::from_str::<Value>(trimmed).ok();
        let cookie = parsed
            .as_ref()
            .and_then(|value| {
                first_string(
                    value,
                    &[
                        "cookie",
                        "cookieHeader",
                        "dashboardCookie",
                        "dashboard_cookie",
                        "authorizationCookie",
                    ],
                )
            })
            .unwrap_or_else(|| trimmed.to_string());

        if cookie.contains("digest=") && cookie.contains("AccountID=") {
            Ok(Self {
                csrf_token: parsed
                    .as_ref()
                    .and_then(|value| first_string(value, &["csrfToken", "csrf", "xCsrfToken"]))
                    .or_else(|| cookie_value(&cookie, "csrfToken")),
                project_name: parsed
                    .as_ref()
                    .and_then(|value| first_string(value, &["projectName", "project"]))
                    .unwrap_or_else(|| "default".to_string()),
                x_web_id: parsed
                    .as_ref()
                    .and_then(|value| first_string(value, &["xWebId", "x-web-id", "webId"])),
                cookie_header: cookie,
            })
        } else {
            Err(volcengine_login_required())
        }
    }
}

fn volcengine_usage_request(credential: &VolcengineCredential) -> ProviderHttpRequest {
    let mut request = ProviderHttpRequest::post(VOLCENGINE_CODING_PLAN_USAGE_URL)
        .header("Accept", "application/json, text/plain, */*")
        .header("Content-Type", "application/json")
        .header("Cookie", &credential.cookie_header)
        .header("Origin", "https://console.volcengine.com")
        .header(
            "Referer",
            &format!(
                "https://console.volcengine.com/ark/region:ark+cn-beijing/openManagement?LLM=%7B%7D&advancedActiveKey=subscribe&projectName={}",
                credential.project_name
            ),
        )
        .body(&format!(r#"{{"ProjectName":"{}"}}"#, credential.project_name));

    if let Some(csrf_token) = credential.csrf_token.as_deref() {
        request = request.header("x-csrf-token", csrf_token);
    }
    if let Some(x_web_id) = credential.x_web_id.as_deref() {
        request = request.header("x-web-id", x_web_id);
    }

    request
}

fn cookie_value(cookie_header: &str, name: &str) -> Option<String> {
    cookie_header.split(';').find_map(|part| {
        let (key, value) = part.trim().split_once('=')?;
        if key == name {
            Some(value.to_string())
        } else {
            None
        }
    })
}

fn volcengine_login_required() -> ProviderError {
    ProviderError::Unauthorized("Volcengine web login authorization is required".to_string())
}

fn parse_volcengine_coding_plan(value: &str) -> Result<QuotaSnapshot, ProviderError> {
    let response: VolcengineCodingPlanUsage =
        serde_json::from_str(value).map_err(|error| ProviderError::Parse(error.to_string()))?;
    let usage = response
        .result
        .and_then(|result| result.quota_usage)
        .unwrap_or_default();
    if usage.is_empty() {
        return Err(ProviderError::QuotaUnavailable(
            "Volcengine quota is unavailable".to_string(),
        ));
    }

    let remaining_basis_points = usage
        .iter()
        .map(|item| basis_points(100.0 - item.percent))
        .fold(10_000.0, f64::min);
    let windows = order_windows(
        usage
            .into_iter()
            .map(|item| {
                percent_window(
                    &volcengine_window_name(&item.level),
                    100.0 - item.percent,
                    item.reset_timestamp,
                )
            })
            .collect(),
    );
    let reset_at = tightest_window_reset(&windows);

    Ok(snapshot_from_windows(
        "volcengine_coding_plan",
        windows,
        remaining_basis_points,
        reset_at,
        None,
    ))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "PascalCase")]
struct VolcengineCodingPlanUsage {
    result: Option<VolcengineResult>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "PascalCase")]
struct VolcengineResult {
    quota_usage: Option<Vec<VolcengineUsageWindow>>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "PascalCase")]
struct VolcengineUsageWindow {
    level: String,
    percent: f64,
    reset_timestamp: Option<i64>,
}

fn volcengine_window_name(value: &str) -> String {
    match value.to_lowercase().as_str() {
        "session" | "rolling" | "five_hour" | "5h" => "5h".to_string(),
        "weekly" | "week" => "week".to_string(),
        "monthly" | "month" => "month".to_string(),
        _ => value.to_string(),
    }
}

fn percent_window(name: &str, remaining_percent: f64, reset_timestamp: Option<i64>) -> QuotaWindow {
    QuotaWindow {
        name: name.to_string(),
        percent_remaining: Some(round_percent(remaining_percent.max(0.0))),
        remaining_text: None,
        reset_at: reset_timestamp.and_then(epoch_seconds_to_iso8601),
    }
}

fn snapshot_from_windows(
    provider_id: &str,
    windows: Vec<QuotaWindow>,
    remaining_basis_points: f64,
    reset_at: Option<String>,
    plan_ends_at: Option<String>,
) -> QuotaSnapshot {
    QuotaSnapshot {
        provider_id: provider_id.to_string(),
        remaining: Some(remaining_basis_points),
        limit: Some(10_000.0),
        remaining_badge_text: windows
            .iter()
            .filter_map(|window| {
                window
                    .percent_remaining
                    .map(|percent| format!("{} {}", window.name, format_percent(percent)))
            })
            .collect::<Vec<_>>()
            .join(" · "),
        quota_label: Some("subscription".to_string()),
        quota_windows: windows,
        reset_at,
        plan_ends_at,
        codex_reset_credits_remaining: None,
        codex_reset_credits_earliest_expires_at: None,
    }
}

fn tightest_window_reset(windows: &[QuotaWindow]) -> Option<String> {
    windows
        .iter()
        .filter(|window| window.reset_at.is_some())
        .min_by(|left, right| {
            let left_percent = left.percent_remaining.unwrap_or(100.0);
            let right_percent = right.percent_remaining.unwrap_or(100.0);
            left_percent.total_cmp(&right_percent)
        })
        .and_then(|window| window.reset_at.clone())
}

fn order_windows(mut windows: Vec<QuotaWindow>) -> Vec<QuotaWindow> {
    windows.sort_by_key(|window| match window.name.as_str() {
        "5h" => 0,
        "week" => 1,
        "month" => 2,
        _ => 3,
    });
    windows
}

fn epoch_seconds_to_iso8601(seconds: i64) -> Option<String> {
    if seconds <= 0 {
        return None;
    }
    let date_time: DateTime<Utc> = DateTime::from_timestamp(seconds, 0)?;
    Some(date_time.to_rfc3339_opts(SecondsFormat::Secs, true))
}

fn basis_points(percent: f64) -> f64 {
    (percent.clamp(0.0, 100.0) * 100.0).floor()
}

fn round_percent(value: f64) -> f64 {
    (value * 10.0).round() / 10.0
}

fn format_percent(value: f64) -> String {
    let rounded = round_percent(value);
    if (rounded.fract()).abs() < f64::EPSILON {
        format!("{}%", rounded as i64)
    } else {
        format!("{rounded:.1}%")
    }
}

fn first_string(value: &Value, keys: &[&str]) -> Option<String> {
    keys.iter()
        .find_map(|key| string_at(value, key))
        .filter(|value| !value.trim().is_empty())
}

fn string_at(value: &Value, key: &str) -> Option<String> {
    value.get(key).and_then(|value| {
        value
            .as_str()
            .map(ToString::to_string)
            .or_else(|| value.as_i64().map(|number| number.to_string()))
    })
}
