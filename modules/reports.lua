local reports = {}

local constants = require("ExportCells.constants")

local config = nil
local utils = require("ExportCells.utils")
local ui = require("ExportCells.ui")

function reports.setConfig(cfg)
    config = cfg
end

-- =============================================================================
-- LANDMASS REPORT
-- =============================================================================
function reports.getLandmassReport()
    local extents = utils.getLandmassExtents()
    if not extents then
        tes3.messageBox("You are in an interior cell or not in an exterior landmass.")
        return
    end

    local minX, maxX, minY, maxY, visited = extents.minX, extents.maxX, extents.minY, extents.maxY, extents.visited
    local cell = tes3.player.cell
    local startX, startY = cell.gridX, cell.gridY
    local width = maxX - minX + 1
    local height = maxY - minY + 1
    local centerX = math.floor((minX + maxX) / 2)
    local centerY = math.floor((minY + maxY) / 2)
    local cellNameGroups = {}
    local linkedInteriors = {}

    for key, _ in pairs(visited) do
        local x, y = key:match("(-?%d+),(-?%d+)")
        x, y = tonumber(x), tonumber(y)
        local c = tes3.getCell({x = x, y = y})
        if c and c.id then
            local region = c.id:match("^(.-),") or c.id
            region = region:gsub("^%s*(.-)%s*$", "%1")
            cellNameGroups[region] = cellNameGroups[region] or {count = 0, cells = {}}
            cellNameGroups[region].count = cellNameGroups[region].count + 1
            table.insert(cellNameGroups[region].cells, { name = c.id, x = x, y = y })
            for ref in c:iterateReferences(tes3.objectType.door) do
                if ref and ref.destination and ref.destination.cell and ref.destination.cell.isInterior then
                    linkedInteriors[ref.destination.cell.id] = true
                end
            end
        end
    end

    local maxWord, maxCount = nil, 0
    for word, group in pairs(cellNameGroups) do
        if group.count > maxCount then maxWord = word; maxCount = group.count end
    end

    local groupedCellNames = {}
    for word, group in pairs(cellNameGroups) do
        if group.count > 1 then table.insert(groupedCellNames, string.format("%s (%d)", word, group.count)) else table.insert(groupedCellNames, word) end
    end
    table.sort(groupedCellNames)

    local modList = utils.getLandmassMods(visited)
    local filteredMods = {}
    for _, mod in ipairs(modList) do if not constants.vanillaMods[mod] then table.insert(filteredMods, mod) end end

    local objectTypeCounts = {}
    for _, objType in ipairs(config.exportTypes) do objectTypeCounts[objType] = 0 end
    for key, _ in pairs(visited) do
        local x, y = key:match("(-?%d+),(-?%d+)")
        x, y = tonumber(x), tonumber(y)
        local c = tes3.getCell({x = x, y = y})
        if c then
            for _, objType in ipairs(config.exportTypes) do
                for ref in c:iterateReferences(objType) do
                    if ref and not ref.deleted and not ref.disabled then objectTypeCounts[objType] = objectTypeCounts[objType] + 1 end
                end
            end
        end
    end

    local reportLines = {
        string.format("Player Cell: %d, %d", startX, startY),
        string.format("Cell Name: %s", cell.id or "Unknown"),
        "",
        "- LANDMASS EXTENTS -",
        string.format("X Range: %d to %d", minX, maxX),
        string.format("Y Range: %d to %d", minY, maxY),
        string.format("Width:  %d cells", width),
        string.format("Height: %d cells", height),
        string.format("Total Cells: %d", width * height),
        "",
        "- LANDMASS CENTER -",
        string.format("Center Cell: %d, %d", centerX, centerY),
        "",
        "- CELLS INCLUDED IN LANDMASS -",
    }
    local sortedWords = {}
    for word in pairs(cellNameGroups) do table.insert(sortedWords, word) end
    table.sort(sortedWords)
    for _, word in ipairs(sortedWords) do local group = cellNameGroups[word]; table.insert(reportLines, string.format("%s (%d)", word, group.count)) end
    table.insert(reportLines, "")
    table.insert(reportLines, "- MODS FOUND IN LANDMASS -")
    if #filteredMods == 0 then table.insert(reportLines, "(No placed objects with source mod info found)") else for _, mod in ipairs(filteredMods) do table.insert(reportLines, mod) end end
    table.insert(reportLines, "")
    table.insert(reportLines, "- OBJECT TYPES IN LANDMASS -")
    table.insert(reportLines, "Counts only placed references")
    for _, objType in ipairs(config.exportTypes) do local typeName = constants.objectTypeNames[objType] or ("Type " .. tostring(objType)); table.insert(reportLines, string.format("%-12s: %d", typeName, objectTypeCounts[objType])) end

    local highestZ, highestRef, objectCounts, modCounts = nil, nil, {}, {}
    for key, _ in pairs(visited) do
        local x, y = key:match("(-?%d+),(-?%d+)")
        x, y = tonumber(x), tonumber(y)
        local c = tes3.getCell({x = x, y = y})
        if c then
            for ref in c:iterateReferences() do
                if ref and not ref.deleted and not ref.disabled then
                    if ref.position and (not highestZ or ref.position.z > highestZ) then highestZ = ref.position.z; highestRef = ref end
                    local objId = ref.object and ref.object.id or "(unknown)"
                    objectCounts[objId] = (objectCounts[objId] or 0) + 1
                    local modName = ref.sourceMod or "(unknown)"
                    modCounts[modName] = (modCounts[modName] or 0) + 1
                end
            end
        end
    end

    local topMod, topModCount = nil, 0
    for mod, count in pairs(modCounts) do if count > topModCount then topMod = mod; topModCount = count end end
    local objectList = {}
    for objId, count in pairs(objectCounts) do table.insert(objectList, {id = objId, count = count}) end
    table.sort(objectList, function(a, b) return a.count > b.count end)
    table.insert(reportLines, "")
    table.insert(reportLines, "- MISCELLANEOUS STATISTICS -")
    if topMod then table.insert(reportLines, string.format("Top Mod by Placed References: %s (%d)", topMod, topModCount)) else table.insert(reportLines, "Top Mod by Placed References: N/A") end
    table.insert(reportLines, "")
    table.insert(reportLines, "Top 5 Most Common Placed Objects:")
    if #objectList == 0 then table.insert(reportLines, "  (N/A)") else for i = 1, math.min(5, #objectList) do local entry = objectList[i]; table.insert(reportLines, string.format("  %d. %s (%d)", i, entry.id, entry.count)) end end
    table.insert(reportLines, "")
    if highestRef and highestRef.position then table.insert(reportLines, string.format("Highest Measured Point: Z = %.2f (Object: %s)", highestZ, highestRef.object and highestRef.object.id or "(unknown)")) else table.insert(reportLines, "Highest Measured Point: N/A") end
    table.insert(reportLines, "")
    local numLinkedInteriors = 0
    for _ in pairs(linkedInteriors) do numLinkedInteriors = numLinkedInteriors + 1 end
    table.insert(reportLines, string.format("Number of Linked Interiors: %d", numLinkedInteriors))

    if config.exportReports then
        local exportWord = maxWord
        local totalCells = width * height
        if totalCells > 1900 then exportWord = "Main" end
        local fileName = exportWord and (exportWord .. " landmass report.txt") or "landmass report.txt"
        local filePath = string.format("%s\\%s", config.exportFolder:gsub("[\\/]$", ""), fileName)

        local exportLines = {}

        -- =============================================================================
        -- REPORT COMPILATION
        -- =============================================================================
        for _, line in ipairs(reportLines) do table.insert(exportLines, line) end
        table.insert(exportLines, "")
        table.insert(exportLines, "- ALL CELL NAMES IN LANDMASS -")
        local allCells = {}
        for key, _ in pairs(visited) do
            local x, y = key:match("(-?%d+),(-?%d+)")
            x, y = tonumber(x), tonumber(y)
            local cellObj = tes3.getCell({ x = x, y = y })
            local cellName = cellObj and cellObj.id or string.format("%d,%d", x, y)
            table.insert(allCells, string.format("%s (%d, %d)", cellName, x, y))
        end
        table.sort(allCells)
        for _, line in ipairs(allCells) do table.insert(exportLines, line) end

        local file, err = io.open(filePath, "w")
        if file then file:write(table.concat(exportLines, "\n")); file:close(); tes3.messageBox("Report exported: %s", fileName) else tes3.messageBox("Failed to write landmass report.") end
    end
    ui.showReportWindow("Landmass Report", reportLines)
