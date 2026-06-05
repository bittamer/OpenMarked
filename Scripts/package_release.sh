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
RESOURCE_BUNDLE="$BIN_DIR/OpenMarked_OpenMarkedCore.bundle"

if [[ ! -x "$BIN_DIR/OpenMarked" ]]; then
  echo "Release executable was not found at $BIN_DIR/OpenMarked" >&2
  exit 1
fi

if [[ ! -d "$RESOURCE_BUNDLE" ]]; then
  echo "SwiftPM resource bundle was not found at $RESOURCE_BUNDLE" >&2
  exit 1
fi

rm -rf "$PACKAGE_DIR" "$ZIP_PATH"
install -d "$APP_DIR/Contents/MacOS"
install -d "$APP_DIR/Contents/Resources"

install -m 755 "$BIN_DIR/OpenMarked" "$APP_DIR/Contents/MacOS/OpenMarked"
cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/OpenMarked_OpenMarkedCore.bundle"

sed \
  -e "s|{{VERSION}}|$VERSION|g" \
  -e "s|{{BUILD}}|$BUILD|g" \
  -e "s|{{BUNDLE_IDENTIFIER}}|$BUNDLE_IDENTIFIER|g" \
  -e "s|{{MINIMUM_MACOS}}|$MINIMUM_MACOS|g" \
  Packaging/Info.plist.template > "$APP_DIR/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_DIR/Contents/Info.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_DIR/Contents/Info.plist" >/dev/null

if [[ "${OPENMARKED_SKIP_CODESIGN:-0}" != "1" ]]; then
  codesign --force --deep --sign - "$APP_DIR"
  codesign --verify --deep --strict --verbose=2 "$APP_DIR"
else
  echo "Skipping ad hoc codesign because OPENMARKED_SKIP_CODESIGN=1"
fi

(
  cd "$PACKAGE_DIR"
  ditto -c -k --sequesterRsrc --keepParent "$APP_NAME" "$ZIP_PATH"
)

echo "Created $APP_DIR"
echo "Created $ZIP_PATH"
