use serde::{Deserialize, Serialize};
use serde_json::Value;
use tauri::{AppHandle, Runtime};

use crate::{
    domain::{CredentialKind, CredentialView},
    platform::web_auth::{
        open_web_authorization_window, web_authorization_started_message,
        WebAuthorizationWindowRequest,
    },
    providers::registry::visible_provider_definitions,
    storage::{
        metadata_store::{load_credentials, save_credentials, MetadataStore, TauriMetadataStore},
        secret_store::{
            build_credential_metadata, save_secret, CredentialSecretInput, SecretVault,
            TauriSecretVault,
        },
    },
};

#[derive(Debug, Clone, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct WebAuthorizationSession {
    pub provider_id: String,
    pub target_credential_id: Option<String>,
    pub login_url: Option<String>,
    pub message: String,
}

#[derive(Debug, Clone, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct CapturedWebAuthorization {
    pub provider_id: String,
    pub target_credential_id: Option<String>,
    pub name: Option<String>,
    pub captured_fields: Value,
}

#[tauri::command]
pub fn start_web_authorization<R: Runtime>(
    app: AppHandle<R>,
    provider_id: String,
    target_credential_id: Option<String>,
) -> Result<WebAuthorizationSession, String> {
    let metadata_store = TauriMetadataStore::open(&app)?;
    let credentials = load_credentials(&metadata_store)?;
    let target_name = target_credential_id.as_ref().and_then(|target_id| {
        credentials
            .iter()
            .find(|credential| credential.id == *target_id)
            .map(|credential| credential.name.as_str())
    });
    let login_url = visible_provider_definitions()
        .into_iter()
        .find(|provider| provider.id == provider_id)
        .and_then(|provider| provider.dashboard_url);

    let session = start_web_authorization_session(
        &provider_id,
        target_credential_id.as_deref(),
        target_name,
        login_url.as_deref(),
    );
    let login_url = session
        .login_url
        .clone()
        .ok_or_else(|| "Provider does not have a web authorization URL".to_string())?;
    open_web_authorization_window(
        &app,
        WebAuthorizationWindowRequest {
            provider_id,
            target_credential_id,
            target_name: target_name.map(ToString::to_string),
            login_url,
        },
    )?;

    Ok(WebAuthorizationSession {
        message: web_authorization_started_message(&session),
        ..session
    })
}

#[tauri::command]
pub fn save_web_authorization<R: Runtime>(
    app: AppHandle<R>,
    input: CapturedWebAuthorization,
) -> Result<CredentialView, String> {
    let metadata_store = TauriMetadataStore::open(&app)?;
    let secret_vault = TauriSecretVault::open(&app)?;
    save_web_authorization_with_stores(&metadata_store, &secret_vault, input)
}

pub fn start_web_authorization_session(
    provider_id: &str,
    target_credential_id: Option<&str>,
    target_name: Option<&str>,
    login_url: Option<&str>,
) -> WebAuthorizationSession {
    let message = match target_name {
        Some(name) => format!("Ready to update {name}"),
        None if target_credential_id.is_some() => {
            "Ready to update selected authorization".to_string()
        }
        None => "Choose an authorization target".to_string(),
    };

    WebAuthorizationSession {
        provider_id: provider_id.to_string(),
        target_credential_id: target_credential_id.map(ToString::to_string),
        login_url: login_url.map(ToString::to_string),
        message,
    }
}

pub fn save_web_authorization_with_stores(
    metadata_store: &impl MetadataStore,
    secret_vault: &impl SecretVault,
    input: CapturedWebAuthorization,
) -> Result<CredentialView, String> {
    let credential_id = input
        .target_credential_id
        .clone()
        .unwrap_or_else(|| format!("{}-web-authorization", input.provider_id));
    let credential_name = input
        .name
        .clone()
        .unwrap_or_else(|| format!("{} Web Login", input.provider_id));
    let existing_secret = secret_vault.read(&credential_id)?;
    let captured_fields = merge_captured_fields(existing_secret.as_deref(), input.captured_fields);
    let secret = serde_json::to_string(&captured_fields).map_err(|error| error.to_string())?;
    let credential_input = CredentialSecretInput {
        id: credential_id,
        provider_id: input.provider_id,
        name: credential_name,
        kind: CredentialKind::DashboardCookie,
        secret,
        linked_authorization_id: None,
        note: None,
    };
    let metadata = build_credential_metadata(&credential_input);
    let mut credentials = load_credentials(metadata_store)?;

    credentials.retain(|credential| credential.id != metadata.id);
    credentials.push(metadata.clone());
    save_secret(secret_vault, &metadata.id, &credential_input.secret)?;
    save_credentials(metadata_store, &credentials)?;

    Ok(metadata)
}

fn merge_captured_fields(existing_secret: Option<&str>, captured_fields: Value) -> Value {
    let Some(existing_secret) = existing_secret
        .map(str::trim)
        .filter(|secret| !secret.is_empty())
    else {
        return captured_fields;
    };

    let Ok(mut existing_value) = serde_json::from_str::<Value>(existing_secret) else {
        return captured_fields;
    };
    let (Some(existing_object), Some(captured_object)) =
        (existing_value.as_object_mut(), captured_fields.as_object())
    else {
        return captured_fields;
    };

    for (key, value) in captured_object {
        existing_object.insert(key.clone(), value.clone());
        if key == "cookie" && existing_object.contains_key("cookies") {
            existing_object.insert("cookies".to_string(), value.clone());
        }
    }

    existing_value
}
