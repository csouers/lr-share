return {
    LrSdkVersion = 13.0,
    LrSdkMinimumVersion = 6.0,
    LrToolkitIdentifier = 'com.csouers.macosclipboard',
    LrPluginName = 'Mac OS',
    LrPluginInfoUrl = 'https://github.com/csouers/lr-share',

    LrExportMenuItems = {
        {
            title = 'Copy to Clipboard - JPEG',
            file = 'ExportToClipboardMenuAction.lua',
            enabledWhen = 'photosSelected',
        },
    },

    LrExportServiceProvider = {
        title = 'Mac OS: Clipboard',
        file = 'MacOSClipboardExportServiceProvider.lua',
    },

    VERSION = {
        major = 0,
        minor = 1,
        revision = 0,
        build = 1,
    },
}