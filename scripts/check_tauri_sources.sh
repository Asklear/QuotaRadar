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
PY

echo "== Tauri source safety passed =="
