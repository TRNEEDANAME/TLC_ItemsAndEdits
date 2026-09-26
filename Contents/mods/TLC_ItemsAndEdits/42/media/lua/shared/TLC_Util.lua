--[[
    TLC_Util.lua  (shared)

    Helpers shared by the Tile Copy tool and the Loot Remover / Adder:
      - access checks
      - floor / number clamping
      - finding every container in an area
      - adding / removing / clearing container items with MP sync
]]

TLC_Util = TLC_Util or {}
local Util = TLC_Util

-- Lowest/highest floor accepted (B42 has basements)
Util.MIN_Z = -32
Util.MAX_Z = 31

--------------------------------------------------------------------------
-- Misc
--------------------------------------------------------------------------

function Util.joinArgs(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    return table.concat(parts, " ")
end

function Util.clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

function Util.clampZ(z)
    return Util.clamp(math.floor(z), Util.MIN_Z, Util.MAX_Z)
end

--- Floor the player is standing on (0 when there's no player).
function Util.playerFloor(player)
    player = player or getPlayer()
    return player and math.floor(player:getZ()) or 0
end

--- Parses a "from" / "to" floor pair (text or numbers) into a sorted,
--- clamped range. Missing values fall back to the player's floor.
function Util.parseFloorRange(fromValue, toValue)
    local z = Util.playerFloor()
    local z1 = tonumber(fromValue) or z
    local z2 = tonumber(toValue) or z1
    z1, z2 = Util.clampZ(z1), Util.clampZ(z2)
    return math.min(z1, z2), math.max(z1, z2)
end

-- Fisher-Yates shuffle
-- Thx Stack Overflow & wikipedia
function Util.shuffle(list)
    for i = #list, 2, -1 do
        local j = ZombRand(1, i + 1)
        list[i], list[j] = list[j], list[i]
    end
end

--------------------------------------------------------------------------
-- Access
--------------------------------------------------------------------------

--- True if `player`'s access level is in `allowed` (a set of lowercase
--- names, e.g. { admin = true }). Always true in single player.
function Util.hasAccess(player, allowed)
    if not player then return false end

    if not isClient() and not isServer() then
        -- Single player: allow freely.
        return true
    end

    local level = player:getAccessLevel()
    if not level or level == "" then return false end

    -- getAccessLevel() returns lowercase names ("admin") in MP
    return allowed[string.lower(tostring(level))] == true
end

--------------------------------------------------------------------------
-- Containers
--------------------------------------------------------------------------

--- Every ItemContainer on an object (a fridge has a fridge + freezer).
function Util.getObjectContainers(obj)
    local list = {}
    if obj.getContainerCount and obj.getContainerByIndex then
        local count = obj:getContainerCount()
        if count and count > 0 then
            for i = 0, count - 1 do
                local c = obj:getContainerByIndex(i)
                if c then list[#list + 1] = c end
            end
        end
    end
    if #list == 0 and obj.getContainer then
        local c = obj:getContainer()
        if c then list[#list + 1] = c end
    end
    return list
end

--- Every container on the loaded squares of an area (x/y inclusive,
--- across floors z1..z2), each listed once.
function Util.collectContainers(x1, y1, x2, y2, z1, z2)
    local containers = {}
    local seen = {}
    local cell = getCell()
    if not cell then return containers end

    for z = z1, z2 do
        for x = x1, x2 do
            for y = y1, y2 do
                local square = cell:getGridSquare(x, y, z)
                local objs = square and square:getObjects()
                if objs then
                    for i = 0, objs:size() - 1 do
                        local obj = objs:get(i)
                        if obj then
                            for _, c in ipairs(Util.getObjectContainers(obj)) do
                                if not seen[c] then
                                    seen[c] = true
                                    containers[#containers + 1] = c
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return containers
end

--- Adds a new item of `fullType` and syncs it to clients.
function Util.addItem(container, fullType)
    local item = container:AddItem(fullType)
    if item and isServer() and sendAddItemToContainer then
        sendAddItemToContainer(container, item)
    end
    return item
end

--- Removes `item` and syncs the removal to clients.
function Util.removeItem(container, item)
    container:Remove(item)
    if isServer() and sendRemoveItemFromContainer then
        sendRemoveItemFromContainer(container, item)
    end
end

--- Empties a container (synced). Returns how many items were removed.
function Util.clearContainer(container)
    local items = container:getItems()
    local count = items:size()
    if count == 0 then return 0 end
    if isServer() and sendRemoveItemsFromContainer then
        sendRemoveItemsFromContainer(container, items)
    end
    container:removeItemsFromProcessItems()
    container:clear()
    return count
end

--- Rolls fresh vanilla loot into a container (the admin "Refill container"),
--- on top of whatever is already there. Returns how many items were added.
function Util.rerollContainer(container, player)
    local square = container:getSourceGrid()
    local room = square and square:getRoom()
    local roomDef = room and room:getRoomDef()
    local procedural = roomDef and roomDef:getProceduralSpawnedContainer()
    if procedural then procedural:clear() end

    local items = container:getItems()
    local before = items:size()
    ItemPickerJava.fillContainer(container, player)
    local after = items:size()

    if after > before and isServer() and sendAddItemsToContainer then
        local added = ArrayList.new()
        for i = before, after - 1 do
            added:add(items:get(i))
        end
        sendAddItemsToContainer(container, added)
    end
    return math.max(0, after - before)
end

--- Call after changing containers' contents: marks them explored so the
--- game doesn't roll loot into them again, and refreshes shelf overlays.
function Util.finishContainers(containers)
    local parents = {}
    for _, container in ipairs(containers) do
        container:setExplored(true)
        container:setDrawDirty(true)
        local parent = container:getParent()
        if parent and not parents[parent] then
            parents[parent] = true
            ItemPickerJava.updateOverlaySprite(parent)
        end
    end
end
