local utils = {}

-- Utility helpers used by main.lua and ui.lua

local config = nil
local constants = require("ExportCells.constants")

local function resetAnimation(ref)
    if not ref.animationData then
        return
    end

    local timings = tes3.getAnimationActionTiming({
        reference = tes3.player,
        group = tes3.animationGroup.idle
    })

    local startTime = timings["Start"]
    if not startTime then
        return
    end

    ref.sceneNode:update({ controllers = true, time = startTime })
end

function utils.resetAnimation(ref)
    resetAnimation(ref)
end

function utils.bakeActor(ref)
    if not ref or not ref.sceneNode then return nil end

    local invTransform = ref.sceneNode.worldTransform:invert()
    local root = niNode.new()

    for shape in table.traverse(ref.sceneNode.children) do
        if shape:isInstanceOfType(tes3.niType.NiTriShape) and not shape:isAppCulled() then
            local t = invTransform * shape.worldTransform
            local clone = shape:clone()
            if clone.skinInstance then
                clone:applySkinDeform()
            end
            clone.name = ""
            clone:copyTransforms(t)
            root:attachChild(clone)
        end
    end

    local objId = (ref.object.id or "unknown"):gsub("%x%x%x%x%x%x%x%x$", "")
    root.name = objId
    root:copyTransforms(ref.sceneNode)
    utils.clean(root)
    root:update()
    
    return root
end

function utils.setConfig(cfg)
    config = cfg
end

-- Strips any leading "data files" segment (any case, either slash style) from a
-- folder value, so resolveExportFolder can re-add it exactly once.
local function stripDataFilesPrefix(folder)
    folder = (folder or ""):gsub("[\\/]+$", "")
    folder = folder:gsub("^[Dd][Aa][Tt][Aa]%s+[Ff][Ii][Ll][Ee][Ss][\\/]+", "")
    return folder
end

-- Computes cfg.exportFolder (the fully resolved "data files\<name>" path every
-- export module reads directly) from cfg.exportFolderName (the bare folder
-- name edited via MCM). Call once on the resolved config table (see
-- main.lua/mcm.lua) -- every other module reads config.exportFolder directly
-- and expects it to already be fully resolved, so this must run before any of
-- them do. Deliberately does NOT write back into cfg.exportFolderName -- that
-- field is what the MCM text field is bound to, and must stay a bare name, not
-- get overwritten with the resolved "data files\..." value (that was the bug:
-- an earlier version of this function normalized cfg.exportFolder in place,
-- which is the same field MCM edits, so the field displayed the resolved path
-- instead of a bare name). Falls back to deriving a name from a pre-this-fix
-- saved `exportFolder` value if `exportFolderName` is missing (an older saved
-- config that predates this split).
function utils.resolveExportFolder(cfg)
    local name = cfg.exportFolderName or stripDataFilesPrefix(cfg.exportFolder or "Export Cells")
    cfg.exportFolder = "data files\\" .. stripDataFilesPrefix(name)
end


-- Check if a cell is populated (has references, landscape, pathgrid, or region)
function utils.isCellPopulated(x, y)
    local cell = tes3.getCell({ x = x, y = y })
    if not cell then return false end

    for ref in cell:iterateReferences() do
        if ref and not ref.deleted and not ref.disabled then
            return true
        end
    end

    if not cell.isInterior then
        local landscapeRoot = tes3.game.worldLandscapeRoot
        if landscapeRoot and landscapeRoot.children then
            for shape in table.traverse(landscapeRoot.children) do
                if shape:isInstanceOfType(tes3.niType.NiTriShape) then
                    local t = shape.worldTransform.translation
                    local cellX = math.floor(t.x / 8192)
                    local cellY = math.floor(t.y / 8192)
                    if cellX == x and cellY == y then
                        return true
                    end
                end
            end
        end
        if cell.pathgrid then return true end
        if cell.region then return true end
    end
    return false
end

function utils.findNearestPopulatedCell(x, y, maxRadius)
    maxRadius = maxRadius or 100
    for r = 1, maxRadius do
        for dx = -r, r do
            for dy = -r, r do
                if math.abs(dx) == r or math.abs(dy) == r then
                    local nx, ny = x + dx, y + dy
                    if utils.isCellPopulated(nx, ny) then
                        return nx, ny
                    end
                end
            end
        end
    end
    return nil, nil
end

