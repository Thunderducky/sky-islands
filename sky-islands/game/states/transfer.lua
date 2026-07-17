-- Two-pane transfer UI: player slots on the left, a container on the
-- right (cache loot, skiff hold, or a ground pile — anything with a
-- .items list). Space/g moves the selected stack; Tab/h/l switch panes;
-- Backspace closes. Transfers are free actions (no turn cost) until
-- combat gives time a price.
local L = require("ui.layout")
local P = require("palette")
local inv = require("sim.inventory")
local flavor = require("flavor")
local market = require("sim.market")

local S = {}

local PANE_W = 32 -- cells
local LEFT_X, RIGHT_X, TOP_Y = 6, 40, 3
local MAX_ROWS = 16 -- taller lists scroll, keeping the cursor in view

local function cap() return State.defs.economy.player_slots end
local function max_stack_of(id)
  return State.defs.item_by_id[id].max_stack or 1
end

function S.enter(self, container)
  self.cont = container
  -- start focused where the action likely is: full container -> take,
  -- empty container (skiff hold) -> stow
  self.focus = #container.items > 0 and "cont" or "player"
  self.cur = { player = 1, cont = 1 }
end

local function clamp(self)
  self.cur.player = math.max(1, math.min(self.cur.player, cap()))
  self.cur.cont = math.max(1, math.min(self.cur.cont, math.max(1, #self.cont.items)))
end

-- prices.market marks the company store: active market events scale
-- both sides of the counter by demand level (sim/market.lua).
local function buy_price(def, prices)
  local m = prices.market and market.charge_mult(State, def) or 1
  return math.max(1, math.ceil(def.value * prices.buy * m))
end
local function sell_price(def, prices)
  local m = prices.market and market.pay_mult(State, def) or 1
  return math.floor(def.value * prices.sell * m)
end

-- one=true moves a single unit (tap g to trickle); otherwise whole stack.
-- If the container has .prices it's a shop: taking costs credits, stowing
-- pays them.
local function transfer(self, one)
  local defs = State.defs
  local prices = self.cont.prices
  if self.focus == "cont" then
    local stack = self.cont.items[self.cur.cont]
    if not stack then return end
    local want = one and 1 or stack.n
    if prices then
      local unit = buy_price(defs.item_by_id[stack.id], prices)
      local afford = State.persist.credits // unit
      if afford == 0 then
        flavor.emit("broke", {})
        return
      end
      want = math.min(want, afford)
    end
    local moved = inv.add(State.player.inv, cap(), max_stack_of,
      { id = stack.id, n = want })
    if moved == 0 then
      flavor.emit("no_room", {})
      return
    end
    local summary = inv.summary({ { id = stack.id, n = moved } }, defs.item_by_id)
    if prices then
      local cost = moved * buy_price(defs.item_by_id[stack.id], prices)
      State.persist.credits = State.persist.credits - cost
      flavor.emit("buy", { items = summary, cost = cost })
    else
      flavor.emit("pickup", { items = summary })
    end
    stack.n = stack.n - moved
    if stack.n == 0 then table.remove(self.cont.items, self.cur.cont) end
    if #self.cont.items == 0 and self.cont.on_empty then
      self.cont.on_empty()
    end
  else
    if self.cont.take_only then
      flavor.emit("cant_stow", { where = self.cont.name })
      return
    end
    local stack = State.player.inv[self.cur.player]
    if not stack then return end
    local want = one and 1 or stack.n
    local moved = inv.add(self.cont.items, self.cont.cap, max_stack_of,
      { id = stack.id, n = want })
    if moved == 0 then
      flavor.emit("no_room_there", { where = self.cont.name })
      return
    end
    local summary = inv.summary({ { id = stack.id, n = moved } }, defs.item_by_id)
    if prices then
      local earned = moved * sell_price(defs.item_by_id[stack.id], prices)
      State.persist.credits = State.persist.credits + earned
      flavor.emit("sell", { items = summary, earned = earned })
    else
      flavor.emit("stow", { items = summary, where = self.cont.name })
    end
    stack.n = stack.n - moved
    if stack.n == 0 then table.remove(State.player.inv, self.cur.player) end
  end
end

function S.key(self, k)
  if k == "backspace" then
    State.stack:pop()
    return
  elseif k == "tab" or k == "h" or k == "l" or k == "left" or k == "right" then
    self.focus = self.focus == "cont" and "player" or "cont"
  elseif k == "up" or k == "k" then
    self.cur[self.focus] = self.cur[self.focus] - 1
  elseif k == "down" or k == "j" then
    self.cur[self.focus] = self.cur[self.focus] + 1
  elseif k == "space" then
    transfer(self, false)
  elseif k == "g" then
    transfer(self, true)
  elseif k == "d" and self.cont.debt_desk then
    -- voluntary debt payment at the store
    local eco = State.defs.economy
    if State.persist.debt == 0 then
      flavor.emit("no_debt", {})
      return
    end
    local pay = math.min(eco.debt_payment_step, State.persist.credits,
      State.persist.debt)
    if pay > 0 then
      State.persist.credits = State.persist.credits - pay
      State.persist.debt = State.persist.debt - pay
      flavor.emit("debt_pay", { paid = pay, debt = State.persist.debt })
      if State.persist.debt == 0 then
        -- the last coin lands at the counter: close the shop, hand over
        -- the coldest letter in company history
        State.stack:pop()
        State.stack:push(require("game.states.manumission"))
      end
    else
      flavor.emit("broke", {})
    end
  end
  clamp(self)
end

-- Slice rows to a window that keeps the cursor visible (the store's deep
-- reserves no longer fit on screen). Returns rows-to-draw, cursor index
-- within them, and whether rows are hidden above/below.
local function scroll_window(rows, cursor)
  if #rows <= MAX_ROWS then return rows, cursor, false, false end
  local first = math.max(1, math.min(cursor - MAX_ROWS // 2,
    #rows - MAX_ROWS + 1))
  local out = {}
  for i = first, first + MAX_ROWS - 1 do out[#out + 1] = rows[i] end
  return out, cursor - first + 1, first > 1, first + MAX_ROWS - 1 < #rows
end

-- demand markers: what the level means for the PLAYER at this counter
local DEMAND_MARK = {
  critical = { glyph = "^", color = P.RED + 5 },
  high = { glyph = "^", color = P.GOLD + 5 },
  low = { glyph = "v", color = P.GREEN + 4 },
  glut = { glyph = "v", color = P.GREEN + 5 },
}

local function draw_pane(self, x, title, all_rows, cursor, focused)
  local defs = State.defs
  local rows, cur, more_up, more_down = scroll_window(all_rows, cursor)
  local n_rows = math.max(#rows, 1)
  local px, py = L.px(x), L.py(TOP_Y)
  local pw, ph = PANE_W * L.CELL_W, (n_rows + 2) * L.CELL_H
  gfx.rect_fill(px - 4, py - 4, pw + 8, ph + 8, P.GRAY + 2)
  gfx.rect(px - 4, py - 4, pw + 8, ph + 8, focused and P.GOLD + 4 or P.GRAY + 5)
  L.text(x, TOP_Y, title, focused and P.GOLD + 5 or P.UI_DIM)
  if more_up then L.text(x + PANE_W - 1, TOP_Y, "^", P.UI_DIM) end
  for i, row in ipairs(rows) do
    local cy = TOP_Y + 1 + i
    if focused and i == cur then
      gfx.rect_fill(px - 2, L.py(cy), pw + 4, L.CELL_H, P.GRAY + 4)
    end
    if row.stack then
      local def = defs.item_by_id[row.stack.id]
      L.text(x, cy, def.glyph, def.color)
      L.text(x + 2, cy, string.format("%-18s x%-3d", def.name, row.stack.n),
        (focused and i == cur) and P.WHITE or P.UI_TEXT)
      local money = row.unit_price
          and string.format("%3dc ea", row.unit_price)
          or string.format("%4dc", def.value * row.stack.n)
      L.text(x + 24, cy, money, P.GOLD + 4)
      local mark = row.demand and DEMAND_MARK[row.demand]
      if mark then L.text(x + PANE_W - 1, cy, mark.glyph, mark.color) end
    else
      L.text(x + 2, cy, row.label, P.UI_DIM)
    end
  end
  if more_down then
    L.text(x + PANE_W - 1, TOP_Y + 1 + #rows, "v", P.UI_DIM)
  end
end

function S.draw(self)
  local defs = State.defs
  local prices = self.cont.prices
  local is_market = prices and prices.market
  local player_rows = {}
  for i = 1, cap() do
    local stack = State.player.inv[i]
    local row = stack and { stack = stack } or { label = "- empty -" }
    if stack and prices then
      local def = defs.item_by_id[stack.id]
      row.unit_price = sell_price(def, prices)
      if is_market then row.demand = market.demand_of(State, def) end
    end
    player_rows[i] = row
  end
  local cont_rows = {}
  for _, stack in ipairs(self.cont.items) do
    local row = { stack = stack }
    if prices then
      local def = defs.item_by_id[stack.id]
      row.unit_price = buy_price(def, prices)
      if is_market then row.demand = market.demand_of(State, def) end
    end
    cont_rows[#cont_rows + 1] = row
  end
  if #cont_rows == 0 then cont_rows[1] = { label = "(empty)" } end

  draw_pane(self, LEFT_X,
    string.format("YOU  %d/%d slots", #State.player.inv, cap()),
    player_rows, self.cur.player, self.focus == "player")
  draw_pane(self, RIGHT_X,
    string.format("%s  %d/%d slots", self.cont.name:upper(),
      #self.cont.items, self.cont.cap),
    cont_rows, self.cur.cont, self.focus == "cont")

  local hint_y = TOP_Y + math.max(math.min(#player_rows, MAX_ROWS),
    math.min(#cont_rows, MAX_ROWS)) + 3
  -- backdrop for the hint/market lines: without it the map's glyphs
  -- show through between the letters
  gfx.rect_fill(L.px(LEFT_X) - 4, L.py(hint_y) - 2,
    (RIGHT_X + PANE_W - LEFT_X) * L.CELL_W + 8, 2 * L.CELL_H + 4,
    P.GRAY + 2)
  if self.cont.take_only then
    L.text(LEFT_X, hint_y, "[Space] take stack  [g] take one  [Bksp] close", P.UI_DIM)
  elseif prices then
    if State.persist.debt > 0 and self.cont.debt_desk then
      L.text(LEFT_X, hint_y, string.format(
        "cash %dc  debt %dc   [Space] buy/sell  [g] one  [d] pay %dc debt  [Bksp] close",
        State.persist.credits, State.persist.debt,
        State.defs.economy.debt_payment_step), P.GOLD + 5)
    else
      L.text(LEFT_X, hint_y, string.format(
        "cash %dc  FREE AGENT   [Space] buy/sell  [g] one  [Bksp] close",
        State.persist.credits), P.GOLD + 5)
    end
  else
    L.text(LEFT_X, hint_y, "[Space] move stack  [g] move one  [Tab] pane  [Bksp] close", P.UI_DIM)
  end
  if is_market then
    local ev = market.active_def(State)
    if ev then
      L.text(LEFT_X, hint_y + 1,
        "word at the counter: " .. ev.name .. "  (^ dear / v cheap)",
        P.GOLD + 4)
    end
  end
end

return S
