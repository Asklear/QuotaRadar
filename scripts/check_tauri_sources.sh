#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    echo "::error::$1" >&2
  fi
  echo "FAIL: $1" >&2
  exit 1
}

trap 'code=$?; if [[ $code -ne 0 && "${GITHUB_ACTIONS:-}" == "true" ]]; then echo "::error::Tauri source safety script exited with code $code near line $LINENO" >&2; fi' ERR

if command -v python3 >/dev/null 2>&1; then
  PYTHON_CMD=(python3)
elif command -v python >/dev/null 2>&1; then
  PYTHON_CMD=(python)
elif command -v py >/dev/null 2>&1; then
  PYTHON_CMD=(py -3)
else
  fail "Python 3 is required for Tauri source safety checks"
fi

if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  echo "::notice::Tauri source safety preflight: pwd=$PWD python=${PYTHON_CMD[*]} rg=$(command -v rg || echo missing)"
fi

assert_no_match() {
  local pattern="$1"
  local message="$2"
  shift 2

  if command -v rg >/dev/null 2>&1; then
    rg -n --hidden \
      --glob '!apps/desktop-tauri/dist/**' \
      --glob '!apps/desktop-tauri/node_modules/**' \
      --glob '!apps/desktop-tauri/src-tauri/target/**' \
      --glob '!apps/desktop-tauri/src-tauri/gen/**' \
      --glob '!apps/desktop-tauri/tests/e2e/screenshots/**' \
      --glob '!apps/desktop-tauri/tests/e2e/artifacts/**' \
      "$pattern" "$@" >/tmp/quotaradar-tauri-source-match.txt || true
  else
    "${PYTHON_CMD[@]}" - "$pattern" "$@" >/tmp/quotaradar-tauri-source-match.txt <<'PY'
import re
import sys
from pathlib import Path

pattern = re.compile(sys.argv[1])
paths = [Path(arg) for arg in sys.argv[2:]]
excluded_prefixes = tuple(Path(path) for path in (
    "apps/desktop-tauri/dist",
    "apps/desktop-tauri/node_modules",
    "apps/desktop-tauri/src-tauri/target",
    "apps/desktop-tauri/src-tauri/gen",
    "apps/desktop-tauri/tests/e2e/screenshots",
    "apps/desktop-tauri/tests/e2e/artifacts",
))

def is_excluded(path: Path) -> bool:
    parts = path.parts
    return any(parts[:len(prefix.parts)] == prefix.parts for prefix in excluded_prefixes)

def iter_files(path: Path):
    if not path.exists() or is_excluded(path):
        return
    if path.is_file():
        yield path
        return
    for child in path.rglob("*"):
        if child.is_file() and not is_excluded(child):
            yield child

for root in paths:
    for file_path in iter_files(root):
        try:
            lines = file_path.read_text(encoding="utf-8", errors="ignore").splitlines()
        except OSError:
            continue
        for line_number, line in enumerate(lines, 1):
            if pattern.search(line):
                print(f"{file_path}:{line_number}:{line}")
PY
  fi

  if [[ -s /tmp/quotaradar-tauri-source-match.txt ]]; then
    cat /tmp/quotaradar-tauri-source-match.txt >&2
    fail "$message"
  fi
}

assert_match() {
  local pattern="$1"
  local path="$2"
  local message="$3"

  if command -v rg >/dev/null 2>&1; then
    rg -n -- "$pattern" "$path" >/tmp/quotaradar-tauri-source-match.txt || true
  else
    "${PYTHON_CMD[@]}" - "$pattern" "$path" >/tmp/quotaradar-tauri-source-match.txt <<'PY'
import re
import sys
from pathlib import Path

pattern = re.compile(sys.argv[1])
path = Path(sys.argv[2])
if path.exists():
    try:
        for line_number, line in enumerate(path.read_text(encoding="utf-8", errors="ignore").splitlines(), 1):
            if pattern.search(line):
                print(f"{path}:{line_number}:{line}")
    except OSError:
        pass
PY
  fi

  if [[ ! -s /tmp/quotaradar-tauri-source-match.txt ]]; then
    fail "$message"
  fi
}

