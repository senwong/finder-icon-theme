#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
[[ "$(uname -s)" == "Darwin" ]] || { echo "Requires macOS" >&2; exit 1; }
APP_VERSION="$(printenv APP_VERSION || echo 0.1.0)"
./build-macos.sh
APP="$PWD/dist/FinderIconTheme.app"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/FinderIconTheme.app"
ln -s /Applications "$STAGE/Applications"
DMG="$PWD/dist/FinderIconTheme-v$APP_VERSION-macOS.dmg"
hdiutil create -ov -format UDZO -volname "Finder Icon Theme" -srcfolder "$STAGE" "$DMG"
hdiutil verify "$DMG"
(cd dist && shasum -a 256 "FinderIconTheme-v$APP_VERSION-macOS.dmg" > "FinderIconTheme-v$APP_VERSION-macOS.dmg.sha256")
echo "Created $DMG"
