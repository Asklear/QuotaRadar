#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${QR_TAURI_APP_PATH:-$ROOT_DIR/apps/desktop-tauri/src-tauri/target/release/bundle/macos/Quota Radar Tauri Preview.app}"
OUT_DIR="${1:-/tmp/quotaradar-tauri-qa-$(date +%Y%m%d-%H%M%S)}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Tauri screenshot QA is only available on macOS." >&2
  exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Tauri app bundle not found: $APP_PATH" >&2
  echo "Run: cd apps/desktop-tauri && pnpm package:mac:local" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

open "$APP_PATH"
sleep 2

PROCESS_NAME="$(osascript <<'APPLESCRIPT'
tell application "System Events"
  set candidateNames to {"quotaradar-desktop-tauri", "Quota Radar"}
  repeat with candidateName in candidateNames
    if exists process (candidateName as text) then return candidateName as text
  end repeat
end tell
error "Quota Radar Tauri process is not running"
APPLESCRIPT
)"

osascript - "$PROCESS_NAME" <<'APPLESCRIPT'
on run argv
  set processName to item 1 of argv
  tell application "System Events"
    tell process processName
      set frontmost to true
    end tell
  end tell
end run
APPLESCRIPT
sleep 1

osascript "$ROOT_DIR/scripts/qa_tauri_window_state.applescript" "$PROCESS_NAME" > "$OUT_DIR/window-state.txt"
screencapture -x "$OUT_DIR/main-window-screen.png"

TRAY_RECT="$(osascript "$ROOT_DIR/scripts/qa_tauri_tray_rect.applescript" "$PROCESS_NAME" 2>/dev/null || true)"
if [[ -n "$TRAY_RECT" ]]; then
  echo "$TRAY_RECT" > "$OUT_DIR/menu-bar-item-rect.txt"
  IFS=',' read -r TRAY_X TRAY_Y TRAY_W TRAY_H <<< "$TRAY_RECT"
  export QR_CLICK_X
  export QR_CLICK_Y
  QR_CLICK_X="$(python3 -c "print(float('$TRAY_X') + float('$TRAY_W') / 2.0)")"
  QR_CLICK_Y="$(python3 -c "print(float('$TRAY_Y') + float('$TRAY_H') / 2.0)")"
  swift - <<'SWIFT'
import CoreGraphics
import Foundation

let x = Double(ProcessInfo.processInfo.environment["QR_CLICK_X"] ?? "0") ?? 0
let y = Double(ProcessInfo.processInfo.environment["QR_CLICK_Y"] ?? "0") ?? 0
let point = CGPoint(x: x, y: y)
let source = CGEventSource(stateID: .hidSystemState)
let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
down?.post(tap: .cghidEventTap)
Thread.sleep(forTimeInterval: 0.08)
up?.post(tap: .cghidEventTap)
SWIFT
  sleep 1
  screencapture -x "$OUT_DIR/menu-bar-popover-screen.png"
else
  echo "Menu bar item was not found through accessibility APIs." > "$OUT_DIR/menu-bar-popover-skipped.txt"
fi

cat > "$OUT_DIR/checklist.md" <<EOF
# Quota Radar Tauri macOS Screenshot QA

- [ ] Main window is visible on the current interaction display.
- [ ] Main window is not white, clipped, or opened on a disconnected / negative-coordinate display unexpectedly.
- [ ] Sidebar and content do not overlap at the current window size.
- [ ] Menu bar popover is adjacent to the menu bar item and is not top-clipped.
- [ ] Menu bar popover uses the same app/provider icon style as the Swift app.
- [ ] External display behavior is covered if an external display is attached during this run.
- [ ] Dark mode is covered manually if this run was not already in dark mode.
- [ ] Transparent menu bar / desktop background contrast is checked manually if the current desktop is not representative.

Artifacts:

- main-window-screen.png
- menu-bar-popover-screen.png, or menu-bar-popover-skipped.txt if accessibility could not locate the status item
- menu-bar-item-rect.txt when the status item is found
- window-state.txt
EOF

echo "Tauri macOS screenshot QA artifacts: $OUT_DIR"
