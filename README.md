> WARNING: This project was written by GPT 5.3 Codex.

# Mac OS

Lightroom Classic plugin (`.lrplugin`) that adds a custom export destination and runs an external command on rendered files.

## What it does

- Registers an Export Service Provider: `Mac OS`
- Lets you choose a bundled command preset from the Export dialog
- Renders files, then runs one command per export job
- Appends all rendered file paths as command arguments
- Fails export if command exits non-zero
- Defaults export color space to `DisplayP3` (DCI-P3 workflow), not sRGB
- Default preset stages files into `/tmp` and runs an embedded helper app so Share menu is not tied to Lightroom temp cleanup timing

## File layout

- `plugin-src/MacOSShareMenu.lrplugin/` (plugin source template)
- `plugin-src/MacOSShareMenu.lrplugin/Info.lua`
- `plugin-src/MacOSShareMenu.lrplugin/MacOSShareMenuExportServiceProvider.lua`
- `plugin-src/MacOSShareMenu.lrplugin/ExportToMacOSShareMenuMenuAction.lua`
- `plugin-src/MacOSShareMenu.lrplugin/CommandPresets.lua`
- `plugin-src/MacOSShareMenu.lrplugin/presets/MacOSShareMenu.lrtemplate`
- `helper/` (Swift source for the embedded helper app)
- `dist/MacOSShareMenu.lrplugin/` (generated install-ready plugin bundle)

The helper app source lives in `helper/`.
The built plugin contains `LightroomShareHelper.app` at `dist/MacOSShareMenu.lrplugin/Support/LightroomShareHelper.app`.

## Build

```bash
cd /Volumes/csouers/lr-share
./build.sh
```

`build.sh` is the canonical build entrypoint. It:
- Builds `helper/dist/LightroomShareHelper.app`
- Packages a complete plugin bundle to `dist/MacOSShareMenu.lrplugin`

Optional debug build:

```bash
./build.sh debug
```

## Install to Lightroom Modules

```bash
cd /Volumes/csouers/lr-share
./build.sh
./install.sh
```

Default install target:
`/Volumes/csouers/Library/Application Support/Adobe/Lightroom/Modules/MacOSShareMenu.lrplugin`

Optional custom Modules path:

```bash
./install.sh "/path/to/Adobe/Lightroom/Modules"
```

## Enable in Lightroom Classic

1. Open **File > Plug-in Manager**.
2. Click **Add** and select `dist/MacOSShareMenu.lrplugin`.
3. Open **Export...** and pick destination **Mac OS**.
4. Choose a command preset in the plugin section.

There is also a **File > Plug-in Extras > Open Share Menu** shortcut.

## Command presets

Edit:

`plugin-src/MacOSShareMenu.lrplugin/CommandPresets.lua`

Then run `./build.sh` again to package changes into `dist/MacOSShareMenu.lrplugin`.

The shipped default (`share_menu_helper`) uses:
`_PLUGIN.path .. "/Support/LightroomShareHelper.app/Contents/MacOS/LightroomShareHelper"`

Schema:

```lua
return {
    defaultPresetId = 'your_preset_id',
    presets = {
        {
            id = 'your_preset_id',
            title = 'Your preset title',
            executable = '/absolute/path/to/executable',
            args = { '--flag', 'value' },
            stageFiles = false,
            description = 'Optional description shown in Export dialog',
        },
    },
}
```

Behavior:

- Plugin builds: `executable + args + rendered file paths`
- File paths are appended as separate quoted arguments
- Command runs once per export job
- Optional `stageFiles = true` copies rendered files to a plugin temp folder before command execution

## Temp files

This plugin uses Lightroom temporary rendering (`canExportToTemporaryLocation = true`) and hides export location UI.

- Lightroom owns creation/cleanup of those temporary rendered files.
- Plugin does not manage lifecycle for Lightroom temp output.
- If you add plugin-generated temp artifacts later, those need explicit cleanup.

## Notes

- This project is actively used and the core export/share flow is stable.
- Load only `dist/MacOSShareMenu.lrplugin` in Lightroom Plugin Manager.
- One-time cleanup: if you still have an old source folder at `/Volumes/csouers/lr-share/MacOSShareMenu.lrplugin`, remove it to avoid confusion.
- Keep executable paths absolute unless intentionally using `_PLUGIN.path` for plugin-relative binaries.
- If a command fails, Lightroom export is marked failed and a dialog is shown.
