use super::{
    http::{MockProviderTransport, ProviderHttpResponse},
    tencent_cloud_coding_plan::TencentCloudCodingPlanProvider,
    ProviderClient, ProviderCredential, ProviderError,
};

fn tencent_credential() -> ProviderCredential {
    ProviderCredential::fake_api_key(
        "tencent_cloud_coding_plan",
        "uin=o123456789; skey=skey-placeholder; ownerUin=o123456789",
    )
}

#[test]
fn tencent_fixture_parses_describe_pkg_windows_and_plan_end() {
    let client = TencentCloudCodingPlanProvider::default();
    let snapshot = client
        .check_fixture_quota(tencent_credential())
        .expect("fixture should parse");

    assert_eq!(snapshot.provider_id, "tencent_cloud_coding_plan");
    assert_eq!(snapshot.remaining, Some(8000.0));
    assert_eq!(snapshot.limit, Some(10_000.0));
    assert_eq!(
        snapshot.remaining_badge_text,
        "5h 99% · week 90% · month 80%"
    );
    assert_eq!(snapshot.quota_label.as_deref(), Some("subscription"));
    assert_eq!(snapshot.reset_at.as_deref(), Some("2026-06-30T16:00:00Z"));
    assert_eq!(
        snapshot.plan_ends_at.as_deref(),
        Some("2026-06-30T16:00:00Z")
    );
    assert_eq!(snapshot.quota_windows.len(), 3);
    assert_eq!(
        snapshot.quota_windows[0].remaining_text.as_deref(),
        Some("1188 / 1200")
    );
    assert_eq!(
        snapshot.quota_windows[1].remaining_text.as_deref(),
        Some("8100 / 9000")
    );
    assert_eq!(
        snapshot.quota_windows[2].remaining_text.as_deref(),
        Some("14400 / 18000")
    );
}

#[test]
fn tencent_zero_packages_maps_to_no_subscribed_plan() {
    let client = TencentCloudCodingPlanProvider::default();
    let error = client
        .check_no_subscription_fixture(tencent_credential())
        .expect_err("zero packages should fail");

    assert!(matches!(
        error,
        ProviderError::NoSubscribedPlan(message) if message.contains("Tencent Cloud coding plan")
    ));
}

#[test]
fn tencent_login_state_failure_maps_to_unauthorized() {
    let client = TencentCloudCodingPlanProvider::default();
    let error = client
        .check_login_failure_fixture(tencent_credential())
        .expect_err("login-state failure should fail");

    assert!(matches!(
        error,
        ProviderError::Unauthorized(message) if message.contains("Tencent Cloud web login")
    ));
}

#[test]
fn tencent_missing_dashboard_cookie_maps_to_unauthorized() {
    let client = TencentCloudCodingPlanProvider::default();
    let error = client
        .check_fixture_quota(ProviderCredential::fake_api_key(
            "tencent_cloud_coding_plan",
            "uin=o123456789",
        ))
        .expect_err("missing skey should fail");

    assert!(matches!(
        error,
        ProviderError::Unauthorized(message) if message.contains("Tencent Cloud web login")
    ));
}

#[test]
fn tencent_live_quota_uses_describe_pkg_transport() {
    let client = TencentCloudCodingPlanProvider::default();
    let transport = MockProviderTransport::responding(ProviderHttpResponse::new(
        200,
        r#"{"data":{"data":{"Response":{"PkgList":[{"PkgName":"Coding Plan","Status":"Normal","EndTime":"2026-07-01 00:00:00","UsageDetail":{"PerFiveHour":{"Used":20,"Total":100,"UsagePercent":20,"EndTime":"2026-06-08 06:00:00"},"PerWeek":{"Used":50,"Total":100,"UsagePercent":50,"EndTime":"2026-06-15 00:00:00"},"PerMonth":{"Used":70,"Total":100,"UsagePercent":70,"EndTime":"2026-07-01 00:00:00"}}}]}}},"code":0,"mccode":0}"#,
    ));

    let snapshot = client
        .check_quota(tencent_credential(), &transport)
        .expect("live Tencent Cloud response should parse");

    assert_eq!(snapshot.remaining, Some(3000.0));
    assert_eq!(snapshot.limit, Some(10_000.0));
    assert_eq!(
        snapshot.remaining_badge_text,
        "5h 80% · week 50% · month 30%"
    );
    assert_eq!(
        snapshot.plan_ends_at.as_deref(),
        Some("2026-06-30T16:00:00Z")
    );

    let requests = transport.requests();
    assert_eq!(requests.len(), 1);
    assert_eq!(requests[0].method, "POST");
    assert!(requests[0]
        .url
        .starts_with("https://console.cloud.tencent.com/cgi/capi?"));
    assert!(requests[0].url.contains("cmd=DescribePkg"));
    assert!(requests[0].url.contains("serviceType=hunyuan"));
    assert!(requests[0].url.contains("uin=123456789"));
    assert!(requests[0].url.contains("ownerUin=123456789"));
    assert!(requests[0].url.contains("csrfCode="));
    assert_eq!(
        requests[0].body.as_deref(),
        Some(
            r#"{"regionId":1,"serviceType":"hunyuan","cmd":"DescribePkg","data":{"Version":"2023-09-01","Language":"zh-CN"}}"#
        )
    );
    assert!(requests[0].headers.contains(&(
        "Cookie".to_string(),
        "uin=o123456789; skey=skey-placeholder; ownerUin=o123456789".to_string()
    )));
    assert!(requests[0].headers.contains(&(
        "Origin".to_string(),
        "https://console.cloud.tencent.com".to_string()
    )));
    assert!(requests[0].headers.contains(&(
        "Referer".to_string(),
        "https://console.cloud.tencent.com/tokenhub/codingplan".to_string()
    )));
}
