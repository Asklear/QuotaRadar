#!/bin/bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${PROJECT_DIR}/build/visual-qa"
APP_BUNDLE="${PROJECT_DIR}/build/Quota Radar.app"
APP_EXECUTABLE="${APP_BUNDLE}/Contents/MacOS/QuotaRadar"
WINDOW_REPORT="${OUTPUT_DIR}/windows.txt"
PANEL_BOUNDS_FILE="${OUTPUT_DIR}/status-panel-bounds.txt"
MAIN_WINDOW_ID_FILE="${OUTPUT_DIR}/main-window-id.txt"
SUMMARY_TEXT_FILE="${OUTPUT_DIR}/summary.txt"
SUMMARY_JSON_FILE="${OUTPUT_DIR}/summary.json"
FOCUS_SIGNALS=(low expiring attention recent)

mkdir -p "${OUTPUT_DIR}"

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

assert_file_nonempty() {
    local path="$1"
    local message="$2"
    if [ ! -s "${path}" ]; then
        fail "${message}"
    fi
}

assert_png_minimum_size() {
    local path="$1"
    local min_width="$2"
    local min_height="$3"
    local label="$4"

    python3 - "${path}" "${min_width}" "${min_height}" "${label}" <<'PY'
from pathlib import Path
import struct
import sys

path = Path(sys.argv[1])
min_width = int(sys.argv[2])
min_height = int(sys.argv[3])
label = sys.argv[4]

try:
    data = path.read_bytes()
except FileNotFoundError:
    print(f"FAIL: {label} screenshot does not exist: {path}", file=sys.stderr)
    sys.exit(1)

if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n":
    print(f"FAIL: {label} screenshot is not a valid PNG: {path}", file=sys.stderr)
    sys.exit(1)

width, height = struct.unpack(">II", data[16:24])
if width < min_width or height < min_height:
    print(
        f"FAIL: {label} screenshot is too small: {width}x{height}, expected at least {min_width}x{min_height}",
        file=sys.stderr,
    )
    sys.exit(1)
PY
}

assert_focused_highlight_present() {
    local path="$1"
    local report_path="${path%.png}-highlight-report.txt"

    python3 - "${path}" "${report_path}" <<'PY'
from pathlib import Path
from PIL import Image
import sys

path = Path(sys.argv[1])
report_path = Path(sys.argv[2])
minimum_highlight_pixels = 20000

try:
    image = Image.open(path).convert("RGB")
except FileNotFoundError:
    print(f"FAIL: focused main-window screenshot does not exist: {path}", file=sys.stderr)
    sys.exit(1)

width, height = image.size
crop = (
    int(width * 0.28),
    int(height * 0.15),
    int(width * 0.90),
    int(height * 0.95),
)

highlight_pixels = 0
for y in range(crop[1], crop[3]):
    for x in range(crop[0], crop[2]):
        red, green, blue = image.getpixel((x, y))
        is_blue_focus = (
            185 <= red <= 235
            and 195 <= green <= 245
            and 220 <= blue <= 255
            and blue - red >= 18
            and blue - green >= 8
        )
        is_risk_focus = (
            210 <= red <= 255
            and 180 <= green <= 245
            and 175 <= blue <= 245
            and red - min(green, blue) >= 2
        )
        if is_blue_focus or is_risk_focus:
            highlight_pixels += 1

report = (
    f"path={path}\n"
    f"size={width}x{height}\n"
    f"crop={crop[0]},{crop[1]},{crop[2]},{crop[3]}\n"
    f"highlight_pixels={highlight_pixels}\n"
    f"minimum_highlight_pixels={minimum_highlight_pixels}\n"
)
report_path.write_text(report)

if highlight_pixels < minimum_highlight_pixels:
    print(
        f"FAIL: focused main-window screenshot does not show a visible account highlight "
        f"({highlight_pixels} matching pixels, expected at least {minimum_highlight_pixels})",
        file=sys.stderr,
    )
    sys.exit(1)
PY
}

