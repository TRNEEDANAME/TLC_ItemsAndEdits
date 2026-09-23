--[[
    ISTileCopyTool.lua  (client)

    Full-screen transparent ISUIElement that:
      - lets the admin drag out a rectangle on the ground (same idea as the
        vanilla "claim safehouse" blue square) to pick the copy area
      - shows a live WxH label while dragging
      - shows a translucent preview of the clipboard's footprint following
        the mouse while in "paste" mode
]]

require "ISUI/ISPanel"
require "TileCopy_Core"

ISTileCopyTool = ISUIElement:derive("ISTileCopyTool")
ISTileCopyTool.instance = nil

local Util = TileCopy.Util
local Core = TileCopy.Core

local TILE_W, TILE_H = 64, 32 -- only used as a fallback box size if conversion fails

local function worldToScreen(x, y, z)
    local player = getPlayer()
    if not player then return nil, nil end
    local ok, sx, sy = pcall(function()
        return isoToScreenX(player, x, y, z), isoToScreenY(player, x, y, z)
    end)
    if ok then return sx, sy end
    return nil, nil
end

local function screenToWorld(mx, my, z)
    local ok, wx, wy = pcall(function()
        return ISCoordConversion.ToWorld(mx, my, z or 0)
    end)
    if ok and wx then return math.floor(wx), math.floor(wy) end

    local player = getPlayer()
    if player then
        return math.floor(player:getX()), math.floor(player:getY())
    end
    return nil, nil
end

function ISTileCopyTool:initialise()
    ISUIElement.initialise(self)
end

function ISTileCopyTool:createChildren()
end

function ISTileCopyTool:new()
    local o = ISUIElement:new(0, 0, getCore():getScreenWidth(), getCore():getScreenHeight())
    setmetatable(o, self)
    self.__index = self
    o.mode = nil -- "select" or "paste"
    o.dragStartX, o.dragStartY = nil, nil
    o.dragCurX, o.dragCurY = nil, nil
    o.z = 0
    o.onSelectionMade = nil -- callback(x1,y1,x2,y2,z)
    o.onPasteConfirmed = nil -- callback(x,y,z)
    o.clipboardPreview = nil -- {width=, height=}
    return o
end

function ISTileCopyTool:startSelecting(z, onSelectionMade)
    self.mode = "select"
    self.z = z or getPlayer():getZ()
    self.dragStartX, self.dragStartY = nil, nil
    self.onSelectionMade = onSelectionMade
    self:setVisible(true)
    self:bringToTop()
end

function ISTileCopyTool:startPasting(z, clipboardData, onPasteConfirmed)
    self.mode = "paste"
    self.z = z or getPlayer():getZ()
    self.clipboardPreview = clipboardData
    self.onPasteConfirmed = onPasteConfirmed
    self:setVisible(true)
    self:bringToTop()
end

function ISTileCopyTool:cancel()
    self.mode = nil
    self.dragStartX, self.dragStartY = nil, nil
    self:setVisible(false)
end

function ISTileCopyTool:onMouseDown(mx, my)
    if self.mode == "select" then
        local wx, wy = screenToWorld(mx, my, self.z)
        if wx then
            self.dragStartX, self.dragStartY = wx, wy
            self.dragCurX, self.dragCurY = wx, wy
        end
        return true
    elseif self.mode == "paste" then
        local wx, wy = screenToWorld(mx, my, self.z)
        if wx and self.onPasteConfirmed then
            self.onPasteConfirmed(wx, wy, self.z)
        end
        return true
    end
    return false
end

function ISTileCopyTool:onMouseUp(mx, my)
    if self.mode == "select" and self.dragStartX then
        local wx, wy = screenToWorld(mx, my, self.z)
        if wx and self.onSelectionMade then
            self.onSelectionMade(self.dragStartX, self.dragStartY, wx, wy, self.z)
        end
        self.dragStartX, self.dragStartY = nil, nil
    end
    return true
end

function ISTileCopyTool:onMouseMove(dx, dy)
    if self.mode == "select" and self.dragStartX then
        local wx, wy = screenToWorld(getMouseX(), getMouseY(), self.z)
        if wx then
            self.dragCurX, self.dragCurY = wx, wy
        end
    end
    return true
end

--- Draws a filled + outlined rectangle covering world tiles (x1,y1)-(x2,y2)
function ISTileCopyTool:drawWorldRect(x1, y1, x2, y2, z, r, g, b, a)
    local minX, maxX = math.min(x1, x2), math.max(x1, x2)
    local minY, maxY = math.min(y1, y2), math.max(y1, y2)

    for gx = minX, maxX do
        for gy = minY, maxY do
            local sx, sy = worldToScreen(gx, gy, z)
            if sx then
                self:drawRect(sx - TILE_W / 2, sy - TILE_H / 2, TILE_W, TILE_H, a, r, g, b)
            end
        end
    end

    -- Border + size label at the top-left corner of the box
    local tlx, tly = worldToScreen(minX, minY, z)
    if tlx then
        local w, h = (maxX - minX + 1), (maxY - minY + 1)
        self:drawText(w .. " x " .. h, tlx - TILE_W / 2, tly - TILE_H, 1, 1, 1, 1, UIFont.Small)
    end
end

function ISTileCopyTool:render()
    if self.mode == "select" and self.dragStartX then
        self:drawWorldRect(self.dragStartX, self.dragStartY, self.dragCurX or self.dragStartX, self.dragCurY or self.dragStartY,
            self.z, 0.15, 0.35, 1.0, 0.35)
    elseif self.mode == "paste" and self.clipboardPreview then
        local wx, wy = screenToWorld(getMouseX(), getMouseY(), self.z)
        if wx then
            local w = self.clipboardPreview.width or 1
            local h = self.clipboardPreview.height or 1
            self:drawWorldRect(wx, wy, wx + w - 1, wy + h - 1, self.z, 0.15, 1.0, 0.35, 0.35)
        end
    end
end

function ISTileCopyTool.OnGameStart()
    if ISTileCopyTool.instance then return end
    local inst = ISTileCopyTool:new()
    inst:initialise()
    inst:setVisible(false)
    inst:addToUIManager()
    ISTileCopyTool.instance = inst
end

Events.OnGameStart.Add(ISTileCopyTool.OnGameStart)
