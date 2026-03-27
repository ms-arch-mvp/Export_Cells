local ui = {}
local tes3ui = tes3ui
local timer = timer

local function safeMenuDestroy(menu)
    if menu and not menu.destroyed then
        menu:destroy()
    end
end

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

-- Generic grid size menu
function ui.createGridSizeMenu(gridType, title, buttonSizes, moveFunction, landmassAutoCallback, onSelect)
    local menu = tes3ui.createMenu{ id = "ExportCell_" .. gridType .. "SizePrompt", fixedFrame = true }
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

    local headerText = mainBlock:createLabel{ text = title }
    headerText.color = tes3ui.getPalette("header_color")
    headerText.borderBottom = 12

    local topSpacer = mainBlock:createBlock()
    topSpacer.heightProportional = 1.0

    local buttonBlock = mainBlock:createBlock()
    buttonBlock.flowDirection = "top_to_bottom"
    buttonBlock.childAlignX = 0.0
    buttonBlock.autoHeight = true
    buttonBlock.paddingLeft = 95

    for _, size in ipairs(buttonSizes) do
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
        local button = buttonBlock:createButton{ text = string.format("%dx%d (%dx%d cells, %d total)", size, size, cellsH, cellsV, totalCells) }
        button.borderBottom = 4
        button.autoHeight = true
        button:register("mouseClick", function()
            safeMenuDestroy(menu)
            tes3ui.leaveMenuMode()
            -- If a moveFunction is provided and player needs moving, perform it first, then call onSelect
            if moveFunction and not tes3.player.cell.isInterior then
                if moveFunction() then
                    timer.frame.delayOneFrame(function()
                        if onSelect then onSelect(size) end
                    end)
                    return
                end
            end
            if onSelect then
                onSelect(size)
            else
                tes3.messageBox("No callback provided for grid size selection.")
            end
        end)
    end

    if landmassAutoCallback then
        local utils = require("ExportCells.utils")
        local grid = require("ExportCells.infrastructure.grid")
        local extents = utils.getLandmassExtents()
        local autoText
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
            autoText = string.format("Landmass %dx%d (%dx%d cells, %d total)", exportH, exportV, cellW, cellH, cellW*cellH)
        else
            autoText = "Landmass (N/A)"
        end
        local autoButton = buttonBlock:createButton{ text = autoText }
        autoButton.borderBottom = 4
        autoButton.autoHeight = true
        autoButton:register("mouseClick", function()
            safeMenuDestroy(menu)
            tes3ui.leaveMenuMode()
            landmassAutoCallback()
        end)
    end

    do
        local utils = require("ExportCells.utils")
        local extents = utils.getLandmassExtents()
        if extents then
            local minX, maxX, minY, maxY = extents.minX, extents.maxX, extents.minY, extents.maxY
            local centerX = math.floor((minX + maxX) / 2)
            local centerY = math.floor((minY + maxY) / 2)
            local teleport = require("ExportCells.infrastructure.teleport")
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

function ui.getModeText(exportMode)
    local config = require("ExportCells.config")
    if exportMode == config.EXPORT_MODE.LANDSCAPE_ONLY then
        return " (Landscape Only)"
    elseif exportMode == config.EXPORT_MODE.EXCLUDE_LANDSCAPE then
        return " (Exclude Landscape)"
    elseif exportMode == config.EXPORT_MODE.LAYER then
        return " (Layer)"
    elseif exportMode == config.EXPORT_MODE.PROXY then
        return " (Proxy)"
    elseif exportMode == config.EXPORT_MODE.JSON then
        return " (JSON)"
    elseif exportMode == config.EXPORT_MODE.DISABLED then
        return " (Export Disabled)"
    else
        return " (Everything)"
    end
end

function ui.create1x1Menu(title, onSizeSelected, onLandmassSelected)
    local buttonSizes = {1, 3, 5, 7, 9}
    local title = title or "Select grid of 1x1s"
    local menu = tes3ui.createMenu{ id = "ExportCell_1x1SizePrompt", fixedFrame = true }
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

    local headerText = mainBlock:createLabel{ text = title }
    headerText.color = tes3ui.getPalette("header_color")
    headerText.borderBottom = 12

    local topSpacer = mainBlock:createBlock()
    topSpacer.heightProportional = 1.0

    local buttonBlock = mainBlock:createBlock()
    buttonBlock.flowDirection = "top_to_bottom"
    buttonBlock.childAlignX = 0.0
    buttonBlock.autoHeight = true
    buttonBlock.paddingLeft = 95

    for _, size in ipairs(buttonSizes) do
        local totalCells = size * size
        local button = buttonBlock:createButton{ text = string.format("%dx%d (%d cells)", size, size, totalCells) }
        button.borderBottom = 4
        button.autoHeight = true
        button:register("mouseClick", function()
            safeMenuDestroy(menu)
            tes3ui.leaveMenuMode()
            if onSizeSelected then onSizeSelected(size) end
        end)
    end

    local utils = require("ExportCells.utils")
    local extents = utils.getLandmassExtents()
    local landmassText
    if extents then
        local minX, maxX, minY, maxY, visited = extents.minX, extents.maxX, extents.minY, extents.maxY, extents.visited
        local cellCount
        if require("ExportCells.config").exportEmptyLandmassCells then
            local width = maxX - minX + 1
            local height = maxY - minY + 1
            cellCount = width * height
        else
            cellCount = 0
            for _ in pairs(visited) do cellCount = cellCount + 1 end
        end
        landmassText = string.format("Landmass (%dx%d, %d cells)", maxX - minX + 1, maxY - minY + 1, cellCount)
    else
        landmassText = "Landmass (N/A)"
    end
    local landmassButton = buttonBlock:createButton{ text = landmassText }
    landmassButton.borderBottom = 4
    landmassButton.autoHeight = true
    landmassButton:register("mouseClick", function()
        safeMenuDestroy(menu)
        tes3ui.leaveMenuMode()
        if onLandmassSelected then onLandmassSelected() end
    end)

    do
        local extents = utils.getLandmassExtents()
        if extents then
            local minX, maxX, minY, maxY = extents.minX, extents.maxX, extents.minY, extents.maxY
            local centerX = math.floor((minX + maxX) / 2)
            local centerY = math.floor((minY + maxY) / 2)
            local teleport = require("ExportCells.infrastructure.teleport")
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

function ui.createMeshFolderInputDialog(params)
    local onConfirm = params.onConfirm
    local onFlagged = params.onFlagged
    local onAllFolders = params.onAllFolders
    local onCancel = params.onCancel

    local GUI_ID_InputDialog = tes3ui.registerID("ExportObjects:InputDialog")
    local GUI_ID_InputField = tes3ui.registerID("ExportObjects:InputField")

    local menu = tes3ui.createMenu({ id = GUI_ID_InputDialog, fixedFrame = true })
    menu.minWidth = 350
    menu.minHeight = 120
    menu.autoHeight = true
    menu.autoWidth = true

    local title = menu:createLabel({ text = "Enter mesh folder to search (e.g. 'f' or 'oaab\\f'):" })
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
        menu:destroy()
        tes3ui.leaveMenuMode()
        if onFlagged then onFlagged() end
    end)

    local batchButton = buttonBlock:createButton({ text = "All Folders" })
    batchButton.borderRight = 10
    batchButton:register("mouseClick", function()
        local inputString = input.text:gsub("^%s+", ""):gsub("%s+$", "")
        menu:destroy()
        tes3ui.leaveMenuMode()
        if onAllFolders then onAllFolders(inputString) end
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

return ui