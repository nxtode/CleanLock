#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CleanLock"
VERSION="0.1.4"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
ZIP_PATH="$DIST_DIR/$APP_NAME-v$VERSION.zip"
DOCS_DIR="$ROOT_DIR/docs"
APPCAST_PATH="$DOCS_DIR/appcast.xml"
DOWNLOAD_URL_PREFIX="https://github.com/nxtode/CleanLock/releases/download/v$VERSION/"
WORK_DIR="$DIST_DIR/sparkle-appcast"

find_generate_appcast() {
  local candidates=(
    "$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin/generate_appcast"
    "$ROOT_DIR/.build/checkouts/Sparkle/generate_appcast"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  find "$ROOT_DIR/.build" -path "*/generate_appcast" -type f -perm -111 | head -1
}

cd "$ROOT_DIR"

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "Missing update ZIP: $ZIP_PATH" >&2
  echo "Run ./script/package_release.sh before generating the Sparkle appcast." >&2
  exit 1
fi

GENERATE_APPCAST="$(find_generate_appcast)"
if [[ -z "$GENERATE_APPCAST" ]]; then
  echo "Sparkle generate_appcast tool was not found." >&2
  echo "Run swift build, then retry ./script/sparkle_generate_appcast.sh" >&2
  exit 1
fi

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$DOCS_DIR"
cp "$ZIP_PATH" "$WORK_DIR/"
cat > "$WORK_DIR/$APP_NAME-v$VERSION.md" <<EOF
CleanLock $VERSION release.
EOF

"$GENERATE_APPCAST" \
  --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
  --embed-release-notes \
  -o "$APPCAST_PATH" \
  "$WORK_DIR"

echo "Sparkle appcast generated: $APPCAST_PATH"
