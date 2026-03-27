local utils = {}

-- Utility helpers used by main.lua and ui.lua

local config = nil

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

function utils.bakeCharacter(ref)
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
        if node.children and #node.children > 0 then
            for i = #node.children, 2, -1 do
                node:detachChildAt(i)
            end
            if node.children[1] then
                utils.filterBestLOD(node.children[1])
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
    if exportMode == config.EXPORT_MODE.DISABLED then
        return traversalMsg
    else
        return exportMsg
    end
end

-- Console toggle helpers: fire-and-forget.
-- exportConsoleToggles are applied once at export start and left on for the session.
-- restoreConsoleToggles are re-disabled when export finishes.
local togglesSetup = false

function utils.setupExportConsoleToggles()
    if togglesSetup then return end
    if not config or not config.exportConsoleToggles then return end

    for toggle, enabledInConfig in pairs(config.exportConsoleToggles) do
        if enabledInConfig then
            tes3.runLegacyScript{ command = toggle }
        end
    end
    togglesSetup = true
end

function utils.restoreExportConsoleToggles()
    if not config or not config.restoreConsoleToggles then return end

    for toggle, shouldRestore in pairs(config.restoreConsoleToggles) do
        if shouldRestore then
            tes3.runLegacyScript{ command = toggle }
        end
    end
    -- Do NOT reset togglesSetup — persistent toggles (e.g. TCL) must not
    -- re-fire on the next export. They were intentionally left on for the session.
end

return utils