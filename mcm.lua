local constants = require("ExportCells.constants")
local defaultConfig = require("ExportCells.config")
local config
if defaultConfig.useSavedConfig then
    config = mwse.loadConfig("Export Cells", defaultConfig)
else
    config = defaultConfig
end

local mcm = {}

function mcm.registerModConfig()
    local template = mwse.mcm.createTemplate("Export Cells")
    template:saveOnClose("Export Cells", config)


    -- =============================================================================
    -- EXPORT SETTINGS PAGE
    -- =============================================================================
    local exportPage = template:createSideBarPage({
        label = "Export Settings",
        description = "Configure export behavior."
    })

    exportPage:createTextField({
        label = "Export Folder Path",
        description = "Directory where exported files will be written.",
        variable = mwse.mcm.createTableVariable({ id = "exportFolder", table = config })
    })

    local exportModes = {
        { label = "Everything", value = constants.EXPORT_MODE.EVERYTHING },
        { label = "Landscape Only", value = constants.EXPORT_MODE.LANDSCAPE_ONLY },
        { label = "Exclude Landscape", value = constants.EXPORT_MODE.EXCLUDE_LANDSCAPE },
        { label = "Layer", value = constants.EXPORT_MODE.LAYER },
        { label = "JSON", value = constants.EXPORT_MODE.JSON },
        { label = "Disabled", value = constants.EXPORT_MODE.DISABLED },
    }

    local exportModeGroup = exportPage:createCategory("Export Modes")

    exportModeGroup:createDropdown({
        label = "Active Cells",
        description = "Export mode used when exporting the currently active cells.",
        options = exportModes,
        variable = mwse.mcm.createTableVariable({ id = "active", table = config.defaultExportModes })
    })

    exportModeGroup:createDropdown({
        label = "1x1",
        description = "Export mode used for 1x1s.",
        options = exportModes,
        variable = mwse.mcm.createTableVariable({ id = "1x1", table = config.defaultExportModes })
    })

    exportModeGroup:createDropdown({
        label = "2x2",
        description = "Export mode used for 2x2s.",
        options = exportModes,
        variable = mwse.mcm.createTableVariable({ id = "2x2", table = config.defaultExportModes })
    })

    exportModeGroup:createDropdown({
        label = "3x3",
        description = "Export mode used for 3x3s.",
        options = exportModes,
        variable = mwse.mcm.createTableVariable({ id = "3x3", table = config.defaultExportModes })
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

    local customGridGroup = exportPage:createCategory("Custom Grid Sizes")

    customGridGroup:createTextField({
        label = "Custom Grid Size (1x1)",
        description = "Additional grid size option for 1x1 exports.",
        variable = mwse.mcm.createTableVariable({ id = "customGridSize1x1", table = config }),
        numbersOnly = true
    })

    customGridGroup:createTextField({
        label = "Custom Grid Size (2x2)",
        description = "Additional grid size option for 2x2 exports.",
        variable = mwse.mcm.createTableVariable({ id = "customGridSize2x2", table = config }),
        numbersOnly = true
    })

    customGridGroup:createTextField({
        label = "Custom Grid Size (3x3)",
        description = "Additional grid size option for 3x3 exports.",
        variable = mwse.mcm.createTableVariable({ id = "customGridSize3x3", table = config }),
        numbersOnly = true
    })

    exportModeGroup:createSlider({
        label = "Teleport Delay (seconds)",
        description = "Delay between teleports.",
        min = 0,
        max = 2,
        step = 0.01,
        jump = 0.1,
        decimalPlaces = 2,
        variable = mwse.mcm.createTableVariable({ id = "teleportDelaySeconds", table = config })
    })

    exportModeGroup:createDropdown({
        label = "Layer Object Type",
        description = "Select the object type to export when using Layer mode.",
        options = layerOptions,
        variable = mwse.mcm.createTableVariable({ id = "exportLayerType", table = config })
    })

    local toggleGroup = exportPage:createCategory("Export Toggles")

    toggleGroup:createYesNoButton({
        label = "Export Hidden Objects",
        description = "Export objects that are hidden in the game world, such as collisions.",
        variable = mwse.mcm.createTableVariable({ id = "exportHidden", table = config })
    })

    toggleGroup:createYesNoButton({
        label = "Clean Exports",
        description = "Removes extra data and dynamic effects.",
        variable = mwse.mcm.createTableVariable({ id = "cleanExports", table = config })
    })

    toggleGroup:createYesNoButton({
        label = "Export Reports",
        description = "Saves text for reports and exports.",
        variable = mwse.mcm.createTableVariable({ id = "exportReports", table = config })
    })

    toggleGroup:createYesNoButton({
        label = "Export Empty Landmass Cells",
        description = "Include empty cells when using landmass export.",
        variable = mwse.mcm.createTableVariable({ id = "exportEmptyLandmassCells", table = config })
    })

    toggleGroup:createYesNoButton({
        label = "Reset Animation Before Export",
        description = "Resets NPC and creature animations to their idle start pose before exporting. Helps avoid exporting characters mid-animation.",
        variable = mwse.mcm.createTableVariable({ id = "resetAnimation", table = config })
    })

    toggleGroup:createYesNoButton({
        label = "NIF: Rename Mesh Child Nodes",
        description = "Sequentially renames mesh nodes (NiTriShape/NiTriStrips) using the object's relative mesh path.",
        variable = mwse.mcm.createTableVariable({ id = "nifRenameMeshChildNodes", table = config })
    })

    toggleGroup:createYesNoButton({
        label = "JSON: Selective Child Nodes Only",
        description = "JSON exports only exports selective child nodes (Lights, Particles) rather than the whole hierarchy.",
        variable = mwse.mcm.createTableVariable({ id = "jsonSelectiveChildNodesOnly", table = config })
    })

    toggleGroup:createYesNoButton({
        label = "JSON: Sequential Naming",
        description = "Sequentially renames all exported JSON elements (Instances, Lights, Empties) to ensure uniqueness.",
        variable = mwse.mcm.createTableVariable({ id = "jsonSequentialNaming", table = config })
    })


    -- =============================================================================
    -- CONSOLE TOGGLES PAGE
    -- =============================================================================
    local consolePage = template:createSideBarPage({
        label = "Console Toggles",
        description = "Configure which console commands are applied during export."
    })

    consolePage:createYesNoButton({
        label = "Auto-Manage God Mode (tgm)",
        description = "Automatically manages God Mode while exporting or traversing.",
        variable = mwse.mcm.createTableVariable({ id = "tgm", table = config.exportConsoleToggles })
    })

    consolePage:createYesNoButton({
        label = "Auto-Manage AI (tai)",
        description = "Automatically manages NPC AI while exporting or traversing.",
        variable = mwse.mcm.createTableVariable({ id = "tai", table = config.exportConsoleToggles })
    })

    consolePage:createYesNoButton({
        label = "Auto-Manage Collision (tcl)",
        description = "Automatically manages collision while exporting or traversing.",
        variable = mwse.mcm.createTableVariable({ id = "tcl", table = config.exportConsoleToggles })
    })

    consolePage:createYesNoButton({
        label = "Disable Vanity Mode",
        description = "Automatically manages vanity camera while exporting or traversing.",
        variable = mwse.mcm.createTableVariable({ id = "disablevanitymode", table = config.exportConsoleToggles })
    })

    mwse.mcm.register(template)
end

return mcm