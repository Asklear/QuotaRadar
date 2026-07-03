use chrono::{DateTime, SecondsFormat, Utc};
use serde::Deserialize;
use serde_json::Value;

use crate::domain::QuotaWindow;

use super::{
    ProviderClient, ProviderCredential, ProviderError, ProviderHttpRequest, ProviderTransport,
    QuotaSnapshot,
};

const CODEX_SESSION_URL: &str = "https://chatgpt.com/api/auth/session";
const CODEX_WHAM_USAGE_URL: &str = "https://chatgpt.com/backend-api/wham/usage";
const CODEX_RESET_CREDITS_URL: &str =
    "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits";
const CODEX_RESET_CREDITS_CONSUME_URL: &str =
    "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits/consume";

const CODEX_WHAM_USAGE_FIXTURE: &str = r#"{
  "plan_type": "pro",
  "rate_limit": {
    "allowed": true,
    "limit_reached": false,
    "primary_window": {
      "used_percent": 0,
      "limit_window_seconds": 18000,
      "reset_after_seconds": 18000,
      "reset_at": 1780924878
    },
    "secondary_window": {
      "used_percent": 70,
      "limit_window_seconds": 604800,
      "reset_after_seconds": 233270,
      "reset_at": 1781140147
    }
  },
  "additional_rate_limits": [],
  "credits": {
    "has_credits": false,
    "unlimited": false,
    "balance": "0"
  }
}"#;

const CODEX_SUBSCRIPTION_LIFECYCLE_FIXTURE: &str = r#"{
  "active_start": "2026-06-08T16:42:25Z",
  "active_until": "2026-07-08T16:42:25Z",
  "billing_period": "monthly",
  "plan_type": "pro",
  "will_renew": true
}"#;

const CODEX_MISSING_RATE_LIMIT_FIXTURE: &str = r#"{
  "plan_type": "pro",
  "credits": {
    "has_credits": false,
    "unlimited": false,
    "balance": "0"
  }
}"#;

#[derive(Debug, Default)]
pub struct CodexSubscriptionProvider;

impl CodexSubscriptionProvider {
    pub fn consume_reset_credit(
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

        let codex_credential = CodexCredential::from_secret(&credential.secret)?;
        let session = fetch_codex_session(&codex_credential, transport)?;
        let account_id = session
            .account_id
            .as_deref()
            .filter(|account_id| !account_id.is_empty())
            .ok_or_else(|| {
                ProviderError::QuotaUnavailable("Codex account id is unavailable".to_string())
            })?;
        let consume_response = transport.send(codex_reset_credit_consume_request(
            &codex_credential,
            &session.access_token,
            account_id,
        ))?;
        if consume_response.status == 401 || consume_response.status == 403 {
            return Err(codex_login_required());
        }
        if !(200..300).contains(&consume_response.status) {
            return Err(ProviderError::QuotaUnavailable(format!(
                "Codex reset credits endpoint returned HTTP {}",
                consume_response.status
            )));
        }

        check_codex_quota_for_session(&session, transport)
    }

    pub fn check_missing_rate_limit_fixture(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(
            credential,
            CODEX_MISSING_RATE_LIMIT_FIXTURE,
            Some(CODEX_SUBSCRIPTION_LIFECYCLE_FIXTURE),
        )
    }

    fn check_response_fixture(
        &self,
        credential: ProviderCredential,
        usage_value: &str,
        lifecycle_value: Option<&str>,
    ) -> Result<QuotaSnapshot, ProviderError> {
        if credential.provider_id != self.provider_id() {
            return Err(ProviderError::Unsupported(format!(
                "credential belongs to {}",
                credential.provider_id
            )));
        }

        CodexCredential::from_secret(&credential.secret)?;
        parse_codex_subscription_usage(usage_value, lifecycle_value, None)
    }
}

impl ProviderClient for CodexSubscriptionProvider {
    fn provider_id(&self) -> &'static str {
        "codex"
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

        let codex_credential = CodexCredential::from_secret(&credential.secret)?;
        let session = fetch_codex_session(&codex_credential, transport)?;
        check_codex_quota_for_session(&session, transport)
    }

    fn check_fixture_quota(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(
            credential,
            CODEX_WHAM_USAGE_FIXTURE,
            Some(CODEX_SUBSCRIPTION_LIFECYCLE_FIXTURE),
        )
    }
}

struct CodexCredential {
    cookie_header: String,
}

impl CodexCredential {
    fn from_secret(secret: &str) -> Result<Self, ProviderError> {
        let trimmed = secret.trim();
        if trimmed.is_empty() || trimmed == "{}" {
            return Err(codex_login_required());
        }

        let candidate = serde_json::from_str::<Value>(trimmed)
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

        if contains_chatgpt_session_cookie(&candidate) {
            Ok(Self {
                cookie_header: candidate,
            })
        } else {
            Err(codex_login_required())
        }
    }
}

