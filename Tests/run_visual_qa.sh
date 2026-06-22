#!/bin/bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${PROJECT_DIR}/build/visual-qa"
APP_BUNDLE="${PROJECT_DIR}/build/Quota Radar.app"
APP_EXECUTABLE="${APP_BUNDLE}/Contents/MacOS/QuotaRadar"
SUMMARY_TEXT_FILE="${OUTPUT_DIR}/summary.txt"
SUMMARY_JSON_FILE="${OUTPUT_DIR}/summary.json"
CHECK_RESULTS_FILE="${OUTPUT_DIR}/check-results.tsv"
FAILURE_REASONS_FILE="${OUTPUT_DIR}/failure-reasons.txt"
SCENARIO_SCREENSHOTS_FILE="${OUTPUT_DIR}/scenario-screenshots.tsv"
WINDOW_REPORT="${OUTPUT_DIR}/windows.txt"
PANEL_BOUNDS_FILE="${OUTPUT_DIR}/status-panel-bounds.txt"
MAIN_WINDOW_ID_FILE="${OUTPUT_DIR}/main-window-id.txt"
FOCUS_SIGNALS=(low expiring attention recent)

VISUAL_QA_LANGUAGES="zh-Hans|en"
VISUAL_QA_APPEARANCES="light|dark"
VISUAL_QA_WINDOW_CLASSES="13-inch|wide"
VISUAL_QA_SCENARIOS=(
    "zh-Hans-light-13-inch|zh-Hans|light|900x600|0.58"
    "zh-Hans-dark-wide-transparent-zero|zh-Hans|dark|1280x760|0.00"
    "zh-Hans-light-dense-accounts|zh-Hans|light|1280x760|0.58"
    "en-light-wide|en|light|1280x760|0.58"
    "en-dark-13-inch|en|dark|900x600|0.58"
)

mkdir -p "${OUTPUT_DIR}"
: >"${CHECK_RESULTS_FILE}"
: >"${FAILURE_REASONS_FILE}"
: >"${SCENARIO_SCREENSHOTS_FILE}"

APP_PID=""
FOCUS_APP_PID=""

record_check() {
    local scenario="$1"
    local check_name="$2"
    local status="$3"
    local detail="$4"
    printf '%s\t%s\t%s\t%s\n' "${scenario}" "${check_name}" "${status}" "${detail}" >>"${CHECK_RESULTS_FILE}"
}

