use super::{
    anthropic_credits::AnthropicCreditsProvider,
    http::{MockProviderTransport, ProviderHttpResponse},
    ProviderClient, ProviderCredential, ProviderError,
};

fn anthropic_credits_credential() -> ProviderCredential {
    ProviderCredential::fake_api_key(
        "anthropic_credits",
        r#"{"sessionKey":"claude-session-placeholder"}"#,
    )
}

#[test]
fn anthropic_credits_fixture_parses_prepaid_balance_without_subscription_windows() {
    let client = AnthropicCreditsProvider::default();
    let snapshot = client
        .check_fixture_quota(anthropic_credits_credential())
        .expect("fixture should parse");

    assert_eq!(snapshot.provider_id, "anthropic_credits");
    assert_eq!(snapshot.remaining, Some(42.5));
    assert_eq!(snapshot.limit, Some(42.5));
    assert_eq!(snapshot.quota_label.as_deref(), Some("credits"));
    assert_eq!(snapshot.remaining_badge_text, "42.5 credits");
    assert!(snapshot.quota_windows.is_empty());
    assert!(snapshot.reset_at.is_none());
    assert!(snapshot.plan_ends_at.is_none());
}

#[test]
fn anthropic_credits_live_quota_fetches_organizations_then_prepaid_credits() {
    let client = AnthropicCreditsProvider::default();
    let transport = MockProviderTransport::responding_many(vec![
        ProviderHttpResponse::new(200, r#"[{"uuid":"org1","active":true}]"#),
        ProviderHttpResponse::new(200, r#"{"amount":42.5}"#),
    ]);

    let snapshot = client
        .check_quota(anthropic_credits_credential(), &transport)
        .expect("live Anthropic Credits responses should parse");

    assert_eq!(snapshot.remaining_badge_text, "42.5 credits");

    let requests = transport.requests();
    assert_eq!(requests.len(), 2);
    assert_eq!(requests[0].url, "https://claude.ai/api/organizations");
    assert_eq!(
        requests[1].url,
        "https://claude.ai/api/organizations/org1/prepaid/credits"
    );
    assert!(requests[0].headers.contains(&(
        "Cookie".to_string(),
        "sessionKey=claude-session-placeholder".to_string()
    )));
}

#[test]
fn anthropic_credits_missing_session_maps_to_unauthorized() {
    let client = AnthropicCreditsProvider::default();
    let error = client
        .check_fixture_quota(ProviderCredential::fake_api_key("anthropic_credits", "{}"))
        .expect_err("missing session key should fail");

    assert!(matches!(
        error,
        ProviderError::Unauthorized(message) if message.contains("Claude web login")
    ));
}
