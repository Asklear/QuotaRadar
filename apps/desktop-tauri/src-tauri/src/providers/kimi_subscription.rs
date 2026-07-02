use serde_json::Value;

use crate::domain::QuotaWindow;

use super::{
    ProviderClient, ProviderCredential, ProviderError, ProviderHttpRequest, ProviderTransport,
    QuotaSnapshot,
};

const KIMI_MEMBERSHIP_URL: &str =
    "https://www.kimi.com/apiv2/kimi.gateway.membership.v2.MembershipService/GetSubscription";
const KIMI_BILLING_USAGE_URL: &str =
    "https://www.kimi.com/apiv2/kimi.gateway.billing.v1.BillingService/GetUsages";

const KIMI_SUBSCRIPTION_FIXTURE: &str = r#"{
  "subscribed": true,
  "balances": [
    {
      "type": "SUBSCRIPTION",
      "unit": "UNIT_CREDIT",
      "amountUsedRatio": 0.916,
      "expireTime": "2026-06-15T08:54:48.861440Z"
    }
  ]
}"#;

const KIMI_USAGE_FIXTURE: &str = r#"{
  "usages": [
    {
      "scope": "FEATURE_CODING",
      "limits": [
        {
          "name": "5h",
          "detail": {
            "limit": 1000,
            "remaining": 960,
            "resetAt": "2026-06-11T13:00:00Z"
          }
        },
        {
          "name": "week",
          "detail": {
            "limit": 1000,
            "remaining": 780,
            "resetAt": "2026-06-15T00:00:00Z"
          }
        }
      ]
    }
  ]
}"#;

const KIMI_OAUTH_USAGE_FIXTURE: &str = r#"{
  "limits": [
    {
      "name": "5h",
      "detail": {
        "limit": 1000,
        "remaining": 750
      }
    },
    {
      "name": "week",
      "detail": {
        "limit": 1000,
        "remaining": 300
      }
    }
  ]
}"#;

const KIMI_NO_SUBSCRIPTION_FIXTURE: &str = r#"{
  "subscribed": false
}"#;

const KIMI_QUOTA_UNAVAILABLE_FIXTURE: &str = r#"{
  "subscribed": true,
  "plan": {
    "name": "Kimi"
  }
}"#;

#[derive(Debug, Default)]
pub struct KimiSubscriptionProvider;

impl KimiSubscriptionProvider {
    pub fn check_oauth_usage_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(
            credential,
            KIMI_QUOTA_UNAVAILABLE_FIXTURE,
            Some(KIMI_OAUTH_USAGE_FIXTURE),
        )
    }

    pub fn check_no_subscription_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, KIMI_NO_SUBSCRIPTION_FIXTURE, None)
    }

    pub fn check_quota_unavailable_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, KIMI_QUOTA_UNAVAILABLE_FIXTURE, None)
    }

    fn check_response_fixture(
        &self,
        credential: ProviderCredential,
        subscription_value: &str,
        usage_value: Option<&str>,
    ) -> Result<QuotaSnapshot, ProviderError> {
        if credential.provider_id != self.provider_id() {
            return Err(ProviderError::Unsupported(format!(
                "credential belongs to {}",
                credential.provider_id
            )));
        }

        KimiCredential::from_secret(&credential.secret)?;
        parse_kimi_subscription_usage(subscription_value, usage_value)
    }
}

impl ProviderClient for KimiSubscriptionProvider {
    fn provider_id(&self) -> &'static str {
        "kimi"
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

        let kimi_credential = KimiCredential::from_secret(&credential.secret)?;
        let subscription_response =
            transport.send(kimi_request(KIMI_MEMBERSHIP_URL, "{}", &kimi_credential))?;
        if subscription_response.status == 401 || subscription_response.status == 403 {
            return Err(ProviderError::Unauthorized(
                "Kimi login authorization is unauthorized".to_string(),
            ));
        }
        if subscription_response.status != 200 {
            return Err(ProviderError::QuotaUnavailable(format!(
                "Kimi membership endpoint returned HTTP {}",
                subscription_response.status
            )));
        }

