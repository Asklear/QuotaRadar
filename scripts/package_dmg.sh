#!/bin/bash

# Build a Quota Radar DMG.
#
# Local/self-use:
#   scripts/package_dmg.sh
#
# White-label/no-updater distribution:
#   scripts/package_dmg.sh --rebuild --white-label
#
# Developer ID distribution:
#   DEVELOPER_ID_APPLICATION="Developer ID Application: Example (TEAMID)" \
#   NOTARYTOOL_PROFILE="notary-profile" \
#   scripts/package_dmg.sh --rebuild --notarize
#
# Or provide Apple ID credentials:
#   DEVELOPER_ID_APPLICATION="Developer ID Application: Example (TEAMID)" \
#   NOTARYTOOL_APPLE_ID="you@example.com" \
#   NOTARYTOOL_TEAM_ID="TEAMID" \
#   NOTARYTOOL_PASSWORD="@keychain:AC_PASSWORD" \
#   scripts/package_dmg.sh --notarize

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT_NAME="QuotaRadar"
DISPLAY_NAME="Quota Radar"
SOURCE_DIR="QuotaRadar"
BUILD_DIR="${PROJECT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/${DISPLAY_NAME}.app"
DMG_DIR="${BUILD_DIR}/dmg"
DMG_PATH="${BUILD_DIR}/${PRODUCT_NAME}.dmg"
VOLUME_NAME="${DISPLAY_NAME}"
REBUILD=false
NOTARIZE=false
WHITE_LABEL=false

for arg in "$@"; do
    case "$arg" in
        --rebuild)
            REBUILD=true
            ;;
        --notarize)
            NOTARIZE=true
            ;;
        --white-label)
            WHITE_LABEL=true
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Usage: scripts/package_dmg.sh [--rebuild] [--notarize] [--white-label]"
            exit 1
            ;;
    esac
done

if [ "${QUOTARADAR_WHITE_LABEL:-0}" = "1" ]; then
    WHITE_LABEL=true
fi

if [ "${WHITE_LABEL}" = true ]; then
    REBUILD=true
    DMG_PATH="${BUILD_DIR}/QuotaRadar-WhiteLabel.dmg"
fi

INSTALL_ARGS=(--bundle-only)
if [ "${REBUILD}" = true ] || [ ! -d "${APP_BUNDLE}" ]; then
    INSTALL_ARGS+=(--rebuild)
fi
if [ "${WHITE_LABEL}" = true ]; then
    INSTALL_ARGS+=(--white-label)
fi
"${PROJECT_DIR}/install.sh" "${INSTALL_ARGS[@]}"

if [ -n "${DEVELOPER_ID_APPLICATION:-}" ]; then
    echo "Signing app with Developer ID: ${DEVELOPER_ID_APPLICATION}"
    codesign --force --deep --options runtime \
        --entitlements "${PROJECT_DIR}/${SOURCE_DIR}/${PRODUCT_NAME}.entitlements" \
        --sign "${DEVELOPER_ID_APPLICATION}" \
        "${APP_BUNDLE}"
else
    echo "Using ad-hoc signed app for local DMG."
    if command -v xattr >/dev/null 2>&1; then
        xattr -dr com.apple.quarantine "${APP_BUNDLE}" 2>/dev/null || true
    fi
fi

rm -rf "${DMG_DIR}" "${DMG_PATH}"
mkdir -p "${DMG_DIR}"
cp -R "${APP_BUNDLE}" "${DMG_DIR}/"
ln -s /Applications "${DMG_DIR}/Applications"

hdiutil create \
    -volname "${VOLUME_NAME}" \
    -srcfolder "${DMG_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"

if [ -n "${DEVELOPER_ID_APPLICATION:-}" ]; then
    echo "Signing DMG..."
    codesign --force --sign "${DEVELOPER_ID_APPLICATION}" "${DMG_PATH}"
fi

if [ "${NOTARIZE}" = true ]; then
    if [ -z "${DEVELOPER_ID_APPLICATION:-}" ]; then
        echo "--notarize requires DEVELOPER_ID_APPLICATION."
        exit 1
    fi

    echo "Submitting DMG for notarization..."
    if [ -n "${NOTARYTOOL_PROFILE:-}" ]; then
        xcrun notarytool submit "${DMG_PATH}" \
            --keychain-profile "${NOTARYTOOL_PROFILE}" \
            --wait
    else
        : "${NOTARYTOOL_APPLE_ID:?Set NOTARYTOOL_APPLE_ID or NOTARYTOOL_PROFILE}"
        : "${NOTARYTOOL_TEAM_ID:?Set NOTARYTOOL_TEAM_ID or NOTARYTOOL_PROFILE}"
        : "${NOTARYTOOL_PASSWORD:?Set NOTARYTOOL_PASSWORD or NOTARYTOOL_PROFILE}"
        xcrun notarytool submit "${DMG_PATH}" \
            --apple-id "${NOTARYTOOL_APPLE_ID}" \
            --team-id "${NOTARYTOOL_TEAM_ID}" \
            --password "${NOTARYTOOL_PASSWORD}" \
            --wait
    fi

    xcrun stapler staple "${DMG_PATH}"
fi

codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}"
echo "DMG created: ${DMG_PATH}"
