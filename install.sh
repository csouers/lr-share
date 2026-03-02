#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_MODULES_DIR="${1:-$HOME/Library/Application Support/Adobe/Lightroom/Modules}"

# Install Share Plugin
echo "=== Installing Mac OS Share Plugin ==="
SOURCE_PLUGIN_DIR="$ROOT_DIR/dist/MacOSShareMenu.lrplugin"
TARGET_PLUGIN_DIR="$TARGET_MODULES_DIR/MacOSShareMenu.lrplugin"

if [[ ! -d "$SOURCE_PLUGIN_DIR" ]]; then
  echo "Built plugin not found: $SOURCE_PLUGIN_DIR" >&2
  echo "Run ./build.sh first." >&2
  exit 1
fi

mkdir -p "$TARGET_MODULES_DIR"
rsync -a --delete "$SOURCE_PLUGIN_DIR/" "$TARGET_PLUGIN_DIR/"

echo "Installed: $TARGET_PLUGIN_DIR"

# Install Clipboard Plugin
echo ""
echo "=== Installing Mac OS Clipboard Plugin ==="
SOURCE_CLIPBOARD_DIR="$ROOT_DIR/dist/MacOSClipboard.lrplugin"
TARGET_CLIPBOARD_DIR="$TARGET_MODULES_DIR/MacOSClipboard.lrplugin"

if [[ ! -d "$SOURCE_CLIPBOARD_DIR" ]]; then
  echo "Built clipboard plugin not found: $SOURCE_CLIPBOARD_DIR" >&2
  exit 1
fi

rsync -a --delete "$SOURCE_CLIPBOARD_DIR/" "$TARGET_CLIPBOARD_DIR/"

echo "Installed: $TARGET_CLIPBOARD_DIR"

echo ""
echo "=== Install Complete ==="