capture_focused_signal() {
    local signal="$1"
    local focused_windows_file="${OUTPUT_DIR}/focused-${signal}-windows.txt"
    local focused_window_id_file="${OUTPUT_DIR}/focused-${signal}-window-id.txt"
    local focused_screenshot="${OUTPUT_DIR}/focused-${signal}-window.png"

    rm -f "${focused_windows_file}" "${focused_window_id_file}" "${focused_screenshot}" "${focused_screenshot%.png}-highlight-report.txt"

    QUOTARADAR_OPEN_MENU_SIGNAL_FOR_AUTOMATION="${signal}" "${APP_EXECUTABLE}" >"${OUTPUT_DIR}/focus-${signal}-app.log" 2>&1 &
    FOCUS_APP_PID=$!

    sleep 4

    swift - "${focused_windows_file}" "${focused_window_id_file}" <<'SWIFT'
import CoreGraphics
import Foundation

let reportURL = URL(fileURLWithPath: CommandLine.arguments[1])
let mainWindowIDURL = URL(fileURLWithPath: CommandLine.arguments[2])
let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
    FileManager.default.createFile(atPath: reportURL.path, contents: Data("No windows\n".utf8))
    exit(1)
}

var report: [String] = []
var mainWindowID: String?
for window in windows {
    let owner = window[kCGWindowOwnerName as String] as? String ?? ""
    let name = window[kCGWindowName as String] as? String ?? ""
    let bounds = window[kCGWindowBounds as String] as? [String: Any] ?? [:]
    let width = bounds["Width"] as? Int ?? 0
    let height = bounds["Height"] as? Int ?? 0
    let id = window[kCGWindowNumber as String] ?? "?"

    if owner.localizedCaseInsensitiveContains("Quota") || name.localizedCaseInsensitiveContains("quota") {
        report.append("id=\(id) owner=\(owner) name=\(name) width=\(width) height=\(height)")
    }

    if owner == "Quota Radar", name == "Quota Radar", width >= 900, height >= 600 {
        mainWindowID = "\(id)"
    }
}

try report.joined(separator: "\n").write(to: reportURL, atomically: true, encoding: .utf8)
try (mainWindowID.map { "\($0)\n" } ?? "").write(to: mainWindowIDURL, atomically: true, encoding: .utf8)
SWIFT

    assert_file_nonempty "${focused_window_id_file}" "Visual QA could not identify the focused main settings window for signal: ${signal}"
    local focused_main_window_id
    focused_main_window_id="$(tr -d '\n' <"${focused_window_id_file}")"
    screencapture -x -l"${focused_main_window_id}" "${focused_screenshot}"
    assert_file_nonempty "${focused_screenshot}" "Visual QA did not capture the focused main settings window for signal: ${signal}"
    assert_png_minimum_size "${focused_screenshot}" 900 600 "focused ${signal} main settings window"
    assert_focused_highlight_present "${focused_screenshot}"

    if [ "${signal}" = "low" ]; then
        cp "${focused_window_id_file}" "${OUTPUT_DIR}/focused-main-window-id.txt"
        cp "${focused_windows_file}" "${OUTPUT_DIR}/focused-windows.txt"
        cp "${focused_screenshot}" "${OUTPUT_DIR}/focused-main-window.png"
        cp "${focused_screenshot%.png}-highlight-report.txt" "${OUTPUT_DIR}/focused-highlight-report.txt"
    fi

    kill "${FOCUS_APP_PID}" 2>/dev/null || true
    wait "${FOCUS_APP_PID}" 2>/dev/null || true
    FOCUS_APP_PID=""
    sleep 1
}

write_visual_qa_summary() {
    python3 - "${OUTPUT_DIR}" "${SUMMARY_TEXT_FILE}" "${SUMMARY_JSON_FILE}" "${FOCUS_SIGNALS[@]}" <<'PY'
from datetime import datetime, timezone
from pathlib import Path
import json
import struct
import sys

output_dir = Path(sys.argv[1])
summary_text_file = Path(sys.argv[2])
summary_json_file = Path(sys.argv[3])
focused_signals = sys.argv[4:]

def png_size(path: Path):
    try:
        data = path.read_bytes()
    except FileNotFoundError:
        return None
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    width, height = struct.unpack(">II", data[16:24])
    return {"width": width, "height": height}

def parse_key_value_file(path: Path):
    values = {}
    if not path.exists():
        return values
    for line in path.read_text().splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key] = value
    return values

