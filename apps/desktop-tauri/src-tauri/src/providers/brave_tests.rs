use super::{
    brave::BraveProvider,
    http::{MockProviderTransport, ProviderHttpResponse},
    ProviderClient, ProviderCredential, ProviderError,
};

#[test]
fn brave_provider_reports_that_quota_checks_consume_search_quota() {
    let client = BraveProvider::default();

    assert_eq!(client.provider_id(), "brave");
    assert!(client.consumes_quota_on_check());
}

#[test]
fn brave_fixture_parses_monthly_request_snapshot() {
    let client = BraveProvider::default();
    let snapshot = client
        .check_fixture_quota(ProviderCredential::fake_api_key("brave", "BSA-test"))
        .expect("fixture should parse");

    assert_eq!(snapshot.provider_id, "brave");
    assert_eq!(snapshot.remaining, Some(742.0));
    assert_eq!(snapshot.limit, Some(1000.0));
    assert_eq!(snapshot.remaining_badge_text, "742 / 1000");
    assert_eq!(snapshot.quota_windows[0].name, "month");
    assert_eq!(snapshot.quota_windows[0].percent_remaining, Some(74.2));
}

#[test]
fn brave_live_quota_uses_search_probe_rate_limit_headers() {
    let client = BraveProvider::default();
    let transport = MockProviderTransport::responding(
        ProviderHttpResponse::new(200, r#"{"type":"search","web":{"results":[]}}"#)
            .with_header("X-RateLimit-Requests-Limit", "1000")
            .with_header("X-RateLimit-Requests-Left", "999")
            .with_header("X-RateLimit-Requests-Reset", "1782864000"),
    );

    let snapshot = client
        .check_quota(
            ProviderCredential::fake_api_key("brave", "BSA-live-test"),
            &transport,
        )
        .expect("live response headers should parse");

    assert_eq!(snapshot.remaining, Some(999.0));
    assert_eq!(snapshot.limit, Some(1000.0));
    assert_eq!(snapshot.remaining_badge_text, "999 / 1000");
    assert_eq!(snapshot.quota_label.as_deref(), Some("requests"));
    assert_eq!(snapshot.quota_windows[0].name, "month");
    assert_eq!(snapshot.quota_windows[0].percent_remaining, Some(99.9));
    assert_eq!(
        snapshot.reset_at.as_deref(),
        Some("2026-07-01T00:00:00+00:00")
    );

    let requests = transport.requests();
    assert_eq!(requests.len(), 1);
    assert_eq!(requests[0].method, "GET");
    assert_eq!(
        requests[0].url,
        "https://api.search.brave.com/res/v1/web/search?q=test&count=1"
    );
    assert!(requests[0].headers.contains(&(
        "X-Subscription-Token".to_string(),
        "BSA-live-test".to_string()
    )));
}

#[test]
fn brave_live_quota_selects_monthly_window_from_comma_separated_rate_limit_headers() {
    let client = BraveProvider::default();
    let transport = MockProviderTransport::responding(
        ProviderHttpResponse::new(200, r#"{"type":"search","web":{"results":[]}}"#)
            .with_header("x-ratelimit-limit", "1, 2000")
            .with_header("x-ratelimit-remaining", "0, 1981")
            .with_header("x-ratelimit-reset", "1, 1540435")
            .with_header("x-ratelimit-policy", "1;w=1, 2000;w=2592000"),
    );

    let snapshot = client
        .check_quota(
            ProviderCredential::fake_api_key("brave", "BSA-live-test"),
            &transport,
        )
        .expect("comma separated rate-limit headers should parse");

    assert_eq!(snapshot.remaining, Some(1981.0));
    assert_eq!(snapshot.limit, Some(2000.0));
    assert_eq!(snapshot.remaining_badge_text, "1981 / 2000");
    assert_eq!(snapshot.quota_windows[0].name, "month");
    assert_eq!(snapshot.quota_windows[0].percent_remaining, Some(99.05));
    assert!(snapshot.reset_at.is_some());
}

#[test]
fn brave_live_quota_with_zero_monthly_window_reports_usable_unknown_quota() {
    let client = BraveProvider::default();
    let transport = MockProviderTransport::responding(
        ProviderHttpResponse::new(200, r#"{"type":"search","web":{"results":[]}}"#)
            .with_header("x-ratelimit-limit", "50, 0")
            .with_header("x-ratelimit-remaining", "49, 0")
            .with_header("x-ratelimit-reset", "1, 931196")
            .with_header("x-ratelimit-policy", "50;w=1, 0;w=2678400"),
    );

    let snapshot = client
        .check_quota(
            ProviderCredential::fake_api_key("brave", "BSA-live-test"),
            &transport,
        )
        .expect("HTTP 200 with hidden monthly quota should remain usable");

    assert_eq!(snapshot.remaining, None);
    assert_eq!(snapshot.limit, None);
    assert_eq!(snapshot.remaining_badge_text, "OK");
    assert_eq!(snapshot.quota_label.as_deref(), Some("quota hidden"));
    assert!(snapshot.quota_windows.is_empty());
    assert!(snapshot.reset_at.is_some());
}

#[test]
fn brave_live_quota_maps_unauthorized_status() {
    let client = BraveProvider::default();
    let transport = MockProviderTransport::responding(ProviderHttpResponse::new(401, "{}"));

    let error = client
        .check_quota(
            ProviderCredential::fake_api_key("brave", "BSA-live-test"),
            &transport,
        )
        .expect_err("401 should fail");

    assert!(matches!(
        error,
        ProviderError::Unauthorized(message) if message.contains("Brave")
    ));
}

#[test]
fn brave_live_quota_maps_invalid_subscription_token_to_authorization_error() {
    let client = BraveProvider::default();
    let transport = MockProviderTransport::responding(ProviderHttpResponse::new(
        422,
        r#"{"type":"ErrorResponse","error":{"code":"SUBSCRIPTION_TOKEN_INVALID","detail":"The provided subscription token is invalid."}}"#,
    ));

    let error = client
        .check_quota(
            ProviderCredential::fake_api_key("brave", "BSA-live-test"),
            &transport,
        )
        .expect_err("422 invalid subscription token should fail");

    assert!(matches!(
        error,
        ProviderError::Unauthorized(message)
            if message.contains("invalid") && message.contains("Brave")
    ));
}
