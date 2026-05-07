local jsons = {}

local constants = require("ExportCells.constants")
local utils = require("ExportCells.utils")

local config = nil

function jsons.setConfig(cfg)
    config = cfg
end

-- Default replacement for nil json node type lookups (tied to a single variable)
local NIL_TYPE = constants.jsonNodeTypes[tes3.niType.NiNode]

local function resolveNodeTypeString(s)
    return s or NIL_TYPE
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
-- INTERNAL HELPERS
-- =============================================================================
function jsons.emitEntry(context, nodeName, parentName, transform, nodeType, extraFields)
    local matStr = buildMatrix4x4(transform)
    local lines = {
        "  {",
        "    " .. jsonString("name")         .. ": " .. jsonString(nodeName) .. ",",
        "    " .. jsonString("type")         .. ": " .. jsonString(resolveNodeTypeString(nodeType))  .. ",",
        "    " .. jsonString("matrix_local") .. ": [\n" .. matStr .. "\n    ],",
        "    " .. jsonString("parent")       .. ": " .. jsonString(parentName),
    }
    if extraFields then
        lines[#lines] = lines[#lines] .. ","
        for _, f in ipairs(extraFields) do table.insert(lines, f) end
    end
    lines[#lines] = lines[#lines]:gsub(",$", "")
    table.insert(lines, "  }")
    table.insert(context.entries, table.concat(lines, "\n"))
end

function jsons.emitLightEntry(context, nodeName, parentName, transform, lightData, nodeType)
    local matStr = buildMatrix4x4(transform)
    local lines = {
        "  {",
        "    " .. jsonString("name")         .. ": " .. jsonString(nodeName)   .. ",",
        "    " .. jsonString("type")         .. ": " .. jsonString(resolveNodeTypeString(nodeType))    .. ",",
        "    " .. jsonString("matrix_local") .. ": [\n" .. matStr .. "\n    ],",
        "    " .. jsonString("parent")       .. ": " .. jsonString(parentName) .. ",",
        "    " .. jsonString("light_data")   .. ": " .. lightData,
        "  }",
    }
    table.insert(context.entries, table.concat(lines, "\n"))
end

function jsons.processInstance(context, obj, sceneNode, instName, parentName, transformOverride, ref)
    local meshPath = obj.mesh
    if meshPath and meshPath ~= "" then
        local lower = meshPath:lower()
        if lower:find("meshes[\\/]grass[\\/]") or lower:find("^grass[\\/]") then
            return
        end
    end

    local objId    = obj.id
    local objName  = obj.name
    local objType  = obj.objectType
    local isLight  = (objType == tes3.objectType.light)
    local typeName = constants.objectTypeNames and constants.objectTypeNames[objType] or tostring(objType)
    local relMesh = utils.getRelativeMeshPath(meshPath)
    local canCarry = (objType == tes3.objectType.light and obj.canCarry == true)

    local fieldMap = {
        object_id      = function() return jsonString(objId) end,
        object_name    = function() return objName and objName ~= "" and jsonString(objName) end,
        object_type    = function() return jsonString(typeName) end,
        source_form_id = function() return ref and jsonNumber(ref.sourceFormId or 0) end,
        source_mod_id  = function() return ref and jsonNumber(ref.sourceModId or 0) end,
        source_mod     = function() return jsonString((ref and ref.sourceMod) or obj.sourceMod or "") end,
        can_carry      = function() return canCarry and "true" or nil end,
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

    local cloned = sceneNode:clone()
    local wt = transformOverride or sceneNode.worldTransform
    local rootTransform = wt

    jsons.emitEntry(context, instName, parentName, rootTransform, resolveNodeTypeString(constants.jsonNodeTypes[tes3.niType.NiNode]), fieldLines)

    -- Non-light instances: skip child traversal unless they contain particle nodes.
    local hasParticleNodes = false
    if config.jsonSelectiveChildNodesOnly and not isLight then
        local clonedCheck = sceneNode:clone()
        for node in table.traverse({clonedCheck}) do
            if node:isInstanceOfType(tes3.niType.NiBSParticleNode) then
                hasParticleNodes = true
                break
            end
        end
        if not hasParticleNodes then return end
    end

    local nodeJsonNames = {}
    nodeJsonNames[tostring(cloned)] = instName

    local selectedAncestors = {}
    local emitterList = {} -- { node, particleName, birthRate, speed, initialSize, jsonName }

    local function findEmitterEntry(node)
        for _, e in ipairs(emitterList) do
            if e.node == node then return e end
        end
    end

    for node in table.traverse({cloned}) do
        local isParticle  = node:isInstanceOfType(tes3.niType.NiBSParticleNode)
        local isLightNode = node:isInstanceOfType(tes3.niType.NiPointLight) or
                            node:isInstanceOfType(tes3.niType.NiSpotLight)

        if isLightNode or isParticle then
            selectedAncestors[tostring(node)] = true
            local p = node.parent
            while p and tostring(p) ~= tostring(cloned) do
                selectedAncestors[tostring(p)] = true
                p = p.parent
            end
        end

        if isParticle and node.children then
            for _, child in ipairs(node.children) do
                if child then
                    local ctrl = child.controller
                    while ctrl do
                        local ok, emNode = pcall(function() return ctrl.emitter end)
                        if ok and emNode then
                            if not findEmitterEntry(emNode) then
                                table.insert(emitterList, {
                                    node         = emNode,
                                    particleName = node.name or "",
                                    birthRate    = ctrl.birthRate,
                                    speed        = ctrl.speed,
                                    initialSize  = ctrl.initialSize,
                                })
                                selectedAncestors[tostring(emNode)] = true
                                local ep = emNode.parent
                                while ep and tostring(ep) ~= tostring(cloned) do
                                    selectedAncestors[tostring(ep)] = true
                                    ep = ep.parent
                                end
                            end
                            break
                        end
                        ctrl = ctrl.nextController
                    end
                end
            end
        end
    end

    for _, entry in ipairs(emitterList) do
        local emBase = (entry.node.name and entry.node.name ~= "") and entry.node.name or "emitter"
        local emName
        if config.jsonSequentialNaming then
            context.idCounters[emBase] = (context.idCounters[emBase] or 0) + 1
            local ci = context.idCounters[emBase]
            emName = ci == 1 and emBase or string.format("%s.%03d", emBase, ci - 1)
        else
            emName = emBase
            context.idCounters[emName] = (context.idCounters[emName] or 0) + 1
            if context.idCounters[emName] > 1 then
                emName = string.format("%s (%s)", emName, tostring(entry.node):match("0x(%w+)") or "?")
            end
        end
        entry.jsonName = emName
    end

    for node in table.traverse({cloned}) do
        if tostring(node) == tostring(cloned) then goto nextNode end
        if not node.parent then goto nextNode end

        local parentJsonName = nodeJsonNames[tostring(node.parent)]
        if not parentJsonName then goto nextNode end

        if node:isInstanceOfType(tes3.niType.RootCollisionNode) then
            goto nextNode
        end

        if config.jsonSelectiveChildNodesOnly and (isLight or hasParticleNodes) and not selectedAncestors[tostring(node)] and node.name ~= "AttachLight" then
            goto nextNode
        end

        local baseName = (node.name and node.name ~= "") and node.name or "Node"

        local nodeName
        if config.jsonSequentialNaming then
            context.idCounters[baseName] = (context.idCounters[baseName] or 0) + 1
            local ci = context.idCounters[baseName]
            nodeName = ci == 1 and baseName or string.format("%s.%03d", baseName, ci - 1)
        else
            nodeName = baseName
            context.idCounters[nodeName] = (context.idCounters[nodeName] or 0) + 1
            if context.idCounters[nodeName] > 1 then
                nodeName = string.format("%s (%s)", nodeName, tostring(node):match("0x(%w+)"))
            end
        end
        nodeJsonNames[tostring(node)] = nodeName

        local lt = { translation = node.translation, rotation = node.rotation, scale = node.scale }

        if node:isInstanceOfType(tes3.niType.NiBSParticleNode) then
            local ed = nil
            local emJsonName = nil
            if node.children then
                for _, child in ipairs(node.children) do
                    if child then
                        local ctrl = child.controller
                        while ctrl do
                            local ok, emNode = pcall(function() return ctrl.emitter end)
                            if ok then
                                if emNode then
                                    local entry = findEmitterEntry(emNode)
                                    if entry then
                                        local emitterType = constants.jsonSpecialNodeTypes and constants.jsonSpecialNodeTypes.EMITTER
                                        emJsonName = emitterType and entry.jsonName or (emNode.name or "")
                                        ed = entry
                                    end
                                end
                                local okB, _ = pcall(function() return ctrl.birthRate end)
                                if okB and not ed then
                                    ed = { birthRate = ctrl.birthRate, speed = ctrl.speed, initialSize = ctrl.initialSize }
                                end
                                break
                            end
                            ctrl = ctrl.nextController
                        end
                    end
                    if ed then break end
                end
            end

            local extraLines = {}
            if emJsonName then
                table.insert(extraLines, "    " .. jsonString("emitter") .. ": " .. jsonString(emJsonName) .. ",")
            end
            if ed then
                table.insert(extraLines, "    " .. jsonString("particle_system") .. ": {")
                table.insert(extraLines, "      " .. jsonString("birth_rate")   .. ": " .. jsonNumber(ed.birthRate)   .. ",")
                table.insert(extraLines, "      " .. jsonString("speed")        .. ": " .. jsonNumber(ed.speed)        .. ",")
                table.insert(extraLines, "      " .. jsonString("initial_size") .. ": " .. jsonNumber(ed.initialSize))
                table.insert(extraLines, "    }")
            end
            jsons.emitEntry(context, nodeName, parentJsonName, lt, resolveNodeTypeString(constants.jsonNodeTypes[tes3.niType.NiBSParticleNode]), #extraLines > 0 and extraLines or nil)

        elseif node:isInstanceOfType(tes3.niType.NiLODNode) then
            jsons.emitEntry(context, nodeName, parentJsonName, lt, resolveNodeTypeString(constants.jsonNodeTypes[tes3.niType.NiLODNode]), nil)

        elseif node:isInstanceOfType(tes3.niType.NiPointLight) then
            local cr = node.diffuse and node.diffuse.r or 1
            local cg = node.diffuse and node.diffuse.g or 1
            local cb = node.diffuse and node.diffuse.b or 1
            local lightJson = table.concat({
                "{",
                "      " .. jsonString("color") .. ": [" .. jsonNumber(cr) .. ", " .. jsonNumber(cg) .. ", " .. jsonNumber(cb) .. "]",
                "    }"
            }, "\n    ")
            jsons.emitLightEntry(context, nodeName, parentJsonName, lt, lightJson, resolveNodeTypeString(constants.jsonNodeTypes[tes3.niType.NiPointLight]))

        elseif node:isInstanceOfType(tes3.niType.NiSpotLight) then
            local cr = node.diffuse and node.diffuse.r or 1
            local cg = node.diffuse and node.diffuse.g or 1
            local cb = node.diffuse and node.diffuse.b or 1
            local lightJson = table.concat({
                "{",
                "      " .. jsonString("color") .. ": [" .. jsonNumber(cr) .. ", " .. jsonNumber(cg) .. ", " .. jsonNumber(cb) .. "]",
                "    }"
            }, "\n    ")
            jsons.emitLightEntry(context, nodeName, parentJsonName, lt, lightJson, resolveNodeTypeString(constants.jsonNodeTypes[tes3.niType.NiSpotLight]))

        elseif node:isInstanceOfType(tes3.niType.NiNode) then
            local entry = findEmitterEntry(node)
            if entry then
                local emitterType = constants.jsonSpecialNodeTypes and constants.jsonSpecialNodeTypes.EMITTER
                if not emitterType then goto nextNode end
                nodeName = entry.jsonName
                nodeJsonNames[tostring(node)] = nodeName
                jsons.emitEntry(context, nodeName, parentJsonName, lt, emitterType, nil)
            else
                jsons.emitEntry(context, nodeName, parentJsonName, lt, resolveNodeTypeString(constants.jsonNodeTypes[tes3.niType.NiNode]), nil)
            end

        elseif node:isInstanceOfType(tes3.niType.NiTriShape) or
               node:isInstanceOfType(tes3.niType.NiTriStrips) then
            jsons.emitEntry(context, nodeName, parentJsonName, lt, resolveNodeTypeString(constants.jsonNodeTypes[tes3.niType.NiTriShape]), nil)
        end

        ::nextNode::
    end
end

-- =============================================================================
-- EXPORT EXECUTION
-- =============================================================================
function jsons.export(regionCells, currentIndex, totalCount)
    local entries = {}

    local cell        = tes3.player.cell
    local cellName    = (cell.id):gsub(":", "-")
    local coords      = ""
    if not cell.isInterior then
        coords = string.format("%d,%d ", cell.gridX, cell.gridY)
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
        "    " .. jsonString("type") .. ": " .. jsonString(resolveNodeTypeString(constants.jsonNodeTypes[tes3.niType.NiNode])) .. ",",
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

    local context = {
        entries = entries,
        idCounters = idCounters,
    }

    for _, c in pairs(regionCells) do
        for ref in c:iterateReferences(config.exportTypes) do
            if ref and not ref.disabled and not ref.deleted and ref.sceneNode then
                local obj = ref.object
                if not obj then goto nextRef end

                local objId = obj.id
                context.idCounters[objId] = (context.idCounters[objId] or 0) + 1
                local count = context.idCounters[objId]
                local instName
                if config.jsonSequentialNaming then
                    instName = count == 1 and objId or string.format("%s.%03d", objId, count - 1)
                else
                    instName = count == 1 and objId or string.format("%s (%s)", objId, tostring(ref):match("0x(%w+)"))
                end

                jsons.processInstance(context, obj, ref.sceneNode, instName, rootName, nil, ref)

                ::nextRef::
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
    tes3.messageBox("JSON exported: %s\n(%d of %d)", shortName, currentIndex or 1, totalCount or 1)
end

function jsons.exportObjectGroup(folderName, objects, spacing, rowSize, path)
    local entries = {}
    local idCounters = {}
    local context = {
        entries = entries,
        idCounters = idCounters,
    }

    local rootName = folderName
    local rootLines = {
        "  {",
        "    " .. jsonString("name") .. ": " .. jsonString(rootName) .. ",",
        "    " .. jsonString("type") .. ": " .. jsonString(resolveNodeTypeString(constants.jsonNodeTypes[tes3.niType.NiNode])) .. ",",
        "    " .. jsonString("matrix_local") .. ": [\n      [1,0,0,0],\n      [0,1,0,0],\n      [0,0,1,0],\n      [0,0,0,1]\n    ],",
        "    " .. jsonString("parent") .. ": null",
        "  }"
    }
    table.insert(entries, table.concat(rootLines, "\n"))

    local count = 0
    for _, obj in ipairs(objects) do
        local node = tes3.loadMesh(obj.mesh)
        if node then
            local objId = obj.id
            context.idCounters[objId] = (context.idCounters[objId] or 0) + 1
            local ci = context.idCounters[objId]
            local instName = ci == 1 and objId or string.format("%s.%03d", objId, ci - 1)

            local x = (count % rowSize) * spacing
            local y = math.floor(count / rowSize) * spacing
            local transform = {
                translation = tes3vector3.new(x, y, 0),
                rotation = tes3matrix33.new(1,0,0, 0,1,0, 0,0,1),
                scale = 1.0
            }

            jsons.processInstance(context, obj, node, instName, rootName, transform, nil)
            count = count + 1
        end
    end

    lfs.mkdir(config.exportFolder)
    local file, err = io.open(path, "w")
    if not file then
        tes3.messageBox("JSON object export failed: %s", err or "unknown error")
        return
    end

    file:write("[\n")
    for i, entry in ipairs(entries) do
        file:write(entry)
        if i < #entries then file:write(",\n") else file:write("\n") end
    end
    file:write("]\n")
    file:close()
end

return jsons