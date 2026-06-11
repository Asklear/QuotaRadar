use super::tray::{fallback_tray_position, tray_window_spec, TrayToggleState, WorkArea};

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
}

#[test]
fn tray_toggle_state_flips_between_show_and_hide() {
    assert_eq!(TrayToggleState::from_visible(false), TrayToggleState::Show);
    assert_eq!(TrayToggleState::from_visible(true), TrayToggleState::Hide);
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
