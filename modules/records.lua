local records = {}

local config = nil
local jsons = require("ExportCells.modules.jsons")

function records.setConfig(cfg)
    config = cfg
end

local exportCancelRequestedRef = nil
function records.setCancelRef(ref)
    exportCancelRequestedRef = ref
end

local exportInProgress = false
function records.isInProgress() return exportInProgress end

local function doExport(modFilter, startChunk)
    if exportInProgress then tes3.messageBox("An export is already in progress."); return end
    
    local results = {}
    local allObjects = tes3.dataHandler.nonDynamicData.objects
    
    local modFilterLower = modFilter and modFilter:lower() or nil
    startChunk = startChunk or 1
    
    for _, obj in pairs(allObjects) do
        if obj and obj.mesh and obj.mesh ~= "" and obj.objectType ~= tes3.objectType.creature then
            if not modFilterLower or (obj.sourceMod and obj.sourceMod:lower() == modFilterLower) then
                table.insert(results, obj)
            end
        end
    end
    table.sort(results, function(a,b) return a.id < b.id end)
    
    if #results == 0 then
        if modFilter then
            tes3.messageBox("No records found for mod: %s", modFilter)
        else
            tes3.messageBox("No records found with meshes.")
        end
        return
    end

    local MAX = 1000
    local totalChunks = math.ceil(#results / MAX)
    exportInProgress = true
    exportCancelRequestedRef[1] = false

    local function processChunk(chunkIndex)
        if exportCancelRequestedRef[1] then
            exportInProgress = false
            tes3.messageBox("Records export cancelled.")
            return
        end
        if chunkIndex > totalChunks then
            exportInProgress = false
            tes3.messageBox("Records export completed. (%d records)", #results)
            return
        end
        
        local startIdx = (chunkIndex - 1) * MAX + 1
        local endIdx = math.min(chunkIndex * MAX, #results)
        local chunkObjects = {}
        for i = startIdx, endIdx do table.insert(chunkObjects, results[i]) end
        
        lfs.mkdir(config.exportFolder)
        local exportName = modFilter and (modFilter:gsub("%.es.$", ""):gsub("[^%w]", "_") .. "_records") or "master_records"
        local fileName = string.format("%s_part_%d.json", exportName, chunkIndex)
        local path = config.exportFolder .. "\\" .. fileName
        
        -- Export at 0,0,0
        jsons.exportObjectGroup(exportName, chunkObjects, 0, 10, path)
        
        tes3.messageBox("Exporting %s: Part %d of %d", exportName, chunkIndex, totalChunks)
        timer.start({ duration = 0.05, callback = function() processChunk(chunkIndex + 1) end })
    end

    if startChunk > totalChunks then
        tes3.messageBox("Part %d exceeds total chunks (%d). Starting from Part 1.", startChunk, totalChunks)
        startChunk = 1
    end
    processChunk(startChunk)
end

function records.exportModRecords(inputString)
    if not inputString or inputString == "" then
        tes3.messageBox("Please enter a mod name to export its records.")
        return
    end
    doExport(inputString, 1)
end

function records.exportAllRecords(inputString)
    local startChunk = 1
    if inputString and inputString ~= "" then
        startChunk = tonumber(inputString)
        if not startChunk then
            tes3.messageBox("Invalid part number for resuming. Starting from part 1.")
            startChunk = 1
        end
    end
    doExport(nil, startChunk)
end

return records
