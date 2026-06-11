use super::secret_store::{
    build_credential_metadata, copy_secret_value, save_secret, CredentialSecretInput,
    MemorySecretVault,
};
use crate::domain::CredentialKind;

#[test]
fn credential_metadata_never_contains_raw_secret() {
    let input = CredentialSecretInput::new_api_key(
        "tavily-test",
        "tavily",
        "Tavily Test",
        "tvly-real-secret-value",
    );

    let metadata = build_credential_metadata(&input);
    let serialized = serde_json::to_string(&metadata).expect("metadata should serialize");

    assert!(!serialized.contains("tvly-real-secret-value"));
    assert_eq!(metadata.masked_value, "tvly••••alue");
}

#[test]
fn api_key_secret_can_be_saved_and_loaded_by_id() {
    let vault = MemorySecretVault::default();

    save_secret(&vault, "tavily-test", "tvly-real-secret-value").expect("secret should save");
    let secret = copy_secret_value(&vault, "tavily-test", true).expect("secret should copy");

    assert_eq!(secret, "tvly-real-secret-value");
}

#[test]
fn dashboard_authorization_is_not_copyable() {
    let vault = MemorySecretVault::default();
    let input = CredentialSecretInput {
        id: "claude-web".to_string(),
        provider_id: "claude".to_string(),
        name: "Claude Login".to_string(),
        kind: CredentialKind::DashboardCookie,
        secret: "session-cookie".to_string(),
        linked_authorization_id: None,
        note: None,
    };

    let metadata = build_credential_metadata(&input);
    save_secret(&vault, &input.id, &input.secret).expect("secret should save");
    let secret = copy_secret_value(&vault, &input.id, metadata.copyable);

    assert!(!metadata.copyable);
    assert!(secret.is_err());
}

#[test]
fn companion_api_key_links_to_authorization_id() {
    let input = CredentialSecretInput {
        id: "claude-api-key".to_string(),
        provider_id: "claude".to_string(),
        name: "Claude API Key".to_string(),
        kind: CredentialKind::StoredApiKeyOnly,
        secret: "fake-anthropic-secret".to_string(),
        linked_authorization_id: Some("claude-web".to_string()),
        note: None,
    };

    let metadata = build_credential_metadata(&input);

    assert!(metadata.copyable);
    assert_eq!(metadata.linked_authorization_id.as_deref(), Some("claude-web"));
}
