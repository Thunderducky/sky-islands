-- Economic events: multi-cycle market stories at the company store.
-- One self-contained table per event; sim/market.lua runs them.
--
-- Authoring guide (all text is yours to write, no code knowledge needed):
--   id        unique key (used in saves — renaming orphans old saves' state)
--   name      shown in the store UI while active
--   weight    relative pick chance vs other eligible events
--   duration  {min, max} cycles, rolled once when the event starts
--   cooldown  cycles after the event ends before it can fire again
--   min_cycle earliest cycle it may first appear
--   effects   list of { match, demand, restock_mult }
--     match        { id = "item_id" } for one item, or
--                  { has = "field" } for every item with that def field
--                  ("nutrition" = all food, "heal" = all medical)
--     demand       "glut" | "low" | "high" | "critical" — price levels;
--                  the actual numbers live in defs/economy.lua demand_levels
--     restock_mult scales how much of it the store stocks (0 = none,
--                  3 = triple); omit for "stock as usual"
--   add_stock  extra goods dumped into the store while active; same
--              {item, min, max, chance} shape as loot tables
--   gossip     what the shopkeeper says (one line picked per visit);
--              shown once when the event is news
--   log        one-line message-log announcement when the event starts
--
return {
  {
    id = "patrol_repairs",
    name = "patrol ship in for repairs",
    weight = 2, duration = { 2, 3 }, cooldown = 4, min_cycle = 2,
    effects = {
      { match = { id = "hull_plate" }, demand = "critical" },
      { match = { id = "sealant_tin" }, demand = "high" },
      { match = { id = "insulated_wiring" }, demand = "high" },
      { match = { has = "heal" }, demand = "high", restock_mult = 0.25 },
    },
    gossip = {
      "One of the Conglomerate's patrol skiffs limped in this morning. She had found more trouble than she was expecting. This might be an opportunity for you if you have any spare plate, sealant or gauze. They're desperate.",
      "Quartermaster was in here earlier, practically tried to buy our whole medicine cabinet. Looks like they ran into trouble out there."
    },
    log = "A mauled Conglomerate patrol ship is parked nearby, barely flying, crew and hull desperate for repair.",
  },

  {
    id = "food_shortfall",
    name = "food shortfall",
    weight = 2, duration = { 2, 4 }, cooldown = 4, min_cycle = 2,
    effects = {
      { match = { has = "nutrition" }, demand = "high", restock_mult = 0.5 },
    },
    gossip = {
      "Supply ship run came up short. We're having to tighten our belts and some folks ain't taking too kindly to it.",
      "Freighter skipped the Tether. Rations are thin and the store pays well for anything with calories in it.",
    },
    log = "Food is short at the Tether; edibles fetch a premium.",
  },

  {
    id = "herb_overgrowth",
    name = "medicinal herb overgrowth",
    weight = 1, duration = { 2, 3 }, cooldown = 5, min_cycle = 2,
    effects = {
      { match = { id = "medicinal_herbs" }, demand = "glut", restock_mult = 3 },
    },
    gossip = {
      "Some islet bloomed overnight - herbs were practically falling into the abyss. We don't have the space for it all, and we're willing to cut you a deal",
      "Every forager on the Line came back stinking of sap. Herbs are cheaper than ballast right now.",
    },
    log = "A herb glut has cratered prices at the store.",
  },

  {
    id = "pirate_crash",
    name = "crashed pirate ship",
    weight = 1, duration = { 1, 2 }, cooldown = 6, min_cycle = 3,
    effects = {
      { match = { id = "salvage_cable" }, demand = "glut" },
      { match = { id = "insulated_wiring" }, demand = "glut" },
      { match = { id = "hull_plate" }, demand = "glut" },
    },
    add_stock = {
      { item = "salvage_cable", min = 2, max = 4, chance = 1 },
      { item = "insulated_wiring", min = 2, max = 5, chance = 0.8 },
      { item = "hull_plate", min = 1, max = 3, chance = 0.8 },
      { item = "ward_shard", min = 1, max = 1, chance = 0.3 },
      { item = "ledger_page", min = 1, max = 3, chance = 0.5 },
    },
    gossip = {
      "Privateer wreck came down inside the patrol line. Salvage crews picked her apart before sundown. If you're looking for a deal on what they found we can be extremely.... reasonable",
      "Some pack of jackasses crashed their ship inside the Line. Lucky you! Cheap cable, cheap plate, and the serial numbers filed off for free!",
    },
    log = "A crashed privateer wreck means the store is flooded with salvaged cheap goods.",
  },
}
