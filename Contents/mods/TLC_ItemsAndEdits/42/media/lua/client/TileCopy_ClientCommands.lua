--[[
    TileCopy_ClientCommands.lua  (client)

    - Opens the tool via keybind (default F9) and
      via a right-click world context menu entry
    - Sends paste requests to the server in multiplayer, and applies the
      paste locally in single player.
]]

require "ISTileCopyUI"
require "TileCopy_Core"

TileCopy.ClientCommands = TileCopy.ClientCommands or {}
local ClientCommands = TileCopy.ClientCommands
local Util = TileCopy.Util
local Core = TileCopy.Core

TILECOPY_KEY = Keyboard.KEY_F9

--- Called by the UI when the admin confirms where to paste.
function ClientCommands.requestPaste(data, x, y, z)
    if not Util.isAdmin(getPlayer()) then return end

    if isClient() then
        sendClientCommand(getPlayer(), "TileCopy", "paste", { data = data, x = x, y = y, z = z })
    else
        -- Single player: we own the world, just do it now.
        Core.applyArea(data, x, y, z)
    end
end

local function onServerCommand(module, command, args)
    if module ~= "TileCopy" then return end
    if command == "paste" and args and args.data then
        Core.applyArea(args.data, args.x, args.y, args.z)
    elseif command == "denied" then
        if getPlayer() then
            getPlayer():Say("Tile Copy: server rejected that paste (admin check failed).")
        end
    end
end
Events.OnServerCommand.Add(onServerCommand)

local function onKeyStartPressed(key)
    if key == TILECOPY_KEY then
        ISTileCopyUI.toggle()
    end
end
Events.OnKeyStartPressed.Add(onKeyStartPressed)

local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then return end
    if not Util.isAdmin(getPlayer(playerNum)) then return end
    context:addOption("Tile Copy Tool", nil, ISTileCopyUI.toggle)
end
Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
