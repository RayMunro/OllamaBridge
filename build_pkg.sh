#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="OllamaBridge"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
IDENTIFIER="com.raymondmunro.ollamabridge.pkg"
PKG_OUT="${APP_NAME}-${VERSION}.pkg"

./build_app.sh

xattr -cr "${APP_NAME}.app"

pkgbuild \
  --component "${APP_NAME}.app" \
  --install-location /Applications \
  --identifier "$IDENTIFIER" \
  --version "$VERSION" \
  "$PKG_OUT"

echo "Built ${PKG_OUT}"
