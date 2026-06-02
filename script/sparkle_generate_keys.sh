#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

find_generate_keys() {
  local candidates=(
    "$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin/generate_keys"
    "$ROOT_DIR/.build/checkouts/Sparkle/generate_keys"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  find "$ROOT_DIR/.build" -path "*/generate_keys" -type f -perm -111 | head -1
}

cd "$ROOT_DIR"

if [[ ! -d "$ROOT_DIR/.build" ]]; then
  swift build
fi

GENERATE_KEYS="$(find_generate_keys)"
if [[ -z "$GENERATE_KEYS" ]]; then
  echo "Sparkle generate_keys tool was not found." >&2
  echo "Run swift build, then retry ./script/sparkle_generate_keys.sh" >&2
  exit 1
fi

echo "Using Sparkle key tool: $GENERATE_KEYS"
echo
"$GENERATE_KEYS"
echo
echo "Keep the Sparkle private key safe. It is stored in your macOS Keychain by Sparkle and must never be committed."
echo "Save only the printed SUPublicEDKey value in Resources/SparklePublicEDKey.txt."
