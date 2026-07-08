use std::{collections::HashMap, sync::Mutex};

use serde_json::Value;
use tauri::{AppHandle, Runtime};
use tauri_plugin_store::{Store, StoreExt};

use crate::domain::{default_provider_order, AppSettings, CredentialView};

const CREDENTIALS_KEY: &str = "credentials";
const SETTINGS_KEY: &str = "settings";
const SETTINGS_STORE_PATH: &str = "settings.json";

pub trait MetadataStore {
    fn get_value(&self, key: &str) -> Option<Value>;
    fn set_value(&self, key: &str, value: Value);
    fn save(&self) -> Result<(), String>;
}

#[derive(Default)]
pub struct MemoryMetadataStore {
    values: Mutex<HashMap<String, Value>>,
}

impl MetadataStore for MemoryMetadataStore {
    fn get_value(&self, key: &str) -> Option<Value> {
        self.values.lock().ok()?.get(key).cloned()
    }

    fn set_value(&self, key: &str, value: Value) {
        if let Ok(mut values) = self.values.lock() {
            values.insert(key.to_string(), value);
        }
    }

    fn save(&self) -> Result<(), String> {
        Ok(())
    }
}

pub struct TauriMetadataStore<R: Runtime> {
    store: std::sync::Arc<Store<R>>,
}

impl<R: Runtime> TauriMetadataStore<R> {
    pub fn open(app: &AppHandle<R>) -> Result<Self, String> {
        let store = app
            .store(SETTINGS_STORE_PATH)
            .map_err(|error| error.to_string())?;
        Ok(Self { store })
    }
}

impl<R: Runtime> MetadataStore for TauriMetadataStore<R> {
    fn get_value(&self, key: &str) -> Option<Value> {
        self.store.get(key)
    }

    fn set_value(&self, key: &str, value: Value) {
        self.store.set(key, value);
    }

    fn save(&self) -> Result<(), String> {
        self.store.save().map_err(|error| error.to_string())
    }
}

pub fn default_settings() -> AppSettings {
    AppSettings::default()
}

pub fn load_settings(store: &impl MetadataStore) -> Result<AppSettings, String> {
    let Some(value) = store.get_value(SETTINGS_KEY) else {
        return Ok(default_settings());
    };

    let mut settings: AppSettings =
        serde_json::from_value(value).map_err(|error| error.to_string())?;
    sanitize_settings(&mut settings);
    Ok(settings)
}

pub fn save_settings(store: &impl MetadataStore, settings: &AppSettings) -> Result<(), String> {
    let mut settings = settings.clone();
    sanitize_settings(&mut settings);
    let value = serde_json::to_value(settings).map_err(|error| error.to_string())?;
    store.set_value(SETTINGS_KEY, value);
    store.save()
}

fn sanitize_settings(settings: &mut AppSettings) {
    settings.provider_order = sanitized_provider_order(&settings.provider_order);
}

fn sanitized_provider_order(provider_order: &[String]) -> Vec<String> {
    let defaults = default_provider_order();
    let mut sanitized = Vec::new();

    for provider in provider_order {
        if defaults.contains(provider) && !sanitized.contains(provider) {
            sanitized.push(provider.clone());
        }
    }

    for provider in defaults {
        if !sanitized.contains(&provider) {
            sanitized.push(provider);
        }
    }

    sanitized
}

pub fn load_credentials(store: &impl MetadataStore) -> Result<Vec<CredentialView>, String> {
    let Some(value) = store.get_value(CREDENTIALS_KEY) else {
        return Ok(Vec::new());
    };

    serde_json::from_value(value).map_err(|error| error.to_string())
}

pub fn save_credentials(
    store: &impl MetadataStore,
    credentials: &[CredentialView],
) -> Result<(), String> {
    let value = serde_json::to_value(credentials).map_err(|error| error.to_string())?;
    store.set_value(CREDENTIALS_KEY, value);
    store.save()
}

pub fn move_provider_in_settings(settings: &mut AppSettings, provider_id: &str, to_index: usize) {
    let Some(current_index) = settings
        .provider_order
        .iter()
        .position(|provider| provider == provider_id)
    else {
        return;
    };

    let provider = settings.provider_order.remove(current_index);
    let target_index = to_index.min(settings.provider_order.len());
    settings.provider_order.insert(target_index, provider);
}

pub fn reset_provider_order(settings: &mut AppSettings) {
    settings.provider_order = default_provider_order();
}
