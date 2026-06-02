#!/usr/bin/env bash
set -euo pipefail
export COPYFILE_DISABLE=1

APP_NAME="CleanLock"
PRODUCT_NAME="CleanLock"
BUNDLE_ID="dev.nxtode.cleanlock"
VERSION="0.1.2"
BUILD="3"
APPCAST_URL="https://nxtode.github.io/CleanLock/appcast.xml"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
EXECUTABLE="$ROOT_DIR/.build/debug/$PRODUCT_NAME"
MENU_BAR_AGENT_NAME="CleanLockMenuBarAgent"
LOGIN_HELPER_NAME="CleanLockLoginHelper"
MENU_BAR_AGENT_EXECUTABLE="$ROOT_DIR/.build/debug/$MENU_BAR_AGENT_NAME"
LOGIN_HELPER_EXECUTABLE="$ROOT_DIR/.build/debug/$LOGIN_HELPER_NAME"
LOGIN_ITEMS_DIR="$APP_BUNDLE/Contents/Library/LoginItems"
MENU_BAR_AGENT_BUNDLE="$LOGIN_ITEMS_DIR/$MENU_BAR_AGENT_NAME.app"
LOGIN_HELPER_BUNDLE="$LOGIN_ITEMS_DIR/$LOGIN_HELPER_NAME.app"
APP_ICON="$ROOT_DIR/Resources/AppIcon.icns"
SPARKLE_PUBLIC_KEY_FILE="$ROOT_DIR/Resources/SparklePublicEDKey.txt"
ZIP_PATH="$DIST_DIR/$APP_NAME-v$VERSION.zip"
DMG_PATH="$DIST_DIR/$APP_NAME-v$VERSION.dmg"
LATEST_ZIP_PATH="$DIST_DIR/$APP_NAME-latest.zip"
LATEST_DMG_PATH="$DIST_DIR/$APP_NAME-latest.dmg"
PACKAGE_DIR="$DIST_DIR/package"
TEMP_DMG_PATH="$PACKAGE_DIR/$APP_NAME-temp.dmg"
VOLUME_DIR="$PACKAGE_DIR/$APP_NAME"
MOUNT_DIR="$PACKAGE_DIR/mount"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required tool: $1" >&2
    exit 1
  fi
}

require_tool swift
require_tool ditto
require_tool hdiutil
require_tool osascript
require_tool install_name_tool
require_tool codesign

find_sparkle_framework() {
  find "$ROOT_DIR/.build" -path "*/debug/Sparkle.framework" -type d | head -1
}

read_sparkle_public_key() {
  if [[ ! -f "$SPARKLE_PUBLIC_KEY_FILE" ]]; then
    echo "Missing Sparkle public key file: $SPARKLE_PUBLIC_KEY_FILE" >&2
    echo "Run ./script/sparkle_generate_keys.sh and save the printed SUPublicEDKey there." >&2
    exit 1
  fi

  tr -d '\n\r[:space:]' < "$SPARKLE_PUBLIC_KEY_FILE"
}

stage_helper_app() {
  local name="$1"
  local executable="$2"
  local bundle="$3"
  local bundle_id="$4"

  if [[ ! -x "$executable" ]]; then
    echo "Missing helper executable: $executable" >&2
    exit 1
  fi

  mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
  cp "$executable" "$bundle/Contents/MacOS/$name"
  cat > "$bundle/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$name</string>
  <key>CFBundleIdentifier</key>
  <string>$bundle_id</string>
  <key>CFBundleName</key>
  <string>$name</string>
  <key>CFBundleDisplayName</key>
  <string>$name</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF
}

cd "$ROOT_DIR"

echo "Cleaning release artifacts..."
rm -rf "$APP_BUNDLE" "$ZIP_PATH" "$DMG_PATH" "$LATEST_ZIP_PATH" "$LATEST_DMG_PATH" "$PACKAGE_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$APP_BUNDLE/Contents/Frameworks" "$LOGIN_ITEMS_DIR" "$VOLUME_DIR"

echo "Building $APP_NAME..."
swift build

echo "Staging app bundle..."
cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
stage_helper_app "$MENU_BAR_AGENT_NAME" "$MENU_BAR_AGENT_EXECUTABLE" "$MENU_BAR_AGENT_BUNDLE" "dev.nxtode.cleanlock.menubar"
stage_helper_app "$LOGIN_HELPER_NAME" "$LOGIN_HELPER_EXECUTABLE" "$LOGIN_HELPER_BUNDLE" "dev.nxtode.cleanlock.loginhelper"
SPARKLE_FRAMEWORK="$(find_sparkle_framework)"
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
  echo "Sparkle.framework was not found in SwiftPM build products." >&2
  exit 1
fi
cp -R "$SPARKLE_FRAMEWORK" "$APP_BUNDLE/Contents/Frameworks/"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || true
SPARKLE_PUBLIC_KEY="$(read_sparkle_public_key)"
if [[ -f "$APP_ICON" ]]; then
  cp "$APP_ICON" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi
if [[ -d "$ROOT_DIR/Resources" ]]; then
  while IFS= read -r resource; do
    cp "$resource" "$APP_BUNDLE/Contents/Resources/"
  done < <(find "$ROOT_DIR/Resources" -maxdepth 1 -type f ! -name "AppIcon.icns")
fi

cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHumanReadableCopyright</key>
  <string>© 2026 NXTode</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>SUFeedURL</key>
  <string>$APPCAST_URL</string>
  <key>SUPublicEDKey</key>
  <string>$SPARKLE_PUBLIC_KEY</string>
  <key>SUEnableAutomaticChecks</key>
  <true/>
</dict>
</plist>
EOF

codesign --force --deep --sign - "$APP_BUNDLE"

echo "Creating ZIP..."
ditto -c -k --norsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "Creating DMG..."
cp -R "$APP_BUNDLE" "$VOLUME_DIR/"
ln -s /Applications "$VOLUME_DIR/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$VOLUME_DIR" -ov -format UDRW "$TEMP_DMG_PATH"
mkdir -p "$MOUNT_DIR"
hdiutil attach "$TEMP_DMG_PATH" -mountpoint "$MOUNT_DIR" -noautoopen -quiet

osascript <<EOF || echo "Warning: Finder layout customization failed; DMG contents are still valid."
tell application "Finder"
  tell disk "$APP_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {100, 100, 740, 520}
    set icon size of icon view options of container window to 96
    set arrangement of icon view options of container window to not arranged
    set position of item "$APP_NAME.app" of container window to {180, 200}
    set position of item "Applications" of container window to {460, 200}
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF

hdiutil detach "$MOUNT_DIR" -quiet
hdiutil convert "$TEMP_DMG_PATH" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"
hdiutil verify "$DMG_PATH"
cp "$ZIP_PATH" "$LATEST_ZIP_PATH"
cp "$DMG_PATH" "$LATEST_DMG_PATH"

echo "Release artifacts created:"
echo "  $APP_BUNDLE"
echo "  $ZIP_PATH"
echo "  $DMG_PATH"
echo "  $LATEST_ZIP_PATH"
echo "  $LATEST_DMG_PATH"
echo
echo "Note: this build is not signed or notarized. macOS Gatekeeper may show a security warning."
