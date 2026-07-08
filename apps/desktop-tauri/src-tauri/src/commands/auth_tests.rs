use serde_json::json;
use std::cell::RefCell;

use crate::{
    domain::CredentialKind,
    storage::{
        metadata_store::{load_credentials, MemoryMetadataStore},
        secret_store::{copy_secret_value, MemorySecretVault, SecretVault},
    },
};

use super::auth::{
    save_web_authorization_with_stores, start_web_authorization_from_credentials,
    start_web_authorization_session, CapturedWebAuthorization,
};

#[test]
fn start_web_authorization_session_identifies_provider_and_target() {
    let session = start_web_authorization_session(
        "claude",
        Some("claude-web-pro"),
        Some("Claude Pro Login"),
        Some("https://claude.ai/settings/usage"),
    );

    assert_eq!(session.provider_id, "claude");
    assert_eq!(
        session.target_credential_id.as_deref(),
        Some("claude-web-pro")
    );
    assert_eq!(
        session.login_url.as_deref(),
        Some("https://claude.ai/settings/usage")
    );
    assert!(session.message.contains("Claude Pro Login"));
}

#[test]
fn start_web_authorization_returns_window_scheduling_errors_to_caller() {
    let credentials = vec![];
    let result = start_web_authorization_from_credentials(
        "opencode_go".to_string(),
        None,
        None,
        "en",
        &credentials,
        |_request| Err("window builder failed".to_string()),
    );

    assert_eq!(result, Err("window builder failed".to_string()));
}

#[test]
fn start_web_authorization_passes_locale_to_window_request() {
    let scheduled_locale = RefCell::new(None);
    let credentials = vec![];

    start_web_authorization_from_credentials(
        "claude".to_string(),
        None,
        Some("Claude Web Login".to_string()),
        "ko",
        &credentials,
        |request| {
            scheduled_locale.replace(Some(request.locale));
            Ok(())
        },
    )
    .expect("web authorization should start");

    assert_eq!(scheduled_locale.into_inner().as_deref(), Some("ko"));
}

#[test]
fn save_web_authorization_persists_dashboard_cookie_metadata_and_secret() {
    let metadata_store = MemoryMetadataStore::default();
    let secret_vault = MemorySecretVault::default();
    let input = CapturedWebAuthorization {
        provider_id: "claude".to_string(),
        target_credential_id: Some("claude-web-pro".to_string()),
        name: Some("Claude Pro Login".to_string()),
        captured_fields: json!({
            "cookie": "sessionKey=mock-session",
            "capturedAt": "2026-06-11T12:00:00+08:00"
        }),
    };

    let saved = save_web_authorization_with_stores(&metadata_store, &secret_vault, input)
        .expect("authorization should save");

    assert_eq!(saved.id, "claude-web-pro");
    assert_eq!(saved.provider_id, "claude");
    assert_eq!(saved.kind, CredentialKind::DashboardCookie);
    assert_eq!(saved.copyable, false);
    assert_eq!(saved.masked_value, "Web login authorization saved");

    let credentials = load_credentials(&metadata_store).expect("metadata should load");
    assert_eq!(credentials.len(), 1);
    assert_eq!(credentials[0].id, "claude-web-pro");
    assert!(secret_vault
        .read("claude-web-pro")
        .expect("secret should load")
        .expect("secret should exist")
        .contains("sessionKey=mock-session"));
    assert!(copy_secret_value(&secret_vault, "claude-web-pro", saved.copyable).is_err());
}

#[test]
fn save_web_authorization_preserves_existing_json_fields_when_refreshing_cookie() {
    let metadata_store = MemoryMetadataStore::default();
    let secret_vault = MemorySecretVault::default();
    save_web_authorization_with_stores(
        &metadata_store,
        &secret_vault,
        CapturedWebAuthorization {
            provider_id: "opencode_go".to_string(),
            target_credential_id: Some("opencode-web-pro".to_string()),
            name: Some("OpenCode Go Login".to_string()),
            captured_fields: json!({
                "cookie": "auth=old-session",
                "workspaceID": "wrk_1",
                "serverID": "srv_1",
                "serverInstance": "server-fn:11"
            }),
        },
    )
    .expect("initial authorization should save");

    save_web_authorization_with_stores(
        &metadata_store,
        &secret_vault,
        CapturedWebAuthorization {
            provider_id: "opencode_go".to_string(),
            target_credential_id: Some("opencode-web-pro".to_string()),
            name: Some("OpenCode Go Login".to_string()),
            captured_fields: json!({
                "cookie": "auth=new-session; oc_locale=zh"
            }),
        },
    )
    .expect("refreshed authorization should save");

    let saved_secret = secret_vault
        .read("opencode-web-pro")
        .expect("secret should load")
        .expect("secret should exist");
    let saved_value: serde_json::Value =
        serde_json::from_str(&saved_secret).expect("secret should stay JSON");
    assert_eq!(saved_value["cookie"], "auth=new-session; oc_locale=zh");
    assert_eq!(saved_value["workspaceID"], "wrk_1");
    assert_eq!(saved_value["serverID"], "srv_1");
    assert_eq!(saved_value["serverInstance"], "server-fn:11");
}
