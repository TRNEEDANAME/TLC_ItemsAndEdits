--[[
    TileCopy_Util.lua  (shared)

    Small helpers shared by client + server code:
      - TileCopy.Util.isAdmin(playerObj)   -> boolean
      - TileCopy.Util.serialize(table)     -> string
      - TileCopy.Util.deserialize(string)  -> table or nil
      - TileCopy.Util.log(...)             -> debug print, only when TileCopy.DEBUG is true

]]

TileCopy = TileCopy or {}
TileCopy.DEBUG = false

TileCopy.Util = TileCopy.Util or {}
local Util = TileCopy.Util

function Util.log(...)
    if not TileCopy.DEBUG then return end
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    print("[TileCopy] " .. table.concat(parts, " "))
end

--- Returns true if the given player should be allowed to use the tool.
--- Always true in single player / debug. In multiplayer, requires
--- Admin / Moderator / Overseer access level.
function Util.isAdmin(playerObj)
    playerObj = playerObj or getPlayer()
    if not playerObj then return false end

    if not isClient() and not isServer() then
        -- Single player: allow the tool freely.
        return true
    end

    local ok, accessLevel = pcall(function() return playerObj:getAccessLevel() end)
    if not ok or not accessLevel then return false end

    accessLevel = tostring(accessLevel)
    return accessLevel == "Admin"
        or accessLevel == "Moderator"
        or accessLevel == "Overseer"
        or accessLevel == "GM"
end

--------------------------------------------------------------------------
-- Serialization: turns a plain Lua table (strings/numbers/booleans/nested
-- tables into a loadable Lua source string, and back.
-- Used to persist clipboard slots to disk.
--------------------------------------------------------------------------

local function serializeValue(v, buffer)
    local t = type(v)
    if t == "string" then
        buffer[#buffer + 1] = string.format("%q", v)
    elseif t == "number" or t == "boolean" then
        buffer[#buffer + 1] = tostring(v)
    elseif t == "table" then
        buffer[#buffer + 1] = "{"
        -- array part
        local n = #v
        for i = 1, n do
            serializeValue(v[i], buffer)
            buffer[#buffer + 1] = ","
        end
        for k, val in pairs(v) do
            if not (type(k) == "number" and k >= 1 and k <= n and math.floor(k) == k) then
                buffer[#buffer + 1] = "["
                serializeValue(k, buffer)
                buffer[#buffer + 1] = "]="
                serializeValue(val, buffer)
                buffer[#buffer + 1] = ","
            end
        end
        buffer[#buffer + 1] = "}"
    else
        buffer[#buffer + 1] = "nil"
    end
end

function Util.serialize(tbl)
    local buffer = { "return " }
    serializeValue(tbl, buffer)
    return table.concat(buffer)
end

function Util.deserialize(str)
    if not str or str == "" then return nil end
    local chunk
    if loadstring then
        chunk = loadstring(str)
    elseif load then
        chunk = load(str)
    end
    if not chunk then
        Util.log("deserialize: failed to compile saved data")
        return nil
    end
    local ok, result = pcall(chunk)
    if not ok then
        Util.log("deserialize: failed to run saved data -", tostring(result))
        return nil
    end
    return result
end

--------------------------------------------------------------------------
-- File persistence
--------------------------------------------------------------------------

local SAVE_FILE = "TileCopy_Clipboard.txt"

function Util.saveClipboardToDisk(clipboardTable)
    local ok, writer = pcall(getFileWriter, SAVE_FILE, true, false)
    if not ok or not writer then
        Util.log("saveClipboardToDisk: could not open file for writing")
        return false
    end
    writer:write(Util.serialize(clipboardTable))
    writer:close()
    return true
end

function Util.loadClipboardFromDisk()
    local ok, reader = pcall(getFileReader, SAVE_FILE, false)
    if not ok or not reader then
        return nil
    end
    local lines = {}
    while true do
        local line = reader:readLine()
        if not line then break end
        lines[#lines + 1] = line
    end
    reader:close()
    if #lines == 0 then return nil end
    return Util.deserialize(table.concat(lines, "\n"))
end
