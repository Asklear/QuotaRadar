use crate::domain::{CredentialKind, CredentialStatus, ProxyMode, RefreshInterval};

use super::{
    metadata_store::{load_credentials, load_settings, MemoryMetadataStore},
    migration::{migrate_swift_configuration, SwiftMigrationInput},
    secret_store::{MemorySecretVault, SecretVault},
};

#[test]
fn migrates_swift_metadata_and_secrets_preserving_snapshot_and_links() {
    let metadata_store = MemoryMetadataStore::default();
    let secret_vault = MemorySecretVault::default();
    let swift_metadata = r#"[
      {
        "id": "00000000-0000-0000-0000-000000000001",
        "name": "TAVILY_API_KEY",
        "provider": "Tavily",
        "isActive": true,
        "remaining": 920,
        "limit": 1000,
        "resetAt": 804556800,
        "planEndsAt": null,
        "lastUpdated": 802864800,
        "lastHTTPStatus": 200,
        "lastDiagnosticMessage": "OK",
        "quotaLabel": "credits",
        "usageCount": 0
      },
      {
        "id": "00000000-0000-0000-0000-000000000002",
        "name": "CLAUDE_SUBSCRIPTION_SESSION",
        "provider": "Claude Subscription",
        "isActive": true,
        "remaining": 75,
        "limit": 100,
        "resetAt": 804556800,
        "planEndsAt": 807235200,
        "lastUpdated": 802864800,
        "lastHTTPStatus": 200,
        "lastDiagnosticMessage": null,
        "quotaLabel": "subscription",
        "usageCount": 0
      },
      {
        "id": "00000000-0000-0000-0000-000000000003",
        "name": "ANTHROPIC_API_KEY",
        "provider": "Claude Subscription",
        "isActive": true,
        "linkedAuthorizationID": "00000000-0000-0000-0000-000000000002",
        "remaining": null,
        "limit": null,
        "resetAt": null,
        "planEndsAt": null,
        "lastUpdated": 802864800,
        "lastHTTPStatus": null,
        "lastDiagnosticMessage": null,
        "quotaLabel": null,
        "usageCount": 0
      },
      {
        "id": "00000000-0000-0000-0000-000000000004",
        "name": "CODEX_SUBSCRIPTION_SESSION",
        "provider": "Codex Subscription",
        "isActive": true,
        "remaining": 60,
        "limit": 100,
        "resetAt": 804556800,
        "planEndsAt": 807235200,
        "codexResetCreditsRemaining": 2,
        "codexResetCreditsEarliestExpiresAt": "2026-07-18T00:38:14Z",
        "lastUpdated": 802864800,
        "lastHTTPStatus": 200,
        "lastDiagnosticMessage": null,
        "quotaLabel": "subscription",
        "usageCount": 0
      }
    ]"#;
    let swift_secrets = r#"{
      "00000000-0000-0000-0000-000000000001": "tvly-real-secret",
      "00000000-0000-0000-0000-000000000002": "session=claude",
      "00000000-0000-0000-0000-000000000003": "anthropic-copyable-placeholder",
      "00000000-0000-0000-0000-000000000004": "__Secure-next-auth.session-token=codex"
    }"#;

    let summary = migrate_swift_configuration(
        &metadata_store,
        &secret_vault,
        SwiftMigrationInput {
            quota_radar_metadata_json: Some(swift_metadata),
            quota_radar_secrets_json: Some(swift_secrets),
            ..SwiftMigrationInput::default()
        },
    )
    .expect("Swift metadata should migrate");

    assert_eq!(summary.added, 4);
    assert_eq!(summary.skipped, 0);
    assert_eq!(summary.secrets_saved, 4);

    let credentials = load_credentials(&metadata_store).expect("credentials should load");
    assert_eq!(credentials.len(), 4);

    let tavily = credentials
        .iter()
        .find(|credential| credential.id == "00000000-0000-0000-0000-000000000001")
        .expect("Tavily should migrate");
    assert_eq!(tavily.provider_id, "tavily");
    assert_eq!(tavily.kind, CredentialKind::ApiKey);
    assert_eq!(tavily.masked_value, "tvly••••cret");
    assert_eq!(tavily.status, CredentialStatus::Healthy);
    assert_eq!(tavily.remaining, Some(920.0));
    assert_eq!(tavily.limit, Some(1000.0));
    assert_eq!(tavily.remaining_badge_text, "920 / 1000");
    assert_eq!(tavily.quota_label.as_deref(), Some("credits"));
    assert_eq!(tavily.reset_at.as_deref(), Some("2026-07-01T00:00:00Z"));
    assert_eq!(tavily.last_updated.as_deref(), Some("2026-06-11T10:00:00Z"));
    assert_eq!(tavily.last_http_status, Some(200));
    assert_eq!(tavily.diagnostic_message.as_deref(), Some("OK"));
    assert_eq!(tavily.quota_windows[0].name, "month");
    assert_eq!(tavily.quota_windows[0].percent_remaining, Some(92.0));

    let claude = credentials
        .iter()
        .find(|credential| credential.id == "00000000-0000-0000-0000-000000000002")
        .expect("Claude authorization should migrate");
    assert_eq!(claude.provider_id, "claude");
    assert_eq!(claude.kind, CredentialKind::DashboardCookie);
    assert!(!claude.copyable);
    assert_eq!(claude.masked_value, "Web login authorization saved");
    assert_eq!(claude.plan_ends_at.as_deref(), Some("2026-08-01T00:00:00Z"));

    let companion = credentials
        .iter()
        .find(|credential| credential.id == "00000000-0000-0000-0000-000000000003")
        .expect("companion API key should migrate");
    assert_eq!(companion.provider_id, "claude");
    assert_eq!(companion.kind, CredentialKind::StoredApiKeyOnly);
    assert!(companion.copyable);
    assert_eq!(
        companion.linked_authorization_id.as_deref(),
        Some("00000000-0000-0000-0000-000000000002")
    );

    let codex = credentials
        .iter()
        .find(|credential| credential.id == "00000000-0000-0000-0000-000000000004")
        .expect("Codex authorization should migrate");
    assert_eq!(codex.provider_id, "codex");
    assert_eq!(codex.kind, CredentialKind::DashboardCookie);
    assert_eq!(codex.codex_reset_credits_remaining, Some(2));
    assert_eq!(
        codex.codex_reset_credits_earliest_expires_at.as_deref(),
        Some("2026-07-18T00:38:14Z")
    );

    assert_eq!(
        secret_vault
            .read("00000000-0000-0000-0000-000000000001")
            .expect("secret read"),
        Some("tvly-real-secret".to_string())
    );
    assert_eq!(
        secret_vault
            .read("00000000-0000-0000-0000-000000000003")
            .expect("secret read"),
        Some("anthropic-copyable-placeholder".to_string())
    );
    assert_eq!(
        secret_vault
            .read("00000000-0000-0000-0000-000000000004")
            .expect("secret read"),
        Some("__Secure-next-auth.session-token=codex".to_string())
    );
}

