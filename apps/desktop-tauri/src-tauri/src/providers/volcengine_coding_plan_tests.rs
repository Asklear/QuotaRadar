use super::{
    volcengine_coding_plan::VolcengineCodingPlanProvider, ProviderClient, ProviderCredential,
    ProviderError,
};

fn volcengine_credential() -> ProviderCredential {
    ProviderCredential::fake_api_key(
        "volcengine_coding_plan",
        r#"{"cookie":"digest=digest-placeholder; AccountID=account-placeholder; csrfToken=csrf-placeholder","csrfToken":"csrf-placeholder","projectName":"default"}"#,
    )
}

#[test]
fn volcengine_fixture_parses_usage_windows_and_reset_times() {
    let client = VolcengineCodingPlanProvider::default();
    let snapshot = client
        .check_fixture_quota(volcengine_credential())
        .expect("fixture should parse");

    assert_eq!(snapshot.provider_id, "volcengine_coding_plan");
    assert_eq!(snapshot.remaining, Some(8918.0));
    assert_eq!(snapshot.limit, Some(10_000.0));
    assert_eq!(snapshot.remaining_badge_text, "5h 100% · week 89.2% · month 94.6%");
    assert_eq!(snapshot.quota_label.as_deref(), Some("subscription"));
    assert_eq!(snapshot.plan_ends_at, None);
    assert_eq!(
        snapshot.reset_at.as_deref(),
        Some("2026-06-07T16:00:00Z")
    );
    assert_eq!(snapshot.quota_windows.len(), 3);
    assert_eq!(snapshot.quota_windows[0].name, "5h");
    assert_eq!(snapshot.quota_windows[0].percent_remaining, Some(100.0));
    assert_eq!(snapshot.quota_windows[0].reset_at, None);
    assert_eq!(snapshot.quota_windows[1].name, "week");
    assert_eq!(snapshot.quota_windows[1].percent_remaining, Some(89.2));
    assert_eq!(
        snapshot.quota_windows[1].reset_at.as_deref(),
        Some("2026-06-07T16:00:00Z")
    );
}

#[test]
fn volcengine_missing_dashboard_cookie_maps_to_unauthorized() {
    let client = VolcengineCodingPlanProvider::default();
    let error = client
        .check_fixture_quota(ProviderCredential::fake_api_key(
            "volcengine_coding_plan",
            r#"{"cookie":"AccountID=account-placeholder"}"#,
        ))
        .expect_err("missing login cookies should fail");

    assert!(matches!(
        error,
        ProviderError::Unauthorized(message) if message.contains("Volcengine web login")
    ));
}

#[test]
fn volcengine_empty_usage_maps_to_quota_unavailable() {
    let client = VolcengineCodingPlanProvider::default();
    let error = client
        .check_empty_usage_fixture(volcengine_credential())
        .expect_err("empty usage should fail");

    assert!(matches!(
        error,
        ProviderError::QuotaUnavailable(message) if message.contains("Volcengine quota")
    ));
}
