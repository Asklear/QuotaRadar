use super::{anysearch::AnySearchProvider, ProviderClient, ProviderCredential};

#[test]
fn anysearch_fixture_reports_unlimited_free_usage_without_large_numbers() {
    let client = AnySearchProvider::default();
    let snapshot = client
        .check_fixture_quota(ProviderCredential::fake_api_key(
            "anysearch",
            "anysearch-test",
        ))
        .expect("fixture should parse");

    assert_eq!(snapshot.provider_id, "anysearch");
    assert_eq!(snapshot.remaining, None);
    assert_eq!(snapshot.limit, None);
    assert_eq!(snapshot.remaining_badge_text, "Unlimited");
    assert_eq!(snapshot.quota_label.as_deref(), Some("free usage"));
    assert!(snapshot.quota_windows.is_empty());
    assert_eq!(snapshot.reset_at, None);
}

#[test]
fn anysearch_quota_check_does_not_consume_search_quota() {
    let client = AnySearchProvider::default();

    assert_eq!(client.provider_id(), "anysearch");
    assert!(!client.consumes_quota_on_check());
}
