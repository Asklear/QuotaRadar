use super::{
    aliyun_coding_plan::AliyunCodingPlanProvider, ProviderClient, ProviderCredential,
    ProviderError,
};

fn aliyun_credential() -> ProviderCredential {
    ProviderCredential::fake_api_key(
        "aliyun_coding_plan",
        "login_aliyunid_ticket=login-placeholder; cna=cna-placeholder; aliyun_lang=zh",
    )
}

#[test]
fn aliyun_instance_info_fixture_parses_usage_windows_resets_and_plan_end() {
    let client = AliyunCodingPlanProvider::default();
    let snapshot = client
        .check_fixture_quota(aliyun_credential())
        .expect("fixture should parse");

    assert_eq!(snapshot.provider_id, "aliyun_coding_plan");
    assert_eq!(snapshot.remaining, Some(9676.0));
    assert_eq!(snapshot.limit, Some(10_000.0));
    assert_eq!(snapshot.remaining_badge_text, "5h 99.3% · week 99.6% · month 96.8%");
    assert_eq!(snapshot.quota_label.as_deref(), Some("subscription"));
    assert_eq!(
        snapshot.reset_at.as_deref(),
        Some("2026-06-26T16:00:00Z")
    );
    assert_eq!(
        snapshot.plan_ends_at.as_deref(),
        Some("2026-06-26T16:00:00Z")
    );
    assert_eq!(snapshot.quota_windows.len(), 3);
    assert_eq!(
        snapshot.quota_windows[0].remaining_text.as_deref(),
        Some("5957 / 6000")
    );
    assert_eq!(
        snapshot.quota_windows[0].reset_at.as_deref(),
        Some("2026-06-09T04:56:37Z")
    );
    assert_eq!(
        snapshot.quota_windows[2].remaining_text.as_deref(),
        Some("87087 / 90000")
    );
}

#[test]
fn aliyun_usage_detail_fixture_is_supported() {
    let client = AliyunCodingPlanProvider::default();
    let snapshot = client
        .check_usage_detail_fixture(aliyun_credential())
        .expect("usage-detail fixture should parse");

    assert_eq!(snapshot.remaining, Some(8000.0));
    assert_eq!(snapshot.limit, Some(10_000.0));
    assert_eq!(snapshot.remaining_badge_text, "5h 98% · week 80% · month 80%");
    assert_eq!(
        snapshot.plan_ends_at.as_deref(),
        Some("2026-07-07T18:19:33Z")
    );
    assert_eq!(snapshot.reset_at, None);
    assert_eq!(
        snapshot.quota_windows[1].remaining_text.as_deref(),
        Some("4800 / 6000")
    );
}

#[test]
fn aliyun_no_subscription_fixtures_map_to_no_subscribed_plan() {
    let client = AliyunCodingPlanProvider::default();
    let status_error = client
        .check_no_subscription_status_fixture(aliyun_credential())
        .expect_err("hasCodingPlan false should fail");
    let empty_error = client
        .check_empty_subscription_list_fixture(aliyun_credential())
        .expect_err("empty instance list should fail");

    assert!(matches!(
        status_error,
        ProviderError::NoSubscribedPlan(message) if message.contains("Aliyun coding plan")
    ));
    assert!(matches!(
        empty_error,
        ProviderError::NoSubscribedPlan(message) if message.contains("Aliyun coding plan")
    ));
}

#[test]
fn aliyun_missing_dashboard_cookie_maps_to_unauthorized() {
    let client = AliyunCodingPlanProvider::default();
    let error = client
        .check_fixture_quota(ProviderCredential::fake_api_key(
            "aliyun_coding_plan",
            "aliyun_lang=zh",
        ))
        .expect_err("missing login cookies should fail");

    assert!(matches!(
        error,
        ProviderError::Unauthorized(message) if message.contains("Aliyun web login")
    ));
}

#[test]
fn aliyun_missing_quota_info_maps_to_quota_unavailable() {
    let client = AliyunCodingPlanProvider::default();
    let error = client
        .check_missing_quota_fixture(aliyun_credential())
        .expect_err("missing quota info should fail");

    assert!(matches!(
        error,
        ProviderError::QuotaUnavailable(message) if message.contains("Aliyun quota")
    ));
}
