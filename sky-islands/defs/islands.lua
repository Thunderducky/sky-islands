-- Hand-authored mission islands. Same authorship rules as the hub
-- (world/hubgen.lua): rows all equal width, legend chars are authoring
-- symbols unrelated to display glyphs, every char must be in the legend.
-- Extra legend powers over the hub's: `loot` puts explicit contents in a
-- feature (caches); a LATENT char marks the feature's REP tile — if its
-- def has a footprint, world/authored.lua stamps the whole splat around
-- that point (leave clearance in the art; out-of-bounds fails loudly).
-- Every island needs exactly one extract_beacon (it's also the start).
-- `npcs` seats people (defs/npcs.lua) at fixed spots; traders need
-- explicit `stock` (authored islands roll no dice).
--
-- Loaded via debugflags `force_level = "<id>"` for now (direct start +
-- board pin); real authored destinations (NPC islands, SI-0006) will
-- use the same format.
return {
  {
    id = "proving_grounds",
    name = "Proving Grounds",
    danger = 1,
    creatures = {
      { def = "dust_hen", x = 12, y = 10 },
      { def = "thorn_hog", x = 33, y = 18 },
    },
    -- the whole cast, for conversation/trade testing without hub trips.
    -- traders get explicit stock (authored islands roll no dice).
    npcs = {
      { def = "store_runner", x = 14, y = 10 },
      { def = "quest_broker", x = 16, y = 10 },
      { def = "quartermaster", x = 18, y = 12,
        stock = { { id = "sealant_tin", n = 2 },
                  { id = "insulated_wiring", n = 3 } } },
      { def = "core_tourist", x = 26, y = 10,
        stock = { { id = "preserves_jar", n = 2 } } },
      { def = "wildlife_researcher", x = 26, y = 17 },
    },
    map = {
      "                                        ",
      "                                        ",
      "     ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,     ",
      "    ########,,T,,,,,,,,,,,,,,,,,,,,     ",
      "    #------#,,,,,,,,,,,,,,,~,,,,,,,     ",
      "  ,,#-c----#,,,,,,,,,,,,,,,,,,,,,,T,,,  ",
      "  ,,#------#,,,,,,,,,,,,,,,,,,,,,,,,,,  ",
      "  ,,####+###,,,,,,,,o,,,,,,,,,,,,,,,,,  ",
      "  ,,,,.........................,,,,,T,  ",
      "  ,,,,.........................,,,,,,,  ",
      "  ,,,,.......R.................,,,,,,,  ",
      "  ,,,,.........................,,,,,,,  ",
      "  ,,,,................**.......M,,,,,,  ",
      "  ,,,,.........................,,,,,,,  ",
      "  ,,,,.........................,,,,,,,  ",
      "  ,,,,....F....................,,,,,,,  ",
      "  ,*,,..................e......,,,,,,,  ",
      "  ,,,,.........................,,,,,,,  ",
      "  ,,,,.........................,,,,,,,  ",
      "     \",,,,,,,,,,?,,,,,,,,,,,,,,,,,,     ",
      "     ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,     ",
      "     ,,,,,,,,,,,,,,B,,,,,,,,,,,,,,,     ",
      "                                        ",
      "                                        ",
    },
    legend = {
      [" "] = { t = "sky" },
      [","] = { t = "grass" },
      ["\""] = { t = "grass_tall" },
      ["."] = { t = "dirt" },
      ["T"] = { t = "tree" },
      ["*"] = { t = "bush" },
      ["#"] = { t = "wall_plank" },
      ["-"] = { t = "floor_planks" },
      ["+"] = { t = "door_closed" },
      ["B"] = { t = "grass", f = "extract_beacon" },
      ["~"] = { t = "grass", f = "freshwater_spring" },
      ["o"] = { t = "grass", f = "ore_deposit" },
      ["F"] = { t = "dirt", f = "old_factory" },
      ["?"] = { t = "grass", f = "magical_inscription" },
      ["M"] = { t = "grass", f = "grand_ruin" },
      ["R"] = { t = "dirt", f = "trader",
        loot = { { id = "ration_pack", n = 4 }, { id = "bandage", n = 2 },
                 { id = "hull_plate", n = 2 } } },
      ["c"] = { t = "floor_planks", f = "cache_small",
        loot = { { id = "salvage_copper", n = 4 },
                 { id = "insulated_wiring", n = 2 } } },
      ["e"] = { t = "dirt", f = "cache_small", loot = {} },
    },
  },
}
