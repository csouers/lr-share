local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrExportSession = import 'LrExportSession'
local LrTasks = import 'LrTasks'

LrTasks.startAsyncTask(function()
    local catalog = LrApplication.activeCatalog()
    local selectedPhotos = catalog:getTargetPhotos()

    if #selectedPhotos == 0 then
        LrDialogs.message('Mac OS Clipboard', 'Select at least one photo first.', 'info')
        return
    end

    local exportSettings = {
        LR_exportServiceProvider = 'com.csouers.macosclipboard',
        LR_exportServiceProviderTitle = 'Mac OS Clipboard',
        LR_format = 'JPEG',
        LR_export_colorSpace = 'DisplayP3',
    }

    local exportSession = LrExportSession {
        photosToExport = selectedPhotos,
        exportSettings = exportSettings,
    }

    exportSession:doExportOnCurrentTask()
end)