-- People (SI-0005). One self-contained table per character; sim/npcs.lua
-- populates the Tether from these (fixed cast always present, visitors
-- rolled per cycle from (master, "visitors:<cycle>")).
--
-- Authoring guide:
--   id, title    title is what the player sees ("the store runner") —
--                names arrive with the name generator (SI-0025)
--   glyph/color  map appearance (NPCs are solid; bump = blocked, T = talk)
--   fixed        true = always at the Tether at their spot (hubgen map
--                chars "1" store_runner, "2" quest_broker)
--   visitor      true = rolled onto a dock berth each cycle
--   visit_on_event  econ event id; while that event is active this
--                visitor is near-certain to be in (economy.npcs knobs)
--   trade        true = conversation offers a trade option
--   stock_table  loot-table-shaped roll for what they're carrying
--   slots        their container cap (small on purpose: visitors are
--                texture and opportunity, not a second store)
--   conversation v1 format, DELIBERATELY minimal (no conditions, no
--                trees — this pass proves the system):
--     greeting        what they say when you [T]alk
--     greeting_free   optional override once the indenture is cleared
--     topics          flat list of { label, text } — pick one, read the
--                     reply, back to the menu
--     (trade option and "goodbye" are added automatically)
--
-- ALL conversation TEXT BELOW IS STUB TEXT (Claude) — Eric rewrites.

return {
  {
    id = "store_runner",
    title = "the store runner",
    glyph = "R", color = require("palette").GOLD + 6,
    -- trade_store: her (trade) opens the island's trader COUNTER (real
    -- stock, market prices) — she runs the store, she doesn't carry it
    fixed = true, trade = false, trade_store = true,
    conversation = {
      -- STUB TEXT
      greeting = "Counter's open. Coin goes in the drawer, goods go in your pack, complaints go in the abyss.",
      greeting_free = "Well, look who owns their own boots now. Counter's still open.",
      topics = {
        { label = "The Tether", text = "Rope-creak and lamp oil, same as every day. The company owns the planks; we just walk on them." },
        { label = "Business", text = "Prices are what the ledger says. You want sentiment, the coordinator does a nice line in danger reports." },
        { label = "The store", text = "If it fits on a shelf, I'll sell it. If it fits in your pack, I'll buy it. Simple as weather." },
      },
    },
  },

  {
    id = "quest_broker",
    title = "the quest broker",
    glyph = "B", color = require("palette").BLUE + 6,
    fixed = true, trade = false,
    conversation = {
      -- STUB TEXT
      greeting = "Contracts are on the board. Fees are set, danger's estimated - loosely - and the skiff leaves when you do.",
      greeting_free = "The veteran board's yours now. Better islands, better fees, worse company out there. Suits you.",
      topics = {
        { label = "The contracts", text = "Survey work. Walk it, mark it, report it. The company pays for what you know, not what you did to know it." },
        { label = "Danger reports", text = "Best guesses from the last soul who flew over. When the board says CALM, pack a bandage anyway." },
        { label = "The veteran board", text = "Clear your account and we'll talk about the deep-sky charters. Company rule, not mine." },
      },
    },
  },

  {
    id = "quartermaster",
    title = "a ship's quartermaster",
    glyph = "Q", color = require("palette").RED + 5,
    visitor = true, visit_on_event = "patrol_repairs",
    trade = true, slots = 4,
    stock_table = {
      { item = "sealant_tin", min = 1, max = 2, chance = 0.7 },
      { item = "insulated_wiring", min = 1, max = 3, chance = 0.7 },
      { item = "ration_pack", min = 1, max = 2, chance = 0.4 },
    },
    conversation = {
      -- STUB TEXT
      greeting = "You the local hauler? I'm buying plate and gauze at ship's rates, which is to say: fast and unfairly.",
      topics = {
        { label = "Your ship", text = "She flies, mostly. Out past the Line everything bites, and the hull remembers every tooth." },
        { label = "The patrol", text = "Conglomerate pays us to draw a line in the sky and dare things to cross it. Some weeks the sky dares back." },
      },
    },
  },

  {
    id = "core_tourist",
    title = "a tourist from the Core",
    glyph = "C", color = require("palette").MAGENTA + 6,
    visitor = true, trade = true, slots = 3,
    stock_table = {
      { item = "preserves_jar", min = 1, max = 2, chance = 0.6 },
      { item = "bandage", min = 1, max = 1, chance = 0.4 },
      { item = "ledger_page", min = 1, max = 2, chance = 0.3 },
    },
    conversation = {
      -- STUB TEXT
      greeting = "Oh! A real surveyor. Do you actually FALL if you step off the edge? Marvelous. Terrifying. Marvelous.",
      topics = {
        { label = "The Core", text = "Lit streets, three meals, nobody owes anybody their own hands. You'd hate it. Everyone here says they'd hate it. Loudly. Repeatedly." },
        { label = "Why visit?", text = "The brochures said 'the frontier as it truly is.' The brochures did not mention the smell of lamp oil. I'm keeping the brochure as evidence." },
      },
    },
  },

  {
    id = "wildlife_researcher",
    title = "a wildlife researcher",
    glyph = "W", color = require("palette").GREEN + 6,
    visitor = true, trade = false,
    conversation = {
      -- STUB TEXT
      greeting = "Shh - no, sorry, habit. You can't startle a dust-hen from here. Probably. What do you need?",
      topics = {
        { label = "The fauna", text = "Everything out here evolved for wind and want. The shrikes ride thermals off the island rims. Beautiful. Don't let one near your eyes." },
        { label = "The wardens", text = "Not fauna. Not flora. They predate the Fracture and they patrol like they're still being paid. Whoever built them had budgets I can only dream of." },
      },
    },
  },
}