#[test]
fn migrates_swift_preferences_into_tauri_settings() {
    let metadata_store = MemoryMetadataStore::default();
    let secret_vault = MemorySecretVault::default();
    let swift_defaults = r#"{
      "appLanguage": "zh-Hans",
      "statusBarTransparency": 0.64,
      "autoRefreshInterval": "thirtyMinutes",
      "quotaConsumingAutoRefreshInterval": "sixHours",
      "networkProxyMode": "custom",
      "customProxyURL": "socks5://127.0.0.1:7890",
      "automaticallyCheckForUpdates": false,
      "customProviderOrderEnabled": true,
      "providerOrder": ["Claude Subscription", "Tavily", "Aliyun Coding Plan"]
    }"#;

    migrate_swift_configuration(
        &metadata_store,
        &secret_vault,
        SwiftMigrationInput {
            quota_radar_defaults_json: Some(swift_defaults),
            ..SwiftMigrationInput::default()
        },
    )
    .expect("Swift preferences should migrate");

    let settings = load_settings(&metadata_store).expect("settings should load");
    assert_eq!(settings.language, "zh-Hans");
    assert_eq!(settings.tray_transparency, 64);
    assert_eq!(
        settings.auto_refresh_interval,
        RefreshInterval::ThirtyMinutes
    );
    assert_eq!(settings.costly_refresh_interval, RefreshInterval::SixHours);
    assert_eq!(settings.proxy.mode, ProxyMode::Custom);
    assert_eq!(
        settings.proxy.custom_url.as_deref(),
        Some("socks5://127.0.0.1:7890")
    );
    assert!(!settings.update_check);
    assert_eq!(
        &settings.provider_order[..3],
        ["claude", "tavily", "aliyun_coding_plan"]
    );
    assert!(settings
        .provider_order
        .iter()
        .any(|provider| provider == "tencent_cloud_coding_plan"));
}

#[test]
fn legacy_quota_bar_payload_is_ignored_after_one_way_migration_marker() {
    let metadata_store = MemoryMetadataStore::default();
    let secret_vault = MemorySecretVault::default();
    let legacy_defaults = r#"{
      "appLanguage": "zh-Hans",
      "customProviderOrderEnabled": true,
      "providerOrder": ["Claude Subscription", "Tavily"]
    }"#;
    let legacy_metadata = r#"[
      {
        "id": "00000000-0000-0000-0000-000000000101",
        "name": "TAVILY_API_KEY",
        "provider": "Tavily",
        "isActive": true,
        "remaining": 1,
        "limit": 1000,
        "resetAt": 804556800,
        "planEndsAt": null,
        "lastUpdated": null,
        "lastHTTPStatus": 200,
        "lastDiagnosticMessage": null,
        "quotaLabel": "credits",
        "usageCount": 0
      }
    ]"#;

    let summary = migrate_swift_configuration(
        &metadata_store,
        &secret_vault,
        SwiftMigrationInput {
            quota_bar_defaults_json: Some(legacy_defaults),
            quota_bar_metadata_json: Some(legacy_metadata),
            legacy_migration_already_completed: true,
            ..SwiftMigrationInput::default()
        },
    )
    .expect("completed legacy migration should be ignored");

    assert_eq!(summary.added, 0);
    assert_eq!(summary.skipped, 0);
    assert_eq!(
        load_credentials(&metadata_store)
            .expect("credentials load")
            .len(),
        0
    );
    let settings = load_settings(&metadata_store).expect("settings load");
    assert_eq!(settings.language, "en");
    assert_eq!(
        settings.provider_order.first().map(String::as_str),
        Some("tavily")
    );
}
