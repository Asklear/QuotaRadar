use crate::{domain::ProviderDefinition, providers::registry::visible_provider_definitions};

#[tauri::command]
pub fn list_provider_definitions() -> Vec<ProviderDefinition> {
    visible_provider_definitions()
}
