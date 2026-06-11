use super::{
    registry::{registered_provider_ids, visible_provider_definitions, visible_provider_ids},
    ProviderClient, ProviderCredential,
};

#[test]
fn visible_provider_registry_excludes_pending_providers() {
    let visible_ids = visible_provider_ids();

    assert!(visible_ids.contains(&"tavily"));
    assert!(visible_ids.contains(&"deepseek"));
    assert!(!visible_ids.contains(&"aliyun-token-plan"));
    assert!(!visible_ids.contains(&"tencent-token-plan"));
}

#[test]
fn tavily_and_deepseek_are_registered_provider_clients() {
    let registered_ids = registered_provider_ids();

    assert!(registered_ids.contains(&"tavily"));
    assert!(registered_ids.contains(&"deepseek"));
}

#[test]
fn first_api_key_providers_do_not_consume_quota_on_check() {
    for provider in visible_provider_definitions() {
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
fn deepseek_fixture_parses_rmb_balance_snapshot() {
    let client = super::deepseek::DeepSeekProvider::default();
    let snapshot = client
        .check_fixture_quota(ProviderCredential::fake_api_key("deepseek", "deepseek-test"))
        .expect("fixture should parse");

    assert_eq!(snapshot.provider_id, "deepseek");
    assert_eq!(snapshot.quota_label.as_deref(), Some("CNY"));
    assert_eq!(snapshot.remaining, Some(128.4));
    assert_eq!(snapshot.limit, Some(200.0));
    assert_eq!(snapshot.remaining_badge_text, "¥128.40 / ¥200.00");
}
