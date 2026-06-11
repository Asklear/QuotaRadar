#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_no_match() {
  local pattern="$1"
  local message="$2"
  shift 2
  if rg -n --hidden \
    --glob '!apps/desktop-tauri/dist/**' \
    --glob '!apps/desktop-tauri/node_modules/**' \
    --glob '!apps/desktop-tauri/src-tauri/target/**' \
    --glob '!apps/desktop-tauri/src-tauri/gen/**' \
    --glob '!apps/desktop-tauri/tests/e2e/screenshots/**' \
    --glob '!apps/desktop-tauri/tests/e2e/artifacts/**' \
    "$pattern" "$@" >/tmp/quotaradar-tauri-source-match.txt; then
    cat /tmp/quotaradar-tauri-source-match.txt >&2
    fail "$message"
  fi
}

assert_match() {
  local pattern="$1"
  local path="$2"
  local message="$3"
  if ! rg -n -- "$pattern" "$path" >/dev/null; then
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

python3 - <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path("apps/desktop-tauri")
locale_dir = root / "src" / "i18n" / "locales"
english = json.loads((locale_dir / "en.json").read_text())
english_keys = set(english)

for locale_file in sorted(locale_dir.glob("*.json")):
    messages = json.loads(locale_file.read_text())
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
    text = path.read_text(errors="ignore")
    for pattern in dashboard_copyable_patterns:
        if pattern.search(text):
            print(path, file=sys.stderr)
            sys.exit("FAIL: Dashboard/web-login authorization credentials must never be copyable")
PY

echo "== Tauri source safety passed =="
