local P = require("palette")

-- Glyphs: printable Basic Latin only (see SPEC "GLYPH RULE").
return {
  { id = "sky", glyph = " ", color = P.BLUE + 2,
    walkable = false, opaque = false, is_sky = true,
    desc = "Open sky. A very long way down." },

  { id = "grass", glyph = ",", color = P.GREEN + 4,
    walkable = true, opaque = false,
    desc = "Wind-flattened island grass." },

  { id = "grass_tall", copy_from = "grass", glyph = "\"", color = P.GREEN + 3,
    desc = "Tall grass, gone to seed." },

  { id = "dirt", glyph = ".", color = P.TAN + 3,
    walkable = true, opaque = false,
    desc = "Bare packed dirt." },

  { id = "rock", glyph = "^", color = P.GRAY + 6,
    walkable = true, opaque = false,
    desc = "Weathered stone, veined with old mineral streaks." },

  { id = "wall_plank", glyph = "#", color = P.TAN + 2,
    walkable = false, opaque = true,
    desc = "A plank wall, silvered by the wind." },

  { id = "floor_planks", glyph = "-", color = P.TAN + 4,
    walkable = true, opaque = false,
    desc = "Creaking plank flooring." },

  { id = "door_closed", glyph = "+", color = P.TAN + 5,
    walkable = false, opaque = true, door = { opens_to = "door_open" },
    desc = "A shut door." },

  { id = "door_open", glyph = "'", color = P.TAN + 5,
    walkable = true, opaque = false, door = { closes_to = "door_closed" },
    desc = "An open door." },
}
