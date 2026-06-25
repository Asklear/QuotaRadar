#!/usr/bin/env bash
set -euo pipefail

# Live acceptance runner for saved Quota Radar credentials.
# No secrets, cookies, tokens, or raw provider responses are printed.
#
# Dry run, no provider requests:
#   scripts/live_acceptance.sh
#
# Real provider checks, explicit opt-in required:
#   QUOTARADAR_LIVE_ACCEPTANCE=1 scripts/live_acceptance.sh --live

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR=""
TARGET_DIR=""

cleanup() {
  if [[ -n "${WORK_DIR}" ]]; then
    rm -rf "${WORK_DIR}"
  fi
}
trap cleanup EXIT

LIVE=false
PASSTHROUGH_ARGS=()

usage() {
  cat <<'USAGE'
Usage: scripts/live_acceptance.sh [--live] [--json] [--provider PROVIDER]

Runs a sanitized acceptance matrix for saved web-login providers.

Without --live, the command only reports which dashboard-login providers have
saved active credentials. It does not hit provider endpoints.

With --live, provider quota endpoints are called. This requires:
  QUOTARADAR_LIVE_ACCEPTANCE=1 scripts/live_acceptance.sh --live

No secrets, cookies, tokens, or raw provider responses are printed.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --live)
      LIVE=true
      PASSTHROUGH_ARGS+=("$1")
      shift
      ;;
    --json)
      PASSTHROUGH_ARGS+=("$1")
      shift
      ;;
    --provider)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --provider" >&2
        exit 2
      fi
      PASSTHROUGH_ARGS+=("$1" "$2")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "${LIVE}" == true && "${QUOTARADAR_LIVE_ACCEPTANCE:-0}" != "1" ]]; then
  echo "Refusing to run live provider checks without QUOTARADAR_LIVE_ACCEPTANCE=1." >&2
  exit 2
fi

mkdir -p "${ROOT_DIR}/build"
WORK_DIR="$(mktemp -d "${ROOT_DIR}/build/live-acceptance-src.XXXXXX")"
TARGET_DIR="${WORK_DIR}/Sources/QuotaRadarLiveAcceptance"
mkdir -p "${TARGET_DIR}"

cat > "${WORK_DIR}/Package.swift" <<'SWIFT'
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "QuotaRadarLiveAcceptance",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "QuotaRadarLiveAcceptance", targets: ["QuotaRadarLiveAcceptance"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(name: "QuotaRadarLiveAcceptance", path: "Sources/QuotaRadarLiveAcceptance")
    ]
)
SWIFT

cp "${ROOT_DIR}"/QuotaRadar/Models/*.swift "${TARGET_DIR}/"
cp "${ROOT_DIR}"/QuotaRadar/Services/*.swift "${TARGET_DIR}/"
cp "${ROOT_DIR}/scripts/live_acceptance_main.swift" "${TARGET_DIR}/LiveAcceptanceMain.swift"

# QuotaRadarApp.swift is intentionally not copied. It contains the SwiftUI @main
# app entry; this temporary target owns its own CLI entry point.

if [[ ${#PASSTHROUGH_ARGS[@]} -gt 0 ]]; then
  swift run --package-path "${WORK_DIR}" -c release QuotaRadarLiveAcceptance "${PASSTHROUGH_ARGS[@]}"
else
  swift run --package-path "${WORK_DIR}" -c release QuotaRadarLiveAcceptance
fi
