local export = {}

local constants = require("ExportCells.constants")
local grid = require("ExportCells.infrastructure.grid")
local teleport = require("ExportCells.infrastructure.teleport")

local charactersModule = require("ExportCells.modules.characters")
local interiorsModule = require("ExportCells.modules.interiors")
local jsonModule = require("ExportCells.modules.jsons")
local nifsModule = require("ExportCells.modules.nifs")
local objectsModule = require("ExportCells.modules.objects")
local reportsModule = require("ExportCells.modules.reports")

local ui = require("ExportCells.ui")
local utils = require("ExportCells.utils")

local config = nil
local exportCancelRequestedRef = { [1] = false }
local exportInProgress = false
local exportReturnPos = nil
local exportReturnCell = nil

function export.setConfig(cfg)
    config = cfg

    grid.setConfig(cfg)
    teleport.setConfig(cfg)

    charactersModule.setConfig(cfg)
    interiorsModule.setConfig(cfg)
    jsonModule.setConfig(cfg)
    nifsModule.setConfig(cfg)
    objectsModule.setConfig(cfg)
    reportsModule.setConfig(cfg)

    utils.setConfig(cfg)
end

function export.setCancelRef(ref)
    exportCancelRequestedRef = ref or exportCancelRequestedRef
    
    interiorsModule.setCancelRef(exportCancelRequestedRef)
    objectsModule.setCancelRef(exportCancelRequestedRef)
    teleport.setCancelRef(exportCancelRequestedRef)
end

-- =============================================================================
-- EXPORT LOGIC & ORCHESTRATION
-- =============================================================================
local exportActiveCells, export2x2, export3x3

local function exportCells(regionCells, exportMode, currentIndex, totalCount)
    nifsModule.export(regionCells, exportMode, currentIndex, totalCount)
end

exportActiveCells = function(exportMode, currentIndex, totalCount)
    exportMode = exportMode or config.defaultExportModes["active"]
    if exportMode == constants.EXPORT_MODE.DISABLED then return end
    local activeCells = tes3.getActiveCells()
    exportCells(activeCells, exportMode, currentIndex, totalCount)
end

export2x2 = function(exportMode, currentIndex, totalCount)
    exportMode = exportMode or config.defaultExportModes["2x2"]
    if exportMode == constants.EXPORT_MODE.DISABLED then return end
    local activeCells = tes3.getActiveCells()
    local regionCells = {}

    if not tes3.player.cell.isInterior then
        local cell = tes3.player.cell
        local startX, startY = cell.gridX, cell.gridY
        for dx = 0, 1 do
            for dy = 0, -1, -1 do
                local x, y = startX + dx, startY + dy
                local c = tes3.getCell({ x = x, y = y })
                if c then table.insert(regionCells, c) end
            end
        end
    else
        regionCells = activeCells
    end
    exportCells(regionCells, exportMode, currentIndex, totalCount)
end

export3x3 = function(exportMode, currentIndex, totalCount)
    exportMode = exportMode or config.defaultExportModes["3x3"]
    if exportMode == constants.EXPORT_MODE.DISABLED then return end
    local activeCells = tes3.getActiveCells()
    exportCells(activeCells, exportMode, currentIndex, totalCount)
end

interiorsModule.setExportActiveCellsRef(exportActiveCells)
interiorsModule.onComplete = function(cancelled, singleCell, gridType)
    exportInProgress = false
    exportCancelRequestedRef[1] = false
    if not singleCell and exportReturnPos and exportReturnCell then
        tes3.positionCell{ reference = tes3.player, position = exportReturnPos, cell = exportReturnCell }
    end
    utils.restoreExportConsoleToggles()
    local exportMode = config.defaultExportModes[gridType] or config.defaultExportModes["active"]
    if cancelled then
        tes3.messageBox(utils.traversalOrExportMsg(exportMode, "Export cancelled. Returned to starting cell.", "Traversal cancelled. Returned to starting cell."))
    elseif singleCell then
        tes3.messageBox(utils.traversalOrExportMsg(exportMode, "Export completed.", "Traversal completed."))
    else
        tes3.messageBox(utils.traversalOrExportMsg(exportMode, "Export completed. Returned to starting cell.", "Traversal completed. Returned to starting cell."))
    end
end

