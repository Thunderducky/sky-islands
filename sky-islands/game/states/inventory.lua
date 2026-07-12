local L = require("ui.layout")
local P = require("palette")
local menu = require("ui.menu")
local needs = require("sim.needs")

local S = {}

local function rebuild(self)
  local items = {}
  local total = 0
  for i, it in ipairs(State.player.inv) do
    local def = State.defs.item_by_id[it.id]
    local v = def.value * it.n
    total = total + v
    local tag = def.nutrition and " [food]" or def.heal and " [heal]" or ""
    items[#items + 1] = {
      label = string.format("%-20s x%-2d %4dc%s", def.name, it.n, v, tag),
      data = { index = i },
    }
  end
  self.total = total
  self.menu = menu.new({
    title = string.format("PACK  %d/%d slots",
      #State.player.inv, State.defs.economy.player_slots),
    items = items,
  })
end

function S.enter(self)
  rebuild(self)
end

function S.key(self, k)
  if k == "up" or k == "k" then self.menu:move(-1)
  elseif k == "down" or k == "j" then self.menu:move(1)
  elseif k == "space" then
    local sel = self.menu:selected()
    if sel and needs.use(State, sel.data.index) then
      local keep = self.menu.index
      rebuild(self) -- fresh menu starts at the top...
      self.menu.index = keep
      self.menu:move(0) -- ...so restore, clamping if the slot is gone
    end
  elseif k == "i" or k == "backspace" then State.stack:pop()
  end
end

local BAR_W = 20

function S.draw(self)
  local px, py, pw = L.px(22), L.py(5), L.px(36)
  local rows = math.max(1, self.menu:count()) + 6
  gfx.rect_fill(px - 4, py - 4, pw + 8, rows * 12 + 28, P.GRAY + 2)
  gfx.rect(px - 4, py - 4, pw + 8, rows * 12 + 28, P.GRAY + 5)
  self.menu:draw(px, py, pw)

  local base = py + (rows - 4) * 12
  gfx.text(string.format("total %dc", self.total), px, base, P.GOLD + 5)

  -- hunger meter: the bar FILLS as you empty
  local eco = State.defs.economy
  local hunger = State.player.hunger or 0
  local state = needs.state(hunger, eco)
  local color = needs.COLORS[state]
  -- bar full = collapse imminent
  local fill = math.floor(math.min(1, hunger / eco.hunger.collapse) * BAR_W + 0.5)
  gfx.text("hunger", px, base + 16, P.UI_TEXT)
  gfx.text("[" .. string.rep("=", fill) .. string.rep(" ", BAR_W - fill) .. "]",
    px + 60, base + 16, color)
  gfx.text(state, px + 60 + (BAR_W + 3) * 6, base + 16, color)

  gfx.text("[Space] use selected   [Bksp] close", px, base + 32, P.UI_DIM)
end

return S
