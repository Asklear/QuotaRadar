use super::{
    http::{MockProviderTransport, ProviderHttpResponse},
    serper::SerperProvider,
    ProviderClient, ProviderCredential, ProviderError,
};

#[test]
fn serper_fixture_parses_credit_balance_snapshot() {
    let client = SerperProvider::default();
    let snapshot = client
        .check_fixture_quota(ProviderCredential::fake_api_key("serper", "serper-test"))
        .expect("fixture should parse");

    assert_eq!(snapshot.provider_id, "serper");
    assert_eq!(snapshot.remaining, Some(2400.0));
    assert_eq!(snapshot.limit, Some(2400.0));
    assert_eq!(snapshot.remaining_badge_text, "2400 credits");
    assert_eq!(snapshot.quota_label.as_deref(), Some("credits"));
    assert!(snapshot.quota_windows.is_empty());
    assert_eq!(snapshot.reset_at, None);
}

#[test]
fn serper_zero_balance_fixture_reports_no_available_credits() {
    let client = SerperProvider::default();
    let snapshot = client
        .check_zero_balance_fixture(ProviderCredential::fake_api_key("serper", "serper-test"))
        .expect("zero balance fixture should parse");

    assert_eq!(snapshot.remaining, Some(0.0));
    assert_eq!(snapshot.limit, Some(0.0));
    assert_eq!(snapshot.remaining_badge_text, "No Serper credits available");
}

#[test]
fn serper_unauthorized_fixture_maps_to_credential_error() {
    let client = SerperProvider::default();
    let error = client
        .check_unauthorized_fixture(ProviderCredential::fake_api_key("serper", "serper-test"))
        .expect_err("unauthorized fixture should fail");

    assert!(matches!(
        error,
        ProviderError::Unauthorized(message) if message.contains("Invalid API key")
    ));
}

#[test]
fn serper_missing_balance_fixture_maps_to_quota_unavailable() {
    let client = SerperProvider::default();
    let error = client
        .check_quota_unavailable_fixture(ProviderCredential::fake_api_key("serper", "serper-test"))
        .expect_err("missing balance fixture should fail");

    assert!(matches!(
        error,
        ProviderError::QuotaUnavailable(message) if message.contains("Serper credits")
    ));
}

#[test]
fn serper_network_failure_maps_to_network_error() {
    let error = SerperProvider::map_network_error("request timed out");

    assert!(matches!(
        error,
        ProviderError::Network(message) if message.contains("request timed out")
    ));
}

#[test]
fn serper_live_quota_uses_account_endpoint_transport() {
    let client = SerperProvider::default();
    let transport = MockProviderTransport::responding(ProviderHttpResponse {
        status: 200,
        body: r#"{"balance":42}"#.to_string(),
    });

    let snapshot = client
        .check_quota(
            ProviderCredential::fake_api_key("serper", "serper-live-test"),
            &transport,
        )
        .expect("live response should parse");

    assert_eq!(snapshot.remaining, Some(42.0));
    let requests = transport.requests();
    assert_eq!(requests.len(), 1);
    assert_eq!(requests[0].method, "GET");
    assert_eq!(requests[0].url, "https://google.serper.dev/account");
    assert!(requests[0]
        .headers
        .contains(&("X-API-KEY".to_string(), "serper-live-test".to_string())));
}
