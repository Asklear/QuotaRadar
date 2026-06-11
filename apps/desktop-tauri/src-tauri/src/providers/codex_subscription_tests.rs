use super::{
    codex_subscription::CodexSubscriptionProvider, ProviderClient, ProviderCredential,
    ProviderError,
};

fn codex_credential() -> ProviderCredential {
    ProviderCredential::fake_api_key(
        "codex",
        "__Secure-next-auth.session-token=chatgpt-session-placeholder; __search-next-auth=search-session-placeholder",
    )
}

#[test]
fn codex_fixture_parses_wham_windows_and_plan_end() {
    let client = CodexSubscriptionProvider::default();
    let snapshot = client
        .check_fixture_quota(codex_credential())
        .expect("fixture should parse");

    assert_eq!(snapshot.provider_id, "codex");
    assert_eq!(snapshot.remaining, Some(3000.0));
    assert_eq!(snapshot.limit, Some(10_000.0));
    assert_eq!(snapshot.remaining_badge_text, "5h 100% · week 30%");
    assert_eq!(snapshot.quota_label.as_deref(), Some("subscription"));
    assert_eq!(
        snapshot.plan_ends_at.as_deref(),
        Some("2026-07-08T16:42:25Z")
    );
    assert_eq!(
        snapshot.reset_at.as_deref(),
        Some("2026-06-11T01:09:07Z")
    );
    assert_eq!(snapshot.quota_windows.len(), 2);
    assert_eq!(snapshot.quota_windows[0].name, "5h");
    assert_eq!(snapshot.quota_windows[0].percent_remaining, Some(100.0));
    assert_eq!(
        snapshot.quota_windows[0].reset_at.as_deref(),
        Some("2026-06-08T13:21:18Z")
    );
    assert_eq!(snapshot.quota_windows[1].name, "week");
    assert_eq!(snapshot.quota_windows[1].percent_remaining, Some(30.0));
}

#[test]
fn codex_chunked_session_cookie_is_supported() {
    let client = CodexSubscriptionProvider::default();
    let snapshot = client
        .check_fixture_quota(ProviderCredential::fake_api_key(
            "codex",
            "__Secure-next-auth.session-token.0=session-part-a; __Secure-next-auth.session-token.1=session-part-b",
        ))
        .expect("chunked session cookie should be accepted");

    assert_eq!(snapshot.remaining_badge_text, "5h 100% · week 30%");
}

#[test]
fn codex_missing_web_login_maps_to_unauthorized() {
    let client = CodexSubscriptionProvider::default();
    let error = client
        .check_fixture_quota(ProviderCredential::fake_api_key("codex", "{}"))
        .expect_err("missing web login should fail");

    assert!(matches!(
        error,
        ProviderError::Unauthorized(message) if message.contains("ChatGPT web login")
    ));
}

#[test]
fn codex_missing_rate_limit_maps_to_quota_unavailable() {
    let client = CodexSubscriptionProvider::default();
    let error = client
        .check_missing_rate_limit_fixture(codex_credential())
        .expect_err("missing rate limit should fail");

    assert!(matches!(
        error,
        ProviderError::QuotaUnavailable(message) if message.contains("Codex usage")
    ));
}
