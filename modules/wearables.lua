local wearables = {}
local ui = require("ExportCells.ui")

local config = nil

local wearableTypes = {
    tes3.objectType.armor,
    tes3.objectType.clothing,
    tes3.objectType.ring,
    tes3.objectType.amulet,
    --tes3.objectType.weapon,
}


function wearables.setConfig(cfg)
    config = cfg
end

-- =============================================================================
-- WEARABLE MANAGEMENT
-- =============================================================================
local function removeExistingWearables(ref)
    local inventory = ref.object.inventory
    local toRemove = {}

    for _, stack in pairs(inventory) do
        local item = stack.object
        for _, objectType in ipairs(wearableTypes) do
            if item.objectType == objectType then
                table.insert(toRemove, { id = item.id, count = stack.count })
                break
            end
        end
    end

    for _, entry in ipairs(toRemove) do
        tes3.removeItem({
            reference = ref,
            item = entry.id,
            count = entry.count,
            playSound = false
        })
    end

    return #toRemove > 0
end

local function addWearablesToNPC(ref, searchText, removeExisting)
    if removeExisting then
        local removed = removeExistingWearables(ref)
        if removed then
            tes3.messageBox("Removed existing wearables from %s", ref.baseObject.name)
        end
    end

    if not searchText or searchText == "" then
        return
    end

    local searchTextLower = searchText:lower()
    local isPluginSearch = searchTextLower:match("%.esp$") or searchTextLower:match("%.esm$")
    local itemsAdded = 0

    for _, objectType in ipairs(wearableTypes) do
        for obj in tes3.iterateObjects(objectType) do
            local matched = false
            if isPluginSearch then
                if obj.sourceMod and obj.sourceMod:lower() == searchTextLower then
                    matched = true
                end
            else
                if (obj.name and obj.name:lower():find(searchTextLower, 1, true)) or 
                   (obj.id and obj.id:lower():find(searchTextLower, 1, true)) then
                    matched = true
                end
            end

            if matched then
                tes3.addItem({
                    reference = ref,
                    item = obj.id,
                    count = 1,
                    playSound = false
                })
                itemsAdded = itemsAdded + 1
            end
        end
    end

    if itemsAdded > 0 then
        local searchTypeText = isPluginSearch and "from mod" or "matching"
        local itemText = itemsAdded == 1 and "item" or "items"
        tes3.messageBox("Added %d wearable %s %s '%s' to %s", itemsAdded, itemText, searchTypeText, searchText, ref.baseObject.name)
    else
        tes3.messageBox("No wearable items found matching '%s'", searchText)
    end
end


-- =============================================================================
-- MENU INTERFACE
-- =============================================================================
function wearables.showInputDialog()
    local ref = tes3.getPlayerTarget()
    if not (ref and (ref.object.objectType == tes3.objectType.npc or ref.object.objectType == tes3.objectType.creature)) then
        tes3.messageBox("No NPC or creature targeted.")
        return
    end

    ui.createWearablesInputDialog({
        onConfirm = function(searchText, removeExisting)
            addWearablesToNPC(ref, searchText, removeExisting)
        end,
        onInventory = function()
            timer.delayOneFrame(function()
                tes3.showContentsMenu({ reference = ref })
            end)
        end
    })
end

return wearables
