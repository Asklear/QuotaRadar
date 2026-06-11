use super::{
    http::{MockProviderTransport, ProviderHttpResponse},
    serpapi::SerpApiProvider,
    ProviderClient, ProviderCredential, ProviderError,
};

#[test]
fn serpapi_fixture_parses_monthly_search_snapshot() {
    let client = SerpApiProvider::default();
    let snapshot = client
        .check_fixture_quota(ProviderCredential::fake_api_key("serpapi", "serp-test"))
        .expect("fixture should parse");

    assert_eq!(snapshot.provider_id, "serpapi");
    assert_eq!(snapshot.remaining, Some(4100.0));
    assert_eq!(snapshot.limit, Some(5000.0));
    assert_eq!(snapshot.remaining_badge_text, "4100 / 5000");
    assert_eq!(snapshot.quota_label.as_deref(), Some("searches"));
    assert_eq!(snapshot.quota_windows[0].percent_remaining, Some(82.0));
}

#[test]
fn serpapi_unauthorized_fixture_maps_to_credential_error() {
    let client = SerpApiProvider::default();
    let error = client
        .check_unauthorized_fixture(ProviderCredential::fake_api_key("serpapi", "serp-test"))
        .expect_err("unauthorized fixture should fail");

    assert!(matches!(
        error,
        ProviderError::Unauthorized(message) if message.contains("Invalid API key")
    ));
}

#[test]
fn serpapi_missing_quota_fixture_maps_to_quota_unavailable() {
    let client = SerpApiProvider::default();
    let error = client
        .check_quota_unavailable_fixture(ProviderCredential::fake_api_key("serpapi", "serp-test"))
        .expect_err("missing quota fixture should fail");

    assert!(matches!(
        error,
        ProviderError::QuotaUnavailable(message) if message.contains("monthly searches")
    ));
}

#[test]
fn serpapi_network_failure_maps_to_network_error() {
    let error = SerpApiProvider::map_network_error("request timed out");

    assert!(matches!(
        error,
        ProviderError::Network(message) if message.contains("request timed out")
    ));
}

#[test]
fn serpapi_live_quota_uses_account_endpoint_transport() {
    let client = SerpApiProvider::default();
    let transport = MockProviderTransport::responding(ProviderHttpResponse {
        status: 200,
        body: r#"{"account":{"total_searches_left":99,"monthly_searches_limit":100,"reset_at":"2026-07-01T00:00:00Z"}}"#.to_string(),
    });

    let snapshot = client
        .check_quota(
            ProviderCredential::fake_api_key("serpapi", "serp-live"),
            &transport,
        )
        .expect("live response should parse");

    assert_eq!(snapshot.remaining, Some(99.0));
    assert_eq!(snapshot.limit, Some(100.0));
    let requests = transport.requests();
    assert_eq!(requests.len(), 1);
    assert_eq!(
        requests[0].url,
        "https://serpapi.com/account.json?api_key=serp-live"
    );
}
