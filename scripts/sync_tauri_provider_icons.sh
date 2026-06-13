#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SWIFT_ICON_DIR="$ROOT_DIR/QuotaRadar/Assets.xcassets/ProviderIcons"
TAURI_ICON_DIR="$ROOT_DIR/apps/desktop-tauri/public/provider-icons"

if [[ "${1:-}" == "--" ]]; then
  shift
fi

MODE="${1:-sync}"

case "$MODE" in
  sync|--sync)
    MODE="sync"
    ;;
  check|--check)
    MODE="check"
    ;;
  *)
    echo "Usage: scripts/sync_tauri_provider_icons.sh [sync|--sync|check|--check]" >&2
    exit 2
    ;;
esac

if [[ ! -d "$SWIFT_ICON_DIR" ]]; then
  echo "Missing Swift provider icon directory: $SWIFT_ICON_DIR" >&2
  exit 1
fi

mkdir -p "$TAURI_ICON_DIR"
shopt -s nullglob

failures=()
copied=0
removed=0

for iconset in "$SWIFT_ICON_DIR"/*.iconset; do
  name="$(basename "$iconset" .iconset)"
  source_icon="$iconset/icon_32x32@2x.png"
  target_icon="$TAURI_ICON_DIR/$name.png"

  if [[ ! -f "$source_icon" ]]; then
    failures+=("missing source icon: $source_icon")
    continue
  fi

  if [[ "$MODE" == "check" ]]; then
    if [[ ! -f "$target_icon" ]]; then
      failures+=("missing Tauri icon: $target_icon")
    elif ! cmp -s "$source_icon" "$target_icon"; then
      failures+=("drifted Tauri icon: $target_icon")
    fi
  elif [[ ! -f "$target_icon" ]] || ! cmp -s "$source_icon" "$target_icon"; then
    cp "$source_icon" "$target_icon"
    copied=$((copied + 1))
  fi
done

for target_icon in "$TAURI_ICON_DIR"/*.png; do
  name="$(basename "$target_icon" .png)"
  source_icon="$SWIFT_ICON_DIR/$name.iconset/icon_32x32@2x.png"

  if [[ -f "$source_icon" ]]; then
    continue
  fi

  if [[ "$MODE" == "check" ]]; then
    failures+=("extra Tauri icon: $target_icon")
  else
    rm "$target_icon"
    removed=$((removed + 1))
  fi
done

if [[ ${#failures[@]} -gt 0 ]]; then
  printf '%s\n' "${failures[@]}" >&2
  echo "Run scripts/sync_tauri_provider_icons.sh to sync provider icons." >&2
  exit 1
fi

if [[ "$MODE" == "check" ]]; then
  echo "Tauri provider icons are in sync."
else
  echo "Synced Tauri provider icons: copied=$copied removed=$removed"
fi
