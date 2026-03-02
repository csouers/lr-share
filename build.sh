#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_CONFIG="${1:-release}"

if [[ "$BUILD_CONFIG" != "release" && "$BUILD_CONFIG" != "debug" ]]; then
  echo "Invalid build configuration: $BUILD_CONFIG" >&2
  echo "Usage: ./build.sh [release|debug]" >&2
  exit 1
fi

# === Build Share Plugin ===
echo "=== Building Mac OS Share Plugin ==="

SOURCE_PLUGIN_DIR="$ROOT_DIR/plugin-src/MacOSShareMenu.lrplugin"
HELPER_BUILD_SCRIPT="$ROOT_DIR/helper/scripts/build-app-bundle.sh"
HELPER_APP_DIR="$ROOT_DIR/helper/dist/LightroomShareHelper.app"
DIST_DIR="$ROOT_DIR/dist"
OUTPUT_PLUGIN_DIR="$DIST_DIR/MacOSShareMenu.lrplugin"
OUTPUT_HELPER_DIR="$OUTPUT_PLUGIN_DIR/Support/LightroomShareHelper.app"
OUTPUT_HELPER_BINARY="$OUTPUT_HELPER_DIR/Contents/MacOS/LightroomShareHelper"

if [[ ! -d "$SOURCE_PLUGIN_DIR" ]]; then
  echo "Plugin source directory not found: $SOURCE_PLUGIN_DIR" >&2
  exit 1
fi

if [[ ! -x "$HELPER_BUILD_SCRIPT" ]]; then
  echo "Helper build script not executable: $HELPER_BUILD_SCRIPT" >&2
  exit 1
fi

echo "Building share helper..."
"$HELPER_BUILD_SCRIPT" "$BUILD_CONFIG"

if [[ ! -d "$HELPER_APP_DIR" ]]; then
  echo "Built helper app not found: $HELPER_APP_DIR" >&2
  exit 1
fi

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

rsync -a --delete "$SOURCE_PLUGIN_DIR/" "$OUTPUT_PLUGIN_DIR/"
mkdir -p "$OUTPUT_PLUGIN_DIR/Support"
rsync -a --delete "$HELPER_APP_DIR/" "$OUTPUT_HELPER_DIR/"

if [[ ! -x "$OUTPUT_HELPER_BINARY" ]]; then
  echo "Packaged helper binary missing or not executable: $OUTPUT_HELPER_BINARY" >&2
  exit 1
fi

echo "Share plugin built: $OUTPUT_PLUGIN_DIR"

# === Build Clipboard Plugin ===
echo ""
echo "=== Building Mac OS Clipboard Plugin ==="

CLIPBOARD_SOURCE="$ROOT_DIR/clipboard-plugin/MacOSClipboard.lrplugin"
CLIPBOARD_HELPER_BUILD_SCRIPT="$ROOT_DIR/helper-clipboard/scripts/build-app-bundle.sh"
CLIPBOARD_HELPER_APP_DIR="$ROOT_DIR/helper-clipboard/dist/LightroomClipboardHelper.app"
CLIPBOARD_OUTPUT_DIR="$DIST_DIR/MacOSClipboard.lrplugin"
CLIPBOARD_OUTPUT_HELPER="$CLIPBOARD_OUTPUT_DIR/Support/LightroomClipboardHelper.app"

if [[ ! -d "$CLIPBOARD_SOURCE" ]]; then
  echo "Clipboard plugin source not found: $CLIPBOARD_SOURCE" >&2
  exit 1
fi

if [[ ! -x "$CLIPBOARD_HELPER_BUILD_SCRIPT" ]]; then
  echo "Clipboard helper build script not executable: $CLIPBOARD_HELPER_BUILD_SCRIPT" >&2
  exit 1
fi

echo "Building clipboard helper..."
"$CLIPBOARD_HELPER_BUILD_SCRIPT" "$BUILD_CONFIG"

if [[ ! -d "$CLIPBOARD_HELPER_APP_DIR" ]]; then
  echo "Built clipboard helper app not found: $CLIPBOARD_HELPER_APP_DIR" >&2
  exit 1
fi

rsync -a "$CLIPBOARD_SOURCE/" "$CLIPBOARD_OUTPUT_DIR/"
mkdir -p "$CLIPBOARD_OUTPUT_DIR/Support"
rsync -a --delete "$CLIPBOARD_HELPER_APP_DIR/" "$CLIPBOARD_OUTPUT_HELPER/"

echo "Clipboard plugin built: $CLIPBOARD_OUTPUT_DIR"

echo ""
echo "=== Build Complete ==="
echo "Plugins:"
echo "  - $OUTPUT_PLUGIN_DIR"
echo "  - $CLIPBOARD_OUTPUT_DIR"
