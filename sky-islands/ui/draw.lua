-- The renderer: map viewport (camera-follow), sidebar, log. Immediate
-- mode, 80x30 cells; no dirty tracking until proven necessary.
local L = require("ui.layout")
local P = require("palette")
local sub = require("world.substrate")

local M = {}

-- Pure center-follow, deliberately unclamped: the island floats in open
-- sky, so the camera can never "hit" an edge — beyond the data we just
-- render more sky (see M.map). The border cushion is the world itself.
function M.camera(S)
  local m = L.MAP
  return S.player.x - m.w // 2, S.player.y - m.h // 2
end

-- Sky is exempt from fog: you can always see the sky (it's the sky), and
-- it extends past the island's data in every direction. Rendering it
-- uniformly means no seam at the array edge and the unexplored island
-- reads as a dark silhouette against blue — the view you flew in on.
local function draw_sky_cell(cx, cy, x, y)
  gfx.rect_fill(L.px(cx), L.py(cy), L.CELL_W, L.CELL_H, P.BLUE + 1)
  if (x * 7 + y * 13) % 11 == 0 then -- faint drifting depth marks
    L.text(cx, cy, ".", P.BLUE + 3)
  end
end

local function cell_appearance(S, x, y, visible)
  local island, defs = S.island, S.defs
  local t = defs.terrain[sub.get(island, "terrain", x, y)]
  local glyph, color, bg = t.glyph, t.color, t.bg
  local f = sub.feature_at(island, x, y)
  if f then glyph, color = f.def.glyph, f.def.color end
  local pile = sub.pile_at(island, x, y)
  if pile and #pile > 0 and visible then
    local it = defs.item_by_id[pile[1].id]
    glyph, color = it.glyph, it.color
  end
  return glyph, color, bg
end

-- Remembered tiles get a uniform gray wash behind dimmed glyphs: bg colors
-- already sit at their ramp floor, so down-ramp dimming can't distinguish
-- them — desaturation reads as "memory" instead.
local MEMORY_BG = P.GRAY + 2

function M.map(S)
  local island = S.island
  local cam_x, cam_y = M.camera(S)
  local m = L.MAP
  for sy = 0, m.h - 1 do
    for sx = 0, m.w - 1 do
      local x, y = cam_x + sx, cam_y + sy
      local in_bounds = sub.in_bounds(island, x, y)
      if not in_bounds or
          S.defs.terrain[sub.get(island, "terrain", x, y)].is_sky then
        draw_sky_cell(m.x + sx, m.y + sy, x, y)
      else
        local fog = sub.get(island, "fog", x, y)
        if fog > 0 then
          local visible = fog == 2
          local glyph, color, bg = cell_appearance(S, x, y, visible)
          if not visible then
            color, bg = P.dim(color), MEMORY_BG
          end
          if bg then
            gfx.rect_fill(L.px(m.x + sx), L.py(m.y + sy), L.CELL_W, L.CELL_H, bg)
          end
          if glyph ~= " " then L.text(m.x + sx, m.y + sy, glyph, color) end
        end
      end
    end
  end
  -- creatures: visible tiles only, honoring concealment (a thing in a
  -- thicket is hidden until you're next to it)
  local creatures = require("sim.creatures")
  for _, c in ipairs(island.creatures or {}) do
    local sx, sy = c.x - cam_x, c.y - cam_y
    if sx >= 0 and sy >= 0 and sx < m.w and sy < m.h
        and creatures.visible_to_player(S, c) then
      L.text(m.x + sx, m.y + sy, c.def.glyph, c.def.color)
    end
  end
  -- player, always on top (tile bg stays: only the glyph is the player)
  L.text(m.x + S.player.x - cam_x, m.y + S.player.y - cam_y, "@", P.WHITE)
end

function M.sidebar(S)
  local s = L.SIDE
  local island = S.island
  -- separator
  for y = 0, s.h - 1 do L.text(s.x - 1, y, "|", P.GRAY + 4) end

  L.text(s.x, 0, island.is_hub and "HOME" or "SURVEY", P.GOLD + 5)
  L.text(s.x, 1, island.name, P.BLUE + 6)

  if S.mission then
    local cov = island.land_count > 0 and island.seen_count / island.land_count or 0
    local cov_color = cov >= 0.75 and P.GREEN + 5 or cov >= 0.4 and P.GOLD + 4 or P.RED + 5
    L.text(s.x, 3, string.format("coverage %3d%%", math.floor(cov * 100)), cov_color)
    L.text(s.x, 4, string.format("caches   %d/%d",
      #S.run.discovered, island.cache_count), P.GOLD + 5)
  end

  local inv = require("sim.inventory")
  local slots = S.defs.economy.player_slots
  local slot_color = #S.player.inv >= slots and P.RED + 5 or P.UI_TEXT
  L.text(s.x, 6, string.format("cash  %5dc", S.persist.credits), P.GOLD + 5)
  if S.persist.debt > 0 then
    L.text(s.x, 7, string.format("debt  %5dc", S.persist.debt), P.RED + 4)
  else
    L.text(s.x, 7, "debt   FREE", P.GREEN + 6)
  end
  L.text(s.x, 8, string.format("pack  %5dc", inv.value(S.player.inv, S.defs.item_by_id)), P.GOLD + 4)
  L.text(s.x, 9, string.format("slots  %d/%d", #S.player.inv, slots), slot_color)
  L.text(s.x, 10, string.format("skiff %5dc", inv.value(S.skiff.hold, S.defs.item_by_id)), P.GOLD + 4)
  L.text(s.x, 11, string.format("turn  %5d", S.clock.turn), P.GRAY + 7)

  local pl = S.defs.economy.player
  local frac = S.player.hp / pl.max_hp
  local hp_color = frac > 0.66 and P.GREEN + 5 or frac > 0.33 and P.GOLD + 4 or P.RED + 5
  L.text(s.x, 12, string.format("hp    %2d/%2d", S.player.hp, pl.max_hp), hp_color)

  local needs = require("sim.needs")
  local hstate = S.player.hunger_state or "full"
  if hstate ~= "full" then
    L.text(s.x, 13, hstate:upper(), needs.COLORS[hstate])
  end

  local hints = {
    "arrows/hjkl move",
    "g get   o door",
    "i inv   x look",
    ". wait",
    "Space interact",
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
