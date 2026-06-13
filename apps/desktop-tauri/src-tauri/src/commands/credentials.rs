use std::fs;

use tauri::{AppHandle, Manager, Runtime};

use crate::{
    domain::CredentialView,
    storage::{
        credential_importer::{
            import_claude_settings_content, import_credentials_into_store, CredentialImportSummary,
        },
        metadata_store::{load_credentials, save_credentials, TauriMetadataStore},
        secret_store::{
            build_credential_metadata, copy_secret_value as copy_secret_value_from_vault,
            delete_secret, save_secret, CredentialSecretInput, TauriSecretVault,
        },
    },
};

#[tauri::command]
pub fn list_credentials<R: Runtime>(app: AppHandle<R>) -> Result<Vec<CredentialView>, String> {
    let metadata_store = TauriMetadataStore::open(&app)?;
    load_credentials(&metadata_store)
}

#[tauri::command]
pub fn create_credential<R: Runtime>(
    app: AppHandle<R>,
    input: CredentialSecretInput,
) -> Result<CredentialView, String> {
    let metadata_store = TauriMetadataStore::open(&app)?;
    let secret_vault = TauriSecretVault::open(&app)?;
    let metadata = build_credential_metadata(&input);
    let mut credentials = load_credentials(&metadata_store)?;

    credentials.retain(|credential| credential.id != metadata.id);
    credentials.push(metadata.clone());
    save_secret(&secret_vault, &metadata.id, &input.secret)?;
    save_credentials(&metadata_store, &credentials)?;

    Ok(metadata)
}

#[tauri::command]
pub fn update_credential<R: Runtime>(
    app: AppHandle<R>,
    input: CredentialSecretInput,
) -> Result<CredentialView, String> {
    create_credential(app, input)
}

#[tauri::command]
pub fn delete_credential<R: Runtime>(
    app: AppHandle<R>,
    credential_id: String,
) -> Result<Vec<CredentialView>, String> {
    let metadata_store = TauriMetadataStore::open(&app)?;
    let secret_vault = TauriSecretVault::open(&app)?;
    let mut credentials = load_credentials(&metadata_store)?;

    credentials.retain(|credential| credential.id != credential_id);
    delete_secret(&secret_vault, &credential_id)?;
    save_credentials(&metadata_store, &credentials)?;

    Ok(credentials)
}

#[tauri::command]
pub fn set_credential_active<R: Runtime>(
    app: AppHandle<R>,
    credential_id: String,
    active: bool,
) -> Result<CredentialView, String> {
    let metadata_store = TauriMetadataStore::open(&app)?;
    let mut credentials = load_credentials(&metadata_store)?;
    let credential = credentials
        .iter_mut()
        .find(|credential| credential.id == credential_id)
        .ok_or_else(|| "Credential was not found".to_string())?;

    credential.active = active;
    let updated = credential.clone();
    save_credentials(&metadata_store, &credentials)?;

    Ok(updated)
}

#[tauri::command]
pub fn copy_credential_value<R: Runtime>(
    app: AppHandle<R>,
    credential_id: String,
) -> Result<String, String> {
    let metadata_store = TauriMetadataStore::open(&app)?;
    let secret_vault = TauriSecretVault::open(&app)?;
    let credentials = load_credentials(&metadata_store)?;
    let credential = credentials
        .iter()
        .find(|credential| credential.id == credential_id)
        .ok_or_else(|| "Credential was not found".to_string())?;

    copy_secret_value_from_vault(&secret_vault, &credential.id, credential.copyable)
}

#[tauri::command]
pub fn import_claude_settings<R: Runtime>(
    app: AppHandle<R>,
) -> Result<CredentialImportSummary, String> {
    let metadata_store = TauriMetadataStore::open(&app)?;
    let secret_vault = TauriSecretVault::open(&app)?;
    let settings_path = app
        .path()
        .home_dir()
        .map_err(|error| error.to_string())?
        .join(".claude")
        .join("settings.json");
    let content = fs::read_to_string(&settings_path).map_err(|error| {
        format!(
            "Could not read Claude settings file {}: {error}",
            settings_path.display()
        )
    })?;
    let imported = import_claude_settings_content(&content)?;

    import_credentials_into_store(&metadata_store, &secret_vault, imported)
}
