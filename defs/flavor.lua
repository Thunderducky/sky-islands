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
}

return M