end

-- =============================================================================
-- INTERIOR REPORT
-- =============================================================================
function reports.getInteriorReport()
    local cell = tes3.player.cell
    local objectTypeCounts = {}
    for _, objType in ipairs(config.exportTypes) do objectTypeCounts[objType] = 0 end
    local modSet, mods = {}, {}
    local objectCounts, modCounts = {}, {}
    local highestZ, highestRef = nil, nil
    local linkedInteriors = {}
    for ref in cell:iterateReferences() do
        if ref and not ref.deleted and not ref.disabled then
            if ref.object and objectTypeCounts[ref.object.objectType] ~= nil then objectTypeCounts[ref.object.objectType] = objectTypeCounts[ref.object.objectType] + 1 end
            if ref.sourceMod and not modSet[ref.sourceMod] then modSet[ref.sourceMod] = true; table.insert(mods, ref.sourceMod) end
            local objId = ref.object and ref.object.id or "(unknown)"
            objectCounts[objId] = (objectCounts[objId] or 0) + 1
            local modName = ref.sourceMod or "(unknown)"
            modCounts[modName] = (modCounts[modName] or 0) + 1
            if ref.position and (not highestZ or ref.position.z > highestZ) then highestZ = ref.position.z; highestRef = ref end
            if ref.object and ref.object.objectType == tes3.objectType.door then
                if ref.destination and ref.destination.cell and ref.destination.cell.isInterior then linkedInteriors[ref.destination.cell.id] = true end
            end
        end
    end
    table.sort(mods)
    local topMod, topModCount = nil, 0
    for mod, count in pairs(modCounts) do if count > topModCount then topMod = mod; topModCount = count end end
    local objectList = {}
    for objId, count in pairs(objectCounts) do table.insert(objectList, {id = objId, count = count}) end
    table.sort(objectList, function(a, b) return a.count > b.count end)
    local reportLines = { string.format("Interior Cell: %s", cell.id or "Unknown"), "", "- OBJECT TYPES IN INTERIOR -", "Counts only placed references" }
    for _, objType in ipairs(config.exportTypes) do local typeName = constants.objectTypeNames[objType] or ("Type " .. tostring(objType)); table.insert(reportLines, string.format("%-12s: %d", typeName, objectTypeCounts[objType])) end
    table.insert(reportLines, "")
    table.insert(reportLines, "- MODS FOUND IN INTERIOR -")
    if #mods == 0 then table.insert(reportLines, "(No placed objects with source mod info found)") else for _, mod in ipairs(mods) do table.insert(reportLines, mod) end end
    table.insert(reportLines, "")
    table.insert(reportLines, "- MISCELLANEOUS STATISTICS -")
    if topMod then table.insert(reportLines, string.format("Top Mod by Placed References: %s (%d)", topMod, topModCount)) else table.insert(reportLines, "Top Mod by Placed References: N/A") end
    table.insert(reportLines, "")
    table.insert(reportLines, "Top 5 Most Common Placed Objects:")
    if #objectList == 0 then table.insert(reportLines, "  (N/A)") else for i = 1, math.min(5, #objectList) do local entry = objectList[i]; table.insert(reportLines, string.format("  %d. %s (%d)", i, entry.id, entry.count)) end end
    table.insert(reportLines, "")
    if highestRef and highestRef.position then table.insert(reportLines, string.format("Highest Measured Point: Z = %.2f (Object: %s)", highestZ, highestRef.object and highestRef.object.id or "(unknown)")) else table.insert(reportLines, "Highest Measured Point: N/A") end
    table.insert(reportLines, "")
    local numLinkedInteriors = 0
    for _ in pairs(linkedInteriors) do numLinkedInteriors = numLinkedInteriors + 1 end
    table.insert(reportLines, string.format("Number of Linked Interiors: %d", numLinkedInteriors))
    if config.exportReports then
        local fileName = (cell.id or "interior") .. " interior report.txt"
        local filePath = string.format("%s\\%s", config.exportFolder:gsub("[\\/]$", ""), fileName)
        local file, err = io.open(filePath, "w")
        if file then file:write(table.concat(reportLines, "\n")); file:close(); tes3.messageBox("Report exported: %s", fileName) else tes3.messageBox("Failed to write interior report.") end
    end
    ui.showReportWindow("Interior Report", reportLines)
end

return reports