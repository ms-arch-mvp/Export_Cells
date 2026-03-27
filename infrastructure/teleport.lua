local teleport = {}

local config = nil
local exportCancelRequestedRef = nil
local utils = require("ExportCells.utils")

function teleport.setConfig(cfg)
    config = cfg
end

function teleport.setCancelRef(refTable)
    -- Expects a table reference so module can check/set exportCancelRequested via that table
    exportCancelRequestedRef = refTable
end

local function getTeleportZ(z)
    return z + (config.exportConsoleToggles.tcl and config.TCL_TELEPORT_Z_OFFSET or 0)
end

-- =============================================================================
-- UTILITIES
-- =============================================================================
local function isCellPopulated(x, y)
    return utils.isCellPopulated(x, y)
end

local function attemptTeleport(targetX, targetY, attempts, targetZ, finalX, finalY, callback)
    if exportCancelRequestedRef and exportCancelRequestedRef[1] then
        if callback then callback(true) end
        return
    end

    attempts = attempts or 0
    if attempts > 100 then
        tes3.messageBox("Failed to reach cell %d, %d after multiple attempts", finalX, finalY)
        if callback then callback(false) end
        return
    end

    local targetCellName = string.format("%d, %d", targetX, targetY)
    local targetPos = tes3vector3.new(targetX * 8192 + 4096, targetY * 8192 + 4096, getTeleportZ(targetZ))

    tes3.positionCell{ reference = tes3.player, position = targetPos, cell = targetCellName, suppressFader = true }

    timer.frame.delayOneFrame(function()
        if exportCancelRequestedRef and exportCancelRequestedRef[1] then
            if callback then callback(true) end
            return
        end

        local playerCell = tes3.player.cell
        if playerCell.gridX == finalX and playerCell.gridY == finalY then
            if callback then callback(false) end
        elseif playerCell.gridX == targetX and playerCell.gridY == targetY then
            local currentX, currentY = playerCell.gridX, playerCell.gridY
            local deltaX = finalX - currentX
            local deltaY = finalY - currentY
            local nextX = currentX
            local nextY = currentY
            if deltaX > 0 then nextX = currentX + 1 elseif deltaX < 0 then nextX = currentX - 1 end
            if deltaY > 0 then nextY = currentY + 1 elseif deltaY < 0 then nextY = currentY - 1 end
            timer.start({ duration = config.TELEPORT_DELAY_SECONDS, callback = function()
                if exportCancelRequestedRef and exportCancelRequestedRef[1] then
                    if callback then callback(true) end
                    return
                end
                attemptTeleport(nextX, nextY, attempts + 1, targetZ, finalX, finalY, callback)
            end })
        else
            local currentX, currentY = playerCell.gridX, playerCell.gridY
            local deltaX = finalX - currentX
            local deltaY = finalY - currentY
            local adjX = currentX
            local adjY = currentY
            if deltaX > 0 then adjX = currentX + 1 elseif deltaX < 0 then adjX = currentX - 1 end
            if deltaY > 0 then adjY = currentY + 1 elseif deltaY < 0 then adjY = currentY - 1 end
            timer.start({ duration = config.TELEPORT_DELAY_SECONDS, callback = function()
                if exportCancelRequestedRef and exportCancelRequestedRef[1] then
                    if callback then callback(true) end
                    return
                end
                attemptTeleport(adjX, adjY, attempts + 1, targetZ, finalX, finalY, callback)
            end })
        end
    end)
end

