#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="OllamaBridge"
BIN_PATH=".build/release/${APP_NAME}"
APP_DIR="${APP_NAME}.app"

swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp Info.plist "$APP_DIR/Contents/Info.plist"
cp Resources/OllamaBridge.icns "$APP_DIR/Contents/Resources/OllamaBridge.icns"

# Re-sign the whole bundle so Info.plist (NSLocalNetworkUsageDescription) is
# sealed into the code signature. Without this, only the raw binary carries
# the linker's ad-hoc signature and macOS's TCC can't tie the Local Network
# permission to the app, so LAN scans silently fail with no prompt ever shown.
codesign --force --deep --sign - "$APP_DIR"

echo "Built ${APP_DIR}"
echo "Run it:      open ${APP_DIR}"
echo "Install it:  mv ${APP_DIR} /Applications/"
