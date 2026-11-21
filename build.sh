#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_PATH="$ROOT_DIR/Morrow.xcodeproj"
SCHEME="Morrow"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/.build}"
DESTINATION="${DESTINATION:-generic/platform=macOS}"

if ! xcodebuild -version >/dev/null 2>&1; then
    for candidate in \
        /Applications/Xcode.app/Contents/Developer \
        /Applications/Xcode-*.app/Contents/Developer \
        "$HOME"/Applications/Xcode*.app/Contents/Developer; do
        if [[ -x "$candidate/usr/bin/xcodebuild" ]]; then
            export DEVELOPER_DIR="$candidate"
            break
        fi
    done
fi

if [[ -n "${DEVELOPER_DIR:-}" && -x "$DEVELOPER_DIR/usr/bin/xcodebuild" ]]; then
    XCODEBUILD="$DEVELOPER_DIR/usr/bin/xcodebuild"
else
    XCODEBUILD="$(command -v xcodebuild || true)"
fi

if [[ -z "$XCODEBUILD" ]] || ! "$XCODEBUILD" -version >/dev/null 2>&1; then
    echo "Error: A full Xcode installation is required to build Morrow." >&2
    echo "Install Xcode, or set DEVELOPER_DIR to its Contents/Developer directory." >&2
    exit 1
fi

if [[ ! -d "$PROJECT_PATH" ]]; then
    echo "Error: Could not find Morrow.xcodeproj next to this script." >&2
    exit 1
fi

"$XCODEBUILD" \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    "$@" \
    CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-YES}" \
    build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/Morrow.app"
DMG_PATH="$ROOT_DIR/Morrow.dmg"
DMG_STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/Morrow-dmg.XXXXXX")"
trap 'rm -rf "$DMG_STAGING_DIR"' EXIT

ditto "$APP_PATH" "$DMG_STAGING_DIR/Morrow.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"
hdiutil create \
    -volname "Morrow" \
    -srcfolder "$DMG_STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_STAGING_DIR"
trap - EXIT

echo "Built app: $APP_PATH"
echo "Built disk image: $DMG_PATH"
