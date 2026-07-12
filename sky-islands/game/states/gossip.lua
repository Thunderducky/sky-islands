-- Shopkeeper gossip overlay: when a market event is news (first store
-- visit since it started), this pops over the transfer UI and delivers
-- the event's cause in the keeper's voice. One line, picked
-- deterministically from the event def's gossip pool.
local L = require("ui.layout")
local P = require("palette")
local rng = require("util.rng")

local S = {}

local BOX_X, BOX_W = 12, 54 -- cells

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

function S.enter(self, ev)
  local def = State.defs.econ_event_by_id[ev.id]
  self.title = def.name
  local r = rng.derive(State.master, "gossip:" .. ev.id .. ":" .. State.cycle)
  self.lines = wrap(def.gossip[r:int(1, #def.gossip)], BOX_W - 4)
end

function S.key(self, k)
  if k == "space" or k == "backspace" then
    State.stack:pop()
  end
end

function S.draw(self)
  local top_y = 8
  local h = #self.lines + 5
  local px, py = L.px(BOX_X), L.py(top_y)
  local pw, ph = BOX_W * L.CELL_W, h * L.CELL_H
  gfx.rect_fill(px - 4, py - 4, pw + 8, ph + 8, P.GRAY + 2)
  gfx.rect(px - 4, py - 4, pw + 8, ph + 8, P.GOLD + 4)
  L.text(BOX_X, top_y, "the keeper leans in:", P.UI_DIM)
  L.text(BOX_X + 2, top_y + 1, self.title:upper(), P.GOLD + 5)
  for i, line in ipairs(self.lines) do
    L.text(BOX_X + 2, top_y + 2 + i, line, P.UI_TEXT)
  end
  L.text(BOX_X, top_y + h - 1, "[Space] so it goes", P.UI_DIM)
end

return S
