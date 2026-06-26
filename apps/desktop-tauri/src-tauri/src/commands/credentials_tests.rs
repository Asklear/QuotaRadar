use super::credentials::{copy_credential_value, create_credential, list_credentials};
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
