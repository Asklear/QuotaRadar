use super::{
    bocha::BochaProvider,
    http::{MockProviderTransport, ProviderHttpResponse},
    ProviderClient, ProviderCredential, ProviderError,
};

#[test]
fn bocha_fixture_parses_cny_balance_snapshot() {
    let client = BochaProvider::default();
    let snapshot = client
        .check_fixture_quota(ProviderCredential::fake_api_key("bocha", "bocha-test"))
        .expect("fixture should parse");

    assert_eq!(snapshot.provider_id, "bocha");
    assert_eq!(snapshot.remaining, Some(12.34));
    assert_eq!(snapshot.limit, Some(12.34));
    assert_eq!(snapshot.remaining_badge_text, "¥12.34");
    assert_eq!(snapshot.quota_label.as_deref(), Some("CNY"));
    assert!(snapshot.quota_windows.is_empty());
    assert_eq!(snapshot.reset_at, None);
}

#[test]
fn bocha_unauthorized_fixture_maps_to_credential_error() {
    let client = BochaProvider::default();
    let error = client
        .check_unauthorized_fixture(ProviderCredential::fake_api_key("bocha", "bocha-test"))
        .expect_err("unauthorized fixture should fail");

    assert!(matches!(
        error,
        ProviderError::Unauthorized(message) if message.contains("Invalid API key")
    ));
}

#[test]
fn bocha_invalid_success_fixture_maps_to_quota_unavailable() {
    let client = BochaProvider::default();
    let error = client
        .check_quota_unavailable_fixture(ProviderCredential::fake_api_key("bocha", "bocha-test"))
        .expect_err("invalid quota fixture should fail");

    assert!(matches!(
        error,
        ProviderError::QuotaUnavailable(message) if message.contains("Bocha balance")
    ));
}

#[test]
fn bocha_network_failure_maps_to_network_error() {
    let error = BochaProvider::map_network_error("request timed out");

    assert!(matches!(
        error,
        ProviderError::Network(message) if message.contains("request timed out")
    ));
}

#[test]
fn bocha_live_quota_uses_balance_endpoint_transport() {
    let client = BochaProvider::default();
    let transport = MockProviderTransport::responding(ProviderHttpResponse {
        status: 200,
        body: r#"{"success":true,"code":"200","data":{"remaining":88.8}}"#.to_string(),
    });

    let snapshot = client
        .check_quota(
            ProviderCredential::fake_api_key("bocha", "bocha-live-test"),
            &transport,
        )
        .expect("live response should parse");

    assert_eq!(snapshot.remaining, Some(88.8));
    let requests = transport.requests();
    assert_eq!(requests.len(), 1);
    assert_eq!(requests[0].url, "https://api.bochaai.com/v1/fund/remaining");
    assert!(requests[0].headers.contains(&(
        "Authorization".to_string(),
        "Bearer bocha-live-test".to_string()
    )));
}
