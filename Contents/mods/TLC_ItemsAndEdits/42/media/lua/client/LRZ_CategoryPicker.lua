-- LRZ_CategoryPicker.lua
-- "ALL categories" tick + the category ticks laid out in columns.
-- Used by the Loot Remover window and the Zone Editor's Loot Removal mode.
-- Ticking a category unticks ALL; ticking ALL unticks every category.

require "ISUI/ISTickBox"
require "LRZ_Shared"

LRZ_CategoryPicker = {}
LRZ_CategoryPicker.__index = LRZ_CategoryPicker

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)

-- onChanged() is called after any tick changes.
function LRZ_CategoryPicker.create(parent, x, y, colW, cols, onChanged)
    local o = setmetatable({}, LRZ_CategoryPicker)
    o.onChanged = onChanged
    o.ticks = {}
    o.index = {}

    o.allTick = ISTickBox:new(x, y, colW * cols, FONT_HGT_SMALL, "", o, LRZ_CategoryPicker.onAllToggle)
    o.allTick:initialise()
    o.allTick:addOption("ALL categories")
    o.allTick:setSelected(1, true)
    parent:addChild(o.allTick)
    y = y + o.allTick:getHeight() + 4

    local cats = LRZ.Categories
    local rows = math.ceil(#cats / cols)
    o.bottom = y
    for col = 1, cols do
        local tick = ISTickBox:new(x + (col - 1) * colW, y, colW, FONT_HGT_SMALL, "", o, LRZ_CategoryPicker.onCategoryToggle)
        tick:initialise()
        for row = 1, rows do
            local cat = cats[(col - 1) * rows + row]
            if cat then
                tick:addOption(cat)
                o.index[cat] = { tick = tick, index = row }
            end
        end
        parent:addChild(tick)
        table.insert(o.ticks, tick)
        o.bottom = math.max(o.bottom, y + tick:getHeight())
    end

    return o
end

function LRZ_CategoryPicker:onAllToggle()
    if self.allTick:isSelected(1) then
        for _, tick in ipairs(self.ticks) do
            for i = 1, #tick.options do
                tick:setSelected(i, false)
            end
        end
    end
    if self.onChanged then self.onChanged() end
end

function LRZ_CategoryPicker:onCategoryToggle()
    local any = false
    for _, ref in pairs(self.index) do
        if ref.tick:isSelected(ref.index) then
            any = true
        end
    end
    self.allTick:setSelected(1, not any)
    if self.onChanged then self.onChanged() end
end

-- Returns a set of checked category keys, or nil when ALL is on.
function LRZ_CategoryPicker:getChecked()
    if self.allTick:isSelected(1) then return nil end
    local set = {}
    for cat, ref in pairs(self.index) do
        if ref.tick:isSelected(ref.index) then
            set[cat] = true
        end
    end
    return set
end

-- Category list for a removeLoot request, or nil when nothing is ticked.
function LRZ_CategoryPicker:getRequestCategories()
    local checked = self:getChecked()
    if not checked then return { LRZ.ALL_KEY } end
    local list = {}
    for cat in pairs(checked) do
        table.insert(list, cat)
    end
    if #list == 0 then return nil end
    return list
end

-- Short human-readable summary for confirmations.
function LRZ_CategoryPicker:describe()
    local list = self:getRequestCategories()
    if not list then return "nothing" end
    if list[1] == LRZ.ALL_KEY then return "ALL categories" end
    table.sort(list)
    return table.concat(list, ", ")
end
