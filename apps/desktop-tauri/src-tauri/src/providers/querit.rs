use serde_json::Value;

use crate::domain::QuotaWindow;

use super::{
    ProviderClient, ProviderCredential, ProviderError, ProviderHttpRequest, ProviderTransport,
    QuotaSnapshot,
};

const QUERIT_ACCOUNT_URL: &str = "https://www.querit.ai/api/v1/user/account";

const QUERIT_ACCOUNT_FIXTURE: &str = r#"{
  "ErrNo": 200,
  "Data": {
    "current_plan": {
      "free_usage_month": 4,
      "paid_usage_month": 6,
      "enterprise_usage_month": 0,
      "coupon_quota": 100,
      "coupon_used": 20
    }
  }
}"#;

const QUERIT_USAGE_WITHOUT_LIMIT_FIXTURE: &str = r#"{
  "ErrNo": 200,
  "Data": {
    "current_plan": {
      "free_usage_month": 10,
      "paid_usage_month": 5,
      "enterprise_usage_month": 2,
      "coupon_used": 7
    }
  }
}"#;

const QUERIT_LOGIN_FAILURE_FIXTURE: &str = r#"{
  "ErrNo": 401,
  "ErrMsg": "login required"
}"#;

#[derive(Debug, Default)]
pub struct QueritProvider;

impl QueritProvider {
    pub fn check_usage_without_limit_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, 200, QUERIT_USAGE_WITHOUT_LIMIT_FIXTURE)
    }

    pub fn check_login_failure_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, 200, QUERIT_LOGIN_FAILURE_FIXTURE)
    }

    fn check_response_fixture(
        &self,
        credential: ProviderCredential,
        http_status: u16,
        value: &str,
    ) -> Result<QuotaSnapshot, ProviderError> {
        if credential.provider_id != self.provider_id() {
            return Err(ProviderError::Unsupported(format!(
                "credential belongs to {}",
                credential.provider_id
            )));
        }

        QueritCredential::from_secret(&credential.secret)?;
        parse_querit_account(http_status, value)
    }
}

impl ProviderClient for QueritProvider {
    fn provider_id(&self) -> &'static str {
        "querit"
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

        let querit_credential = QueritCredential::from_secret(&credential.secret)?;
        let response = transport.send(querit_account_request(&querit_credential))?;
        if response.status == 401 || response.status == 403 {
            return Err(querit_login_required());
        }
        if response.status != 200 {
            return Err(ProviderError::QuotaUnavailable(format!(
                "Querit account endpoint returned HTTP {}",
                response.status
            )));
        }

        parse_querit_account(response.status, &response.body)
    }

    fn check_fixture_quota(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(credential, 200, QUERIT_ACCOUNT_FIXTURE)
    }
}

struct QueritCredential {
    cookie_header: String,
}

