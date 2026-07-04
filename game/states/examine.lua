local L = require("ui.layout")
local P = require("palette")
local sub = require("world.substrate")
local draw = require("ui.draw")

local S = {}

local DIRS = {
  up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 },
  k = { 0, -1 }, j = { 0, 1 }, h = { -1, 0 }, l = { 1, 0 },
  y = { -1, -1 }, u = { 1, -1 }, b = { -1, 1 }, n = { 1, 1 },
}

function S.enter(self)
  self.x, self.y = State.player.x, State.player.y
end

function S.key(self, k)
  local d = DIRS[k]
  if d then
    local nx, ny = self.x + d[1], self.y + d[2]
    if sub.in_bounds(State.island, nx, ny) then
      self.x, self.y = nx, ny
    end
  elseif k == "x" or k == "space" then
    State.stack:pop()
  end
end

local function describe(self)
  local island, defs = State.island, State.defs
  if self.x == State.player.x and self.y == State.player.y then
    return "That's you. Still in one piece.", P.WHITE
  end
  local fog = sub.get(island, "fog", self.x, self.y)
  if fog == 0 then
    return "Unsurveyed. The report has a blank there.", P.UI_DIM
  end
  local f = sub.feature_at(island, self.x, self.y)
  if f then return f.def.desc or f.def.name, f.def.color end
  if fog == 2 then
    local pile = sub.pile_at(island, self.x, self.y)
    if pile then
      local def = defs.item_by_id[pile[1].id]
      return def.desc or def.name, def.color
    end
  end
  local t = defs.terrain[sub.get(island, "terrain", self.x, self.y)]
  return t.desc or t.id, t.color
end

function S.draw(self)
  local cam_x, cam_y = draw.camera(State)
  local sx, sy = self.x - cam_x, self.y - cam_y
  local m = L.MAP
  if sx >= 0 and sy >= 0 and sx < m.w and sy < m.h then
    gfx.rect(L.px(m.x + sx), L.py(m.y + sy), L.CELL_W, L.CELL_H, P.WHITE)
  end
  local text, color = describe(self)
  gfx.rect_fill(L.px(0), L.py(L.LOG.y), L.COLS * L.CELL_W, L.CELL_H, P.GRAY + 2)
  L.text(0, L.LOG.y, "LOOK: " .. text, color)
end

return S
