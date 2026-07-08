use super::metadata_store::{
    default_settings, load_settings, move_provider_in_settings, save_settings, MemoryMetadataStore,
    MetadataStore,
};
use crate::domain::{ProxyMode, RefreshInterval};
use serde_json::json;

#[test]
fn default_settings_include_stable_provider_order_and_refresh_policy() {
    let settings = default_settings();

    assert_eq!(settings.language, "en");
    assert_eq!(settings.proxy.mode, ProxyMode::System);
    assert!(!settings.launch_at_login);
    assert_eq!(settings.auto_refresh_interval, RefreshInterval::Off);
    assert_eq!(settings.costly_refresh_interval, RefreshInterval::Off);
    assert_eq!(
        settings.provider_order.first().map(String::as_str),
        Some("tavily")
    );
    assert_eq!(
        settings.provider_order.last().map(String::as_str),
        Some("tencent_cloud_coding_plan")
    );
    assert!(settings
        .provider_order
        .iter()
        .any(|provider_id| provider_id == "kimi"));
    assert!(settings
        .provider_order
        .iter()
        .any(|provider_id| provider_id == "aliyun_coding_plan"));
    assert!(settings
        .provider_order
        .iter()
        .any(|provider_id| provider_id == "querit"));
}

#[test]
fn settings_round_trip_through_metadata_store() {
    let store = MemoryMetadataStore::default();
    let mut settings = default_settings();
    settings.language = "zh-Hans".to_string();
    settings.proxy.mode = ProxyMode::Custom;
    settings.proxy.custom_url = Some("socks5://127.0.0.1:7890".to_string());
    settings.auto_refresh_interval = RefreshInterval::OneHour;
    settings.costly_refresh_interval = RefreshInterval::SixHours;
    settings.provider_order = vec![
        "kimi".to_string(),
        "tavily".to_string(),
        "brave".to_string(),
    ];

    save_settings(&store, &settings).expect("settings should save");
    let loaded = load_settings(&store).expect("settings should load");

    assert_eq!(loaded.language, settings.language);
    assert_eq!(loaded.proxy, settings.proxy);
    assert_eq!(loaded.auto_refresh_interval, settings.auto_refresh_interval);
    assert_eq!(
        loaded.costly_refresh_interval,
        settings.costly_refresh_interval
    );
    assert_eq!(&loaded.provider_order[..3], ["kimi", "tavily", "brave"]);
    assert_eq!(
        loaded.provider_order.len(),
        default_settings().provider_order.len()
    );
}

#[test]
fn load_settings_sanitizes_stale_provider_order_from_older_builds() {
    let store = MemoryMetadataStore::default();
    store.set_value(
        "settings",
        json!({
            "language": "en",
            "launchAtLogin": false,
            "updateCheck": true,
            "autoRefreshInterval": "off",
            "costlyRefreshInterval": "off",
            "proxy": {
                "mode": "system",
                "customUrl": null
            },
            "trayTransparency": 82,
            "providerOrder": [
                "kimi",
                "unknown_provider",
                "tavily",
                "kimi"
            ]
        }),
    );

    let loaded = load_settings(&store).expect("settings should load");

    assert_eq!(&loaded.provider_order[..2], ["kimi", "tavily"]);
    assert!(!loaded
        .provider_order
        .iter()
        .any(|provider| provider == "unknown_provider"));
    assert_eq!(
        loaded
            .provider_order
            .iter()
            .filter(|provider| provider.as_str() == "kimi")
            .count(),
        1
    );
    assert_eq!(
        loaded.provider_order.len(),
        default_settings().provider_order.len()
    );
    assert_eq!(
        loaded.provider_order.last().map(String::as_str),
        Some("tencent_cloud_coding_plan")
    );
}

#[test]
fn move_provider_updates_order_without_losing_items() {
    let mut settings = default_settings();

    move_provider_in_settings(&mut settings, "kimi", 1);

    assert_eq!(settings.provider_order[0], "tavily");
    assert_eq!(settings.provider_order[1], "kimi");
    assert_eq!(
        settings.provider_order.len(),
        default_settings().provider_order.len()
    );
}
