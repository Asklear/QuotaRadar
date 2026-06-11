use serde_json::Value;

use crate::domain::QuotaWindow;

use super::{
    ProviderClient, ProviderCredential, ProviderError, ProviderHttpRequest, ProviderTransport,
    QuotaSnapshot,
};

const CLAUDE_ORGANIZATIONS_URL: &str = "https://claude.ai/api/organizations";

const CLAUDE_ORGANIZATIONS_FIXTURE: &str = r#"[
  {
    "uuid": "org-redacted",
    "name": "Personal",
    "active": true
  }
]"#;

const CLAUDE_NESTED_ORGANIZATIONS_FIXTURE: &str = r#"{
  "data": {
    "organizations": [
      {
        "uuid": "org-default",
        "default": true
      },
      {
        "uuid": "org-active",
        "active": true
      }
    ]
  }
}"#;

const CLAUDE_USAGE_FIXTURE: &str = r#"{
  "five_hour": {
    "utilization": 24.5,
    "resets_at": "2026-06-09T10:00:00Z"
  },
  "seven_day": {
    "utilization": "70",
    "resets_at": "2026-06-15T00:00:00Z"
  },
  "seven_day_opus": {
    "utilization": 95,
    "resets_at": "2026-06-15T00:00:00Z"
  }
}"#;

const CLAUDE_SUBSCRIPTION_DETAILS_FIXTURE: &str = r#"{
  "status": "active",
  "billing_interval": "monthly",
  "next_charge_date": "2026-07-09",
  "next_charge_at": "2026-07-09T09:57:27Z"
}"#;

const CLAUDE_MISSING_USAGE_FIXTURE: &str = r#"{
  "seven_day_opus": {
    "utilization": 95,
    "resets_at": "2026-06-15T00:00:00Z"
  }
}"#;

#[derive(Debug, Default)]
pub struct ClaudeSubscriptionProvider;

impl ClaudeSubscriptionProvider {
    pub fn select_nested_organization_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<String, ProviderError> {
        if credential.provider_id != self.provider_id() {
            return Err(ProviderError::Unsupported(format!(
                "credential belongs to {}",
                credential.provider_id
            )));
        }

        ClaudeCredential::from_secret(&credential.secret)?;
        parse_claude_organization_id(CLAUDE_NESTED_ORGANIZATIONS_FIXTURE)
    }

    pub fn check_missing_usage_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(
            credential,
            CLAUDE_ORGANIZATIONS_FIXTURE,
            CLAUDE_MISSING_USAGE_FIXTURE,
            Some(CLAUDE_SUBSCRIPTION_DETAILS_FIXTURE),
        )
    }

    fn check_response_fixture(
        &self,
        credential: ProviderCredential,
        organizations_value: &str,
        usage_value: &str,
        details_value: Option<&str>,
    ) -> Result<QuotaSnapshot, ProviderError> {
        if credential.provider_id != self.provider_id() {
            return Err(ProviderError::Unsupported(format!(
                "credential belongs to {}",
                credential.provider_id
            )));
        }

        ClaudeCredential::from_secret(&credential.secret)?;
        let _organization_id = parse_claude_organization_id(organizations_value)?;
        parse_claude_subscription_usage(usage_value, details_value)
    }
}

impl ProviderClient for ClaudeSubscriptionProvider {
    fn provider_id(&self) -> &'static str {
        "claude"
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

        let claude_credential = ClaudeCredential::from_secret(&credential.secret)?;
        let organizations_response =
            transport.send(claude_request(CLAUDE_ORGANIZATIONS_URL, &claude_credential))?;
        if organizations_response.status == 401 || organizations_response.status == 403 {
            return Err(claude_login_required());
        }
        if organizations_response.status != 200 {
            return Err(ProviderError::QuotaUnavailable(format!(
                "Claude organizations endpoint returned HTTP {}",
                organizations_response.status
            )));
        }

        let organization_id = parse_claude_organization_id(&organizations_response.body)?;
        let usage_url = format!("https://claude.ai/api/organizations/{organization_id}/usage");
        let usage_response = transport.send(claude_request(&usage_url, &claude_credential))?;
        if usage_response.status == 401 || usage_response.status == 403 {
            return Err(claude_login_required());
        }
        if usage_response.status != 200 {
            return Err(ProviderError::QuotaUnavailable(format!(
                "Claude usage endpoint returned HTTP {}",
                usage_response.status
            )));
        }

        let details_url =
            format!("https://claude.ai/api/organizations/{organization_id}/subscription_details");
        let details_response = transport.send(claude_request(&details_url, &claude_credential))?;
        if details_response.status == 401 || details_response.status == 403 {
            return Err(claude_login_required());
        }
        let details_value = if details_response.status == 200 {
            Some(details_response.body)
        } else {
            None
        };

        parse_claude_subscription_usage(&usage_response.body, details_value.as_deref())
    }

    fn check_fixture_quota(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(
            credential,
            CLAUDE_ORGANIZATIONS_FIXTURE,
            CLAUDE_USAGE_FIXTURE,
            Some(CLAUDE_SUBSCRIPTION_DETAILS_FIXTURE),
        )
    }
}

struct ClaudeCredential {
    cookie_header: String,
}

