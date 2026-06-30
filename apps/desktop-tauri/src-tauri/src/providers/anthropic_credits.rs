use serde_json::Value;

use super::{
    ProviderClient, ProviderCredential, ProviderError, ProviderHttpRequest, ProviderTransport,
    QuotaSnapshot,
};

const CLAUDE_ORGANIZATIONS_URL: &str = "https://claude.ai/api/organizations";

const ANTHROPIC_CREDITS_ORGANIZATIONS_FIXTURE: &str = r#"[
  {
    "uuid": "org-redacted",
    "name": "Personal",
    "active": true
  }
]"#;

const ANTHROPIC_CREDITS_FIXTURE: &str = r#"{
  "amount": 42.5
}"#;

#[derive(Debug, Default)]
pub struct AnthropicCreditsProvider;

impl AnthropicCreditsProvider {
    fn check_response_fixture(
        &self,
        credential: ProviderCredential,
        organizations_value: &str,
        credits_value: &str,
    ) -> Result<QuotaSnapshot, ProviderError> {
        if credential.provider_id != self.provider_id() {
            return Err(ProviderError::Unsupported(format!(
                "credential belongs to {}",
                credential.provider_id
            )));
        }

        ClaudeWebCredential::from_secret(&credential.secret)?;
        let _organization_id = parse_claude_organization_id(organizations_value)?;
        parse_anthropic_credits(credits_value)
    }
}

impl ProviderClient for AnthropicCreditsProvider {
    fn provider_id(&self) -> &'static str {
        "anthropic_credits"
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

        let claude_credential = ClaudeWebCredential::from_secret(&credential.secret)?;
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
        let credits_url =
            format!("https://claude.ai/api/organizations/{organization_id}/prepaid/credits");
        let credits_response = transport.send(claude_request(&credits_url, &claude_credential))?;
        if credits_response.status == 401 || credits_response.status == 403 {
            return Err(claude_login_required());
        }
        if credits_response.status != 200 {
            return Err(ProviderError::QuotaUnavailable(format!(
                "Anthropic Credits endpoint returned HTTP {}",
                credits_response.status
            )));
        }

        parse_anthropic_credits(&credits_response.body)
    }

    fn check_fixture_quota(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        self.check_response_fixture(
            credential,
            ANTHROPIC_CREDITS_ORGANIZATIONS_FIXTURE,
            ANTHROPIC_CREDITS_FIXTURE,
        )
    }
}

struct ClaudeWebCredential {
    cookie_header: String,
}

impl ClaudeWebCredential {
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

fn claude_request(url: &str, credential: &ClaudeWebCredential) -> ProviderHttpRequest {
    ProviderHttpRequest::get(url)
        .header("Accept", "application/json")
        .header("Cookie", &credential.cookie_header)
}

fn claude_login_required() -> ProviderError {
    ProviderError::Unauthorized("Claude web login authorization is required".to_string())
}

fn parse_anthropic_credits(value: &str) -> Result<QuotaSnapshot, ProviderError> {
    let parsed: Value =
        serde_json::from_str(value).map_err(|error| ProviderError::Parse(error.to_string()))?;
    let amount = first_number(&parsed, &["amount", "balance", "credits"]).or_else(|| {
        parsed
            .get("data")
            .and_then(|data| first_number(data, &["amount", "balance", "credits"]))
    });
    let amount = amount.ok_or_else(|| {
        ProviderError::QuotaUnavailable("Anthropic Credits balance is unavailable".to_string())
    })?;

    Ok(QuotaSnapshot {
        provider_id: "anthropic_credits".to_string(),
        remaining: Some(amount),
        limit: Some(amount),
        remaining_badge_text: format!("{} credits", format_amount(amount)),
        quota_label: Some("credits".to_string()),
        quota_windows: Vec::new(),
        reset_at: None,
        plan_ends_at: None,
        codex_reset_credits_remaining: None,
        codex_reset_credits_earliest_expires_at: None,
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

fn format_amount(value: f64) -> String {
    if (value.fract()).abs() < f64::EPSILON {
        format!("{}", value as i64)
    } else {
        let formatted = format!("{value:.2}");
        formatted.trim_end_matches('0').trim_end_matches('.').to_string()
    }
}
