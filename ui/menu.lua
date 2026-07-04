-- Vertical list-picker widget drawn with gfx.
-- This is the ONLY module permitted to make engine calls.

local gfx = gfx
local P = require("palette")

local LINE_HEIGHT = 12
local CHAR_WIDTH = 6 -- bundled font advance, ~6px per character

local Menu = {}
Menu.__index = Menu

local M = {}

--- Create a new menu.
-- @param opts { title = string, items = array of { label = string, data = any } }
-- @return menu instance
function M.new(opts)
  opts = opts or {}
  local m = setmetatable({}, Menu)
  m.title = opts.title or ""
  m.items = opts.items or {}
  m.index = 1
  return m
end

--- Move the selection by delta, clamping at the ends (no wrap).
-- @param delta integer
function Menu:move(delta)
  if #self.items == 0 then
    return
  end
  local idx = self.index + delta
  if idx < 1 then
    idx = 1
  elseif idx > #self.items then
    idx = #self.items
  end
  self.index = idx
end

--- Return the currently selected item, or nil if there are no items.
-- @return item table or nil
function Menu:selected()
  if #self.items == 0 then
    return nil
  end
  return self.items[self.index]
end

--- Number of items in the menu.
-- @return number
function Menu:count()
  return #self.items
end

-- Truncate a label so it fits within `pw` pixels at CHAR_WIDTH per char.
local function truncate(label, pw)
  local max_chars = math.floor(pw / CHAR_WIDTH)
  if max_chars < 0 then
    max_chars = 0
  end
  if #label <= max_chars then
    return label
  end
  if max_chars <= 0 then
    return ""
  end
  return string.sub(label, 1, max_chars)
end

--- Draw the menu.
-- @param px pixel top-left x
-- @param py pixel top-left y
-- @param pw pixel width
function Menu:draw(px, py, pw)
  -- Title row with background bar.
  gfx.rect_fill(px, py, pw, LINE_HEIGHT, P.GRAY + 3)
  gfx.text(truncate(self.title, pw), px, py, P.UI_TEXT)

  if #self.items == 0 then
    gfx.text("(nothing)", px, py + LINE_HEIGHT, P.UI_DIM)
    return
  end

  for i, item in ipairs(self.items) do
    local row_y = py + i * LINE_HEIGHT
    local label = truncate(item.label, pw)
    if i == self.index then
      gfx.rect_fill(px, row_y, pw, LINE_HEIGHT, P.GRAY + 4)
      gfx.text(label, px, row_y, P.WHITE)
    else
      gfx.text(label, px, row_y, P.UI_DIM)
    end
  end
end

return M
