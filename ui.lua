local ui = {}

local grid = require("ExportCells.infrastructure.grid")
local teleport = require("ExportCells.infrastructure.teleport")

local config = require("ExportCells.config")
local utils = require("ExportCells.utils")
local constants = require("ExportCells.constants")

local tes3ui = tes3ui
local timer = timer

-- =============================================================================
-- HELPERS
-- =============================================================================

local function safeMenuDestroy(menu)
    if menu and not menu.destroyed then
        menu:destroy()
    end
end

function ui.getModeText(exportMode)
    if exportMode == constants.EXPORT_MODE.LANDSCAPE_ONLY then
        return " (Landscape Only)"
    elseif exportMode == constants.EXPORT_MODE.EXCLUDE_LANDSCAPE then
        return " (Exclude Landscape)"
    elseif exportMode == constants.EXPORT_MODE.LAYER then
        return " (Layer)"
    elseif exportMode == constants.EXPORT_MODE.JSON then
        return " (JSON)"
    elseif exportMode == constants.EXPORT_MODE.DISABLED then
        return " (Export Disabled)"
    else
        return " (Everything)"
    end
end

-- =============================================================================
-- SHARED GRID MENU BUILDER
-- =============================================================================

local function createBaseGridMenu(params)
    local menu = tes3ui.createMenu{ id = params.id, fixedFrame = true }
    menu.minWidth = 200
    menu.alignX = 0.5
    menu.alignY = 0.5

    local mainBlock = menu:createThinBorder()
    mainBlock.flowDirection = "top_to_bottom"
    mainBlock.childAlignX = 0.5
    mainBlock.paddingLeft = 8
    mainBlock.paddingRight = 8
    mainBlock.paddingTop = 8
    mainBlock.paddingBottom = 8

    local headerText = mainBlock:createLabel{ text = params.title }
    headerText.color = tes3ui.getPalette("header_color")
    headerText.borderBottom = 12

    local topSpacer = mainBlock:createBlock()
    topSpacer.heightProportional = 1.0

    local buttonBlock = mainBlock:createBlock()
    buttonBlock.flowDirection = "top_to_bottom"
    buttonBlock.childAlignX = 0.0
    buttonBlock.autoHeight = true
    buttonBlock.paddingLeft = 95

    for _, size in ipairs(params.buttonSizes) do
        local buttonLabel = params.getButtonLabel(size)
        local button = buttonBlock:createButton{ text = buttonLabel }
        button.borderBottom = 4
        button.autoHeight = true
        button:register("mouseClick", function()
            safeMenuDestroy(menu)
            tes3ui.leaveMenuMode()
            if params.onSizeClick then params.onSizeClick(size) end
        end)
    end

    if params.onLandmassClick then
        local autoButton = buttonBlock:createButton{ text = params.getLandmassLabel() }
        autoButton.borderBottom = 4
        autoButton.autoHeight = true
        autoButton:register("mouseClick", function()
            safeMenuDestroy(menu)
            tes3ui.leaveMenuMode()
            params.onLandmassClick()
        end)
    end

    do
        local extents = utils.getLandmassExtents()
        if extents then
            local minX, maxX, minY, maxY = extents.minX, extents.maxX, extents.minY, extents.maxY
            local centerX = math.floor((minX + maxX) / 2)
            local centerY = math.floor((minY + maxY) / 2)
            local teleportButton = buttonBlock:createButton{ text = "Teleport to Landmass Center" }
            teleportButton.borderBottom = 4
            teleportButton.autoHeight = true
            teleportButton:register("mouseClick", function()
                safeMenuDestroy(menu)
                tes3ui.leaveMenuMode()
                teleport.tryTeleportToCell(centerX, centerY, tes3.player.position.z)
                tes3.messageBox("Teleported to landmass center: %d, %d", centerX, centerY)
            end)
        end
    end

    local bottomSpacer = mainBlock:createBlock()
    bottomSpacer.heightProportional = 1.0

    local buttonBar = mainBlock:createBlock()
    buttonBar.flowDirection = "left_to_right"
    buttonBar.widthProportional = 1.0
    buttonBar.autoHeight = true

    local rightSpacer = buttonBar:createBlock()
    rightSpacer.widthProportional = 1.0
    rightSpacer.autoHeight = true

    local cancelButton = buttonBar:createButton{ text = "Cancel" }
    cancelButton.borderTop = 8
    cancelButton.autoWidth = true
    cancelButton.autoHeight = true
    cancelButton:register("mouseClick", function()
        safeMenuDestroy(menu)
        tes3ui.leaveMenuMode()
    end)

    menu:register("keyEscape", function()
        cancelButton:triggerEvent("mouseClick")
    end)

    menu:updateLayout()
    buttonBlock.width = mainBlock.width
    menu:updateLayout()
    tes3ui.enterMenuMode(menu.id)
