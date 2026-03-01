#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_PLUGIN_DIR="$ROOT_DIR/dist/MacOSShareMenu.lrplugin"
TARGET_MODULES_DIR="${1:-/Volumes/csouers/Library/Application Support/Adobe/Lightroom/Modules}"
TARGET_PLUGIN_DIR="$TARGET_MODULES_DIR/MacOSShareMenu.lrplugin"

if [[ ! -d "$SOURCE_PLUGIN_DIR" ]]; then
  echo "Built plugin not found: $SOURCE_PLUGIN_DIR" >&2
  echo "Run ./build.sh first." >&2
  exit 1
fi

mkdir -p "$TARGET_MODULES_DIR"
rsync -a --delete "$SOURCE_PLUGIN_DIR/" "$TARGET_PLUGIN_DIR/"

echo "Installed plugin:"
echo "$TARGET_PLUGIN_DIR"
