# LightroomShareHelper

macOS helper app used by the `MacOSShareMenu.lrplugin` export destination.

When Lightroom opens this app with exported files, it immediately displays the macOS native Share picker (`NSSharingServicePicker`) for those files.

## Build

Requirements:
- macOS with Xcode command line tools
- Swift 5.9+

Primary build command (from repo root):

```bash
cd ~/lr-share
./build.sh
```

This is the canonical workflow and produces the install-ready plugin at:

`~/lr-share/dist/MacOSShareMenu.lrplugin`

Helper-only build (internal/advanced use):

Commands:

```bash
cd ~/lr-share/helper
chmod +x scripts/build-app-bundle.sh
scripts/build-app-bundle.sh
```

Output app bundle:

`~/lr-share/helper/dist/LightroomShareHelper.app`

## Test outside Lightroom

```bash
open -a ~/lr-share/helper/dist/LightroomShareHelper.app /path/to/image.jpg
```

You should see only the native Share picker (no visible helper window).

## Plugin integration setup

1. Run `~/lr-share/build.sh`.
2. In Lightroom Classic, use **File > Plug-in Manager > Add** and select:
   - `~/lr-share/dist/MacOSShareMenu.lrplugin`

## Sign and notarize for distribution

For distribution outside your local machine, run the root release script:

```bash
cd ~/lr-share
export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="lr-share-notary"
./release-signed.sh
```

What this does for the embedded helper app:
- Signs `dist/MacOSShareMenu.lrplugin/Support/LightroomShareHelper.app` with hardened runtime
- Submits it to Apple notarization with `notarytool`
- Staples and validates the notarization ticket

Verification commands:

```bash
codesign --verify --strict --verbose=2 ~/lr-share/dist/MacOSShareMenu.lrplugin/Support/LightroomShareHelper.app
spctl --assess --type execute --verbose=4 ~/lr-share/dist/MacOSShareMenu.lrplugin/Support/LightroomShareHelper.app
xcrun stapler validate -v ~/lr-share/dist/MacOSShareMenu.lrplugin/Support/LightroomShareHelper.app
```

## Notes

- This helper is used by the plugin's default share-menu export flow.
- `helper/scripts/build-app-bundle.sh` is an implementation detail used by root `build.sh`.
- For signed distribution, use `~/lr-share/release-signed.sh`.
