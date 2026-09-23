-- LRZ_Shared.lua
-- Shared constants/helpers for the Loot Removal Zones mod.
-- Loaded on both client and server.

LRZ = LRZ or {}
LRZ.ModuleName = "LRZ"

-- Client -> Server command name
LRZ.CMD_REMOVE_LOOT = "removeLoot"

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

LRZ.AllowedAccessLevels = {
    admin = true,
    moderator = false,
    overseer = false,
    gm = false,
}

function LRZ.CanUse(player)
    if not player then return false end

    local level = player:getAccessLevel()
    if level and level ~= "" and LRZ.AllowedAccessLevels[string.lower(level)] == true then
        return true
    end
    return false
end
