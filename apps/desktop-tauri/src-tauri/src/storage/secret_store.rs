use std::{collections::HashMap, sync::Mutex};

use serde::{Deserialize, Serialize};
use serde_json::Value;
use tauri::{AppHandle, Runtime};
use tauri_plugin_store::{Store, StoreExt};

use crate::domain::{CredentialKind, CredentialStatus, CredentialView};

const SECRET_STORE_PATH: &str = "credential-secrets.json";

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct CredentialSecretInput {
    pub id: String,
    pub provider_id: String,
    pub name: String,
    pub kind: CredentialKind,
    pub secret: String,
    pub linked_authorization_id: Option<String>,
    pub note: Option<String>,
}

impl CredentialSecretInput {
    pub fn new_api_key(id: &str, provider_id: &str, name: &str, secret: &str) -> Self {
        Self {
            id: id.to_string(),
            provider_id: provider_id.to_string(),
            name: name.to_string(),
            kind: CredentialKind::ApiKey,
            secret: secret.to_string(),
            linked_authorization_id: None,
            note: None,
        }
    }
}

pub trait SecretVault {
    fn save(&self, credential_id: &str, secret: &str) -> Result<(), String>;
    fn read(&self, credential_id: &str) -> Result<Option<String>, String>;
    fn delete(&self, credential_id: &str) -> Result<(), String>;
}

#[derive(Default)]
pub struct MemorySecretVault {
    values: Mutex<HashMap<String, String>>,
}

impl SecretVault for MemorySecretVault {
    fn save(&self, credential_id: &str, secret: &str) -> Result<(), String> {
        self.values
            .lock()
            .map_err(|error| error.to_string())?
            .insert(credential_id.to_string(), secret.to_string());
        Ok(())
    }

    fn read(&self, credential_id: &str) -> Result<Option<String>, String> {
        Ok(self
            .values
            .lock()
            .map_err(|error| error.to_string())?
            .get(credential_id)
            .cloned())
    }

    fn delete(&self, credential_id: &str) -> Result<(), String> {
        self.values
            .lock()
            .map_err(|error| error.to_string())?
            .remove(credential_id);
        Ok(())
    }
}

pub struct TauriSecretVault<R: Runtime> {
    store: std::sync::Arc<Store<R>>,
}

impl<R: Runtime> TauriSecretVault<R> {
    pub fn open(app: &AppHandle<R>) -> Result<Self, String> {
        let store = app
            .store(SECRET_STORE_PATH)
            .map_err(|error| error.to_string())?;
        Ok(Self { store })
    }
}

impl<R: Runtime> SecretVault for TauriSecretVault<R> {
    fn save(&self, credential_id: &str, secret: &str) -> Result<(), String> {
        self.store
            .set(credential_id, Value::String(secret.to_string()));
        self.store.save().map_err(|error| error.to_string())
    }

    fn read(&self, credential_id: &str) -> Result<Option<String>, String> {
        Ok(self
            .store
            .get(credential_id)
            .and_then(|value| value.as_str().map(ToString::to_string)))
    }

    fn delete(&self, credential_id: &str) -> Result<(), String> {
        self.store.delete(credential_id);
        self.store.save().map_err(|error| error.to_string())
    }
}

pub fn save_secret(
    vault: &impl SecretVault,
    credential_id: &str,
    secret: &str,
) -> Result<(), String> {
    vault.save(credential_id, secret)
}

pub fn delete_secret(vault: &impl SecretVault, credential_id: &str) -> Result<(), String> {
    vault.delete(credential_id)
}

pub fn copy_secret_value(
    vault: &impl SecretVault,
    credential_id: &str,
    copyable: bool,
) -> Result<String, String> {
    if !copyable {
        return Err("Credential value is not copyable".to_string());
    }

    vault
        .read(credential_id)?
        .ok_or_else(|| "Credential value was not found".to_string())
}

pub fn build_credential_metadata(input: &CredentialSecretInput) -> CredentialView {
    let copyable = credential_kind_is_copyable(&input.kind);
    let masked_value = match input.kind {
        CredentialKind::DashboardCookie => "Web login authorization saved".to_string(),
        _ => mask_secret(&input.secret),
    };
    let remaining_badge_text = match input.kind {
        CredentialKind::DashboardCookie => "Authorization saved",
        CredentialKind::StoredApiKeyOnly => "API key saved",
        CredentialKind::AdminCredential => "Credential saved",
        CredentialKind::ApiKey => "Saved",
    }
    .to_string();

    CredentialView {
        id: input.id.clone(),
        provider_id: input.provider_id.clone(),
        name: input.name.clone(),
        kind: input.kind.clone(),
        masked_value,
        copyable,
        active: true,
        status: CredentialStatus::NotChecked,
        remaining: None,
        limit: None,
        remaining_badge_text,
        quota_label: None,
        quota_windows: Vec::new(),
        reset_at: None,
        plan_ends_at: None,
        codex_reset_credits_remaining: None,
        codex_reset_credits_earliest_expires_at: None,
        last_updated: None,
        last_http_status: None,
        diagnostic_message: None,
        note: input.note.clone(),
        linked_authorization_id: input.linked_authorization_id.clone(),
    }
}

pub fn credential_kind_is_copyable(kind: &CredentialKind) -> bool {
    !matches!(kind, CredentialKind::DashboardCookie)
}

fn mask_secret(secret: &str) -> String {
    let chars = secret.chars().collect::<Vec<_>>();
    if chars.len() <= 8 {
        return "••••".to_string();
    }

    let prefix = chars.iter().take(4).collect::<String>();
    let suffix = chars
        .iter()
        .skip(chars.len().saturating_sub(4))
        .collect::<String>();
    format!("{prefix}••••{suffix}")
}
