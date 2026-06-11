use super::{
    claude_subscription::ClaudeSubscriptionProvider,
    http::{MockProviderTransport, ProviderHttpResponse},
    ProviderClient, ProviderCredential, ProviderError,
};

fn claude_credential() -> ProviderCredential {
    ProviderCredential::fake_api_key("claude", "sessionKey=claude-session-placeholder")
}

#[test]
fn claude_fixture_parses_usage_windows_and_plan_end() {
    let client = ClaudeSubscriptionProvider::default();
    let snapshot = client
        .check_fixture_quota(claude_credential())
        .expect("fixture should parse");

    assert_eq!(snapshot.provider_id, "claude");
    assert_eq!(snapshot.remaining, Some(3000.0));
    assert_eq!(snapshot.limit, Some(10_000.0));
    assert_eq!(snapshot.remaining_badge_text, "5h 75.5% · week 30%");
    assert_eq!(snapshot.quota_label.as_deref(), Some("subscription"));
    assert_eq!(
        snapshot.plan_ends_at.as_deref(),
        Some("2026-07-09T09:57:27Z")
    );
    assert_eq!(snapshot.reset_at.as_deref(), Some("2026-06-15T00:00:00Z"));
    assert_eq!(snapshot.quota_windows.len(), 2);
    assert_eq!(snapshot.quota_windows[0].name, "5h");
    assert_eq!(snapshot.quota_windows[0].percent_remaining, Some(75.5));
    assert_eq!(
        snapshot.quota_windows[0].reset_at.as_deref(),
        Some("2026-06-09T10:00:00Z")
    );
    assert_eq!(snapshot.quota_windows[1].name, "week");
    assert_eq!(snapshot.quota_windows[1].percent_remaining, Some(30.0));
}

#[test]
fn claude_nested_organizations_choose_active_id() {
    let client = ClaudeSubscriptionProvider::default();
    let organization_id = client
        .select_nested_organization_fixture(claude_credential())
        .expect("organization fixture should parse");

    assert_eq!(organization_id, "org-active");
}

#[test]
fn claude_missing_session_key_maps_to_unauthorized() {
    let client = ClaudeSubscriptionProvider::default();
    let error = client
        .check_fixture_quota(ProviderCredential::fake_api_key("claude", "{}"))
        .expect_err("missing session key should fail");

    assert!(matches!(
        error,
        ProviderError::Unauthorized(message) if message.contains("Claude web login")
    ));
}

#[test]
fn claude_missing_usage_windows_maps_to_quota_unavailable() {
    let client = ClaudeSubscriptionProvider::default();
    let error = client
        .check_missing_usage_fixture(claude_credential())
        .expect_err("missing usage windows should fail");

    assert!(matches!(
        error,
        ProviderError::QuotaUnavailable(message) if message.contains("Claude usage")
    ));
}

#[test]
fn claude_live_quota_fetches_organization_usage_and_subscription_details() {
    let client = ClaudeSubscriptionProvider::default();
    let transport = MockProviderTransport::responding_many(vec![
        ProviderHttpResponse::new(200, r#"[{"uuid":"org1","active":true}]"#),
        ProviderHttpResponse::new(
            200,
            r#"{"five_hour":{"utilization":10,"resets_at":"2026-06-12T12:00:00Z"},"seven_day":{"utilization":90,"resets_at":"2026-06-15T00:00:00Z"}}"#,
        ),
        ProviderHttpResponse::new(200, r#"{"next_charge_at":"2026-07-09T09:57:27Z"}"#),
    ]);

    let snapshot = client
        .check_quota(claude_credential(), &transport)
        .expect("live Claude responses should parse");

    assert_eq!(snapshot.remaining, Some(1000.0));
    assert_eq!(snapshot.limit, Some(10_000.0));
    assert_eq!(snapshot.remaining_badge_text, "5h 90% · week 10%");
    assert_eq!(
        snapshot.plan_ends_at.as_deref(),
        Some("2026-07-09T09:57:27Z")
    );

    let requests = transport.requests();
    assert_eq!(requests.len(), 3);
    assert_eq!(requests[0].method, "GET");
    assert_eq!(requests[0].url, "https://claude.ai/api/organizations");
    assert!(requests[0].headers.contains(&(
        "Cookie".to_string(),
        "sessionKey=claude-session-placeholder".to_string()
    )));
    assert_eq!(requests[1].method, "GET");
    assert_eq!(
        requests[1].url,
        "https://claude.ai/api/organizations/org1/usage"
    );
    assert_eq!(requests[2].method, "GET");
    assert_eq!(
        requests[2].url,
        "https://claude.ai/api/organizations/org1/subscription_details"
    );
}
