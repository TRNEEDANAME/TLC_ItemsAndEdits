local function registerMongooseWoundCommand()
	local ok, mongooseCore = require, "MC_Core"
	if not ok or type(mongooseCore) ~= "table"
		or type(mongooseCore.SERVER_SLASH_COMMANDS) ~= "table" then
		return false
	end

	for _, command in ipairs(mongooseCore.SERVER_SLASH_COMMANDS) do
		if command == "/wound" then
			return true
		end
	end

	table.insert(mongooseCore.SERVER_SLASH_COMMANDS, "/wound")
	return true
end

Events.OnGameStart.Add(registerMongooseWoundCommand)