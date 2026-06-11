use serde::Serialize;

use super::QuotaWindow;

#[derive(Debug, Clone, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub enum CredentialKind {
    ApiKey,
    DashboardCookie,
    AdminCredential,
    StoredApiKeyOnly,
}

#[derive(Debug, Clone, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub enum CredentialStatus {
    Healthy,
    Failed,
    Expired,
    UsageLimitExceeded,
    Disabled,
    UnknownQuotaUsable,
    NotChecked,
    Unsupported,
    NoSubscribedPlan,
    ManualRefreshOnly,
}

#[derive(Debug, Clone, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct CredentialView {
    pub id: String,
    pub provider_id: String,
    pub name: String,
    pub kind: CredentialKind,
    pub masked_value: String,
    pub copyable: bool,
    pub active: bool,
    pub status: CredentialStatus,
    pub remaining: Option<f64>,
    pub limit: Option<f64>,
    pub remaining_badge_text: String,
    pub quota_label: Option<String>,
    pub quota_windows: Vec<QuotaWindow>,
    pub reset_at: Option<String>,
    pub plan_ends_at: Option<String>,
    pub last_updated: Option<String>,
    pub last_http_status: Option<u16>,
    pub diagnostic_message: Option<String>,
    pub note: Option<String>,
    pub linked_authorization_id: Option<String>,
}

impl CredentialView {
    #[allow(clippy::too_many_arguments)]
    pub fn api_key(
        id: &str,
        provider_id: &str,
        name: &str,
        masked_value: &str,
        status: CredentialStatus,
        remaining_badge_text: &str,
        remaining: Option<f64>,
        limit: Option<f64>,
        quota_windows: Vec<QuotaWindow>,
        reset_at: Option<&str>,
        last_updated: Option<&str>,
        last_http_status: Option<u16>,
    ) -> Self {
        Self {
            id: id.to_string(),
            provider_id: provider_id.to_string(),
            name: name.to_string(),
            kind: CredentialKind::ApiKey,
            masked_value: masked_value.to_string(),
            copyable: true,
            active: true,
            status,
            remaining,
            limit,
            remaining_badge_text: remaining_badge_text.to_string(),
            quota_label: None,
            quota_windows,
            reset_at: reset_at.map(ToString::to_string),
            plan_ends_at: None,
            last_updated: last_updated.map(ToString::to_string),
            last_http_status,
            diagnostic_message: None,
            note: None,
            linked_authorization_id: None,
        }
    }

    #[allow(clippy::too_many_arguments)]
    pub fn web_login(
        id: &str,
        provider_id: &str,
        name: &str,
        masked_value: &str,
        status: CredentialStatus,
        remaining_badge_text: &str,
        quota_windows: Vec<QuotaWindow>,
        plan_ends_at: Option<&str>,
        last_updated: Option<&str>,
        last_http_status: Option<u16>,
    ) -> Self {
        Self {
            id: id.to_string(),
            provider_id: provider_id.to_string(),
            name: name.to_string(),
            kind: CredentialKind::DashboardCookie,
            masked_value: masked_value.to_string(),
            copyable: false,
            active: true,
            status,
            remaining: None,
            limit: None,
            remaining_badge_text: remaining_badge_text.to_string(),
            quota_label: None,
            quota_windows,
            reset_at: None,
            plan_ends_at: plan_ends_at.map(ToString::to_string),
            last_updated: last_updated.map(ToString::to_string),
            last_http_status,
            diagnostic_message: None,
            note: None,
            linked_authorization_id: None,
        }
    }

    pub fn stored_api_key(
        id: &str,
        provider_id: &str,
        name: &str,
        masked_value: &str,
        remaining_badge_text: &str,
        linked_authorization_id: Option<&str>,
        last_updated: Option<&str>,
    ) -> Self {
        Self {
            id: id.to_string(),
            provider_id: provider_id.to_string(),
            name: name.to_string(),
            kind: CredentialKind::StoredApiKeyOnly,
            masked_value: masked_value.to_string(),
            copyable: true,
            active: true,
            status: CredentialStatus::NotChecked,
            remaining: None,
            limit: None,
            remaining_badge_text: remaining_badge_text.to_string(),
            quota_label: None,
            quota_windows: Vec::new(),
            reset_at: None,
            plan_ends_at: None,
            last_updated: last_updated.map(ToString::to_string),
            last_http_status: None,
            diagnostic_message: None,
            note: None,
            linked_authorization_id: linked_authorization_id.map(ToString::to_string),
        }
    }

    pub fn with_diagnostic_message(mut self, diagnostic_message: &str) -> Self {
        self.diagnostic_message = Some(diagnostic_message.to_string());
        self
    }

    pub fn with_note(mut self, note: &str) -> Self {
        self.note = Some(note.to_string());
        self
    }

    pub fn with_quota_label(mut self, quota_label: &str) -> Self {
        self.quota_label = Some(quota_label.to_string());
        self
    }
}
