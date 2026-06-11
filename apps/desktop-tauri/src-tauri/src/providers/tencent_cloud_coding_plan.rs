use chrono::{DateTime, FixedOffset, NaiveDateTime, SecondsFormat, TimeZone, Utc};
use serde_json::Value;

use crate::domain::QuotaWindow;

use super::{
    ProviderClient, ProviderCredential, ProviderError, ProviderHttpRequest, ProviderTransport,
    QuotaSnapshot,
};

const TENCENT_CLOUD_CODING_PLAN_CAPI_URL: &str = "https://console.cloud.tencent.com/cgi/capi";

const TENCENT_CLOUD_CODING_PLAN_FIXTURE: &str = r#"{
  "code": 0,
  "data": {
    "code": 0,
    "cgwerrorCode": 0,
    "data": {
      "Response": {
        "RequestId": "request-redacted",
        "PkgList": [
          {
            "PkgName": "Lite",
            "PkgType": "lite",
            "Status": "Normal",
            "StartTime": "2026-06-01 00:00:00",
            "EndTime": "2026-07-01 00:00:00",
            "RemainingDays": 22,
            "UsageDetail": {
              "PerFiveHour": {
                "Used": 12,
                "Total": 1200,
                "UsagePercent": 1,
                "EndTime": "2026-06-08 06:00:00"
              },
              "PerWeek": {
                "Used": 900,
                "Total": 9000,
                "UsagePercent": 10,
                "EndTime": "2026-06-15 00:00:00"
              },
              "PerMonth": {
                "Used": 3600,
                "Total": 18000,
                "UsagePercent": 20,
                "EndTime": "2026-07-01 00:00:00"
              }
            }
          }
        ]
      }
    }
  },
  "mccode": 0
}"#;

const TENCENT_CLOUD_NO_SUBSCRIPTION_FIXTURE: &str = r#"{
  "code": 0,
  "data": {
    "code": 0,
    "cgwerrorCode": 0,
    "data": {
      "Response": {
        "RequestId": "request-redacted",
        "TotalCount": 0
      }
    }
  },
  "mccode": 0
}"#;

const TENCENT_CLOUD_LOGIN_FAILURE_FIXTURE: &str = r#"{
  "code": 7,
  "mccode": 7,
  "msg": "login state validation failed (UIN_OR_SKEY_MISSING)",
  "uiMsg": "login state validation failed"
}"#;

#[derive(Debug, Default)]
pub struct TencentCloudCodingPlanProvider;

impl TencentCloudCodingPlanProvider {
    pub fn check_no_subscription_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, TENCENT_CLOUD_NO_SUBSCRIPTION_FIXTURE)
    }

    pub fn check_login_failure_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, TENCENT_CLOUD_LOGIN_FAILURE_FIXTURE)
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

        TencentCloudCredential::from_secret(&credential.secret)?;
        parse_tencent_cloud_coding_plan(value)
    }
}

impl ProviderClient for TencentCloudCodingPlanProvider {
    fn provider_id(&self) -> &'static str {
        "tencent_cloud_coding_plan"
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

        let tencent_credential = TencentCloudCredential::from_secret(&credential.secret)?;
        let response = transport.send(tencent_cloud_describe_pkg_request(&tencent_credential))?;
        if response.status == 401 || response.status == 403 {
            return Err(tencent_login_required());
        }
        if response.status != 200 {
            return Err(ProviderError::QuotaUnavailable(format!(
                "Tencent Cloud coding plan endpoint returned HTTP {}",
                response.status
            )));
        }

        parse_tencent_cloud_coding_plan(&response.body)
    }

    fn check_fixture_quota(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, TENCENT_CLOUD_CODING_PLAN_FIXTURE)
    }
}

struct TencentCloudCredential {
    cookie_header: String,
    csrf_token: String,
    uin: String,
    owner_uin: String,
}

