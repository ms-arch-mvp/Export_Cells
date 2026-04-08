local objects = {}

local config = nil
local utils = require("ExportCells.utils")
local nifs = require("ExportCells.modules.nifs")

function objects.setConfig(cfg)
    config = cfg
end

local exportCancelRequestedRef = nil
function objects.setCancelRef(ref)
    exportCancelRequestedRef = ref
end

local exportInProgress = false
function objects.isInProgress() return exportInProgress end

-- =============================================================================
-- OBJECT COLLECTION
-- =============================================================================
local function collectObjectsByMeshFolder(folderName)
    local results = {}
    local seen = {}
    local searchFolder = string.lower(folderName):gsub("/", "\\")
    searchFolder = searchFolder:gsub("^\\*", ""):gsub("\\*$", "")

    local function check(obj)
        if not obj or not obj.mesh or obj.mesh == "" then return end
        if obj.objectType == tes3.objectType.creature then return end
        local mesh = string.lower(obj.mesh):gsub("/", "\\")
        if seen[mesh] then return end

        local currentFolder = ""
        if string.find(mesh, "^meshes\\") then
            currentFolder = mesh:match("^meshes\\(.+)\\[^\\]+$")
            if not currentFolder then currentFolder = "meshes" end
        else
            currentFolder = mesh:match("^(.+)\\[^\\]+$")
            if not currentFolder then currentFolder = "meshes" end
        end

        if currentFolder == searchFolder then
            if searchFolder == "meshes" and mesh:find("\\") then return end
            seen[mesh] = true
            table.insert(results, obj)
        end
    end

    local allObjects = tes3.dataHandler.nonDynamicData.objects
    if not allObjects then return results end
    for _, obj in pairs(allObjects) do check(obj) end
    table.sort(results, function(a,b) return a.id < b.id end)
    return results
end

local function discoverAllUsedFolders(prefix)
    local folderGroups = {}
    local folders = {}
    local allObjects = tes3.dataHandler.nonDynamicData.objects
    if not allObjects then return {}, {} end

    local searchPrefix = prefix and string.lower(prefix):gsub("/", "\\"):gsub("^\\*", ""):gsub("\\*$", "")
    local skipFolders = {}

    for _, obj in pairs(allObjects) do
        if obj and obj.mesh and obj.mesh ~= "" and obj.objectType ~= tes3.objectType.creature then
            local mesh = string.lower(obj.mesh):gsub("/", "\\")
            local folder = ""
            if string.find(mesh, "^meshes\\") then
                folder = mesh:match("^meshes\\(.+)\\[^\\]+$")
                if not folder then folder = "meshes" end
            else
                folder = mesh:match("^(.+)\\[^\\]+$")
                if not folder then folder = "meshes" end
            end

            if folder and not skipFolders[folder] then
                local include = true
                if searchPrefix then
                    if searchPrefix == "meshes" then
                        include = (folder == "meshes" and not mesh:find("\\"))
                    elseif folder == searchPrefix then
                        include = true
                    elseif string.find(folder, "^" .. searchPrefix .. "\\") then
                        include = true
                    else
                        include = false
                    end
                end

                if include then
                    if not folderGroups[folder] then
                        folderGroups[folder] = {}
                        table.insert(folders, folder)
                    end
                    local meshLower = mesh
                    if not folderGroups[folder][meshLower] then
                        folderGroups[folder][meshLower] = true
                        table.insert(folderGroups[folder], obj)
                    end
                end
            end
        end
    end
    table.sort(folders)
    for _, list in pairs(folderGroups) do
        table.sort(list, function(a,b) return a.id < b.id end)
    end
    return folders, folderGroups
end

local function collectFlaggedObjects()
    local fileName = config.flaggedNifsFile or "Flagged nifs.txt"
    lfs.mkdir(config.exportFolder)
    local path = config.exportFolder .. "\\" .. fileName
    
    local file = io.open(path, "r")
    if not file then return nil end
    
    local flaggedSet = {}
    for line in file:lines() do
        local mesh = line:gsub("^%s+", ""):gsub("%s+$", ""):lower():gsub("/", "\\")
        if mesh ~= "" then
            mesh = mesh:gsub("^meshes\\", "")
            flaggedSet[mesh] = true
        end
    end
    file:close()
    
    local results = {}
    local seen = {}
    local allObjects = tes3.dataHandler.nonDynamicData.objects
    for _, obj in pairs(allObjects) do
        if obj and obj.mesh and obj.mesh ~= "" and obj.objectType ~= tes3.objectType.creature then
            local mesh = obj.mesh:lower():gsub("/", "\\")
            if flaggedSet[mesh] and not seen[mesh] then
                seen[mesh] = true
                table.insert(results, obj)
            end
        end
    end
    table.sort(results, function(a,b) return a.id < b.id end)
    return results