struct CodexSession {
    access_token: String,
    account_id: Option<String>,
}

fn codex_session_request(credential: &CodexCredential) -> ProviderHttpRequest {
    ProviderHttpRequest::get(CODEX_SESSION_URL)
        .header("Accept", "application/json")
        .header("Cookie", &credential.cookie_header)
}

fn fetch_codex_session(
    credential: &CodexCredential,
    transport: &dyn ProviderTransport,
) -> Result<CodexSession, ProviderError> {
    let session_response = transport.send(codex_session_request(credential))?;
    if session_response.status == 401 || session_response.status == 403 {
        return Err(codex_login_required());
    }
    if session_response.status != 200 {
        return Err(ProviderError::Unauthorized(format!(
            "ChatGPT session endpoint returned HTTP {}",
            session_response.status
        )));
    }

    parse_codex_session(&session_response.body)
}

fn check_codex_quota_for_session(
    session: &CodexSession,
    transport: &dyn ProviderTransport,
) -> Result<QuotaSnapshot, ProviderError> {
    let usage_response = transport.send(codex_authorized_request(
        CODEX_WHAM_USAGE_URL,
        &session.access_token,
    ))?;
    if usage_response.status == 401 || usage_response.status == 403 {
        return Err(codex_login_required());
    }
    if usage_response.status != 200 {
        return Err(ProviderError::QuotaUnavailable(format!(
            "Codex usage endpoint returned HTTP {}",
            usage_response.status
        )));
    }

    let mut lifecycle_response = None;
    let mut reset_credit_metadata = None;
    if let Some(account_id) = session.account_id.as_deref() {
        let url = format!("https://chatgpt.com/backend-api/subscriptions?account_id={account_id}");
        let response = transport.send(codex_authorized_request(&url, &session.access_token))?;
        if response.status == 401 || response.status == 403 {
            return Err(codex_login_required());
        }
        if response.status == 200 {
            lifecycle_response = Some(response.body);
        }

        if let Ok(response) = transport.send(codex_account_authorized_request(
            CODEX_RESET_CREDITS_URL,
            &session.access_token,
            account_id,
        )) {
            if response.status == 200 {
                reset_credit_metadata = parse_codex_reset_credit_metadata(&response.body).ok();
            }
        }
    }

    parse_codex_subscription_usage(
        &usage_response.body,
        lifecycle_response.as_deref(),
        reset_credit_metadata,
    )
}

fn codex_authorized_request(url: &str, access_token: &str) -> ProviderHttpRequest {
    ProviderHttpRequest::get(url)
        .header("Accept", "application/json")
        .header("Authorization", &format!("Bearer {access_token}"))
}

fn codex_account_authorized_request(
    url: &str,
    access_token: &str,
    account_id: &str,
) -> ProviderHttpRequest {
    codex_authorized_request(url, access_token).header("chatgpt-account-id", account_id)
}

fn codex_reset_credit_consume_request(
    credential: &CodexCredential,
    access_token: &str,
    account_id: &str,
) -> ProviderHttpRequest {
    let body = serde_json::json!({
        "redeem_request_id": uuid::Uuid::new_v4().to_string()
    })
    .to_string();

    ProviderHttpRequest::post(CODEX_RESET_CREDITS_CONSUME_URL)
        .header("Accept", "application/json")
        .header("Content-Type", "application/json")
        .header("Authorization", &format!("Bearer {access_token}"))
        .header("Cookie", &credential.cookie_header)
        .header("chatgpt-account-id", account_id)
        .header("originator", "codex_cli_rs")
        .body(&body)
}

fn codex_login_required() -> ProviderError {
    ProviderError::Unauthorized("ChatGPT web login authorization is required".to_string())
}

fn contains_chatgpt_session_cookie(value: &str) -> bool {
    value.contains("__Secure-next-auth.session-token") || value.contains("__search-next-auth")
}

fn parse_codex_session(value: &str) -> Result<CodexSession, ProviderError> {
    let parsed: Value =
        serde_json::from_str(value).map_err(|error| ProviderError::Parse(error.to_string()))?;
    let access_token = first_string(
        &parsed,
        &[
            "accessToken",
            "access_token",
            "sessionAccessToken",
            "session_access_token",
        ],
    )
    .ok_or_else(codex_login_required)?;
    let account_id = first_string(&parsed, &["account_id", "accountId"]).or_else(|| {
        parsed
            .get("account")
            .and_then(|account| first_string(account, &["id", "account_id", "accountId"]))
    });

    Ok(CodexSession {
        access_token,
        account_id,
    })
}

