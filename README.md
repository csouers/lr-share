> WARNING: This project was written by LLMs.

# Export from Lightroom to macOS Share Menu or Clipboard

Lightroom Classic plugins (`.lrplugin`) that add custom export destinations:
- **Mac OS**: Share menu
- **Mac OS**: Clipboard

## What it does

**Share Menu Plugin:**
- Registers an Export Service Provider: `Mac OS`
- Opens the native macOS Share menu for rendered files
- Includes preset: "Open Share Menu - JPEG"

**Clipboard Plugin:**
- Registers an Export Service Provider: `Mac OS`
- Copies rendered images to the macOS clipboard
- Includes preset: "Copy To Clipboard - JPEG"

Both plugins:
- Render files, then run one command per export job
- Append all rendered file paths as command arguments
- Fail export if command exits non-zero
- Default export color space to `DisplayP3` (DCI-P3 workflow)
- Use embedded helper apps for reliable execution

## Build

```bash
./build.sh
```

`build.sh` is the canonical build entrypoint. It:
- Builds `helper/dist/LightroomShareHelper.app` (share menu)
- Builds `helper-clipboard/dist/LightroomClipboardHelper.app` (clipboard)
- Packages complete plugin bundles to `dist/`

Optional debug build:

```bash
./build.sh debug
```

## Install (automatic) and then start/restart Lightroom

```bash
./build.sh
./install.sh
```

Default install targets:
- `~/Library/Application Support/Adobe/Lightroom/Modules/MacOSShareMenu.lrplugin`
- `~/Library/Application Support/Adobe/Lightroom/Modules/MacOSClipboard.lrplugin`

Optional custom Modules path:

```bash
./install.sh "/path/to/Adobe/Lightroom/Modules"
```

## Enable in Lightroom Classic

1. Open **File > Plug-in Manager**.
2. Click **Add** and select both plugins from `dist/`.
3. Open **Export...** and pick destination **Mac OS**.
4. Choose from the presets:
   - "Open Share Menu - JPEG"
   - "Copy To Clipboard - JPEG"

There is also a **File > Plug-in Extras > Copy to Clipboard - JPEG** shortcut.

## Signed release (Developer ID + notarization)

Use the dedicated release script when distributing to other machines:

```bash
./release-signed.sh
```

Required environment variables:
- `CODESIGN_IDENTITY` (example: `Developer ID Application: Your Name (TEAMID)`)
- `NOTARY_PROFILE` (name created with `xcrun notarytool store-credentials`)

Example:

```bash
export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="lr-share-notary"
./release-signed.sh
```

Optional debug build:

```bash
./release-signed.sh debug
```

One-time setup for a notary profile in your keychain:

```bash
xcrun notarytool store-credentials "lr-share-notary" \
  --apple-id "you@example.com" \
  --team-id "TEAMID1234" \
  --password "app-specific-password"
```

`release-signed.sh`:
- Builds both plugins via `./build.sh`
- Signs and notarizes both helper apps
- Produces `dist/MacOS-LrPlugins.zip` for distribution

## Built-in Lightroom export presets

Built-in presets are in:

- `plugin-src/MacOSShareMenu.lrplugin/presets/MacOSShareMenu.lrtemplate`
- `clipboard-plugin/MacOSClipboard.lrplugin/presets/CopyToClipboard.lrtemplate`

## Temp files

These plugins use Lightroom temporary rendering (`canExportToTemporaryLocation = true`) and hide export location UI.

- Lightroom owns creation/cleanup of those temporary rendered files.
- Plugin does not manage lifecycle for Lightroom temp output.
- If you add plugin-generated temp artifacts later, those need explicit cleanup.

## File layout

**Share Plugin:**
- `plugin-src/MacOSShareMenu.lrplugin/`
- `plugin-src/MacOSShareMenu.lrplugin/Info.lua`
- `plugin-src/MacOSShareMenu.lrplugin/MacOSShareMenuExportServiceProvider.lua`
- `plugin-src/MacOSShareMenu.lrplugin/CommandPresets.lua`
- `helper/` (Swift source for share helper app)
- `dist/MacOSShareMenu.lrplugin/` (generated install-ready plugin bundle)

**Clipboard Plugin:**
- `clipboard-plugin/MacOSClipboard.lrplugin/`
- `clipboard-plugin/MacOSClipboard.lrplugin/Info.lua`
- `clipboard-plugin/MacOSClipboard.lrplugin/MacOSClipboardExportServiceProvider.lua`
- `helper-clipboard/` (Swift source for clipboard helper app)
- `dist/MacOSClipboard.lrplugin/` (generated install-ready plugin bundle)

The built plugins contain:
- `dist/MacOSShareMenu.lrplugin/Support/LightroomShareHelper.app`
- `dist/MacOSClipboard.lrplugin/Support/LightroomClipboardHelper.app`

## Notes

- This project is actively used and the core export/share/clipboard flow is stable.
- Load both plugins in Lightroom Plugin Manager.
- Keep executable paths absolute unless intentionally using `_PLUGIN.path` for plugin-relative binaries.
- If a command fails, Lightroom export is marked failed and a dialog is shown.