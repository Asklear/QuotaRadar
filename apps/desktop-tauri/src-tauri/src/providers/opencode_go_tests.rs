use super::{
    http::{MockProviderTransport, ProviderHttpResponse},
    opencode_go::OpenCodeGoProvider,
    ProviderClient, ProviderCredential, ProviderError,
};

fn opencode_credential() -> ProviderCredential {
    ProviderCredential::fake_api_key(
        "opencode_go",
        r#"{"cookie":"auth=opencode-auth-placeholder; oc_locale=zh","workspaceID":"wrk_placeholder","serverID":"server-id-placeholder","serverInstance":"server-fn:11"}"#,
    )
}

#[test]
fn opencode_fixture_parses_server_function_usage_windows() {
    let client = OpenCodeGoProvider::default();
    let snapshot = client
        .check_fixture_quota(opencode_credential())
        .expect("fixture should parse");

    assert_eq!(snapshot.provider_id, "opencode_go");
    assert_eq!(snapshot.remaining, Some(2500.0));
    assert_eq!(snapshot.limit, Some(10_000.0));
    assert_eq!(
        snapshot.remaining_badge_text,
        "5h 98% · week 50% · month 25%"
    );
    assert_eq!(snapshot.quota_label.as_deref(), Some("subscription"));
    assert_eq!(snapshot.plan_ends_at, None);
    assert!(snapshot.reset_at.is_some());
    assert_eq!(snapshot.quota_windows.len(), 3);
    assert_eq!(snapshot.quota_windows[0].name, "5h");
    assert_eq!(snapshot.quota_windows[0].percent_remaining, Some(98.0));
    assert_eq!(snapshot.quota_windows[1].name, "week");
    assert_eq!(snapshot.quota_windows[1].percent_remaining, Some(50.0));
    assert_eq!(snapshot.quota_windows[2].name, "month");
    assert_eq!(snapshot.quota_windows[2].percent_remaining, Some(25.0));
}

#[test]
fn opencode_raw_auth_cookie_is_supported() {
    let client = OpenCodeGoProvider::default();
    let snapshot = client
        .check_fixture_quota(ProviderCredential::fake_api_key(
            "opencode_go",
            "auth=opencode-auth-placeholder; oc_locale=zh",
        ))
        .expect("raw auth cookie should be accepted");

    assert_eq!(
        snapshot.remaining_badge_text,
        "5h 98% · week 50% · month 25%"
    );
}

#[test]
fn opencode_auth_redirect_maps_to_unauthorized() {
    let client = OpenCodeGoProvider::default();
    let error = client
        .check_auth_redirect_fixture(opencode_credential())
        .expect_err("auth redirect should fail");

    assert!(matches!(
        error,
        ProviderError::Unauthorized(message) if message.contains("OpenCode Go web login")
    ));
}

#[test]
fn opencode_missing_auth_cookie_maps_to_unauthorized() {
    let client = OpenCodeGoProvider::default();
    let error = client
        .check_fixture_quota(ProviderCredential::fake_api_key(
            "opencode_go",
            "oc_locale=zh",
        ))
        .expect_err("missing auth cookie should fail");

    assert!(matches!(
        error,
        ProviderError::Unauthorized(message) if message.contains("OpenCode Go web login")
    ));
}

#[test]
fn opencode_missing_usage_windows_maps_to_quota_unavailable() {
    let client = OpenCodeGoProvider::default();
    let error = client
        .check_missing_usage_fixture(opencode_credential())
        .expect_err("missing usage windows should fail");

    assert!(matches!(
        error,
        ProviderError::QuotaUnavailable(message) if message.contains("OpenCode Go usage")
    ));
}

