#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
[[ "$(uname -s)" == "Darwin" ]] || { echo "Requires macOS" >&2; exit 1; }
APP_VERSION="${APP_VERSION:-0.1.1}"
BUILD_ARCH="${BUILD_ARCH:-$(uname -m)}"
case "$BUILD_ARCH" in x86_64|arm64) ;; *) echo "Unsupported architecture: $BUILD_ARCH" >&2; exit 1 ;; esac
[[ "$(uname -m)" == "$BUILD_ARCH" ]] || {
  echo "Runner is $(uname -m), but requested $BUILD_ARCH" >&2
  exit 1
}

export MACOSX_DEPLOYMENT_TARGET=13.0
swift build --configuration release --product FinderIconTheme
BIN_DIR="$(swift build --configuration release --show-bin-path)"
BINARY="$BIN_DIR/FinderIconTheme"
test -f "$BINARY"

ACTUAL_ARCH="$(lipo -archs "$BINARY")"
if [[ "$ACTUAL_ARCH" != "$BUILD_ARCH" ]]; then
  echo "Binary arch mismatch: got $ACTUAL_ARCH, expected $BUILD_ARCH" >&2
  exit 1
fi

# Package.swift and Info.plist say macOS 13; the actual Mach-O must agree.
MIN_OS="$(otool -l "$BINARY" | awk '
  $1 == "cmd" && $2 == "LC_BUILD_VERSION" { in_build=1 }
  in_build && $1 == "minos" { print $2; exit }
  $1 == "cmd" && $2 == "LC_VERSION_MIN_MACOSX" { in_legacy=1 }
  in_legacy && $1 == "version" { print $2; exit }
')"
case "$MIN_OS" in
  13.0|13.0.0) ;;
  *) echo "Binary minimum macOS mismatch: got '$MIN_OS', expected 13.0" >&2; exit 1 ;;
esac

APP="$PWD/dist/FinderIconTheme.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
ditto "$BINARY" "$APP/Contents/MacOS/FinderIconTheme"
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
echo "Built $APP ($BUILD_ARCH; min macOS $MIN_OS)"
