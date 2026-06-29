use std::fs;

use serde::Deserialize;
use tauri::{AppHandle, Manager, Runtime};

use crate::{
    domain::{CredentialKind, CredentialStatus, CredentialView},
    storage::{
        credential_importer::{
            import_claude_settings_content, import_credentials_into_store, CredentialImportSummary,
        },
        metadata_store::{load_credentials, save_credentials, TauriMetadataStore},
        secret_store::{
            build_credential_metadata, copy_secret_value as copy_secret_value_from_vault,
            credential_kind_is_copyable, delete_secret, save_secret, CredentialSecretInput,
            TauriSecretVault,
        },
    },
};

#[derive(Debug, Clone, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct CredentialUpdateInput {
    pub id: String,
    pub provider_id: String,
    pub name: String,
    pub kind: CredentialKind,
    pub secret: Option<String>,
    pub active: Option<bool>,
    pub linked_authorization_id: Option<String>,
    pub note: Option<String>,
}

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
    input: CredentialUpdateInput,
) -> Result<CredentialView, String> {
    let metadata_store = TauriMetadataStore::open(&app)?;
    let secret_vault = TauriSecretVault::open(&app)?;
    let mut credentials = load_credentials(&metadata_store)?;
    let credential_index = credentials
        .iter()
        .position(|credential| credential.id == input.id)
        .ok_or_else(|| "Credential was not found".to_string())?;
    let mut updated = credentials[credential_index].clone();
    let provider_changed = updated.provider_id != input.provider_id;
    let kind_changed = updated.kind != input.kind;
    let new_secret = input
        .secret
        .as_deref()
        .map(str::trim)
        .filter(|secret| !secret.is_empty());

    if let Some(secret) = new_secret {
        let metadata = build_credential_metadata(&CredentialSecretInput {
            id: input.id.clone(),
            provider_id: input.provider_id.clone(),
            name: input.name.clone(),
            kind: input.kind.clone(),
            secret: secret.to_string(),
            linked_authorization_id: input.linked_authorization_id.clone(),
            note: input.note.clone(),
        });
        updated.masked_value = metadata.masked_value;
        updated.copyable = metadata.copyable;
        updated.remaining_badge_text = metadata.remaining_badge_text;
        save_secret(&secret_vault, &input.id, secret)?;
    } else if kind_changed {
        updated.copyable = credential_kind_is_copyable(&input.kind);
        if matches!(input.kind, CredentialKind::DashboardCookie) {
            updated.masked_value = "Web login authorization saved".to_string();
            updated.remaining_badge_text = "Authorization saved".to_string();
        }
    }

    if provider_changed || kind_changed || new_secret.is_some() {
        clear_quota_state(&mut updated);
    }

    updated.provider_id = input.provider_id;
    updated.name = input.name;
    updated.kind = input.kind;
    updated.active = input.active.unwrap_or(updated.active);
    updated.linked_authorization_id = input.linked_authorization_id;
    updated.note = input.note;
    credentials[credential_index] = updated.clone();
    save_credentials(&metadata_store, &credentials)?;

    Ok(updated)
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

fn clear_quota_state(credential: &mut CredentialView) {
    credential.status = CredentialStatus::NotChecked;
    credential.remaining = None;
    credential.limit = None;
    credential.quota_label = None;
    credential.quota_windows.clear();
    credential.reset_at = None;
    credential.plan_ends_at = None;
    credential.last_updated = None;
    credential.last_http_status = None;
    credential.diagnostic_message = None;
}
