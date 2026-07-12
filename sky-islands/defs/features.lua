local P = require("palette")

local M = {}

M.features = {
  { id = "cache_small", name = "supply cache", glyph = "=",
    color = P.GOLD + 5, loot_table = "cache_small", reportable = true,
    bounty = 15, slots = 10,
    desc = "A weatherproofed company cache. Yours to open, theirs to count." },

  { id = "cache_ruin", name = "pre-Fracture strongbox", glyph = "=",
    color = P.MAGENTA + 4, loot_table = "cache_ruin", reportable = true,
    bounty = 30, slots = 6,
    desc = "Older than the company. Older than the sky, maybe." },

  { id = "extract_beacon", name = "extraction beacon", glyph = ">",
    color = P.MAGENTA + 5,
    desc = "The company skiff homes on this. Submit your survey here." },

  -- forage: one-way containers — you can take, you can't stow. The bush
  -- declines your donations. Emptied instances are removed, leaving the
  -- plain bush terrain underneath. (Future: regrowth on a day clock;
  -- crafting berries into preserves.)
  { id = "forage_berries", name = "berry bush", glyph = "%",
    color = P.MAGENTA + 4, take_only = true,
    desc = "A bush heavy with skyberries. Free food - don't tell the store." },

  -- hub amenities (instances get their containers in world/hubgen.lua)
  { id = "bunk", name = "your bunk", glyph = "8", color = P.TAN + 5,
    desc = "A company bunk, rented weekly. The lockbox under it is yours. [Space] sleep, [g] stash." },

  { id = "trader", name = "company store", glyph = "@", color = P.GOLD + 5,
    desc = "The Meridian company store. They pay you, then they charge you. [Space] trade." },

  { id = "coordinator", name = "mission coordinator", glyph = "@", color = P.BLUE + 6,
    desc = "The coordinator's desk: survey contracts, posted and priced. [Space] browse." },

  { id = "skiff_dock", name = "skiff dock", glyph = ">", color = P.MAGENTA + 5,
    desc = "Your leased skiff, moored to the jetty. Its hold carries what you can't. [g] hold." },
}

-- Loot tables: each entry {item=id, min=, max=, chance=}
M.loot_tables = {
  cache_small = {
    { item = "salvage_copper", min = 2, max = 5, chance = 0.9 },
    { item = "salvage_cable", min = 1, max = 2, chance = 0.5 },
    { item = "preserves_jar", min = 1, max = 3, chance = 0.6 },
    { item = "bandage", min = 1, max = 2, chance = 0.3 },
    { item = "ledger_page", min = 1, max = 1, chance = 0.3 },
    { item = "tools_surveyor", min = 1, max = 1, chance = 0.15 },
    { item = "insulated_wiring", min = 1, max = 3, chance = 0.4 },
    { item = "sealant_tin", min = 1, max = 2, chance = 0.3 },
    { item = "hull_plate", min = 1, max = 2, chance = 0.25 },
  },
  cache_ruin = {
    { item = "ward_shard", min = 1, max = 2, chance = 0.8 },
    { item = "salvage_cable", min = 1, max = 3, chance = 0.5 },
    { item = "ledger_page", min = 1, max = 2, chance = 0.4 },
    { item = "hull_plate", min = 1, max = 3, chance = 0.4 },
  },
}

return M