function utils.findLastPopulatedCellOnLine(startX, startY, endX, endY)
    local dx = endX - startX
    local dy = endY - startY
    local steps = math.max(math.abs(dx), math.abs(dy))
    if steps == 0 then
        if utils.isCellPopulated(startX, startY) then
            return startX, startY
        else
            return nil, nil
        end
    end
    local xInc = dx / steps
    local yInc = dy / steps
    local lastPopX, lastPopY = nil, nil
    for i = 0, steps do
        local x = math.floor(startX + xInc * i + 0.5)
        local y = math.floor(startY + yInc * i + 0.5)
        if utils.isCellPopulated(x, y) then
            lastPopX, lastPopY = x, y
        else
            break
        end
    end
    return lastPopX, lastPopY
end

-- Landmass extents and anchors
function utils.getLandmassExtents()
    local cell = tes3.player.cell
    if cell.isInterior then return nil end

    local startX, startY = cell.gridX, cell.gridY
    local visited = {}
    local queue = { {x = startX, y = startY} }
    local minX, maxX = startX, startX
    local minY, maxY = startY, startY

    local function key(x, y) return x .. "," .. y end
    local function isLandmassCell(x, y)
        local c = tes3.getCell({x = x, y = y})
        return c and not c.isInterior
    end

    if not isLandmassCell(startX, startY) then return nil end

    while #queue > 0 do
        local current = table.remove(queue, 1)
        local x, y = current.x, current.y
        local k = key(x, y)
        if not visited[k] and isLandmassCell(x, y) then
            visited[k] = true
            if x < minX then minX = x end
            if x > maxX then maxX = x end
            if y < minY then minY = y end
            if y > maxY then maxY = y end
            table.insert(queue, {x = x + 1, y = y})
            table.insert(queue, {x = x - 1, y = y})
            table.insert(queue, {x = x, y = y + 1})
            table.insert(queue, {x = x, y = y - 1})
        end
    end

    return {minX = minX, maxX = maxX, minY = minY, maxY = maxY, visited = visited}
end

function utils.getLandmassMods(visited)
    local mods = {}
    local modSet = {}
    for key, _ in pairs(visited) do
        local x, y = key:match("(-?%d+),(-?%d+)")
        x, y = tonumber(x), tonumber(y)
        local cell = tes3.getCell({x = x, y = y})
        if cell then
            for ref in cell:iterateReferences() do
                if ref and ref.sourceMod then
                    if not modSet[ref.sourceMod] then
                        modSet[ref.sourceMod] = true
                        table.insert(mods, ref.sourceMod)
                    end
                end
            end
        end
    end
    table.sort(mods)
    return mods
end

-- Renames mesh nodes sequentially
function utils.renameNodes(rootNode, baseName)
    if not rootNode then return end
    local counter = 0
    local function recurseRename(n)
        if not n then return end
        if n:isInstanceOfType(tes3.niType.NiTriShape) or n:isInstanceOfType(tes3.niType.NiTriStrips) then
            n.name = string.format("%s.%03d", baseName, counter)
            counter = counter + 1
        end
        if n.children then
            for _, c in ipairs(n.children) do
                recurseRename(c)
            end
        end
    end
    recurseRename(rootNode)
end

-- Extracts a relative path from a full Morrowind mesh path
function utils.getRelativeMeshPath(meshPath)
    if not meshPath or meshPath == "" then return nil end
    local rel = meshPath:match("[\\/][Mm][Ee][Ss][Hh][Ee][Ss][\\/](.+)$")
               or meshPath:match("^[Mm][Ee][Ss][Hh][Ee][Ss][\\/](.+)$")
               or meshPath
    rel = rel:gsub("/", "\\")
    return rel:gsub("%.[^%.]+$", string.lower)
end

-- Generic helpers moved from main.lua
function utils.clean(root)
    for obj in table.traverse(root.children) do
        -- remove extra data
        obj:removeAllExtraData()

        -- remove dynamic effects
        if obj:isInstanceOfType(tes3.niType.NiNode) then
            for i=0, 4 do
                local effect = obj:getEffect(i)
                if effect then
                    obj:detachChild(effect)
                    obj:detachEffect(effect)
                end
            end
        end
    end
end

function utils.stripHiddenNodes(root)
    -- Remove appCulled, keep preserved
    if not config.exportHidden then
        for node in table.traverse(root.children) do
            if node:isAppCulled() then
                local shouldPreserve = false
                local current = node
                
                while current do
                    if current:isInstanceOfType(tes3.niType.NiCollisionSwitch) then
                        shouldPreserve = true
                        break
                    end
                                    
                    current = current.parent
                end

                if shouldPreserve then
                    if node.name and (string.find(node.name:lower(), "collision")) then
                        if not node:isInstanceOfType(tes3.niType.NiCollisionSwitch) then 
                            shouldPreserve = false
                        end
                    end
                end

                if not shouldPreserve then
                    node.parent:detachChild(node)
                end
            end
        end
    end
