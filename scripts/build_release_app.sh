#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="GoalReminderSwift.app"
APP_PATH="$ROOT_DIR/release/$APP_NAME"
ZIP_PATH="$ROOT_DIR/release/GoalReminderSwift.app.zip"
BUILD_BIN="$(find "$ROOT_DIR/.build" -type f -path '*/release/GoalReminderApp' | head -n 1)"
INFO_PLIST_PATH="$APP_PATH/Contents/Info.plist"
CACHE_ROOT="$ROOT_DIR/.swift-cache"
HOME_ROOT="$ROOT_DIR/.home"

mkdir -p "$CACHE_ROOT/clang-module-cache" "$CACHE_ROOT/org.swift.swiftpm" "$HOME_ROOT"
export HOME="$HOME_ROOT"
export XDG_CACHE_HOME="$CACHE_ROOT"
export CLANG_MODULE_CACHE_PATH="$CACHE_ROOT/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CACHE_ROOT/org.swift.swiftpm"

mkdir -p "$ROOT_DIR/release"

swift build -c release

BUILD_BIN="$(find "$ROOT_DIR/.build" -type f -path '*/release/GoalReminderApp' | head -n 1)"
if [[ -z "$BUILD_BIN" ]]; then
  echo "Release binary not found." >&2
  exit 1
fi

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"

if [[ -f "$ZIP_PATH" ]]; then
  unzip -p "$ZIP_PATH" "$APP_NAME/Contents/Info.plist" > "$INFO_PLIST_PATH"
else
  cat > "$INFO_PLIST_PATH" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleDisplayName</key>
    <string>GoalReminderSwift</string>
    <key>CFBundleExecutable</key>
    <string>GoalReminderApp</string>
    <key>CFBundleIdentifier</key>
    <string>local.goalreminder.swiftui</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>GoalReminderSwift</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.4.4</string>
    <key>CFBundleVersion</key>
    <string>9</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST
fi

cp "$BUILD_BIN" "$APP_PATH/Contents/MacOS/GoalReminderApp"
chmod +x "$APP_PATH/Contents/MacOS/GoalReminderApp"

codesign --force --deep --sign - "$APP_PATH"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Built app: $APP_PATH"
echo "Packed zip: $ZIP_PATH"
