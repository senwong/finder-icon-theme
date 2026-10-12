#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
[[ "$(uname -s)" == "Darwin" ]] || { echo "Requires macOS" >&2; exit 1; }
APP_VERSION="${APP_VERSION:-0.1.1}"
BUILD_ARCH="${BUILD_ARCH:-$(uname -m)}"
./build-macos.sh
APP="$PWD/dist/FinderIconTheme.app"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/FinderIconTheme.app"
ln -s /Applications "$STAGE/Applications"
DMG="$PWD/dist/FinderIconTheme-v${APP_VERSION}-macOS-${BUILD_ARCH}.dmg"
hdiutil create -ov -format UDZO -volname "Finder Icon Theme" -srcfolder "$STAGE" "$DMG"
hdiutil verify "$DMG"
(cd dist && shasum -a 256 "FinderIconTheme-v${APP_VERSION}-macOS-${BUILD_ARCH}.dmg" > "FinderIconTheme-v${APP_VERSION}-macOS-${BUILD_ARCH}.dmg.sha256")
echo "Created $DMG"