end

function utils.filterBestLOD(node)
    if not node then return end
    if node:isInstanceOfType(tes3.niType.NiLODNode) then
        if node.children then
            local niNodeCount = 0
            for _, child in ipairs(node.children) do
                if child and child:isInstanceOfType(tes3.niType.NiNode) then
                    niNodeCount = niNodeCount + 1
                end
            end
            if niNodeCount >= 2 then
                for i = #node.children, 2, -1 do
                    node:detachChildAt(i)
                end
            end
        end
    elseif node.children then
        for _, child in ipairs(node.children) do
            if child then utils.filterBestLOD(child) end
        end
    end
end

function utils.traversalOrExportMsg(exportMode, exportMsg, traversalMsg)
    if not config then return exportMsg end
    if exportMode == constants.EXPORT_MODE.DISABLED then
        return traversalMsg
    else
        return exportMsg
    end
end

-- Console toggle helpers: fire-and-forget.
-- consoleToggles are applied once at export start and left on for the session.
-- restoreConsoleToggles are re-disabled when export finishes.
local togglesSetup = false

function utils.setupConsoleToggles()
    if togglesSetup then return end
    if not config or not config.consoleToggles then return end

    for toggle, enabledInConfig in pairs(config.consoleToggles) do
        if enabledInConfig then
            tes3.runLegacyScript{ command = toggle }
        end
    end
    togglesSetup = true
end

function utils.restoreConsoleToggles()
    if not config or not config.restoreConsoleToggles then return end

    for toggle, shouldRestore in pairs(config.restoreConsoleToggles) do
        if shouldRestore then
            tes3.runLegacyScript{ command = toggle }
        end
    end
    -- Do NOT reset togglesSetup — persistent toggles (e.g. TCL) must not
    -- re-fire on the next export. They were intentionally left on for the session.
end

function utils.executeConsoleFile()
    -- Check for console.lua first
    local luaPath = "Data Files/MWSE/mods/ExportCells/console.lua"
    local file = io.open(luaPath, "r")
    if not file then
        luaPath = "MWSE/mods/ExportCells/console.lua"
        file = io.open(luaPath, "r")
    end

    if file then
        file:close()

        -- Check if there are any executable (non-empty, non-comment) lines
        local hasExecutableLines = false
        local checkFile = io.open(luaPath, "r")
        if checkFile then
            for line in checkFile:lines() do
                local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
                if trimmed ~= "" and not trimmed:match("^%-%-") then
                    hasExecutableLines = true
                    break
                end
            end
            checkFile:close()
        end

        mwse.log("[Export Cells] Found console.lua, executing...")
        local fn, err = loadfile(luaPath)
        if fn then
            local status, runErr = pcall(fn)
            if status then
                if hasExecutableLines then
                    tes3.messageBox("Executed console custom commands.")
                end
            else
                local errMsg = "Error running console.lua: " .. tostring(runErr)
                tes3.messageBox(errMsg)
                mwse.log("[Export Cells] " .. errMsg)
            end
        else
            local errMsg = "Error loading console.lua: " .. tostring(err)
            tes3.messageBox(errMsg)
            mwse.log("[Export Cells] " .. errMsg)
        end
        return
    end

    -- If console.lua was not found, check console.txt
    local txtPath = "Data Files/MWSE/mods/ExportCells/console.txt"
    file = io.open(txtPath, "r")
    if not file then
        txtPath = "MWSE/mods/ExportCells/console.txt"
        file = io.open(txtPath, "r")
    end

    if file then
        mwse.log("[Export Cells] Found console.txt, executing lines...")
        local count = 0
        for line in file:lines() do
            local cmd = line:gsub("^%s+", ""):gsub("%s+$", "")
            if cmd ~= "" and not cmd:match("^%-%-") and not cmd:match("^#") and not cmd:match("^;") then
                tes3.runLegacyScript{ command = cmd }
                count = count + 1
            end
        end
        file:close()
        if count > 0 then
            tes3.messageBox("Executed %d console commands from console.txt", count)
        end
    else
        mwse.log("[Export Cells] Neither console.lua nor console.txt was found.")
    end
end

return utils