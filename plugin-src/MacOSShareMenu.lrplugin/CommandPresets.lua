local pluginPath = (_PLUGIN and _PLUGIN.path) or ""
local embeddedHelperBinary = pluginPath .. "/Support/LightroomShareHelper.app/Contents/MacOS/LightroomShareHelper"

return {
    defaultPresetId = 'share_menu_helper',
    presets = {
        {
            id = 'share_menu_helper',
            title = 'Show macOS Share menu',
            executable = embeddedHelperBinary,
            args = {},
            stageFiles = true,
            description = 'Stages files to /tmp, then runs the embedded helper binary to show NSSharingServicePicker.',
        },
    }
}
