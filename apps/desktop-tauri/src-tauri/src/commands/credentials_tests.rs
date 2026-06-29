use super::credentials::{
    copy_credential_value, create_credential, list_credentials, update_credential,
    CredentialUpdateInput,
};
use crate::storage::secret_store::CredentialSecretInput;

fn test_app() -> tauri::App<tauri::test::MockRuntime> {
    tauri::test::mock_builder()
        .plugin(tauri_plugin_store::Builder::new().build())
        .build(tauri::test::mock_context(tauri::test::noop_assets()))
        .expect("mock Tauri app should build")
}

#[test]
fn create_credential_persists_metadata_and_secret_through_tauri_store() {
    let app = test_app();
    let app_handle = app.handle().clone();

    let saved = create_credential(
        app_handle.clone(),
        CredentialSecretInput::new_api_key(
            "tavily-windows-store-check",
            "tavily",
            "Tavily Windows Store Check",
            "tvly-windows-secret",
        ),
    )
    .expect("credential should save through Tauri store");

    assert_eq!(saved.id, "tavily-windows-store-check");
    assert_eq!(saved.masked_value, "tvly••••cret");

    let credentials = list_credentials(app_handle.clone()).expect("credentials should load");
    assert!(credentials
        .iter()
        .any(|credential| credential.id == "tavily-windows-store-check"));

    let secret = copy_credential_value(app_handle, "tavily-windows-store-check".to_string())
        .expect("credential secret should be readable");
    assert_eq!(secret, "tvly-windows-secret");
}

#[test]
fn update_credential_preserves_existing_secret_when_secret_is_omitted() {
    let app = test_app();
    let app_handle = app.handle().clone();

    create_credential(
        app_handle.clone(),
        CredentialSecretInput::new_api_key(
            "tavily-edit-check",
            "tavily",
            "Tavily Edit Check",
            "tvly-original-secret",
        ),
    )
    .expect("credential should save through Tauri store");

    let updated = update_credential(
        app_handle.clone(),
        CredentialUpdateInput {
            id: "tavily-edit-check".to_string(),
            provider_id: "tavily".to_string(),
            name: "Tavily Edited Check".to_string(),
            kind: crate::domain::CredentialKind::ApiKey,
            secret: None,
            active: Some(false),
            linked_authorization_id: None,
            note: Some("Edited note".to_string()),
        },
    )
    .expect("credential metadata should update");

    assert_eq!(updated.name, "Tavily Edited Check");
    assert!(!updated.active);
    assert_eq!(updated.note.as_deref(), Some("Edited note"));

    let secret = copy_credential_value(app_handle, "tavily-edit-check".to_string())
        .expect("credential secret should still be readable");
    assert_eq!(secret, "tvly-original-secret");
}
