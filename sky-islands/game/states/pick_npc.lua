-- Tiny picker for when more than one person is within arm's reach:
-- choose who to [T]alk to.
local L = require("ui.layout")
local P = require("palette")
local menu = require("ui.menu")

local S = {}

function S.enter(self, npcs)
  local items = {}
  for _, n in ipairs(npcs) do
    items[#items + 1] = { label = n.def.title, data = { npc = n } }
  end
  self.menu = menu.new({ title = "talk to whom?", items = items })
end

function S.key(self, k)
  if k == "up" or k == "k" then self.menu:move(-1)
  elseif k == "down" or k == "j" then self.menu:move(1)
  elseif k == "space" then
    local sel = self.menu:selected()
    State.stack:pop()
    if sel then
      State.stack:push(require("game.states.talk"), sel.data.npc)
    end
  elseif k == "backspace" then
    State.stack:pop()
  end
end

function S.draw(self)
  local px, py = L.px(24), L.py(8)
  local pw = 30 * L.CELL_W
  local ph = (self.menu:count() + 2) * L.CELL_H
  gfx.rect_fill(px - 4, py - 4, pw + 8, ph + 8, P.GRAY + 2)
  gfx.rect(px - 4, py - 4, pw + 8, ph + 8, P.BLUE + 5)
  self.menu:draw(px, py, pw)
end

return S
