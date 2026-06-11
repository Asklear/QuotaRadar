pub mod commands;
pub mod domain;
pub mod platform;
pub mod providers;
pub mod scheduler;
pub mod storage;

use tauri::Manager;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_http::init())
        .plugin(tauri_plugin_autostart::Builder::new().build())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .plugin(tauri_plugin_store::Builder::new().build())
        .plugin(tauri_plugin_positioner::init())
        .setup(|app| {
            let salt_path = app.path().app_local_data_dir()?.join("stronghold-salt.bin");
            app.handle()
                .plugin(tauri_plugin_stronghold::Builder::with_argon2(&salt_path).build())?;
            platform::tray::setup_tray_shell(app.handle())?;
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::app_state::get_app_state,
            commands::credentials::copy_credential_value,
            commands::credentials::create_credential,
            commands::credentials::delete_credential,
            commands::credentials::list_credentials,
            commands::providers::list_provider_definitions,
            commands::credentials::set_credential_active,
            commands::credentials::update_credential,
            commands::settings::get_settings,
            commands::settings::update_settings,
            commands::settings::reset_provider_order,
            commands::settings::move_provider,
            commands::updates::check_for_updates,
            commands::updates::download_and_install_update,
            commands::updates::get_update_state
        ])
        .run(tauri::generate_context!())
        .expect("error while running Quota Radar Tauri application");
}
