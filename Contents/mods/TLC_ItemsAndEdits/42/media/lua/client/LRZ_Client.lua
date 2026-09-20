-- LRZ_Client.lua
-- how it *should* work if I did it right "Start Zone Here" -> "End Zone Here" -> confirmation window -> send to server.

require "LRZ_Shared"
require "LRZ_UI"

local pending = nil -- {x=, y=, z=} set after "Start Zone Here"

local function chat(msg)
    local player = getPlayer()
    if not player then return end
    player:setHaloNote(msg)
end

-- Uses the clicked objects when available
local function getClickedSquare(worldobjects, playerObj)
    if worldobjects then
        for _, obj in ipairs(worldobjects) do
            if obj and obj.getSquare then
                local sq = obj:getSquare()
                if sq then return sq end
            end
        end
    end

    local z = playerObj:getZ()
    local wx, wy = ISCoordConversion.ToWorld(getMouseXScaled(), getMouseYScaled(), z)
    return getCell():getGridSquare(math.floor(wx), math.floor(wy), z)
end

local function sendRemoveLoot(x1, y1, x2, y2, z, percent, categories)
    sendClientCommand(getPlayer(), LRZ.ModuleName, LRZ.CMD_REMOVE_LOOT, {
        x1 = x1, y1 = y1, x2 = x2, y2 = y2, z = z,
        percent = percent,
        categories = categories,
    })
end

local function openConfirmWindow(x1, y1, x2, y2, z)
    local ui = LRZ_UI:new(x1, y1, x2, y2, z, sendRemoveLoot)
    ui:initialise()
    ui:addToUIManager()
end

local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then return true end

    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then return end

    if not LRZ.CanUse(playerObj) then return end

    local square = getClickedSquare(worldobjects, playerObj)
    if not square then return end

    local x, y, z = square:getX(), square:getY(), square:getZ()

    local option = context:addOption("Loot Removal Zone", worldobjects, nil)
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(option, subMenu)

    if not pending then
        subMenu:addOption("Start Zone Here", worldobjects, function()
            pending = { x = x, y = y, z = z }
            chat("Loot removal zone: start point set. Right-click the opposite corner to finish.")
        end)
    else
        subMenu:addOption("End Zone Here", worldobjects, function()
            if pending.z ~= z then
                chat("Both corners must be on the same floor/Z level. Zone cancelled.")
                pending = nil
                return
            end
            local x1, y1, x2, y2, zUse = pending.x, pending.y, x, y, pending.z
            pending = nil
            openConfirmWindow(x1, y1, x2, y2, zUse)
        end)
        subMenu:addOption("Cancel Zone", worldobjects, function()
            pending = nil
            chat("Loot removal zone cancelled.")
        end)
    end
end

local function onServerCommand(module, command, args)
    if module ~= LRZ.ModuleName then return end
    if command == "done" then
        chat("Loot removal complete: " .. tostring(args.removed) .. " item(s) removed.")
    elseif command == "denied" then
        chat("You do not have permission to use loot removal zones.")
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
Events.OnServerCommand.Add(onServerCommand)