write_visual_qa_summary() {
    local status="${1:-passed}"
    python3 - "${OUTPUT_DIR}" "${SUMMARY_TEXT_FILE}" "${SUMMARY_JSON_FILE}" "${CHECK_RESULTS_FILE}" "${FAILURE_REASONS_FILE}" "${SCENARIO_SCREENSHOTS_FILE}" "${status}" "${FOCUS_SIGNALS[@]}" <<'PY'
from datetime import datetime, timezone
from pathlib import Path
import json
import struct
import sys

output_dir = Path(sys.argv[1])
summary_text_file = Path(sys.argv[2])
summary_json_file = Path(sys.argv[3])
check_results_file = Path(sys.argv[4])
failure_reasons_file = Path(sys.argv[5])
scenario_screenshots_file = Path(sys.argv[6])
status = sys.argv[7]
focused_signals = sys.argv[8:]

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

def read_tsv(path: Path, fields):
    rows = []
    if not path.exists():
        return rows
    for line in path.read_text().splitlines():
        if not line.strip():
            continue
        parts = line.split("\t")
        if len(parts) < len(fields):
            parts += [""] * (len(fields) - len(parts))
        rows.append(dict(zip(fields, parts[:len(fields)])))
    return rows

scenario_rows = read_tsv(
    scenario_screenshots_file,
    ["scenario", "language", "appearance", "window_size", "transparency", "main_window", "menu_bar", "desktop"],
)
check_rows = read_tsv(check_results_file, ["scenario", "check", "status", "detail"])
failure_reasons = [
    line.strip()
    for line in failure_reasons_file.read_text().splitlines()
    if line.strip()
] if failure_reasons_file.exists() else []

screenshots = {}
for name in [
    "main-window.png",
    "menu-bar-popover.png",
    "focused-main-window.png",
    "desktop.png",
]:
    screenshots[name] = png_size(output_dir / name)

scenario_screenshots = []
for row in scenario_rows:
    scenario_screenshots.append({
        **row,
        "main_dimensions": png_size(output_dir / row["main_window"]),
        "menu_dimensions": png_size(output_dir / row["menu_bar"]),
        "desktop_dimensions": png_size(output_dir / row["desktop"]),
    })

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
languages = sorted({row["language"] for row in scenario_rows})
appearances = sorted({row["appearance"] for row in scenario_rows})
window_sizes = sorted({row["window_size"] for row in scenario_rows})
checklist = {
    "languages": languages,
    "appearances": appearances,
    "window_sizes": window_sizes,
    "surfaces": ["main_window", "menu_bar", "focused_provider", "expanded_provider"],
    "stress_cases": [
        "multi_key_provider",
        "dense_single_provider_accounts",
        "long_provider_name",
        "long_localized_plan_name",
        "long_error_message",
        "transparent_menu_readability",
        "compact_13_inch_window",
        "wide_window",
    ],
}

summary = {
    "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "behavior_tests": behavior_tests or {"status": "missing", "command": "bash Tests/run_behavior_tests.sh"},
    "visual_qa": {
        "status": status,
        "command": "bash Tests/run_visual_qa.sh",
        "focused_signals": focused_signals,
    },
    "checklist": checklist,
    "screenshots": screenshots,
    "scenario_screenshots": scenario_screenshots,
    "focused_checks": focused,
    "quality_checks": check_rows,
    "failure_reasons": failure_reasons,
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
    "Checklist:",
    f"- Languages: {', '.join(checklist['languages']) or 'missing'}",
    f"- Appearances: {', '.join(checklist['appearances']) or 'missing'}",
    f"- Window sizes: {', '.join(checklist['window_sizes']) or 'missing'}",
    f"- Surfaces: {', '.join(checklist['surfaces'])}",
    f"- Stress cases: {', '.join(checklist['stress_cases'])}",
    "",
    "Scenario screenshots:",
]
for row in scenario_screenshots:
    main_size = row["main_dimensions"]
    menu_size = row["menu_dimensions"]
    main_text = f"{main_size['width']}x{main_size['height']}" if main_size else "missing"
    menu_text = f"{menu_size['width']}x{menu_size['height']}" if menu_size else "missing"
    lines.append(
        f"- {row['scenario']}: main={row['main_window']} {main_text}, "
        f"menu={row['menu_bar']} {menu_text}, language={row['language']}, "
        f"appearance={row['appearance']}, window={row['window_size']}, transparency={row['transparency']}"
    )

lines.extend(["", "Legacy screenshots:"])
for name, dimensions in screenshots.items():
    if dimensions:
        lines.append(f"- {name}: {dimensions['width']}x{dimensions['height']}")
    else:
        lines.append(f"- {name}: missing")

lines.extend(["", "Quality checks:"])
for row in check_rows:
    lines.append(f"- {row['scenario']} / {row['check']}: {row['status']} ({row['detail']})")

lines.extend(["", "Focused signals:"])
for item in focused:
    dimensions = item["dimensions"]
    size = f"{dimensions['width']}x{dimensions['height']}" if dimensions else "missing"
    state = "pass" if item["highlight_passed"] else "fail"
    lines.append(
        f"- {item['signal']}: {item['screenshot']} {size}, "
        f"highlight {item['highlight_pixels']}/{item['minimum_highlight_pixels']} ({state})"
    )

lines.extend(["", "Failure reasons:"])
if failure_reasons:
    lines.extend(f"- {reason}" for reason in failure_reasons)
else:
    lines.append("- none")

summary_text_file.write_text("\n".join(lines) + "\n")
PY
}

fail() {
    local message="$1"
    echo "FAIL: ${message}" >&2
    printf '%s\n' "${message}" >>"${FAILURE_REASONS_FILE}"
    write_visual_qa_summary "failed" || true
    exit 1
}

