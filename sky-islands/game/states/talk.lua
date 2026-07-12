-- Conversation overlay (SI-0005, v1 format: greeting -> flat topic menu
-- -> optional trade -> goodbye). Deliberately shallow; deeper dialogue
-- arrives only if this proves worth deepening.
local L = require("ui.layout")
local P = require("palette")
local menu = require("ui.menu")

local S = {}

local BOX_X, BOX_W = 10, 58 -- cells

local function wrap(text, width)
  local lines, line = {}, ""
  for word in text:gmatch("%S+") do
    if #line + #word + 1 > width then
      lines[#lines + 1] = line
      line = word
    else
      line = #line > 0 and (line .. " " .. word) or word
    end
  end
  if #line > 0 then lines[#lines + 1] = line end
  return lines
end

local function build_menu(self)
  local items = {}
  for _, topic in ipairs(self.convo.topics or {}) do
    items[#items + 1] = { label = topic.label, data = { text = topic.text } }
  end
  if self.npc.def.trade or self.npc.def.trade_store then
    items[#items + 1] = { label = "(trade)", data = { trade = true } }
  end
  items[#items + 1] = { label = "(goodbye)", data = { bye = true } }
  self.menu = menu.new({ title = self.npc.def.title, items = items })
end

function S.enter(self, npc)
  self.npc = npc
  self.convo = npc.def.conversation
  local greeting = self.convo.greeting
  if State.persist.debt == 0 and self.convo.greeting_free then
    greeting = self.convo.greeting_free
  end
  self.body = wrap(greeting, BOX_W - 4)
  build_menu(self)
end

function S.key(self, k)
  if k == "up" or k == "k" then self.menu:move(-1)
  elseif k == "down" or k == "j" then self.menu:move(1)
  elseif k == "space" then
    local sel = self.menu:selected()
    if not sel then return end
    if sel.data.bye then
      State.stack:pop()
    elseif sel.data.trade then
      if self.npc.def.trade_store then
        -- she runs the counter: open the island's store proper
        local island = State.island
        local counter
        for _, f in pairs(island.features) do
          if f.def.id == "trader" then counter = f break end
        end
        if counter then
          State.stack:push(require("game.states.transfer"), {
            name = "company store", items = counter.stock,
            cap = State.defs.economy.trader_slots,
            prices = { buy = State.defs.economy.buy_mult,
                       sell = State.defs.economy.sell_mult, market = true },
          })
        else
          self.body = { "\"Counter's not set up here. Come by the", "Tether.\"" }
        end
      else
        State.stack:push(require("game.states.transfer"), {
          name = self.npc.def.title,
          items = self.npc.stock or {},
          cap = self.npc.def.slots or 4,
          prices = { buy = State.defs.economy.npcs.prices.buy,
                     sell = State.defs.economy.npcs.prices.sell },
        })
      end
    else
      self.body = wrap(sel.data.text, BOX_W - 4)
    end
  elseif k == "backspace" then
    State.stack:pop()
  end
end

function S.draw(self)
  local top_y = 5
  local h = #self.body + self.menu:count() + 6
  local px, py = L.px(BOX_X), L.py(top_y)
  local pw, ph = BOX_W * L.CELL_W, h * L.CELL_H
  gfx.rect_fill(px - 4, py - 4, pw + 8, ph + 8, P.GRAY + 2)
  gfx.rect(px - 4, py - 4, pw + 8, ph + 8, P.BLUE + 5)
  L.text(BOX_X, top_y, self.npc.def.title:upper(), P.BLUE + 6)
  for i, line in ipairs(self.body) do
    L.text(BOX_X + 1, top_y + 1 + i, line, P.UI_TEXT)
  end
  self.menu:draw(px + L.CELL_W, L.py(top_y + 3 + #self.body),
    (BOX_W - 2) * L.CELL_W)
  L.text(BOX_X, top_y + h - 1,
    "[Space] choose  [Bksp] walk away", P.UI_DIM)
end

return S
