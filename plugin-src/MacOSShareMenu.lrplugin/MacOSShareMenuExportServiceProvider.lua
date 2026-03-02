local LrDialogs = import 'LrDialogs'
local LrFileUtils = import 'LrFileUtils'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'

local bind = LrView.bind

local PLUGIN_TITLE = 'Mac OS'

math.randomseed(os.time())

local function loadPresetConfig()
    local path = _PLUGIN.path .. '/CommandPresets.lua'
    local ok, data = pcall(dofile, path)
    if not ok then
        return nil, string.format('Could not load CommandPresets.lua: %s', tostring(data))
    end

    if type(data) ~= 'table' or type(data.presets) ~= 'table' then
        return nil, 'CommandPresets.lua must return { presets = { ... } }.'
    end

    return data, nil
end

local function firstPresetId(config)
    for _, preset in ipairs(config.presets or {}) do
        if type(preset.id) == 'string' and preset.id ~= '' then
            return preset.id
        end
    end
    return nil
end

local function findPreset(config, presetId)
    if type(presetId) ~= 'string' or presetId == '' then
        return nil
    end

    for _, preset in ipairs(config.presets or {}) do
        if preset.id == presetId then
            return preset
        end
    end

    return nil
end

local function quoteArg(value)
    local escaped = tostring(value):gsub('\\', '\\\\'):gsub('"', '\\"')
    return '"' .. escaped .. '"'
end

local function failRenditions(renditions, message)
    for _, rendition in ipairs(renditions) do
        rendition:uploadFailed(message)
    end
end

local function setSynopsis(propertyTable, preset)
    if not preset then
        propertyTable.lrsm_presetSummary = 'No command preset selected'
        return
    end

    local title = preset.title or preset.id or 'Unnamed preset'
    local description = preset.description
    if type(description) == 'string' and description ~= '' then
        propertyTable.lrsm_presetSummary = string.format('%s: %s', title, description)
    else
        propertyTable.lrsm_presetSummary = title
    end
end

local function buildCommand(preset, renderedPaths)
    if type(preset.executable) ~= 'string' or preset.executable == '' then
        return nil, 'Preset executable path is empty.'
    end

    if not LrFileUtils.exists(preset.executable) then
        return nil, string.format('Executable not found: %s', preset.executable)
    end

    local pieces = { quoteArg(preset.executable) }

    if type(preset.args) == 'table' then
        for _, arg in ipairs(preset.args) do
            table.insert(pieces, quoteArg(arg))
        end
    end

    for _, filePath in ipairs(renderedPaths) do
        table.insert(pieces, quoteArg(filePath))
    end

    return table.concat(pieces, ' '), nil
end

local function leafName(path)
    local name = tostring(path):match('([^/]+)$')
    if name and name ~= '' then
        return name
    end
    return tostring(path)
end

local function removeStagingDirectory(stagingDirectory)
    if not stagingDirectory or stagingDirectory == '' then
        return
    end

    LrTasks.execute('/bin/rm -rf ' .. quoteArg(stagingDirectory))
end

local function stageRenderedPaths(renderedPaths)
    local stagingDirectory = string.format(
        '/tmp/lightroom-share-menu-staging/%d-%06d',
        os.time(),
        math.random(0, 999999)
    )

    local mkdirExit = LrTasks.execute('/bin/mkdir -p ' .. quoteArg(stagingDirectory))
    if mkdirExit ~= 0 then
        return nil, nil, 'Failed to create staging directory for share menu files.'
    end

    local stagedPaths = {}
    for index, sourcePath in ipairs(renderedPaths) do
        local destinationPath = string.format('%s/%03d_%s', stagingDirectory, index, leafName(sourcePath))
        local copyExit = LrTasks.execute('/bin/cp -f ' .. quoteArg(sourcePath) .. ' ' .. quoteArg(destinationPath))
        if copyExit ~= 0 then
            removeStagingDirectory(stagingDirectory)
            return nil, nil, string.format('Failed to stage exported file: %s', tostring(sourcePath))
        end
        table.insert(stagedPaths, destinationPath)
    end

    return stagedPaths, stagingDirectory, nil
end

local exportProvider = {
    hideSections = {
        'exportLocation',
        'fileNaming',
        'outputSharpening',
        'watermarking',
        'postProcessing',
    },
    canExportToTemporaryLocation = true,
    allowFileFormats = {
        'JPEG',
    },
    allowColorSpaces = {
        'DisplayP3',
    },
}

