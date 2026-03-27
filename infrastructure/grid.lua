local grid = {}

local configRef = nil

function grid.setConfig(cfg)
    configRef = cfg
end

-- Multiples and rounding helpers

-- =============================================================================
-- OFFSETS & ANCHORS
-- =============================================================================
function grid.get2x2GridOffsets(size)
    local half = math.floor(size / 2)
    local offsets = {}
    for y = -half, half do
        for x = -half, half do
            table.insert(offsets, { x = x * 2, y = y * 2 })
        end
    end
    return offsets
end

function grid.get3x3GridOffsets(size)
    local half = math.floor(size / 2)
    local offsets = {}
    for y = -half, half do
        for x = -half, half do
            table.insert(offsets, { x = x * 3, y = y * 3 })
        end
    end
    return offsets
end

function grid.get1x1GridOffsets(size)
    local half = math.floor(size / 2)
    local offsets = {}
    for y = -half, half do
        for x = -half, half do
            table.insert(offsets, { x = x, y = y })
        end
    end
    return offsets
end

-- getGridAnchors moved to grid module; uses configRef to check exportEmptyLandmassCells
function grid.getGridAnchors(gridType, minX, maxX, minY, maxY, visited)
    local anchors = {}
    local cfg = configRef or {}
    if cfg.exportEmptyLandmassCells then
        local step = (gridType == "2x2") and 2 or 3
        local function roundUp(n, mult)
            local r = n % mult
            return r == 0 and n or (n + (mult - r))
        end
        local anchorMinX, anchorMinY
        if gridType == "2x2" then
            anchorMinX = roundUp(minX, 2)
            anchorMinY = roundUp(minY, 2)
        else
            anchorMinX = roundUp(minX, 3)
            anchorMinY = roundUp(minY, 3)
        end
        for x = anchorMinX, maxX, step do
            for y = anchorMinY, maxY, step do
                table.insert(anchors, { x = x, y = y })
            end
        end
    else
        if gridType == "2x2" then
            local anchorSet = {}
            for key, _ in pairs(visited) do
                local x, y = key:match("(-?%d+),(-?%d+)")
                x, y = tonumber(x), tonumber(y)
                local ax = x + 1
                if ax % 2 ~= 0 then ax = ax + 1 end
                local ay = y + 1
                if ay % 2 ~= 0 then ay = ay + 1 end
                local akey = ax .. "," .. ay
                if not anchorSet[akey] then
                    anchorSet[akey] = {x = ax, y = ay}
                end
            end
            for _, anchor in pairs(anchorSet) do
                table.insert(anchors, anchor)
            end
        else
            local anchorSet = {}
            for key, _ in pairs(visited) do
                local x, y = key:match("(-?%d+),(-?%d+)")
                x, y = tonumber(x), tonumber(y)
                local function anchor3(n)
                    if n % 3 == 0 then return n end
                    if n % 3 == 1 then return n - 1 end
                    return n + 1
                end
                local ax = anchor3(x)
                local ay = anchor3(y)
                local akey = ax .. "," .. ay
                if not anchorSet[akey] then
                    anchorSet[akey] = {x = ax, y = ay}
                end
            end
            for _, anchor in pairs(anchorSet) do
                table.insert(anchors, anchor)
            end
        end
    end
    return anchors
end

return grid