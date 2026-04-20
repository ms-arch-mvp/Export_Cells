local constants = {}

-- =============================================================================
-- EXPORT MODES
-- =============================================================================
constants.EXPORT_MODE = {
    EVERYTHING = "everything",
    LANDSCAPE_ONLY = "landscape_only",
    EXCLUDE_LANDSCAPE = "exclude_landscape",
    LAYER = "layer",
    JSON = "json",
    DISABLED = "disabled"
}

-- =============================================================================
-- VANILLA MOD LIST
-- =============================================================================
constants.vanillaMods = {
    ["Bloodmoon.esp"] = true,
    ["Tribunal.esm"] = true,
    ["adamantiumarmor.esp"] = true,
    ["AreaEffectArrows.esp"] = true,
    ["bcsounds.esp"] = true,
    ["EBQ_Artifact.esp"] = true,
    ["entertainers.esp"] = true,
    ["Siege at Firemoth.esp"] = true,
    ["LeFemmArmor.esp"] = true,
    ["master_index.esp"] = true,
}

-- =============================================================================
-- JSON NODE MAPPING
-- =============================================================================
constants.jsonNodeTypes = {
    [tes3.niType.NiPointLight] = "LIGHT",
    [tes3.niType.NiSpotLight] = "LIGHT",
    [tes3.niType.NiTriShape] = "MESH",
    [tes3.niType.NiTriStrips] = "MESH",
    [tes3.niType.NiBillboardNode] = "BILLBOARD",
    [tes3.niType.NiSwitchNode] = "SWITCH",
    [tes3.niType.NiNode] = "EMPTY",
}

-- =============================================================================
-- OBJECT TYPE NAMES
-- =============================================================================
constants.objectTypeNames = {
    [tes3.objectType.activator] = "Activator",
    [tes3.objectType.alchemy] = "Alchemy",
    [tes3.objectType.ammunition] = "Ammunition",
    [tes3.objectType.apparatus] = "Apparatus",
    [tes3.objectType.armor] = "Armor",
    [tes3.objectType.book] = "Book",
    [tes3.objectType.clothing] = "Clothing",
    [tes3.objectType.container] = "Container",
    [tes3.objectType.creature] = "Creature",
    [tes3.objectType.door] = "Door",
    [tes3.objectType.ingredient] = "Ingredient",
    [tes3.objectType.light] = "Light",
    [tes3.objectType.lockpick] = "Lockpick",
    [tes3.objectType.miscItem] = "Misc Item",
    [tes3.objectType.npc] = "NPC",
    [tes3.objectType.probe] = "Probe",
    [tes3.objectType.repairItem] = "Repair Item",
    [tes3.objectType.static] = "Static",
    [tes3.objectType.weapon] = "Weapon",
}

-- =============================================================================
-- ITEM TYPES (PICKABLE)
-- =============================================================================
constants.itemTypes = {
    [tes3.objectType.alchemy] = true,
    [tes3.objectType.ammunition] = true,
    [tes3.objectType.apparatus] = true,
    [tes3.objectType.armor] = true,
    [tes3.objectType.book] = true,
    [tes3.objectType.clothing] = true,
    [tes3.objectType.ingredient] = true,
    [tes3.objectType.lockpick] = true,
    [tes3.objectType.miscItem] = true,
    [tes3.objectType.probe] = true,
    [tes3.objectType.repairItem] = true,
    [tes3.objectType.weapon] = true,
}

return constants