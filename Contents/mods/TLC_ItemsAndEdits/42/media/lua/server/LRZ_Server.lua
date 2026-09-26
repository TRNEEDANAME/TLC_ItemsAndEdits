-- LRZ_Server.lua
-- Loot removal / adding: collects every container in the zone (across a
-- floor range) and either
--   - removes a percentage of each checked category (bulk), or
--   - reports a per-item breakdown (scan), or
--   - trims specific item types down to a target amount (apply edits), or
--   - adds picked items / rerolls vanilla loot, on top of or replacing
--     what's there (add loot).

require "LRZ_Shared"

local Util = TLC_Util

-- Returns (bucket, rawDisplayCategory).
-- Anything not in LRZ.Categories goes to the "Other" bucket.
local function getItemCategory(item)
    local cat = item:getDisplayCategory()
    if cat and cat ~= "" then
        local raw = tostring(cat)
        return LRZ.CategorySet[string.lower(raw)] or LRZ.OTHER_KEY, raw
    end
    return LRZ.OTHER_KEY, "(none)"
end

-- Checks permissions and area size, then returns the zone's containers
-- (or nil after telling the client why not).
local function containersForRequest(player, args)
    if not LRZ.CanUse(player) then
        sendServerCommand(player, LRZ.ModuleName, LRZ.RES_DENIED, {})
        return nil
    end

    local x1, y1, x2, y2, z1, z2 = LRZ.NormaliseBounds(args)
    local squares = LRZ.SquareCount(x1, y1, x2, y2, z1, z2)
    if squares > LRZ.MAX_SQUARES then
        sendServerCommand(player, LRZ.ModuleName, LRZ.RES_TOO_BIG, { squares = squares, max = LRZ.MAX_SQUARES })
        return nil
    end

    return Util.collectContainers(x1, y1, x2, y2, z1, z2)
end

