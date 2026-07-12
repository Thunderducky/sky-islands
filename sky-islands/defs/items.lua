local P = require("palette")

-- value in credits; the slice economy is: value is everything.
return {
  { id = "salvage_copper", name = "copper fittings", glyph = "$",
    color = P.GOLD + 4, value = 8, max_stack = 10,
    desc = "Green-crusted fittings. The company smelter takes these by weight." },

  { id = "salvage_cable", name = "sky-cable spool", glyph = "$",
    color = P.GOLD + 3, value = 14, max_stack = 4,
    desc = "Braided mooring cable. Heavier than it looks." },

  { id = "tools_surveyor", name = "surveyor's level", glyph = "/",
    color = P.BLUE + 5, value = 25, max_stack = 1,
    desc = "Someone left in a hurry. Still calibrated." },

  { id = "preserves_jar", name = "jar of preserves", glyph = "%", nutrition = 120,
    color = P.RED + 5, value = 6, max_stack = 6,
    desc = "Sealed fruit preserves. Pre-Fracture recipe, if the label's honest." },

  { id = "ward_shard", name = "ward-stone shard", glyph = "*",
    color = P.MAGENTA + 5, value = 40, max_stack = 3,
    desc = "A chip of the stuff that keeps islands up. It hums faintly." },

  { id = "ration_pack", name = "company ration", glyph = "%", nutrition = 250,
    color = P.TAN + 5, value = 10, max_stack = 8,
    desc = "Dense, joyless, keeps forever. The wrapper bills your account number." },

  { id = "berries", name = "skyberries", glyph = "%", nutrition = 60,
    color = P.MAGENTA + 4, value = 2, max_stack = 10,
    desc = "Tart, wind-hardy berries. The one meal out here the company can't invoice." },

  { id = "game_meat", name = "game meat", glyph = ":", nutrition = 180,
    color = P.RED + 4, value = 6, max_stack = 5,
    desc = "Fresh kill, honestly earned. The one protein the company didn't sell you." },

  { id = "bandage", name = "bandage roll", glyph = "+", heal = 8,
    color = P.GRAY + 9, value = 15, max_stack = 5,
    desc = "Company-issue gauze. The wrapper reminds you injuries are billable." },

  { id = "ledger_page", name = "torn ledger page", glyph = "?",
    color = P.GRAY + 8, value = 3, max_stack = 10,
    desc = "Company accounts in a cramped hand. Someone owed more than you." },

  -- trade goods with market-event hooks (SI-0002)
  { id = "hull_plate", name = "hull plate", glyph = "$",
    color = P.GRAY + 8, value = 18, max_stack = 4,
    desc = "Rolled skyship skin, company gauge. Dents ship free of charge." },

  { id = "sealant_tin", name = "tin of sealant", glyph = "$",
    color = P.TAN + 4, value = 12, max_stack = 6,
    desc = "Pitch-black, airtight, eats brushes. The lid warns: not for internal use." },

  { id = "insulated_wiring", name = "insulated wiring", glyph = "$",
    color = P.RED + 3, value = 10, max_stack = 8,
    desc = "Copper core, cloth jacket. Half the sky runs on this; the other half wants it." },

  { id = "medicinal_herbs", name = "medicinal herbs", glyph = "%", heal = 3,
    color = P.GREEN + 5, value = 9, max_stack = 8,
    desc = "Bitter leaves the sawbones swears by. Not billable - yet." },
}
