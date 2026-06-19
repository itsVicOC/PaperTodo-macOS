#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/PaperTodo.app"
ASSET_DIR="$ROOT_DIR/.build/release-assets"
PLIST="$ROOT_DIR/Resources/Info.plist"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"
ARCH="${ARCH:-$(uname -m)}"
ASSET_BASENAME="PaperTodo-v${VERSION}-macos-${ARCH}-unnotarized"
ZIP_PATH="$ASSET_DIR/${ASSET_BASENAME}.app.zip"
NOTICE_PATH="$ASSET_DIR/README-macOS-unnotarized.txt"
CHECKSUM_PATH="$ASSET_DIR/SHA256SUMS.txt"

cd "$ROOT_DIR"

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  ./scripts/build-app.sh >/dev/null
fi

if [[ ! -d "$APP_DIR" ]]; then
  echo "App bundle not found: $APP_DIR" >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_DIR"

rm -rf "$ASSET_DIR"
mkdir -p "$ASSET_DIR"

ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

cat >"$NOTICE_PATH" <<EOF
PaperTodo for macOS
Version: ${VERSION} (${BUILD})
Asset: ${ASSET_BASENAME}.app.zip

This build is open-source and ad-hoc signed, but it is not signed with an Apple Developer ID and it is not notarized by Apple.

First launch on another Mac may be blocked by Gatekeeper. If you trust the source, you can open it from Finder with Control-click -> Open, or remove quarantine with:

  xattr -dr com.apple.quarantine PaperTodo.app

Install suggestion:

  1. Unzip ${ASSET_BASENAME}.app.zip.
  2. Move PaperTodo.app to /Applications.
  3. Open it once manually before enabling Launch at Login.

Verify the download:

  shasum -a 256 -c SHA256SUMS.txt
EOF

(
  cd "$ASSET_DIR"
  shasum -a 256 "$(basename "$ZIP_PATH")" "$(basename "$NOTICE_PATH")" >"$CHECKSUM_PATH"
)

echo "$ASSET_DIR"
