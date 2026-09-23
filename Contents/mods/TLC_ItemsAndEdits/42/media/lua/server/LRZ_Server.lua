-- LRZ_Server.lua
-- Loot removal: collects every container in the zone, groups matching items by
-- display category, and removes the requested percentage of each group.

require "LRZ_Shared"

-- Returns (bucket, rawDisplayCategory).
-- Anything not in LRZ.Categories goes to the "Other" bucket.
local function getItemCategory(item)
    local ok, cat = pcall(function() return item:getDisplayCategory() end)
    if ok and cat and cat ~= "" then
        local raw = tostring(cat)
        return LRZ.CategorySet[string.lower(raw)] or LRZ.OTHER_KEY, raw
    end
    return LRZ.OTHER_KEY, "(none)"
end

-- Gathers every ItemContainer on a single square: furniture/appliances
-- (which may expose several containers each) plus anything else that
-- exposes a container.
local function collectContainersOnSquare(square, containers, seen)
    local objs = square:getObjects()
    if not objs then return end

    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if obj then
            local found = {}

            if obj.getContainerCount and obj.getContainerByIndex then
                local okCount, count = pcall(function() return obj:getContainerCount() end)
                if okCount and count and count > 0 then
                    for ci = 0, count - 1 do
                        local okC, c = pcall(function() return obj:getContainerByIndex(ci) end)
                        if okC and c then
                            table.insert(found, c)
                        end
                    end
                end
            end

            if #found == 0 and obj.getContainer then
                local okC, c = pcall(function() return obj:getContainer() end)
                if okC and c then
                    table.insert(found, c)
                end
            end

            for _, c in ipairs(found) do
                if not seen[c] then
                    seen[c] = true
                    table.insert(containers, c)
                end
            end
        end
    end
end

local function collectContainers(x1, y1, x2, y2, z)
    local minX, maxX = math.min(x1, x2), math.max(x1, x2)
    local minY, maxY = math.min(y1, y2), math.max(y1, y2)

    local containers = {}
    local seen = {}
    local cell = getCell()

    for x = minX, maxX do
        for y = minY, maxY do
            local square = cell:getGridSquare(x, y, z)
            if square then
                collectContainersOnSquare(square, containers, seen)
            end
        end
    end

    return containers
end

-- Something something magic
local function removeLoot(player, args)
    if not LRZ.CanUse(player) then
        sendServerCommand(player, LRZ.ModuleName, "denied", {})
        return
    end

    local percent = tonumber(args.percent) or 100
    percent = math.max(0, math.min(100, percent))

    local wantAll = false
    local wanted = {}
    for _, c in ipairs(args.categories or { LRZ.ALL_KEY }) do
        if c == LRZ.ALL_KEY then wantAll = true end
        wanted[string.lower(c)] = true
    end

    local containers = collectContainers(args.x1, args.y1, args.x2, args.y2, args.z)

    local seenCats = {}
    -- buckets are cool
    local buckets = {}
    for _, container in ipairs(containers) do
        local items = container:getItems()
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            local cat, raw = getItemCategory(item)
            seenCats[raw] = (seenCats[raw] or 0) + 1
            if wantAll or wanted[string.lower(cat)] then
                buckets[cat] = buckets[cat] or {}
                table.insert(buckets[cat], { container = container, item = item })
            end
        end
    end

    for raw, n in pairs(seenCats) do
    end

    local totalRemoved = 0
    for cat, entries in pairs(buckets) do
        -- Fisher-Yates shuffle so the removed items are a random sample
        -- Thx Stack Overflow & wikipedia
        for i = #entries, 2, -1 do
            local j = ZombRand(1, i + 1)
            entries[i], entries[j] = entries[j], entries[i]
        end

        local toRemove = math.floor((#entries * percent / 100) + 0.5)

        for i = 1, toRemove do
            local entry = entries[i]
            entry.container:Remove(entry.item)
            if isServer() and sendRemoveItemFromContainer then
                sendRemoveItemFromContainer(entry.container, entry.item)
            end
            totalRemoved = totalRemoved + 1
        end
    end

    sendServerCommand(player, LRZ.ModuleName, "done", { removed = totalRemoved })
end

local function onClientCommand(module, command, player, args)
    if module ~= LRZ.ModuleName then return end
    if command == LRZ.CMD_REMOVE_LOOT then
        removeLoot(player, args)
    end
end

Events.OnClientCommand.Add(onClientCommand)
