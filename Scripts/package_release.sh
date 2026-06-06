#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

read_app_info_value() {
  local key="$1"
  sed -nE "s/^[[:space:]]*public static let ${key} = \"([^\"]+)\".*/\\1/p" Sources/OpenMarkedCore/AppInfo.swift | head -n 1
}

VERSION="${OPENMARKED_VERSION:-$(read_app_info_value version)}"
BUILD="${OPENMARKED_BUILD:-$(read_app_info_value build)}"
BUNDLE_IDENTIFIER="${OPENMARKED_BUNDLE_IDENTIFIER:-$(read_app_info_value bundleIdentifier)}"
MINIMUM_MACOS="${OPENMARKED_MINIMUM_MACOS:-$(read_app_info_value minimumMacOSVersion)}"

if [[ -z "$VERSION" || -z "$BUILD" || -z "$BUNDLE_IDENTIFIER" || -z "$MINIMUM_MACOS" ]]; then
  echo "Could not read release metadata from AppInfo.swift" >&2
  exit 1
fi

echo "Building OpenMarked ${VERSION} (${BUILD})"
swift build -c release --product OpenMarked
BIN_DIR="$(swift build -c release --show-bin-path | tail -n 1)"

APP_NAME="OpenMarked.app"
DIST_DIR="$ROOT_DIR/dist"
PACKAGE_DIR="$DIST_DIR/OpenMarked-${VERSION}"
APP_DIR="$PACKAGE_DIR/$APP_NAME"
ZIP_PATH="$DIST_DIR/OpenMarked-${VERSION}-macOS.zip"
DMG_PATH="$DIST_DIR/OpenMarked-${VERSION}-macOS.dmg"
RESOURCE_BUNDLE="$BIN_DIR/OpenMarked_OpenMarkedCore.bundle"
APP_ICON_SOURCE="$ROOT_DIR/Packaging/Assets/OpenMarkedIcon.icns"
APP_ICON_NAME="OpenMarkedIcon.icns"
SIGN_IDENTITY="${OPENMARKED_SIGN_IDENTITY:--}"

if [[ ! -x "$BIN_DIR/OpenMarked" ]]; then
  echo "Release executable was not found at $BIN_DIR/OpenMarked" >&2
  exit 1
fi

if [[ ! -d "$RESOURCE_BUNDLE" ]]; then
  echo "SwiftPM resource bundle was not found at $RESOURCE_BUNDLE" >&2
  exit 1
fi

if [[ ! -f "$APP_ICON_SOURCE" ]]; then
  echo "App icon was not found at $APP_ICON_SOURCE" >&2
  exit 1
fi

rm -rf "$PACKAGE_DIR" "$ZIP_PATH" "$DMG_PATH"
install -d "$APP_DIR/Contents/MacOS"
install -d "$APP_DIR/Contents/Resources"

install -m 755 "$BIN_DIR/OpenMarked" "$APP_DIR/Contents/MacOS/OpenMarked"
install -m 644 "$APP_ICON_SOURCE" "$APP_DIR/Contents/Resources/$APP_ICON_NAME"
cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/OpenMarked_OpenMarkedCore.bundle"

PACKAGED_RESOURCE_BUNDLE="$APP_DIR/Contents/Resources/OpenMarked_OpenMarkedCore.bundle"

require_packaged_resource() {
  local resource_name="$1"
  if ! find "$PACKAGED_RESOURCE_BUNDLE" -type f -name "$resource_name" -print -quit | grep -q .; then
    echo "Packaged rich content resource is missing: $resource_name" >&2
    exit 1
  fi
}

require_packaged_resource "rich-content-runtime.js"
require_packaged_resource "rich-content.css"
require_packaged_resource "mermaid.min.js"
require_packaged_resource "Mermaid-LICENSE"
require_packaged_resource "katex.min.js"
require_packaged_resource "katex.min.css"
require_packaged_resource "KaTeX-LICENSE"
require_packaged_resource "KaTeX_Main-Regular.woff2"

katex_woff2_count="$(find "$PACKAGED_RESOURCE_BUNDLE" -type f -name 'KaTeX_*.woff2' | wc -l | tr -d ' ')"
if [[ "$katex_woff2_count" -lt 10 ]]; then
  echo "Expected packaged KaTeX WOFF2 fonts, found $katex_woff2_count." >&2
  exit 1
fi

sed \
  -e "s|{{VERSION}}|$VERSION|g" \
  -e "s|{{BUILD}}|$BUILD|g" \
  -e "s|{{BUNDLE_IDENTIFIER}}|$BUNDLE_IDENTIFIER|g" \
  -e "s|{{MINIMUM_MACOS}}|$MINIMUM_MACOS|g" \
  Packaging/Info.plist.template > "$APP_DIR/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_DIR/Contents/Info.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_DIR/Contents/Info.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$APP_DIR/Contents/Info.plist" >/dev/null

if [[ ! -f "$APP_DIR/Contents/Resources/$APP_ICON_NAME" ]]; then
  echo "Packaged app icon is missing: $APP_ICON_NAME" >&2
  exit 1
fi

if [[ "${OPENMARKED_SKIP_CODESIGN:-0}" != "1" ]]; then
  codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR"
  codesign --verify --deep --strict --verbose=2 "$APP_DIR"
else
  echo "Skipping ad hoc codesign because OPENMARKED_SKIP_CODESIGN=1"
fi

(
  cd "$PACKAGE_DIR"
  ditto -c -k --sequesterRsrc --keepParent "$APP_NAME" "$ZIP_PATH"
)

hdiutil create -volname "OpenMarked ${VERSION}" -srcfolder "$PACKAGE_DIR" -ov -format UDZO "$DMG_PATH"

if [[ "${OPENMARKED_SKIP_CODESIGN:-0}" != "1" && "$SIGN_IDENTITY" != "-" ]]; then
  codesign --force --sign "$SIGN_IDENTITY" "$DMG_PATH"
fi

if [[ "${OPENMARKED_NOTARIZE:-0}" == "1" ]]; then
  if [[ -z "${APPLE_ID:-}" || -z "${APPLE_TEAM_ID:-}" || -z "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
    echo "OPENMARKED_NOTARIZE=1 requires APPLE_ID, APPLE_TEAM_ID, and APPLE_APP_SPECIFIC_PASSWORD." >&2
    exit 1
  fi

  xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --wait
  xcrun stapler staple "$DMG_PATH"
fi

echo "Created $APP_DIR"
echo "Created $ZIP_PATH"
echo "Created $DMG_PATH"
