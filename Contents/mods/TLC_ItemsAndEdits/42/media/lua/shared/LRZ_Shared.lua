-- LRZ_Shared.lua
-- Shared constants/helpers for the Loot Removal Zones mod (remover + adder).
-- Loaded on both client and server.

require "TLC_Util"

LRZ = LRZ or {}
LRZ.ModuleName = "LRZ"

-- Client -> Server command names
LRZ.CMD_REMOVE_LOOT = "removeLoot"   -- bulk: % of the checked categories
LRZ.CMD_SCAN = "scanLoot"            -- breakdown: list every item type in the zone
LRZ.CMD_APPLY_EDITS = "applyEdits"   -- breakdown: set per-item target amounts
LRZ.CMD_ADD_LOOT = "addLoot"         -- adder: add picked items or reroll vanilla loot

-- Server -> Client command names
LRZ.RES_DONE = "done"
LRZ.RES_DENIED = "denied"
LRZ.RES_SCAN = "scanResult"
LRZ.RES_TOO_BIG = "tooBig"
LRZ.RES_ADDED = "added"

-- Loot adder sources
LRZ.SOURCE_ITEMS = "items"     -- the item types / amounts the admin picked
LRZ.SOURCE_REROLL = "reroll"   -- vanilla loot tables, like the admin "Refill container"

-- Hard cap on squares visited per request (width * height * floors)
LRZ.MAX_SQUARES = 250000

-- Hard cap on items spawned by one "add items" request
LRZ.MAX_ADD_ITEMS = 5000

-- Lowest/highest floor the Z range accepts (B42 has basements)
LRZ.MIN_Z = TLC_Util.MIN_Z
LRZ.MAX_Z = TLC_Util.MAX_Z

LRZ.ALL_KEY = "ALL"

-- Bucket for any item whose display category isn't in LRZ.Categories
LRZ.OTHER_KEY = "Other"

-- Display categories offered in the checkbox list (item script DisplayCategory keys).
LRZ.Categories = {
    -- weapons & ammo
    "Weapon", "WeaponPart", "Ammo", "Explosives", "Security",
    -- food, medical, clothing, containers
    "Food", "Cooking", "FirstAid", "Bandage", "Clothing",
    "ProtectiveGear", "Bag",
    "Literature", "SkillBook",
    -- materials & tools
    "Material", "RecipeResource", "Tool", "VehicleMaintenance", "Electronics",
    "Communications", "LightSource", "Camping", "Fishing",
    "Trapping", "Gardening", "Household",
    -- everything not listed above
    "Other",
}

LRZ.CategorySet = {}
for _, c in ipairs(LRZ.Categories) do
    LRZ.CategorySet[string.lower(c)] = c
end

-- Normalises a request's bounds: sorted corners and a clamped, sorted Z range.
-- Older clients only send `z`, so fall back to that for both ends.
function LRZ.NormaliseBounds(args)
    local x1, x2 = math.min(args.x1, args.x2), math.max(args.x1, args.x2)
    local y1, y2 = math.min(args.y1, args.y2), math.max(args.y1, args.y2)
    local z1 = tonumber(args.z1) or tonumber(args.z) or 0
    local z2 = tonumber(args.z2) or tonumber(args.z) or z1
    z1, z2 = TLC_Util.clampZ(math.min(z1, z2)), TLC_Util.clampZ(math.max(z1, z2))
    return x1, y1, x2, y2, z1, z2
end

function LRZ.SquareCount(x1, y1, x2, y2, z1, z2)
    return (x2 - x1 + 1) * (y2 - y1 + 1) * (z2 - z1 + 1)
end

-- Error text when a request's area is over LRZ.MAX_SQUARES, else nil.
function LRZ.TooBigMessage(args)
    local squares = LRZ.SquareCount(args.x1, args.y1, args.x2, args.y2, args.z1, args.z2)
    if squares > LRZ.MAX_SQUARES then
        return "Area too big: " .. squares .. " squares (max " .. LRZ.MAX_SQUARES .. ")"
    end
    return nil
end

LRZ.AllowedAccessLevels = {
    admin = true,
    moderator = false,
    overseer = false,
    gm = false,
}

function LRZ.CanUse(player)
    return TLC_Util.hasAccess(player, LRZ.AllowedAccessLevels)
end

-- "W x H tiles on floors a to b" for status lines / confirmations.
function LRZ.DescribeArea(args)
    local text = (args.x2 - args.x1 + 1) .. " x " .. (args.y2 - args.y1 + 1) .. " tiles"
    if args.z1 == args.z2 then
        return text .. " on floor " .. args.z1
    end
    return text .. " on floors " .. args.z1 .. " to " .. args.z2
end
