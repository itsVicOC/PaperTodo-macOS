#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/.build/PaperTodo.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
SDK_PATH="${SDK_PATH:-}"

if [[ -z "$SDK_PATH" && -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
  SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
fi

cd "$ROOT_DIR"
mkdir -p .build/cache .build/config .build/security .build/clang-module-cache .build/tmp .build/home

build_args=(
  -c release
  --disable-sandbox
  --cache-path .build/cache
  --config-path .build/config
  --security-path .build/security
  --manifest-cache local
  -Xcc -fmodules-cache-path="$ROOT_DIR/.build/clang-module-cache"
)

if [[ -n "$SDK_PATH" ]]; then
  build_args+=(--sdk "$SDK_PATH")
fi

HOME="$ROOT_DIR/.build/home" \
CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-module-cache" \
TMPDIR="$ROOT_DIR/.build/tmp" \
swift build "${build_args[@]}"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
cp "$BUILD_DIR/PaperTodoMac" "$MACOS_DIR/PaperTodoMac"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo "$APP_DIR"
