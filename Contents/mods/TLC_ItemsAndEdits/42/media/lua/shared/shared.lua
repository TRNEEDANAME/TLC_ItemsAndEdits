local DurabilityAdjusted = false

TLC_ItemsAndEdits = TLC_ItemsAndEdits or {}

TLC_ItemsAndEdits.WoundBodyParts = {
    Head = "Head",
    Neck = "Neck",
    Groin = "Groin",
    TorsoUpper = "Torso_Upper",
    TorsoLower = "Torso_Lower",
    UpperTorso = "Torso_Upper",
    LowerTorso = "Torso_Lower",
    LeftUpperArm = "UpperArm_L",
    RightUpperArm = "UpperArm_R",
    LeftForearm = "ForeArm_L",
    RightForearm = "ForeArm_R",
    LeftHand = "Hand_L",
    RightHand = "Hand_R",
    LeftThigh = "UpperLeg_L",
    RightThigh = "UpperLeg_R",
    LeftShin = "LowerLeg_L",
    RightShin = "LowerLeg_R",
    LeftFoot = "Foot_L",
    RightFoot = "Foot_R",
}

TLC_ItemsAndEdits.WoundTypes = {
    Bleeding = "bleeding",
    Burn = "burn",
    Bullet = "bullet",
    DeepWound = "deepWound",
    Fracture = "fracture",
    GlassShard = "glass",
    Laceration = "cut",
    Scratch = "scratch",
}

function TLCItemEdits.GetWoundDuration(baseDuration)
    local settings = SandboxVars and SandboxVars.TLCItemEdits
    local multiplier = settings and settings.WoundDurationMultiplier or 1
    return baseDuration * multiplier
end

local function debugPrint(...)
    local settings = SandboxVars and SandboxVars.TLCItemEdits

    if settings and settings.Debug then
        print(...)
    end
end

local bowDurability = {
    { type = "Base.CrudeCarvedBow", conditionMax = 3, conditionLowerChance = 15 },
    { type = "Base.CarvedBow", conditionMax = 5, conditionLowerChance = 30 },
    { type = "Base.FineCarvedBow", conditionMax = 8, conditionLowerChance = 50 },
    { type = "Base.CompoundBowRed", conditionMax = 8, conditionLowerChance = 45 },
    { type = "Base.CompoundBowBlue", conditionMax = 8, conditionLowerChance = 45 },
    { type = "Base.CompoundBowGreen", conditionMax = 8, conditionLowerChance = 45 },
    { type = "Base.CompoundBowTan", conditionMax = 8, conditionLowerChance = 45 },
    { type = "Base.CompoundBowWhite", conditionMax = 8, conditionLowerChance = 45 },
    { type = "Base.CompoundBowBlack", conditionMax = 8, conditionLowerChance = 45 },
    { type = "Base.CompoundBowYellow", conditionMax = 8, conditionLowerChance = 45 },
    { type = "Base.CompoundBowPink", conditionMax = 8, conditionLowerChance = 45 },
    { type = "Base.CompoundBowHeavyRed", conditionMax = 9, conditionLowerChance = 42 },
    { type = "Base.CompoundBowHeavyBlue", conditionMax = 9, conditionLowerChance = 42 },
    { type = "Base.CompoundBowHeavyGreen", conditionMax = 9, conditionLowerChance = 42 },
    { type = "Base.CompoundBowHeavyTan", conditionMax = 9, conditionLowerChance = 42 },
    { type = "Base.CompoundBowHeavyWhite", conditionMax = 9, conditionLowerChance = 42 },
    { type = "Base.CompoundBowHeavyBlack", conditionMax = 9, conditionLowerChance = 42 },
    { type = "Base.CompoundBowHeavyYellow", conditionMax = 9, conditionLowerChance = 42 },
    { type = "Base.CompoundBowHeavyPink", conditionMax = 9, conditionLowerChance = 42 },
}

local function adjustBowDurability()
    if DurabilityAdjusted then
        return
    end

    for _, bow in ipairs(bowDurability) do
        local scriptItem = ScriptManager.instance:getItem(bow.type)
        if scriptItem then
            scriptItem:DoParam("ConditionMax = " .. tostring(bow.conditionMax * 3))
            scriptItem:DoParam("ConditionLowerChanceOneIn = " .. tostring(bow.conditionLowerChance * 2))
            debugPrint("New Durability for " .. bow.type .. " " .. tostring(bow.conditionMax))
            debugPrint("New ConditionLowerChanceOneIn for " .. bow.type .. " " .. tostring(bow.conditionLowerChance))
        end
    end

    DurabilityAdjusted = true
end

Events.OnGameBoot.Add(adjustBowDurability)