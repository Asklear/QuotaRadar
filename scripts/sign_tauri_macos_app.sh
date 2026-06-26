#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEFAULT_APP_PATH="$ROOT_DIR/apps/desktop-tauri/src-tauri/target/release/bundle/macos/Quota Radar Tauri Preview.app"
APP_PATH="${1:-$DEFAULT_APP_PATH}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Tauri macOS signing is only available on macOS." >&2
  exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Tauri app bundle not found: $APP_PATH" >&2
  echo "Run: cd apps/desktop-tauri && pnpm tauri build --bundles app" >&2
  exit 1
fi

codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"
echo "Signed and verified: $APP_PATH"
