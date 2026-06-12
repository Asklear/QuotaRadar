#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/apps/desktop-tauri"
LOG_FILE="${RUNNER_TEMP:-/tmp}/quotaradar-tauri-cargo-test.log"

cd "$APP_DIR"

set +e
cargo test --manifest-path src-tauri/Cargo.toml 2>&1 | tee "$LOG_FILE"
status=${PIPESTATUS[0]}
set -e

if [[ "$status" -ne 0 && "${GITHUB_ACTIONS:-}" == "true" ]]; then
  summary="$(grep -E 'FAILED|failures:|---- |panicked at|assertion|error:' "$LOG_FILE" | tail -n 30 | tr '\n' ' ')"
  if [[ -z "$summary" ]]; then
    summary="$(tail -n 30 "$LOG_FILE" | tr '\n' ' ')"
  fi
  summary="${summary//'%'/'%25'}"
  summary="${summary//$'\r'/'%0D'}"
  summary="${summary//$'\n'/'%0A'}"
  echo "::error::Cargo tests failed on ${RUNNER_OS:-unknown}: $summary" >&2
fi

exit "$status"