cleanup() {
    if [ -n "${APP_PID}" ]; then
        kill "${APP_PID}" 2>/dev/null || true
        wait "${APP_PID}" 2>/dev/null || true
    fi
    if [ -n "${FOCUS_APP_PID}" ]; then
        kill "${FOCUS_APP_PID}" 2>/dev/null || true
        wait "${FOCUS_APP_PID}" 2>/dev/null || true
    fi
}
trap cleanup EXIT

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

capture_window_png() {
    local window_id="$1"
    local output_path="$2"

    swift - "${window_id}" "${output_path}" <<'SWIFT'
import CoreGraphics
import Foundation
import ImageIO

guard CommandLine.arguments.count == 3,
      let numericWindowID = UInt32(CommandLine.arguments[1]) else {
    exit(1)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let image = CGWindowListCreateImage(
    .null,
    [.optionIncludingWindow],
    CGWindowID(numericWindowID),
    [.boundsIgnoreFraming, .bestResolution]
) else {
    exit(1)
}

guard let destination = CGImageDestinationCreateWithURL(
    outputURL as CFURL,
    "public.png" as CFString,
    1,
    nil
) else {
    exit(1)
}

CGImageDestinationAddImage(destination, image, nil)
if !CGImageDestinationFinalize(destination) {
    exit(1)
}
SWIFT
}

assert_main_table_alignment() {
    local screenshot="$1"
    local scenario="$2"
    local report_path="${OUTPUT_DIR}/alignment-${scenario}.txt"

    python3 - "${PROJECT_DIR}/QuotaRadar/Views/SettingsView.swift" "${report_path}" <<'PY'
from pathlib import Path
import re
import sys

source_path = Path(sys.argv[1])
report_path = Path(sys.argv[2])
source = source_path.read_text()

checks = {
    "header_uses_shared_grid": "struct ProviderQuotaMonitorTableHeader" in source and "ProviderQuotaOverviewGridRow(height: 18)" in source,
    "summary_rows_use_shared_grid": "private var providerSummaryRow" in source and "ProviderQuotaOverviewGridRow(height: 34)" in source,
    "account_header_uses_shared_grid": "struct ProviderQuotaKeyTableHeader" in source and "ProviderQuotaAccountGridRow(height: 18)" in source,
    "account_rows_use_shared_grid": "struct ProviderQuotaKeyTableRow" in source and "ProviderQuotaAccountGridRow(height: 44)" in source,
    "overview_widths_single_source": bool(re.search(r"ProviderQuotaOverviewLayout\.columnWidths\(for:", source)),
    "account_widths_single_source": bool(re.search(r"ProviderQuotaAccountLayout\.columnWidths\(for:", source)),
}
report_path.write_text("\n".join(f"{key}={value}" for key, value in checks.items()) + "\n")

failed = [key for key, value in checks.items() if not value]
if failed:
    print(
        "FAIL: provider table header/content alignment guard failed: " + ", ".join(failed),
        file=sys.stderr,
    )
    sys.exit(1)
PY

    assert_file_nonempty "${screenshot}" "Visual QA alignment check did not receive a screenshot for ${scenario}"
    record_check "${scenario}" "header_content_alignment" "passed" "shared overview/account grid rows; report=$(basename "${report_path}")"
}

assert_no_text_occlusion() {
    local path="$1"
    local scenario="$2"
    local report_path="${OUTPUT_DIR}/occlusion-${scenario}.txt"

    python3 - "${path}" "${report_path}" "${scenario}" <<'PY'
from pathlib import Path
from PIL import Image
import statistics
import sys
import warnings

warnings.filterwarnings("ignore", category=DeprecationWarning)

path = Path(sys.argv[1])
report_path = Path(sys.argv[2])
scenario = sys.argv[3]
image = Image.open(path).convert("RGBA")
width, height = image.size
edge = max(6, min(width, height) // 140)

content_x = []
content_y = []
for y in range(height):
    for x in range(width):
        red, green, blue, alpha = image.getpixel((x, y))
        if alpha >= 32 and max(red, green, blue) > 12:
            content_x.append(x)
            content_y.append(y)

if content_x and content_y:
    content_left = min(content_x)
    content_top = min(content_y)
    content_right = max(content_x) + 1
    content_bottom = max(content_y) + 1
else:
    content_left = 0
    content_top = 0
    content_right = width
    content_bottom = height

outer_ignore = max(48, min(width, height) // 50)
content_inset = max(18, edge * 3)
left = max(outer_ignore, content_left + content_inset)
top = max(outer_ignore, content_top + content_inset)
right = min(width - outer_ignore, content_right - content_inset)
bottom = min(height - outer_ignore, content_bottom - content_inset)

if right <= left + edge * 2 or bottom <= top + edge * 2:
    left = outer_ignore
    top = outer_ignore
    right = width - outer_ignore
    bottom = height - outer_ignore

interior_luminance = []
for y in range(top + edge, bottom - edge):
    for x in range(left + edge, right - edge):
        red, green, blue, alpha = image.getpixel((x, y))
        if alpha < 32:
            continue
        interior_luminance.append(0.2126 * red + 0.7152 * green + 0.0722 * blue)
background_luminance = statistics.median(interior_luminance) if interior_luminance else 128

def is_ink(pixel):
    red, green, blue, alpha = pixel
    if alpha < 32:
        return False
    luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
    return abs(luminance - background_luminance) > 70

edge_pixels = 0
edge_ink = 0
for y in range(top, bottom):
    for x in range(left, right):
        if x >= left + edge and x < right - edge and y >= top + edge and y < bottom - edge:
            continue
        edge_pixels += 1
        if is_ink(image.getpixel((x, y))):
            edge_ink += 1

edge_ink_ratio = edge_ink / max(1, edge_pixels)
report = (
    f"path={path}\n"
    f"scenario={scenario}\n"
    f"size={width}x{height}\n"
    f"content_bounds={content_left},{content_top},{content_right},{content_bottom}\n"
    f"outer_ignore={outer_ignore}\n"
    f"content_inset={content_inset}\n"
    f"sample_bounds={left},{top},{right},{bottom}\n"
    f"edge_width={edge}\n"
    f"background_luminance={background_luminance:.2f}\n"
    f"edge_ink_ratio={edge_ink_ratio:.4f}\n"
    f"maximum_edge_ink_ratio=0.1200\n"
)
report_path.write_text(report)
if edge_ink_ratio > 0.12:
    print(
        f"FAIL: likely text overlap or clipping near screenshot edge for {scenario}: "
        f"edge ink ratio {edge_ink_ratio:.3f} exceeds 0.120",
        file=sys.stderr,
    )
    sys.exit(1)
PY

    record_check "${scenario}" "text_occlusion" "passed" "edge ink below threshold; report=$(basename "${report_path}")"
}

assert_menu_panel_not_clipped() {
    local path="$1"
    local scenario="$2"
    local panel_bounds_file="$3"
    local windows_file="$4"
    local report_path="${OUTPUT_DIR}/menu-clipping-${scenario}.txt"

    python3 - "${path}" "${report_path}" "${scenario}" "${panel_bounds_file}" "${windows_file}" <<'PY'
from pathlib import Path
from PIL import Image
import re
import sys

path = Path(sys.argv[1])
report_path = Path(sys.argv[2])
scenario = sys.argv[3]
panel_bounds_file = Path(sys.argv[4])
windows_file = Path(sys.argv[5])
image = Image.open(path).convert("RGB")
width, height = image.size

try:
    panel_x, panel_y, panel_width, panel_height = [
        float(value) for value in panel_bounds_file.read_text().strip().split(",")
    ]
except Exception as error:
    print(f"FAIL: could not parse status-panel bounds for {scenario}: {error}", file=sys.stderr)
    sys.exit(1)

screen_frames = []
for line in windows_file.read_text().splitlines():
    match = re.search(r"screen=\d+ frame=\(([-0-9.]+), ([-0-9.]+), ([-0-9.]+), ([-0-9.]+)\)", line)
    if match:
        screen_frames.append(tuple(float(value) for value in match.groups()))

if not screen_frames:
    print(f"FAIL: no screen frame recorded for menu clipping check in {scenario}", file=sys.stderr)
    sys.exit(1)

tolerance = 2.0
containing_screen = None
for screen_x, screen_y, screen_width, screen_height in screen_frames:
    if (
        panel_x >= screen_x - tolerance
        and panel_y >= screen_y - tolerance
        and panel_x + panel_width <= screen_x + screen_width + tolerance
        and panel_y + panel_height <= screen_y + screen_height + tolerance
    ):
        containing_screen = (screen_x, screen_y, screen_width, screen_height)
        break

report = (
    f"path={path}\n"
    f"scenario={scenario}\n"
    f"size={width}x{height}\n"
    f"panel_bounds={panel_x:.1f},{panel_y:.1f},{panel_width:.1f},{panel_height:.1f}\n"
    f"screen_frames={screen_frames}\n"
    f"containing_screen={containing_screen}\n"
)
report_path.write_text(report)
if containing_screen is None:
    print(
        f"FAIL: menu bar panel appears clipped or off-screen for {scenario}: "
        f"panel bounds {panel_x:.0f},{panel_y:.0f},{panel_width:.0f},{panel_height:.0f}",
        file=sys.stderr,
    )
    sys.exit(1)
PY

    record_check "${scenario}" "menubar_top_bottom_clipping" "passed" "panel bounds fit within screen; report=$(basename "${report_path}")"
}

assert_transparency_readability() {
    local path="$1"
    local scenario="$2"
    local report_path="${OUTPUT_DIR}/readability-${scenario}.txt"

    python3 - "${path}" "${report_path}" "${scenario}" <<'PY'
from pathlib import Path
from PIL import Image
import statistics
import sys
import warnings

warnings.filterwarnings("ignore", category=DeprecationWarning)

path = Path(sys.argv[1])
report_path = Path(sys.argv[2])
scenario = sys.argv[3]
image = Image.open(path).convert("RGB")
width, height = image.size
crop = image.crop((int(width * 0.08), int(height * 0.08), int(width * 0.92), int(height * 0.92)))
luminance_values = []
for red, green, blue in crop.getdata():
    luminance_values.append(0.2126 * red + 0.7152 * green + 0.0722 * blue)

luminance_values.sort()
low = luminance_values[max(0, int(len(luminance_values) * 0.05) - 1)]
high = luminance_values[min(len(luminance_values) - 1, int(len(luminance_values) * 0.95))]
contrast_span = high - low
mean = statistics.fmean(luminance_values)
report = (
    f"path={path}\n"
    f"scenario={scenario}\n"
    f"luminance_p05={low:.2f}\n"
    f"luminance_p95={high:.2f}\n"
    f"luminance_mean={mean:.2f}\n"
    f"contrast_span={contrast_span:.2f}\n"
    f"minimum_contrast_span=18.00\n"
)
report_path.write_text(report)
if contrast_span < 18:
    print(
        f"FAIL: menu transparency/readability is too weak for {scenario}: "
        f"luminance contrast span {contrast_span:.1f}, expected at least 18",
        file=sys.stderr,
    )
    sys.exit(1)
PY

    record_check "${scenario}" "transparency_readability" "passed" "luminance contrast above threshold; report=$(basename "${report_path}")"
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

capture_windows_for_scenario() {
    local windows_file="$1"
    local panel_bounds_file="$2"
    local main_window_id_file="$3"

    swift - "${windows_file}" "${panel_bounds_file}" "${main_window_id_file}" <<'SWIFT'
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

    if owner == "Quota Radar", name.localizedCaseInsensitiveContains("Quota Radar"), width >= 880, height >= 580 {
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
}

capture_status_panel_bounds_with_retry() {
    local windows_file="$1"
    local panel_bounds_file="$2"
    local main_window_id_file="$3"
    local attempt=1
    local max_attempts=8

    while [ "${attempt}" -le "${max_attempts}" ]; do
        capture_windows_for_scenario "${windows_file}" "${panel_bounds_file}" "${main_window_id_file}"
        if [ -s "${panel_bounds_file}" ]; then
            return 0
        fi
        sleep 0.5
        attempt=$((attempt + 1))
    done

    return 1
}

run_scenario() {
    local scenario="$1"
    local language="$2"
    local appearance="$3"
    local window_size="$4"
    local transparency="$5"
    local windows_file="${OUTPUT_DIR}/windows-${scenario}.txt"
    local panel_bounds_file="${OUTPUT_DIR}/status-panel-bounds-${scenario}.txt"
    local main_window_id_file="${OUTPUT_DIR}/main-window-id-${scenario}.txt"
    local menu_screenshot="${OUTPUT_DIR}/menu-bar-popover-${scenario}.png"
    local main_screenshot="${OUTPUT_DIR}/main-window-${scenario}.png"
    local desktop_screenshot="${OUTPUT_DIR}/desktop-${scenario}.png"

    rm -f "${windows_file}" "${panel_bounds_file}" "${main_window_id_file}" "${menu_screenshot}" "${main_screenshot}" "${desktop_screenshot}"

    pkill -x QuotaRadar 2>/dev/null || true
    sleep 1

    QUOTARADAR_VISUAL_QA_FIXTURES=1 \
    QUOTARADAR_VISUAL_QA_LANGUAGE="${language}" \
    QUOTARADAR_VISUAL_QA_APPEARANCE="${appearance}" \
    QUOTARADAR_VISUAL_QA_WINDOW_SIZE="${window_size}" \
    QUOTARADAR_VISUAL_QA_TRANSPARENCY="${transparency}" \
    QUOTARADAR_SHOW_STATUS_PANEL_FOR_AUTOMATION=1 \
    "${APP_EXECUTABLE}" >"${OUTPUT_DIR}/app-${scenario}.log" 2>&1 &
    APP_PID=$!

    sleep 4

    capture_status_panel_bounds_with_retry "${windows_file}" "${panel_bounds_file}" "${main_window_id_file}" || true

    assert_file_nonempty "${panel_bounds_file}" "Visual QA could not find the status-panel window bounds for ${scenario}"
    IFS=, read -r x y width height <"${panel_bounds_file}" || true
    local menu_window_id
    menu_window_id="$(
        sed -nE 's/^id=([0-9]+).*owner=Quota Radar.*width=([0-9]+) height=([0-9]+).*$/\1 \2 \3/p' "${windows_file}" \
            | awk '$2 >= 540 && $2 <= 660 && $3 >= 720 && $3 <= 820 { print $1; exit }'
    )"
    if [ -n "${menu_window_id}" ]; then
        capture_window_png "${menu_window_id}" "${menu_screenshot}" || \
            screencapture -x -R"${x},${y},${width},${height}" "${menu_screenshot}"
    else
        screencapture -x -R"${x},${y},${width},${height}" "${menu_screenshot}"
    fi
    assert_file_nonempty "${menu_screenshot}" "Visual QA did not capture the menu-bar popover for ${scenario}"
    assert_png_minimum_size "${menu_screenshot}" 540 720 "menu-bar popover ${scenario}"

    assert_file_nonempty "${main_window_id_file}" "Visual QA could not identify the main settings window for ${scenario}"
    local main_window_id
    main_window_id="$(tr -d '\n' <"${main_window_id_file}")"
    screencapture -x -l"${main_window_id}" "${main_screenshot}"
    assert_file_nonempty "${main_screenshot}" "Visual QA did not capture the main settings window for ${scenario}"
    assert_png_minimum_size "${main_screenshot}" 900 600 "main settings window ${scenario}"

    screencapture -x "${desktop_screenshot}" || true

    assert_main_table_alignment "${main_screenshot}" "${scenario}"
    assert_no_text_occlusion "${main_screenshot}" "${scenario}-main"
    assert_no_text_occlusion "${menu_screenshot}" "${scenario}-menu"
    assert_menu_panel_not_clipped "${menu_screenshot}" "${scenario}" "${panel_bounds_file}" "${windows_file}"
    assert_transparency_readability "${menu_screenshot}" "${scenario}"

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "${scenario}" "${language}" "${appearance}" "${window_size}" "${transparency}" \
        "$(basename "${main_screenshot}")" "$(basename "${menu_screenshot}")" "$(basename "${desktop_screenshot}")" \
        >>"${SCENARIO_SCREENSHOTS_FILE}"

    if [ ! -s "${OUTPUT_DIR}/main-window.png" ]; then
        cp "${main_screenshot}" "${OUTPUT_DIR}/main-window.png"
        cp "${menu_screenshot}" "${OUTPUT_DIR}/menu-bar-popover.png"
        cp "${desktop_screenshot}" "${OUTPUT_DIR}/desktop.png"
        cp "${windows_file}" "${OUTPUT_DIR}/windows.txt"
        cp "${panel_bounds_file}" "${OUTPUT_DIR}/status-panel-bounds.txt"
        cp "${main_window_id_file}" "${OUTPUT_DIR}/main-window-id.txt"
    fi

    kill "${APP_PID}" 2>/dev/null || true
    wait "${APP_PID}" 2>/dev/null || true
    APP_PID=""
    sleep 1
}

capture_focused_signal() {
    local signal="$1"
    local focused_windows_file="${OUTPUT_DIR}/focused-${signal}-windows.txt"
    local focused_window_id_file="${OUTPUT_DIR}/focused-${signal}-window-id.txt"
    local focused_screenshot="${OUTPUT_DIR}/focused-${signal}-window.png"

    rm -f "${focused_windows_file}" "${focused_window_id_file}" "${focused_screenshot}" "${focused_screenshot%.png}-highlight-report.txt"

    pkill -x QuotaRadar 2>/dev/null || true
    sleep 1

    QUOTARADAR_VISUAL_QA_FIXTURES=1 \
    QUOTARADAR_VISUAL_QA_LANGUAGE="zh-Hans" \
    QUOTARADAR_VISUAL_QA_APPEARANCE="light" \
    QUOTARADAR_VISUAL_QA_WINDOW_SIZE="900x600" \
    QUOTARADAR_VISUAL_QA_TRANSPARENCY="0.58" \
    QUOTARADAR_OPEN_MENU_SIGNAL_FOR_AUTOMATION="${signal}" \
    "${APP_EXECUTABLE}" >"${OUTPUT_DIR}/focus-${signal}-app.log" 2>&1 &
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

    if owner == "Quota Radar", name.localizedCaseInsensitiveContains("Quota Radar"), width >= 880, height >= 580 {
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
    assert_main_table_alignment "${focused_screenshot}" "focused-${signal}"
    assert_no_text_occlusion "${focused_screenshot}" "focused-${signal}"

    record_check "focused-${signal}" "menu_to_main_highlight" "passed" "visible account highlight; report=$(basename "${focused_screenshot%.png}-highlight-report.txt")"

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

rm -f "${OUTPUT_DIR}/main-window.png" "${OUTPUT_DIR}/menu-bar-popover.png" "${OUTPUT_DIR}/focused-main-window.png" "${OUTPUT_DIR}/desktop.png"

if [ "${QUOTARADAR_VISUAL_QA_SKIP_REBUILD:-0}" != "1" ]; then
    "${PROJECT_DIR}/install.sh" --bundle-only --rebuild
elif [ ! -x "${APP_EXECUTABLE}" ]; then
    "${PROJECT_DIR}/install.sh" --bundle-only --rebuild
fi

for scenario_entry in "${VISUAL_QA_SCENARIOS[@]}"; do
    IFS='|' read -r scenario language appearance window_size transparency <<<"${scenario_entry}"
    run_scenario "${scenario}" "${language}" "${appearance}" "${window_size}" "${transparency}"
done

assert_file_nonempty "${PANEL_BOUNDS_FILE}" "Visual QA could not find the status-panel window bounds"
assert_file_nonempty "${MAIN_WINDOW_ID_FILE}" "Visual QA could not identify the main settings window"
assert_png_minimum_size "${OUTPUT_DIR}/menu-bar-popover.png" 540 720 "menu-bar popover"

for signal in "${FOCUS_SIGNALS[@]}"; do
    capture_focused_signal "${signal}"
done

write_visual_qa_summary "passed"

echo "Visual QA artifacts:"
echo "  ${OUTPUT_DIR}/windows.txt"
echo "  ${OUTPUT_DIR}/main-window.png"
echo "  ${OUTPUT_DIR}/menu-bar-popover.png"
echo "  ${OUTPUT_DIR}/focused-main-window.png"
for signal in "${FOCUS_SIGNALS[@]}"; do
    echo "  ${OUTPUT_DIR}/focused-${signal}-window.png"
done
echo "  ${OUTPUT_DIR}/desktop.png"
echo "  ${SUMMARY_TEXT_FILE}"
echo "  ${SUMMARY_JSON_FILE}"
