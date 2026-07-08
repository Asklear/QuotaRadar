use std::{fs, io, path::PathBuf};

use crate::domain::CredentialKind;

use super::{
    credential_importer::{
        claude_settings_error_is_missing, import_claude_settings_content,
        import_claude_settings_file, import_credentials_into_store, parse_env_content,
        ImportedCredential, ImportedCredentialSource,
    },
    metadata_store::{load_credentials, MemoryMetadataStore, MetadataStore},
    secret_store::{MemorySecretVault, SecretVault},
};

#[test]
fn parses_claude_settings_env_into_visible_provider_credentials() {
    let imported = import_claude_settings_content(
        r#"{
          "env": {
            "TAVILY_API_KEY": "tvly-live-secret",
            "ANTHROPIC_API_KEY": "anthropic-example-value",
            "OPENAI_API_KEY": "openai-example-value",
            "KIMI_API_KEY": "kimi-example-value",
            "UNSUPPORTED_VENDOR_KEY": "ignored",
            "EMPTY_VALUE": ""
          }
        }"#,
    )
    .expect("Claude settings should parse");

    assert_eq!(imported.len(), 4);
    assert_eq!(imported[0].provider_id, "claude");
    assert_eq!(imported[0].name, "ANTHROPIC_API_KEY");
    assert_eq!(imported[0].kind, CredentialKind::StoredApiKeyOnly);
    assert_eq!(
        imported[0].note.as_deref(),
        Some("Imported from ~/.claude/settings.json")
    );

    assert_eq!(imported[1].provider_id, "codex");
    assert_eq!(imported[1].name, "OPENAI_API_KEY");
    assert_eq!(imported[1].kind, CredentialKind::StoredApiKeyOnly);

    assert_eq!(imported[2].provider_id, "kimi");
    assert_eq!(imported[2].name, "KIMI_API_KEY");
    assert_eq!(imported[2].kind, CredentialKind::StoredApiKeyOnly);

    assert_eq!(imported[3].provider_id, "tavily");
    assert_eq!(imported[3].name, "TAVILY_API_KEY");
    assert_eq!(imported[3].kind, CredentialKind::ApiKey);
}

#[test]
fn parses_env_content_with_quotes_exports_and_dashboard_authorizations() {
    let imported = parse_env_content(
        r#"
          # ignored comment
          export BRAVE_API_KEY="BSA-live-secret"
          KIMI_AUTH='mock-kimi-dashboard-authorization'
          VOLCENGINE_CODING_PLAN_COOKIE=session=volc
          ANTHROPIC_AUTH_TOKEN=not-imported
          PLACEHOLDER=xxx
        "#,
        ImportedCredentialSource::EnvFile,
    );

    assert_eq!(imported.len(), 3);
    assert_eq!(imported[0].provider_id, "brave");
    assert_eq!(imported[0].kind, CredentialKind::ApiKey);
    assert_eq!(imported[1].provider_id, "kimi");
    assert_eq!(imported[1].kind, CredentialKind::DashboardCookie);
    assert_eq!(imported[2].provider_id, "volcengine_coding_plan");
    assert_eq!(imported[2].kind, CredentialKind::DashboardCookie);
}

#[test]
fn missing_claude_settings_file_is_skipped_without_clearing_existing_credentials() {
    let metadata_store = MemoryMetadataStore::default();
    let secret_vault = MemorySecretVault::default();
    let first_summary = import_credentials_into_store(
        &metadata_store,
        &secret_vault,
        vec![ImportedCredential {
            provider_id: "brave".to_string(),
            name: "BRAVE_API_KEY".to_string(),
            kind: CredentialKind::ApiKey,
            secret: "brave-existing-secret".to_string(),
            note: Some("Imported from .env".to_string()),
        }],
    )
    .expect("initial import should save");

    let missing_settings_path = temp_root("missing-claude-settings")
        .join(".claude")
        .join("settings.json");
    let summary =
        import_claude_settings_file(&metadata_store, &secret_vault, &missing_settings_path)
            .expect("missing Claude settings should be skipped");

    assert_eq!(summary.added, 0);
    assert_eq!(summary.updated, 0);
    assert_eq!(summary.credentials, first_summary.credentials);
    assert_eq!(
        secret_vault
            .read("imported-brave-brave-api-key")
            .expect("secret read"),
        Some("brave-existing-secret".to_string())
    );
}

#[test]
fn windows_missing_claude_settings_errors_are_skipped_like_not_found() {
    assert!(claude_settings_error_is_missing(
        &io::Error::from_raw_os_error(2)
    ));
    assert!(claude_settings_error_is_missing(
        &io::Error::from_raw_os_error(3)
    ));
}

#[test]
fn imports_credentials_by_updating_provider_name_matches_without_leaking_secrets_to_metadata() {
    let metadata_store = MemoryMetadataStore::default();
    let secret_vault = MemorySecretVault::default();
    let first_summary = import_credentials_into_store(
        &metadata_store,
        &secret_vault,
        vec![ImportedCredential {
            provider_id: "tavily".to_string(),
            name: "TAVILY_API_KEY".to_string(),
            kind: CredentialKind::ApiKey,
            secret: "old-tavily-secret-value".to_string(),
            note: Some("Imported from .env".to_string()),
        }],
    )
    .expect("initial import should save");
    assert_eq!(first_summary.added, 1);
    let tavily_id = first_summary.credentials[0].id.clone();

    let second_summary = import_credentials_into_store(
        &metadata_store,
        &secret_vault,
        vec![
            ImportedCredential {
                provider_id: "tavily".to_string(),
                name: "TAVILY_API_KEY".to_string(),
                kind: CredentialKind::ApiKey,
                secret: "new-tavily-secret-value".to_string(),
                note: Some("Imported from ~/.claude/settings.json".to_string()),
            },
            ImportedCredential {
                provider_id: "brave".to_string(),
                name: "BRAVE_API_KEY".to_string(),
                kind: CredentialKind::ApiKey,
                secret: "new-brave-secret-value".to_string(),
                note: Some("Imported from ~/.claude/settings.json".to_string()),
            },
        ],
    )
    .expect("second import should merge");

    assert_eq!(second_summary.added, 1);
    assert_eq!(second_summary.updated, 1);

    let credentials = load_credentials(&metadata_store).expect("credentials should load");
    assert_eq!(credentials.len(), 2);
    let tavily = credentials
        .iter()
        .find(|credential| credential.provider_id == "tavily")
        .expect("Tavily credential should exist");
    assert_eq!(tavily.id, tavily_id);
    assert_eq!(tavily.masked_value, "new-••••alue");
    assert_eq!(
        tavily.note.as_deref(),
        Some("Imported from ~/.claude/settings.json")
    );
    assert_eq!(
        secret_vault.read(&tavily.id).expect("secret read"),
        Some("new-tavily-secret-value".to_string())
    );

    let metadata_payload = metadata_store
        .get_value("credentials")
        .expect("metadata should have credentials")
        .to_string();
    assert!(!metadata_payload.contains("new-tavily-secret-value"));
    assert!(!metadata_payload.contains("new-brave-secret-value"));
}

fn temp_root(name: &str) -> PathBuf {
    let unique = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .expect("test clock")
        .as_nanos();
    let root =
        std::env::temp_dir().join(format!("quotaradar-{name}-{}-{unique}", std::process::id()));
    fs::remove_dir_all(&root).ok();
    fs::create_dir_all(&root).expect("temp root");
    root
}
