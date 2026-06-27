use super::{
    http::{MockProviderTransport, ProviderHttpResponse},
    registry::{registered_provider_ids, visible_provider_definitions, visible_provider_ids},
    ProviderClient, ProviderCredential,
};

#[test]
fn visible_provider_registry_excludes_pending_providers() {
    let visible_ids = visible_provider_ids();

    assert!(visible_ids.contains(&"tavily"));
    assert!(visible_ids.contains(&"deepseek"));
    assert!(visible_ids.contains(&"querit"));
    assert!(!visible_ids.contains(&"aliyun-token-plan"));
    assert!(!visible_ids.contains(&"tencent-token-plan"));
}

#[test]
fn tavily_and_deepseek_are_registered_provider_clients() {
    let registered_ids = registered_provider_ids();

    assert!(registered_ids.contains(&"tavily"));
    assert!(registered_ids.contains(&"deepseek"));
    assert!(registered_ids.contains(&"querit"));
    assert!(registered_ids.contains(&"anthropic_credits"));
}

#[test]
fn anthropic_credits_is_visible_as_separate_llm_provider() {
    let visible_ids = visible_provider_ids();
    let definitions = visible_provider_definitions();
    let definition = definitions
        .iter()
        .find(|provider| provider.id == "anthropic_credits")
        .expect("Anthropic Credits should be visible");

    assert!(visible_ids.contains(&"anthropic_credits"));
    assert_eq!(definition.display_name, "Anthropic Credits");
    assert_eq!(definition.family_name, "Anthropic");
    assert_eq!(definition.plan_type.as_deref(), Some("Credits"));
    assert!(!definition.quota_check_consumes_search_quota);
}

#[test]
fn only_dashboard_cookie_providers_show_reauthorization() {
    let definitions = visible_provider_definitions();
    let deepseek = definitions
        .iter()
        .find(|provider| provider.id == "deepseek")
        .expect("DeepSeek should be visible");
    let codex = definitions
        .iter()
        .find(|provider| provider.id == "codex")
        .expect("Codex should be visible");

    assert!(!deepseek.supports_reauth);
    assert!(codex.supports_reauth);
}

#[test]
fn no_cost_api_key_providers_do_not_consume_quota_on_check() {
    for provider in visible_provider_definitions()
        .into_iter()
        .filter(|provider| provider.id != "brave")
    {
        assert!(
            !provider.quota_check_consumes_search_quota,
            "{} should not consume quota while checking quota",
            provider.id
        );
    }
}

#[test]
fn tavily_fixture_parses_monthly_credit_snapshot() {
    let client = super::tavily::TavilyProvider::default();
    let snapshot = client
        .check_fixture_quota(ProviderCredential::fake_api_key("tavily", "tvly-test"))
        .expect("fixture should parse");

    assert_eq!(snapshot.provider_id, "tavily");
    assert_eq!(snapshot.remaining, Some(920.0));
    assert_eq!(snapshot.limit, Some(1000.0));
    assert_eq!(snapshot.quota_windows[0].name, "month");
    assert_eq!(snapshot.quota_windows[0].percent_remaining, Some(92.0));
}

#[test]
fn tavily_live_quota_uses_usage_endpoint_transport() {
    let client = super::tavily::TavilyProvider::default();
    let transport = MockProviderTransport::responding(ProviderHttpResponse::new(
        200,
        r#"{"key":{"usage":80,"limit":1000},"account":{"plan_usage":300,"plan_limit":5000}}"#,
    ));

    let snapshot = client
        .check_quota(
            ProviderCredential::fake_api_key("tavily", "tvly-live-test"),
            &transport,
        )
        .expect("live response should parse");

    assert_eq!(snapshot.remaining, Some(920.0));
    assert_eq!(snapshot.limit, Some(1000.0));
    let requests = transport.requests();
    assert_eq!(requests.len(), 1);
    assert_eq!(requests[0].method, "GET");
    assert_eq!(requests[0].url, "https://api.tavily.com/usage");
    assert!(requests[0].headers.contains(&(
        "Authorization".to_string(),
        "Bearer tvly-live-test".to_string()
    )));
}

#[test]
fn tavily_live_quota_maps_unauthorized_status() {
    let client = super::tavily::TavilyProvider::default();
    let transport = MockProviderTransport::responding(ProviderHttpResponse::new(401, "{}"));

    let error = client
        .check_quota(
            ProviderCredential::fake_api_key("tavily", "tvly-live-test"),
            &transport,
        )
        .expect_err("401 should fail");

    assert!(
        matches!(error, super::ProviderError::Unauthorized(message) if message.contains("Tavily"))
    );
}

#[test]
fn deepseek_fixture_parses_rmb_balance_snapshot() {
    let client = super::deepseek::DeepSeekProvider::default();
    let snapshot = client
        .check_fixture_quota(ProviderCredential::fake_api_key(
            "deepseek",
            "deepseek-test",
        ))
        .expect("fixture should parse");

    assert_eq!(snapshot.provider_id, "deepseek");
    assert_eq!(snapshot.quota_label.as_deref(), Some("CNY"));
    assert_eq!(snapshot.remaining, Some(128.4));
    assert_eq!(snapshot.limit, Some(200.0));
    assert_eq!(snapshot.remaining_badge_text, "¥128.40 / ¥200.00");
}

#[test]
fn deepseek_live_quota_parses_official_balance_shape() {
    let client = super::deepseek::DeepSeekProvider::default();
    let transport = MockProviderTransport::responding(ProviderHttpResponse::new(
        200,
        r#"{"is_available":true,"balance_infos":[{"currency":"CNY","total_balance":"128.40"}]}"#,
    ));

    let snapshot = client
        .check_quota(
            ProviderCredential::fake_api_key("deepseek", "deepseek-live-test"),
            &transport,
        )
        .expect("live response should parse");

    assert_eq!(snapshot.remaining, Some(12840.0));
    assert_eq!(snapshot.limit, Some(12840.0));
    assert_eq!(snapshot.remaining_badge_text, "CNY 128.40 available");
    assert_eq!(snapshot.quota_label.as_deref(), Some("CNY"));
    let requests = transport.requests();
    assert_eq!(requests.len(), 1);
    assert_eq!(requests[0].url, "https://api.deepseek.com/user/balance");
    assert!(requests[0].headers.contains(&(
        "Authorization".to_string(),
        "Bearer deepseek-live-test".to_string()
    )));
}