screenshots = {}
for name in [
    "main-window.png",
    "menu-bar-popover.png",
    "focused-main-window.png",
    "desktop.png",
]:
    screenshots[name] = png_size(output_dir / name)

focused = []
for signal in focused_signals:
    screenshot_name = f"focused-{signal}-window.png"
    report = parse_key_value_file(output_dir / f"focused-{signal}-window-highlight-report.txt")
    highlight_pixels = int(report.get("highlight_pixels", "0") or 0)
    minimum_highlight_pixels = int(report.get("minimum_highlight_pixels", "0") or 0)
    focused.append({
        "signal": signal,
        "screenshot": screenshot_name,
        "dimensions": png_size(output_dir / screenshot_name),
        "highlight_pixels": highlight_pixels,
        "minimum_highlight_pixels": minimum_highlight_pixels,
        "highlight_passed": highlight_pixels >= minimum_highlight_pixels and minimum_highlight_pixels > 0,
    })

behavior_tests = parse_key_value_file(output_dir / "behavior-tests-status.txt")
summary = {
    "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "behavior_tests": behavior_tests or {"status": "missing", "command": "bash Tests/run_behavior_tests.sh"},
    "visual_qa": {
        "status": "passed",
        "command": "bash Tests/run_visual_qa.sh",
        "focused_signals": focused_signals,
    },
    "screenshots": screenshots,
    "focused_checks": focused,
}

summary_json_file.write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n")

lines = [
    "Quota Radar Visual QA Summary",
    "=============================",
    f"Generated: {summary['generated_at']}",
    "",
    f"Behavior tests: {summary['behavior_tests'].get('status', 'missing')} ({summary['behavior_tests'].get('command', 'bash Tests/run_behavior_tests.sh')})",
    f"Visual QA: {summary['visual_qa']['status']} ({summary['visual_qa']['command']})",
    "",
    "Screenshots:",
]
for name, dimensions in screenshots.items():
    if dimensions:
        lines.append(f"- {name}: {dimensions['width']}x{dimensions['height']}")
    else:
        lines.append(f"- {name}: missing")

lines.extend(["", "Focused signals:"])
for item in focused:
    dimensions = item["dimensions"]
    size = f"{dimensions['width']}x{dimensions['height']}" if dimensions else "missing"
    state = "pass" if item["highlight_passed"] else "fail"
    lines.append(
        f"- {item['signal']}: {item['screenshot']} {size}, "
        f"highlight {item['highlight_pixels']}/{item['minimum_highlight_pixels']} ({state})"
    )

summary_text_file.write_text("\n".join(lines) + "\n")
PY
}

if [ ! -x "${APP_EXECUTABLE}" ]; then
    "${PROJECT_DIR}/install.sh" --bundle-only --rebuild
fi

pkill -x QuotaRadar 2>/dev/null || true
sleep 1

QUOTARADAR_SHOW_STATUS_PANEL_FOR_AUTOMATION=1 "${APP_EXECUTABLE}" >"${OUTPUT_DIR}/app.log" 2>&1 &
APP_PID=$!
FOCUS_APP_PID=""

cleanup() {
    kill "${APP_PID}" 2>/dev/null || true
    if [ -n "${FOCUS_APP_PID}" ]; then
        kill "${FOCUS_APP_PID}" 2>/dev/null || true
    fi
}
trap cleanup EXIT

sleep 4

swift - "${WINDOW_REPORT}" "${PANEL_BOUNDS_FILE}" "${MAIN_WINDOW_ID_FILE}" <<'SWIFT'
import AppKit
import CoreGraphics
import Foundation

let reportURL = URL(fileURLWithPath: CommandLine.arguments[1])
let boundsURL = URL(fileURLWithPath: CommandLine.arguments[2])
let mainWindowIDURL = URL(fileURLWithPath: CommandLine.arguments[3])
let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
    FileManager.default.createFile(atPath: reportURL.path, contents: Data("No windows\n".utf8))
    exit(1)
}

