use chrono::{DateTime, SecondsFormat, Utc};
use serde_json::Value;

use crate::domain::QuotaWindow;

use super::{ProviderClient, ProviderCredential, ProviderError, QuotaSnapshot};

const ALIYUN_INSTANCE_INFO_FIXTURE: &str = r#"{
  "code": "200",
  "data": {
    "DataV2": {
      "ret": ["SUCCESS::ok"],
      "data": {
        "data": {
          "codingPlanInstanceInfos": [
            {
              "instanceName": "Coding Plan Pro",
              "instanceType": "pro",
              "status": "VALID",
              "instanceStartTime": 1772064682000,
              "instanceEndTime": 1782489600000,
              "remainingDays": 17,
              "codingPlanQuotaInfo": {
                "per5HourUsedQuota": 43,
                "per5HourTotalQuota": 6000,
                "per5HourQuotaNextRefreshTime": 1780980997000,
                "perWeekUsedQuota": 165,
                "perWeekTotalQuota": 45000,
                "perWeekQuotaNextRefreshTime": 1781452800000,
                "perBillMonthUsedQuota": 2913,
                "perBillMonthTotalQuota": 90000,
                "perBillMonthQuotaNextRefreshTime": 1782489600000
              }
            }
          ],
          "userId": "redacted"
        },
        "success": true,
        "failed": false
      }
    }
  },
  "successResponse": true
}"#;

const ALIYUN_USAGE_DETAIL_FIXTURE: &str = r#"{
  "code": "200",
  "data": {
    "DataV2": {
      "data": {
        "data": {
          "hasCodingPlan": true,
          "clawQuota": 2,
          "codingPlanInfo": {
            "instanceType": "Lite",
            "status": "VALID",
            "startTime": 1780858373000,
            "endTime": 1783448373000,
            "remainingDays": 30,
            "usageDetail": {
              "perFiveHour": {
                "used": 20,
                "total": 1000
              },
              "perWeek": {
                "used": 1200,
                "total": 6000
              },
              "perMonth": {
                "used": 2000,
                "total": 10000
              }
            }
          }
        },
        "success": true,
        "failed": false
      }
    }
  },
  "successResponse": true
}"#;

const ALIYUN_NO_SUBSCRIPTION_STATUS_FIXTURE: &str = r#"{
  "code": "200",
  "data": {
    "DataV2": {
      "data": {
        "data": {
          "hasCodingPlan": false,
          "clawQuota": 0
        },
        "success": true,
        "failed": false
      }
    }
  },
  "successResponse": true
}"#;

const ALIYUN_EMPTY_SUBSCRIPTION_LIST_FIXTURE: &str = r#"{
  "code": "200",
  "data": {
    "DataV2": {
      "ret": ["SUCCESS::ok"],
      "data": {
        "data": {
          "codingPlanInstanceInfos": [],
          "userId": "redacted"
        },
        "success": true,
        "failed": false
      }
    }
  },
  "successResponse": true
}"#;

const ALIYUN_MISSING_QUOTA_FIXTURE: &str = r#"{
  "code": "200",
  "data": {
    "DataV2": {
      "data": {
        "data": {
          "hasCodingPlan": true,
          "codingPlanInfo": {
            "status": "VALID",
            "endTime": 1783448373000
          }
        },
        "success": true,
        "failed": false
      }
    }
  },
  "successResponse": true
}"#;

#[derive(Debug, Default)]
pub struct AliyunCodingPlanProvider;

impl AliyunCodingPlanProvider {
    pub fn check_usage_detail_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, ALIYUN_USAGE_DETAIL_FIXTURE)
    }

    pub fn check_no_subscription_status_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, ALIYUN_NO_SUBSCRIPTION_STATUS_FIXTURE)
    }

    pub fn check_empty_subscription_list_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, ALIYUN_EMPTY_SUBSCRIPTION_LIST_FIXTURE)
    }

    pub fn check_missing_quota_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, ALIYUN_MISSING_QUOTA_FIXTURE)
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

        AliyunCredential::from_secret(&credential.secret)?;
        parse_aliyun_coding_plan(value)
    }
}

