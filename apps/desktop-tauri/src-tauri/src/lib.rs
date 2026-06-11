pub mod commands;
pub mod domain;
pub mod platform;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_positioner::init())
        .setup(|app| {
            platform::tray::setup_tray_shell(app.handle())?;
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![commands::app_state::get_app_state])
        .run(tauri::generate_context!())
        .expect("error while running Quota Radar Tauri application");
}
