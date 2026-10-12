#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
[[ "$(uname -s)" == "Darwin" ]] || { echo "Requires macOS" >&2; exit 1; }
APP_VERSION="$(printenv APP_VERSION || echo 0.1.0)"
swift build --configuration release --product FinderIconTheme
BIN_DIR="$(swift build --configuration release --show-bin-path)"
APP="$PWD/dist/FinderIconTheme.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
ditto "$BIN_DIR/FinderIconTheme" "$APP/Contents/MacOS/FinderIconTheme"
chmod +x "$APP/Contents/MacOS/FinderIconTheme"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>FinderIconTheme</string>
<key>CFBundleIdentifier</key><string>com.senwong.FinderIconTheme</string>
<key>CFBundleName</key><string>Finder Icon Theme</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$APP_VERSION</string>
<key>CFBundleVersion</key><string>$APP_VERSION</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
plutil -lint "$APP/Contents/Info.plist"
codesign --verify --deep --strict "$APP"
echo "Built $APP"
