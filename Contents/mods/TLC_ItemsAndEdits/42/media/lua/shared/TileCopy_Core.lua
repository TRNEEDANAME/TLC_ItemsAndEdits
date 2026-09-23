--[[
    TileCopy_Core.lua  (shared)

    The actual "copy" and "paste" logic, kept separate from any UI so it can
    be called from the client (single player / previewing) and from the
    server (authoritative placement in multiplayer).

    Layer definitions used by this mod
      - TILES      : the floor sprite, plus every "structural" object on the
                      square : walls, windows, doors, furniture, containers...
      - CONTAINERS : when enabled, the *contents* of any container object
                      that gets copied as part of the TILES layer are copied
                      too (item type, count, condition/uses where possible).
                      Turning this off still copies the container itself
                      (e.g. an empty crate) if TILES is on - it only skips
                      the items inside it.
      - OVERLAY    : everything left over that isn't structural - rugs,
                      ground clutter, moss/dirt/blood-type decorative
                      sprites sitting on top of the floor.
--]]

TileCopy = TileCopy or {}
TileCopy.Core = TileCopy.Core or {}
local Core = TileCopy.Core
local Util = TileCopy.Util

local function isStructuralObject(obj)
    local ok, container = pcall(function() return obj:getContainer() end)
    if ok and container then return true end

    local okProps, props = pcall(function() return obj:getProperties() end)
    if okProps and props then
        local flags = { "solid", "solidtrans", "collideN", "collideW", "Wall", "wallN", "wallW", "HoppableN", "HoppableW" }
        for _, flag in ipairs(flags) do
            local okFlag, isSet = pcall(function() return props:Is(flag) end)
            if okFlag and isSet then return true end
        end
    end

    local okInst, isDoorOrThump = pcall(function()
        return instanceof(obj, "IsoDoor") or instanceof(obj, "IsoThumpable") or instanceof(obj, "IsoWindow")
    end)
    if okInst and isDoorOrThump then return true end

    return false
end

local function getSpriteNameSafe(obj)
    local ok, name = pcall(function() return obj:getSpriteName() end)
    if ok and name then return name end
    local ok2, sprite = pcall(function() return obj:getSprite() end)
    if ok2 and sprite then
        local ok3, name3 = pcall(function() return sprite:getName() end)
        if ok3 then return name3 end
    end
    return nil
end