impl ProviderClient for AliyunCodingPlanProvider {
    fn provider_id(&self) -> &'static str {
        "aliyun_coding_plan"
    }

    fn consumes_quota_on_check(&self) -> bool {
        false
    }

    fn check_fixture_quota(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, ALIYUN_INSTANCE_INFO_FIXTURE)
    }
}

struct AliyunCredential;

impl AliyunCredential {
    fn from_secret(secret: &str) -> Result<Self, ProviderError> {
        let trimmed = secret.trim();
        if trimmed.is_empty() || trimmed == "{}" {
            return Err(aliyun_login_required());
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

        if cookie.contains("login_aliyunid_ticket=") && cookie.contains("cna=") {
            Ok(Self)
        } else {
            Err(aliyun_login_required())
        }
    }
}

fn aliyun_login_required() -> ProviderError {
    ProviderError::Unauthorized("Aliyun web login authorization is required".to_string())
}

fn parse_aliyun_coding_plan(value: &str) -> Result<QuotaSnapshot, ProviderError> {
    let envelope: Value =
        serde_json::from_str(value).map_err(|error| ProviderError::Parse(error.to_string()))?;
    if let Some(code) = string_at(&envelope, "code") {
        if code != "200" && code != "0" {
            return Err(ProviderError::QuotaUnavailable(
                "Aliyun quota is unavailable".to_string(),
            ));
        }
    }

    let payload = aliyun_payload(&envelope).ok_or_else(|| {
        ProviderError::QuotaUnavailable("Aliyun quota is unavailable".to_string())
    })?;

    if let Some(instance_infos) = payload
        .get("codingPlanInstanceInfos")
        .and_then(Value::as_array)
    {
        return parse_instance_infos(instance_infos);
    }

    if payload.get("hasCodingPlan").and_then(Value::as_bool) == Some(false) {
        return Err(ProviderError::NoSubscribedPlan(
            "Aliyun coding plan was not found".to_string(),
        ));
    }

    let coding_plan_info = payload.get("codingPlanInfo").and_then(Value::as_object);
    let Some(coding_plan_info) = coding_plan_info else {
        return Err(ProviderError::QuotaUnavailable(
            "Aliyun quota is unavailable".to_string(),
        ));
    };
    let coding_plan_info = Value::Object(coding_plan_info.clone());
    let status = first_string(&coding_plan_info, &["status"]).map(|status| status.to_uppercase());
    if status.as_deref() == Some("INVALID") {
        return Err(ProviderError::NoSubscribedPlan(
            "Aliyun coding plan was not found".to_string(),
        ));
    }

    let windows = aliyun_usage_windows(&coding_plan_info);
    if windows.is_empty() {
        return Err(ProviderError::QuotaUnavailable(
            "Aliyun quota is unavailable".to_string(),
        ));
    }

    let windows = order_windows(windows);
    let reset_at = tightest_window_reset(&windows);
    Ok(snapshot_from_windows(
        "aliyun_coding_plan",
        windows,
        reset_at,
        timestamp_value_to_iso(
            coding_plan_info
                .get("endTime")
                .or_else(|| coding_plan_info.get("instanceEndTime")),
        ),
    ))
}

fn aliyun_payload(envelope: &Value) -> Option<Value> {
    if envelope.get("hasCodingPlan").and_then(Value::as_bool).is_some()
        || envelope.get("codingPlanInfo").is_some()
    {
        return Some(envelope.clone());
    }

    let inner = envelope
        .get("data")?
        .get("DataV2")?
        .get("data")?;
    if inner.get("success").and_then(Value::as_bool) == Some(false) {
        return None;
    }
    inner.get("data").cloned()
}

fn parse_instance_infos(instance_infos: &[Value]) -> Result<QuotaSnapshot, ProviderError> {
    if instance_infos.is_empty() {
        return Err(ProviderError::NoSubscribedPlan(
            "Aliyun coding plan was not found".to_string(),
        ));
    }

    let usable_instances = instance_infos
        .iter()
        .filter(|instance| {
            first_string(instance, &["status"])
                .map(|status| {
                    matches!(
                        status.to_uppercase().as_str(),
                        "VALID" | "NORMAL" | "ACTIVE"
                    )
                })
                .unwrap_or(true)
        })
        .collect::<Vec<_>>();
    let selected = usable_instances
        .iter()
        .copied()
        .find(|instance| aliyun_quota_info(instance).is_some())
        .or_else(|| usable_instances.first().copied())
        .ok_or_else(|| {
            ProviderError::NoSubscribedPlan("Aliyun coding plan was not found".to_string())
        })?;
    let quota_info = aliyun_quota_info(selected).ok_or_else(|| {
        ProviderError::QuotaUnavailable("Aliyun quota is unavailable".to_string())
    })?;

    let windows = order_windows(aliyun_instance_windows(&quota_info));
    if windows.is_empty() {
        return Err(ProviderError::QuotaUnavailable(
            "Aliyun quota is unavailable".to_string(),
        ));
    }
    let reset_at = tightest_window_reset(&windows);
    Ok(snapshot_from_windows(
        "aliyun_coding_plan",
        windows,
        reset_at,
        timestamp_value_to_iso(
            selected
                .get("instanceEndTime")
                .or_else(|| selected.get("endTime"))
                .or_else(|| selected.get("EndTime"))
                .or_else(|| selected.get("expireTime"))
                .or_else(|| selected.get("expirationTime")),
        ),
    ))
}

fn aliyun_quota_info(instance: &Value) -> Option<Value> {
    ["codingPlanQuotaInfo", "quotaInfo", "usageDetail", "codingPlanUsageDTO", "codingPlanUsage"]
        .iter()
        .find_map(|key| instance.get(*key).cloned())
        .filter(Value::is_object)
}

fn aliyun_instance_windows(quota_info: &Value) -> Vec<QuotaWindow> {
    [
        flat_window(
            "5h",
            quota_info,
            &[
                "per5HourUsedQuota",
                "perFiveHourUsedQuota",
                "rp5hUsage",
                "perFiveHourUsage",
                "fiveHourUsage",
            ],
            &[
                "per5HourTotalQuota",
                "perFiveHourTotalQuota",
                "rp5hLimit",
                "perFiveHourLimit",
                "fiveHourLimit",
            ],
            &[
                "per5HourQuotaNextRefreshTime",
                "perFiveHourQuotaNextRefreshTime",
                "rp5hNextRefreshTime",
                "perFiveHourNextRefreshTime",
            ],
        ),
        flat_window(
            "week",
            quota_info,
            &[
                "perWeekUsedQuota",
                "rpwUsage",
                "perWeekUsage",
                "weekUsage",
                "weeklyUsage",
            ],
            &[
                "perWeekTotalQuota",
                "rpwLimit",
                "perWeekLimit",
                "weekLimit",
                "weeklyLimit",
            ],
            &[
                "perWeekQuotaNextRefreshTime",
                "rpwNextRefreshTime",
                "perWeekNextRefreshTime",
                "weekNextRefreshTime",
            ],
        ),
        flat_window(
            "month",
            quota_info,
            &[
                "perBillMonthUsedQuota",
                "perMonthUsedQuota",
                "packageUsage",
                "perMonthUsage",
                "monthUsage",
                "monthlyUsage",
            ],
            &[
                "perBillMonthTotalQuota",
                "perMonthTotalQuota",
                "packageLimit",
                "perMonthLimit",
                "monthLimit",
                "monthlyLimit",
            ],
            &[
                "perBillMonthQuotaNextRefreshTime",
                "perMonthQuotaNextRefreshTime",
                "packageNextRefreshTime",
                "monthNextRefreshTime",
            ],
        ),
    ]
    .into_iter()
    .flatten()
    .collect()
}

fn flat_window(
    name: &str,
    source: &Value,
    used_keys: &[&str],
    total_keys: &[&str],
    reset_keys: &[&str],
) -> Option<QuotaWindow> {
    let total = first_number(source, total_keys)?;
    if total <= 0.0 {
        return None;
    }
    let used = first_number(source, used_keys).unwrap_or(0.0);
    let remaining = (total - used).max(0.0);
    Some(count_window(
        name,
        remaining,
        total,
        reset_keys
            .iter()
            .find_map(|key| timestamp_value_to_iso(source.get(*key))),
    ))
}

fn aliyun_usage_windows(coding_plan_info: &Value) -> Vec<QuotaWindow> {
    let usage_containers = [
        "usageDetail",
        "usage",
        "quotaUsage",
        "codingPlanUsageDTO",
        "codingPlanUsage",
    ]
    .iter()
    .filter_map(|key| coding_plan_info.get(*key))
    .filter(|value| value.is_object())
    .collect::<Vec<_>>();
    let sources = if usage_containers.is_empty() {
        vec![coding_plan_info]
    } else {
        usage_containers
    };

    for source in sources {
        let windows = [
            object_window(
                "5h",
                source,
                &["perFiveHour", "PerFiveHour", "rp5h", "fiveHour", "five_hour", "rolling"],
                &["rp5hLeft", "rp5hRemaining", "perFiveHourLeft", "fiveHourLeft"],
                &["rp5hLimit", "perFiveHourLimit", "fiveHourLimit"],
                &["rp5hUsage", "perFiveHourUsage", "fiveHourUsage"],
            ),
            object_window(
                "week",
                source,
                &["perWeek", "PerWeek", "rpw", "week", "weekly"],
                &["rpwLeft", "rpwRemaining", "perWeekLeft", "weekLeft", "weeklyLeft"],
                &["rpwLimit", "perWeekLimit", "weekLimit", "weeklyLimit"],
                &["rpwUsage", "perWeekUsage", "weekUsage", "weeklyUsage"],
            ),
            object_window(
                "month",
                source,
                &["perMonth", "PerMonth", "package", "month", "monthly"],
                &["packageLeft", "packageRemaining", "perMonthLeft", "monthLeft", "monthlyLeft"],
                &["packageLimit", "perMonthLimit", "monthLimit", "monthlyLimit"],
                &["packageUsage", "perMonthUsage", "monthUsage", "monthlyUsage"],
            ),
        ]
        .into_iter()
        .flatten()
        .collect::<Vec<_>>();

        if !windows.is_empty() {
            return windows;
        }
    }

    Vec::new()
}

fn object_window(
    name: &str,
    source: &Value,
    object_keys: &[&str],
    left_keys: &[&str],
    limit_keys: &[&str],
    usage_keys: &[&str],
) -> Option<QuotaWindow> {
    let object = object_keys
        .iter()
        .find_map(|key| source.get(*key))
        .unwrap_or(source);
    let limit = first_number(
        object,
        &["total", "Total", "limit", "Limit", "quota", "Quota"]
            .into_iter()
            .chain(limit_keys.iter().copied())
            .collect::<Vec<_>>(),
    )?;
    if limit <= 0.0 {
        return None;
    }
    let used = first_number(
        object,
        &["used", "Used", "usage", "Usage"]
            .into_iter()
            .chain(usage_keys.iter().copied())
            .collect::<Vec<_>>(),
    );
    let explicit_left = first_number(
        object,
        &["left", "Left", "remaining", "Remaining", "remain", "Remain"]
            .into_iter()
            .chain(left_keys.iter().copied())
            .collect::<Vec<_>>(),
    );
    let remaining = explicit_left.unwrap_or_else(|| limit - used.unwrap_or(0.0));
    Some(count_window(name, remaining.max(0.0), limit, None))
}

fn count_window(
    name: &str,
    remaining: f64,
    limit: f64,
    reset_at: Option<String>,
) -> QuotaWindow {
    let safe_remaining = remaining.max(0.0).min(limit.max(0.0));
    let percent = if limit > 0.0 {
        round_percent(safe_remaining / limit * 100.0)
    } else {
        0.0
    };
    QuotaWindow {
        name: name.to_string(),
        percent_remaining: Some(percent),
        remaining_text: Some(format!(
            "{} / {}",
            safe_remaining.floor() as i64,
            limit.floor() as i64
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

fn timestamp_value_to_iso(value: Option<&Value>) -> Option<String> {
    let value = value?;
    let raw = value
        .as_i64()
        .or_else(|| value.as_f64().map(|number| number as i64))
        .or_else(|| value.as_str()?.parse::<i64>().ok())?;
    let seconds = if raw > 10_000_000_000 { raw / 1000 } else { raw };
    let date_time: DateTime<Utc> = DateTime::from_timestamp(seconds, 0)?;
    Some(date_time.to_rfc3339_opts(SecondsFormat::Secs, true))
}

fn first_number(value: &Value, keys: &[&str]) -> Option<f64> {
    keys.iter()
        .find_map(|key| value.get(*key))
        .and_then(|value| value.as_f64().or_else(|| value.as_str()?.parse::<f64>().ok()))
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
