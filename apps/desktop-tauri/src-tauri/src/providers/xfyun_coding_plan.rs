use serde::Deserialize;
use serde_json::Value;

use crate::domain::QuotaWindow;

use super::{
    ProviderClient, ProviderCredential, ProviderError, ProviderHttpRequest, ProviderTransport,
    QuotaSnapshot,
};

const XFYUN_CODING_PLAN_LIST_URL: &str =
    "https://maas.xfyun.cn/api/v1/gpt-finetune/coding-plan/list?page=1&size=6";

const XFYUN_CODING_PLAN_FIXTURE: &str = r#"{
  "code": 0,
  "data": {
    "rows": [
      {
        "name": "Efficient",
        "expiresAt": "2026-06-28 17:48:58",
        "status": 1,
        "codingPlanUsageDTO": {
          "packageLeft": 80704,
          "packageLimit": 90000,
          "packageUsage": 9296,
          "rp5hLimit": 6000,
          "rp5hUsage": 60,
          "rpwLimit": 45000,
          "rpwUsage": 9296
        }
      }
    ]
  },
  "succeed": true
}"#;

const XFYUN_FAILED_LOGIN_FIXTURE: &str = r#"{
  "code": 4001,
  "failed": true,
  "message": "login required"
}"#;

const XFYUN_NO_SUBSCRIPTION_FIXTURE: &str = r#"{
  "code": 0,
  "data": {
    "rows": []
  },
  "succeed": true
}"#;

const XFYUN_MISSING_USAGE_FIXTURE: &str = r#"{
  "code": 0,
  "data": {
    "rows": [
      {
        "name": "Efficient",
        "expiresAt": "2026-06-28 17:48:58",
        "status": 1
      }
    ]
  },
  "succeed": true
}"#;

#[derive(Debug, Default)]
pub struct XfyunCodingPlanProvider;

impl XfyunCodingPlanProvider {
    pub fn check_failed_login_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, XFYUN_FAILED_LOGIN_FIXTURE)
    }

    pub fn check_no_subscription_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, XFYUN_NO_SUBSCRIPTION_FIXTURE)
    }

    pub fn check_missing_usage_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, XFYUN_MISSING_USAGE_FIXTURE)
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

        XfyunCredential::from_secret(&credential.secret)?;
        parse_xfyun_coding_plan(value)
    }
}

impl ProviderClient for XfyunCodingPlanProvider {
    fn provider_id(&self) -> &'static str {
        "xfyun_coding_plan"
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

        let xfyun_credential = XfyunCredential::from_secret(&credential.secret)?;
        let response = transport.send(
            ProviderHttpRequest::get(XFYUN_CODING_PLAN_LIST_URL)
                .header("Accept", "application/json, text/plain, */*")
                .header("Cookie", &xfyun_credential.cookie_header)
                .header("Referer", "https://maas.xfyun.cn/packageSubscription"),
        )?;
        if response.status == 401 || response.status == 403 {
            return Err(xfyun_login_required());
        }
        if response.status != 200 {
            return Err(ProviderError::QuotaUnavailable(format!(
                "XFYun coding plan endpoint returned HTTP {}",
                response.status
            )));
        }

        parse_xfyun_coding_plan(&response.body)
    }

    fn check_fixture_quota(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, XFYUN_CODING_PLAN_FIXTURE)
    }
}

struct XfyunCredential {
    cookie_header: String,
}

