pub mod commands;
pub mod domain;
pub mod platform;
pub mod providers;
pub mod scheduler;
pub mod storage;

use tauri::{AppHandle, Manager, RunEvent, Runtime};

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
            run_swift_configuration_migration(app.handle());
            platform::tray::setup_tray_shell(app.handle())?;
            platform::window::setup_main_window(app.handle())?;
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::app_state::get_app_state,
            commands::credentials::copy_credential_value,
            commands::credentials::create_credential,
            commands::credentials::delete_credential,
            commands::credentials::list_credentials,
            commands::auth::save_web_authorization,
            commands::auth::start_web_authorization,
            commands::providers::list_provider_definitions,
            commands::providers::refresh_provider,
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
        .build(tauri::generate_context!())
        .expect("error while building Quota Radar Tauri application")
        .run(|app_handle, event| {
            if matches!(event, RunEvent::Reopen { .. }) {
                let _ = platform::window::reopen_main_window(app_handle);
            }
        });
}

#[cfg(target_os = "macos")]
fn run_swift_configuration_migration<R: Runtime>(app: &AppHandle<R>) {
    use storage::{
        metadata_store::TauriMetadataStore,
        migration_io::{migrate_swift_configuration_from_paths, SwiftMigrationFilePaths},
        secret_store::TauriSecretVault,
    };

    let Ok(home_dir) = app.path().home_dir() else {
        eprintln!("Quota Radar Swift configuration migration skipped: home directory unavailable");
        return;
    };
    let Ok(metadata_store) = TauriMetadataStore::open(app) else {
        eprintln!("Quota Radar Swift configuration migration skipped: metadata store unavailable");
        return;
    };
    let Ok(secret_vault) = TauriSecretVault::open(app) else {
        eprintln!("Quota Radar Swift configuration migration skipped: secret store unavailable");
        return;
    };
    let paths = SwiftMigrationFilePaths::for_home(home_dir);
    if let Err(error) =
        migrate_swift_configuration_from_paths(&metadata_store, &secret_vault, &paths)
    {
        eprintln!("Quota Radar Swift configuration migration skipped: {error}");
    }
}

#[cfg(not(target_os = "macos"))]
fn run_swift_configuration_migration<R: Runtime>(_app: &AppHandle<R>) {}
