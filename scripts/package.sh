#!/bin/bash
# Builds a release binary, wraps it in Koob Shell.app, and produces a DMG installer.
#
# Usage: scripts/package.sh [version]
#   version defaults to 1.0.0
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-1.0.0}"
APP_NAME="Koob Shell"
EXECUTABLE="KoobShell"
BUNDLE_ID="com.vurzumm.koobshell"
DIST_DIR="dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/KoobShell-$VERSION.dmg"

echo "==> Building release binary (universal)"
if swift build -c release --arch arm64 --arch x86_64; then
    BIN_PATH="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
else
    echo "==> Universal build failed, falling back to native arch"
    swift build -c release
    BIN_PATH="$(swift build -c release --show-bin-path)"
fi

echo "==> Assembling $APP_DIR"
rm -rf "$APP_DIR" "$DMG_PATH"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN_PATH/$EXECUTABLE" "$APP_DIR/Contents/MacOS/$EXECUTABLE"

# Bundle.module resolves the SwiftPM resource bundle from Contents/Resources.
cp -R "$BIN_PATH/MacTerminalTracker_MacTerminalTracker.bundle" "$APP_DIR/Contents/Resources/"

printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> Code signing (ad-hoc)"
codesign --force --deep --sign - "$APP_DIR"

echo "==> Creating DMG"
STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT
cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$STAGING_DIR" \
    -fs HFS+ \
    -format UDZO \
    "$DMG_PATH"

echo
echo "Done:"
echo "  App: $APP_DIR"
echo "  DMG: $DMG_PATH"