TAURI_SOURCE_PATHS=(
  "apps/desktop-tauri/src"
  "apps/desktop-tauri/tests"
  "apps/desktop-tauri/src-tauri/src"
  "apps/desktop-tauri/src-tauri/capabilities"
  "apps/desktop-tauri/src-tauri/tauri.conf.json"
  "apps/desktop-tauri/index.html"
  "apps/desktop-tauri/package.json"
  "apps/desktop-tauri/playwright.config.ts"
  "docs/desktop-tauri-ui-spec.md"
  "docs/desktop-tauri-implementation-plan.md"
  "docs/desktop-tauri-parity-checklist.md"
  "docs/tauri-provider-migration-checklist.md"
  "docs/provider-capabilities.md"
  "docs/provider-capabilities.en.md"
)

echo "== Tauri source safety =="
assert_no_match \
  'sk-(ant|proj|live|test)[A-Za-z0-9_-]{12,}|Bearer [A-Za-z0-9._-]{20,}|kimi-auth=|osduss=|passOsRefreshTk=|X-Subscription-Token: [A-Za-z0-9]{12,}|api[_-]?key[:=][A-Za-z0-9_-]{12,}|cookie[:=][A-Za-z0-9._%+-]{20,}' \
  "Tauri sources must not contain real-looking API keys, cookies, or bearer tokens" \
  "${TAURI_SOURCE_PATHS[@]}"

assert_no_match \
  'curl .*-H .*(Authorization|Cookie)|curl .* -b ' \
  "Tauri sources must not contain copied cURL commands with authorization material" \
  "${TAURI_SOURCE_PATHS[@]}"

assert_no_match \
  '\b(describe|it|test)\.(only|skip)\b' \
  "Tauri tests must not leave focused or skipped tests behind" \
  "apps/desktop-tauri/tests" \
  "apps/desktop-tauri/src"

assert_no_match \
  'placeholder=.*Tavily|default(Name|Value).*Tavily|Tavily_api_key|provider_api_key|PROVIDER_API_KEY' \
  "Tauri credential UI must not leak generic provider placeholder names" \
  "apps/desktop-tauri/src" \
  "apps/desktop-tauri/src-tauri/src"

assert_match 'dashboard_authorization_is_not_copyable' \
  "apps/desktop-tauri/src-tauri/src/storage/secret_store_tests.rs" \
  "Tauri secret-store tests must assert dashboard authorization is not copyable"

"${PYTHON_CMD[@]}" - <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path("apps/desktop-tauri")
locale_dir = root / "src" / "i18n" / "locales"
english = json.loads((locale_dir / "en.json").read_text(encoding="utf-8"))
english_keys = set(english)

for locale_file in sorted(locale_dir.glob("*.json")):
    messages = json.loads(locale_file.read_text(encoding="utf-8"))
    keys = set(messages)
    missing = sorted(english_keys - keys)
    extra = sorted(keys - english_keys)
    if missing or extra:
        print(f"{locale_file}: missing={missing} extra={extra}", file=sys.stderr)
        sys.exit("FAIL: Tauri locale files must have the same keys as en.json")
    for key, value in messages.items():
        if not isinstance(value, str) or not value.strip():
            print(f"{locale_file}:{key} has an empty or non-string value", file=sys.stderr)
            sys.exit("FAIL: Tauri locale values must be non-empty strings")
        if any(marker in value for marker in ("TODO", "__MISSING__", "MISSING_TRANSLATION")):
            print(f"{locale_file}:{key} contains an unfinished translation marker", file=sys.stderr)
            sys.exit("FAIL: Tauri locale values must not contain missing-translation markers")