impl XfyunCredential {
    fn from_secret(secret: &str) -> Result<Self, ProviderError> {
        let trimmed = secret.trim();
        if trimmed.is_empty() || trimmed == "{}" {
            return Err(xfyun_login_required());
        }

        let cookie = serde_json::from_str::<Value>(trimmed)
            .ok()
            .and_then(|value| {
                first_string(
                    &value,
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

        if cookie.contains("ssoSessionId=") && cookie.contains("tenantToken=") {
            Ok(Self {
                cookie_header: cookie,
            })
        } else {
            Err(xfyun_login_required())
        }
    }
}

fn xfyun_login_required() -> ProviderError {
    ProviderError::Unauthorized("XFYun web login authorization is required".to_string())
}

fn parse_xfyun_coding_plan(value: &str) -> Result<QuotaSnapshot, ProviderError> {
    let response: XfyunCodingPlanList =
        serde_json::from_str(value).map_err(|error| ProviderError::Parse(error.to_string()))?;
    if response.code == Some(4001) || response.failed == Some(true) {
        return Err(xfyun_login_required());
    }
    if response.code != Some(0) && response.succeed != Some(true) {
        return Err(ProviderError::QuotaUnavailable(
            "XFYun quota is unavailable".to_string(),
        ));
    }

    let rows = response.data.map(|data| data.rows).unwrap_or_default();
    if rows.is_empty() {
        return Err(ProviderError::NoSubscribedPlan(
            "XFYun coding plan was not found".to_string(),
        ));
    }

    let plan = rows
        .iter()
        .find(|plan| plan.status == Some(1) && plan.coding_plan_usage_dto.is_some())
        .or_else(|| {
            rows.iter()
                .find(|plan| plan.coding_plan_usage_dto.is_some())
        })
        .ok_or_else(|| ProviderError::QuotaUnavailable("XFYun quota is unavailable".to_string()))?;
    let usage = plan
        .coding_plan_usage_dto
        .as_ref()
        .ok_or_else(|| ProviderError::QuotaUnavailable("XFYun quota is unavailable".to_string()))?;

    let mut windows = Vec::new();
    if let Some(limit) = usage.rp5h_limit.filter(|limit| *limit > 0.0) {
        windows.push(count_window(
            "5h",
            limit - usage.rp5h_usage.unwrap_or_default(),
            limit,
            None,
        ));
    }
    if let Some(limit) = usage.rpw_limit.filter(|limit| *limit > 0.0) {
        windows.push(count_window(
            "week",
            limit - usage.rpw_usage.unwrap_or_default(),
            limit,
            None,
        ));
    }
    if let Some(limit) = usage.package_limit.filter(|limit| *limit > 0.0) {
        let left = usage
            .package_left
            .unwrap_or_else(|| limit - usage.package_usage.unwrap_or_default());
        windows.push(count_window("month", left, limit, None));
    }

    let windows = order_windows(windows);
    if windows.is_empty() {
        return Err(ProviderError::QuotaUnavailable(
            "XFYun quota is unavailable".to_string(),
        ));
    }

    Ok(snapshot_from_windows(
        "xfyun_coding_plan",
        windows,
        None,
        plan.expires_at.clone(),
    ))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct XfyunCodingPlanList {
    code: Option<i64>,
    data: Option<XfyunPageData>,
    succeed: Option<bool>,
    failed: Option<bool>,
}

#[derive(Debug, Deserialize)]
struct XfyunPageData {
    rows: Vec<XfyunPlan>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct XfyunPlan {
    expires_at: Option<String>,
    status: Option<i64>,
    #[serde(rename = "codingPlanUsageDTO")]
    coding_plan_usage_dto: Option<XfyunUsage>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct XfyunUsage {
    package_left: Option<f64>,
    package_limit: Option<f64>,
    package_usage: Option<f64>,
    rp5h_limit: Option<f64>,
    rp5h_usage: Option<f64>,
    rpw_limit: Option<f64>,
    rpw_usage: Option<f64>,
}

fn count_window(name: &str, remaining: f64, limit: f64, reset_at: Option<String>) -> QuotaWindow {
    let safe_limit = limit.max(0.0);
    let safe_remaining = remaining.max(0.0).min(limit.max(0.0));
    let percent = if safe_limit > 0.0 {
        round_percent(safe_remaining / safe_limit * 100.0)
    } else {
        0.0
    };

    QuotaWindow {
        name: name.to_string(),
        percent_remaining: Some(percent),
        remaining_text: Some(format!(
            "{} / {}",
            safe_remaining.floor() as i64,
            safe_limit.floor() as i64
        )),
        reset_at,
    }
}

fn snapshot_from_windows(
    provider_id: &str,
    windows: Vec<QuotaWindow>,
    reset_at: Option<String>,
    plan_ends_at: Option<String>,
) -> QuotaSnapshot {
    let remaining_basis_points = windows
        .iter()
        .filter_map(window_basis_points)
        .fold(10_000.0, f64::min);

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
    }
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

fn window_basis_points(window: &QuotaWindow) -> Option<f64> {
    if let Some(text) = window.remaining_text.as_deref() {
        let (remaining, limit) = text.split_once(" / ")?;
        let remaining = remaining.parse::<f64>().ok()?;
        let limit = limit.parse::<f64>().ok()?;
        if limit > 0.0 {
            return Some((remaining.max(0.0).min(limit) / limit * 10_000.0).floor());
        }
    }

    window
        .percent_remaining
        .map(|percent| (percent.clamp(0.0, 100.0) * 100.0).floor())
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
