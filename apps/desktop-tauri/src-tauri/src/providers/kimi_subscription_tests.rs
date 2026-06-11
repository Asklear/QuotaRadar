use super::{
    kimi_subscription::KimiSubscriptionProvider, ProviderClient, ProviderCredential, ProviderError,
};

fn kimi_credential() -> ProviderCredential {
    ProviderCredential::fake_api_key(
        "kimi",
        r#"{"accessToken":"access-token-placeholder","deviceID":"device-placeholder","sessionID":"session-placeholder","trafficID":"traffic-placeholder"}"#,
    )
}

#[test]
fn kimi_fixture_parses_coding_usage_windows_and_plan_end() {
    let client = KimiSubscriptionProvider::default();
    let snapshot = client
        .check_fixture_quota(kimi_credential())
        .expect("fixture should parse");

    assert_eq!(snapshot.provider_id, "kimi");
    assert_eq!(snapshot.remaining, None);
    assert_eq!(snapshot.limit, None);
    assert_eq!(snapshot.remaining_badge_text, "5h 96% · week 78% · month 8.4%");
    assert_eq!(snapshot.quota_label.as_deref(), Some("subscription"));
    assert_eq!(
        snapshot.plan_ends_at.as_deref(),
        Some("2026-06-15T08:54:48.861440Z")
    );
    assert_eq!(snapshot.quota_windows.len(), 3);
    assert_eq!(snapshot.quota_windows[0].name, "5h");
    assert_eq!(snapshot.quota_windows[0].percent_remaining, Some(96.0));
    assert_eq!(
        snapshot.quota_windows[0].reset_at.as_deref(),
        Some("2026-06-11T13:00:00Z")
    );
    assert_eq!(snapshot.quota_windows[1].name, "week");
    assert_eq!(snapshot.quota_windows[1].percent_remaining, Some(78.0));
    assert_eq!(snapshot.quota_windows[2].name, "month");
    assert_eq!(snapshot.quota_windows[2].percent_remaining, Some(8.4));
}

#[test]
fn kimi_oauth_usage_shape_is_supported_without_subscription_balance() {
    let client = KimiSubscriptionProvider::default();
    let snapshot = client
        .check_oauth_usage_fixture(kimi_credential())
        .expect("OAuth usage fixture should parse");

    assert_eq!(snapshot.remaining_badge_text, "5h 75% · week 30%");
    assert_eq!(snapshot.quota_windows.len(), 2);
    assert_eq!(snapshot.quota_windows[0].remaining_text.as_deref(), Some("750 / 1000"));
    assert_eq!(snapshot.quota_windows[1].remaining_text.as_deref(), Some("300 / 1000"));
}

#[test]
fn kimi_missing_access_token_maps_to_unauthorized() {
    let client = KimiSubscriptionProvider::default();
    let error = client
        .check_fixture_quota(ProviderCredential::fake_api_key("kimi", "{}"))
        .expect_err("missing access token should fail");

    assert!(matches!(
        error,
        ProviderError::Unauthorized(message) if message.contains("access token")
    ));
}

#[test]
fn kimi_no_subscription_fixture_maps_to_no_subscribed_plan() {
    let client = KimiSubscriptionProvider::default();
    let error = client
        .check_no_subscription_fixture(kimi_credential())
        .expect_err("no subscription fixture should fail");

    assert!(matches!(
        error,
        ProviderError::NoSubscribedPlan(message) if message.contains("Kimi subscription")
    ));
}

#[test]
fn kimi_quota_unknown_fixture_maps_to_quota_unavailable() {
    let client = KimiSubscriptionProvider::default();
    let error = client
        .check_quota_unavailable_fixture(kimi_credential())
        .expect_err("unknown quota fixture should fail");

    assert!(matches!(
        error,
        ProviderError::QuotaUnavailable(message) if message.contains("Kimi quota")
    ));
}
