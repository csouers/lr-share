return {
    LrSdkVersion = 13.0,
    LrSdkMinimumVersion = 6.0,
    LrToolkitIdentifier = 'com.csouers.macossharemenu',
    LrPluginName = 'Mac OS',
    LrPluginInfoUrl = 'https://github.com/csouers/lr-share',

    LrExportMenuItems = {
        {
            title = 'Open Share Menu',
            file = 'ExportToMacOSShareMenuMenuAction.lua',
            enabledWhen = 'photosSelected',
        },
    },

    LrExportServiceProvider = {
        title = 'Mac OS',
        file = 'MacOSShareMenuExportServiceProvider.lua',
        builtInPresetsDir = 'presets',
    },

    VERSION = {
        major = 0,
        minor = 1,
        revision = 0,
        build = 1,
    },
}
