local L = require("ui.layout")
local P = require("palette")
local menu = require("ui.menu")

local S = {}

function S.enter(self)
  local items = {}
  local total = 0
  for _, it in ipairs(State.player.inv) do
    local def = State.defs.item_by_id[it.id]
    local v = def.value * it.n
    total = total + v
    items[#items + 1] = {
      label = string.format("%-22s x%-2d %4dc", def.name, it.n, v),
      data = it,
    }
  end
  self.total = total
  self.menu = menu.new({ title = "HAUL", items = items })
end

function S.key(self, k)
  if k == "up" or k == "k" then self.menu:move(-1)
  elseif k == "down" or k == "j" then self.menu:move(1)
  elseif k == "i" or k == "space" then State.stack:pop()
  end
end

function S.draw(self)
  local px, py, pw = L.px(22), L.py(6), L.px(36)
  local rows = math.max(1, self.menu:count()) + 3
  gfx.rect_fill(px - 4, py - 4, pw + 8, rows * 12 + 20, P.GRAY + 2)
  gfx.rect(px - 4, py - 4, pw + 8, rows * 12 + 20, P.GRAY + 5)
  self.menu:draw(px, py, pw)
  gfx.text(string.format("total %dc", self.total),
    px, py + (rows - 1) * 12 + 4, P.GOLD + 5)
end

return S
