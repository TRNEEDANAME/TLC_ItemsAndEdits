-- LRZ_AdderUI.lua
-- Loot Adder window, opened from the Loot Remover window or the Zone Editor's
-- Loot Removal mode (the "owner"), which supplies the area.
--   - source "Items": pick item types from your inventory (copies are
--     spawned, yours are untouched) and how many of each
--   - source "Reroll": every container gets a fresh roll from the game's
--     loot tables, like the admin "Refill container" option
--   - either adds on top of what's there, or replaces it
--
-- The owner implements getLootArgs() -> args (x1, y1, x2, y2, z1, z2 and
-- optionally rescan) or nil, errorText.

require "ISUI/ISCollapsableWindow"
require "ISUI/ISTickBox"
require "ISUI/ISButton"
require "ISUI/ISComboBox"
require "ISUI/ISTextBox"
require "ISUI/ISScrollingListBox"
require "ISUI/ISLabel"
require "ISUI/ISModalDialog"
require "LRZ_Shared"
require "TLC_UIUtil"

LRZ_AdderUI = ISCollapsableWindow:derive("LRZ_AdderUI")
LRZ_AdderUI.instance = nil

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local BTN_H = FONT_HGT_SMALL + 6
local PADDING = 10
local WIDTH = 460
local INV_LIST_H = 150
local ADD_LIST_H = 110

local SOURCE_OPTIONS = {
    { label = "Items from my inventory", source = LRZ.SOURCE_ITEMS },
    { label = "Reroll vanilla loot (admin refill)", source = LRZ.SOURCE_REROLL },
}

function LRZ_AdderUI:new()
    local x = (getCore():getScreenWidth() / 2) - (WIDTH / 2)
    local y = (getCore():getScreenHeight() / 2) - 300

    local o = ISCollapsableWindow:new(x, y, WIDTH, 600)
    setmetatable(o, self)
    self.__index = self

    o.title = "Loot Adder"
    o:setResizable(false)
    o.owner = nil
    o.toAdd = {}   -- { type, name, count }
    return o
end

