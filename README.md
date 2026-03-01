# LightroomShareHelper

Minimal macOS helper app for Lightroom Classic `Post-Processing > Open in Other Application`.

When Lightroom opens this app with exported files, it immediately displays the macOS native Share picker (`NSSharingServicePicker`) for those files.

## Build

Requirements:
- macOS with Xcode command line tools
- Swift 5.9+

Commands:

```bash
cd /Volumes/csouers/lr-share
chmod +x scripts/build-app-bundle.sh
scripts/build-app-bundle.sh
```

Output app bundle:

`/Volumes/csouers/lr-share/dist/LightroomShareHelper.app`

## Test outside Lightroom

```bash
open -a /Volumes/csouers/lr-share/dist/LightroomShareHelper.app /path/to/image.jpg
```

You should see only the native Share picker (no visible helper window).

## Lightroom Classic setup

1. Open `Export...`
2. In `Post-Processing`, set `After Export` to `Open in Other Application...`
3. Select `/Volumes/csouers/lr-share/dist/LightroomShareHelper.app`
4. Save as an export preset (for one-click reuse)

## Notes

- This is a working draft focused on the local flow.
- For distribution to other machines, add app signing and notarization.
