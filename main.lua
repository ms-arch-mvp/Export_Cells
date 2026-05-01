local export = require("ExportCells.export")
local grid = require("ExportCells.infrastructure.grid")
local teleport = require("ExportCells.infrastructure.teleport")

local wearables = require("ExportCells.modules.wearables")

local defaultConfig = require("ExportCells.config")
local ui = require("ExportCells.ui")
local utils = require("ExportCells.utils")

local config

-- Load config
if defaultConfig.useSavedConfig then
    config = mwse.loadConfig("Export Cells", defaultConfig)
else
    config = defaultConfig
end

wearables.setConfig(config)

-- Provide config and cancellation to all modules via the orchestrator
export.setConfig(config)

-- Shared cancellation reference
local exportCancelRequestedRef = { [1] = false }
export.setCancelRef(exportCancelRequestedRef)

event.register("modConfigReady", function()
    require("ExportCells.mcm").registerModConfig()
end)

-- =============================================================================
-- FUNCTIONS
-- =============================================================================

local function prompt1x1GridSizeAndExport()
    local buttonSizes = table.copy(config.gridSizes1x1)
    local custom = tonumber(config.customGridSize1x1)
    if custom then table.insert(buttonSizes, custom) end

    local exportMode = config.defaultExportModes["1x1"]
    local title = "Select grid of 1x1s" .. ui.getModeText(exportMode)
    ui.create1x1Menu(buttonSizes, title, function(size) export.exportGridWithSize(size, "1x1") end, function() export.exportLandmassGrid("1x1") end)
end

local function prompt2x2GridSizeAndExport()
    local buttonSizes = table.copy(config.gridSizes2x2)
    local custom = tonumber(config.customGridSize2x2)
    if custom then table.insert(buttonSizes, custom) end

    local exportMode = config.defaultExportModes["2x2"]
    local title = "Select grid of 2x2s" .. ui.getModeText(exportMode)
    ui.createGridSizeMenu("2x2", title, buttonSizes, teleport.moveToNearestMultipleOf2Cell, function()
        export.exportLandmassGrid("2x2")
    end, function(size)
        export.exportGridWithSize(size, "2x2")
    end)
end

local function prompt3x3GridSizeAndExport()
    local buttonSizes = table.copy(config.gridSizes3x3)
    local custom = tonumber(config.customGridSize3x3)
    if custom then table.insert(buttonSizes, custom) end

    local exportMode = config.defaultExportModes["3x3"]
    local title = "Select grid of 3x3s" .. ui.getModeText(exportMode)
    ui.createGridSizeMenu("3x3", title, buttonSizes, teleport.moveToNearestMultipleOf3Cell, function()
        export.exportLandmassGrid("3x3")
    end, function(size)
        export.exportGridWithSize(size, "3x3")
    end)
end

-- =============================================================================
-- EVENT HANDLERS & HOTKEY REGISTRATION
-- =============================================================================

-- Ctrl+Shift+E: Export Active Cells
local function onKeyDownE(e)
    if tes3ui.menuMode() then return end
    if e.isControlDown and e.isShiftDown then
        export.exportActiveCells()
    end
end

-- Shift+1: 1x1 Grid Export Menu
local function onKeyDown1(e)
    if tes3ui.menuMode() then return end
    if e.isShiftDown then
        if tes3.player.cell.isInterior then
            export.exportInteriorsFromSameMod("1x1")
        else
            prompt1x1GridSizeAndExport()
        end
    end
end

-- Shift+2: 2x2 Grid Export Menu
local function onKeyDown2(e)
    if tes3ui.menuMode() then return end
    if e.isShiftDown then
        if tes3.player.cell.isInterior then
            export.exportInteriorsFromSameMod("2x2")
        else
            prompt2x2GridSizeAndExport()
        end
    end
end

-- Shift+3: 3x3 Grid Export Menu
local function onKeyDown3(e)
    if tes3ui.menuMode() then return end
    if e.isShiftDown then
        if tes3.player.cell.isInterior then
            export.exportInteriorsFromSameMod("3x3")
        else
            prompt3x3GridSizeAndExport()
        end
    end
end

-- Shift+R: Landmass or Interior Report
local function onKeyDownR(e)
    if tes3ui.menuMode() then return end
    if e.isControlDown and e.isShiftDown then
        if tes3.player.cell.isInterior then
            export.getInteriorReport()
        else
            export.getLandmassReport()
        end
    end
end

-- Ctrl+9: Export Records (Opens UI Menu)
local function onKeyDown9(e)
    if tes3ui.menuMode() then return end
    if e.isControlDown then
        export.promptExportRecords()
    end
end

-- Shift+0: Export Objects By Mesh Folder (Opens UI Menu)
local function onKeyDown0(e)
    if tes3ui.menuMode() then return end
    if e.isShiftDown then
        if export.isInProgress() then
            tes3.messageBox("An export is already in progress.")
            return
        end
        export.exportObjectsByMeshFolder()
    end
end

-- Space: Cancel ongoing export
local function onKeyDownSpace(e)
    if export.isInProgress and export.isInProgress() and e.keyCode == tes3.scanCode.space then
        exportCancelRequestedRef[1] = true
    end
end

-- Shift+C: Add Wearables To NPC Call
local function onKeyDownC(e)
    if tes3ui.menuMode() then return end
    if e.isShiftDown then
        wearables.showInputDialog()
    end
end

-- Shift+N: Export Character Call
local function onKeyDownCharacter(e)
    if tes3ui.menuMode() then return end
    if e.isShiftDown then
        export.exportCharacter()
    end
end

-- Register all hotkeys
event.register("keyDown", onKeyDownE, { filter = tes3.scanCode.e })
event.register("keyDown", onKeyDown1, { filter = tes3.scanCode["1"] })
event.register("keyDown", onKeyDown2, { filter = tes3.scanCode["2"] })
event.register("keyDown", onKeyDown3, { filter = tes3.scanCode["3"] })
event.register("keyDown", onKeyDown9, { filter = tes3.scanCode["9"] })
event.register("keyDown", onKeyDown0, { filter = tes3.scanCode["0"] })
event.register("keyDown", onKeyDownR, { filter = tes3.scanCode.r })
event.register("keyDown", onKeyDownC, { filter = tes3.scanCode.c })
event.register("keyDown", onKeyDownCharacter, { filter = tes3.scanCode.n })
event.register("keyDown", onKeyDownSpace)