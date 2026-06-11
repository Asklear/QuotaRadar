use crate::domain::AppState;

#[tauri::command]
pub fn get_app_state() -> AppState {
    AppState::mock()
}
