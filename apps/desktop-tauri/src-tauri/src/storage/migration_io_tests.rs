use std::{fs, path::PathBuf};

use serde_json::Value;

use super::{
    metadata_store::{
        load_credentials, load_settings, save_settings, MemoryMetadataStore, MetadataStore,
    },
    migration_io::{
        migrate_swift_configuration_from_paths, SwiftMigrationFilePaths,
        SWIFT_MIGRATION_COMPLETED_KEY,
    },
    secret_store::{MemorySecretVault, SecretVault},
};

#[test]
fn swift_migration_paths_match_macos_app_locations_under_home() {
    let paths = SwiftMigrationFilePaths::for_home(PathBuf::from("/Users/example"));

    assert_eq!(
        paths.quota_radar_preferences,
        PathBuf::from("/Users/example/Library/Preferences/com.gaorongvc.quotaradar.plist")
    );
    assert_eq!(
        paths.quota_bar_preferences,
        PathBuf::from("/Users/example/Library/Preferences/com.gaorongvc.quotabar.plist")
    );
    assert_eq!(
        paths.quota_radar_secrets,
        PathBuf::from("/Users/example/Library/Application Support/QuotaRadar/secrets.json")
    );
    assert_eq!(
        paths.quota_bar_secrets,
        PathBuf::from("/Users/example/Library/Application Support/QuotaBar/secrets.json")
    );
}

#[test]
fn migrates_swift_plist_and_secret_files_once_then_respects_completion_marker() {
    let root = temp_root("swift-plist-migration");
    let preferences = root.join("Preferences");
    let support = root.join("Application Support");
    fs::create_dir_all(&preferences).expect("preferences dir");
    fs::create_dir_all(support.join("QuotaRadar")).expect("quota radar support dir");
    fs::create_dir_all(support.join("QuotaBar")).expect("quota bar support dir");
    let paths = SwiftMigrationFilePaths {
        quota_radar_preferences: preferences.join("com.gaorongvc.quotaradar.plist"),
        quota_bar_preferences: preferences.join("com.gaorongvc.quotabar.plist"),
        quota_radar_secrets: support.join("QuotaRadar").join("secrets.json"),
        quota_bar_secrets: support.join("QuotaBar").join("secrets.json"),
    };
    fs::write(
        &paths.quota_radar_preferences,
        swift_preferences_plist(
            "zh-Hans",
            "W3siaWQiOiIwMDAwMDAwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAyMDEiLCJuYW1lIjoiVEFWSUxZX0FQSV9LRVkiLCJwcm92aWRlciI6IlRhdmlseSIsImlzQWN0aXZlIjp0cnVlLCJyZW1haW5pbmciOjgwMCwibGltaXQiOjEwMDAsInJlc2V0QXQiOjgwNDU1NjgwMCwicGxhbkVuZHNBdCI6bnVsbCwibGFzdFVwZGF0ZWQiOjgwMjg2NDgwMCwibGFzdEhUVFBTdGF0dXMiOjIwMCwibGFzdERpYWdub3N0aWNNZXNzYWdlIjpudWxsLCJxdW90YUxhYmVsIjoiY3JlZGl0cyIsInVzYWdlQ291bnQiOjB9XQ==",
        ),
    )
    .expect("write current plist");
    fs::write(
        &paths.quota_radar_secrets,
        r#"{"00000000-0000-0000-0000-000000000201":"tvly-file-secret"}"#,
    )
    .expect("write current secrets");

    let metadata_store = MemoryMetadataStore::default();
    let secret_vault = MemorySecretVault::default();

    let summary = migrate_swift_configuration_from_paths(&metadata_store, &secret_vault, &paths)
        .expect("Swift files should migrate");

    assert_eq!(summary.added, 1);
    assert_eq!(summary.secrets_saved, 1);
    assert_eq!(
        metadata_store.get_value(SWIFT_MIGRATION_COMPLETED_KEY),
        Some(Value::Bool(true))
    );
    let credentials = load_credentials(&metadata_store).expect("credentials load");
    assert_eq!(credentials.len(), 1);
    assert_eq!(credentials[0].provider_id, "tavily");
    assert_eq!(credentials[0].remaining, Some(800.0));
    assert_eq!(
        secret_vault
            .read("00000000-0000-0000-0000-000000000201")
            .expect("secret read"),
        Some("tvly-file-secret".to_string())
    );
    let mut settings = load_settings(&metadata_store).expect("settings load");
    assert_eq!(settings.language, "zh-Hans");

    settings.language = "ja".to_string();
    save_settings(&metadata_store, &settings).expect("settings save");
    fs::write(
        &paths.quota_radar_preferences,
        swift_preferences_plist("ko", ""),
    )
    .expect("rewrite current plist");

    let second_summary =
        migrate_swift_configuration_from_paths(&metadata_store, &secret_vault, &paths)
            .expect("second migration should no-op");

    assert_eq!(second_summary.added, 0);
    assert_eq!(
        load_settings(&metadata_store)
            .expect("settings reload")
            .language,
        "ja"
    );

    fs::remove_dir_all(root).ok();
}

fn swift_preferences_plist(language: &str, metadata_base64: &str) -> String {
    let metadata_entry = if metadata_base64.is_empty() {
        String::new()
    } else {
        format!(
            r#"
    <key>apiKeyMetadata</key>
    <data>{metadata_base64}</data>"#
        )
    };
    format!(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>appLanguage</key>
    <string>{language}</string>
    <key>statusBarTransparency</key>
    <real>0.64</real>
    <key>autoRefreshInterval</key>
    <string>thirtyMinutes</string>
    <key>quotaConsumingAutoRefreshInterval</key>
    <string>sixHours</string>
    <key>networkProxyMode</key>
    <string>custom</string>
    <key>customProxyURL</key>
    <string>socks5://127.0.0.1:7890</string>
    <key>automaticallyCheckForUpdates</key>
    <false/>
    <key>customProviderOrderEnabled</key>
    <true/>
    <key>providerOrder</key>
    <array>
        <string>Claude Subscription</string>
        <string>Tavily</string>
    </array>{metadata_entry}
</dict>
</plist>
"#
    )
}

fn temp_root(name: &str) -> PathBuf {
    let unique = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .expect("test clock")
        .as_nanos();
    let root = std::env::temp_dir().join(format!(
        "quotaradar-{name}-{}-{unique}",
        std::process::id(),
    ));
    fs::remove_dir_all(&root).ok();
    fs::create_dir_all(&root).expect("temp root");
    root
}