end

local function collectObjectsByMod(modName)
    modName = modName:lower():gsub("^%s+", ""):gsub("%s+$", "")
    local results = {}
    local seen = {}
    local allObjects = tes3.dataHandler.nonDynamicData.objects
    for _, obj in pairs(allObjects) do
        if obj and obj.sourceMod and obj.sourceMod:lower() == modName and obj.objectType ~= tes3.objectType.creature then
            local mesh = obj.mesh and obj.mesh:lower() or ""
            if mesh ~= "" and not seen[mesh] then
                seen[mesh] = true
                table.insert(results, obj)
            end
        end
    end
    if #results > 0 then
        table.sort(results, function(a,b) return a.id < b.id end)
        return results
    end
    return nil
end


-- =============================================================================
-- PATH LIST EXPORT
-- =============================================================================
local function exportMeshPathLists()
    local allObjects = tes3.dataHandler.nonDynamicData.objects
    local rootPaths, subPaths = {}, {}
    local seenRoot, seenSub = {}, {}
    if allObjects then
        for _, obj in pairs(allObjects) do
            if obj and obj.mesh and obj.mesh ~= "" then
                local mesh = string.lower(obj.mesh):gsub("/", "\\")
                if mesh:find("^meshes\\") then
                    local inRoot = not mesh:match("^meshes\\[^\\]+\\[^\\]")
                    if inRoot and not seenRoot[obj.mesh] then seenRoot[obj.mesh] = true; table.insert(rootPaths, obj.mesh)
                    elseif not inRoot and not seenSub[obj.mesh] then seenSub[obj.mesh] = true; table.insert(subPaths, obj.mesh) end
                else
                    if not mesh:find("\\") and not seenRoot[obj.mesh] then seenRoot[obj.mesh] = true; table.insert(rootPaths, obj.mesh)
                    elseif mesh:find("\\") and not seenSub[obj.mesh] then seenSub[obj.mesh] = true; table.insert(subPaths, obj.mesh) end
                end
            end
        end
    end
    table.sort(rootPaths)
    table.sort(subPaths)
    
    lfs.mkdir(config.exportFolder)
    local fileName = "Meshes.txt"
    local filePath = config.exportFolder .. "\\" .. fileName
    local file = io.open(filePath, "w")
    if file then
        file:write("Referenced mesh paths (Morrowind game data)\n")
        file:write(string.format("Total: %d\n\n", #rootPaths + #subPaths))
        file:write("--- Root ---\n")
        for _, p in ipairs(rootPaths) do file:write(p .. "\n") end
        file:write("\n--- Subfolders ---\n")
        for _, p in ipairs(subPaths) do file:write(p .. "\n") end
        file:close()
        tes3.messageBox("Mesh list exported: %s", fileName)
    end
end


-- =============================================================================
-- EXPORT EXECUTION
-- =============================================================================
function objects.exportObjectsByMeshFolder(targetFolder, folderDataMap, resumeFolder)
    if exportInProgress then tes3.messageBox("An export is already in progress."); return end
    exportCancelRequestedRef[1] = false

    local queue = {}
    if type(targetFolder) == "table" then
        for _, f in ipairs(targetFolder) do table.insert(queue, f) end
    elseif type(targetFolder) == "string" then
        table.insert(queue, targetFolder)
    end

    if resumeFolder and resumeFolder ~= "" then
        local found = false
        local filtered = {}
        for _, f in ipairs(queue) do
            if found or f == resumeFolder then
                found = true
                table.insert(filtered, f)
            end
        end
        if found then
            queue = filtered
        else
            tes3.messageBox("Folder '%s' not found. Exporting all.", resumeFolder)
        end
    end

    local MAX_OBJECTS_PER_FILE = 1000

    local function processQueue()
        if exportCancelRequestedRef[1] then
            exportInProgress = false
            tes3.messageBox("Export cancelled.")
            return
        end

        if #queue == 0 then
            exportInProgress = false
            tes3.messageBox("All exports complete.")
            return
        end

        local folderName = table.remove(queue, 1)
        local objects = (folderDataMap and folderDataMap[folderName]) or collectObjectsByMeshFolder(folderName)

        if #objects == 0 then
            timer.start({ duration = 0.01, callback = processQueue })
            return
        end

        local totalChunks = math.ceil(#objects / MAX_OBJECTS_PER_FILE)
        if totalChunks == 1 then
            tes3.messageBox("Exporting '%s' (%d objects)", folderName, #objects)
        else
            tes3.messageBox("Exporting '%s' (%d objects in %d parts)", folderName, #objects, totalChunks)
        end

        local function processChunk(chunkIndex)
            if exportCancelRequestedRef[1] then exportInProgress = false; return end
            if chunkIndex > totalChunks then
                timer.start({ duration = 0.01, callback = processQueue })
                return
            end

            timer.start({ duration = 0.01, callback = function()
                local startIdx = (chunkIndex - 1) * MAX_OBJECTS_PER_FILE + 1
                local endIdx = math.min(chunkIndex * MAX_OBJECTS_PER_FILE, #objects)
                local chunkObjects = {}
                for i = startIdx, endIdx do table.insert(chunkObjects, objects[i]) end

                local root = niNode.new()
                root.name = folderName

                local maxDim = 16
                for _, obj in ipairs(chunkObjects) do
                    if obj.boundingBox then
                        local bb = obj.boundingBox
                        maxDim = math.max(maxDim, bb.max.x - bb.min.x, bb.max.y - bb.min.y)
                    end
                end
                local spacing = math.max(128, maxDim + 32)
                local rowSize = math.ceil(math.sqrt(#chunkObjects))
                local count = 0

                for _, obj in ipairs(chunkObjects) do
                    local node = tes3.loadMesh(obj.mesh)
                    if node then
                        local cloneSuccess, clonedNode = pcall(function() return node:clone() end)
                        if cloneSuccess and clonedNode then
                            utils.filterBestLOD(clonedNode)
                            utils.clean(clonedNode)

                            local meshBase = utils.getRelativeMeshPath(obj.mesh)
                            clonedNode.name = meshBase

                            if config.nifRenameMeshChildNodes then
                                utils.renameNodes(clonedNode, meshBase)
                            end

                            utils.stripHiddenNodes(clonedNode)

                            clonedNode:removeAllControllers()

                            local x = (count % rowSize) * spacing
                            local y = math.floor(count / rowSize) * spacing
                            clonedNode.translation = tes3vector3.new(x, y, 0)
                            clonedNode.rotation = tes3matrix33.new(1,0,0, 0,1,0, 0,0,1)
                            clonedNode.scale = 1.0
                            root:attachChild(clonedNode)
                            count = count + 1
                        end
                    end
                end

                lfs.mkdir(config.exportFolder)
                local fileName
                if folderName == "Flagged_nifs" then
                    if totalChunks > 1 then
                        fileName = string.format("Flagged_nifs_part%d.nif", chunkIndex)
                    else
                        fileName = "Flagged_nifs.nif"
                    end
                elseif folderName:find("_plugin$") then
                    local baseName = folderName:gsub("_plugin$", "")
                    if totalChunks > 1 then
                        fileName = string.format("%s_nifs_part%d.nif", baseName, chunkIndex)
                    else
                        fileName = string.format("%s_nifs.nif", baseName)
                    end
                else
                    local safeName = folderName:gsub("[^%w]", "_")
                    if totalChunks > 1 then
                        fileName = string.format("%s_meshes_part%d.nif", safeName, chunkIndex)
                    else
                        fileName = string.format("%s_meshes.nif", safeName)
                    end
                end
                local path = config.exportFolder .. "\\" .. fileName
                
                local success, err = pcall(function() root:saveBinary(path) end)
                if not success then tes3.messageBox("FAILED to save %s: %s", fileName, err) end
                
                -- Collect garbage AFTER saving to prevent MWSE from prematurely freeing C++ pointers 
                -- (like NiTriShapes shared with collision nodes) before NiStream finishes serializing them.
                collectgarbage("collect")

                timer.start({ duration = 0.01, callback = function()
                    processChunk(chunkIndex + 1)
                end})
            end})
        end
        processChunk(1)
    end

    if #queue > 0 then
        exportInProgress = true
        processQueue()
    end
end


-- =============================================================================
-- UI DISCOVERY
-- =============================================================================
function objects.discoverFolders(prefix) return discoverAllUsedFolders(prefix) end
function objects.collectFlagged() return collectFlaggedObjects() end
function objects.collectByMod(name) return collectObjectsByMod(name) end
function objects.exportLists() exportMeshPathLists() end

return objects