-- =============================================================================
-- GRID EXPORT CONTROLLER
-- =============================================================================
local function writeExteriorsTxt(cell, gridType, exportMode, size)
    if not config.exportReports then return end
    if exportMode == constants.EXPORT_MODE.DISABLED then return end
    if gridType == "1x1" or gridType == "2x2" or gridType == "3x3" then
        local exportFolder = config.exportFolder and config.exportFolder:gsub("[\\/]$", "") or ""
        if exportFolder ~= "" then lfs.mkdir(exportFolder) end
        local fileName = "Exteriors.txt"
        local filePath = string.format("%s\\%s", exportFolder, fileName)
        local file = io.open(filePath, "w")
        if file then
            local cellNameStr = ""
            if cell.id and cell.id ~= "" then
                cellNameStr = string.format("%d, %d %s", cell.gridX, cell.gridY, cell.id)
            else
                cellNameStr = string.format("%d, %d Wilderness", cell.gridX, cell.gridY)
            end
            local extentStr = "N/A"
            if size == "Landmass" then
                extentStr = "Landmass"
            elseif type(size) == "number" then
                local gridPositions = size * size
                if gridType == "2x2" then
                    extentStr = string.format("%dx%d (%dx%d cells, %d total)", size, size, size * 2, size * 2, gridPositions * 4)
                elseif gridType == "3x3" then
                    extentStr = string.format("%dx%d (%dx%d cells, %d total)", size, size, size * 3, size * 3, gridPositions * 9)
                else
                    extentStr = string.format("%dx%d (%d cells)", size, size, gridPositions)
                end
            end
            
            local outputStr = string.format("Starting Cell: %s\nGrid Type: %s\nExtent: %s\n", cellNameStr, gridType, extentStr)
            
            if exportMode == constants.EXPORT_MODE.LAYER then
                local layerName = constants.objectTypeNames and constants.objectTypeNames[config.exportLayerType] or tostring(config.exportLayerType)
                outputStr = outputStr .. string.format("Layer: %s\n", layerName)
            end

            file:write(outputStr)
            file:close()
        end
    end
end

