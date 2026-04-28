local config = {

    -- =============================================================================
    -- GENERAL
    -- =============================================================================

    exportFolder = "data files\\Export Cells",
    useSavedConfig = false,

    teleportDelaySeconds = 0.02,
    tclTeleportZOffset = 128,

    -- Grid Sizes
    gridSizes1x1 = { 1, 3, 5, 7, 9, 11, 13, 15, 17, 19 },
    gridSizes2x2 = { 1, 3, 5, 7, 9, 11, 13, 15, 17, 19 },
    gridSizes3x3 = { 1, 3, 5, 7, 9, 11, 13, 15, 17, 19 },

    customGridSize1x1 = 21,
    customGridSize2x2 = 51, -- size to include all of Vvardenfell + Tamriel Rebuilt + Tomb of the Snow Prince
    customGridSize3x3 = 33, -- size to include all of Vvardenfell + Tamriel Rebuilt + Tomb of the Snow Prince

    -- =============================================================================
    -- EXPORT
    -- =============================================================================
    defaultExportModes = {
        ["active"] = "json",
        ["1x1"] = "disabled",
        ["2x2"] = "landscape_only",
        ["3x3"] = "json"
    },

    exportLayerType = tes3.objectType.npc,

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

    exportHidden = false,
    cleanExports = false,
    exportReports = true,
    exportEmptyLandmassCells = true,
    interiorGarbageCollection = true,
    resetAnimation = true,
    nifRenameMeshChildNodes = true,
    flaggedNifsFile = "Flagged nifs.txt",


    -- =============================================================================
    -- JSONS
    -- =============================================================================
    jsonFields = {
        "object_id",
        "object_name",
        "object_type",
        -- "source_form_id",
        -- "source_mod_id",  
        "source_mod",
        "can_carry",
        "mesh",
        "script",
    },

    jsonSelectiveChildNodesOnly = true,
    jsonSequentialNaming = true,


    -- =============================================================================
    -- CONSOLE
    -- =============================================================================
    exportConsoleToggles = {
        tgm = true,
        tai = true,
        disablevanitymode = true,
        tcl = true,
    },

    restoreConsoleToggles = {
        tgm = true,
        tai = true,
    },

}

return config