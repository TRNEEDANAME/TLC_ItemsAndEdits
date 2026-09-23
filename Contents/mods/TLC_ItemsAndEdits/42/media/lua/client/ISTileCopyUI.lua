--[[
    ISTileCopyUI.lua  (client)

    The little control panel the admin opens to:
      - toggle which layers get copied (Tiles / Containers / Overlay)
      - start a drag-select on the ground
      - copy the current selection into a named clipboard slot
      - pick a slot from the list and paste it (with a live size preview)
      - save/load the whole clipboard to disk
]]

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISTickBox"
require "ISUI/ISScrollingListBox"
require "ISUI/ISLabel"
require "TileCopy_Core"
require "ISTileCopyTool"

ISTileCopyUI = ISPanel:derive("ISTileCopyUI")
ISTileCopyUI.instance = nil

local Util = TileCopy.Util
local Core = TileCopy.Core

local PANEL_W, PANEL_H = 260, 380

function ISTileCopyUI:initialise()
    ISPanel.initialise(self)
end

function ISTileCopyUI:createChildren()
    ISPanel.createChildren(self)

    local pad = 10
    local y = 10

    self.titleLabel = ISLabel:new(pad, y, 20, "Tile Copy Tool (Admin)", 1, 1, 1, 1, UIFont.Medium, true)
    self:addChild(self.titleLabel)
    y = y + 26

    -- What to copy
    self.optionsTick = ISTickBox:new(pad, y, self.width - pad * 2, 60, "", self, self.onOptionsChanged)
    self.optionsTick:initialise()
    self.optionsTick:addOption("Tiles (floor / walls / furniture)")
    self.optionsTick:addOption("Containers (items inside)")
    self.optionsTick:addOption("Overlay (clutter / decals)")
    self.optionsTick:setSelected(1, true)
    self.optionsTick:setSelected(2, true)
    self.optionsTick:setSelected(3, true)
    self:addChild(self.optionsTick)
    y = y + self.optionsTick.height + 10

    self.selectBtn = ISButton:new(pad, y, self.width - pad * 2, 25, "1. Select Area", self, self.onSelectArea)
    self.selectBtn:initialise()
    self:addChild(self.selectBtn)
    y = y + 30

    self.selectionLabel = ISLabel:new(pad, y, 20, "No area selected", 0.8, 0.8, 0.8, 1, UIFont.Small, true)
    self:addChild(self.selectionLabel)
    y = y + 20

    self.nameEntry = ISTextEntryBox:new("", pad, y, self.width - pad * 2, 25)
    self.nameEntry:initialise()
    self.nameEntry:instantiate()
    self.nameEntry:setText("Clipboard " .. os.date("%H:%M:%S"))
    self:addChild(self.nameEntry)
    y = y + 30

    self.copyBtn = ISButton:new(pad, y, self.width - pad * 2, 25, "2. Copy Selection", self, self.onCopy)
    self.copyBtn:initialise()
    self.copyBtn.enable = false
    self:addChild(self.copyBtn)
    y = y + 34

    self.listLabel = ISLabel:new(pad, y, 20, "Saved clipboards:", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.listLabel)
    y = y + 18

    self.list = ISScrollingListBox:new(pad, y, self.width - pad * 2, 110)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = 20
    self.list.drawBorder = true
    self.list.selected = 0
    self:addChild(self.list)
    y = y + 110 + 10

    self.pasteBtn = ISButton:new(pad, y, self.width - pad * 2, 25, "3. Paste Selected", self, self.onPaste)
    self.pasteBtn:initialise()
    self:addChild(self.pasteBtn)
    y = y + 30

    self.deleteBtn = ISButton:new(pad, y, (self.width - pad * 3) / 2, 25, "Delete", self, self.onDelete)
    self.deleteBtn:initialise()
    self:addChild(self.deleteBtn)

    self.renameBtn = ISButton:new(pad * 2 + self.deleteBtn.width, y, (self.width - pad * 3) / 2, 25, "Rename", self, self.onRename)
    self.renameBtn:initialise()
    self:addChild(self.renameBtn)
    y = y + 34

    self.saveBtn = ISButton:new(pad, y, (self.width - pad * 3) / 2, 25, "Save to Disk", self, self.onSaveDisk)
    self.saveBtn:initialise()
    self:addChild(self.saveBtn)

    self.loadBtn = ISButton:new(pad * 2 + self.saveBtn.width, y, (self.width - pad * 3) / 2, 25, "Load from Disk", self, self.onLoadDisk)
    self.loadBtn:initialise()
    self:addChild(self.loadBtn)
    y = y + 34

    self.closeBtn = ISButton:new(pad, y, self.width - pad * 2, 25, "Close", self, self.onClose)
    self.closeBtn:initialise()
    self:addChild(self.closeBtn)

    self:refreshList()
