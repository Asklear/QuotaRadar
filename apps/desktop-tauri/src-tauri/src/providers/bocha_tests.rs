use super::{bocha::BochaProvider, ProviderClient, ProviderCredential, ProviderError};

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
        .check_quota_unavailable_fixture(ProviderCredential::fake_api_key(
            "bocha",
            "bocha-test",
        ))
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
