local interiors = {}

local config = nil
local constants = require("ExportCells.constants")
local exportCancelRequestedRef = nil
local teleport = require("ExportCells.infrastructure.teleport")
local utils = require("ExportCells.utils")

function interiors.setConfig(cfg)
    config = cfg
end

function interiors.setCancelRef(ref)
    exportCancelRequestedRef = ref
end

-- =============================================================================
-- INTERNAL REFERENCES
-- =============================================================================
local exportActiveCellsRef = nil
function interiors.setExportActiveCellsRef(fn)
    exportActiveCellsRef = fn
end

-- =============================================================================
-- INTERIOR SCANNING & EXPORT
-- =============================================================================
function interiors.exportInteriorsFromSameMod(gridType)
    gridType = gridType or "active"

    if not config then
        tes3.messageBox("Export initialization error: configuration missing.")
        return
    end

    local exportMode = config.defaultExportModes and config.defaultExportModes[gridType] or constants.EXPORT_MODE.STANDARD

    -- For interiors, preserve JSON mode if selected, otherwise fallback to STANDARD
    local interiorExportMode = constants.EXPORT_MODE.STANDARD
    if exportMode == constants.EXPORT_MODE.DISABLED then
        interiorExportMode = constants.EXPORT_MODE.DISABLED
    elseif exportMode == constants.EXPORT_MODE.JSON then
        interiorExportMode = constants.EXPORT_MODE.JSON
    end

    local cell = tes3.player.cell
    if not cell.isInterior then tes3.messageBox("This command only works when in an interior cell."); return end

    -- Determine the source mod for the current cell
    local modName = nil
    for _, c in pairs(tes3.dataHandler.nonDynamicData.cells) do
        if c.id == cell.id and c.sourceMod and c.sourceMod ~= "" then
            modName = c.sourceMod
            break
        end
    end
    if not modName or modName == "" then
        for ref in cell:iterateReferences() do
            if ref and ref.sourceMod and ref.sourceMod ~= "" then
                modName = ref.sourceMod
                break
            end
        end
    end

    if not modName or modName == "" then
        tes3.messageBox("Could not determine source mod for the current interior cell.")
        return
    end

    local cellNames = {}
    local seenCells = {}
    local modNameLower = modName:lower():gsub("^%s*(.-)%s*$", "%1")

    tes3.messageBox("Scanning cells for %s... This may take a moment.", modName)

    local function addCell(id)
        if not seenCells[id] then
            table.insert(cellNames, id)
            seenCells[id] = true
        end
    end

    for _, c in pairs(tes3.dataHandler.nonDynamicData.cells) do
        if c.isInterior and c.id then
             local source = c.sourceMod
            if source and source:lower():gsub("^%s*(.-)%s*$", "%1") == modNameLower then
                addCell(c.id)
             end
        end
    end

    for _, c in pairs(tes3.dataHandler.nonDynamicData.cells) do
        if c.isInterior and c.id and not seenCells[c.id] then
            for ref in c:iterateReferences() do
                if ref.sourceMod and ref.sourceMod:lower():gsub("^%s*(.-)%s*$", "%1") == modNameLower then
                    addCell(c.id)
                    break
                end
            end
        end
    end

    if cell.id then addCell(cell.id) end

    table.sort(cellNames)

    local startId = cell.id
    local targets = {}
    for _, id in ipairs(cellNames) do
        if id ~= startId then table.insert(targets, id) end
    end

    if config.exportReports then
        local exportList = {}
        for _, id in ipairs(cellNames) do table.insert(exportList, id) end
        table.sort(exportList)

        local exportFolder = config.exportFolder and config.exportFolder:gsub("[\\/]$", "") or ""
        if exportFolder ~= "" then lfs.mkdir(exportFolder) end
        local safeModName = (modName or "mod"):gsub("[\\/:*?\"<>|]", "_")
        local fileName = string.format("%s interiors.txt", safeModName)
        local filePath = string.format("%s\\%s", exportFolder, fileName)
        local file = io.open(filePath, "w")
        if file then
            file:write(string.format("Interiors in mod: %s\nTotal: %d\n\n", modName or "(unknown)", #exportList))
            for _, id in ipairs(exportList) do file:write(id .. "\n") end
            file:close()
            tes3.messageBox("Interiors list exported: %s", fileName)
        end
    end

    local totalCount = #targets + 1

    local function finishExport(cancelled, singleCell)
        if interiors.onComplete then interiors.onComplete(cancelled, singleCell) end
    end

    tes3.messageBox(utils.traversalOrExportMsg(interiorExportMode,
        string.format("Starting interior export for mod: %s (%d cells) | Press SPACE to cancel", modName, totalCount),
        string.format("Starting interior traversal for mod: %s (%d cells) | Press SPACE to cancel", modName, totalCount)))

    -- Export starting cell
    if interiorExportMode ~= constants.EXPORT_MODE.DISABLED then
        if exportActiveCellsRef then exportActiveCellsRef(interiorExportMode, 1, totalCount) end
    else
        tes3.messageBox(utils.traversalOrExportMsg(interiorExportMode, "", string.format("Traversed to starting cell: %s (1 of %d)", startId, totalCount)))
    end

    -- If this was the only interior, finish immediately (no return teleport needed)
    if #targets == 0 then
        timer.start({ duration = config.teleportDelaySeconds, callback = function() finishExport(false, true) end })
        return
    end

    local function processNext(index)
        if exportCancelRequestedRef[1] then finishExport(true); return end
        if index > #targets then finishExport(false); return end
        local targetId = targets[index]
        local safeId = targetId:gsub('"', '\\"')
        local cmd = string.format('coc "%s"', safeId)

        if config.interiorGarbageCollection then
            collectgarbage("collect")
        end

        tes3.runLegacyScript{ command = cmd }

        timer.start({ duration = config.teleportDelaySeconds, callback = function()
            if exportCancelRequestedRef[1] then finishExport(true); return end
            if interiorExportMode ~= constants.EXPORT_MODE.DISABLED then
                if exportActiveCellsRef then exportActiveCellsRef(interiorExportMode, index + 1, totalCount) end
            else
                tes3.messageBox(utils.traversalOrExportMsg(interiorExportMode, "", string.format("Traversed to: %s (%d of %d)", targetId, index + 1, totalCount)))
            end
            timer.start({ duration = config.teleportDelaySeconds, callback = function()
                processNext(index + 1)
            end })
        end })
    end

    timer.start({ duration = config.teleportDelaySeconds, callback = function() processNext(1) end })
end

return interiors