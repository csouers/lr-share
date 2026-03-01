#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_CONFIG="${1:-release}"

if [[ "$BUILD_CONFIG" != "release" && "$BUILD_CONFIG" != "debug" ]]; then
  echo "Invalid build configuration: $BUILD_CONFIG" >&2
  echo "Usage: ./build.sh [release|debug]" >&2
  exit 1
fi

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

echo "Build complete."
echo "Plugin bundle:"
echo "$OUTPUT_PLUGIN_DIR"
echo
echo "In Lightroom Classic: File > Plug-in Manager > Add"
echo "Select:"
echo "$OUTPUT_PLUGIN_DIR"