function LRZ_AdderUI:createChildren()
    ISCollapsableWindow.createChildren(self)

    local innerW = WIDTH - PADDING * 2
    local y = self:titleBarHeight() + PADDING

    self.areaLabel = ISLabel:new(PADDING, y, FONT_HGT_SMALL, "", 0.8, 0.8, 0.8, 1, UIFont.Small, true)
    self:addChild(self.areaLabel)
    y = y + FONT_HGT_SMALL + 8

    -- Row: source
    local sourceLabel = ISLabel:new(PADDING, y, BTN_H, "Source:", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(sourceLabel)
    local sx = PADDING + getTextManager():MeasureStringX(UIFont.Small, "Source:") + 8
    self.sourceCombo = ISComboBox:new(sx, y, WIDTH - sx - PADDING, BTN_H, self, LRZ_AdderUI.onSourceChanged)
    self.sourceCombo:initialise()
    for _, opt in ipairs(SOURCE_OPTIONS) do
        self.sourceCombo:addOptionWithData(opt.label, opt.source)
    end
    self:addChild(self.sourceCombo)
    y = y + BTN_H + 10

    -- Items section (hidden when rerolling)
    local itemsTop = y
    self.itemWidgets = {}
    local function addItemWidget(widget)
        self:addChild(widget)
        table.insert(self.itemWidgets, widget)
    end

    local invLabel = ISLabel:new(PADDING, y, BTN_H, "Your inventory (double-click to add):", 1, 1, 1, 1, UIFont.Small, true)
    addItemWidget(invLabel)
    self.refreshBtn = ISButton:new(WIDTH - PADDING - 80, y, 80, BTN_H, "Refresh", self, LRZ_AdderUI.refreshInventory)
    self.refreshBtn:initialise()
    addItemWidget(self.refreshBtn)
    y = y + BTN_H + 4

    self.invList = ISScrollingListBox:new(PADDING, y, innerW, INV_LIST_H)
    self.invList:initialise()
    self.invList:instantiate()
    self.invList:setFont(UIFont.Small, 2)
    self.invList.drawBorder = true
    self.invList:setOnMouseDoubleClick(self, LRZ_AdderUI.onPickItem)
    addItemWidget(self.invList)
    y = y + INV_LIST_H + 8

    local addLabel = ISLabel:new(PADDING, y, FONT_HGT_SMALL, "To add (double-click to change the amount):", 1, 1, 1, 1, UIFont.Small, true)
    addItemWidget(addLabel)
    y = y + FONT_HGT_SMALL + 4

    self.addList = ISScrollingListBox:new(PADDING, y, innerW, ADD_LIST_H)
    self.addList:initialise()
    self.addList:instantiate()
    self.addList:setFont(UIFont.Small, 2)
    self.addList.drawBorder = true
    self.addList:setOnMouseDoubleClick(self, LRZ_AdderUI.promptAmount)
    addItemWidget(self.addList)
    y = y + ADD_LIST_H + 6

    local btnW = (innerW - 10) / 3
    self.setAmountBtn = ISButton:new(PADDING, y, btnW, BTN_H, "Set Amount", self, LRZ_AdderUI.onSetAmount)
    self.setAmountBtn:initialise()
    addItemWidget(self.setAmountBtn)

    self.removeBtn = ISButton:new(PADDING + btnW + 5, y, btnW, BTN_H, "Remove", self, LRZ_AdderUI.onRemoveEntry)
    self.removeBtn:initialise()
    addItemWidget(self.removeBtn)

    self.clearBtn = ISButton:new(PADDING + (btnW + 5) * 2, y, btnW, BTN_H, "Clear", self, LRZ_AdderUI.onClearEntries)
    self.clearBtn:initialise()
    addItemWidget(self.clearBtn)
    y = y + BTN_H + 8

    local amountLabel = ISLabel:new(PADDING, y, BTN_H, "Amount is:", 1, 1, 1, 1, UIFont.Small, true)
    addItemWidget(amountLabel)
    local ax = PADDING + getTextManager():MeasureStringX(UIFont.Small, "Amount is:") + 8
    self.spreadCombo = ISComboBox:new(ax, y, WIDTH - ax - PADDING, BTN_H, nil, nil)
    self.spreadCombo:initialise()
    self.spreadCombo:addOptionWithData("Total, spread over random containers", false)
    self.spreadCombo:addOptionWithData("Per container (every container gets it)", true)
    addItemWidget(self.spreadCombo)
    y = y + BTN_H + 10

    -- Shown in the items section's place when rerolling
    self.rerollNote = ISLabel:new(PADDING, itemsTop, FONT_HGT_SMALL,
        "Every container gets a fresh roll from the game's loot tables for its room.",
        0.8, 0.8, 0.8, 1, UIFont.Small, true)
    self:addChild(self.rerollNote)

    -- Mode
    self.replaceTick = ISTickBox:new(PADDING, y, innerW, FONT_HGT_SMALL, "", nil, nil)
    self.replaceTick:initialise()
    self.replaceTick:addOption("Replace existing contents (empty the containers first)")
    self:addChild(self.replaceTick)
    y = y + self.replaceTick:getHeight() + 10

    -- Actions
    self.addBtn = ISButton:new(PADDING, y, innerW, BTN_H, "Add Loot", self, LRZ_AdderUI.onAddLoot)
    self.addBtn:initialise()
    self:addChild(self.addBtn)
    y = y + BTN_H + 8

    self.statusLabel = ISLabel:new(PADDING, y, FONT_HGT_SMALL, "", 0.6, 1, 0.6, 1, UIFont.Small, true)
    self:addChild(self.statusLabel)

    self.closeBtn = ISButton:new(WIDTH - PADDING - 100, y, 100, BTN_H, "Close", self, LRZ_AdderUI.close)
    self.closeBtn:initialise()
    self:addChild(self.closeBtn)
    y = y + BTN_H + PADDING

    self:setHeight(y)
    self:onSourceChanged()
    self:refreshInventory()
end

-------------------------------------------------------------------------------
-- Source
-------------------------------------------------------------------------------

function LRZ_AdderUI:getSource()
    return self.sourceCombo:getOptionData(self.sourceCombo.selected)
end

function LRZ_AdderUI:onSourceChanged()
    local items = self:getSource() == LRZ.SOURCE_ITEMS
    for _, widget in ipairs(self.itemWidgets) do
        widget:setVisible(items)
    end
    self.rerollNote:setVisible(not items)
end

-------------------------------------------------------------------------------
-- Item lists
-------------------------------------------------------------------------------

-- Counts every item in `container` by type, including inside bags.
local function gatherInventory(container, byType, list)
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local fullType = item:getFullType()
        local entry = byType[fullType]
        if not entry then
            entry = { type = fullType, name = item:getDisplayName(), count = 0 }
            byType[fullType] = entry
            table.insert(list, entry)
        end
        entry.count = entry.count + 1
        if instanceof(item, "InventoryContainer") then
            gatherInventory(item:getInventory(), byType, list)
        end
    end
end

function LRZ_AdderUI:refreshInventory()
    self.invList:clear()
    local player = getPlayer()
    if not player then return end

    local list = {}
    gatherInventory(player:getInventory(), {}, list)
    table.sort(list, function(a, b) return a.name < b.name end)
    for _, e in ipairs(list) do
        self.invList:addItem(string.format("%s  (x%d)", e.name, e.count), e)
    end
end

function LRZ_AdderUI:refreshAddList()
    local selected = self.addList.selected
    self.addList:clear()
    for _, e in ipairs(self.toAdd) do
        self.addList:addItem(string.format("%s   x%d", e.name, e.count), e)
    end
    self.addList.selected = math.min(selected, #self.addList.items)
end

function LRZ_AdderUI:findEntry(fullType)
    for _, e in ipairs(self.toAdd) do
        if e.type == fullType then return e end
    end
    return nil
end

-- Double-click in the inventory list: add the type (or bump it) and ask how many.
function LRZ_AdderUI:onPickItem(invEntry)
    local e = self:findEntry(invEntry.type)
    if not e then
        e = { type = invEntry.type, name = invEntry.name, count = 1 }
        table.insert(self.toAdd, e)
        self:refreshAddList()
    end
    self:promptAmount(e)
end

function LRZ_AdderUI:getSelectedEntry()
    local row = self.addList.items[self.addList.selected]
    return row and row.item
end

function LRZ_AdderUI:onSetAmount()
    local e = self:getSelectedEntry()
    if e then self:promptAmount(e) end
end

function LRZ_AdderUI:promptAmount(e)
    local modal = ISTextBox:new(0, 0, 280, 180, "Add how many " .. e.name .. "?", tostring(e.count), self, LRZ_AdderUI.onAmountEntered, getPlayer():getPlayerNum(), e)
    modal:initialise()
    modal:setOnlyNumbers(true)
    modal:addToUIManager()
    modal:setAlwaysOnTop(true)
end

function LRZ_AdderUI:onAmountEntered(button, e)
    if button.internal ~= "OK" then return end
    local n = tonumber(button.parent.entry:getText())
    if not n then return end
    e.count = TLC_Util.clamp(math.floor(n), 1, LRZ.MAX_ADD_ITEMS)
    self:refreshAddList()
end

function LRZ_AdderUI:onRemoveEntry()
    local e = self:getSelectedEntry()
    if not e then return end
    for i, entry in ipairs(self.toAdd) do
        if entry == e then
            table.remove(self.toAdd, i)
            break
        end
    end
    self:refreshAddList()
end

function LRZ_AdderUI:onClearEntries()
    self.toAdd = {}
    self:refreshAddList()
end

-------------------------------------------------------------------------------
-- Request
-------------------------------------------------------------------------------

-- Area args from the owner, or nil after showing why not.
function LRZ_AdderUI:getAreaArgs()
    if not self.owner then
        self:setStatus("No area source - reopen from the Loot Remover.", true)
        return nil
    end
    local args, err = self.owner:getLootArgs()
    if not args then
        self:setStatus(err or "No area selected.", true)
        return nil
    end
    local tooBig = LRZ.TooBigMessage(args)
    if tooBig then
        self:setStatus(tooBig, true)
        return nil
    end
    return args
end

function LRZ_AdderUI:refreshArea()
    local args = self.owner and self.owner:getLootArgs()
    if args then
        self.areaLabel:setName("Area: " .. LRZ.DescribeArea(args))
    else
        self.areaLabel:setName("Area: none selected")
    end
end

function LRZ_AdderUI:onAddLoot()
    local args = self:getAreaArgs()
    if not args then return end

    args.source = self:getSource()
    args.replace = self.replaceTick:isSelected(1)

    local what
    if args.source == LRZ.SOURCE_REROLL then
        what = "Reroll vanilla loot"
    else
        if #self.toAdd == 0 then
            self:setStatus("Pick at least one item to add.", true)
            return
        end
        args.items = {}
        local total = 0
        for _, e in ipairs(self.toAdd) do
            table.insert(args.items, { type = e.type, count = e.count })
            total = total + e.count
        end
        args.perContainer = self.spreadCombo:getOptionData(self.spreadCombo.selected) == true
        if args.perContainer then
            what = string.format("Add %d item(s) of %d type(s) to EVERY container", total, #args.items)
        else
            what = string.format("Add %d item(s) of %d type(s), spread over random containers,", total, #args.items)
        end
    end

    local text = what .. " in " .. LRZ.DescribeArea(args)
    if args.replace then
        text = text .. ", REPLACING what's in them?"
    else
        text = text .. "?"
    end

    local modal = ISModalDialog:new(self:getRight() + 10, self:getY(), 380, 150, text, true, self, LRZ_AdderUI.onConfirmAdd, nil, args)
    modal:initialise()
    modal:addToUIManager()
    modal:setAlwaysOnTop(true)
end

function LRZ_AdderUI:onConfirmAdd(button, args)
    if button.internal ~= "YES" then return end
    self:setStatus("Adding...")
    sendClientCommand(getPlayer(), LRZ.ModuleName, LRZ.CMD_ADD_LOOT, args)
end

-- Server reply (LRZ.RES_ADDED).
function LRZ_AdderUI:onAdded(args)
    if args.error then
        self:setStatus(args.error, true)
    elseif args.containers == 0 then
        self:setStatus("No containers found - is the area loaded (near a player)?", true)
    else
        local msg = "Added " .. tostring(args.added) .. " item(s) to " .. tostring(args.containers) .. " container(s)"
        if args.cleared and args.cleared > 0 then
            msg = msg .. ", " .. tostring(args.cleared) .. " removed first"
        end
        self:setStatus(msg .. ".")
    end
end

-------------------------------------------------------------------------------
-- Misc
-------------------------------------------------------------------------------

function LRZ_AdderUI:setStatus(text, isError)
    TLC_UIUtil.setStatus(self.statusLabel, text, isError)
end

function LRZ_AdderUI:close()
    self:setVisible(false)
end

--- Opens the window for `owner` (see the top of this file).
function LRZ_AdderUI.open(owner)
    if not LRZ_AdderUI.instance then
        local ui = LRZ_AdderUI:new()
        ui:initialise()
        ui:addToUIManager()
        LRZ_AdderUI.instance = ui
    else
        LRZ_AdderUI.instance:refreshInventory()
        LRZ_AdderUI.instance:setVisible(true)
    end
    local ui = LRZ_AdderUI.instance
    ui.owner = owner
    ui:refreshArea()
    ui:setStatus("")
    -- Also has to show over the full-screen Zone Editor
    ui:setAlwaysOnTop(true)
    ui:bringToTop()
    return ui
end
