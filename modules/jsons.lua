local jsons = {}

local constants = require("ExportCells.constants")
local utils = require("ExportCells.utils")

local config = nil

function jsons.setConfig(cfg)
    config = cfg
end

-- =============================================================================
-- SERIALIZATION HELPERS
-- =============================================================================
local function jsonString(s)
    s = tostring(s or "")
    s = s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
    return '"' .. s .. '"'
end

local function jsonNumber(n)
    if type(n) ~= "number" then return "0" end
    if n ~= n then return "0" end          -- NaN guard
    if n == math.huge or n == -math.huge then return "0" end
    return string.format("%.8g", n)
end

-- =============================================================================
-- TRANSFORM HELPERS
-- =============================================================================

-- Build a column-major 4x4 matrix from a Morrowind worldTransform.
local function buildMatrix4x4(transform)
    local r = transform.rotation
    local s = transform.scale or 1
    local t = transform.translation
    local rows = { r.x, r.y, r.z }
    local cols = { "x", "y", "z" }

    local function col(c)
        return string.format(
            "      [%s, %s, %s, 0]",
            jsonNumber(rows[1][cols[c]] * s),
            jsonNumber(rows[2][cols[c]] * s),
            jsonNumber(rows[3][cols[c]] * s)
        )
    end
    return table.concat({
        col(1) .. ",",
        col(2) .. ",",
        col(3) .. ",",
        string.format(
            "      [%s, %s, %s, 1]",
            jsonNumber(t.x), jsonNumber(t.y), jsonNumber(t.z)
        ),
    }, "\n")
end

