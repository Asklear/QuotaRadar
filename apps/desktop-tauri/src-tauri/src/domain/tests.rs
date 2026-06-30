use serde_json::json;

use super::{
    AppState, CredentialKind, CredentialStatus, CredentialView, ProviderCategory,
    ProviderDefinition, QuotaWindow,
};

#[test]
fn app_state_serializes_with_frontend_contract_field_names() {
    let state = AppState::mock();
    let value = serde_json::to_value(state).expect("app state should serialize");

    assert_eq!(value["providers"][0]["displayName"], "Tavily");
    assert_eq!(
        value["providers"][0]["quotaCheckConsumesSearchQuota"],
        false
    );
    assert_eq!(value["credentials"][0]["maskedValue"], "tvly••••9Q2a");
    assert_eq!(value["credentials"][0]["quotaWindows"][0]["name"], "month");
    assert!(value["providers"][0].get("display_name").is_none());
    assert!(value["credentials"][0].get("masked_value").is_none());
}

#[test]
fn credential_view_serializes_optional_http_and_timing_fields() {
    let credential = CredentialView {
        id: "codex-web-expired".to_string(),
        provider_id: "codex".to_string(),
        name: "Codex Pro Login".to_string(),
        kind: CredentialKind::DashboardCookie,
        masked_value: "Web login expired".to_string(),
        copyable: false,
        active: true,
        status: CredentialStatus::Expired,
        remaining: None,
        limit: None,
        remaining_badge_text: "Login expired".to_string(),
        quota_label: None,
        quota_windows: vec![QuotaWindow {
            name: "week".to_string(),
            percent_remaining: Some(0.0),
            remaining_text: None,
            reset_at: Some("2026-06-15T00:00:00+08:00".to_string()),
        }],
        reset_at: None,
        plan_ends_at: Some("2026-07-01T00:00:00+08:00".to_string()),
        codex_reset_credits_remaining: Some(2),
        codex_reset_credits_earliest_expires_at: Some("2026-07-18T00:38:14Z".to_string()),
        last_updated: Some("2026-06-11T09:30:00+08:00".to_string()),
        last_http_status: Some(401),
        diagnostic_message: Some("Web login authorization expired.".to_string()),
        note: None,
        linked_authorization_id: None,
    };

    let value = serde_json::to_value(credential).expect("credential should serialize");

    assert_eq!(
        value,
        json!({
            "id": "codex-web-expired",
            "providerId": "codex",
            "name": "Codex Pro Login",
            "kind": "dashboardCookie",
            "maskedValue": "Web login expired",
            "copyable": false,
            "active": true,
            "status": "expired",
            "remaining": null,
            "limit": null,
            "remainingBadgeText": "Login expired",
            "quotaLabel": null,
            "quotaWindows": [{
                "name": "week",
                "percentRemaining": 0.0,
                "remainingText": null,
                "resetAt": "2026-06-15T00:00:00+08:00"
            }],
            "resetAt": null,
            "planEndsAt": "2026-07-01T00:00:00+08:00",
            "codexResetCreditsRemaining": 2,
            "codexResetCreditsEarliestExpiresAt": "2026-07-18T00:38:14Z",
            "lastUpdated": "2026-06-11T09:30:00+08:00",
            "lastHttpStatus": 401,
            "diagnosticMessage": "Web login authorization expired.",
            "note": null,
            "linkedAuthorizationId": null
        })
    );
}

#[test]
fn provider_definition_serializes_category_and_plan_labels() {
    let provider = ProviderDefinition {
        id: "claude".to_string(),
        display_name: "Claude".to_string(),
        family_name: "Anthropic".to_string(),
        category: ProviderCategory::Llm,
        plan_type: Some("Pro".to_string()),
        icon: "claude".to_string(),
        dashboard_url: Some("https://claude.ai/settings/billing".to_string()),
        supports_reauth: true,
        supports_refresh: true,
        quota_check_consumes_search_quota: false,
        hidden: None,
    };

    let value = serde_json::to_value(provider).expect("provider should serialize");

    assert_eq!(value["category"], "LLM");
    assert_eq!(value["planType"], "Pro");
    assert_eq!(value["supportsReauth"], true);
}
