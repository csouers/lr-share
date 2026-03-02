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
PLUGIN_DIR="$DIST_DIR/MacOSShareMenu.lrplugin"
HELPER_APP="$PLUGIN_DIR/Support/LightroomShareHelper.app"
HELPER_ZIP="$DIST_DIR/LightroomShareHelper.notarize.zip"
PLUGIN_ZIP="$DIST_DIR/MacOSShareMenu.lrplugin.zip"

echo "Building unsigned plugin bundle..."
"$BUILD_SCRIPT" "$BUILD_CONFIG"

if [[ ! -d "$PLUGIN_DIR" ]]; then
  echo "Built plugin bundle not found: $PLUGIN_DIR" >&2
  exit 1
fi

if [[ ! -d "$HELPER_APP" ]]; then
  echo "Helper app not found inside plugin: $HELPER_APP" >&2
  exit 1
fi

echo "Signing helper app bundle..."
codesign --force --timestamp --options runtime --sign "$CODESIGN_IDENTITY" "$HELPER_APP"

echo "Verifying signature..."
codesign --verify --strict --verbose=2 "$HELPER_APP"

echo "Preparing helper app zip for notarization..."
rm -f "$HELPER_ZIP"
ditto -c -k --keepParent "$HELPER_APP" "$HELPER_ZIP"

echo "Submitting helper app for notarization..."
NOTARY_OUTPUT="$(xcrun notarytool submit "$HELPER_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json)"
printf '%s\n' "$NOTARY_OUTPUT"

if ! printf '%s\n' "$NOTARY_OUTPUT" | grep -Eq '"status"[[:space:]]*:[[:space:]]*"Accepted"'; then
  echo "Notarization did not return status Accepted." >&2
  echo "Temporary notarization archive retained for debugging: $HELPER_ZIP" >&2
  exit 1
fi

echo "Stapling notarization ticket to helper app..."
xcrun stapler staple -v "$HELPER_APP"

echo "Validating stapled ticket..."
xcrun stapler validate -v "$HELPER_APP"

echo "Running Gatekeeper assessment..."
spctl --assess --type execute --verbose=4 "$HELPER_APP"

echo "Creating signed plugin zip artifact..."
rm -f "$PLUGIN_ZIP"
ditto -c -k --keepParent "$PLUGIN_DIR" "$PLUGIN_ZIP"

rm -f "$HELPER_ZIP"

echo
echo "Signed release complete."
echo "Plugin bundle:"
echo "$PLUGIN_DIR"
echo
echo "Plugin zip:"
echo "$PLUGIN_ZIP"
