use super::{
    http::{MockProviderTransport, ProviderHttpResponse},
    xfyun_coding_plan::XfyunCodingPlanProvider,
    ProviderClient, ProviderCredential, ProviderError,
};

fn xfyun_credential() -> ProviderCredential {
    ProviderCredential::fake_api_key(
        "xfyun_coding_plan",
        "ssoSessionId=xfyun-session-placeholder; tenantToken=tenant-placeholder; atp-auth-token=auth-placeholder; account_id=account-placeholder",
    )
}

#[test]
fn xfyun_fixture_parses_coding_plan_windows_and_plan_end() {
    let client = XfyunCodingPlanProvider::default();
    let snapshot = client
        .check_fixture_quota(xfyun_credential())
        .expect("fixture should parse");

    assert_eq!(snapshot.provider_id, "xfyun_coding_plan");
    assert_eq!(snapshot.remaining, Some(7934.0));
    assert_eq!(snapshot.limit, Some(10_000.0));
    assert_eq!(
        snapshot.remaining_badge_text,
        "5h 99% · week 79.3% · month 89.7%"
    );
    assert_eq!(snapshot.quota_label.as_deref(), Some("subscription"));
    assert_eq!(snapshot.reset_at, None);
    assert_eq!(
        snapshot.plan_ends_at.as_deref(),
        Some("2026-06-28 17:48:58")
    );
    assert_eq!(snapshot.quota_windows.len(), 3);
    assert_eq!(snapshot.quota_windows[0].name, "5h");
    assert_eq!(snapshot.quota_windows[0].percent_remaining, Some(99.0));
    assert_eq!(
        snapshot.quota_windows[0].remaining_text.as_deref(),
        Some("5940 / 6000")
    );
    assert_eq!(snapshot.quota_windows[1].name, "week");
    assert_eq!(snapshot.quota_windows[1].percent_remaining, Some(79.3));
    assert_eq!(
        snapshot.quota_windows[2].remaining_text.as_deref(),
        Some("80704 / 90000")
    );
}

#[test]
fn xfyun_missing_dashboard_cookie_maps_to_unauthorized() {
    let client = XfyunCodingPlanProvider::default();
    let error = client
        .check_fixture_quota(ProviderCredential::fake_api_key(
            "xfyun_coding_plan",
            "tenantToken=tenant-placeholder",
        ))
        .expect_err("missing session cookie should fail");

    assert!(matches!(
        error,
        ProviderError::Unauthorized(message) if message.contains("XFYun web login")
    ));
}

#[test]
fn xfyun_failed_login_fixture_maps_to_unauthorized() {
    let client = XfyunCodingPlanProvider::default();
    let error = client
        .check_failed_login_fixture(xfyun_credential())
        .expect_err("failed login fixture should fail");

    assert!(matches!(
        error,
        ProviderError::Unauthorized(message) if message.contains("XFYun web login")
    ));
}

#[test]
fn xfyun_empty_rows_maps_to_no_subscribed_plan() {
    let client = XfyunCodingPlanProvider::default();
    let error = client
        .check_no_subscription_fixture(xfyun_credential())
        .expect_err("empty rows should fail");

    assert!(matches!(
        error,
        ProviderError::NoSubscribedPlan(message) if message.contains("XFYun coding plan")
    ));
}

#[test]
fn xfyun_missing_usage_maps_to_quota_unavailable() {
    let client = XfyunCodingPlanProvider::default();
    let error = client
        .check_missing_usage_fixture(xfyun_credential())
        .expect_err("missing usage should fail");

    assert!(matches!(
        error,
        ProviderError::QuotaUnavailable(message) if message.contains("XFYun quota")
    ));
}

#[test]
fn xfyun_live_quota_uses_coding_plan_list_transport() {
    let client = XfyunCodingPlanProvider::default();
    let transport = MockProviderTransport::responding(ProviderHttpResponse::new(
        200,
        r#"{"code":0,"data":{"rows":[{"expiresAt":"2026-06-28 17:48:58","status":1,"codingPlanUsageDTO":{"packageLeft":70,"packageLimit":100,"rp5hLimit":100,"rp5hUsage":20,"rpwLimit":100,"rpwUsage":50}}]},"succeed":true}"#,
    ));

    let snapshot = client
        .check_quota(xfyun_credential(), &transport)
        .expect("live XFYun response should parse");

    assert_eq!(snapshot.remaining, Some(5000.0));
    assert_eq!(snapshot.limit, Some(10_000.0));
    assert_eq!(
        snapshot.remaining_badge_text,
        "5h 80% · week 50% · month 70%"
    );
    assert_eq!(
        snapshot.plan_ends_at.as_deref(),
        Some("2026-06-28 17:48:58")
    );

    let requests = transport.requests();
    assert_eq!(requests.len(), 1);
    assert_eq!(requests[0].method, "GET");
    assert_eq!(
        requests[0].url,
        "https://maas.xfyun.cn/api/v1/gpt-finetune/coding-plan/list?page=1&size=6"
    );
    assert!(requests[0].headers.contains(&(
        "Cookie".to_string(),
        "ssoSessionId=xfyun-session-placeholder; tenantToken=tenant-placeholder; atp-auth-token=auth-placeholder; account_id=account-placeholder".to_string()
    )));
}

#[test]
fn xfyun_live_quota_accepts_decimal_numeric_counters() {
    let client = XfyunCodingPlanProvider::default();
    let transport = MockProviderTransport::responding(ProviderHttpResponse::new(
        200,
        r#"{"code":0,"data":{"rows":[{"expiresAt":"2026-06-28 17:48:58","status":1,"codingPlanUsageDTO":{"packageLeft":87297.0,"packageLimit":90000.0,"packageUsage":2703.0,"rp5hLimit":6000.0,"rp5hUsage":30.0,"rpwLimit":45000.0,"rpwUsage":2703.0}}]},"succeed":true}"#,
    ));

    let snapshot = client
        .check_quota(xfyun_credential(), &transport)
        .expect("XFYun decimal counters should parse");

    assert_eq!(
        snapshot.remaining_badge_text,
        "5h 99.5% · week 94% · month 97%"
    );
    assert_eq!(
        snapshot.quota_windows[0].remaining_text.as_deref(),
        Some("5970 / 6000")
    );
    assert_eq!(
        snapshot.quota_windows[1].remaining_text.as_deref(),
        Some("42297 / 45000")
    );
    assert_eq!(
        snapshot.quota_windows[2].remaining_text.as_deref(),
        Some("87297 / 90000")
    );
}
