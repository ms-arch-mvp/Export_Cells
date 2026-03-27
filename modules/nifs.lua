local nifs = {}

local config = nil
local utils = require("ExportCells.utils")
local jsonModule = require("ExportCells.modules.jsons")

function nifs.setConfig(cfg)
    config = cfg
end

-- =============================================================================
-- EXPORT EXECUTION
-- =============================================================================
function nifs.export(regionCells, exportMode, currentIndex, totalCount)
    if exportMode == config.EXPORT_MODE.DISABLED then
        return
    end

    if exportMode == config.EXPORT_MODE.JSON then
        jsonModule.export(regionCells, currentIndex, totalCount)
        return
    end

    local root = niNode.new()
    local idCounters = {}

    if exportMode ~= config.EXPORT_MODE.LANDSCAPE_ONLY then
        local searchTypes = (exportMode == config.EXPORT_MODE.LAYER) and {config.exportLayerType} or config.exportTypes
        for _, cell in pairs(regionCells) do
            for ref in cell:iterateReferences(searchTypes) do
                local include = true
                if exportMode == config.EXPORT_MODE.LAYER then
                    if ref.object.objectType ~= config.exportLayerType then
                        include = false
                    end
                elseif exportMode == config.EXPORT_MODE.EXCLUDE_LANDSCAPE then
                    local isLight = ref.object.objectType == tes3.objectType.light
                    if not isLight and (not ref.object.mesh or ref.object.mesh == "") then
                        include = false
                    end
                end

                if include and ref.sceneNode and not (ref.disabled or ref.deleted) then
                    local node = ref.sceneNode:clone()

                    if node then
                        local obj = ref.object
                        local isCharacter = (obj.objectType == tes3.objectType.npc or obj.objectType == tes3.objectType.creature)
                        local isLight = (obj.objectType == tes3.objectType.light)
                        local objId = obj.id

                        if exportMode == config.EXPORT_MODE.LAYER and config.resetAnimation and isCharacter then
                            utils.resetAnimation(ref)
                        end
                        if isCharacter then
                            local bakedNode = utils.bakeCharacter(ref, true)
                            if bakedNode then
                                node = bakedNode
                            end
                        end
                        utils.filterBestLOD(node)
                        local nodeName, baseNameForRenaming
                        local relativePath = (obj.mesh and obj.mesh ~= "") and utils.getRelativeMeshPath(obj.mesh) or nil

                        if isCharacter then
                            nodeName = objId
                            baseNameForRenaming = objId
                        elseif isLight then
                            idCounters[objId] = (idCounters[objId] or 0) + 1
                            local count = idCounters[objId]
                            nodeName = (count == 1) and objId or string.format("%s.%03d", objId, count - 1)
                            baseNameForRenaming = relativePath or objId
                        elseif relativePath then
                            nodeName = relativePath
                            baseNameForRenaming = relativePath
                        else
                            nodeName = objId
                            baseNameForRenaming = objId
                        end

                        if config.nifRenameMeshChildNodes then
                            utils.renameNodes(node, baseNameForRenaming)
                        end
                        node.name = nodeName

                        utils.stripHiddenNodes(node)
                        node:removeAllControllers()
                        root:attachChild(node)
                    end
                end
            end
        end
    end

    -- Landscape
    if not tes3.player.cell.isInterior and exportMode ~= config.EXPORT_MODE.EXCLUDE_LANDSCAPE and exportMode ~= config.EXPORT_MODE.LAYER then
        local landscapeRoot = tes3.game.worldLandscapeRoot
        local node = niNode.new()
        node.name = landscapeRoot.name
        node.materialProperty = landscapeRoot.materialProperty
        node.texturingProperty = landscapeRoot.texturingProperty
        root:attachChild(node)

        local landscapeCounters = {}
        for shape in table.traverse(landscapeRoot.children) do
            if shape:isInstanceOfType(tes3.niType.NiTriShape) then
                local t = shape.worldTransform.translation:copy()
                local cellX = math.floor(t.x / 8192)
                local cellY = math.floor(t.y / 8192)
                local cellKey = string.format("%d_%d", cellX, cellY)

                local found = false
                for _, cell in pairs(regionCells) do
                    if cell.gridX == cellX and cell.gridY == cellY then
                        found = true
                        break
                    end
                end

                if found then
                    local shapeClone = shape:clone()
                    shapeClone.translation = t
                    landscapeCounters[cellKey] = (landscapeCounters[cellKey] or 0) + 1
                    local uniqueNum = landscapeCounters[cellKey]
                    local safeCellName = (tes3.getCell({x=cellX, y=cellY}).id):gsub("[^%w_]", "_")
                    shapeClone.name = string.format("%s_%s_Landscape_%03d", cellKey, safeCellName, uniqueNum)
                    node:attachChild(shapeClone)
                end
            end
        end
    end

    if config.cleanExports then
        utils.clean(root)
    end

    local cell = tes3.player.cell
    local cellName = (cell.id):gsub("%s+", "_"):gsub(":", "-")
    local coords = ""
    if not cell.isInterior then
        coords = string.format("%d_%d_", cell.gridX, cell.gridY)
    end

    local modeSuffix = ""
    if exportMode == config.EXPORT_MODE.EXCLUDE_LANDSCAPE then
        modeSuffix = "_no_landscape"
    elseif exportMode == config.EXPORT_MODE.LANDSCAPE_ONLY then
        modeSuffix = "_landscape"
    elseif exportMode == config.EXPORT_MODE.LAYER then
        local typeName = config.objectTypeNames[config.exportLayerType] or "Layer"
        modeSuffix = "_" .. typeName:gsub("%s+", "_")
    end

    lfs.mkdir(config.EXPORT_FOLDER)
    local path = string.format("%s\\%s%s%s.nif", config.EXPORT_FOLDER, coords, cellName, modeSuffix)
    root:saveBinary(path)

    local exportMsg = string.format("%s%s%s.nif", coords, cellName, modeSuffix)
    tes3.messageBox("Exported: %s\n(%d of %d)", exportMsg, currentIndex or 1, totalCount or 1)
end

return nifs
