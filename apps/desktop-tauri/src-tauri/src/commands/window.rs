use serde::{Deserialize, Serialize};
use tauri::{AppHandle, Emitter, Runtime};

use crate::platform::window::reopen_main_window;

pub const MAIN_WINDOW_NAVIGATION_EVENT: &str = "main_window_navigation_requested";

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MainWindowTarget {
    pub page: Option<String>,
    pub provider_id: Option<String>,
    pub credential_id: Option<String>,
}

#[tauri::command]
pub fn open_main_window<R: Runtime>(
    app: AppHandle<R>,
    target: Option<MainWindowTarget>,
) -> Result<(), String> {
    reopen_main_window(&app).map_err(|error| error.to_string())?;
    if let Some(target) = target {
        app.emit(MAIN_WINDOW_NAVIGATION_EVENT, target)
            .map_err(|error| error.to_string())?;
    }
    Ok(())
}
