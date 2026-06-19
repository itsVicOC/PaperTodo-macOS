# PaperTodo for macOS

This is the native macOS/AppKit version of PaperTodo. This repository maintains the macOS app only; Windows builds and Windows source are maintained by the original project: <https://github.com/snownico0722/PaperTodo>.

## Current Scope

Implemented:

- Menu bar app with no Dock icon when launched as a bundled app.
- Create todo and note papers.
- Independent borderless paper windows.
- Todo editing with add/delete, clear completed, Enter/Backspace row shortcuts, multi-line paste splitting, drag sorting, and footer drag-to-delete.
- Note editing with native `NSTextView`, basic Markdown pseudo-rendering including fenced code blocks, formatting shortcuts, right-click formatting menu for common Markdown inserts, text zoom, and link opening.
- Show all / hide all from the menu bar.
- Per-paper position, size, visibility, collapsed, and topmost persistence.
- Native settings window for theme, color scheme, Markdown mode, top-bar buttons, capsule flags, and interaction preferences.
- Live theme/color refresh for open paper windows.
- Optional display of paper windows and capsules across all Spaces.
- Todo-to-note links with native per-item link menus and linked-note opening.
- Basic capsule mode and right-edge deep capsule auto-arrangement with hover slide-out.
- Deep capsule drag reordering and expanded-edge reservation, including right-edge opening alignment that avoids overwriting normal paper geometry.
- Collapse-all master capsule for collecting and restoring right-edge capsules.
- Single-instance command forwarding for show, hide, toggle, new todo, new note, and exit.
- Safe `data.json` import from the menu bar or `--import /path/to/data.json`.
- Native launch-at-login control through macOS Login Items.
- Core UI localization for Chinese, English, Japanese, and Korean, following the system language.
- Windows-compatible `data.json` field names.
- Native macOS data directory: `~/Library/Application Support/PaperTodo/`.

Known polish areas:

- Markdown rendering intentionally remains lightweight; images, tables, attachments, embeds, block HTML, and full block editing are out of scope.
- Multi-display, Spaces, Stage Manager, and first-launch Gatekeeper behavior still need real-device QA before each public release.

## Requirements

- macOS 13 or newer.
- Swift toolchain from Xcode or Command Line Tools.

## Build

From this directory:

```sh
swift build
```

For a release build:

```sh
swift build -c release
```

Inside sandboxed environments where `~/Library` or `~/.cache` is not writable, use project-local caches:

```sh
mkdir -p .build/cache .build/config .build/security .build/clang-module-cache .build/tmp .build/home
HOME="$PWD/.build/home" \
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache" \
TMPDIR="$PWD/.build/tmp" \
swift build --disable-sandbox \
  --cache-path .build/cache \
  --config-path .build/config \
  --security-path .build/security \
  --manifest-cache local \
  -Xcc -fmodules-cache-path="$PWD/.build/clang-module-cache"
```

If your Command Line Tools installation points at a newer SDK that does not match the active Swift compiler, pass an older installed SDK explicitly:

```sh
swift build --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
```

Run unit tests:

```sh
HOME="$PWD/.build/home" \
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache" \
TMPDIR="$PWD/.build/tmp" \
swift test --disable-sandbox \
  --cache-path .build/cache \
  --config-path .build/config \
  --security-path .build/security \
  --manifest-cache local \
  -Xcc -fmodules-cache-path="$PWD/.build/clang-module-cache"
```

## Build a Local `.app`

```sh
./scripts/build-app.sh
```

The script creates:

```text
.build/PaperTodo.app
```

It uses ad-hoc signing only. Without an Apple Developer ID, this app is not notarized and may require manual approval the first time it is opened on another Mac.

Launch-at-login uses Apple's `SMAppService.mainApp` Login Items API. The app must be code signed, so the local bundle is ad-hoc signed by `build-app.sh`; on some macOS versions an unsigned, relocated, or unnotarized build may still require user approval in System Settings -> General -> Login Items, or may need to be moved to `/Applications` before registration works reliably.

You can override the SDK used by the script:

```sh
SDK_PATH=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ./scripts/build-app.sh
```

## Package an Unnotarized Release Asset

```sh
./scripts/package-release.sh
```

The script rebuilds the app, verifies the ad-hoc signature, and writes release-ready files to:

```text
.build/release-assets/
├─ PaperTodo-v<version>-macos-<arch>-unnotarized.app.zip
├─ README-macOS-unnotarized.txt
└─ SHA256SUMS.txt
```

This is the intended open-source distribution path until the project has an Apple Developer ID. The zip is ad-hoc signed but not notarized, so Release notes must keep the "unnotarized" wording visible. Users should verify `SHA256SUMS.txt`, move `PaperTodo.app` to `/Applications`, and open it once manually before enabling Launch at Login.

For local packaging without rebuilding first:

```sh
SKIP_BUILD=1 ./scripts/package-release.sh
```

## Run During Development

Command-line run:

```sh
swift run
```

Bundled run after `build-app.sh`:

```sh
open .build/PaperTodo.app
```

Opening the app with `open` may require macOS GUI approval depending on the local security state.

## Launch Commands

The executable accepts these commands. If PaperTodo is already running, a later process forwards the command to the main instance and exits:

```sh
PaperTodoMac --show
PaperTodoMac --hide
PaperTodoMac --toggle
PaperTodoMac --new-todo
PaperTodoMac --new-note
PaperTodoMac --import /path/to/data.json
PaperTodoMac --exit
```

Aliases include `open` for `show`, `todo` for `new-todo`, `note` for `new-note`, and `quit` for `exit`.

For local verification only, `PAPERTODO_DATA_DIR=/path/to/test-data` overrides the data directory. `PAPERTODO_IMPORT_WITHOUT_CONFIRMATION=1` skips the import confirmation dialog for scripted tests. Normal users should leave both unset so PaperTodo uses `~/Library/Application Support/PaperTodo/` and confirms destructive imports.

## Verification Note

Verified locally with Xcode 26.5:

- `swift test` with project-local caches.
- `swift build` with project-local caches.
- `./scripts/build-app.sh`.
- `codesign --verify --deep --strict --verbose=2 .build/PaperTodo.app`.
- `PAPERTODO_DATA_DIR="$PWD/.build/smoke/data" .build/PaperTodo.app/Contents/MacOS/PaperTodoMac --exit`.
- `PAPERTODO_DATA_DIR="$PWD/.build/smoke/data" PAPERTODO_IMPORT_WITHOUT_CONFIRMATION=1 .build/PaperTodo.app/Contents/MacOS/PaperTodoMac --import "$PWD/.build/smoke/import.json"`.
- GUI launch via `open .build/PaperTodo.app`.
- State file creation at `~/Library/Application Support/PaperTodo/data.json`.

If SwiftPM fails before compiling source code because its own manifest sandbox cannot run, this source-level check still validates the Swift/AppKit code:

```sh
swiftc -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
  -target arm64-apple-macosx13.0 \
  -typecheck Sources/PaperTodoMac/*.swift
```