impl QueritCredential {
    fn from_secret(secret: &str) -> Result<Self, ProviderError> {
        let trimmed = secret.trim();
        if trimmed.is_empty() || trimmed == "{}" {
            return Err(querit_login_required());
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

        if cookie_value(&cookie, "osduss").is_some()
            && cookie_value(&cookie, "passOsRefreshTk").is_some()
            && cookie_value(&cookie, "osfuid").is_some()
        {
            Ok(Self {
                cookie_header: cookie,
            })
        } else {
            Err(querit_login_required())
        }
    }
}

fn querit_account_request(credential: &QueritCredential) -> ProviderHttpRequest {
    ProviderHttpRequest::get(QUERIT_ACCOUNT_URL)
        .header("Accept", "application/json")
        .header("Accept-Language", "zh-CN,zh;q=0.9")
        .header("Cache-Control", "no-cache")
        .header("Pragma", "no-cache")
        .header("Cookie", &credential.cookie_header)
        .header("Referer", "https://www.querit.ai/zh/dashboard/home")
        .header("User-Agent", "Mozilla/5.0")
}

fn parse_querit_account(http_status: u16, value: &str) -> Result<QuotaSnapshot, ProviderError> {
    if http_status == 401 || http_status == 403 {
        return Err(querit_login_required());
    }

    let response: Value =
        serde_json::from_str(value).map_err(|error| ProviderError::Parse(error.to_string()))?;
    if let Some(error_number) = first_number(&response, &["ErrNo", "errNo", "code"]) {
        if (error_number - 200.0).abs() > f64::EPSILON {
            if matches!(error_number as i64, 401 | 403) || login_message(&response) {
                return Err(querit_login_required());
            }
            return Err(ProviderError::QuotaUnavailable(
                "Querit account quota is unavailable".to_string(),
            ));
        }
    }

    let plan = response
        .get("Data")
        .or_else(|| response.get("data"))
        .and_then(|data| data.get("current_plan").or_else(|| data.get("currentPlan")))
        .ok_or_else(|| {
            ProviderError::QuotaUnavailable("Querit account quota is unavailable".to_string())
        })?;

    let coupon_quota = first_number(plan, &["coupon_quota", "couponQuota"]).unwrap_or(0.0);
    let coupon_used = first_number(plan, &["coupon_used", "couponUsed"]).unwrap_or(0.0);
    let used = first_number(plan, &["free_usage_month", "freeUsageMonth"]).unwrap_or(0.0)
        + first_number(plan, &["paid_usage_month", "paidUsageMonth"]).unwrap_or(0.0)
        + first_number(plan, &["enterprise_usage_month", "enterpriseUsageMonth"]).unwrap_or(0.0)
        + coupon_used;

    if coupon_quota <= 0.0 {
        return Ok(QuotaSnapshot {
            provider_id: "querit".to_string(),
            remaining: None,
            limit: None,
            remaining_badge_text: format!("{} monthly requests used", format_count(used)),
            quota_label: Some("monthly requests".to_string()),
            quota_windows: vec![],
            reset_at: None,
            plan_ends_at: None,
            codex_reset_credits_remaining: None,
            codex_reset_credits_earliest_expires_at: None,
        });
    }

    let remaining = (coupon_quota - coupon_used).max(0.0);
    let percent_remaining = if coupon_quota > 0.0 {
        round_percent(remaining / coupon_quota * 100.0)
    } else {
        0.0
    };
    let remaining_text = format!(
        "{} / {}",
        format_count(remaining),
        format_count(coupon_quota)
    );

    Ok(QuotaSnapshot {
        provider_id: "querit".to_string(),
        remaining: Some(remaining),
        limit: Some(coupon_quota),
        remaining_badge_text: format!("{remaining_text} monthly requests"),
        quota_label: Some("monthly requests".to_string()),
        quota_windows: vec![QuotaWindow {
            name: "month".to_string(),
            percent_remaining: Some(percent_remaining),
            remaining_text: Some(remaining_text),
            reset_at: None,
        }],
        reset_at: None,
        plan_ends_at: None,
        codex_reset_credits_remaining: None,
        codex_reset_credits_earliest_expires_at: None,
    })
}

fn querit_login_required() -> ProviderError {
    ProviderError::Unauthorized("Querit web login authorization is required".to_string())
}

fn login_message(value: &Value) -> bool {
    first_string(value, &["ErrMsg", "errMsg", "message", "msg"])
        .map(|message| {
            let lower = message.to_lowercase();
            lower.contains("login") || lower.contains("auth")
        })
        .unwrap_or(false)
}

fn first_number(value: &Value, keys: &[&str]) -> Option<f64> {
    keys.iter()
        .find_map(|key| value.get(*key))
        .and_then(|value| {
            value
                .as_f64()
                .or_else(|| value.as_str()?.parse::<f64>().ok())
        })
        .map(|value| value.max(0.0).floor())
}

fn first_string(value: &Value, keys: &[&str]) -> Option<String> {
    keys.iter()
        .find_map(|key| value.get(*key))
        .and_then(|value| value.as_str().map(ToString::to_string))
        .filter(|value| !value.trim().is_empty())
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

fn round_percent(value: f64) -> f64 {
    (value * 10.0).round() / 10.0
}

fn format_count(value: f64) -> String {
    let rounded = value.floor();
    if rounded <= i64::MAX as f64 {
        (rounded as i64).to_string()
    } else {
        rounded.to_string()
    }
}
