#!/bin/bash

# Build and install Quota Radar.
# Run: ./install.sh to install the existing build/Quota Radar.app when present.
# Run: ./install.sh --rebuild to rebuild and install.
# Run: ./install.sh --bundle-only --rebuild to create build/Quota Radar.app without copying to /Applications.
# Run: ./install.sh --bundle-only --rebuild --white-label to build without GitHub Release updater URLs.

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PRODUCT_NAME="QuotaRadar"
DISPLAY_NAME="Quota Radar"
SOURCE_DIR="QuotaRadar"
BUILD_DIR="${PROJECT_DIR}/build"
RESOURCE_BUNDLE_NAME="${PRODUCT_NAME}_${PRODUCT_NAME}.bundle"
BUNDLE_ONLY=false
REBUILD=false
WHITE_LABEL=false

for arg in "$@"; do
    case "$arg" in
        --bundle-only)
            BUNDLE_ONLY=true
            ;;
        --rebuild)
            REBUILD=true
            ;;
        --white-label)
            WHITE_LABEL=true
            ;;
        *)
            echo "❌ Unknown option: $arg"
            echo "Usage: ./install.sh [--bundle-only] [--rebuild] [--white-label]"
            exit 1
            ;;
    esac
done

if [ "${QUOTARADAR_WHITE_LABEL:-0}" = "1" ]; then
    WHITE_LABEL=true
fi

if [ "${WHITE_LABEL}" = true ]; then
    REBUILD=true
fi

APP_BUNDLE="${BUILD_DIR}/${DISPLAY_NAME}.app"

if [ -d "${APP_BUNDLE}" ] && [ "${REBUILD}" = false ]; then
    if [ -x "${APP_BUNDLE}/Contents/MacOS/${PRODUCT_NAME}" ] && [ -d "${APP_BUNDLE}/Contents/Resources/${RESOURCE_BUNDLE_NAME}" ]; then
        echo "📦 Using existing app bundle: ${APP_BUNDLE}"
    else
        echo "⚠️ Existing app bundle is incomplete; rebuilding ${DISPLAY_NAME}..."
        REBUILD=true
    fi
else
    echo "🚀 Building ${DISPLAY_NAME}..."
    REBUILD=true
fi

echo "📁 Project: ${PROJECT_DIR}"
if [ "${WHITE_LABEL}" = true ]; then
    echo "🏷️  Build mode: white-label, GitHub Release updater disabled"
fi

# Create build directory
mkdir -p "${BUILD_DIR}"