impl ClaudeCredential {
    fn from_secret(secret: &str) -> Result<Self, ProviderError> {
        let trimmed = secret.trim();
        if trimmed.is_empty() || trimmed == "{}" {
            return Err(claude_login_required());
        }

        if let Ok(value) = serde_json::from_str::<Value>(trimmed) {
            if let Some(session_key) = first_string(&value, &["sessionKey", "session_key"]) {
                if !session_key.trim().is_empty() {
                    return Ok(Self {
                        cookie_header: normalized_claude_session_cookie(session_key),
                    });
                }
            }

            if let Some(cookie_header) = first_string(
                &value,
                &[
                    "cookie",
                    "cookieHeader",
                    "dashboardCookie",
                    "dashboard_cookie",
                    "authorizationCookie",
                ],
            ) {
                if cookie_header.contains("sessionKey=") {
                    return Ok(Self { cookie_header });
                }
            }

            return Err(claude_login_required());
        }

        if trimmed.contains("sessionKey=") {
            Ok(Self {
                cookie_header: trimmed.to_string(),
            })
        } else {
            Err(claude_login_required())
        }
    }
}

fn normalized_claude_session_cookie(value: String) -> String {
    if value.contains('=') {
        value
    } else {
        format!("{}={value}", "sessionKey")
    }
}

fn claude_request(url: &str, credential: &ClaudeCredential) -> ProviderHttpRequest {
    ProviderHttpRequest::get(url)
        .header("Accept", "application/json")
        .header("Cookie", &credential.cookie_header)
}

fn claude_login_required() -> ProviderError {
    ProviderError::Unauthorized("Claude web login authorization is required".to_string())
}

fn parse_claude_subscription_usage(
    usage_value: &str,
    details_value: Option<&str>,
) -> Result<QuotaSnapshot, ProviderError> {
    let parsed: Value = serde_json::from_str(usage_value)
        .map_err(|error| ProviderError::Parse(error.to_string()))?;
    let usage = parsed.get("usage").unwrap_or(&parsed);
    let mut windows = Vec::new();

    if let Some(window) = usage
        .get("five_hour")
        .and_then(|value| claude_usage_window("5h", value))
    {
        windows.push(window);
    }
    if let Some(window) = usage
        .get("seven_day")
        .and_then(|value| claude_usage_window("week", value))
    {
        windows.push(window);
    }

    let windows = order_windows(windows);
    if windows.is_empty() {
        return Err(ProviderError::QuotaUnavailable(
            "Claude usage is unavailable".to_string(),
        ));
    }

    let tightest_percent = windows
        .iter()
        .filter_map(|window| window.percent_remaining)
        .fold(100.0, f64::min);
    let reset_at = windows
        .iter()
        .filter(|window| window.reset_at.is_some())
        .min_by(|left, right| {
            let left_percent = left.percent_remaining.unwrap_or(100.0);
            let right_percent = right.percent_remaining.unwrap_or(100.0);
            left_percent.total_cmp(&right_percent)
        })
        .and_then(|window| window.reset_at.clone());

    Ok(QuotaSnapshot {
        provider_id: "claude".to_string(),
        remaining: Some(basis_points(tightest_percent)),
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
        plan_ends_at: details_value.and_then(parse_claude_subscription_details),
    })
}

fn claude_usage_window(name: &str, source: &Value) -> Option<QuotaWindow> {
    let used_percent = first_number(source, &["utilization", "used_percentage", "usedPercent"])?;
    Some(QuotaWindow {
        name: name.to_string(),
        percent_remaining: Some(round_percent((100.0 - used_percent).max(0.0))),
        remaining_text: None,
        reset_at: first_string(source, &["resets_at", "reset_at", "resetsAt", "resetAt"]),
    })
}

fn parse_claude_subscription_details(value: &str) -> Option<String> {
    let parsed = serde_json::from_str::<Value>(value).ok()?;
    first_string(
        &parsed,
        &[
            "next_charge_at",
            "next_charge_date",
            "current_period_end",
            "active_until",
            "expires_at",
            "ends_at",
        ],
    )
    .or_else(|| {
        parsed.get("subscription").and_then(|subscription| {
            first_string(
                subscription,
                &[
                    "next_charge_at",
                    "next_charge_date",
                    "current_period_end",
                    "active_until",
                    "expires_at",
                    "ends_at",
                ],
            )
        })
    })
}

fn parse_claude_organization_id(value: &str) -> Result<String, ProviderError> {
    let parsed: Value =
        serde_json::from_str(value).map_err(|error| ProviderError::Parse(error.to_string()))?;
    let candidates = claude_organization_candidates(&parsed);
    candidates
        .iter()
        .find(|candidate| candidate.is_active == Some(true))
        .or_else(|| {
            candidates
                .iter()
                .find(|candidate| candidate.is_default == Some(true))
        })
        .or_else(|| candidates.first())
        .and_then(|candidate| candidate.id.clone())
        .filter(|id| !id.trim().is_empty())
        .ok_or_else(|| {
            ProviderError::QuotaUnavailable("Claude organization is unavailable".to_string())
        })
}

#[derive(Debug, Clone)]
struct ClaudeOrganizationCandidate {
    id: Option<String>,
    is_active: Option<bool>,
    is_default: Option<bool>,
}

fn claude_organization_candidates(value: &Value) -> Vec<ClaudeOrganizationCandidate> {
    if let Some(organizations) = value.as_array() {
        return organizations
            .iter()
            .flat_map(claude_organization_candidates)
            .collect();
    }

    let Some(object) = value.as_object() else {
        return Vec::new();
    };

    let id = first_string(
        value,
        &["uuid", "id", "organization_uuid", "organizationUuid"],
    );
    let mut candidates = Vec::new();
    if id.is_some() {
        candidates.push(ClaudeOrganizationCandidate {
            id,
            is_active: object
                .get("active")
                .or_else(|| object.get("is_active"))
                .and_then(Value::as_bool),
            is_default: object
                .get("default")
                .or_else(|| object.get("is_default"))
                .and_then(Value::as_bool),
        });
    }

    for key in ["organizations", "data", "results", "items"] {
        if let Some(nested) = object.get(key) {
            candidates.extend(claude_organization_candidates(nested));
        }
    }

    candidates
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