-- =============================================================================
-- TELEPORTATION LOGIC
-- =============================================================================
function teleport.tryTeleportToCell(x, y, z, callback)
    local finalX, finalY = x, y
    if not isCellPopulated(x, y) then
        local playerCell = tes3.player.cell
        local dist = math.abs(playerCell.gridX - x) + math.abs(playerCell.gridY - y)
        if dist <= 5 then
            attemptTeleport(playerCell.gridX, playerCell.gridY, 0, z, x, y, callback)
            return
        end
        local nx, ny = nil, nil
        if utils.findNearestPopulatedCell then
            nx, ny = utils.findNearestPopulatedCell(x, y, 8)
        end
        if nx ~= nil and ny ~= nil then
            tes3.messageBox("Target cell %d,%d is empty. Teleporting to nearest populated cell %d,%d first.", x, y, nx, ny)
            tes3.positionCell{ reference = tes3.player, position = tes3vector3.new(nx * 8192 + 4096, ny * 8192 + 4096, getTeleportZ(z)), cell = string.format("%d, %d", nx, ny), suppressFader = true }
            timer.start({ duration = config.TELEPORT_DELAY_SECONDS, callback = function()
                attemptTeleport(nx, ny, 0, z, x, y, callback)
            end })
            return
        else
            local sx, sy = playerCell.gridX, playerCell.gridY
            local lx, ly = nil, nil
            if utils.findLastPopulatedCellOnLine then
                lx, ly = utils.findLastPopulatedCellOnLine(sx, sy, x, y)
            end
            if lx ~= nil and ly ~= nil then
                tes3.messageBox("No nearby populated cell. Teleporting to last populated cell along line: %d,%d", lx, ly)
                tes3.positionCell{ reference = tes3.player, position = tes3vector3.new(lx * 8192 + 4096, ly * 8192 + 4096, getTeleportZ(z)), cell = string.format("%d, %d", lx, ly), suppressFader = true }
                timer.start({ duration = config.TELEPORT_DELAY_SECONDS, callback = function()
                    attemptTeleport(lx, ly, 0, z, x, y, callback)
                end })
                return
            else
                tes3.messageBox("No populated cell found near or along path to %d,%d. Attempting adjacent teleport from current position.", x, y)
                local nx2, ny2 = nil, nil
                if utils.findNearestPopulatedCell then
                    nx2, ny2 = utils.findNearestPopulatedCell(x, y, 8)
                end
                if nx2 ~= nil and ny2 ~= nil then
                    tes3.messageBox("Target cell %d,%d is empty. Teleporting to nearest populated cell %d,%d first.", x, y, nx2, ny2)
                    tes3.positionCell{ reference = tes3.player, position = tes3vector3.new(nx2 * 8192 + 4096, ny2 * 8192 + 4096, getTeleportZ(z)), cell = string.format("%d, %d", nx2, ny2), suppressFader = true }
                    timer.start({ duration = config.TELEPORT_DELAY_SECONDS, callback = function()
                        attemptTeleport(nx2, ny2, 0, z, x, y, callback)
                    end })
                    return
                else
                    tes3.messageBox("No populated cell found near %d,%d. Attempting adjacent teleport from current position.", x, y)
                    local playerCell = tes3.player.cell
                    attemptTeleport(playerCell.gridX, playerCell.gridY, 0, z, x, y, callback)
                    return
                end
            end
        end
    end

    attemptTeleport(x, y, 0, z, x, y, callback)
end

function teleport.moveToNearestMultipleOf2Cell()
    local cell = tes3.player.cell
    if cell.isInterior then return false end
    local x, y = cell.gridX, cell.gridY
    if x % 2 == 0 and y % 2 == 0 then return false end
    local newX = math.floor((x + 1) / 2) * 2
    local newY = math.floor((y + 1) / 2) * 2
    local z = tes3.player.position.z
    teleport.tryTeleportToCell(newX, newY, z)
    tes3.messageBox("Moved to center cell %d, %d for 2x2 export.", newX, newY)
    return true
end

function teleport.moveToNearestMultipleOf3Cell()
    local cell = tes3.player.cell
    if cell.isInterior then return false end
    local x, y = cell.gridX, cell.gridY
    if x % 3 == 0 and y % 3 == 0 then return false end
    local newX = math.floor((x + 1.5) / 3) * 3
    local newY = math.floor((y + 1.5) / 3) * 3
    local z = tes3.player.position.z
    teleport.tryTeleportToCell(newX, newY, z)
    tes3.messageBox("Moved to center cell %d, %d for 3x3 export.", newX, newY)
    return true
end

return teleport