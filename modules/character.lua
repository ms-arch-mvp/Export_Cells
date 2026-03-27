local character = {}

local utils = require("ExportCells.utils")
local config = nil

function character.setConfig(cfg)
    config = cfg
end

function character.export(ref)
    if not ref or not (ref.object.objectType == tes3.objectType.npc or ref.object.objectType == tes3.objectType.creature) then
        tes3.messageBox("No NPC or creature targeted.")
        return
    end

    if config and config.resetAnimation then
        utils.resetAnimation(ref)
    end

    local bakedNode = utils.bakeCharacter(ref)
    if not bakedNode then
        tes3.messageBox("Failed to bake character.")
        return
    end

    local objId = (ref.baseObject.id or "unknown"):gsub("%x%x%x%x%x%x%x%x$", "")
    local exportDir = config and config.EXPORT_FOLDER or "Data Files/Export Cells/"
    local fileName = ("%s.nif"):format(ref.baseObject.id)
    local fullPath = exportDir .. "\\" .. fileName

    fullPath = fullPath:gsub("[\\/]+", "\\")

    bakedNode:saveBinary(fullPath)
    tes3.messageBox("Character exported to %s", fullPath)
end

return character