scan_files = [
    *Path("apps/desktop-tauri/src").rglob("*.ts"),
    *Path("apps/desktop-tauri/src").rglob("*.tsx"),
    *Path("apps/desktop-tauri/src-tauri/src").rglob("*.rs"),
    *Path("apps/desktop-tauri/tests").rglob("*.ts"),
    *Path("apps/desktop-tauri/tests").rglob("*.tsx"),
]

dashboard_copyable_patterns = [
    re.compile(r"CredentialKind::DashboardCookie\s*=>\s*true"),
    re.compile(r"kind:\s*CredentialKind::DashboardCookie(?:(?!kind:).){0,500}copyable:\s*true", re.S),
    re.compile(r'kind:\s*"dashboardCookie"(?:(?!kind:).){0,500}copyable:\s*true', re.S),
    re.compile(r'"kind"\s*:\s*"dashboardCookie"(?:(?!"kind").){0,500}"copyable"\s*:\s*true', re.S),
]

for path in scan_files:
    text = path.read_text(encoding="utf-8", errors="ignore")
    for pattern in dashboard_copyable_patterns:
        if pattern.search(text):
            print(path, file=sys.stderr)
            sys.exit("FAIL: Dashboard/web-login authorization credentials must never be copyable")
PY

"${PYTHON_CMD[@]}" - <<'PY'
import json
import sys
from pathlib import Path

config = json.loads(Path("apps/desktop-tauri/src-tauri/tauri.conf.json").read_text(encoding="utf-8"))
if config.get("productName") != "Quota Radar Tauri Preview":
    sys.exit("FAIL: Tauri preview app must not share the stable Swift app product name")
if config.get("identifier") == "com.gaorongvc.quotaradar":
    sys.exit("FAIL: Tauri preview app must not share the stable Swift app bundle identifier")
main_rs = Path("apps/desktop-tauri/src-tauri/src/main.rs").read_text(encoding="utf-8")
if 'windows_subsystem = "windows"' not in main_rs:
    sys.exit("FAIL: Tauri Windows release binary must use the windows GUI subsystem")
cargo_toml = Path("apps/desktop-tauri/src-tauri/Cargo.toml").read_text(encoding="utf-8")
if 'custom-protocol = ["tauri/custom-protocol"]' not in cargo_toml:
    sys.exit("FAIL: Tauri Cargo.toml must map the custom-protocol feature for production builds")
windows = config.get("app", {}).get("windows", [])
main_window = next((window for window in windows if window.get("label") == "main"), None)
if not main_window or main_window.get("title") != "Quota Radar Tauri Preview":
    sys.exit("FAIL: Tauri preview main window title must distinguish it from the Swift app")

workflow = Path(".github/workflows/desktop-tauri.yml")
if not workflow.exists():
    sys.exit("FAIL: Tauri desktop workflow is required")
workflow_text = workflow.read_text(encoding="utf-8")
for required in (
    "workflow_dispatch:",
    "paths:",
    "apps/desktop-tauri/**",
    "QuotaRadar/Assets.xcassets/ProviderIcons/**",
    "pnpm tauri build --bundles app --ci",
    "pnpm tauri build --bundles nsis --ci",
    "pnpm tauri build --bundles deb --ci",
    "SODIUM_DIST_DIR",
    "LATEST.tar.gz",
    "LATEST.tar.gz.minisig",
    "libsodium-1.0.22-stable-msvc.zip",
    "libsodium-1.0.22-stable-msvc.zip.minisig",
    "actions/upload-artifact@",
    "if-no-files-found: error",
    "retention-days:",
    "scripts/check_tauri_sources.sh",
    "scripts/run_tauri_cargo_tests.sh",
):
    if required not in workflow_text:
        sys.exit(f"FAIL: Tauri desktop workflow must include guarded trigger entry: {required}")

gitignore = Path(".gitignore").read_text(encoding="utf-8")
if "apps/desktop-tauri/artifacts/" not in gitignore:
    sys.exit("FAIL: Tauri CI artifact staging directory must be ignored")

