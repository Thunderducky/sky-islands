-- Hand-authored mission islands. Same authorship rules as the hub
-- (world/hubgen.lua): rows all equal width, legend chars are authoring
-- symbols unrelated to display glyphs, every char must be in the legend.
-- Extra legend powers over the hub's: `loot` puts explicit contents in a
-- feature (caches); a LATENT char marks the feature's REP tile — if its
-- def has a footprint, world/authored.lua stamps the whole splat around
-- that point (leave clearance in the art; out-of-bounds fails loudly).
-- Every island needs exactly one extract_beacon (it's also the start).
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
      "  ,,,,.........................,,,,,,,  ",
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
      ["c"] = { t = "floor_planks", f = "cache_small",
        loot = { { id = "salvage_copper", n = 4 },
                 { id = "insulated_wiring", n = 2 } } },
      ["e"] = { t = "dirt", f = "cache_small", loot = {} },
    },
  },
}