end

-- =============================================================================
-- MENUS
-- =============================================================================

function ui.createGridSizeMenu(gridType, title, buttonSizes, moveFunction, landmassAutoCallback, onSelect)
    createBaseGridMenu({
        id = "ExportCell_" .. gridType .. "SizePrompt",
        title = title,
        buttonSizes = buttonSizes,
        getButtonLabel = function(size)
            local gridPositions = size * size
            local totalCells, cellsH, cellsV
            if gridType == "2x2" then
                totalCells = gridPositions * 4
                cellsH = size * 2
                cellsV = size * 2
            else
                totalCells = gridPositions * 9
                cellsH = size * 3
                cellsV = size * 3
            end
            return string.format("%dx%d (%dx%d cells, %d total)", size, size, cellsH, cellsV, totalCells)
        end,
        onSizeClick = function(size)
            if moveFunction and not tes3.player.cell.isInterior then
                if moveFunction() then
                    timer.frame.delayOneFrame(function()
                        if onSelect then onSelect(size) end
                    end)
                    return
                end
            end
            if onSelect then onSelect(size) end
        end,
        getLandmassLabel = function()
            local extents = utils.getLandmassExtents()
            if extents then
                local minX, maxX, minY, maxY, visited = extents.minX, extents.maxX, extents.minY, extents.maxY, extents.visited
                local anchors = grid.getGridAnchors(gridType, minX, maxX, minY, maxY, visited)
                local anchorXs, anchorYs = {}, {}
                for _, anchor in ipairs(anchors) do anchorXs[anchor.x] = true; anchorYs[anchor.y] = true end
                local exportH, exportV = 0, 0
                for _ in pairs(anchorXs) do exportH = exportH + 1 end
                for _ in pairs(anchorYs) do exportV = exportV + 1 end
                local cellW, cellH
                if gridType == "2x2" then
                    cellW = exportH * 2
                    cellH = exportV * 2
                else
                    cellW = exportH * 3
                    cellH = exportV * 3
                end
                return string.format("Landmass %dx%d (%dx%d cells, %d total)", exportH, exportV, cellW, cellH, cellW*cellH)
            end
            return "Landmass (N/A)"
        end,
        onLandmassClick = landmassAutoCallback
    })
end

function ui.create1x1Menu(buttonSizes, title, onSizeSelected, onLandmassSelected)
    createBaseGridMenu({
        id = "ExportCell_1x1SizePrompt",
        title = title or "Select grid of 1x1s",
        buttonSizes = buttonSizes,
        getButtonLabel = function(size)
            return string.format("%dx%d (%d cells)", size, size, size * size)
        end,
        onSizeClick = onSizeSelected,
        getLandmassLabel = function()
            local extents = utils.getLandmassExtents()
            if extents then
                local minX, maxX, minY, maxY, visited = extents.minX, extents.maxX, extents.minY, extents.maxY, extents.visited
                local cellCount
                if config.exportEmptyLandmassCells then
                    local width = maxX - minX + 1
                    local height = maxY - minY + 1
                    cellCount = width * height
                else
                    cellCount = 0
                    for _ in pairs(visited) do cellCount = cellCount + 1 end
                end
                return string.format("Landmass (%dx%d, %d cells)", maxX - minX + 1, maxY - minY + 1, cellCount)
            end
            return "Landmass (N/A)"
        end,
        onLandmassClick = onLandmassSelected
    })
end

-- =============================================================================
-- INPUT DIALOGS
-- =============================================================================

