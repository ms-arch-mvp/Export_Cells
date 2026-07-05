local config = {

    -- =============================================================================
    -- GENERAL
    -- =============================================================================

    -- Bare folder name edited via MCM -- never contains a "data files\" prefix.
    -- `exportFolder` (the fully resolved path every export module actually reads)
    -- is computed from this by `utils.resolveExportFolder`, not stored here.
    exportFolderName = "Export Cells",
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
        ["3x3"] = "json",
    },

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

    exportLayerType = tes3.objectType.npc,
    actorExportMode = "target",
    actorFilename = "name",

    cleanExports = false,
    exportHidden = false,
    exportReports = true,
    exportEmptyLandmassCells = true,
    interiorGarbageCollection = true,
    nifRenameMeshChildNodes = true,
    nifNodeNameStrategy = "mesh",
    resetAnimation = true,
    
    flaggedMeshesFile = "Flagged meshes.txt",
    exportMeshesWithJson = false,
    exportMeshesSpacedOut = true,
    recordsRequireMesh = false,
    recordsExcludeTypes = {
        tes3.objectType.creature,
        tes3.objectType.bodyPart,
    },

    -- =============================================================================
    -- JSONS
    -- =============================================================================
    jsonFields = {
        "object_id",
        "object_name",
        "object_type",
        "weapon_type",
        "clothing_type",
        "creature_type",
        "apparatus_type",
        "armor_type",
        -- "source_form_id",
        -- "source_mod_id",  
        "source_mod",
        "can_carry",
        "mesh",
        "script",
        "destination",
    },

    jsonSelectiveChildNodesOnly = true,
    jsonSequentialNaming = true,


    -- =============================================================================
    -- CONSOLE
    -- =============================================================================
    consoleToggles = {
        tgm = true,
        tai = true,
        disablevanitymode = true,
        tcl = true,
    },

    restoreConsoleToggles = {
        tgm = true,
        tai = true,
    },

    runConsoleCustomCommands = true,
}

return config
