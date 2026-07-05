local constants = require("ExportCells.constants")
local defaultConfig = require("ExportCells.config")
local utils = require("ExportCells.utils")
local config
if defaultConfig.useSavedConfig then
    config = mwse.loadConfig("Export Cells", defaultConfig)
else
    config = defaultConfig
end
utils.resolveExportFolder(config)

local mcm = {}

function mcm.registerModConfig()
    local template = mwse.mcm.createTemplate("Export Cells")
    template:saveOnClose("Export Cells", config)


    -- =============================================================================
    -- MODE SETTINGS PAGE
    -- =============================================================================
    local modesPage = template:createSideBarPage({
        label = "Mode Settings",
        description = "Configure export behavior."
    })

    local group = modesPage:createCategory("Export Modes")

    local exportModes = {
        { label = "Standard", value = constants.EXPORT_MODE.STANDARD },
        { label = "Landscape Only", value = constants.EXPORT_MODE.LANDSCAPE_ONLY },
        { label = "Exclude Landscape", value = constants.EXPORT_MODE.EXCLUDE_LANDSCAPE },
        { label = "Layer", value = constants.EXPORT_MODE.LAYER },
        { label = "JSON", value = constants.EXPORT_MODE.JSON },
        { label = "Disabled", value = constants.EXPORT_MODE.DISABLED },
    }

    group:createDropdown({
        label = "Active Cells",
        description = "Export mode used when exporting the currently active cells.",
        options = exportModes,
        variable = mwse.mcm.createTableVariable({ id = "active", table = config.defaultExportModes })
    })

    group:createDropdown({
        label = "1x1",
        description = "Export mode used for 1x1s.",
        options = exportModes,
        variable = mwse.mcm.createTableVariable({ id = "1x1", table = config.defaultExportModes })
    })

    group:createDropdown({
        label = "2x2",
        description = "Export mode used for 2x2s.",
        options = exportModes,
        variable = mwse.mcm.createTableVariable({ id = "2x2", table = config.defaultExportModes })
    })

    group:createDropdown({
        label = "3x3",
        description = "Export mode used for 3x3s.",
        options = exportModes,
        variable = mwse.mcm.createTableVariable({ id = "3x3", table = config.defaultExportModes })
    })

    local actorExportModeOptions = {
        { label = "Target", value = constants.ACTOR_EXPORT_MODE.TARGET },
        { label = "Active Cells", value = constants.ACTOR_EXPORT_MODE.ACTIVE_CELLS },
    }

    group:createDropdown({
        label = "Actor",
        description = "Select the actor export mode for Shift+C: Target exports the targeted NPC/creature; Active Cells exports unique actors from currently active cells.",
        options = actorExportModeOptions,
        variable = mwse.mcm.createTableVariable({ id = "actorExportMode", table = config })
    })

    local layerOptions = {}
    local sortedTypes = {}
    for k, v in pairs(constants.objectTypeNames) do
        table.insert(sortedTypes, { id = k, name = v })
    end
    table.sort(sortedTypes, function(a, b) return a.name < b.name end)
    for _, item in ipairs(sortedTypes) do
        table.insert(layerOptions, { label = item.name, value = item.id })
    end

    local group = modesPage:createCategory("Custom Grid Sizes")

    group:createTextField({
        label = "Custom Grid Size (1x1)",
        description = "Additional grid size option for 1x1 exports.",
        buttonText = "Apply",
        variable = mwse.mcm.createTableVariable({ id = "customGridSize1x1", table = config }),
        numbersOnly = true
    })

    group:createTextField({
        label = "Custom Grid Size (2x2)",
        description = "Additional grid size option for 2x2 exports.",
        buttonText = "Apply",
        variable = mwse.mcm.createTableVariable({ id = "customGridSize2x2", table = config }),
        numbersOnly = true
    })

    group:createTextField({
        label = "Custom Grid Size (3x3)",
        description = "Additional grid size option for 3x3 exports.",
        buttonText = "Apply",
        variable = mwse.mcm.createTableVariable({ id = "customGridSize3x3", table = config }),
        numbersOnly = true
    })

    group:createDropdown({
        label = "Layer Object Type",
        description = "Select the object type to export when using Layer mode.",
        options = layerOptions,
        variable = mwse.mcm.createTableVariable({ id = "exportLayerType", table = config })
    })

    group:createSlider({
        label = "Teleport Delay (seconds)",
        description = "Delay between teleports.",
        min = 0,
        max = 2,
        step = 0.01,
        jump = 0.1,
        decimalPlaces = 2,
        variable = mwse.mcm.createTableVariable({ id = "teleportDelaySeconds", table = config })
    })

    -- =============================================================================
    -- EXPORT SETTINGS PAGE
    -- =============================================================================
    local exportPage = template:createSideBarPage({
        label = "Export Settings",
        description = "Configure export settings."
    })

    local group = exportPage:createCategory("Export Folder")

    group:createTextField({
        label = "Folder Path",
        description = "Folder name that exported files are written under, inside Data Files "
            .. "(e.g. \"Export Cells\").",
        buttonText = "Apply",
        variable = mwse.mcm.createTableVariable({ id = "exportFolderName", table = config })
    })

    local group = exportPage:createCategory("Export Toggles")

    group:createYesNoButton({
        label = "Export Hidden Objects",
        description = "Export objects that are hidden in the game world, such as collisions.",
        variable = mwse.mcm.createTableVariable({ id = "exportHidden", table = config })
    })

    group:createYesNoButton({
        label = "Clean Exports",
        description = "Removes extra data and dynamic effects.",
        variable = mwse.mcm.createTableVariable({ id = "cleanExports", table = config })
    })

    group:createYesNoButton({
        label = "Export Reports",
        description = "Saves text for reports and exports.",
        variable = mwse.mcm.createTableVariable({ id = "exportReports", table = config })
    })

    group:createYesNoButton({
        label = "Export Empty Landmass Cells",
        description = "Include empty cells when using landmass export.",
        variable = mwse.mcm.createTableVariable({ id = "exportEmptyLandmassCells", table = config })
    })

    local group = exportPage:createCategory("JSONs")

    group:createYesNoButton({
        label = "Selective Child Nodes Only",
        description = "JSON exports only exports selective child nodes (Lights, Particles) rather than the whole hierarchy.",
        variable = mwse.mcm.createTableVariable({ id = "jsonSelectiveChildNodesOnly", table = config })
    })

    group:createYesNoButton({
        label = "Sequential Naming",
        description = "Sequentially renames all exported JSON elements (Instances, Lights, Empties) to ensure uniqueness.",
        variable = mwse.mcm.createTableVariable({ id = "jsonSequentialNaming", table = config })
    })

    local group = exportPage:createCategory("NIFs")

    local nifNameOptions = {
        { label = "Object ID", value = "id" },
        { label = "Mesh Path", value = "mesh" },
    }

    group:createDropdown({
        label = "Node Name Strategy",
        description = "Choose whether exported NIF node names use the object ID or mesh path. Mesh path is recommended. Light top-level nodes still use object ID.",
        options = nifNameOptions,
        variable = mwse.mcm.createTableVariable({ id = "nifNodeNameStrategy", table = config })
    })

    group:createYesNoButton({
        label = "Rename Mesh Child Nodes",
        description = "Sequentially renames mesh nodes (NiTriShape/NiTriStrips) using the object's relative mesh path.",
        variable = mwse.mcm.createTableVariable({ id = "nifRenameMeshChildNodes", table = config })
    })
    
    local group = exportPage:createCategory("Actors")

    local actorFilenameOptions = {
        { label = "Object ID", value = "id" },
        { label = "Object Name", value = "name" },
    }

    group:createDropdown({
        label = "Actor Filename",
        description = "Choose whether exported NIF files use the object ID or name. Object IDs are for uniqueness, whereas names are for readability.",
        options = actorFilenameOptions,
        variable = mwse.mcm.createTableVariable({ id = "actorFilename", table = config })
    })

    group:createYesNoButton({
        label = "Reset Animation Before Export",
        description = "Resets NPC and creature animations to their idle start pose before exporting. Helps avoid exporting actors mid-animation.",
        variable = mwse.mcm.createTableVariable({ id = "resetAnimation", table = config })
    })

    local group = exportPage:createCategory("Meshes")

    group:createYesNoButton({
        label = "Export JSONs With NIFs",
        description = "When exporting meshes, also generate a JSON file.",
        variable = mwse.mcm.createTableVariable({ id = "exportMeshesWithJson", table = config })
    })

    group:createYesNoButton({
        label = "Spaced Out In Grid",
        description = "When exporting meshes, arrange them in a grid. If disabled, all objects will be placed at the origin (0,0,0).",
        variable = mwse.mcm.createTableVariable({ id = "exportMeshesSpacedOut", table = config })
    })

    local group = exportPage:createCategory("Records")

    group:createYesNoButton({
        label = "Require Mesh",
        description = "Only export records that have a mesh path.",
        variable = mwse.mcm.createTableVariable({ id = "recordsRequireMesh", table = config })
    })

    -- =============================================================================
    -- CONSOLE COMMANDS PAGE
    -- =============================================================================
    local group = template:createSideBarPage({
        label = "Console Commands",
        description = "Configure which console commands are applied during export."
    })

    group:createYesNoButton({
        label = "Auto-Manage God Mode (tgm)",
        description = "Automatically manages God Mode while exporting or traversing.",
        variable = mwse.mcm.createTableVariable({ id = "tgm", table = config.consoleToggles })
    })

    group:createYesNoButton({
        label = "Auto-Manage AI (tai)",
        description = "Automatically manages NPC AI while exporting or traversing.",
        variable = mwse.mcm.createTableVariable({ id = "tai", table = config.consoleToggles })
    })

    group:createYesNoButton({
        label = "Auto-Manage Collision (tcl)",
        description = "Automatically manages collision while exporting or traversing.",
        variable = mwse.mcm.createTableVariable({ id = "tcl", table = config.consoleToggles })
    })

    group:createYesNoButton({
        label = "Disable Vanity Mode",
        description = "Automatically manages vanity camera while exporting or traversing.",
        variable = mwse.mcm.createTableVariable({ id = "disablevanitymode", table = config.consoleToggles })
    })

    group:createYesNoButton({
        label = "Console Custom Commands",
        description = "Executes the lines in console.lua when teleporting to landmass center.",
        variable = mwse.mcm.createTableVariable({ id = "runConsoleCustomCommands", table = config })
    })

    mwse.mcm.register(template)
end

return mcm
