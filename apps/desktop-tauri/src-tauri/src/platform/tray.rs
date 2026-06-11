use tauri::image::Image;
#[cfg(target_os = "linux")]
use tauri::menu::Menu;
use tauri::tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent};
use tauri::{
    AppHandle, Manager, PhysicalPosition, Runtime, WebviewUrl, WebviewWindow, WebviewWindowBuilder,
    WindowEvent,
};
use tauri_plugin_positioner::{Position, WindowExt};

pub const TRAY_LABEL: &str = "tray";
pub const TRAY_ROUTE: &str = "/?view=tray";
pub const TRAY_WIDTH: f64 = 560.0;
pub const TRAY_HEIGHT: f64 = 500.0;
pub const TRAY_MARGIN: f64 = 12.0;
const TRAY_ICON_ID: &str = "quota-radar-tray";

#[derive(Debug, PartialEq)]
pub struct TrayWindowSpec {
    pub label: &'static str,
    pub route: &'static str,
    pub width: f64,
    pub height: f64,
    pub visible: bool,
    pub decorations: bool,
    pub resizable: bool,
    pub skip_taskbar: bool,
}

#[derive(Debug, PartialEq)]
pub enum TrayToggleState {
    Show,
    Hide,
}

impl TrayToggleState {
    pub fn from_visible(is_visible: bool) -> Self {
        if is_visible {
            Self::Hide
        } else {
            Self::Show
        }
    }
}

#[derive(Debug, Clone, Copy)]
pub struct WorkArea {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

#[derive(Debug, PartialEq)]
pub struct WindowPosition {
    pub x: f64,
    pub y: f64,
}

pub fn tray_window_spec() -> TrayWindowSpec {
    TrayWindowSpec {
        label: TRAY_LABEL,
        route: TRAY_ROUTE,
        width: TRAY_WIDTH,
        height: TRAY_HEIGHT,
        visible: false,
        decorations: false,
        resizable: false,
        skip_taskbar: true,
    }
}

pub fn fallback_tray_position(
    work_area: WorkArea,
    window_width: f64,
    window_height: f64,
) -> WindowPosition {
    let x = if window_width + TRAY_MARGIN > work_area.width {
        work_area.x
    } else {
        work_area.x + work_area.width - window_width - TRAY_MARGIN
    };

    let y = if window_height + TRAY_MARGIN > work_area.height {
        work_area.y
    } else {
        work_area.y + TRAY_MARGIN
    };

    WindowPosition { x, y }
}

pub fn setup_tray_shell<R: Runtime>(app: &AppHandle<R>) -> tauri::Result<()> {
    ensure_tray_window(app)?;
    ensure_tray_icon(app)?;
    Ok(())
}

fn ensure_tray_window<R: Runtime>(app: &AppHandle<R>) -> tauri::Result<()> {
    if app.get_webview_window(TRAY_LABEL).is_some() {
        return Ok(());
    }

    let spec = tray_window_spec();
    let tray_window =
        WebviewWindowBuilder::new(app, spec.label, WebviewUrl::App(spec.route.into()))
            .title("Quota Radar")
            .inner_size(spec.width, spec.height)
            .min_inner_size(spec.width, spec.height)
            .max_inner_size(spec.width, spec.height)
            .decorations(spec.decorations)
            .resizable(spec.resizable)
            .visible(spec.visible)
            .focused(false)
            .skip_taskbar(spec.skip_taskbar)
            .always_on_top(true)
            .shadow(true)
            .build()?;

    let window_for_blur = tray_window.clone();
    tray_window.on_window_event(move |event| {
        if matches!(event, WindowEvent::Focused(false)) {
            let _ = window_for_blur.hide();
        }
    });

    Ok(())
}

fn ensure_tray_icon<R: Runtime>(app: &AppHandle<R>) -> tauri::Result<()> {
    let icon = app
        .default_window_icon()
        .cloned()
        .map(|icon| icon.to_owned())
        .unwrap_or_else(fallback_tray_icon);

    let builder = TrayIconBuilder::with_id(TRAY_ICON_ID)
        .tooltip("Quota Radar")
        .icon(icon)
        .icon_as_template(true)
        .show_menu_on_left_click(false)
        .on_tray_icon_event(|tray, event| {
            if is_primary_click_release(&event) {
                let _ = toggle_tray_window(tray.app_handle());
            }
        });

    #[cfg(target_os = "linux")]
    {
        let menu = Menu::new(app)?;
        let _tray = builder.menu(&menu).build(app)?;
        return Ok(());
    }

    #[cfg(not(target_os = "linux"))]
    let _tray = builder.build(app)?;

    Ok(())
}

fn is_primary_click_release(event: &TrayIconEvent) -> bool {
    matches!(
        event,
        TrayIconEvent::Click {
            button: MouseButton::Left,
            button_state: MouseButtonState::Up,
            ..
        }
    )
}

fn toggle_tray_window<R: Runtime>(app: &AppHandle<R>) -> tauri::Result<()> {
    let window = app
        .get_webview_window(TRAY_LABEL)
        .ok_or(tauri::Error::WindowNotFound)?;

    match TrayToggleState::from_visible(window.is_visible().unwrap_or(false)) {
        TrayToggleState::Hide => window.hide(),
        TrayToggleState::Show => {
            position_tray_window(&window)?;
            window.show()?;
            window.set_focus()
        }
    }
}

fn position_tray_window<R: Runtime>(window: &WebviewWindow<R>) -> tauri::Result<()> {
    if window
        .move_window_constrained(Position::TrayBottomRight)
        .is_ok()
    {
        return Ok(());
    }

    if let Some(monitor) = window
        .current_monitor()?
        .or(window.primary_monitor()?)
        .or_else(|| window.available_monitors().ok()?.into_iter().next())
    {
        let work_area = monitor.work_area();
        let window_size = window.outer_size()?;
        let position = fallback_tray_position(
            WorkArea {
                x: work_area.position.x as f64,
                y: work_area.position.y as f64,
                width: work_area.size.width as f64,
                height: work_area.size.height as f64,
            },
            window_size.width as f64,
            window_size.height as f64,
        );
        window.set_position(PhysicalPosition::new(
            position.x.round() as i32,
            position.y.round() as i32,
        ))?;
    }

    Ok(())
}

fn fallback_tray_icon() -> Image<'static> {
    const SIZE: u32 = 32;
    let mut rgba = vec![0; (SIZE * SIZE * 4) as usize];
    let center = (SIZE as f64 - 1.0) / 2.0;

    for y in 0..SIZE {
        for x in 0..SIZE {
            let dx = x as f64 - center;
            let dy = y as f64 - center;
            let distance = (dx * dx + dy * dy).sqrt();
            let on_outer_ring = (11.4..=13.2).contains(&distance);
            let on_inner_ring = (4.6..=5.9).contains(&distance);
            let on_sweep = dy.abs() <= 1.0 && dx >= -1.0 && dx <= 11.5;
            let on_center = distance <= 1.8;

            if on_outer_ring || on_inner_ring || on_sweep || on_center {
                let index = ((y * SIZE + x) * 4) as usize;
                rgba[index] = 255;
                rgba[index + 1] = 255;
                rgba[index + 2] = 255;
                rgba[index + 3] = 255;
            }
        }
    }

    Image::new_owned(rgba, SIZE, SIZE)
}
