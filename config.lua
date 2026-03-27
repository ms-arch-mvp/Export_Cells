local config = {
    -- =============================================================================
    -- GENERAL SETTINGS
    -- =============================================================================
    USE_SAVED_CONFIG = false,

    EXPORT_FOLDER = "data files\\Export Cells",

    EXPORT_MODE = {
        EVERYTHING = "everything",
        LANDSCAPE_ONLY = "landscape_only",
        EXCLUDE_LANDSCAPE = "exclude_landscape",
        LAYER = "layer",
        JSON = "json",
        DISABLED = "disabled"
    },

    defaultExportModes = {
        ["active"] = "everything",
        ["1x1"] = "disabled",
        ["2x2"] = "landscape_only",
        ["3x3"] = "json"
    },

    TELEPORT_DELAY_SECONDS = 0.02,

    exportHidden = false,
    cleanExports = false,
    flaggedNifsFile = "Flagged nifs.txt",
    exportReports = true,
    exportInteriorsLists = true,
    exportEmptyLandmassCells = true,
    interiorGarbageCollection = true,
    resetAnimation = true,
    exportLayerType = tes3.objectType.npc,
    nifRenameMeshChildNodes = true,
    jsonLightChildNodesOnly = true,
    jsonSequentialNaming = true,


    -- =============================================================================
    -- CONSOLE TOGGLES
    -- =============================================================================
    -- Toggles fired once at export start, left on for the session
    exportConsoleToggles = {
        tgm = true,
        tai = true,
        disablevanitymode = true,
        tcl = true,
    },

    -- Toggles to re-disable when export finishes
    restoreConsoleToggles = {
        tgm = true,
        tai = true,
    },

    TCL_TELEPORT_Z_OFFSET = 128,


    -- =============================================================================
    -- EXPORT TYPES
    -- =============================================================================
    exportTypes = {
        tes3.objectType.activator,
        tes3.objectType.alchemy,
        tes3.objectType.ammunition,
        tes3.objectType.apparatus,
        tes3.objectType.armor,
        tes3.objectType.book,
        tes3.objectType.clothing,
        tes3.objectType.container,
        tes3.objectType.door,
        tes3.objectType.ingredient,
        tes3.objectType.light,
        tes3.objectType.lockpick,
        tes3.objectType.miscItem,
        tes3.objectType.probe,
        tes3.objectType.repairItem,
        tes3.objectType.static,
        tes3.objectType.weapon,
    },


    -- =============================================================================
    -- JSON NODE MAPPING
    -- =============================================================================
    jsonNodeTypes = {
        [tes3.niType.NiPointLight] = "LIGHT",
        [tes3.niType.NiSpotLight] = "LIGHT",
        [tes3.niType.NiTriShape] = "MESH",
        [tes3.niType.NiTriStrips] = "MESH",
        [tes3.niType.NiBillboardNode] = "BILLBOARD",
        [tes3.niType.NiSwitchNode] = "SWITCH",
        [tes3.niType.NiNode] = "EMPTY",
        -- [tes3.niType.RootCollisionNode] = "COLLISION",
    },

    -- Object Types excluded from exports:

    -- tes3.objectType.birthsign
    -- tes3.objectType.bodyPart
    -- tes3.objectType.cell
    -- tes3.objectType.class
    -- tes3.objectType.creature
    -- tes3.objectType.dialogue
    -- tes3.objectType.dialogueInfo
    -- tes3.objectType.enchantment
    -- tes3.objectType.faction
    -- tes3.objectType.land
    -- tes3.objectType.landTexture
    -- tes3.objectType.leveledCreature
    -- tes3.objectType.leveledItem
    -- tes3.objectType.magicEffect
    -- tes3.objectType.npc
    -- tes3.objectType.pathGrid
    -- tes3.objectType.quest
    -- tes3.objectType.race
    -- tes3.objectType.reference
    -- tes3.objectType.region
    -- tes3.objectType.script
    -- tes3.objectType.skill
    -- tes3.objectType.sound
    -- tes3.objectType.soundGenerator
    -- tes3.objectType.spell
    -- tes3.objectType.startScript


    -- =============================================================================
    -- VANILLA MOD LIST
    -- =============================================================================
    vanillaMods = {
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
    },


    -- =============================================================================
    -- OBJECT TYPE NAMES
    -- =============================================================================
    objectTypeNames = {
        [tes3.objectType.activator] = "Activator", [tes3.objectType.alchemy] = "Alchemy",
        [tes3.objectType.ammunition] = "Ammunition", [tes3.objectType.apparatus] = "Apparatus",
        [tes3.objectType.armor] = "Armor", [tes3.objectType.book] = "Book",
        [tes3.objectType.clothing] = "Clothing", [tes3.objectType.container] = "Container",
        [tes3.objectType.creature] = "Creature",
        [tes3.objectType.door] = "Door", [tes3.objectType.ingredient] = "Ingredient",
        [tes3.objectType.light] = "Light", [tes3.objectType.lockpick] = "Lockpick",
        [tes3.objectType.miscItem] = "Misc Item", [tes3.objectType.npc] = "NPC",
        [tes3.objectType.probe] = "Probe",
        [tes3.objectType.repairItem] = "Repair Item", [tes3.objectType.static] = "Static",
        [tes3.objectType.weapon] = "Weapon",
    }
}

return config