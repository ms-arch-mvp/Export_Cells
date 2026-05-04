local constants = {}

-- =============================================================================
-- EXPORT MODES
-- =============================================================================
constants.EXPORT_MODE = {
    STANDARD = "standard",
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
    [tes3.niType.NiNode] = "EMPTY",
    [tes3.niType.NiSwitchNode] = "SWITCH",
    [tes3.niType.NiLODNode] = "LOD",
    [tes3.niType.NiBSParticleNode] = "PARTICLE_SYSTEM",
    [tes3.niType.NiTriShape] = "MESH",
    [tes3.niType.NiTriStrips] = "MESH",
    [tes3.niType.NiPointLight] = "POINTLIGHT",
    [tes3.niType.NiSpotLight] = "SPOTLIGHT",
    [tes3.niType.NiBillboardNode] = "BILLBOARD",
}

constants.jsonSpecialNodeTypes = {
    EMITTER = "EMITTER",
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

return constants