function export.exportGridWithSize(size, gridType)
    utils.setupExportConsoleToggles()
    local cell = tes3.player.cell
    local exportMode = config.defaultExportModes[gridType]

    if cell.isInterior then
        exportReturnPos = tes3.player.position:copy()
        exportReturnCell = cell
        exportInProgress = true
        interiorsModule.exportInteriorsFromSameMod(gridType)
        return
    end

    writeExteriorsTxt(cell, gridType, exportMode, size)

    local startX, startY = cell.gridX, cell.gridY
    exportReturnPos = tes3.player.position:copy()
    exportReturnCell = cell

    local sequence = {}
    local offsets = {}
    if gridType == "3x3" then offsets = grid.get3x3GridOffsets(size)
    elseif gridType == "2x2" then offsets = grid.get2x2GridOffsets(size)
    else offsets = grid.get1x1GridOffsets(size) end

    for _, offset in ipairs(offsets) do
        table.insert(sequence, { x = startX + offset.x, y = startY + offset.y })
    end

    exportInProgress = true
    exportCancelRequestedRef[1] = false

    local function finishExport(cancelled)
        exportInProgress = false
        exportCancelRequestedRef[1] = false
        if exportReturnPos and exportReturnCell then
            tes3.positionCell{ reference = tes3.player, position = exportReturnPos, cell = exportReturnCell, suppressFader = true }
        end
        utils.restoreExportConsoleToggles()
        if cancelled then
            tes3.messageBox(utils.traversalOrExportMsg(exportMode, "Export cancelled.", "Traversal cancelled."))
        else
            tes3.messageBox(utils.traversalOrExportMsg(exportMode, "Export completed.", "Traversal completed."))
        end
    end

    local function processNextCell(index)
        if exportCancelRequestedRef[1] then finishExport(true); return end
        if index > #sequence then finishExport(false); return end
        local coord = sequence[index]
        teleport.tryTeleportToCell(coord.x, coord.y, tes3.player.position.z, function()
            timer.start({ duration = config.teleportDelaySeconds, callback = function()
                if exportCancelRequestedRef[1] then finishExport(true); return end
                if gridType == "3x3" then
                    export3x3(exportMode, index, #sequence)
                elseif gridType == "2x2" then
                    export2x2(exportMode, index, #sequence)
                else
                    exportActiveCells(exportMode, index, #sequence)
                end
                timer.start({ duration = config.teleportDelaySeconds, callback = function() processNextCell(index + 1) end })
            end })
        end)
    end

    tes3.messageBox(utils.traversalOrExportMsg(exportMode, "Starting %s export (%dx%d grid)", "Starting %s traversal (%dx%d grid)"), gridType, size, size)
    timer.start({ duration = config.teleportDelaySeconds, callback = function() processNextCell(1) end })
end

-- =============================================================================
-- LANDMASS EXPORT CONTROLLER
-- =============================================================================
function export.exportLandmassGrid(gridType)
    utils.setupExportConsoleToggles()
    if exportInProgress then return end

    local extents = utils.getLandmassExtents()
    if not extents then return end

    local anchors = grid.getGridAnchors(gridType, extents.minX, extents.maxX, extents.minY, extents.maxY, extents.visited)
    local exportMode = config.defaultExportModes[gridType]

    writeExteriorsTxt(tes3.player.cell, gridType, exportMode, "Landmass")

    exportReturnPos = tes3.player.position:copy()
    exportReturnCell = tes3.player.cell
    exportInProgress = true
    exportCancelRequestedRef[1] = false

    local function finishExport(cancelled)
        exportInProgress = false
        exportCancelRequestedRef[1] = false
        if exportReturnPos and exportReturnCell then
            tes3.positionCell{ reference = tes3.player, position = exportReturnPos, cell = exportReturnCell }
        end
        utils.restoreExportConsoleToggles()
        tes3.messageBox(utils.traversalOrExportMsg(exportMode,
            cancelled and "Landmass export cancelled." or "Landmass export completed.",
            cancelled and "Landmass traversal cancelled." or "Landmass traversal completed."))
    end

    local function processAnchor(index)
        if exportCancelRequestedRef[1] then finishExport(true); return end
        if index > #anchors then finishExport(false); return end
        local anchor = anchors[index]
        teleport.tryTeleportToCell(anchor.x, anchor.y, tes3.player.position.z, function()
            timer.start({ duration = config.teleportDelaySeconds, callback = function()
                if exportCancelRequestedRef[1] then finishExport(true); return end

                local regionCells = {}
                local step = (gridType == "2x2") and 1 or 1 -- anchors are already grid-aware
                if gridType == "2x2" then
                    for dx = 0, 1 do for dy = 0, 1 do
                        local c = tes3.getCell({x = anchor.x + dx, y = anchor.y + dy})
                        if c then table.insert(regionCells, c) end
                    end end
                else
                    for dx = -1, 1 do for dy = -1, 1 do
                        local c = tes3.getCell({x = anchor.x + dx, y = anchor.y + dy})
                        if c then table.insert(regionCells, c) end
                    end end
                end

                exportCells(regionCells, exportMode, index, #anchors)
                timer.start({ duration = config.teleportDelaySeconds, callback = function() processAnchor(index + 1) end })
            end })
        end)
    end

    processAnchor(1)
end

-- =============================================================================
-- PUBLIC API
-- =============================================================================
function export.getLandmassReport() reportsModule.getLandmassReport() end
function export.getInteriorReport() reportsModule.getInteriorReport() end
function export.exportInteriorsFromSameMod(gridType)
    utils.setupExportConsoleToggles()
    exportReturnPos = tes3.player.position:copy()
    exportReturnCell = tes3.player.cell
    exportInProgress = true
    exportCancelRequestedRef[1] = false
    interiorsModule.exportInteriorsFromSameMod(gridType)
end

-- Misc
function export.isInProgress() 
    return exportInProgress or objectsModule.isInProgress()
end
function export.exportObjectsByMeshFolder(folder)
    if folder then
        objectsModule.exportObjectsByMeshFolder(folder)
    else
        ui.createMeshFolderInputDialog({
            onConfirm = function(folderInput)
                if string.find(string.lower(folderInput), "%.esp$") or string.find(string.lower(folderInput), "%.esm$") then
                    local objs = objectsModule.collectByMod(folderInput)
                    if objs and #objs > 0 then
                        local map = { [folderInput] = objs }
                        objectsModule.exportObjectsByMeshFolder({ folderInput }, map)
                    else
                        tes3.messageBox("No objects found for mod: %s", folderInput)
                    end
                else
                    local f, groups = objectsModule.discoverFolders(folderInput)
                    if f and #f > 0 then
                        objectsModule.exportObjectsByMeshFolder(f, groups)
                    else
                        tes3.messageBox("No matching folders found.")
                    end
                end
            end,
            onFlagged = function(modFilter)
                local objs = objectsModule.collectFlagged(modFilter)
                if objs and #objs > 0 then
                    local map = { ["Flagged"] = objs }
                    objectsModule.exportObjectsByMeshFolder({"Flagged"}, map)
                else
                    if modFilter and modFilter ~= "" then
                        tes3.messageBox("No matching objects found in flagged file for mod: %s", modFilter)
                    else
                        tes3.messageBox("No matching objects found in flagged file.")
                    end
                end
            end,
            onAllFolders = function(resumeFolder)
                objectsModule.exportLists()
                local folders, groups = objectsModule.discoverFolders()
                if folders and #folders > 0 then
                    if resumeFolder and resumeFolder ~= "" then
                        local queued = {}
                        local found = false
                        for _, f in ipairs(folders) do
                            if found or f == resumeFolder then
                                found = true
                                table.insert(queued, f)
                            end
                        end
                        if found then
                            objectsModule.exportObjectsByMeshFolder(queued, groups)
                        else
                            tes3.messageBox("Folder '%s' not found. Exporting all.", resumeFolder)
                            objectsModule.exportObjectsByMeshFolder(folders, groups)
                        end
                    else
                        objectsModule.exportObjectsByMeshFolder(folders, groups)
                    end
                else
                    tes3.messageBox("No mesh folders found.")
                end
            end,
            onAllRecords = function(resumePart)
                export.exportMasterRecordList(resumePart)
            end,
            onCancel = function()
                tes3.messageBox("Export cancelled.")
            end
        })
    end
end

function export.exportMasterRecordList(resumePart)
    objectsModule.exportMasterRecordList(resumePart)
end

export.exportCells = exportCells
export.export2x2 = export2x2
export.export3x3 = export3x3
export.exportActiveCells = exportActiveCells

function export.exportCharacter()
    local ref = tes3.getPlayerTarget()
    charactersModule.export(ref)
end

return export