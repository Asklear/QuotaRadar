use super::{exa::ExaProvider, ProviderClient, ProviderCredential, ProviderError};

fn exa_management_credential() -> ProviderCredential {
    ProviderCredential::fake_api_key(
        "exa",
        r#"{"serviceKey":"service-key-placeholder","apiKeyID":"api-key-id-placeholder","days":30}"#,
    )
}

#[test]
fn exa_fixture_parses_management_usage_snapshot_without_fake_quota() {
    let client = ExaProvider::default();
    let snapshot = client
        .check_fixture_quota(exa_management_credential())
        .expect("fixture should parse");

    assert_eq!(snapshot.provider_id, "exa");
    assert_eq!(snapshot.remaining, None);
    assert_eq!(snapshot.limit, None);
    assert_eq!(snapshot.remaining_badge_text, "USD 45.67 used");
    assert_eq!(snapshot.quota_label.as_deref(), Some("usage"));
    assert!(snapshot.quota_windows.is_empty());
    assert_eq!(snapshot.reset_at, None);
}

#[test]
fn exa_camel_case_usage_fixture_is_supported() {
    let client = ExaProvider::default();
    let snapshot = client
        .check_camel_case_usage_fixture(exa_management_credential())
        .expect("camel case fixture should parse");

    assert_eq!(snapshot.remaining_badge_text, "USD 12.50 used");
}

#[test]
fn exa_plain_api_key_maps_to_unsupported_management_credential_error() {
    let client = ExaProvider::default();
    let error = client
        .check_fixture_quota(ProviderCredential::fake_api_key("exa", "exa-search-key-only"))
        .expect_err("plain Exa search key should not be accepted");

    assert!(matches!(
        error,
        ProviderError::Unsupported(message) if message.contains("service key")
    ));
}

#[test]
fn exa_unauthorized_fixture_maps_to_credential_error() {
    let client = ExaProvider::default();
    let error = client
        .check_unauthorized_fixture(exa_management_credential())
        .expect_err("unauthorized fixture should fail");

    assert!(matches!(
        error,
        ProviderError::Unauthorized(message) if message.contains("Invalid service key")
    ));
}

#[test]
fn exa_missing_usage_fixture_maps_to_quota_unavailable() {
    let client = ExaProvider::default();
    let error = client
        .check_quota_unavailable_fixture(exa_management_credential())
        .expect_err("missing usage fixture should fail");

    assert!(matches!(
        error,
        ProviderError::QuotaUnavailable(message) if message.contains("Exa usage")
    ));
}

#[test]
fn exa_network_failure_maps_to_network_error() {
    let error = ExaProvider::map_network_error("request timed out");

    assert!(matches!(
        error,
        ProviderError::Network(message) if message.contains("request timed out")
    ));
}
