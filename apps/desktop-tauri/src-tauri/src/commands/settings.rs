use tauri::{AppHandle, Runtime};
use tauri_plugin_autostart::ManagerExt;

use crate::{
    domain::AppSettings,
    storage::metadata_store::{
        load_settings, move_provider_in_settings,
        reset_provider_order as reset_provider_order_in_settings, save_settings,
        TauriMetadataStore,
    },
};

pub trait AutostartController {
    fn enable(&self) -> Result<(), String>;
    fn disable(&self) -> Result<(), String>;
}

struct TauriAutostartController<'a, R: Runtime> {
    app: &'a AppHandle<R>,
}

impl<'a, R: Runtime> TauriAutostartController<'a, R> {
    fn new(app: &'a AppHandle<R>) -> Self {
        Self { app }
    }
}

impl<R: Runtime> AutostartController for TauriAutostartController<'_, R> {
    fn enable(&self) -> Result<(), String> {
        self.app
            .autolaunch()
            .enable()
            .map_err(|error| error.to_string())
    }

    fn disable(&self) -> Result<(), String> {
        self.app
            .autolaunch()
            .disable()
            .map_err(|error| error.to_string())
    }
}

pub fn sync_launch_at_login(
    settings: &AppSettings,
    autostart: &impl AutostartController,
) -> Result<(), String> {
    if settings.launch_at_login {
        autostart.enable()
    } else {
        autostart.disable()
    }
}

pub fn sync_launch_at_login_for_app<R: Runtime>(app: &AppHandle<R>) -> Result<(), String> {
    let store = TauriMetadataStore::open(app)?;
    let settings = load_settings(&store)?;
    sync_launch_at_login(&settings, &TauriAutostartController::new(app))
}

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
    sync_launch_at_login(&settings, &TauriAutostartController::new(&app))?;
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

#[cfg(test)]
mod tests {
    use std::cell::RefCell;

    use crate::storage::metadata_store::default_settings;

    use super::{sync_launch_at_login, AutostartController};

    #[derive(Default)]
    struct RecordingAutostart {
        calls: RefCell<Vec<&'static str>>,
    }

    impl AutostartController for RecordingAutostart {
        fn enable(&self) -> Result<(), String> {
            self.calls.borrow_mut().push("enable");
            Ok(())
        }

        fn disable(&self) -> Result<(), String> {
            self.calls.borrow_mut().push("disable");
            Ok(())
        }
    }

    #[test]
    fn sync_launch_at_login_enables_autostart_when_setting_is_enabled() {
        let mut settings = default_settings();
        settings.launch_at_login = true;
        let autostart = RecordingAutostart::default();

        sync_launch_at_login(&settings, &autostart).expect("autostart should sync");

        assert_eq!(&*autostart.calls.borrow(), &["enable"]);
    }

    #[test]
    fn sync_launch_at_login_disables_autostart_when_setting_is_disabled() {
        let mut settings = default_settings();
        settings.launch_at_login = false;
        let autostart = RecordingAutostart::default();

        sync_launch_at_login(&settings, &autostart).expect("autostart should sync");

        assert_eq!(&*autostart.calls.borrow(), &["disable"]);
    }
}
