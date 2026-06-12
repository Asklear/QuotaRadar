use super::tray::{
    fallback_tray_position, is_primary_click, menu_bar_template_icon_rgba,
    should_accept_tray_click, tray_anchor_position, tray_icon_spec, tray_window_spec,
    TrayIconSource, TrayRect, TrayToggleState, WorkArea,
};
use super::window::{choose_main_window_frame, DisplayArea, MainWindowFrame};
use std::time::{Duration, Instant};
use tauri::tray::{MouseButton, MouseButtonState};

#[test]
fn tray_window_spec_matches_compact_popover_contract() {
    let spec = tray_window_spec();

    assert_eq!(spec.label, "tray");
    assert_eq!(spec.route, "/?view=tray");
    assert_eq!(spec.width, 560.0);
    assert_eq!(spec.height, 500.0);
    assert!(!spec.visible);
    assert!(!spec.decorations);
    assert!(!spec.resizable);
    assert!(spec.skip_taskbar);
    assert!(spec.transparent);
}

#[test]
fn tray_toggle_state_flips_between_show_and_hide() {
    assert_eq!(TrayToggleState::from_visible(false), TrayToggleState::Show);
    assert_eq!(TrayToggleState::from_visible(true), TrayToggleState::Hide);
}

#[test]
fn tray_click_toggles_once_on_primary_down_event() {
    assert!(is_primary_click(MouseButton::Left, MouseButtonState::Down));
    assert!(is_primary_click(MouseButton::Left, MouseButtonState::Up));
    assert!(!is_primary_click(MouseButton::Right, MouseButtonState::Up));
}

#[test]
fn tray_click_debounce_allows_accessibility_clicks_without_double_toggling() {
    let now = Instant::now();

    assert!(should_accept_tray_click(None, now));
    assert!(!should_accept_tray_click(
        Some(now),
        now + Duration::from_millis(120)
    ));
    assert!(should_accept_tray_click(
        Some(now),
        now + Duration::from_millis(320)
    ));
}

#[test]
fn tray_icon_uses_dedicated_template_artwork_not_the_bundle_icon() {
    let spec = tray_icon_spec();

    assert_eq!(spec.id, "quota-radar-tray");
    assert_eq!(spec.tooltip, "Quota Radar");
    assert_eq!(spec.title, None);
    assert_eq!(spec.source, TrayIconSource::TemplateArtwork);
}

#[test]
fn menu_bar_template_artwork_has_visible_mask_and_clear_cutouts() {
    let rgba = menu_bar_template_icon_rgba();
    let opaque_pixels = rgba.chunks_exact(4).filter(|pixel| pixel[3] == 255).count();
    let transparent_pixels = rgba.chunks_exact(4).filter(|pixel| pixel[3] == 0).count();

    assert_eq!(rgba.len(), 36 * 36 * 4);
    assert!(opaque_pixels > 300);
    assert!(transparent_pixels > 300);
}

#[test]
fn fallback_position_anchors_to_top_right_work_area_with_margin() {
    let work_area = WorkArea {
        x: 0.0,
        y: 25.0,
        width: 1440.0,
        height: 875.0,
    };

    let position = fallback_tray_position(work_area, 560.0, 500.0);

    assert_eq!(position.x, 868.0);
    assert_eq!(position.y, 37.0);
}

#[test]
fn fallback_position_never_escapes_small_work_area() {
    let work_area = WorkArea {
        x: 20.0,
        y: 30.0,
        width: 400.0,
        height: 300.0,
    };

    let position = fallback_tray_position(work_area, 560.0, 500.0);

    assert_eq!(position.x, 20.0);
    assert_eq!(position.y, 30.0);
}

#[test]
fn tray_anchor_position_follows_menu_bar_item_on_negative_display() {
    let work_area = WorkArea {
        x: -1920.0,
        y: 0.0,
        width: 1920.0,
        height: 1080.0,
    };
    let tray_rect = TrayRect {
        x: -943.0,
        y: 0.0,
        width: 33.0,
        height: 30.0,
    };

    let position = tray_anchor_position(work_area, tray_rect, 560.0, 500.0);

    assert_eq!(position.x, -1470.0);
    assert_eq!(position.y, 42.0);
}

#[test]
fn tray_anchor_position_stays_inside_the_active_display() {
    let work_area = WorkArea {
        x: 0.0,
        y: 0.0,
        width: 320.0,
        height: 280.0,
    };
    let tray_rect = TrayRect {
        x: 300.0,
        y: 0.0,
        width: 18.0,
        height: 24.0,
    };

    let position = tray_anchor_position(work_area, tray_rect, 560.0, 500.0);

    assert_eq!(position.x, 0.0);
    assert_eq!(position.y, 0.0);
}

#[test]
fn main_window_without_saved_frame_opens_on_interaction_display() {
    let interaction_display = DisplayArea {
        x: 1440.0,
        y: 0.0,
        width: 1512.0,
        height: 982.0,
    };

    let frame = choose_main_window_frame(
        None,
        interaction_display,
        &[interaction_display],
        1120.0,
        640.0,
    );

    assert_eq!(
        frame,
        MainWindowFrame {
            x: 1636.0,
            y: 171.0,
            width: 1120.0,
            height: 640.0
        }
    );
}

#[test]
fn main_window_preserves_saved_negative_display_frame_when_visible() {
    let primary = DisplayArea {
        x: 0.0,
        y: 0.0,
        width: 1512.0,
        height: 982.0,
    };
    let external_left = DisplayArea {
        x: -1920.0,
        y: 0.0,
        width: 1920.0,
        height: 1080.0,
    };
    let saved = MainWindowFrame {
        x: -1493.0,
        y: 133.0,
        width: 1120.0,
        height: 640.0,
    };

    let frame = choose_main_window_frame(
        Some(saved),
        primary,
        &[primary, external_left],
        1120.0,
        640.0,
    );

    assert_eq!(frame, saved);
}

#[test]
fn main_window_repairs_offscreen_saved_frame_to_interaction_display() {
    let interaction_display = DisplayArea {
        x: 0.0,
        y: 25.0,
        width: 1440.0,
        height: 875.0,
    };
    let disconnected_display_frame = MainWindowFrame {
        x: -1493.0,
        y: 133.0,
        width: 1120.0,
        height: 640.0,
    };

    let frame = choose_main_window_frame(
        Some(disconnected_display_frame),
        interaction_display,
        &[interaction_display],
        1120.0,
        640.0,
    );

    assert_eq!(
        frame,
        MainWindowFrame {
            x: 160.0,
            y: 142.5,
            width: 1120.0,
            height: 640.0
        }
    );
}

#[test]
fn main_window_frame_keeps_size_but_anchors_when_display_is_smaller_than_window() {
    let interaction_display = DisplayArea {
        x: 10.0,
        y: 20.0,
        width: 900.0,
        height: 620.0,
    };

    let frame = choose_main_window_frame(
        None,
        interaction_display,
        &[interaction_display],
        1120.0,
        640.0,
    );

    assert_eq!(
        frame,
        MainWindowFrame {
            x: 10.0,
            y: 20.0,
            width: 1120.0,
            height: 640.0
        }
    );
}
