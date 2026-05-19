local scripts = {}

local config = nil
local exportCancelRequestedRef = nil
local exportInProgress = false

function scripts.setConfig(cfg)
    config = cfg
end

function scripts.setCancelRef(ref)
    exportCancelRequestedRef = ref
end

function scripts.isInProgress()
    return exportInProgress
end

local function doExport(modFilter)
    if exportInProgress then
        tes3.messageBox("An export is already in progress.")
        return
    end

    local allObjects = tes3.dataHandler.nonDynamicData.objects
    if not allObjects then
        tes3.messageBox("No objects found in the data handler.")
        return
    end

    local results = {}
    local added = {}
    local globalsByMod = {}
    local modFilterLower = modFilter and modFilter:lower() or nil

    for _, obj in pairs(allObjects) do
        if obj.script then
            local script = obj.script
            if script.id and not added[script.id:lower()] then
                local sourceMod = script.sourceMod
                if not modFilterLower or (sourceMod and sourceMod:lower() == modFilterLower) then
                    table.insert(results, script)
                    added[script.id:lower()] = true
                end
            end
        end
    end

    local allGlobals = tes3.dataHandler.nonDynamicData.globals
    if allGlobals then
        for _, obj in pairs(allGlobals) do
            local sourceMod = obj.sourceMod
            if not modFilterLower or (sourceMod and sourceMod:lower() == modFilterLower) then
                local sm = sourceMod or "Unknown"
                globalsByMod[sm] = globalsByMod[sm] or {}
                table.insert(globalsByMod[sm], string.format("%s = %s", obj.id, obj.value))
            end
        end
    else
        for _, obj in pairs(allObjects) do
            local isGlobal = false
            pcall(function()
                if type(obj.value) == "number" and not obj.name and not obj.mesh and obj.id then
                    isGlobal = true
                end
            end)
            if isGlobal then
                local sourceMod = obj.sourceMod
                if not modFilterLower or (sourceMod and sourceMod:lower() == modFilterLower) then
                    local sm = sourceMod or "Unknown"
                    globalsByMod[sm] = globalsByMod[sm] or {}
                    table.insert(globalsByMod[sm], string.format("%s = %s", obj.id, obj.value))
                end
            end
        end
    end

    local hasGlobals = false
    for k, v in pairs(globalsByMod) do hasGlobals = true break end

    if #results == 0 and not hasGlobals then
        if modFilter then
            tes3.messageBox("No scripts or globals found for mod: %s", modFilter)
        else
            tes3.messageBox("No scripts or globals found in database.")
        end
        return
    end

    -- Sort scripts alphabetically by ID
    table.sort(results, function(a, b) return a.id:lower() < b.id:lower() end)

    exportInProgress = true
    exportCancelRequestedRef[1] = false

    local MAX = 50 -- Export 50 scripts per frame tick for seamless game performance
    local totalScripts = #results
    local currentIndex = 1

    local function processBatch()
        if exportCancelRequestedRef[1] then
            exportInProgress = false
            tes3.messageBox("Scripts/Globals export cancelled.")
            return
        end

        if currentIndex == 1 and hasGlobals then
            lfs.mkdir(config.exportFolder)
            for sm, list in pairs(globalsByMod) do
                local modFolder = string.format("%s\\%s", config.exportFolder, sm)
                lfs.mkdir(modFolder)
                table.sort(list)
                local filePath = string.format("%s\\globals.txt", modFolder)
                local file = io.open(filePath, "w")
                if file then
                    file:write(table.concat(list, "\n"))
                    file:close()
                end
            end
            
            if totalScripts == 0 then
                exportInProgress = false
                tes3.messageBox("Globals exported successfully. (No scripts found)")
                return
            end
        end

        local endIdx = math.min(currentIndex + MAX - 1, totalScripts)
        
        -- Create export base folder
        lfs.mkdir(config.exportFolder)

        for i = currentIndex, endIdx do
            local script = results[i]
            -- Use original sourceMod name exactly as folder name as requested
            local modFolder = string.format("%s\\%s", config.exportFolder, script.sourceMod)
            lfs.mkdir(modFolder)

            -- Sanitize script ID for safe windows filename
            local safeScriptId = script.id:gsub("[^%w_%-%s]", "_")
            local filePath = string.format("%s\\%s.txt", modFolder, safeScriptId)

            -- Decompile/Retrieve script text asynchronously inside the batch loop to prevent freezes
            local text = script.text
            if text and text ~= "" then
                local file = io.open(filePath, "w")
                if file then
                    file:write(text)
                    file:close()
                end
            end
        end

        currentIndex = endIdx + 1
        
        if currentIndex > totalScripts then
            exportInProgress = false
            tes3.messageBox("Scripts export completed. (%d scripts)", totalScripts)
            return
        end

        tes3.messageBox("Exporting scripts: %d of %d...", currentIndex - 1, totalScripts)
        timer.start({ duration = 0.02, callback = processBatch })
    end

    processBatch()
end

function scripts.exportModScripts(inputString)
    if not inputString or inputString == "" then
        tes3.messageBox("Please enter a mod name to export its scripts.")
        return
    end
    -- Append .esp if extension is missing, safely checking lowercase to prevent .ESP.esp
    if not inputString:lower():match("%.es[mp]$") then
        inputString = inputString .. ".esp"
    end
    doExport(inputString)
end

function scripts.exportAllScripts()
    doExport(nil)
end

return scripts