end

function ISTileCopyUI:getOptions()
    return {
        includeTiles = self.optionsTick:isSelected(1),
        includeContainers = self.optionsTick:isSelected(2),
        includeOverlay = self.optionsTick:isSelected(3),
    }
end

function ISTileCopyUI:onOptionsChanged()
end

function ISTileCopyUI:onSelectArea()
    self:setVisible(false)
    ISTileCopyTool.instance:startSelecting(getPlayer():getZ(), function(x1, y1, x2, y2, z)
        self.pendingSelection = { x1 = x1, y1 = y1, x2 = x2, y2 = y2, z = z }
        local w = math.abs(x2 - x1) + 1
        local h = math.abs(y2 - y1) + 1
        self.selectionLabel:setName("Selected: " .. w .. " x " .. h .. " tiles")
        self.copyBtn.enable = true
        ISTileCopyTool.instance:cancel()
        self:setVisible(true)
    end)
end

function ISTileCopyUI:onCopy()
    if not self.pendingSelection then return end
    local sel = self.pendingSelection
    local opts = self:getOptions()
    local data = Core.captureArea(sel.x1, sel.y1, sel.x2, sel.y2, sel.z, opts)
    data.name = self.nameEntry:getText()
    if data.name == "" then data.name = "Clipboard " .. os.date("%H:%M:%S") end

    TileCopy.Clipboards = TileCopy.Clipboards or {}
    table.insert(TileCopy.Clipboards, data)
    self:refreshList()

    self.selectionLabel:setName("Copied '" .. data.name .. "' (" .. data.width .. "x" .. data.height .. ")")
end

function ISTileCopyUI:refreshList()
    self.list:clear()
    TileCopy.Clipboards = TileCopy.Clipboards or {}
    for i, data in ipairs(TileCopy.Clipboards) do
        self.list:addItem((data.name or ("Slot " .. i)) .. "  (" .. data.width .. "x" .. data.height .. ")", data)
    end
end

function ISTileCopyUI:getSelectedClipboard()
    if not self.list.selected or self.list.selected == 0 then return nil end
    local row = self.list.items[self.list.selected]
    return row and row.item
end

function ISTileCopyUI:onPaste()
    local data = self:getSelectedClipboard()
    if not data then return end

    self:setVisible(false)
    ISTileCopyTool.instance:startPasting(getPlayer():getZ(), data, function(x, y, z)
        TileCopy.ClientCommands.requestPaste(data, x, y, z)
        ISTileCopyTool.instance:cancel()
        self:setVisible(true)
    end)
end

function ISTileCopyUI:onDelete()
    if not self.list.selected or self.list.selected == 0 then return end
    table.remove(TileCopy.Clipboards, self.list.selected)
    self:refreshList()
end

function ISTileCopyUI:onRename()
    local data = self:getSelectedClipboard()
    if not data then return end
    local newName = self.nameEntry:getText()
    if newName and newName ~= "" then
        data.name = newName
        self:refreshList()
    end
end

function ISTileCopyUI:onSaveDisk()
    TileCopy.Clipboards = TileCopy.Clipboards or {}
    Util.saveClipboardToDisk(TileCopy.Clipboards)
end

function ISTileCopyUI:onLoadDisk()
    local loaded = Util.loadClipboardFromDisk()
    if loaded then
        TileCopy.Clipboards = loaded
        self:refreshList()
    end
end

function ISTileCopyUI:onClose()
    self:setVisible(false)
end

function ISTileCopyUI:new(x, y)
    local o = ISPanel:new(x, y, PANEL_W, PANEL_H)
    setmetatable(o, self)
    self.__index = self
    o.pendingSelection = nil
    o.moveWithMouse = true
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.85 }
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    return o
end

function ISTileCopyUI.toggle()
    if not Util.isAdmin(getPlayer()) then
        if getPlayer() then
            getPlayer():Say("You need admin rights to use the Tile Copy tool.")
        end
        return
    end

    if not ISTileCopyUI.instance then
        local x = getCore():getScreenWidth() / 2 - PANEL_W / 2
        local y = getCore():getScreenHeight() / 2 - PANEL_H / 2
        local inst = ISTileCopyUI:new(x, y)
        inst:initialise()
        inst:addToUIManager()
        ISTileCopyUI.instance = inst
    end

    ISTileCopyUI.instance:setVisible(not ISTileCopyUI.instance:isVisible())
    if ISTileCopyUI.instance:isVisible() then
        ISTileCopyUI.instance:bringToTop()
    end
end