impl TencentCloudCredential {
    fn from_secret(secret: &str) -> Result<Self, ProviderError> {
        let trimmed = secret.trim();
        if trimmed.is_empty() || trimmed == "{}" {
            return Err(tencent_login_required());
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

        let uin = parsed
            .as_ref()
            .and_then(|value| first_string(value, &["uin", "UIN"]))
            .or_else(|| cookie_value(&cookie, "uin"))
            .and_then(|value| numeric_tencent_cookie(&value))
            .ok_or_else(tencent_login_required)?;
        let owner_uin = parsed
            .as_ref()
            .and_then(|value| first_string(value, &["ownerUin", "owneruin", "owner_uin"]))
            .or_else(|| cookie_value(&cookie, "ownerUin"))
            .and_then(|value| numeric_tencent_cookie(&value))
            .unwrap_or_else(|| uin.clone());
        let csrf_token = parsed
            .as_ref()
            .and_then(|value| first_string(value, &["skey", "p_skey", "pSkey", "csrfToken"]))
            .or_else(|| cookie_value(&cookie, "skey"))
            .or_else(|| cookie_value(&cookie, "p_skey"))
            .filter(|value| !value.trim().is_empty())
            .ok_or_else(tencent_login_required)?;

        Ok(Self {
            cookie_header: cookie,
            csrf_token,
            uin,
            owner_uin,
        })
    }
}

fn tencent_cloud_describe_pkg_request(credential: &TencentCloudCredential) -> ProviderHttpRequest {
    let timestamp_ms = Utc::now().timestamp_millis();
    let csrf_code = tencent_cloud_csrf_code(&credential.csrf_token);
    let url = format!(
        "{TENCENT_CLOUD_CODING_PLAN_CAPI_URL}?cmd=DescribePkg&action=delegate&serviceType=hunyuan&secure=1&version=3&json=1&dictId=3216&sts=1&t={timestamp_ms}&uin={}&ownerUin={}&csrfCode={csrf_code}",
        credential.uin, credential.owner_uin
    );

    ProviderHttpRequest::post(&url)
        .header("Accept", "application/json, text/plain, */*")
        .header("Content-Type", "application/json")
        .header("Cookie", &credential.cookie_header)
        .header("Origin", "https://console.cloud.tencent.com")
        .header("Referer", "https://console.cloud.tencent.com/tokenhub/codingplan")
        .header("User-Agent", "Mozilla/5.0")
        .body(
            r#"{"regionId":1,"serviceType":"hunyuan","cmd":"DescribePkg","data":{"Version":"2023-09-01","Language":"zh-CN"}}"#,
        )
}

fn numeric_tencent_cookie(value: &str) -> Option<String> {
    let digits = value
        .chars()
        .filter(|character| character.is_ascii_digit())
        .collect::<String>();
    if digits.is_empty() {
        None
    } else {
        Some(digits)
    }
}

fn tencent_cloud_csrf_code(token: &str) -> String {
    let mut hash: u32 = 5381;
    for unit in token.encode_utf16() {
        hash = hash.wrapping_add(hash << 5).wrapping_add(u32::from(unit));
    }
    (hash & 0x7fff_ffff).to_string()
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

fn tencent_login_required() -> ProviderError {
    ProviderError::Unauthorized("Tencent Cloud web login authorization is required".to_string())
}

fn parse_tencent_cloud_coding_plan(value: &str) -> Result<QuotaSnapshot, ProviderError> {
    let envelope: Value =
        serde_json::from_str(value).map_err(|error| ProviderError::Parse(error.to_string()))?;
    validate_tencent_status(&envelope, &["code", "mccode"])?;
    if let Some(data) = envelope.get("data") {
        validate_tencent_status(data, &["code", "cgwerrorCode"])?;
    }

    let response = envelope
        .get("data")
        .and_then(|data| data.get("data"))
        .and_then(|data| data.get("Response"))
        .or_else(|| envelope.get("data").and_then(|data| data.get("Response")))
        .or_else(|| envelope.get("Response"))
        .ok_or_else(|| {
            ProviderError::QuotaUnavailable("Tencent Cloud quota is unavailable".to_string())
        })?;

    if response.get("Error").is_some() {
        return Err(ProviderError::QuotaUnavailable(
            "Tencent Cloud quota is unavailable".to_string(),
        ));
    }

    let Some(packages) = response.get("PkgList").and_then(Value::as_array) else {
        if first_number(response, &["TotalCount"]) == Some(0.0) {
            return Err(ProviderError::NoSubscribedPlan(
                "Tencent Cloud coding plan was not found".to_string(),
            ));
        }
        return Err(ProviderError::QuotaUnavailable(
            "Tencent Cloud quota is unavailable".to_string(),
        ));
    };
    if packages.is_empty() {
        return Err(ProviderError::NoSubscribedPlan(
            "Tencent Cloud coding plan was not found".to_string(),
        ));
    }

    let package = packages
        .iter()
        .find(|package| {
            first_string(package, &["Status"])
                .map(|status| status.to_lowercase().contains("normal"))
                .unwrap_or(false)
                && package.get("UsageDetail").is_some()
        })
        .or_else(|| {
            packages
                .iter()
                .find(|package| package.get("UsageDetail").is_some())
        })
        .ok_or_else(|| {
            ProviderError::QuotaUnavailable("Tencent Cloud quota is unavailable".to_string())
        })?;
    let usage = package.get("UsageDetail").ok_or_else(|| {
        ProviderError::QuotaUnavailable("Tencent Cloud quota is unavailable".to_string())
    })?;

    let windows = order_windows(
        [
            tencent_usage_window("5h", usage.get("PerFiveHour")),
            tencent_usage_window("week", usage.get("PerWeek")),
            tencent_usage_window("month", usage.get("PerMonth")),
        ]
        .into_iter()
        .flatten()
        .collect(),
    );
    if windows.is_empty() {
        return Err(ProviderError::QuotaUnavailable(
            "Tencent Cloud quota is unavailable".to_string(),
        ));
    }

    let reset_at = tightest_window_reset(&windows);
    Ok(snapshot_from_windows(
        "tencent_cloud_coding_plan",
        windows,
        reset_at,
        local_datetime_value_to_iso(package.get("EndTime")),
    ))
}

fn validate_tencent_status(value: &Value, keys: &[&str]) -> Result<(), ProviderError> {
    for key in keys {
        if let Some(code) = value.get(*key).and_then(|value| {
            value
                .as_i64()
                .or_else(|| value.as_str()?.parse::<i64>().ok())
        }) {
            if code != 0 {
                let message = first_string(value, &["msg", "uiMsg"]).unwrap_or_default();
                if code == 7
                    || message.contains("UIN_OR_SKEY")
                    || message.to_lowercase().contains("login")
                {
                    return Err(tencent_login_required());
                }
                return Err(ProviderError::QuotaUnavailable(
                    "Tencent Cloud quota is unavailable".to_string(),
                ));
            }
        }
    }
    Ok(())
}

fn tencent_usage_window(name: &str, value: Option<&Value>) -> Option<QuotaWindow> {
    let source = value?;
    let total = first_number(source, &["Total"])?;
    if total <= 0.0 {
        return None;
    }
    let used = first_number(source, &["Used"]).unwrap_or(0.0);
    let remaining = (total - used).max(0.0);
    let percent = first_number(source, &["UsagePercent"])
        .map(|usage_percent| 100.0 - usage_percent)
        .unwrap_or_else(|| remaining / total * 100.0);

    Some(QuotaWindow {
        name: name.to_string(),
        percent_remaining: Some(round_percent(percent.max(0.0))),
        remaining_text: Some(format!(
            "{} / {}",
            remaining.floor() as i64,
            total.floor() as i64
        )),
        reset_at: local_datetime_value_to_iso(source.get("EndTime")),
    })
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

fn tightest_window_reset(windows: &[QuotaWindow]) -> Option<String> {
    windows
        .iter()
        .filter(|window| window.reset_at.is_some())
        .min_by(|left, right| {
            let left_basis = window_basis_points(left).unwrap_or(10_000.0);
            let right_basis = window_basis_points(right).unwrap_or(10_000.0);
            left_basis.total_cmp(&right_basis)
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

fn local_datetime_value_to_iso(value: Option<&Value>) -> Option<String> {
    let value = value?.as_str()?;
    let parsed = NaiveDateTime::parse_from_str(value, "%Y-%m-%d %H:%M:%S").ok()?;
    let timezone = FixedOffset::east_opt(8 * 3600)?;
    let date_time = timezone.from_local_datetime(&parsed).single()?;
    let utc: DateTime<Utc> = date_time.with_timezone(&Utc);
    Some(utc.to_rfc3339_opts(SecondsFormat::Secs, true))
}

fn first_number(value: &Value, keys: &[&str]) -> Option<f64> {
    keys.iter()
        .find_map(|key| value.get(*key))
        .and_then(|value| {
            value
                .as_f64()
                .or_else(|| value.as_str()?.parse::<f64>().ok())
        })
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
