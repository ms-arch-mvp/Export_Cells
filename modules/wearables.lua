local wearables = {}
local GUI_ID_InputDialog = tes3ui.registerID("Wearables:InputDialog")
local GUI_ID_InputField = tes3ui.registerID("Wearables:InputField")

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
    local itemsRemoved = 0
    
    local inventory = ref.object.inventory
    
    for _, stack in pairs(inventory) do
        local item = stack.object
        for _, objectType in ipairs(wearableTypes) do
            if item.objectType == objectType then
                tes3.removeItem({
                    reference = ref,
                    item = item,
                    count = stack.count,
                    playSound = false
                })
                itemsRemoved = itemsRemoved + stack.count
                break
            end
        end
    end
    
    return itemsRemoved
end

local function addWearablesToNPC(ref, searchText, removeExisting)
    if not searchText or searchText == "" then
        tes3.messageBox("No input provided.")
        return
    end

    if removeExisting then
        local removed = removeExistingWearables(ref)
        if removed > 0 then
            tes3.messageBox("Removed %d existing wearable item(s) from %s", removed, ref.baseObject.name)
        end
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

    local menu = tes3ui.createMenu({ id = GUI_ID_InputDialog, fixedFrame = true })
    menu.minWidth = 350
    menu.minHeight = 150
    menu.autoHeight = true
    menu.autoWidth = true

    local title = menu:createLabel({ text = "Mod name (.esp) or search string:" })
    title.borderBottom = 10

    local inputBlock = menu:createBlock()
    inputBlock.autoHeight = true
    inputBlock.widthProportional = 1.0

    local input = inputBlock:createTextInput({ id = GUI_ID_InputField })
    input.widthProportional = 1.0
    input.height = 30
    input.borderAllSides = 5

    local checkboxBlock = menu:createBlock()
    checkboxBlock.autoHeight = true
    checkboxBlock.widthProportional = 1.0
    checkboxBlock.borderTop = 10
    checkboxBlock.flowDirection = "left_to_right"

    local isChecked = true
    
    local checkbox = checkboxBlock:createButton({ text = "[X]" })
    checkbox.paddingAllSides = 4
    
    local function updateCheckbox()
        if isChecked then
            checkbox.text = "[X]"
        else
            checkbox.text = "[ ]"
        end
        checkbox:updateLayout()
    end
    
    checkbox:register("mouseClick", function()
        isChecked = not isChecked
        updateCheckbox()
    end)

    local checkboxLabel = checkboxBlock:createLabel({ text = " Remove existing wearables" })
    checkboxLabel.borderLeft = 8
    checkboxLabel.borderTop = 4

    local buttonBlock = menu:createBlock()
    buttonBlock.widthProportional = 1.0
    buttonBlock.autoHeight = true
    buttonBlock.childAlignX = 1.0
    buttonBlock.borderTop = 15

    local okButton = buttonBlock:createButton({ text = "OK" })
    okButton:register("mouseClick", function()
        local searchText = input.text
        menu:destroy()
        tes3ui.leaveMenuMode()
        
        if searchText and searchText ~= "" then
            addWearablesToNPC(ref, searchText, isChecked)
        end
    end)

    local cancelButton = buttonBlock:createButton({ text = "Cancel" })
    cancelButton:register("mouseClick", function()
        menu:destroy()
        tes3ui.leaveMenuMode()
    end)

    menu:updateLayout()
    tes3ui.enterMenuMode(GUI_ID_InputDialog)
    tes3ui.acquireTextInput(input)
end

return wearables