        let usage_response = transport.send(kimi_request(
            KIMI_BILLING_USAGE_URL,
            r#"{"scope":["FEATURE_CODING"]}"#,
            &kimi_credential,
        ))?;
        if usage_response.status == 401 || usage_response.status == 403 {
            return Err(ProviderError::Unauthorized(
                "Kimi login authorization is unauthorized".to_string(),
            ));
        }
        if usage_response.status != 200 {
            return Err(ProviderError::QuotaUnavailable(format!(
                "Kimi billing usage endpoint returned HTTP {}",
                usage_response.status
            )));
        }

        parse_kimi_subscription_usage(&subscription_response.body, Some(&usage_response.body))
    }

    fn check_fixture_quota(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(
            credential,
            KIMI_SUBSCRIPTION_FIXTURE,
            Some(KIMI_USAGE_FIXTURE),
        )
    }
}

struct KimiCredential {
    access_token: String,
    cookie: Option<String>,
    device_id: Option<String>,
    session_id: Option<String>,
    traffic_id: Option<String>,
}

impl KimiCredential {
    fn from_secret(secret: &str) -> Result<Self, ProviderError> {
        let trimmed = secret.trim();
        if trimmed.is_empty() || trimmed == "{}" {
            return Err(ProviderError::Unauthorized(
                "Kimi access token is required".to_string(),
            ));
        }

        if let Ok(value) = serde_json::from_str::<Value>(trimmed) {
            let token = first_string(
                &value,
                &[
                    "accessToken",
                    "access_token",
                    "authorization",
                    "bearerToken",
                    "bearer_token",
                    "token",
                ],
            );
            if token.as_deref().unwrap_or_default().trim().is_empty() {
                return Err(ProviderError::Unauthorized(
                    "Kimi access token is required".to_string(),
                ));
            }

            let device_id = first_string(
                &value,
                &[
                    "deviceID",
                    "device_id",
                    "xMshDeviceId",
                    "x_msh_device_id",
                    "x-msh-device-id",
                ],
            );
            let session_id = first_string(
                &value,
                &[
                    "sessionID",
                    "session_id",
                    "xMshSessionId",
                    "x_msh_session_id",
                    "x-msh-session-id",
                ],
            );
            let traffic_id = first_string(
                &value,
                &[
                    "trafficID",
                    "traffic_id",
                    "xTrafficId",
                    "x_traffic_id",
                    "x-traffic-id",
                ],
            );
            if device_id.is_none() && session_id.is_none() && traffic_id.is_none() {
                return Err(ProviderError::Unauthorized(
                    "Kimi session metadata is required".to_string(),
                ));
            }

            return Ok(Self {
                access_token: token.expect("token was checked above"),
                cookie: first_string(&value, &["cookie", "Cookie", "cookies"])
                    .or_else(|| first_string(&value, &["kimiAuth", "kimi_auth", "kimi-auth"]))
                    .map(normalized_kimi_cookie),
                device_id,
                session_id,
                traffic_id,
            });
        }

        Err(ProviderError::Unauthorized(
            "Kimi session metadata is required".to_string(),
        ))
    }
}

fn kimi_request(url: &str, body: &str, credential: &KimiCredential) -> ProviderHttpRequest {
    let mut request = ProviderHttpRequest::post(url)
        .header(
            "Authorization",
            &format!("Bearer {}", credential.access_token),
        )
        .header("Accept", "*/*")
        .header("Content-Type", "application/json")
        .header("connect-protocol-version", "1")
        .header("x-language", "zh-CN")
        .header("x-msh-platform", "web")
        .header("x-msh-version", "1.0.0")
        .body(body);

    if let Some(cookie) = credential.cookie.as_deref() {
        request = request.header("Cookie", cookie);
    }
    if let Some(device_id) = credential.device_id.as_deref() {
        request = request.header("x-msh-device-id", device_id);
    }
    if let Some(session_id) = credential.session_id.as_deref() {
        request = request.header("x-msh-session-id", session_id);
    }
    if let Some(traffic_id) = credential.traffic_id.as_deref() {
        request = request.header("x-traffic-id", traffic_id);
    }

    request
}

fn normalized_kimi_cookie(value: String) -> String {
    if value.contains('=') {
        value
    } else {
        format!("{}={value}", "kimi-auth")
    }
}

