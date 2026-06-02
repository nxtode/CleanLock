#!/usr/bin/env bash
set -euo pipefail
export COPYFILE_DISABLE=1

APP_NAME="CleanLock"
PRODUCT_NAME="CleanLock"
BUNDLE_ID="dev.asuncion.cleanlock"
VERSION="0.1.0"
BUILD="1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
EXECUTABLE="$ROOT_DIR/.build/debug/$PRODUCT_NAME"
APP_ICON="$ROOT_DIR/Resources/AppIcon.icns"
ZIP_PATH="$DIST_DIR/$APP_NAME-v$VERSION.zip"
DMG_PATH="$DIST_DIR/$APP_NAME-v$VERSION.dmg"
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

cd "$ROOT_DIR"

echo "Cleaning release artifacts..."
rm -rf "$APP_BUNDLE" "$ZIP_PATH" "$DMG_PATH" "$PACKAGE_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$VOLUME_DIR"

echo "Building $APP_NAME..."
swift build

echo "Staging app bundle..."
cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
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
</dict>
</plist>
EOF

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

echo "Release artifacts created:"
echo "  $APP_BUNDLE"
echo "  $ZIP_PATH"
echo "  $DMG_PATH"
echo
echo "Note: this build is not signed or notarized. macOS Gatekeeper may show a security warning."