var report: [String] = []
report.append("Screens:")
for (index, screen) in NSScreen.screens.enumerated() {
    report.append("screen=\(index) frame=\(screen.frame) visible=\(screen.visibleFrame)")
}
report.append("Windows:")

var statusPanelBounds: (x: Int, y: Int, width: Int, height: Int)?
var mainWindowID: String?
for window in windows {
    let owner = window[kCGWindowOwnerName as String] as? String ?? ""
    let name = window[kCGWindowName as String] as? String ?? ""
    let bounds = window[kCGWindowBounds as String] as? [String: Any] ?? [:]
    let x = bounds["X"] as? Int ?? 0
    let y = bounds["Y"] as? Int ?? 0
    let width = bounds["Width"] as? Int ?? 0
    let height = bounds["Height"] as? Int ?? 0
    let id = window[kCGWindowNumber as String] ?? "?"
    let layer = window[kCGWindowLayer as String] ?? "?"

    if owner.localizedCaseInsensitiveContains("Quota") || name.localizedCaseInsensitiveContains("quota") {
        report.append("id=\(id) layer=\(layer) owner=\(owner) name=\(name) x=\(x) y=\(y) width=\(width) height=\(height)")
    }

    if owner == "Quota Radar", width >= 540, width <= 660, height >= 720, height <= 820 {
        statusPanelBounds = (x, y, width, height)
    }

    if owner == "Quota Radar", name == "Quota Radar", width >= 900, height >= 600 {
        mainWindowID = "\(id)"
    }
}

try report.joined(separator: "\n").write(to: reportURL, atomically: true, encoding: .utf8)
if let bounds = statusPanelBounds {
    try "\(bounds.x),\(bounds.y),\(bounds.width),\(bounds.height)\n".write(to: boundsURL, atomically: true, encoding: .utf8)
} else {
    try "".write(to: boundsURL, atomically: true, encoding: .utf8)
}
try (mainWindowID.map { "\($0)\n" } ?? "").write(to: mainWindowIDURL, atomically: true, encoding: .utf8)
SWIFT

assert_file_nonempty "${PANEL_BOUNDS_FILE}" "Visual QA could not find the status-panel window bounds"
IFS=, read -r x y width height <"${PANEL_BOUNDS_FILE}" || true
screencapture -x -R"${x},${y},${width},${height}" "${OUTPUT_DIR}/menu-bar-popover.png"
assert_file_nonempty "${OUTPUT_DIR}/menu-bar-popover.png" "Visual QA did not capture the menu-bar popover"
assert_png_minimum_size "${OUTPUT_DIR}/menu-bar-popover.png" 540 720 "menu-bar popover"

assert_file_nonempty "${MAIN_WINDOW_ID_FILE}" "Visual QA could not identify the main settings window"
main_window_id="$(tr -d '\n' <"${MAIN_WINDOW_ID_FILE}")"
screencapture -x -l"${main_window_id}" "${OUTPUT_DIR}/main-window.png"
assert_file_nonempty "${OUTPUT_DIR}/main-window.png" "Visual QA did not capture the main settings window"
assert_png_minimum_size "${OUTPUT_DIR}/main-window.png" 900 600 "main settings window"

screencapture -x "${OUTPUT_DIR}/desktop.png" || true

kill "${APP_PID}" 2>/dev/null || true
wait "${APP_PID}" 2>/dev/null || true
sleep 1

for signal in "${FOCUS_SIGNALS[@]}"; do
    capture_focused_signal "${signal}"
done

write_visual_qa_summary

echo "Visual QA artifacts:"
echo "  ${WINDOW_REPORT}"
echo "  ${OUTPUT_DIR}/main-window.png"
echo "  ${OUTPUT_DIR}/menu-bar-popover.png"
echo "  ${OUTPUT_DIR}/focused-main-window.png"
for signal in "${FOCUS_SIGNALS[@]}"; do
    echo "  ${OUTPUT_DIR}/focused-${signal}-window.png"
done
echo "  ${OUTPUT_DIR}/desktop.png"
echo "  ${SUMMARY_TEXT_FILE}"
echo "  ${SUMMARY_JSON_FILE}"
