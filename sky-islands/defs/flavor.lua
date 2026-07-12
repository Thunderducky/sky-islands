local P = require("palette")

-- Narration pools. {slot} names are filled by flavor.emit(event, slots).
-- Add lines freely; the picker avoids repeating the last one used.
local M = {}

M.events = {
  game_start = {
    color = P.BLUE + 5,
    templates = {
      "The skiff banks away and is gone. Just you, the wind, and {island}.",
      "The company skiff dumps you at the beacon and doesn't wave. {island} awaits its survey.",
    },
  },
  cache_open = {
    color = P.GOLD + 5,
    templates = {
      "You pry the {feature} open - {contents}.",
      "The {feature}'s seal gives with a hiss. Inside: {contents}.",
      "You work the {feature} open. {contents}. Not bad.",
    },
  },
  cache_empty = {
    color = P.GRAY + 7,
    templates = {
      "You pry the {feature} open - empty. Someone got here first.",
      "The {feature} is bare inside. The report will note it anyway.",
    },
  },
  pickup = {
    color = P.GOLD + 4,
    templates = {
      "You take {items}.",
      "{items} - stowed.",
    },
  },
  hub_arrive = {
    color = P.BLUE + 5,
    templates = {
      "The Tether. Rope-creak, lamp oil, and the company's prices. Home, for a debtor's value of home.",
      "The skiff noses into its dock at The Tether. The ledger, no doubt, has already been updated.",
    },
  },
  sleep = {
    color = P.BLUE + 6,
    templates = {
      "You sleep. The Tether sways on its moorings, and the debt collects its interest in dreams. (Saved.)",
      "Lights out in the bunkhouse. Tomorrow the sky again. (Saved.)",
    },
  },
  buy = {
    color = P.GOLD + 5,
    templates = {
      "{items}, for {cost}c of your hard-fallen credits.",
      "The clerk wraps {items}. {cost}c, billed with a smile.",
    },
  },
  sell = {
    color = P.GOLD + 5,
    templates = {
      "The clerk weighs {items} and counts out {earned}c.",
      "{items} across the counter; {earned}c back. The margin is theirs, always.",
    },
  },
  debt_pay = {
    color = P.GREEN + 5,
    templates = {
      "{paid}c against the indenture. {debt}c between you and the open sky.",
    },
  },
  no_debt = {
    color = P.GREEN + 5,
    templates = {
      "You owe nothing. The clerk looks almost disappointed.",
    },
  },
  manumitted = {
    color = P.GREEN + 6,
    templates = {
      "Paid. In. Full.",
    },
  },
  reindentured = {
    color = P.RED + 5,
    templates = {
      "The retrieval bill reopens your account. The company welcomes you back to the fold.",
    },
  },
  broke = {
    color = P.RED + 5,
    templates = {
      "Your pockets disagree with your ambitions.",
      "Not enough credits. The clerk's sympathy is not company policy.",
    },
  },
  -- combat
  hit = {
    color = P.RED + 5,
    templates = {
      "You strike the {name} ({dmg}).",
      "You catch the {name} solidly ({dmg}).",
    },
  },
  miss = {
    color = P.GRAY + 7,
    templates = {
      "You swing at the {name} and find only air.",
      "The {name} slips your swing.",
    },
  },
  kill = {
    color = P.GOLD + 5,
    templates = {
      "The {name} drops and does not get up.",
      "Down goes the {name}.",
    },
  },
  creature_hit = {
    color = P.RED + 5,
    templates = {
      "The {name} tears at you ({dmg}).",
      "The {name} connects ({dmg}). That one will bruise.",
    },
  },
  creature_miss = {
    color = P.GRAY + 7,
    templates = {
      "The {name} lunges and misses.",
    },
  },
  creature_notice = {
    color = P.RED + 4,
    templates = {
      "The {name} takes notice of you.",
      "The {name}'s head snaps your way.",
    },
  },
  bandage = {
    color = P.GREEN + 5,
    templates = {
      "You bind your wounds. Good as billed.",
    },
  },
  not_hurt = {
    color = P.GRAY + 7,
    templates = { "You're in one piece. Save it." },
  },
  not_usable = {
    color = P.GRAY + 7,
    templates = { "You consider using the {item}. You reconsider." },
  },
  eat = {
    color = P.GREEN + 5,
    templates = {
      "You eat the {item}. Better.",
      "The {item} goes down. The sky seems less far away.",
    },
  },
  not_edible = {
    color = P.GRAY + 7,
    templates = {
      "You consider eating the {item}. You reconsider.",
    },
  },
  hunger_peckish = {
    color = P.GOLD + 4,
    templates = {
      "Your stomach files a preliminary complaint.",
    },
  },
  hunger_hungry = {
    color = P.RED + 4,
    templates = {
      "Properly hungry now. The company sells rations, of course.",
      "Hunger sets in. Out here, nobody bills you for an appetite - yet.",
    },
  },
  hunger_starving = {
    color = P.RED + 5,
    templates = {
      "You are starving. Eat something, debtor - collapse gets billed.",
    },
  },
  rescued = {
    color = P.RED + 5,
    templates = {
      "Retrieved, stabilized, and billed: {fee}c. The indenture stands at {debt}c.",
    },
  },
  stow = {
    color = P.GOLD + 4,
    templates = {
      "{items} - into {where}.",
      "You stow {items} in {where}.",
    },
  },
  no_room = {
    color = P.RED + 5,
    templates = {
      "No room in your pack. Something has to stay behind.",
      "Your pack is full. The company would call this a good problem.",
    },
  },
  cant_stow = {
    color = P.GRAY + 7,
    templates = {
      "{where} takes no deposits.",
      "You can't put that back.",
    },
  },
  no_room_there = {
    color = P.RED + 5,
    templates = {
      "{where} is packed tight. Nothing more fits.",
    },
  },
  door_open = {
    color = P.TAN + 5,
    templates = {
      "The door swings open, complaining.",
      "You shoulder the door open.",
      "The hinges shriek. So much for quiet.",
    },
  },
  door_close = {
    color = P.TAN + 5,
    templates = { "You pull the door shut." },
  },
  sky_blocked = {
    color = P.BLUE + 4,
    templates = {
      "The ground simply stops. Below: sky, and more sky.",
      "One more step and the company writes off its investment.",
      "Wind comes UP at you here. You keep back from the edge.",
    },
  },
  first_sky_edge = {
    color = P.BLUE + 5,
    templates = {
      "You reach the island's rim. The world ends in a ragged line of grass and then - nothing, all the way down.",
    },
  },
  first_building = {
    color = P.TAN + 5,
    templates = {
      "A structure - someone lived out here, before the company bought the sky from under them.",
    },
  },
  submit_hint = {
    color = P.MAGENTA + 5,
    templates = {
      "The beacon thrums underfoot. [Space] transmits your survey and calls the skiff.",
    },
  },
  nothing_here = {
    color = P.GRAY + 6,
    templates = { "Nothing here worth the ink." },
  },
  wait = {
    color = P.GRAY + 6,
    templates = {
      "You listen to the wind for a moment.",
      "You wait. Somewhere below, clouds are doing the same.",
    },
  },
  -- market events (defs/econ_events.lua): {line} is the event's own log
  -- text, so the def stays the single place its words live
  market_news = {
    color = P.GOLD + 5,
    templates = { "{line}" },
  },
  market_settled = {
    color = P.GRAY + 7,
    templates = {
      "Counter talk moves on; prices settle back to company standard.",
      "The {name} is old news. The ledger returns to its usual appetite.",
    },
  },
}

return M