local function removeEntries(entries, count)
    local removed = 0
    for i = 1, math.min(count, #entries) do
        local entry = entries[i]
        Util.removeItem(entry.container, entry.item)
        removed = removed + 1
    end
    return removed
end

-- Per item type totals for the breakdown list.
local function buildBreakdown(containers)
    local byType = {}
    local list = {}
    local total = 0
    for _, container in ipairs(containers) do
        local items = container:getItems()
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            local fullType = item:getFullType()
            local entry = byType[fullType]
            if not entry then
                local cat = getItemCategory(item)
                entry = { type = fullType, name = item:getDisplayName(), cat = cat, count = 0 }
                byType[fullType] = entry
                table.insert(list, entry)
            end
            entry.count = entry.count + 1
            total = total + 1
        end
    end
    return list, total, #containers
end

local function sendBreakdown(player, containers, removed)
    local list, total, containerCount = buildBreakdown(containers)
    sendServerCommand(player, LRZ.ModuleName, LRZ.RES_SCAN, {
        entries = list,
        total = total,
        containers = containerCount,
        removed = removed,
    })
end

-- Bulk: removes `percent` of every checked category.
local function removeLoot(player, args)
    local containers = containersForRequest(player, args)
    if not containers then return end

    local percent = tonumber(args.percent) or 100
    percent = Util.clamp(percent, 0, 100)

    local wantAll = false
    local wanted = {}
    for _, c in ipairs(args.categories or { LRZ.ALL_KEY }) do
        if c == LRZ.ALL_KEY then wantAll = true end
        wanted[string.lower(c)] = true
    end

    -- buckets are cool
    local buckets = {}
    for _, container in ipairs(containers) do
        local items = container:getItems()
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            local cat = getItemCategory(item)
            if wantAll or wanted[string.lower(cat)] then
                buckets[cat] = buckets[cat] or {}
                table.insert(buckets[cat], { container = container, item = item })
            end
        end
    end

    local totalRemoved = 0
    for _, entries in pairs(buckets) do
        Util.shuffle(entries)
        local toRemove = math.floor((#entries * percent / 100) + 0.5)
        totalRemoved = totalRemoved + removeEntries(entries, toRemove)
    end

    sendServerCommand(player, LRZ.ModuleName, LRZ.RES_DONE, { removed = totalRemoved, containers = #containers })
    if args.rescan then
        sendBreakdown(player, containers, totalRemoved)
    end
end

-- Breakdown: just report what's in there.
local function scanLoot(player, args)
    local containers = containersForRequest(player, args)
    if not containers then return end
    sendBreakdown(player, containers, nil)
end

-- Breakdown: args.edits = { { type = "Base.Axe", target = 2 }, ... }
-- Removes random copies of each type until only `target` are left.
local function applyEdits(player, args)
    local containers = containersForRequest(player, args)
    if not containers then return end

    local targets = {}
    for _, edit in ipairs(args.edits or {}) do
        local target = tonumber(edit.target)
        if edit.type and target then
            targets[edit.type] = math.max(0, math.floor(target))
        end
    end

    local byType = {}
    for _, container in ipairs(containers) do
        local items = container:getItems()
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            local fullType = item:getFullType()
            if targets[fullType] then
                byType[fullType] = byType[fullType] or {}
                table.insert(byType[fullType], { container = container, item = item })
            end
        end
    end

    local totalRemoved = 0
    for fullType, entries in pairs(byType) do
        local excess = #entries - targets[fullType]
        if excess > 0 then
            Util.shuffle(entries)
            totalRemoved = totalRemoved + removeEntries(entries, excess)
        end
    end

    sendServerCommand(player, LRZ.ModuleName, LRZ.RES_DONE, { removed = totalRemoved, containers = #containers })
    sendBreakdown(player, containers, totalRemoved)
end

-- Only real item types, with a sane amount.
local function validItemRequests(list)
    local valid = {}
    for _, req in ipairs(list or {}) do
        local count = tonumber(req.count)
        if type(req.type) == "string" and count and count >= 1
            and ScriptManager.instance:getItem(req.type) then
            table.insert(valid, { type = req.type, count = math.floor(count) })
        end
    end
    return valid
end

-- Adder: args.source = LRZ.SOURCE_ITEMS (args.items = { { type, count } },
-- args.perContainer) or LRZ.SOURCE_REROLL. args.replace empties the
-- containers first.
local function addLoot(player, args)
    local zoneContainers = containersForRequest(player, args)
    if not zoneContainers then return end

    -- Corpses aren't loot spots
    local containers = {}
    for _, c in ipairs(zoneContainers) do
        if not instanceof(c:getParent(), "IsoDeadBody") then
            table.insert(containers, c)
        end
    end

    local items
    if args.source ~= LRZ.SOURCE_REROLL then
        items = validItemRequests(args.items)
        if #items == 0 then
            sendServerCommand(player, LRZ.ModuleName, LRZ.RES_ADDED, { error = "No valid items to add." })
            return
        end
        local total = 0
        for _, req in ipairs(items) do
            total = total + (args.perContainer and req.count * #containers or req.count)
        end
        if total > LRZ.MAX_ADD_ITEMS then
            sendServerCommand(player, LRZ.ModuleName, LRZ.RES_ADDED, {
                error = "Too many items: " .. total .. " (max " .. LRZ.MAX_ADD_ITEMS .. ")",
            })
            return
        end
    end

    local cleared = 0
    if args.replace then
        for _, c in ipairs(containers) do
            cleared = cleared + Util.clearContainer(c)
        end
    end

    local added = 0
    if #containers > 0 then
        if args.source == LRZ.SOURCE_REROLL then
            for _, c in ipairs(containers) do
                added = added + Util.rerollContainer(c, player)
            end
        else
            for _, req in ipairs(items) do
                if args.perContainer then
                    for _, c in ipairs(containers) do
                        for _ = 1, req.count do
                            if Util.addItem(c, req.type) then added = added + 1 end
                        end
                    end
                else
                    for _ = 1, req.count do
                        local c = containers[ZombRand(#containers) + 1]
                        if Util.addItem(c, req.type) then added = added + 1 end
                    end
                end
            end
        end
        Util.finishContainers(containers)
    end

    sendServerCommand(player, LRZ.ModuleName, LRZ.RES_ADDED, {
        added = added,
        cleared = cleared,
        containers = #containers,
    })
    if args.rescan then
        sendBreakdown(player, zoneContainers, nil)
    end
end

local function onClientCommand(module, command, player, args)
    if module ~= LRZ.ModuleName then return end
    if command == LRZ.CMD_REMOVE_LOOT then
        removeLoot(player, args)
    elseif command == LRZ.CMD_SCAN then
        scanLoot(player, args)
    elseif command == LRZ.CMD_APPLY_EDITS then
        applyEdits(player, args)
    elseif command == LRZ.CMD_ADD_LOOT then
        addLoot(player, args)
    end
end

Events.OnClientCommand.Add(onClientCommand)
