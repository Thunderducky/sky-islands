local P = require("palette")

-- speed: mp per world turn, acts at 100 (50 = half speed, 200 = double).
-- aggro_radius 0 = docile: wanders, retaliates only when hurt.
-- drops roll into a ground pile on death.
return {
  { id = "dust_hen", name = "dust-hen", glyph = "h", color = P.TAN + 4,
    max_hp = 4, damage = { 1, 2 }, acc = 0.5, speed = 100, aggro_radius = 0,
    drops = { { item = "game_meat", min = 1, max = 2, chance = 0.9 } },
    desc = "A fat, flightless bird pecking at the dirt. It has never heard of you and would prefer to keep it that way." },

  { id = "rim_shrike", name = "rim shrike", glyph = "r", color = P.RED + 4,
    max_hp = 5, damage = { 1, 3 }, acc = 0.75, speed = 100, aggro_radius = 9,
    drops = { { item = "game_meat", min = 1, max = 1, chance = 0.6 } },
    desc = "A wind-riding raptor with opinions about trespassers. Fast, mean, mostly beak." },

  { id = "thorn_hog", name = "thorn-hog", glyph = "q", color = P.GREEN + 5,
    max_hp = 12, damage = { 2, 4 }, acc = 0.7, speed = 100, aggro_radius = 7,
    drops = { { item = "game_meat", min = 2, max = 3, chance = 0.9 } },
    desc = "A bristle-backed rooter that treats thickets as home and you as an intrusion. You will not hear it coming." },

  { id = "shard_warden", name = "shard-warden", glyph = "W", color = P.MAGENTA + 5,
    max_hp = 20, damage = { 3, 6 }, acc = 0.8, speed = 50, aggro_radius = 6,
    drops = { { item = "ward_shard", min = 1, max = 1, chance = 0.5 } },
    desc = "A pre-Fracture construct, still keeping a watch nobody assigned it. Slow. Patient. Very committed." },
}
