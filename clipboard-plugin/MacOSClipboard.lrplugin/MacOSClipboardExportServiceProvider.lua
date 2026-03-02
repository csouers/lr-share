local LrDialogs = import 'LrDialogs'
local LrFileUtils = import 'LrFileUtils'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'

local bind = LrView.bind

local PLUGIN_TITLE = 'Mac OS'

-- Force the export service provider to register by adding this table
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

local function quoteArg(value)
    local escaped = tostring(value):gsub('\\', '\\\\'):gsub('"', '\\"')
    return '"' .. escaped .. '"'
end

local function failRenditions(renditions, message)
    for _, rendition in ipairs(renditions) do
        rendition:uploadFailed(message)
    end
end

function exportProvider.startDialog(propertyTable)
    propertyTable.lrsm_summary = 'Copy rendered images to the macOS clipboard'
end

function exportProvider.sectionsForTopOfDialog(f, _)
    return {
        {
            title = PLUGIN_TITLE,
            synopsis = bind 'lrsm_summary',
            f:static_text {
                title = 'Copies rendered images to the macOS clipboard.',
                fill_horizontal = 1,
            },
        },
    }
end

function exportProvider.processRenderedPhotos(_, exportContext)
    local helperPath = _PLUGIN.path .. "/Support/LightroomClipboardHelper.app/Contents/MacOS/LightroomClipboardHelper"
    
    if not LrFileUtils.exists(helperPath) then
        LrDialogs.message(PLUGIN_TITLE, 'Clipboard helper not found at: ' .. helperPath, 'critical')
        return
    end

    local exportSession = exportContext.exportSession
    local nRenditions = exportSession:countRenditions()
    local progressTitle = nRenditions == 1
        and 'Copying 1 photo to clipboard'
        or string.format('Copying %d photos to clipboard', nRenditions)

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
            rendition:uploadFailed(pathOrMessage or 'Failed to render photo.')
        end
    end

    if #successfulRenditions == 0 then
        return
    end

    -- Build command - direct call to clipboard helper
    local pieces = { quoteArg(helperPath) }
    for _, filePath in ipairs(renderedPaths) do
        table.insert(pieces, quoteArg(filePath))
    end
    local command = table.concat(pieces, ' ')

    local exitCode = LrTasks.execute(command)

    if exitCode ~= 0 then
        local message = string.format('Clipboard copy failed with exit code %s.', tostring(exitCode))
        failRenditions(successfulRenditions, message)
        LrDialogs.message(PLUGIN_TITLE, message, 'critical')
        return
    end
end

return exportProvider