-- =============================================================================
-- EXPORT EXECUTION
-- =============================================================================
function jsons.export(regionCells, currentIndex, totalCount)
    local entries = {}

    local cell        = tes3.player.cell
    local cellName    = (cell.id):gsub("%s+", "_"):gsub(":", "-")
    local coords      = ""
    if not cell.isInterior then
        coords = string.format("%d_%d_", cell.gridX, cell.gridY)
    end

    local suffix = ""
    local path = string.format("%s\\%s%s%s.json", config.exportFolder, coords, cellName, suffix)

    -- ---- Root cell empty ----
    local rootName = coords .. cellName .. suffix
    local regionId = cell.region and cell.region.id or ""

    local function jsonColor(c)
        if not c then return "null" end
        return string.format("[%s, %s, %s]", jsonNumber(c.r), jsonNumber(c.g), jsonNumber(c.b))
    end

    local rootLines = {
        "  {",
        "    " .. jsonString("name") .. ": " .. jsonString(rootName) .. ",",
        "    " .. jsonString("type") .. ": " .. jsonString("EMPTY") .. ",",
    }
    if cell.isInterior then
        table.insert(rootLines, "    " .. jsonString("is_interior") .. ": true,")
    end
    if cell.behavesAsExterior then
        table.insert(rootLines, "    " .. jsonString("behaves_as_exterior") .. ": true,")
    end
    if cell.isInterior then
        if regionId ~= "" then
            table.insert(rootLines, "    " .. jsonString("region") .. ": " .. jsonString(regionId) .. ",")
        end
        table.insert(rootLines, "    " .. jsonString("ambient_color") .. ": " .. jsonColor(cell.ambientColor) .. ",")
        table.insert(rootLines, "    " .. jsonString("sun_color") .. ": " .. jsonColor(cell.sunColor) .. ",")
        table.insert(rootLines, "    " .. jsonString("fog_color") .. ": " .. jsonColor(cell.fogColor) .. ",")
        table.insert(rootLines, "    " .. jsonString("fog_density") .. ": " .. jsonNumber(cell.fogDensity ~= nil and cell.fogDensity or 0) .. ",")
        table.insert(rootLines, "    " .. jsonString("has_water") .. ": " .. tostring(cell.hasWater and true or false) .. ",")
        if cell.hasWater then
            table.insert(rootLines, "    " .. jsonString("water_level") .. ": " .. jsonNumber(cell.waterLevel or 0) .. ",")
        end
    end
    -- ---- cells array: one entry per cell in the 3x3 export ----
    local cellEntries = {}
    for _, c in pairs(regionCells) do
        if not c.isInterior then
            local cName = c.id
            local cRegion = (c.region and c.region.id) or ""
            table.insert(cellEntries,
                "      {" ..
                jsonString("x")      .. ": " .. jsonNumber(c.gridX) .. ", " ..
                jsonString("y")      .. ": " .. jsonNumber(c.gridY) .. ", " ..
                jsonString("name")   .. ": " .. jsonString(cName)   .. ", " ..
                jsonString("region") .. ": " .. jsonString(cRegion) ..
                "}"
            )
        end
    end
    if #cellEntries > 0 then
        table.insert(rootLines, "    " .. jsonString("cells") .. ": [\n" .. table.concat(cellEntries, ",\n") .. "\n    ],")
    end
    table.insert(rootLines, "    " .. jsonString("matrix_local") .. ": [\n      [1,0,0,0],\n      [0,1,0,0],\n      [0,0,1,0],\n      [0,0,0,1]\n    ],")
    table.insert(rootLines, "    " .. jsonString("parent") .. ": null")
    table.insert(rootLines, "  }")
    table.insert(entries, table.concat(rootLines, "\n"))

    local idCounters = {}

    local function emitEntry(nodeName, parentName, transform, nodeType, extraFields)
        local matStr = buildMatrix4x4(transform)
        local lines = {
            "  {",
            "    " .. jsonString("name")         .. ": " .. jsonString(nodeName) .. ",",
            "    " .. jsonString("type")         .. ": " .. jsonString(nodeType or "EMPTY")  .. ",",
            "    " .. jsonString("matrix_local") .. ": [\n" .. matStr .. "\n    ],",
            "    " .. jsonString("parent")       .. ": " .. jsonString(parentName),
        }
        if extraFields then
            lines[#lines] = lines[#lines] .. ","
            for _, f in ipairs(extraFields) do table.insert(lines, f) end
        end
        lines[#lines] = lines[#lines]:gsub(",$", "")
        table.insert(lines, "  }")
        table.insert(entries, table.concat(lines, "\n"))
    end

    local function emitLightEntry(nodeName, parentName, transform, lightData, nodeType)
        local matStr = buildMatrix4x4(transform)
        local lines = {
            "  {",
            "    " .. jsonString("name")         .. ": " .. jsonString(nodeName)   .. ",",
            "    " .. jsonString("type")         .. ": " .. jsonString(nodeType or "LIGHT")    .. ",",
            "    " .. jsonString("matrix_local") .. ": [\n" .. matStr .. "\n    ],",
            "    " .. jsonString("parent")       .. ": " .. jsonString(parentName) .. ",",
            "    " .. jsonString("light_data")   .. ": " .. lightData,
            "  }",
        }
        table.insert(entries, table.concat(lines, "\n"))
    end

    for _, c in pairs(regionCells) do
        for ref in c:iterateReferences(config.exportTypes) do
            if ref and not ref.disabled and not ref.deleted and ref.sceneNode then
                local obj = ref.object
                if not obj then goto continue end

                local meshPath = obj.mesh
                if meshPath and meshPath ~= "" then
                    local lower = meshPath:lower()
                    if lower:find("meshes[\\/]grass[\\/]") or lower:find("^grass[\\/]") then
                        goto continue
                    end
                end

                local objId    = obj.id
                local objName  = obj.name
                local objType  = obj.objectType
                local isLight  = (objType == tes3.objectType.light)
                local typeName = constants.objectTypeNames and constants.objectTypeNames[objType] or tostring(objType)
                local relMesh = utils.getRelativeMeshPath(meshPath)
                local isItem  = (constants.itemTypes[objType] == true) or (objType == tes3.objectType.light and obj.canCarry == true)

                idCounters[objId] = (idCounters[objId] or 0) + 1
                local count    = idCounters[objId]
                local instName
                if config.jsonSequentialNaming then
                    instName = count == 1 and objId or string.format("%s.%03d", objId, count - 1)
                else
                    instName = count == 1 and objId or string.format("%s (%s)", objId, tostring(ref):match("0x(%w+)"))
                end

                local fieldMap = {
                    object_id      = function() return jsonString(objId) end,
                    object_name    = function() return objName and objName ~= "" and jsonString(objName) end,
                    source_form_id = function() return jsonNumber(ref.sourceFormId or 0) end,
                    source_mod_id  = function() return jsonNumber(ref.sourceModId or 0) end,
                    source_mod     = function() return jsonString(ref.sourceMod or "") end,
                    morrowind_type = function() return jsonString(typeName) end,
                    is_item        = function() return isItem and "true" or nil end,
                    mesh           = function() return relMesh and jsonString(relMesh) end,
                    script         = function() return obj.script and jsonString(obj.script.id or "") end,
                }
                
                local fieldLines = {}
                for _, field in ipairs(config.jsonFields or {}) do
                    local handler = fieldMap[field]
                    if handler then
                        local val = handler()
                        if val then
                            table.insert(fieldLines, string.format("    %s: %s,", jsonString(field), val))
                        end
                    end
                end

                if isLight and obj.color and obj.radius then
                    local r = (obj.color[1] or 0) / 255
                    local g = (obj.color[2] or 0) / 255
                    local b = (obj.color[3] or 0) / 255
                    local lightJson = table.concat({
                        "{",
                        "      " .. jsonString("color")        .. ": [" .. jsonNumber(r) .. ", " .. jsonNumber(g) .. ", " .. jsonNumber(b) .. "],",
                        "      " .. jsonString("radius")       .. ": " .. jsonNumber(obj.radius),
                        "    }"
                    }, "\n    ")
                    table.insert(fieldLines, #fieldLines, "    " .. jsonString("light_data") .. ": " .. lightJson .. ",")
                end

                local cloned = ref.sceneNode:clone()
                local wt = ref.sceneNode.worldTransform
                local rootTransform
                if isLight then
                    rootTransform = wt
                    for child in table.traverse({cloned}) do
                        if child:isInstanceOfType(tes3.niType.NiTriShape) or
                           child:isInstanceOfType(tes3.niType.NiTriStrips) then
                            local s = child.scale or 1
                            if s ~= 1 then
                                rootTransform = { translation = wt.translation, rotation = wt.rotation, scale = s }
                            end
                            break
                        end
                    end
                else
                    rootTransform = { translation = wt.translation, rotation = wt.rotation, scale = cloned.scale or 1 }
                end

                emitEntry(instName, rootName, rootTransform, "EMPTY", fieldLines)

                -- Non-light instances: no child nodes are used by the importer, skip traversal.
                if config.jsonSelectiveChildNodesOnly and not isLight then goto continue end

                local nodeJsonNames = {}
                nodeJsonNames[tostring(cloned)] = instName

                -- Pre-pass: build set of nodes that are NiPointLight/NiSpotLight
                -- or ancestors of one. Only these will be emitted.
                local lightAncestors = {}
                if isLight then
                    for node in table.traverse({cloned}) do
                        if node:isInstanceOfType(tes3.niType.NiPointLight) or
                           node:isInstanceOfType(tes3.niType.NiSpotLight) or
                           node:isInstanceOfType(tes3.niType.NiBSParticleNode) then
                            lightAncestors[tostring(node)] = true
                            local p = node.parent
                            while p and tostring(p) ~= tostring(cloned) do
                                lightAncestors[tostring(p)] = true
                                p = p.parent
                            end
                        end
                    end
                end

                for node in table.traverse({cloned}) do
                    if tostring(node) == tostring(cloned) then goto nextNode end
                    if not node.parent then goto nextNode end

                    local parentJsonName = nodeJsonNames[tostring(node.parent)]
                    if not parentJsonName then goto nextNode end

                    -- Exclude collision nodes and their entire subtree by not registering
                    -- in nodeJsonNames — all descendants will fail the parentJsonName check.
                    if node:isInstanceOfType(tes3.niType.RootCollisionNode) then
                        goto nextNode
                    end

                    -- For light-bearing instances, skip nodes that are not lights
                    -- or ancestors of lights — the importer doesn't use them.
                    if config.jsonSelectiveChildNodesOnly and isLight and not lightAncestors[tostring(node)] then
                        goto nextNode
                    end

                    local baseName = (node.name and node.name ~= "") and node.name or "Node"

                    local nodeName
                    if config.jsonSequentialNaming then
                        local counterKey = baseName
                        idCounters[counterKey] = (idCounters[counterKey] or 0) + 1
                        local ci = idCounters[counterKey]
                        nodeName = ci == 1 and baseName or string.format("%s.%03d", baseName, ci - 1)
                    else
                        nodeName = baseName
                        idCounters[nodeName] = (idCounters[nodeName] or 0) + 1
                        if idCounters[nodeName] > 1 then
                            nodeName = string.format("%s (%s)", nodeName, tostring(node):match("0x(%w+)"))
                        end
                    end
                    nodeJsonNames[tostring(node)] = nodeName

                    local lt = { translation = node.translation, rotation = node.rotation, scale = node.scale }

                    local jsonType = nil
                    if node:isInstanceOfType(tes3.niType.NiBSParticleNode) then
                        jsonType = "PARTICLE"
                        emitEntry(nodeName, parentJsonName, lt, jsonType, nil)
                    elseif node:isInstanceOfType(tes3.niType.NiPointLight) or
                       node:isInstanceOfType(tes3.niType.NiSpotLight) then
                        jsonType = constants.jsonNodeTypes[tes3.niType.NiPointLight] or "LIGHT"
                        local cr = node.diffuse and node.diffuse.r or 1
                        local cg = node.diffuse and node.diffuse.g or 1
                        local cb = node.diffuse and node.diffuse.b or 1
                        local radius = node.radius or 0
                        local lightJson = table.concat({
                            "{",
                            "      " .. jsonString("type")             .. ": " .. jsonString("POINT") .. ",",
                            "      " .. jsonString("color")            .. ": [" .. jsonNumber(cr) .. ", " .. jsonNumber(cg) .. ", " .. jsonNumber(cb) .. "]",
                            "    }"
                        }, "\n    ")
                        emitLightEntry(nodeName, parentJsonName, lt, lightJson, jsonType)
                    elseif node:isInstanceOfType(tes3.niType.NiNode) then
                        jsonType = constants.jsonNodeTypes[tes3.niType.NiNode] or "EMPTY"
                        local meshScale = nil
                        if node.children then
                            for _, child in ipairs(node.children) do
                                if child and (child:isInstanceOfType(tes3.niType.NiTriShape) or
                                              child:isInstanceOfType(tes3.niType.NiTriStrips)) then
                                    meshScale = child.scale
                                    break
                                end
                            end
                        end
                        if meshScale and meshScale ~= 1 and meshScale ~= (lt.scale or 1) then
                            lt = { translation = lt.translation, rotation = lt.rotation, scale = meshScale }
                        end
                        emitEntry(nodeName, parentJsonName, lt, jsonType, nil)
                    elseif node:isInstanceOfType(tes3.niType.NiTriShape) or
                           node:isInstanceOfType(tes3.niType.NiTriStrips) then
                        jsonType = constants.jsonNodeTypes[tes3.niType.NiTriShape] or "EMPTY"
                        emitEntry(nodeName, parentJsonName, lt, jsonType, nil)
                    end

                    ::nextNode::
                end
                ::continue::
            end
        end
    end

    lfs.mkdir(config.exportFolder)
    local file, err = io.open(path, "w")
    if not file then
        tes3.messageBox("JSON export failed: %s", err or "unknown error")
        return
    end

    file:write("[\n")
    for i, entry in ipairs(entries) do
        file:write(entry)
        if i < #entries then file:write(",\n") else file:write("\n") end
    end
    file:write("]\n")
    file:close()

    local shortName = coords .. cellName .. suffix .. ".json"
    tes3.messageBox("JSON Exported: %s\n(%d of %d)", shortName, currentIndex or 1, totalCount or 1)
end

return jsons