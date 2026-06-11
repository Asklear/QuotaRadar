use super::{
    http::{MockProviderTransport, ProviderHttpResponse},
    querit::QueritProvider,
    ProviderClient, ProviderCredential, ProviderError,
};

fn querit_credential() -> ProviderCredential {
    ProviderCredential::fake_api_key("querit", &querit_cookie())
}

fn querit_cookie() -> String {
    format!(
        "osfuid=user-placeholder; {}=session-placeholder; {}=refresh-placeholder",
        "osduss", "passOsRefreshTk"
    )
}

#[test]
fn querit_fixture_parses_monthly_coupon_quota() {
    let client = QueritProvider::default();
    let snapshot = client
        .check_fixture_quota(querit_credential())
        .expect("fixture should parse");

    assert_eq!(snapshot.provider_id, "querit");
    assert_eq!(snapshot.remaining, Some(80.0));
    assert_eq!(snapshot.limit, Some(100.0));
    assert_eq!(snapshot.remaining_badge_text, "80 / 100 monthly requests");
    assert_eq!(snapshot.quota_label.as_deref(), Some("monthly requests"));
    assert_eq!(snapshot.quota_windows.len(), 1);
    assert_eq!(snapshot.quota_windows[0].name, "month");
    assert_eq!(snapshot.quota_windows[0].percent_remaining, Some(80.0));
    assert_eq!(
        snapshot.quota_windows[0].remaining_text.as_deref(),
        Some("80 / 100")
    );
}

#[test]
fn querit_without_coupon_quota_reports_usage_without_fake_limit() {
    let client = QueritProvider::default();
    let snapshot = client
        .check_usage_without_limit_fixture(querit_credential())
        .expect("usage-only fixture should parse");

    assert_eq!(snapshot.provider_id, "querit");
    assert_eq!(snapshot.remaining, None);
    assert_eq!(snapshot.limit, None);
    assert_eq!(snapshot.remaining_badge_text, "24 monthly requests used");
    assert_eq!(snapshot.quota_label.as_deref(), Some("monthly requests"));
    assert!(snapshot.quota_windows.is_empty());
}

#[test]
fn querit_missing_dashboard_cookie_maps_to_unauthorized() {
    let client = QueritProvider::default();
    let error = client
        .check_fixture_quota(ProviderCredential::fake_api_key(
            "querit",
            "osfuid=user-placeholder",
        ))
        .expect_err("missing session cookies should fail");

    assert!(matches!(
        error,
        ProviderError::Unauthorized(message) if message.contains("Querit web login")
    ));
}

#[test]
fn querit_login_failure_maps_to_unauthorized() {
    let client = QueritProvider::default();
    let error = client
        .check_login_failure_fixture(querit_credential())
        .expect_err("login failure should fail");

    assert!(matches!(
        error,
        ProviderError::Unauthorized(message) if message.contains("Querit web login")
    ));
}

#[test]
fn querit_live_quota_uses_account_endpoint_transport() {
    let client = QueritProvider::default();
    let transport = MockProviderTransport::responding(ProviderHttpResponse::new(
        200,
        r#"{"ErrNo":200,"Data":{"current_plan":{"free_usage_month":3,"paid_usage_month":7,"enterprise_usage_month":0,"coupon_quota":50,"coupon_used":11}}}"#,
    ));

    let snapshot = client
        .check_quota(querit_credential(), &transport)
        .expect("live Querit response should parse");

    assert_eq!(snapshot.remaining, Some(39.0));
    assert_eq!(snapshot.limit, Some(50.0));
    assert_eq!(snapshot.remaining_badge_text, "39 / 50 monthly requests");

    let requests = transport.requests();
    assert_eq!(requests.len(), 1);
    assert_eq!(requests[0].method, "GET");
    assert_eq!(requests[0].url, "https://www.querit.ai/api/v1/user/account");
    assert!(requests[0]
        .headers
        .contains(&("Cookie".to_string(), querit_cookie())));
    assert!(requests[0]
        .headers
        .contains(&("Accept".to_string(), "application/json".to_string())));
    assert!(requests[0].headers.contains(&(
        "Referer".to_string(),
        "https://www.querit.ai/zh/dashboard/home".to_string()
    )));
}