function ui.createMeshFolderInputDialog(params)
    local onConfirm = params.onConfirm
    local onFlagged = params.onFlagged
    local onAllFolders = params.onAllFolders
    local onAllRecords = params.onAllRecords
    local onCancel = params.onCancel

    local GUI_ID_InputDialog = tes3ui.registerID("ExportObjects:InputDialog")
    local GUI_ID_InputField = tes3ui.registerID("ExportObjects:InputField")

    local menu = tes3ui.createMenu({ id = GUI_ID_InputDialog, fixedFrame = true })
    menu.minWidth = 500
    menu.minHeight = 120
    menu.autoHeight = true
    menu.autoWidth = true

    local title = menu:createLabel({ text = "Search and resume by folder, mod, or part #:" })
    title.borderBottom = 15

    local inputBlock = menu:createBlock()
    inputBlock.autoHeight = true
    inputBlock.widthProportional = 1.0

    local input = inputBlock:createTextInput({ id = GUI_ID_InputField })
    input.widthProportional = 1.0
    input.height = 30
    input.borderAllSides = 5

    local buttonBlock = menu:createBlock()
    buttonBlock.widthProportional = 1.0
    buttonBlock.autoHeight = true
    buttonBlock.childAlignX = 1.0
    buttonBlock.borderTop = 20

    local okButton = buttonBlock:createButton({ text = "OK" })
    okButton.borderRight = 10
    okButton:register("mouseClick", function()
        local inputString = input.text:gsub("^%s+", ""):gsub("%s+$", "")
        menu:destroy()
        tes3ui.leaveMenuMode()
        if onConfirm then onConfirm(inputString) end
    end)

    local flaggedButton = buttonBlock:createButton({ text = "Flagged" })
    flaggedButton.borderRight = 10
    flaggedButton:register("mouseClick", function()
        local inputString = input.text:gsub("^%s+", ""):gsub("%s+$", "")
        menu:destroy()
        tes3ui.leaveMenuMode()
        if onFlagged then onFlagged(inputString) end
    end)

    local batchButton = buttonBlock:createButton({ text = "All Folders" })
    batchButton.borderRight = 10
    batchButton:register("mouseClick", function()
        local inputString = input.text:gsub("^%s+", ""):gsub("%s+$", "")
        menu:destroy()
        tes3ui.leaveMenuMode()
        if onAllFolders then onAllFolders(inputString) end
    end)

    local recordsButton = buttonBlock:createButton({ text = "All Records" })
    recordsButton.borderRight = 10
    recordsButton:register("mouseClick", function()
        local inputString = input.text:gsub("^%s+", ""):gsub("%s+$", "")
        menu:destroy()
        tes3ui.leaveMenuMode()
        if onAllRecords then onAllRecords(inputString) end
    end)

    local cancelButton = buttonBlock:createButton({ text = "Cancel" })
    cancelButton:register("mouseClick", function()
        menu:destroy()
        tes3ui.leaveMenuMode()
        if onCancel then onCancel() end
    end)

    menu:updateLayout()
    tes3ui.enterMenuMode(GUI_ID_InputDialog)
    tes3ui.acquireTextInput(input)
end

-- =============================================================================
-- REPORTS
-- =============================================================================

function ui.showReportWindow(title, lines)
    local menuId = "ExportCells_ReportWindow"
    local existing = tes3ui.findMenu(menuId)
    if existing then safeMenuDestroy(existing) end

    local menu = tes3ui.createMenu{ id = menuId, fixedFrame = true }
    menu.minWidth = 800
    menu.minHeight = 650
    menu.alignX = 0.5
    menu.alignY = 0.5

    local mainBlock = menu:createThinBorder()
    mainBlock.flowDirection = "top_to_bottom"
    mainBlock.childAlignX = 0.5
    mainBlock.widthProportional = 1.0
    mainBlock.heightProportional = 1.0
    mainBlock.paddingAllSides = 12

    local header = mainBlock:createLabel{ text = title }
    header.color = tes3ui.getPalette("header_color")
    header.borderBottom = 8

    local scroll = mainBlock:createVerticalScrollPane()
    scroll.widthProportional = 1.0
    scroll.heightProportional = 1.0

    for i = 1, #lines do
        local text = lines[i]
        if text:match("^%- .+ %-$") then
            local label = scroll:createLabel{ text = text }
            label.color = tes3ui.getPalette("big_header_color")
        else
            scroll:createLabel{ text = text }
        end
    end

    local buttonBar = mainBlock:createBlock()
    buttonBar.flowDirection = "left_to_right"
    buttonBar.widthProportional = 1.0
    buttonBar.autoHeight = true

    local rightSpacer = buttonBar:createBlock()
    rightSpacer.widthProportional = 1.0

    local closeButton = buttonBar:createButton{ text = "Close" }
    closeButton:register("mouseClick", function()
        safeMenuDestroy(menu)
        tes3ui.leaveMenuMode()
    end)

    menu:register("keyEscape", function()
        closeButton:triggerEvent("mouseClick")
    end)

    menu:updateLayout()
    tes3ui.enterMenuMode(menu.id)
end

return ui