local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrExportSession = import 'LrExportSession'
local LrTasks = import 'LrTasks'

local function loadPresetConfig()
    local path = _PLUGIN.path .. '/CommandPresets.lua'
    local ok, data = pcall(dofile, path)
    if not ok or type(data) ~= 'table' then
        return nil
    end
    return data
end

local function defaultPresetId(config)
    if config and type(config.defaultPresetId) == 'string' and config.defaultPresetId ~= '' then
        return config.defaultPresetId
    end

    if config and type(config.presets) == 'table' then
        for _, preset in ipairs(config.presets) do
            if type(preset.id) == 'string' and preset.id ~= '' then
                return preset.id
            end
        end
    end

    return nil
end

LrTasks.startAsyncTask(function()
    local catalog = LrApplication.activeCatalog()
    local selectedPhotos = catalog:getTargetPhotos()

    if #selectedPhotos == 0 then
        LrDialogs.message('Mac OS', 'Select at least one photo first.', 'info')
        return
    end

    local presetConfig = loadPresetConfig()
    local presetId = defaultPresetId(presetConfig)

    local exportSettings = {
        LR_exportServiceProvider = 'com.csouers.macossharemenu',
        LR_exportServiceProviderTitle = 'Mac OS',
        LR_format = 'JPEG',
        LR_export_colorSpace = 'DisplayP3',
    }

    if presetId then
        exportSettings.lrsm_presetId = presetId
    end

    local exportSession = LrExportSession {
        photosToExport = selectedPhotos,
        exportSettings = exportSettings,
    }

    exportSession:doExportOnCurrentTask()
end)
