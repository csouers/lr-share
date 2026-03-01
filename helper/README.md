# LightroomShareHelper

macOS helper app used by the `MacOSShareMenu.lrplugin` export destination.

When Lightroom opens this app with exported files, it immediately displays the macOS native Share picker (`NSSharingServicePicker`) for those files.

## Build

Requirements:
- macOS with Xcode command line tools
- Swift 5.9+

Primary build command (from repo root):

```bash
cd /Volumes/csouers/lr-share
./build.sh
```

This is the canonical workflow and produces the install-ready plugin at:

`/Volumes/csouers/lr-share/dist/MacOSShareMenu.lrplugin`

Helper-only build (internal/advanced use):

Commands:

```bash
cd /Volumes/csouers/lr-share/helper
chmod +x scripts/build-app-bundle.sh
scripts/build-app-bundle.sh
```

Output app bundle:

`/Volumes/csouers/lr-share/helper/dist/LightroomShareHelper.app`

## Test outside Lightroom

```bash
open -a /Volumes/csouers/lr-share/helper/dist/LightroomShareHelper.app /path/to/image.jpg
```

You should see only the native Share picker (no visible helper window).

## Plugin integration setup

1. Run `/Volumes/csouers/lr-share/build.sh`.
2. In Lightroom Classic, use **File > Plug-in Manager > Add** and select:
   - `/Volumes/csouers/lr-share/dist/MacOSShareMenu.lrplugin`

## Notes

- This helper is used by the plugin's default share-menu export flow.
- `helper/scripts/build-app-bundle.sh` is an implementation detail used by root `build.sh`.
- For distribution to other machines, add app signing and notarization.