if [ "${REBUILD}" = true ]; then
    # Check for Xcode
    if ! command -v xcodebuild &> /dev/null; then
        echo "❌ Xcode not found. Please install Xcode from the App Store."
        exit 1
    fi

    # Build the app
    echo "🔨 Building Release version..."
    cd "${PROJECT_DIR}"

    SWIFT_BUILD_ARGS=(-c release)
    SWIFT_SCRATCH_PATH="${PROJECT_DIR}/.build"
    if [ "${WHITE_LABEL}" = true ]; then
        SWIFT_SCRATCH_PATH="${PROJECT_DIR}/.build-white-label"
        SWIFT_BUILD_ARGS+=(--scratch-path "${SWIFT_SCRATCH_PATH}" -Xswiftc -DQUOTARADAR_DISABLE_GITHUB_UPDATER)
    fi

    # Use swift package manager to build
    swift build "${SWIFT_BUILD_ARGS[@]}" 2>&1 | tee "${BUILD_DIR}/build.log" || {
        echo "❌ Build failed. Check ${BUILD_DIR}/build.log"
        exit 1
    }

    # Find the built executable
    EXECUTABLE="${SWIFT_SCRATCH_PATH}/release/${PRODUCT_NAME}"

    if [ ! -f "${EXECUTABLE}" ]; then
        echo "❌ Executable not found at ${EXECUTABLE}"
        echo "🔍 Searching for executable..."
        find "${SWIFT_SCRATCH_PATH}" -name "${PRODUCT_NAME}" -type f 2>/dev/null | head -5
        exit 1
    fi

    echo "✅ Build successful!"
    echo "📦 Creating App Bundle..."

    # Create app bundle structure
    CONTENTS="${APP_BUNDLE}/Contents"
    MACOS="${CONTENTS}/MacOS"
    RESOURCES="${CONTENTS}/Resources"

    rm -rf "${APP_BUNDLE}"
    mkdir -p "${MACOS}" "${RESOURCES}"

    # Copy executable
    cp "${EXECUTABLE}" "${MACOS}/${PRODUCT_NAME}"

    # Copy resources
    cp "${PROJECT_DIR}/${SOURCE_DIR}/Info.plist" "${CONTENTS}/Info.plist"
    cp "${PROJECT_DIR}/${SOURCE_DIR}/QuotaRadar.entitlements" "${RESOURCES}/" 2>/dev/null || true
    cp "${PROJECT_DIR}/${SOURCE_DIR}/Resources/QuotaRadar.icns" "${RESOURCES}/QuotaRadar.icns"

    RESOURCE_BUNDLE="${SWIFT_SCRATCH_PATH}/release/${RESOURCE_BUNDLE_NAME}"
    if [ -d "${RESOURCE_BUNDLE}" ]; then
        cp -R "${RESOURCE_BUNDLE}" "${RESOURCES}/"
    else
        echo "❌ Resource bundle not found at ${RESOURCE_BUNDLE}"
        exit 1
    fi

    # Create PkgInfo
    echo "APPL????" > "${CONTENTS}/PkgInfo"

    if command -v codesign &> /dev/null; then
        echo "🔏 Ad-hoc signing app bundle..."
        codesign --force --deep --sign - "${APP_BUNDLE}" >/dev/null
    fi
fi

if command -v xattr &> /dev/null; then
    echo "🧹 Clearing quarantine attributes..."
    xattr -dr com.apple.quarantine "${APP_BUNDLE}" 2>/dev/null || true
fi

echo "📝 App Bundle Info:"
echo "   Location: ${APP_BUNDLE}"
echo "   Executable: ${APP_BUNDLE}/Contents/MacOS/${PRODUCT_NAME}"
echo "   Size: $(du -sh "${APP_BUNDLE}" | cut -f1)"

if [ "${BUNDLE_ONLY}" = true ]; then
    echo "✅ Bundle created at ${APP_BUNDLE}"
    exit 0
fi

# Install to Applications
for old_app in "/Applications/${DISPLAY_NAME}.app" "/Applications/QuotaRadar.app" "/Applications/QuotaBar.app"; do
if [ -d "${old_app}" ]; then
    echo "🗑️  Removing old version..."
    rm -rf "${old_app}"
fi
done

echo "📲 Installing to Applications..."
cp -R "${APP_BUNDLE}" "/Applications/"
if command -v xattr &> /dev/null; then
    xattr -dr com.apple.quarantine "/Applications/${DISPLAY_NAME}.app" 2>/dev/null || true
fi

if command -v spctl &> /dev/null; then
    echo "✅ Registering local Gatekeeper approval..."
    spctl --add --label "${DISPLAY_NAME}" "/Applications/${DISPLAY_NAME}.app" 2>/dev/null || true
fi

if [ -d "/Applications/${DISPLAY_NAME}.app" ]; then
    echo "✅ Installation successful!"
    echo ""
    echo "🎉 ${DISPLAY_NAME} is now installed in Applications"
    echo ""
    echo "To run:"
    echo "  1. Open Applications folder (Cmd+Shift+A in Finder)"
    echo "  open '/Applications/${DISPLAY_NAME}.app'"
    echo ""
    echo "The app will appear in your menu bar with the adaptive quota-radar icon"
else
    echo "❌ Installation failed"
    exit 1
fi
