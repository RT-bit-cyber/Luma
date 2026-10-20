#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
swift build -c release --disable-sandbox
BIN_DIR="$(swift build -c release --show-bin-path --disable-sandbox)"
APP="${LUMA_APP_PATH:-$PWD/../Luma.app}"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Luma" "$APP/Contents/MacOS/Luma"
cp Resources/Luma.icns "$APP/Contents/Resources/Luma.icns"
cp Resources/LumaIcon.png "$APP/Contents/Resources/LumaIcon.png"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp LICENSE "$APP/Contents/Resources/LICENSE"
codesign --force --sign - --identifier local.lightsaber.Luma --entitlements Resources/Luma.entitlements "$APP"
codesign --verify --strict "$APP"
plutil -lint "$APP/Contents/Info.plist"
echo "Built $APP"