bundle = config.get("bundle", {})
if bundle.get("targets") != "all":
    sys.exit("FAIL: Tauri bundle targets must be 'all' so each OS builds its native package set")

icons = set(bundle.get("icon", []))
required_icons = {"icons/icon.png", "icons/icon.icns", "icons/icon.ico"}
missing_icons = sorted(required_icons - icons)
if missing_icons:
    sys.exit(f"FAIL: Tauri bundle config is missing icon paths: {missing_icons}")

updater = config.get("plugins", {}).get("updater", {})
if updater.get("endpoints") or updater.get("pubkey"):
    sys.exit("FAIL: Tauri preview must not enable signed updater endpoints until release signing is configured")

release_doc = Path("docs/desktop-tauri-release.md")
if not release_doc.exists():
    sys.exit("FAIL: Tauri desktop release documentation is required")
release_text = release_doc.read_text(encoding="utf-8")
for required in ("Unsigned preview boundary", "GitHub Release asset names", "Platform package targets"):
    if required not in release_text:
        sys.exit(f"FAIL: Tauri release docs must document {required}")

sign_script = Path("scripts/sign_tauri_macos_app.sh")
if not sign_script.exists():
    sys.exit("FAIL: Tauri local macOS ad-hoc signing script is required")

qa_script = Path("scripts/qa_tauri_macos_screenshots.sh")
if not qa_script.exists():
    sys.exit("FAIL: Tauri macOS screenshot QA script is required")

icon_sync_script = Path("scripts/sync_tauri_provider_icons.sh")
if not icon_sync_script.exists():
    sys.exit("FAIL: Tauri provider icon sync script is required")

swift_icon_root = Path("QuotaRadar/Assets.xcassets/ProviderIcons")
tauri_icon_root = Path("apps/desktop-tauri/public/provider-icons")
swift_icons = {
    icon_path.parent.stem: icon_path
    for icon_path in swift_icon_root.glob("*.iconset/icon_32x32@2x.png")
}
tauri_icons = {icon_path.stem: icon_path for icon_path in tauri_icon_root.glob("*.png")}
missing_tauri_icons = sorted(set(swift_icons) - set(tauri_icons))
extra_tauri_icons = sorted(set(tauri_icons) - set(swift_icons))
if missing_tauri_icons or extra_tauri_icons:
    sys.exit(
        "FAIL: Tauri provider icons must match Swift provider iconsets; "
        f"missing={missing_tauri_icons} extra={extra_tauri_icons}"
    )

drifted_icons = sorted(
    name
    for name, swift_path in swift_icons.items()
    if tauri_icons[name].read_bytes() != swift_path.read_bytes()
)
if drifted_icons:
    sys.exit(
        "FAIL: Tauri provider icons are out of sync with Swift assets; "
        f"run scripts/sync_tauri_provider_icons.sh. drifted={drifted_icons}"
    )

package_json = json.loads(Path("apps/desktop-tauri/package.json").read_text(encoding="utf-8"))
scripts = package_json.get("scripts", {})
if "sign:mac" not in scripts:
    sys.exit("FAIL: Tauri package.json must expose a sign:mac command")
if scripts.get("sync:provider-icons") != "../../scripts/sync_tauri_provider_icons.sh":
    sys.exit("FAIL: Tauri package.json must expose sync:provider-icons for provider icon sync")

for required in ("scripts/sign_tauri_macos_app.sh", "codesign --verify --deep --strict"):
    if required not in release_text:
        sys.exit(f"FAIL: Tauri release docs must document local signing step: {required}")

parity_doc = Path("docs/desktop-tauri-parity-checklist.md")
parity_text = parity_doc.read_text(encoding="utf-8")
for required in ("scripts/qa_tauri_macos_screenshots.sh", "/tmp/quotaradar-tauri-qa", "Dark mode"):
    if required not in parity_text:
        sys.exit(f"FAIL: Tauri parity checklist must document screenshot QA coverage: {required}")
PY

echo "== Tauri source safety passed =="
