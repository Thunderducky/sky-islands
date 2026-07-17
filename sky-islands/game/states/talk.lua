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
    local text = topic.text
    if State.persist.debt == 0 and topic.text_free then
      text = topic.text_free -- freedom changes some answers
    end
    items[#items + 1] = { label = topic.label, data = { text = text } }
  end
  if self.npc.def.trade or self.npc.def.trade_store then
    items[#items + 1] = { label = "(trade)", data = { trade = true } }
  end
  if self.npc.def.travel then
    local eco = State.defs.economy
    local here = State.world.current
    for _, d in ipairs(eco.travel.destinations) do
      if ("isle:authored:" .. d.id) ~= here then
        local spec = State.defs.island_by_id[d.id]
        items[#items + 1] = {
          label = string.format("(fly: %s - %dc, %dcy)",
            spec.name, d.fee, d.distance),
          data = { travel = d.id, fee = d.fee },
        }
      end
    end
    if here ~= "hub" then
      items[#items + 1] = {
        label = string.format("(fly: the Tether - %dc, %dcy)",
          eco.travel.hub.fee, eco.travel.hub.distance),
        data = { travel = "hub", fee = eco.travel.hub.fee },
      }
    end
    if State.island.sells_passage then
      items[#items + 1] = {
        label = string.format("(book passage OUT - %dc)",
          eco.travel.retire_cost),
        data = { retire = true },
      }
    end
  end
  items[#items + 1] = { label = "(goodbye)", data = { bye = true } }
  self.menu = menu.new({ title = self.npc.def.title, items = items })
end

-- Portrait slice for an NPC: their own, else the generic "Shadow"
-- fallback, else nil (layout degrades to text-only).
local function portrait_of(def)
  local art = require("defs.art")
  return art[def.portrait or "Placeholder"]
end

function S.enter(self, npc)
  self.npc = npc
  self.convo = npc.def.conversation
  self.portrait = portrait_of(npc.def)
  -- portrait (96px = 12 cells) reserves the box's left side
  self.text_w = BOX_W - 4 - (self.portrait and 13 or 0)
  local greeting = self.convo.greeting
  if State.persist.debt == 0 and self.convo.greeting_free then
    greeting = self.convo.greeting_free
  end
  self.body = wrap(greeting, self.text_w)
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
    elseif sel.data.travel then
      if sel.data.travel ~= "hub" and State.persist.debt > 0 then
        self.body = wrap("\"Company debtors fly company routes only. Clear your ledger first - that's policy.\"", self.text_w)
      elseif State.persist.credits < sel.data.fee then
        self.body = wrap("\"Fare's posted. Come back when your pockets agree with it.\"", self.text_w)
      else
        local dest = sel.data.travel
        State.stack:pop() -- conversation over; the skiff won't wait
        require("game.run").travel(dest)
      end
    elseif sel.data.retire then
      local cost = State.defs.economy.travel.retire_cost
      if State.persist.debt > 0 then
        self.body = wrap("\"Passage out is for closed accounts only. The Conglomerate checks.\"", self.text_w)
      elseif State.persist.credits < cost then
        self.body = wrap("\"Out-of-sector passage runs " .. cost .. "c. A number worth working toward.\"", self.text_w)
      else
        State.stack:push(require("game.states.confirm"), {
          text = "Spend " .. cost .. "c and leave the sector for good?",
          on_yes = function()
            State.persist.credits = State.persist.credits - cost
            State.stack:switch(require("game.states.retired"))
          end,
        })
      end
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
            debt_desk = State.island.is_hub or nil,
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
      self.body = wrap(sel.data.text, self.text_w)
    end
  elseif k == "backspace" then
    State.stack:pop()
  end
end

function S.draw(self)
  -- step aside while something's open over the conversation (trading):
  -- the world stays visible instead of a stack of boxes
  if State.stack:top() ~= self then return end
  local top_y = 5
  local text_x = BOX_X + 1 + (self.portrait and 13 or 0)
  local h = #self.body + self.menu:count() + 6
  if self.portrait then h = math.max(h, 12) end -- 8 portrait rows + trim
  local px, py = L.px(BOX_X), L.py(top_y)
  local pw, ph = BOX_W * L.CELL_W, h * L.CELL_H
  gfx.rect_fill(px - 4, py - 4, pw + 8, ph + 8, P.GRAY + 2)
  gfx.rect(px - 4, py - 4, pw + 8, ph + 8, P.BLUE + 5)
  L.text(BOX_X, top_y, self.npc.def.title:upper(), P.BLUE + 6)
  if self.portrait then
    local t = self.portrait
    local fx, fy = L.px(BOX_X + 1), L.py(top_y + 2)
    gfx.sspr(t.x, t.y, t.w, t.h, fx, fy)
    gfx.rect(fx - 1, fy - 1, t.w + 2, t.h + 2, P.GRAY + 5)
  end
  for i, line in ipairs(self.body) do
    L.text(text_x, top_y + 1 + i, line, P.UI_TEXT)
  end
  self.menu:draw(L.px(text_x), L.py(top_y + 3 + #self.body),
    (BOX_W - (text_x - BOX_X) - 1) * L.CELL_W)
  L.text(BOX_X, top_y + h - 1,
    "[Space] choose  [Bksp] walk away", P.UI_DIM)
end

return S