--- Captures the contents (items) of a container object.
function Core.captureContainer(obj)
    local ok, container = pcall(function() return obj:getContainer() end)
    if not ok or not container then return nil end

    local items = {}
    local okItems, itemList = pcall(function() return container:getItems() end)
    if okItems and itemList then
        for i = 0, itemList:size() - 1 do
            local item = itemList:get(i)
            local entry = {}
            local okFull, fullType = pcall(function() return item:getFullType() end)
            if okFull then entry.fullType = fullType end

            local okCount, count = pcall(function() return item:getCount() end)
            if okCount and count then entry.count = count end

            local okCond, cond = pcall(function() return item:getCondition() end)
            if okCond and cond then entry.condition = cond end

            local okUses, uses = pcall(function() return item:getCurrentUsesFloat() end)
            if okUses and uses then entry.uses = uses end

            if entry.fullType then
                items[#items + 1] = entry
            end
        end
    end

    local containerType, capacity
    pcall(function() containerType = container:getType() end)
    pcall(function() capacity = container:getCapacity() end)

    return {
        containerType = containerType,
        capacity = capacity,
        items = items,
    }
end

--- Captures a rectangular region into a data table.
-- @param x1,y1,x2,y2 any two opposite corners (order doesn't matter)
-- @param z            floor/z-level to copy
-- @param opts         { includeTiles=bool, includeContainers=bool, includeOverlay=bool }
function Core.captureArea(x1, y1, x2, y2, z, opts)
    opts = opts or {}
    local includeTiles = opts.includeTiles ~= false
    local includeContainers = opts.includeContainers ~= false
    local includeOverlay = opts.includeOverlay ~= false

    local minX, maxX = math.min(x1, x2), math.max(x1, x2)
    local minY, maxY = math.min(y1, y2), math.max(y1, y2)

    local cell = getCell()
    local data = {
        width = maxX - minX + 1,
        height = maxY - minY + 1,
        includeTiles = includeTiles,
        includeContainers = includeContainers,
        includeOverlay = includeOverlay,
        squares = {},
    }

    for y = minY, maxY do
        for x = minX, maxX do
            local sq = cell and cell:getGridSquare(x, y, z)
            local entry = { dx = x - minX, dy = y - minY }

            if sq then
                if includeTiles then
                    local okFloor, floorObj = pcall(function() return sq:getFloor() end)
                    if okFloor and floorObj then
                        entry.floor = getSpriteNameSafe(floorObj)
                    end
                end

                -- This whole thing is a mess, don't show that to the "never nester", they'll have an aneurism
                local structObjects, overlayObjects = {}, {}
                local okObjs, objs = pcall(function() return sq:getObjects() end)
                if okObjs and objs then
                    local floorRef = sq:getFloor()
                    for i = 0, objs:size() - 1 do
                        local obj = objs:get(i)
                        if obj ~= floorRef then
                            local spriteName = getSpriteNameSafe(obj)
                            if spriteName then
                                if isStructuralObject(obj) then
                                    if includeTiles then
                                        local rec = { sprite = spriteName }
                                        if includeContainers then
                                            local containerData = Core.captureContainer(obj)
                                            if containerData then rec.container = containerData end
                                        end
                                        structObjects[#structObjects + 1] = rec
                                    end
                                else
                                    if includeOverlay then
                                        overlayObjects[#overlayObjects + 1] = { sprite = spriteName }
                                    end
                                end
                            end
                        end
                    end
                end

                if includeTiles then entry.objects = structObjects end
                if includeOverlay then entry.overlay = overlayObjects end
            end

            data.squares[#data.squares + 1] = entry
        end
    end

    Util.log("captureArea: captured", data.width, "x", data.height, "squares")
    return data
end

--- Places the items saved for one container object.
function Core.applyContainer(obj, containerData)
    if not containerData or not containerData.items then return end
    local okContainer, container = pcall(function() return obj:getContainer() end)
    if not okContainer or not container then return end

    for _, itemData in ipairs(containerData.items) do
        if itemData.fullType then
            local okAdd, newItem = pcall(function() return container:AddItem(itemData.fullType) end)
            if okAdd and newItem then
                if itemData.count and newItem.setCount then
                    pcall(function() newItem:setCount(itemData.count) end)
                end
                if itemData.condition and newItem.setCondition then
                    pcall(function() newItem:setCondition(itemData.condition) end)
                end
                if itemData.uses and newItem.setCurrentUsesFloat then
                    pcall(function() newItem:setCurrentUsesFloat(itemData.uses) end)
                end
            end
        end
    end
    pcall(function() container:setDrawDirty(true) end)
end

--- Pastes a previously captured data table with its (0,0) corner at
--- destX,destY,destZ.
function Core.applyArea(data, destX, destY, destZ)
    if not data or not data.squares then return false end
    local cell = getCell()
    if not cell then return false end

    for _, entry in ipairs(data.squares) do
        local x, y, z = destX + entry.dx, destY + entry.dy, destZ
        local sq = cell:getGridSquare(x, y, z)
        if sq then
            if entry.floor then
                local okNew, floorObj = pcall(function() return IsoObject.new(sq, entry.floor) end)
                if okNew and floorObj then
                    pcall(function() sq:AddTileObject(floorObj) end)
                end
            end

            if entry.objects then
                for _, rec in ipairs(entry.objects) do
                    local okNew, obj = pcall(function() return IsoObject.new(sq, rec.sprite) end)
                    if okNew and obj then
                        pcall(function() sq:AddTileObject(obj) end)
                        if rec.container then
                            Core.applyContainer(obj, rec.container)
                        end
                    end
                end
            end

            if entry.overlay then
                for _, rec in ipairs(entry.overlay) do
                    local okNew, obj = pcall(function() return IsoObject.new(sq, rec.sprite) end)
                    if okNew and obj then
                        pcall(function() sq:AddTileObject(obj) end)
                    end
                end
            end

            pcall(function() sq:RecalcAllWithNeighbours(true) end)
        else
            Util.log("applyArea: target square not loaded at", x, y, z, "- skipped")
        end
    end

    return true
end

return Core