#[test]
fn opencode_live_quota_uses_server_function_transport() {
    let client = OpenCodeGoProvider::default();
    let transport = MockProviderTransport::responding(ProviderHttpResponse::new(
        200,
        r#";0x00000129;((self.$R=self.$R||{})["server-fn:11"]=[],($R=>$R[0]={mine:!0,useBalance:!1,rollingUsage:$R[1]={status:"ok",resetInSec:100,usagePercent:10},weeklyUsage:$R[2]={status:"ok",resetInSec:200,usagePercent:40},monthlyUsage:$R[3]={status:"ok",resetInSec:300,usagePercent:60}})($R["server-fn:11"]))"#,
    ));

    let snapshot = client
        .check_quota(opencode_credential(), &transport)
        .expect("live OpenCode Go response should parse");

    assert_eq!(snapshot.remaining, Some(4000.0));
    assert_eq!(snapshot.limit, Some(10_000.0));
    assert_eq!(
        snapshot.remaining_badge_text,
        "5h 90% · week 60% · month 40%"
    );

    let requests = transport.requests();
    assert_eq!(requests.len(), 1);
    assert_eq!(requests[0].method, "GET");
    assert!(requests[0]
        .url
        .starts_with("https://opencode.ai/_server?id=server-id-placeholder&args="));
    assert!(requests[0].url.contains("wrk_placeholder"));
    assert!(requests[0].headers.contains(&(
        "Cookie".to_string(),
        "auth=opencode-auth-placeholder; oc_locale=zh".to_string()
    )));
    assert!(requests[0]
        .headers
        .contains(&("Accept-Language".to_string(), "zh-CN,zh;q=0.9".to_string())));
    assert!(requests[0]
        .headers
        .contains(&("Cache-Control".to_string(), "no-cache".to_string())));
    assert!(requests[0]
        .headers
        .contains(&("sec-fetch-mode".to_string(), "cors".to_string())));
    assert!(requests[0]
        .headers
        .contains(&("sec-fetch-site".to_string(), "same-origin".to_string())));
    assert!(requests[0]
        .headers
        .iter()
        .any(|(name, value)| { name == "User-Agent" && value.contains("Mozilla/5.0") }));
    assert!(requests[0].headers.contains(&(
        "x-server-id".to_string(),
        "server-id-placeholder".to_string()
    )));
    assert!(requests[0]
        .headers
        .contains(&("x-server-instance".to_string(), "server-fn:11".to_string())));
}

#[test]
fn opencode_live_quota_uses_swift_defaults_for_web_auth_cookie_only() {
    let client = OpenCodeGoProvider::default();
    let transport = MockProviderTransport::responding(ProviderHttpResponse::new(
        200,
        r#";0x00000129;((self.$R=self.$R||{})["server-fn:11"]=[],($R=>$R[0]={mine:!0,useBalance:!1,rollingUsage:$R[1]={status:"ok",resetInSec:100,usagePercent:10},weeklyUsage:$R[2]={status:"ok",resetInSec:200,usagePercent:40},monthlyUsage:$R[3]={status:"ok",resetInSec:300,usagePercent:60}})($R["server-fn:11"]))"#,
    ));

    let snapshot = client
        .check_quota(
            ProviderCredential::fake_api_key(
                "opencode_go",
                r#"{"cookie":"auth=opencode-auth-placeholder; oc_locale=zh"}"#,
            ),
            &transport,
        )
        .expect("web auth cookie-only credential should use Swift defaults");

    assert_eq!(snapshot.remaining, Some(4000.0));
    let requests = transport.requests();
    assert_eq!(requests.len(), 1);
    assert!(requests[0].url.contains("wrk_01KSKR4K4WDJY0JZSCJTMRZ5CV"));
    assert!(requests[0].url.starts_with(
        "https://opencode.ai/_server?id=c7389bd0e731f80f49593e5ee53835475f4e28594dd6bd83eb229bab753498cd&args="
    ));
    assert!(requests[0].headers.contains(&(
        "x-server-id".to_string(),
        "c7389bd0e731f80f49593e5ee53835475f4e28594dd6bd83eb229bab753498cd".to_string()
    )));
    assert!(requests[0]
        .headers
        .contains(&("x-server-instance".to_string(), "server-fn:11".to_string())));
}