function exportProvider.startDialog(propertyTable)
    local config, _ = loadPresetConfig()

    local selectedPreset = config and findPreset(config, propertyTable.lrsm_presetId)
    if not selectedPreset and config then
        local fallbackId = config.defaultPresetId or firstPresetId(config)
        propertyTable.lrsm_presetId = fallbackId
        selectedPreset = findPreset(config, fallbackId)
    end

    setSynopsis(propertyTable, selectedPreset)

    propertyTable:addObserver('lrsm_presetId', function()
        local currentConfig = select(1, loadPresetConfig())
        local preset = currentConfig and findPreset(currentConfig, propertyTable.lrsm_presetId) or nil
        setSynopsis(propertyTable, preset)
    end)
end

function exportProvider.sectionsForTopOfDialog(f, _)
    local config, errorMessage = loadPresetConfig()

    if not config then
        return {
            {
                title = PLUGIN_TITLE,
                f:static_text {
                    title = errorMessage,
                    fill_horizontal = 1,
                },
            },
        }
    end

    local items = {}
    for _, preset in ipairs(config.presets or {}) do
        if type(preset.id) == 'string' and preset.id ~= '' then
            table.insert(items, {
                title = preset.title or preset.id,
                value = preset.id,
            })
        end
    end

    if #items == 0 then
        return {
            {
                title = PLUGIN_TITLE,
                f:static_text {
                    title = 'No presets found in CommandPresets.lua.',
                    fill_horizontal = 1,
                },
            },
        }
    end

    return {
        {
            title = PLUGIN_TITLE,
            synopsis = bind 'lrsm_presetSummary',

            f:row {
                spacing = f:label_spacing(),
                f:static_text {
                    title = 'Command preset:',
                },
                f:popup_menu {
                    value = bind 'lrsm_presetId',
                    items = items,
                    immediate = true,
                    width_in_chars = 34,
                },
            },

            f:static_text {
                title = 'Runs once per export job and appends all rendered file paths as command arguments.',
                fill_horizontal = 1,
            },
        },
    }
end

function exportProvider.processRenderedPhotos(_, exportContext)
    local config, configError = loadPresetConfig()
    local selectedPreset = nil

    if config then
        local presetId = exportContext.propertyTable.lrsm_presetId
        
        if presetId then
            selectedPreset = findPreset(config, presetId)
        end
        
        if not selectedPreset then
            local fallbackId = config.defaultPresetId or firstPresetId(config)
            selectedPreset = findPreset(config, fallbackId)
        end
    end

    local exportSession = exportContext.exportSession
    local nRenditions = exportSession:countRenditions()
    local progressTitle = nRenditions == 1
        and 'Preparing 1 photo for Mac OS'
        or string.format('Preparing %d photos for Mac OS', nRenditions)

    local progressScope = exportContext:configureProgress {
        title = progressTitle,
    }

    local successfulRenditions = {}
    local renderedPaths = {}

    for _, rendition in exportContext:renditions { stopIfCanceled = true } do
        local success, pathOrMessage = rendition:waitForRender()

        if progressScope:isCanceled() then
            return
        end

        if success then
            table.insert(successfulRenditions, rendition)
            table.insert(renderedPaths, pathOrMessage)
        else
            rendition:uploadFailed(pathOrMessage or 'Failed to render photo for command execution.')
        end
    end

    if #successfulRenditions == 0 then
        return
    end

    if not config then
        local message = configError or 'Command preset configuration is invalid.'
        failRenditions(successfulRenditions, message)
        LrDialogs.message(PLUGIN_TITLE, message, 'critical')
        return
    end

    if not selectedPreset then
        local message = 'No valid command preset selected.'
        failRenditions(successfulRenditions, message)
        LrDialogs.message(PLUGIN_TITLE, message, 'critical')
        return
    end

    local commandPaths = renderedPaths
    local stagedDirectory = nil

    if selectedPreset.stageFiles == true then
        local stagedPaths, stagingPath, stageError = stageRenderedPaths(renderedPaths)
        if not stagedPaths then
            local message = stageError or 'Failed to stage exported files for sharing.'
            failRenditions(successfulRenditions, message)
            LrDialogs.message(PLUGIN_TITLE, message, 'critical')
            return
        end

        commandPaths = stagedPaths
        stagedDirectory = stagingPath
    end

    local command, commandError = buildCommand(selectedPreset, commandPaths)
    if not command then
        removeStagingDirectory(stagedDirectory)
        failRenditions(successfulRenditions, commandError)
        LrDialogs.message(PLUGIN_TITLE, commandError, 'critical')
        return
    end

    local exitCode = LrTasks.execute(command)

    removeStagingDirectory(stagedDirectory)

    if exitCode ~= 0 then
        local message = string.format('Command failed with exit code %s.', tostring(exitCode))
        failRenditions(successfulRenditions, message)
        LrDialogs.message(PLUGIN_TITLE, message, 'critical')
        return
    end
end

return exportProvider
