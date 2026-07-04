-- Apollo palette (lospec.com/palette-list/apollo), loaded from palette.png.
-- 46 slots: six 6-step ramps + 10 grays. Ramps run dark -> light, so
-- ramp base + intensity (1..6) gives a color: pal.GOLD + fire_intensity.
local pal = {}

-- Ramp base offsets (add 1..6).
pal.BLUE = 0 -- sky, water, ice, night
pal.GREEN = 6 -- vegetation, poison
pal.TAN = 12 -- earth, wood, skin, parchment
pal.GOLD = 18 -- fire, light, sand, treasure
pal.RED = 24 -- blood, danger, heat
pal.MAGENTA = 30 -- magic, arcane, corruption
pal.GRAY = 36 -- stone, metal, smoke, UI (10 steps, 1..10)

pal.RAMPS = {
  { name = "blue", base = pal.BLUE, len = 6 },
  { name = "green", base = pal.GREEN, len = 6 },
  { name = "tan", base = pal.TAN, len = 6 },
  { name = "gold", base = pal.GOLD, len = 6 },
  { name = "red", base = pal.RED, len = 6 },
  { name = "magenta", base = pal.MAGENTA, len = 6 },
  { name = "gray", base = pal.GRAY, len = 10 },
}

-- Common picks so drawing code isn't full of magic offsets.
pal.BLACK = pal.GRAY + 1
pal.WHITE = pal.GRAY + 10
pal.UI_DIM = pal.GRAY + 6
pal.UI_TEXT = pal.GRAY + 9

-- Dim a color for fog-of-war "remembered" tiles: two steps down its own
-- ramp, clamped so it never goes fully dark. Grays clamp higher because
-- their bottom steps are near-black.
function pal.dim(c)
  if c <= 0 or c > 46 then return pal.GRAY + 4 end
  if c > pal.GRAY then
    return math.max(pal.GRAY + 3, c - 2)
  end
  local base = ((c - 1) // 6) * 6
  return math.max(base + 2, c - 2)
end

return pal
