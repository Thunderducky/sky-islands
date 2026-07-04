local P = require("palette")

-- value in credits; the slice economy is: value is everything.
return {
  { id = "salvage_copper", name = "copper fittings", glyph = "$",
    color = P.GOLD + 4, value = 8,
    desc = "Green-crusted fittings. The company smelter takes these by weight." },

  { id = "salvage_cable", name = "sky-cable spool", glyph = "$",
    color = P.GOLD + 3, value = 14,
    desc = "Braided mooring cable. Heavier than it looks." },

  { id = "tools_surveyor", name = "surveyor's level", glyph = "/",
    color = P.BLUE + 5, value = 25,
    desc = "Someone left in a hurry. Still calibrated." },

  { id = "preserves_jar", name = "jar of preserves", glyph = "%",
    color = P.RED + 5, value = 6,
    desc = "Sealed fruit preserves. Pre-Fracture recipe, if the label's honest." },

  { id = "ward_shard", name = "ward-stone shard", glyph = "*",
    color = P.MAGENTA + 5, value = 40,
    desc = "A chip of the stuff that keeps islands up. It hums faintly." },

  { id = "ledger_page", name = "torn ledger page", glyph = "?",
    color = P.GRAY + 8, value = 3,
    desc = "Company accounts in a cramped hand. Someone owed more than you." },
}
