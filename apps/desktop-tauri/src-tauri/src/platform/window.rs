use std::sync::{Arc, Mutex};

use serde::{Deserialize, Serialize};
use tauri::{AppHandle, Manager, Monitor, PhysicalPosition, Runtime, WebviewWindow, WindowEvent};

use crate::storage::metadata_store::{MetadataStore, TauriMetadataStore};

pub const MAIN_WINDOW_LABEL: &str = "main";
pub const MAIN_WINDOW_MARGIN: f64 = 24.0;
const MAIN_WINDOW_FRAME_KEY: &str = "mainWindowFrame";
const MIN_VISIBLE_WIDTH: f64 = 160.0;
const MIN_VISIBLE_HEIGHT: f64 = 120.0;
const POSITION_EPSILON: f64 = 3.0;

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MainWindowFrame {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct DisplayArea {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

pub fn choose_main_window_frame(
    saved: Option<MainWindowFrame>,
    interaction_display: DisplayArea,
    displays: &[DisplayArea],
    default_width: f64,
    default_height: f64,
) -> MainWindowFrame {
    if let Some(saved_frame) = saved {
        if frame_is_visible_on_any_display(saved_frame, displays) {
            return saved_frame;
        }
    }

    centered_frame(interaction_display, default_width, default_height)
}

pub fn setup_main_window<R: Runtime>(app: &AppHandle<R>) -> tauri::Result<()> {
    let Some(window) = app.get_webview_window(MAIN_WINDOW_LABEL) else {
        return Ok(());
    };

    let programmatic_target = Arc::new(Mutex::new(None));
    apply_main_window_frame(app, &window, &programmatic_target)?;
    register_main_window_events(app, &window, programmatic_target);
    Ok(())
}

pub fn reopen_main_window<R: Runtime>(app: &AppHandle<R>) -> tauri::Result<()> {
    let Some(window) = app.get_webview_window(MAIN_WINDOW_LABEL) else {
        return Ok(());
    };

    let programmatic_target = Arc::new(Mutex::new(None));
    apply_main_window_frame(app, &window, &programmatic_target)?;
    window.show()?;
    window.unminimize()?;
    window.set_focus()
}

fn apply_main_window_frame<R: Runtime>(
    app: &AppHandle<R>,
    window: &WebviewWindow<R>,
    programmatic_target: &Arc<Mutex<Option<MainWindowFrame>>>,
) -> tauri::Result<()> {
    let window_size = window.outer_size()?;
    let displays = display_areas(app.available_monitors()?);
    let interaction_display = interaction_display(app, window, &displays)?;
    let saved_frame = load_main_window_frame_for_app(app);
    let frame = choose_main_window_frame(
        saved_frame,
        interaction_display,
        &displays,
        window_size.width as f64,
        window_size.height as f64,
    );

    if let Ok(mut target) = programmatic_target.lock() {
        *target = Some(frame);
    }
    window.set_position(PhysicalPosition::new(
        frame.x.round() as i32,
        frame.y.round() as i32,
    ))
}

fn register_main_window_events<R: Runtime>(
    app: &AppHandle<R>,
    window: &WebviewWindow<R>,
    programmatic_target: Arc<Mutex<Option<MainWindowFrame>>>,
) {
    let app_for_events = app.clone();
    let window_for_events = window.clone();
    window.on_window_event(move |event| match event {
        WindowEvent::CloseRequested { api, .. } => {
            api.prevent_close();
            let _ = window_for_events.hide();
        }
        WindowEvent::Moved(position) => {
            if should_ignore_programmatic_move(&programmatic_target, position.x, position.y) {
                return;
            }
            let _ = save_current_main_window_frame(&app_for_events, &window_for_events);
        }
        WindowEvent::Resized(_) => {
            let _ = save_current_main_window_frame(&app_for_events, &window_for_events);
        }
        _ => {}
    });
}

fn should_ignore_programmatic_move(
    programmatic_target: &Arc<Mutex<Option<MainWindowFrame>>>,
    x: i32,
    y: i32,
) -> bool {
    let Ok(mut target) = programmatic_target.lock() else {
        return false;
    };
    let Some(frame) = *target else {
        return false;
    };

    if (frame.x - x as f64).abs() <= POSITION_EPSILON
        && (frame.y - y as f64).abs() <= POSITION_EPSILON
    {
        *target = None;
        true
    } else {
        false
    }
}

fn save_current_main_window_frame<R: Runtime>(
    app: &AppHandle<R>,
    window: &WebviewWindow<R>,
) -> Result<(), String> {
    if window.is_minimized().unwrap_or(false) || window.is_fullscreen().unwrap_or(false) {
        return Ok(());
    }

    let position = window.outer_position().map_err(|error| error.to_string())?;
    let size = window.outer_size().map_err(|error| error.to_string())?;
    let frame = MainWindowFrame {
        x: position.x as f64,
        y: position.y as f64,
        width: size.width as f64,
        height: size.height as f64,
    };
    let store = TauriMetadataStore::open(app)?;
    save_main_window_frame(&store, frame)
}

fn load_main_window_frame_for_app<R: Runtime>(app: &AppHandle<R>) -> Option<MainWindowFrame> {
    let store = TauriMetadataStore::open(app).ok()?;
    load_main_window_frame(&store)
}

fn load_main_window_frame(store: &impl MetadataStore) -> Option<MainWindowFrame> {
    serde_json::from_value(store.get_value(MAIN_WINDOW_FRAME_KEY)?).ok()
}

fn save_main_window_frame(
    store: &impl MetadataStore,
    frame: MainWindowFrame,
) -> Result<(), String> {
    let value = serde_json::to_value(frame).map_err(|error| error.to_string())?;
    store.set_value(MAIN_WINDOW_FRAME_KEY, value);
    store.save()
}

fn interaction_display<R: Runtime>(
    app: &AppHandle<R>,
    window: &WebviewWindow<R>,
    displays: &[DisplayArea],
) -> tauri::Result<DisplayArea> {
    if let Ok(cursor) = app.cursor_position() {
        if let Some(monitor) = app.monitor_from_point(cursor.x, cursor.y)? {
            return Ok(display_area(&monitor));
        }
    }

    if let Some(monitor) = window.current_monitor()? {
        return Ok(display_area(&monitor));
    }

    if let Some(monitor) = app.primary_monitor()? {
        return Ok(display_area(&monitor));
    }

    Ok(displays.first().copied().unwrap_or(DisplayArea {
        x: 0.0,
        y: 0.0,
        width: 1120.0,
        height: 640.0,
    }))
}

fn display_areas(monitors: Vec<Monitor>) -> Vec<DisplayArea> {
    monitors.iter().map(display_area).collect()
}

fn display_area(monitor: &Monitor) -> DisplayArea {
    let work_area = monitor.work_area();
    DisplayArea {
        x: work_area.position.x as f64,
        y: work_area.position.y as f64,
        width: work_area.size.width as f64,
        height: work_area.size.height as f64,
    }
}

fn centered_frame(display: DisplayArea, width: f64, height: f64) -> MainWindowFrame {
    let preferred_x = display.x + (display.width - width) / 2.0;
    let preferred_y = display.y + (display.height - height) / 2.0;

    MainWindowFrame {
        x: clamp_axis(display.x, display.width, width, preferred_x),
        y: clamp_axis(display.y, display.height, height, preferred_y),
        width,
        height,
    }
}

fn clamp_axis(display_origin: f64, display_size: f64, window_size: f64, preferred: f64) -> f64 {
    if window_size + MAIN_WINDOW_MARGIN * 2.0 > display_size {
        display_origin
    } else {
        let min = display_origin + MAIN_WINDOW_MARGIN;
        let max = display_origin + display_size - window_size - MAIN_WINDOW_MARGIN;
        preferred.clamp(min, max)
    }
}

fn frame_is_visible_on_any_display(frame: MainWindowFrame, displays: &[DisplayArea]) -> bool {
    displays
        .iter()
        .any(|display| frame_is_visible(frame, *display))
}

fn frame_is_visible(frame: MainWindowFrame, display: DisplayArea) -> bool {
    let left = frame.x.max(display.x);
    let top = frame.y.max(display.y);
    let right = (frame.x + frame.width).min(display.x + display.width);
    let bottom = (frame.y + frame.height).min(display.y + display.height);
    let visible_width = (right - left).max(0.0);
    let visible_height = (bottom - top).max(0.0);

    visible_width >= MIN_VISIBLE_WIDTH.min(frame.width)
        && visible_height >= MIN_VISIBLE_HEIGHT.min(frame.height)
}