fn parse_kimi_subscription_usage(
    subscription_value: &str,
    usage_value: Option<&str>,
) -> Result<QuotaSnapshot, ProviderError> {
    let subscription: Value = serde_json::from_str(subscription_value)
        .map_err(|error| ProviderError::Parse(error.to_string()))?;
    let usage = usage_value
        .map(serde_json::from_str::<Value>)
        .transpose()
        .map_err(|error| ProviderError::Parse(error.to_string()))?;

    let plan_ends_at =
        kimi_plan_end_date(&subscription).or_else(|| usage.as_ref().and_then(kimi_plan_end_date));
    let mut windows = Vec::new();

    if let Some(usage) = usage.as_ref() {
        windows.extend(kimi_usage_windows(usage));
    }
    if let Some(window) = kimi_subscription_balance_window(&subscription, plan_ends_at.as_deref())
        .or_else(|| {
            usage
                .as_ref()
                .and_then(|usage| kimi_subscription_balance_window(usage, plan_ends_at.as_deref()))
        })
    {
        windows.push(window);
    }

    windows = order_windows(deduplicate_windows(windows));
    if !windows.is_empty() {
        return Ok(QuotaSnapshot {
            provider_id: "kimi".to_string(),
            remaining: None,
            limit: None,
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
            reset_at: None,
            plan_ends_at,
            codex_reset_credits_remaining: None,
            codex_reset_credits_earliest_expires_at: None,
        });
    }

    if bool_at(&subscription, "subscribed") == Some(false) {
        return Err(ProviderError::NoSubscribedPlan(
            "Kimi subscription was not found".to_string(),
        ));
    }

    Ok(QuotaSnapshot {
        provider_id: "kimi".to_string(),
        remaining: None,
        limit: None,
        remaining_badge_text: "Usable · quota unknown".to_string(),
        quota_label: Some("subscription".to_string()),
        quota_windows: Vec::new(),
        reset_at: None,
        plan_ends_at,
        codex_reset_credits_remaining: None,
        codex_reset_credits_earliest_expires_at: None,
    })
}

fn kimi_usage_windows(value: &Value) -> Vec<QuotaWindow> {
    let mut windows = Vec::new();

    if let Some(limits) = value.get("limits").and_then(Value::as_array) {
        windows.extend(limits.iter().filter_map(kimi_usage_limit_window));
    }

    if let Some(usages) = value.get("usages").and_then(Value::as_array) {
        let selected = usages
            .iter()
            .find(|usage| {
                string_at(usage, "scope")
                    .map(|scope| scope.eq_ignore_ascii_case("FEATURE_CODING"))
                    .unwrap_or(false)
            })
            .or_else(|| usages.first());
        if let Some(selected) = selected {
            if let Some(limits) = selected.get("limits").and_then(Value::as_array) {
                windows.extend(limits.iter().filter_map(kimi_usage_limit_window));
            }
        }
    }

    windows
}

fn kimi_usage_limit_window(item: &Value) -> Option<QuotaWindow> {
    let detail = item
        .get("detail")
        .or_else(|| item.get("usage"))
        .unwrap_or(item);
    let name = string_at(item, "name")
        .and_then(|value| normalized_kimi_window_name(&value))
        .unwrap_or_else(|| "week".to_string());
    kimi_usage_detail_window(&name, detail)
}

fn kimi_usage_detail_window(name: &str, source: &Value) -> Option<QuotaWindow> {
    let limit = first_number(source, &["limit", "total", "quota", "amount"])?;
    if limit <= 0.0 {
        return None;
    }
    let remaining = first_number(
        source,
        &["remaining", "remain", "left", "amountLeft", "amount_left"],
    )
    .or_else(|| {
        first_number(source, &["used", "usage", "amountUsed"]).map(|used| (limit - used).max(0.0))
    })?;
    let safe_remaining = remaining.max(0.0).min(limit);

    Some(QuotaWindow {
        name: name.to_string(),
        percent_remaining: Some(round_percent(safe_remaining / limit * 100.0)),
        remaining_text: Some(format!(
            "{} / {}",
            compact_number(safe_remaining),
            compact_number(limit)
        )),
        reset_at: first_string(source, &["resetTime", "resetAt", "reset_time", "reset_at"]),
    })
}

