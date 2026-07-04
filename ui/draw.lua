-- The renderer: map viewport (camera-follow), sidebar, log. Immediate
-- mode, 80x30 cells; no dirty tracking until proven necessary.
local L = require("ui.layout")
local P = require("palette")
local sub = require("world.substrate")

local M = {}

function M.camera(S)
  local m = L.MAP
  local island = S.island
  local cx = math.max(0, math.min(S.player.x - m.w // 2, island.w - m.w))
  local cy = math.max(0, math.min(S.player.y - m.h // 2, island.h - m.h))
  return cx, cy
end

local function cell_appearance(S, x, y, visible)
  local island, defs = S.island, S.defs
  local t = defs.terrain[sub.get(island, "terrain", x, y)]
  local glyph, color = t.glyph, t.color
  if t.is_sky then
    -- faint drifting depth marks so the void reads as sky, not screen
    glyph = ((x * 7 + y * 13) % 11 == 0) and "." or " "
    return glyph, P.BLUE + 2
  end
  local f = sub.feature_at(island, x, y)
  if f then glyph, color = f.def.glyph, f.def.color end
  local pile = sub.pile_at(island, x, y)
  if pile and visible then
    local it = defs.item_by_id[pile[1].id]
    glyph, color = it.glyph, it.color
  end
  return glyph, color
end

function M.map(S)
  local island = S.island
  local cam_x, cam_y = M.camera(S)
  local m = L.MAP
  for sy = 0, m.h - 1 do
    for sx = 0, m.w - 1 do
      local x, y = cam_x + sx, cam_y + sy
      if sub.in_bounds(island, x, y) then
        local fog = sub.get(island, "fog", x, y)
        if fog > 0 then
          local visible = fog == 2
          local glyph, color = cell_appearance(S, x, y, visible)
          if not visible then color = P.dim(color) end
          if glyph ~= " " then L.text(m.x + sx, m.y + sy, glyph, color) end
        end
      end
    end
  end
  -- player, always on top
  L.text(m.x + S.player.x - cam_x, m.y + S.player.y - cam_y, "@", P.WHITE)
end

function M.sidebar(S)
  local s = L.SIDE
  local island = S.island
  -- separator
  for y = 0, s.h - 1 do L.text(s.x - 1, y, "|", P.GRAY + 4) end

  L.text(s.x, 0, "SURVEY", P.GOLD + 5)
  L.text(s.x, 1, island.name, P.BLUE + 6)

  local cov = island.land_count > 0 and island.seen_count / island.land_count or 0
  local cov_color = cov >= 0.75 and P.GREEN + 5 or cov >= 0.4 and P.GOLD + 4 or P.RED + 5
  L.text(s.x, 3, string.format("coverage %3d%%", math.floor(cov * 100)), cov_color)
  L.text(s.x, 4, string.format("caches   %d/%d",
    #S.run.discovered, island.cache_count), P.GOLD + 5)

  local inv_v = 0
  for _, it in ipairs(S.player.inv) do
    inv_v = inv_v + S.defs.item_by_id[it.id].value * it.n
  end
  L.text(s.x, 6, string.format("haul  %5dc", inv_v), P.GOLD + 4)
  L.text(s.x, 7, string.format("debt  %5dc", S.run.debt), P.RED + 4)
  L.text(s.x, 9, string.format("turn  %5d", S.clock.turn), P.GRAY + 7)

  local hints = {
    "arrows/hjkl move",
    "g get   o door",
    "i inv   x look",
    ". wait",
    "Space submit",
    "  (at beacon)",
  }
  for i, hint in ipairs(hints) do
    L.text(s.x, s.h - #hints + i - 1, hint, P.UI_DIM)
  end
end

function M.log(S)
  local lg = L.LOG
  L.text(lg.x, lg.y, string.rep("-", L.COLS), P.GRAY + 4)
  local lines = S.log:last(lg.h - 1)
  for i, line in ipairs(lines) do
    local color = line.color or P.UI_TEXT
    if i < #lines then color = P.dim(color) end -- older lines recede
    L.text(lg.x, lg.y + i, line.text, color)
  end
end

function M.frame(S)
  gfx.clear(P.GRAY + 1)
  M.map(S)
  M.sidebar(S)
  M.log(S)
end

return M
