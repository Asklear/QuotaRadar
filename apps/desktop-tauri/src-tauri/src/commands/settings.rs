use tauri::{AppHandle, Runtime};

use crate::{
    domain::AppSettings,
    storage::metadata_store::{
        load_settings, move_provider_in_settings,
        reset_provider_order as reset_provider_order_in_settings, save_settings,
        TauriMetadataStore,
    },
};

#[tauri::command]
pub fn get_settings<R: Runtime>(app: AppHandle<R>) -> Result<AppSettings, String> {
    let store = TauriMetadataStore::open(&app)?;
    load_settings(&store)
}

#[tauri::command]
pub fn update_settings<R: Runtime>(
    app: AppHandle<R>,
    settings: AppSettings,
) -> Result<AppSettings, String> {
    let store = TauriMetadataStore::open(&app)?;
    save_settings(&store, &settings)?;
    Ok(settings)
}

#[tauri::command]
pub fn reset_provider_order<R: Runtime>(app: AppHandle<R>) -> Result<AppSettings, String> {
    let store = TauriMetadataStore::open(&app)?;
    let mut settings = load_settings(&store)?;
    reset_provider_order_in_settings(&mut settings);
    save_settings(&store, &settings)?;
    Ok(settings)
}

#[tauri::command]
pub fn move_provider<R: Runtime>(
    app: AppHandle<R>,
    provider_id: String,
    to_index: usize,
) -> Result<AppSettings, String> {
    let store = TauriMetadataStore::open(&app)?;
    let mut settings = load_settings(&store)?;
    move_provider_in_settings(&mut settings, &provider_id, to_index);
    save_settings(&store, &settings)?;
    Ok(settings)
}
