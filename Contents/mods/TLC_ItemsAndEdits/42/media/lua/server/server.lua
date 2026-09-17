local function sendWoundResult(player, message)
	sendServerCommand(player, "MongooseChat", "SystemMessage", {
		message = message,
		color = {200, 200, 200},
	})
end

local function findWoundEntry(entries, name)
	if type(name) ~= "string" then
		return nil
	end

	local normalizedName = name:lower()
	for entryName, entryValue in pairs(entries) do
		if entryName:lower() == normalizedName then
			return entryValue
		end
	end

	return nil
end

local woundActions = {
	bleeding = function(bodyPart)
		bodyPart:setBleeding(true)
		bodyPart:setBleedingTime(TLCItemEdits.GetWoundDuration(10))
	end,
	burn = function(bodyPart)
		bodyPart:setBurned()
		bodyPart:setBurnTime(TLCItemEdits.GetWoundDuration(50))
	end,
	bullet = function(bodyPart)
		bodyPart:setHaveBullet(true, 0)
	end,
	cut = function(bodyPart)
		bodyPart:setCut(true, true)
		bodyPart:setCutTime(TLCItemEdits.GetWoundDuration(10))
	end,
	deepWound = function(bodyPart)
		bodyPart:generateDeepWound()
		bodyPart:setDeepWoundTime(TLCItemEdits.GetWoundDuration(20))
	end,
	fracture = function(bodyPart)
		bodyPart:generateFracture(10.0)
		bodyPart:setFractureTime(TLCItemEdits.GetWoundDuration(30))
	end,
	glass = function(bodyPart)
		bodyPart:generateDeepShardWound()
	end,
	scratch = function(bodyPart)
		bodyPart:setScratched(true, true)
		bodyPart:setScratchTime(TLCItemEdits.GetWoundDuration(10))
	end,
}


local function applyWound(player, bodyPartName, woundType)
	local bodyPartTypeName = findWoundEntry(TLC_ItemsAndEdits.WoundBodyParts, bodyPartName)
	local woundAction = findWoundEntry(TLC_ItemsAndEdits.WoundTypes, woundType)
	if not bodyPartTypeName or not woundAction then
		sendWoundResult(player, "Usage: /wound LeftHand Bleeding|Burn|Bullet|DeepWound|Fracture|GlassShard|Laceration|Scratch")
		return
	end

	local bodyPartType = BodyPartType[bodyPartTypeName]
	local bodyPart = bodyPartType and player:getBodyDamage():getBodyPart(bodyPartType) or nil
	local applyWoundAction = woundActions[woundAction]
	if not bodyPart or not applyWoundAction then
		sendWoundResult(player, "Unable to create wound")
		return
	end

	applyWoundAction(bodyPart)
	syncBodyPart(bodyPart, 0xFFFFFFFFFFF)
	sendWoundResult(player, woundType .. " created on " .. bodyPartName)
end

local function sendWoundHelp(player)
	sendWoundResult(player, "Body parts: Head, Neck, Groin, UpperTorso, LowerTorso")
	sendWoundResult(player, "Body parts: LeftUpperArm, RightUpperArm, LeftForearm, RightForearm")
	sendWoundResult(player, "Body parts: LeftHand, RightHand, LeftThigh, RightThigh")
	sendWoundResult(player, "Body parts: LeftShin, RightShin, LeftFoot, RightFoot")
	sendWoundResult(player, "Wound types: Bleeding, Burn, Bullet, DeepWound, Fracture")
	sendWoundResult(player, "Wound types: GlassShard, Laceration, Scratch")
	sendWoundResult(player, "Example: /wound LeftHand DeepWound")
end

local function getWoundArguments(argString)
	if type(argString) == "table" then
		local arguments = argString.args or argString
		if type(arguments) == "table" then
			if arguments.bodyPartName or arguments.woundType then
				return arguments.bodyPartName, arguments.woundType
			end
			if arguments[2] then
				return arguments[1], arguments[2]
			end
			argString = arguments[1]
		else
			argString = arguments
		end
	end

	if type(argString) ~= "string" then
		return nil, nil
	end

	return argString:match("^%s*(%S+)%s*(%S*)%s*$")
end


local function handleWoundCommand(player, argString, commandArguments)
	if commandArguments ~= nil then
		argString = commandArguments
	end

	local bodyPartName, woundType = getWoundArguments(argString)
	if woundType == "" then
		woundType = nil
	end
	if bodyPartName == "help" and not woundType then
		sendWoundHelp(player)
	else
		applyWound(player, bodyPartName, woundType)
	end
end

local function registerMongooseWoundCommand()
	local ok, mongooseServer = pcall(require, "MC_Server")
	if not ok or type(mongooseServer) ~= "table"
		or type(mongooseServer._SlashHandlers) ~= "table" then
		return false
	end

	mongooseServer._SlashHandlers["/wound"] = handleWoundCommand
	return true
end