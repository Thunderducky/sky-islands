local P = require("palette")

local M = {}

M.features = {
  { id = "cache_small", name = "supply cache", glyph = "=",
    color = P.GOLD + 5, loot_table = "cache_small", reportable = true,
    bounty = 15,
    desc = "A weatherproofed company cache. Yours to open, theirs to count." },

  { id = "cache_ruin", name = "pre-Fracture strongbox", glyph = "=",
    color = P.MAGENTA + 4, loot_table = "cache_ruin", reportable = true,
    bounty = 30,
    desc = "Older than the company. Older than the sky, maybe." },

  { id = "extract_beacon", name = "extraction beacon", glyph = ">",
    color = P.MAGENTA + 5,
    desc = "The company skiff homes on this. Submit your survey here." },
}

-- Loot tables: each entry {item=id, min=, max=, chance=}
M.loot_tables = {
  cache_small = {
    { item = "salvage_copper", min = 2, max = 5, chance = 0.9 },
    { item = "salvage_cable", min = 1, max = 2, chance = 0.5 },
    { item = "preserves_jar", min = 1, max = 3, chance = 0.6 },
    { item = "ledger_page", min = 1, max = 1, chance = 0.3 },
    { item = "tools_surveyor", min = 1, max = 1, chance = 0.15 },
  },
  cache_ruin = {
    { item = "ward_shard", min = 1, max = 2, chance = 0.8 },
    { item = "salvage_cable", min = 1, max = 3, chance = 0.5 },
    { item = "ledger_page", min = 1, max = 2, chance = 0.4 },
  },
}

return M
