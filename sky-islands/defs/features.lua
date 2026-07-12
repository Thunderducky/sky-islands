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

  -- latent features (SI-0003): worth nothing to USE yet — worth money to
  -- REPORT. discover = "sight" (seeing is surveying) or "assay" (stand on
  -- it and do the work: Space). Spawn counts per danger tier live in
  -- economy.danger.latent; weight = relative pick chance.
  --
  -- footprint (SI-0023): the feature occupies a SPLAT of terrain, not one
  -- tile. rows+legend like any prefab, but spaces = outside the mask
  -- (untouched ground — shapes can be rings and crosses). Exactly one
  -- "@" cell: the representative tile that carries the feature entry and
  -- the bounty. Sight discovery fires when ANY mask tile is seen; assay
  -- and Space work from any mask tile.
  { id = "old_factory", short = "factory", name = "old factory", glyph = "&",
    color = P.GRAY + 7, latent = true, discover = "sight", reportable = true,
    bounty = 35, weight = 2,
    footprint = {
      rows = {
        "######",
        "#;;;;#",
        "#;@;;-",
        "######",
      },
      legend = {
        ["#"] = { t = "wall_stone" },
        [";"] = { t = "rubble" },
        ["-"] = { t = "rubble" }, -- the gap where the doors were
        ["@"] = { t = "rubble", rep = true },
      },
    },
    desc = "A pre-Fracture works, seized up mid-shift. The company will want to know." },

  { id = "ore_deposit", short = "ore", name = "ore deposit", glyph = "^",
    color = P.RED + 4, latent = true, discover = "assay", reportable = true,
    bounty = 40, weight = 3,
    footprint = {
      rows = {
        " ; ",
        ";@;",
        " ; ",
      },
      legend = {
        [";"] = { t = "rubble" },
        ["@"] = { t = "rubble", rep = true },
      },
    },
    desc = "Rust-streaked stone. Could be a seam, could be a stain - the soil will say. [Space] assay." },

  { id = "magical_inscription", short = "inscription", name = "magical inscription", glyph = "?",
    color = P.MAGENTA + 5, latent = true, discover = "assay", reportable = true,
    bounty = 45, weight = 1,
    -- deliberately single-tile: one carved stone, easy to walk past
    desc = "Carved lines that hum like the ward-stones do. Reading it properly takes standing still. [Space] study." },

  { id = "freshwater_spring", short = "spring", name = "freshwater spring", glyph = "~",
    color = P.BLUE + 5, latent = true, discover = "sight", reportable = true,
    bounty = 20, weight = 3,
    footprint = {
      rows = {
        "~@",
        "~~",
      },
      legend = {
        ["~"] = { t = "water_shallow" },
        ["@"] = { t = "water_shallow", rep = true },
      },
    },
    desc = "Clean water, rising on its own. The one thing out here nobody has to refine." },

  { id = "grand_ruin", short = "ruin", name = "grand pre-Fracture ruin", glyph = "M",
    color = P.MAGENTA + 4, latent = true, discover = "sight", reportable = true,
    bounty = 50, weight = 1,
    footprint = {
      rows = {
        " ##### ",
        " #;;;# ",
        " ;;@;# ",
        " #;;;# ",
        " ##;## ",
      },
      legend = {
        ["#"] = { t = "wall_stone" },
        [";"] = { t = "rubble" },
        ["@"] = { t = "rubble", rep = true },
      },
    },
    desc = "Architecture from before the sky broke. Bigger inside than the company's whole ledger." },

  -- hub amenities (instances get their containers in world/hubgen.lua)
  { id = "bunk", name = "your bunk", glyph = "8", color = P.TAN + 5,
    desc = "A company bunk, rented weekly. The lockbox under it is yours. [Space] sleep, [g] stash." },

  -- counters/desks are furniture now (SI-0005): the PEOPLE stand beside
  -- them, so the station glyphs stopped pretending to be people
  { id = "trader", name = "store counter", glyph = "]", color = P.GOLD + 5,
    desc = "The Meridian company store counter. They pay you, then they charge you. [Space] trade." },

  { id = "coordinator", name = "contract desk", glyph = "]", color = P.BLUE + 6,
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