fn parse_codex_subscription_usage(
    usage_value: &str,
    lifecycle_value: Option<&str>,
    reset_credit_metadata: Option<CodexResetCreditMetadata>,
) -> Result<QuotaSnapshot, ProviderError> {
    let usage: CodexUsageResponse = serde_json::from_str(usage_value)
        .map_err(|error| ProviderError::Parse(error.to_string()))?;
    let rate_limit = usage
        .rate_limit
        .ok_or_else(|| ProviderError::QuotaUnavailable("Codex usage is unavailable".to_string()))?;

    let mut windows = Vec::new();
    if let Some(primary_window) = rate_limit.primary_window {
        if let Some(window) = codex_percent_quota_window(
            quota_window_name(primary_window.limit_window_seconds).unwrap_or("5h"),
            primary_window.used_percent,
            primary_window.reset_at,
        ) {
            windows.push(window);
        }
    }
    if let Some(secondary_window) = rate_limit.secondary_window {
        if let Some(window) = codex_percent_quota_window(
            quota_window_name(secondary_window.limit_window_seconds).unwrap_or("week"),
            secondary_window.used_percent,
            secondary_window.reset_at,
        ) {
            windows.push(window);
        }
    }

    let windows = order_windows(windows);
    if windows.is_empty() {
        return Err(ProviderError::QuotaUnavailable(
            "Codex usage is unavailable".to_string(),
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
        provider_id: "codex".to_string(),
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
        plan_ends_at: lifecycle_value.and_then(parse_codex_subscription_lifecycle),
        codex_reset_credits_remaining: reset_credit_metadata
            .as_ref()
            .and_then(|metadata| metadata.available_count),
        codex_reset_credits_earliest_expires_at: reset_credit_metadata
            .and_then(|metadata| metadata.earliest_expires_at),
    })
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct CodexResetCreditMetadata {
    available_count: Option<u32>,
    earliest_expires_at: Option<String>,
}

#[derive(Debug, Deserialize)]
struct CodexResetCreditsResponse {
    available_count: Option<i64>,
    credits: Option<Vec<CodexResetCredit>>,
}

#[derive(Debug, Deserialize)]
struct CodexResetCredit {
    status: Option<String>,
    expires_at: Option<String>,
    redeemed_at: Option<Value>,
}

fn parse_codex_reset_credit_metadata(
    value: &str,
) -> Result<CodexResetCreditMetadata, ProviderError> {
    let parsed: CodexResetCreditsResponse =
        serde_json::from_str(value).map_err(|error| ProviderError::Parse(error.to_string()))?;
    let available_count = parsed
        .available_count
        .filter(|count| *count >= 0)
        .and_then(|count| u32::try_from(count).ok());
    let earliest_expires_at = parsed
        .credits
        .unwrap_or_default()
        .into_iter()
        .filter(available_reset_credit)
        .filter_map(|credit| {
            let expires_at = credit.expires_at?;
            let parsed = DateTime::parse_from_rfc3339(&expires_at).ok()?;
            Some((parsed, expires_at))
        })
        .min_by(|left, right| left.0.cmp(&right.0))
        .map(|(_, expires_at)| expires_at);

    Ok(CodexResetCreditMetadata {
        available_count,
        earliest_expires_at,
    })
}

fn available_reset_credit(credit: &CodexResetCredit) -> bool {
    if credit
        .redeemed_at
        .as_ref()
        .is_some_and(|redeemed_at| !redeemed_at.is_null())
    {
        return false;
    }

    !matches!(
        credit
            .status
            .as_deref()
            .map(str::to_ascii_lowercase)
            .as_deref(),
        Some("redeemed" | "consumed" | "expired" | "used")
    )
}

#[derive(Debug, Deserialize)]
struct CodexUsageResponse {
    rate_limit: Option<CodexRateLimit>,
}

#[derive(Debug, Deserialize)]
struct CodexRateLimit {
    primary_window: Option<CodexUsageWindow>,
    secondary_window: Option<CodexUsageWindow>,
}

#[derive(Debug, Deserialize)]
struct CodexUsageWindow {
    used_percent: Option<f64>,
    limit_window_seconds: Option<i64>,
    reset_at: Option<f64>,
}

fn codex_percent_quota_window(
    name: &str,
    used_percent: Option<f64>,
    reset_at: Option<f64>,
) -> Option<QuotaWindow> {
    let used_percent = used_percent?;
    Some(QuotaWindow {
        name: name.to_string(),
        percent_remaining: Some(round_percent((100.0 - used_percent).max(0.0))),
        remaining_text: None,
        reset_at: reset_at.and_then(epoch_seconds_to_iso8601),
    })
}

fn parse_codex_subscription_lifecycle(value: &str) -> Option<String> {
    let parsed = serde_json::from_str::<Value>(value).ok()?;
    first_string(
        &parsed,
        &["active_until", "current_period_end", "expires_at"],
    )
}

fn quota_window_name(seconds: Option<i64>) -> Option<&'static str> {
    match seconds? {
        18_000 => Some("5h"),
        604_800 => Some("week"),
        2_419_200..=2_678_400 => Some("month"),
        _ => None,
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

fn epoch_seconds_to_iso8601(seconds: f64) -> Option<String> {
    if seconds <= 0.0 {
        return None;
    }
    let seconds = seconds.trunc() as i64;
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
