local P = require("palette")

-- Glyphs: printable Basic Latin only (see SPEC "GLYPH RULE").
-- bg is the per-tile background fill; keep it 2-3 ramp steps below the
-- glyph color or the glyph disappears.
return {
  { id = "sky", glyph = " ", color = P.BLUE + 3, bg = P.BLUE + 1,
    walkable = false, opaque = false, is_sky = true,
    desc = "Open sky. A very long way down." },

  { id = "grass", glyph = ",", color = P.GREEN + 4, bg = P.GREEN + 1,
    walkable = true, opaque = false,
    desc = "Wind-flattened island grass." },

  { id = "grass_tall", copy_from = "grass", glyph = "\"", color = P.GREEN + 3,
    desc = "Tall grass, gone to seed." },

  { id = "dirt", glyph = ".", color = P.TAN + 3, bg = P.TAN + 1,
    walkable = true, opaque = false,
    desc = "Bare packed dirt." },

  { id = "rock", glyph = "^", color = P.GRAY + 6, bg = P.GRAY + 3,
    walkable = true, opaque = false,
    desc = "Weathered stone, veined with old mineral streaks." },

  { id = "tree", glyph = "T", color = P.GREEN + 6, bg = P.GREEN + 2,
    walkable = true, opaque = true, conceals = true,
    desc = "A wind-bent tree. You can push through, but not see through." },

  { id = "bush", glyph = "%", color = P.GREEN + 4, bg = P.GREEN + 2,
    walkable = true, opaque = true, conceals = true,
    desc = "A dense thicket. Good cover - yours or something else's." },

  { id = "wall_plank", glyph = "#", color = P.TAN + 4, bg = P.TAN + 2,
    walkable = false, opaque = true,
    desc = "A plank wall, silvered by the wind." },

  { id = "floor_planks", glyph = "-", color = P.TAN + 4, bg = P.TAN + 1,
    walkable = true, opaque = false,
    desc = "Creaking plank flooring." },

  { id = "door_closed", glyph = "+", color = P.TAN + 5, bg = P.TAN + 2,
    walkable = false, opaque = true, door = { opens_to = "door_open" },
    desc = "A shut door." },

  { id = "door_open", glyph = "'", color = P.TAN + 5, bg = P.TAN + 1,
    walkable = true, opaque = false, door = { closes_to = "door_closed" },
    desc = "An open door." },
}