fn kimi_subscription_balance_window(
    value: &Value,
    plan_ends_at: Option<&str>,
) -> Option<QuotaWindow> {
    let balance = value
        .get("subscription_balance")
        .or_else(|| value.get("subscriptionBalance"))
        .or_else(|| value.get("creditBalance"))
        .or_else(|| {
            value
                .get("balances")
                .and_then(Value::as_array)
                .and_then(|balances| {
                    balances
                        .iter()
                        .find(|balance| {
                            string_at(balance, "type")
                                .map(|kind| kind.to_lowercase().contains("subscription"))
                                .unwrap_or(false)
                        })
                        .or_else(|| balances.first())
                })
        })?;

    let amount = first_number(balance, &["amount", "total", "quota", "limit"]);
    let amount_left = first_number(
        balance,
        &["amount_left", "amountLeft", "left", "remaining", "remain"],
    );
    let used_ratio = first_number(
        balance,
        &[
            "amount_used_ratio",
            "amountUsedRatio",
            "used_ratio",
            "usedRatio",
            "usage_ratio",
            "usageRatio",
        ],
    );

    let (remaining_percent, remaining_text) = if let Some(amount) =
        amount.filter(|amount| *amount > 0.0)
    {
        let remaining = amount_left.or_else(|| {
            used_ratio.map(|ratio| amount * (1.0 - normalized_used_percent(ratio) / 100.0).max(0.0))
        })?;
        (
            round_percent((remaining.max(0.0) / amount * 100.0).max(0.0)),
            Some(format!(
                "{} / {}",
                compact_number(remaining),
                compact_number(amount)
            )),
        )
    } else if let Some(used_ratio) = used_ratio {
        (
            round_percent((100.0 - normalized_used_percent(used_ratio)).max(0.0)),
            None,
        )
    } else {
        return None;
    };

    Some(QuotaWindow {
        name: "month".to_string(),
        percent_remaining: Some(remaining_percent),
        remaining_text,
        reset_at: first_string(
            balance,
            &[
                "reset_time",
                "resetTime",
                "expire_time",
                "expireTime",
                "upcoming_expiration",
                "upcomingExpiration",
            ],
        )
        .or_else(|| plan_ends_at.map(ToString::to_string)),
    })
}

fn kimi_plan_end_date(value: &Value) -> Option<String> {
    first_string(
        value,
        &[
            "planEndsAt",
            "plan_ends_at",
            "expireTime",
            "expire_time",
            "endTime",
            "end_time",
        ],
    )
    .or_else(|| {
        value
            .get("balances")
            .and_then(Value::as_array)
            .and_then(|balances| {
                balances
                    .iter()
                    .find_map(|balance| first_string(balance, &["expireTime", "expire_time"]))
            })
    })
}

fn deduplicate_windows(windows: Vec<QuotaWindow>) -> Vec<QuotaWindow> {
    let mut seen = Vec::<String>::new();
    windows
        .into_iter()
        .filter(|window| {
            if seen.contains(&window.name) {
                false
            } else {
                seen.push(window.name.clone());
                true
            }
        })
        .collect()
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

fn normalized_kimi_window_name(value: &str) -> Option<String> {
    let normalized = value.trim().to_lowercase();
    if normalized.contains("5h") || normalized.contains("five") || normalized.contains("300") {
        return Some("5h".to_string());
    }
    if normalized.contains("week") || normalized.contains("weekly") || normalized.contains("7d") {
        return Some("week".to_string());
    }
    if normalized.contains("month") || normalized.contains("monthly") {
        return Some("month".to_string());
    }
    None
}

fn normalized_used_percent(value: f64) -> f64 {
    if value.abs() <= 1.0 {
        value * 100.0
    } else {
        value
    }
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

fn compact_number(value: f64) -> String {
    if (value.fract()).abs() < f64::EPSILON {
        format!("{}", value as i64)
    } else {
        format!("{value:.1}")
    }
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

fn bool_at(value: &Value, key: &str) -> Option<bool> {
    value.get(key).and_then(Value::as_bool)
}
