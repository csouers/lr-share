#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_CONFIG="${1:-release}"

usage() {
  echo "Usage: ./release-signed.sh [release|debug]" >&2
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: $name" >&2
    exit 1
  fi
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd" >&2
    exit 1
  fi
}

require_xcrun_tool() {
  local tool="$1"
  if ! xcrun -f "$tool" >/dev/null 2>&1; then
    echo "Required Xcode tool not found via xcrun: $tool" >&2
    exit 1
  fi
}

if [[ "$BUILD_CONFIG" != "release" && "$BUILD_CONFIG" != "debug" ]]; then
  echo "Invalid build configuration: $BUILD_CONFIG" >&2
  usage
  exit 1
fi

require_env "CODESIGN_IDENTITY"
require_env "NOTARY_PROFILE"

require_cmd "codesign"
require_cmd "spctl"
require_cmd "security"
require_cmd "ditto"
require_xcrun_tool "notarytool"
require_xcrun_tool "stapler"

if ! security find-identity -v -p codesigning | grep -Fq "$CODESIGN_IDENTITY"; then
  echo "Signing identity not found in keychain: $CODESIGN_IDENTITY" >&2
  echo "Available code-sign identities:" >&2
  security find-identity -v -p codesigning >&2 || true
  exit 1
fi

BUILD_SCRIPT="$ROOT_DIR/build.sh"
DIST_DIR="$ROOT_DIR/dist"

# Share plugin
SHARE_PLUGIN_DIR="$DIST_DIR/MacOSShareMenu.lrplugin"
SHARE_HELPER_APP="$SHARE_PLUGIN_DIR/Support/LightroomShareHelper.app"
SHARE_HELPER_ZIP="$DIST_DIR/LightroomShareHelper.notarize.zip"
SHARE_PLUGIN_ZIP="$DIST_DIR/MacOSShareMenu.lrplugin.zip"

# Clipboard plugin
CLIPBOARD_PLUGIN_DIR="$DIST_DIR/MacOSClipboard.lrplugin"
CLIPBOARD_HELPER_APP="$CLIPBOARD_PLUGIN_DIR/Support/LightroomClipboardHelper.app"
CLIPBOARD_HELPER_ZIP="$DIST_DIR/LightroomClipboardHelper.notarize.zip"
CLIPBOARD_PLUGIN_ZIP="$DIST_DIR/MacOSClipboard.lrplugin.zip"

echo "Building unsigned plugin bundles..."
"$BUILD_SCRIPT" "$BUILD_CONFIG"

if [[ ! -d "$SHARE_PLUGIN_DIR" ]]; then
  echo "Built share plugin bundle not found: $SHARE_PLUGIN_DIR" >&2
  exit 1
fi

if [[ ! -d "$SHARE_HELPER_APP" ]]; then
  echo "Share helper app not found: $SHARE_HELPER_APP" >&2
  exit 1
fi

if [[ ! -d "$CLIPBOARD_PLUGIN_DIR" ]]; then
  echo "Built clipboard plugin bundle not found: $CLIPBOARD_PLUGIN_DIR" >&2
  exit 1
fi

if [[ ! -d "$CLIPBOARD_HELPER_APP" ]]; then
  echo "Clipboard helper app not found: $CLIPBOARD_HELPER_APP" >&2
  exit 1
fi

sign_and_notarize() {
  local app="$1"
  local zip="$2"
  local label="$3"

  echo ""
  echo "=== Signing $label ==="
  codesign --force --timestamp --options runtime --sign "$CODESIGN_IDENTITY" "$app"

  echo "Verifying signature..."
  codesign --verify --strict --verbose=2 "$app"

  echo "Preparing zip for notarization..."
  rm -f "$zip"
  ditto -c -k --keepParent "$app" "$zip"

  echo "Submitting for notarization..."
  NOTARY_OUTPUT="$(xcrun notarytool submit "$zip" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json)"
  printf '%s\n' "$NOTARY_OUTPUT"

  if ! printf '%s\n' "$NOTARY_OUTPUT" | grep -Eq '"status"[[:space:]]*:[[:space:]]*"Accepted"'; then
    echo "Notarization did not return status Accepted." >&2
    echo "Temporary notarization archive retained for debugging: $zip" >&2
    exit 1
  fi

  echo "Stapling notarization ticket..."
  xcrun stapler staple -v "$app"

  echo "Validating stapled ticket..."
  xcrun stapler validate -v "$app"

  echo "Running Gatekeeper assessment..."
  spctl --assess --type execute --verbose=4 "$app"

  rm -f "$zip"
}

sign_and_notarize "$SHARE_HELPER_APP" "$SHARE_HELPER_ZIP" "LightroomShareHelper"
sign_and_notarize "$CLIPBOARD_HELPER_APP" "$CLIPBOARD_HELPER_ZIP" "LightroomClipboardHelper"

echo ""
echo "=== Creating signed release zip ==="
RELEASE_ZIP="$DIST_DIR/MacOS-LrPlugins.zip"
rm -f "$RELEASE_ZIP"
ditto -c -k --keepParent "$SHARE_PLUGIN_DIR" "$RELEASE_ZIP"
ditto -c -k --keepParent "$CLIPBOARD_PLUGIN_DIR" "$RELEASE_ZIP"

echo ""
echo "Signed release complete."
echo "Plugin bundles:"
echo "  - $SHARE_PLUGIN_DIR"
echo "  - $CLIPBOARD_PLUGIN_DIR"
echo ""
echo "Release zip:"
echo "  - $RELEASE_ZIP"
