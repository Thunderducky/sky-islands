-- The coordinator's contract board: three offers per cycle, derived purely
-- from (master, cycle) — browsing is free and repeatable.
local L = require("ui.layout")
local P = require("palette")

local S = {}

function S.enter(self)
  self.offers = require("game.run").offers()
  self.cur = 1
end

function S.key(self, k)
  if k == "up" or k == "k" then
    self.cur = math.max(1, self.cur - 1)
  elseif k == "down" or k == "j" then
    self.cur = math.min(#self.offers, self.cur + 1)
  elseif k == "space" then
    require("game.run").start_mission(self.offers[self.cur])
  elseif k == "backspace" then
    State.stack:pop()
  end
end

function S.draw(self)
  local x, y = 16, 6
  local px, py = L.px(x), L.py(y)
  local pw, ph = 46 * L.CELL_W, (#self.offers * 2 + 5) * L.CELL_H
  gfx.rect_fill(px - 4, py - 4, pw + 8, ph + 8, P.GRAY + 2)
  gfx.rect(px - 4, py - 4, pw + 8, ph + 8, P.BLUE + 5)
  L.text(x, y, "SURVEY CONTRACTS  -  posting cycle " .. State.cycle, P.BLUE + 6)

  -- Column plan (offsets from x, panel is 46 cells wide): id 0-7,
  -- danger 10-16, blurb 20-33, fee 38-42 — each with a clear gap so a
  -- long danger word or a 4-digit fee never runs into its neighbor.
  local DANGER = {
    { "calm", P.GREEN + 5 },
    { "uneasy", P.GOLD + 4 },
    { "hostile", P.RED + 5 },
  }
  for i, offer in ipairs(self.offers) do
    local cy = y + 1 + i * 2
    if i == self.cur then
      gfx.rect_fill(px - 2, L.py(cy), pw + 4, L.CELL_H, P.GRAY + 4)
    end
    L.text(x, cy, string.format("Isle-%03d", offer.seed % 1000),
      i == self.cur and P.WHITE or P.UI_TEXT)
    local d = DANGER[offer.reported]
    L.text(x + 10, cy, d[1]:upper(), d[2])
    L.text(x + 20, cy, "uncharted isle", P.UI_DIM)
    L.text(x + 38, cy, string.format("%4dc", offer.fee), P.GOLD + 5)
  end

  L.text(x, y + #self.offers * 2 + 3,
    "[Space] take contract   [Bksp] not today", P.UI_DIM)
end

return S
