-- LRZ_UI.lua
-- Confirmation window shown after the admin marks both corners of a zone.
-- Lets them pick categories (or "ALL") and a percentage

require "ISUI/ISCollapsableWindow"
require "ISUI/ISTickBox"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "ISUI/ISLabel"
require "LRZ_Shared"

LRZ_UI = ISCollapsableWindow:derive("LRZ_UI")

local COLS = 3
local COL_WIDTH = 190
local PADDING = 10
local ROW_HEIGHT = 20

function LRZ_UI:new(x1, y1, x2, y2, z, onConfirmCallback)
    local width, height = COLS * COL_WIDTH + PADDING * 2, 500
    local x = (getCore():getScreenWidth() / 2) - (width / 2)
    local y = (getCore():getScreenHeight() / 2) - (height / 2)

    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.width = width
    o.height = height
    o.x1, o.y1, o.x2, o.y2, o.z = x1, y1, x2, y2, z
    o.onConfirmCallback = onConfirmCallback
    o.title = "Loot Removal Zone"
    o:setResizable(false)
    o.categoryTicks = {}
    return o
end

function LRZ_UI:initialise()
    ISCollapsableWindow.initialise(self)
    self:create()
end

function LRZ_UI:create()
    local y = 40

    self.allTick = ISTickBox:new(PADDING, y, self.width - PADDING * 2, ROW_HEIGHT, "", self, LRZ_UI.onAllToggle)
    self.allTick:initialise()
    self.allTick:addOption("Remove ALL categories")
    self.allTick:setSelected(1, true)
    self:addChild(self.allTick)
    y = y + 26

    -- Category checkboxes, laid out in columns filled top to bottom
    local rows = math.ceil(#LRZ.Categories / COLS)
    for i, cat in ipairs(LRZ.Categories) do
        local col = math.floor((i - 1) / rows)
        local row = (i - 1) % rows
        local tick = ISTickBox:new(PADDING + col * COL_WIDTH, y + row * ROW_HEIGHT, COL_WIDTH, ROW_HEIGHT, "", self, nil)
        tick:initialise()
        tick:addOption(cat)
        tick:setSelected(1, false)
        tick.enable = false -- greyed out while "ALL" is checked
        self:addChild(tick)
        self.categoryTicks[cat] = tick
    end
    y = y + rows * ROW_HEIGHT + 10

    self.percentLabel = ISLabel:new(PADDING, y, 20, "Percent to remove (0-100):", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.percentLabel)
    y = y + 20

    self.percentEntry = ISTextEntryBox:new("100", PADDING, y, self.width - PADDING * 2, 25)
    self.percentEntry:initialise()
    self.percentEntry:instantiate()
    self.percentEntry:setOnlyNumbers(true)
    self:addChild(self.percentEntry)
    y = y + 35

    self.confirmBtn = ISButton:new(PADDING, y, 100, 25, "Confirm", self, LRZ_UI.onConfirm)
    self.confirmBtn:initialise()
    self:addChild(self.confirmBtn)

    self.cancelBtn = ISButton:new(PADDING + 110, y, 100, 25, "Cancel", self, LRZ_UI.onCancel)
    self.cancelBtn:initialise()
    self:addChild(self.cancelBtn)

    y = y + 40
    self:setHeight(y)
end

function LRZ_UI:onAllToggle()
    local allSelected = self.allTick:isSelected(1)
    for _, tick in pairs(self.categoryTicks) do
        tick.enable = not allSelected
        if allSelected then
            tick:setSelected(1, false)
        end
    end
end

function LRZ_UI:onConfirm()
    local percent = tonumber(self.percentEntry:getText()) or 100
    percent = math.max(0, math.min(100, percent))

    local categories = {}
    if self.allTick:isSelected(1) then
        categories = { LRZ.ALL_KEY }
    else
        for cat, tick in pairs(self.categoryTicks) do
            if tick:isSelected(1) then
                table.insert(categories, cat)
            end
        end
        if #categories == 0 then
            return -- nothing selected
        end
    end

    if self.onConfirmCallback then
        self.onConfirmCallback(self.x1, self.y1, self.x2, self.y2, self.z, percent, categories)
    end
    self:close()
end

function LRZ_UI:onCancel()
    self:close()
end

function LRZ_UI:close()
    self:setVisible(false)
    self:removeFromUIManager()
end
