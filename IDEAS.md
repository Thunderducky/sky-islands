# Sky Islands — design notes

> **Distilled into [DESIGN.md](DESIGN.md) (2026-07-04).** This file remains the
> raw ideation log; DESIGN.md is the reviewable document.

Engine: [Usagi](https://usagiengine.com/) (Rust host, Lua 5.5, mlua, Raylib) — stay on PUC Lua, keep web export.
Resolution: `_config()` at 640×360 → 80×30 glyph grid with an 8×12 font.
Project scaffolded at `sky-islands/` (palette.png, palette.lua, main.lua smoke test).

Palette: [Apollo](https://lospec.com/palette-list/apollo) (46 colors) via `palette.png`.
Usagi palettes are any rectangular size (w×h = slot count, row-major, 1-based);
slot 0 = true white, out-of-range = magenta sentinel.

Apollo's structure maps to game semantics almost 1:1 — six 6-step ramps + 10 grays:
- slots 1–6   blues    → sky, water, ice, night
- slots 7–12  greens   → vegetation, poison
- slots 13–18 tans     → earth, wood, skin, parchment
- slots 19–24 golds    → fire, light, sand, treasure
- slots 25–30 reds     → blood, danger, heat
- slots 31–36 magentas → magic, arcane, corruption
- slots 37–46 grays    → stone, metal, smoke, UI chrome

Ramps being 6 deep means field *intensity can be color*: fire intensity 1–6
indexes directly into the gold ramp, scent into greens, etc.

## Theme: Sky Islands
An archipelago of floating islands — the sky is the world's edge.
- **Bounded is diegetic.** Islands have real edges; no invisible walls, just sky.
  Falling is a mechanic. Travel time between islands hides the sim swap.
- **Island = content chunk.** Adding content = adding an island.
- **Wind as a first-class substrate.** A directional field that carries fire,
  smoke, scent, seeds, gliders.
- **Verticality matters** (altitude, climbing, gliding) without CDDA-scale
  z-level plumbing.
- **Travel is a design surface.** Bridges, gliders, ships, wind currents.

## Simulation model (Eric's core design)
Two resolutions, one island active at a time:

- **Active island** (exactly one): full tile-level simulation — substrates,
  fields, creatures, the roguelike part. Travel time between islands masks
  the activation swap; the boundary is open sky, so there's no visible seam.
- **Strategic mode** (inactive islands): a stock-and-flow model. Each island
  compresses to stocks (food store, ore, population…) + flow rates (mine
  output/day, food consumption/day) + discrete events (supply ship arrives,
  stock hits zero, global events). Workers' pathfinding etc. is NOT simulated —
  only daily aggregates.
- **"Compiling"/solving:** trajectories are piecewise-linear, so the strategic
  sim is an event queue, not a tick loop. Solve forward to the next inflection
  point ("food hits 0 on day 12 unless a ship lands"); query state on any date
  by interpolation. Global events invalidate and re-solve from their date.
  Side effect: the game *knows the future* of inactive islands → rumors,
  quest urgency, drama for free.
- **Consistency rule:** flow rates live in the content defs and BOTH sims read
  the same numbers (a `miner` def: eats 1 food/day, mines 2 ore/day — tactical
  spends it via meals/actions, strategic as a rate). One source of truth, so
  the two resolutions can't drift apart. Compress = tally survivors and intact
  buildings, sum their def rates.
- Player tactical actions cross into strategic automatically via the compress
  tally (kill miners / burn the granary → different rates when you leave).

## Claims, discovery, expansion (Eric's core design)
- **Claim system**: islands under a claim get strategic sims; claims are the
  soft cap on how many simulations run. The budget is diegetic — administering
  territory costs something, so the cap reads as a mechanic, not a limit.
- **Discovery flow**: locate island → explorers/surveyors return a rough
  *estimate* of contents → player decides whether an expedition is worth it.
- Estimates can double as generation constraints: the island isn't generated
  until first landing, seeded to match the estimate ± surveyor error. Better
  surveyors = tighter error bars; wrong estimates = the expedition gamble.
- **Abandon / cede**: a claim can be dropped or turned over to another faction.
  Abandoned islands decay (computable lazily on re-entry from time elapsed).
- Simulation LOD ladder: active (tiles) → claimed (stock-flow) →
  known-unclaimed (static estimate) → unknown (not yet generated).

## Architecture sketch (v1 skeleton)
- `substrate.lua` — flat-array tile layers (terrain, fields, scent…), indexed y*w+x
- `defs/` — content tables; `copy_from` inheritance via metatable; defs carry
  both tactical behavior AND strategic flow rates
- `turnloop.lua` — move-point scheduler (active island)
- `strategic.lua` — stock/flow/event-queue sim for claimed islands
- `fov.lua` — recompute only on change
- `dijkstra.lua` — one flow field, all monsters descend it
- First system to prove composition: fire field (spread + heat + materials burning)
- Perf escape hatch if ever needed: native Rust kernels exposed to Lua
  (usagi is public domain), NOT a LuaJIT port (loses 5.5 + web export)

## Fantasy & arc (Eric)
- You are a **fantasy administrator** — but see the two player paths below;
  current shape is more "runner who can scale up into an administrator."
- **Early game**: establish yourself on one island with limited outside help —
  pure tactical roguelike, no claims yet.
- **Mid/late game**: capture/use of other islands — the claim + strategic layer.
- The arc doubles as the dev roadmap: build the one-island tactical game first,
  layer the administrator game on top; playable at every stage.
- No fixed goal for now. Rule of thumb: the world must generate *pressure*
  (rival claims, scarcity, decay, global events) even without a win condition;
  an explicit goal can be added later as content, not architecture.

## Player paths: escape vs. faction work (Eric)
- **Path 1 — individual escape**: accumulate enough wealth to personally get
  out. Debtrunner / STALKER-type playthrough: runs into dangerous places, haul,
  sell, gear up, "one more run."
- **Path 2 — faction work**: contract-like work toward a faction's goal. The
  factions control the megaprojects (they build the ark / run the ritual); the
  rogue is about **shifting the scales** — the marginal actor deciding which
  big slow clock finishes first. Right-sizes the protagonist: you don't build
  the ark, you decide whose ark gets built.
- **Contracts fall out of the strategic sim for free**: faction stock deficits
  ARE contract offers ("hull short 200 timber"). No hand-written quest table —
  query faction event queues, post the gaps as work. Sabotage contracts are the
  same data structure with the sign flipped (dark faction pays to worsen
  someone else's deficit).
- Lean AGAINST a hard mode split: wealth is fungible, so escape vs. investment
  is a per-coin strategic choice inside one system — the tension IS the
  character arc. Escape ticket can literally be passage on the escape faction's
  ark (individual ending still routes through the faction race).
- **Debt as day-one pressure**: you arrive owing (passage debt / bond) — debt
  payments layer under tribute on the same event queue; explains "limited
  outside help" (nobody helps a debtor).
- Likely ladder reconciling runner ↔ administrator: contracts are early income →
  first claim is what a successful runner buys → administration is how you
  fulfill contracts too big to haul on your back.

## Control plane (Eric: "same tech at different levels — it's a control plane issue")
- **Data plane** = the sim (stocks, flows, events, tiles) — runs identically no
  matter who owns what. **Control plane** = a small verb set: commission
  building, post contract, set route, drop claim…
- **Roles are permissions over verbs**, not modes: runner (read + execute
  contracts) → tenant (write access to a PLOT on a host island; rent is a flow)
  → steward (rep unlocks admin verbs on a faction's claim — learn the game on
  their capital) → claimant (full verb set on your own island).
- **Rep system is the keyring** — faction rep unlocks "administrator access."
- **Faction AI is just another control-plane client**: NPC administrators issue
  the same commands through the same API as the player. Build the command layer
  once; player UI, faction AI, scripted events all drive through it.
- Mercenary vs. administrator paths = consuming the contract queue vs.
  producing it. Same market, different permission level.
- The control plane is attackable (scale-shifting, literalized): kill an
  administrator → island stops issuing commands; forge credentials → it issues
  yours.
- Implementation note: ownership must be a tile/building attribute in the
  tactical sim (an ownership substrate) to support plots/tenancy.
- Answers an open question: player is structurally a free agent; faction
  alignment = whose keys you hold.

## Pressure design (Eric)
All pressures are strategic-sim content (stocks, flows, events) — no new machinery:
- **Tribute**: you must return resources to the system to keep existing as a
  claimant. A scheduled event in the queue; scales with holdings → this IS the
  soft claim cap, and whoever collects it IS the "outside."
- **Subsistence**: produce enough to keep your people alive and your claim
  powered — flows must net positive.
- **Morale**: a slow-drifting stock. CAUTION: classic death-spiral ingredient
  (food↓ → morale↓ → production↓). Design exit ramps from day one: recovery
  floors, morale keyed to trajectory not level, cheap interventions (festival).
- **External threats**: stochastic events.
- **End-of-the-world scenario**: one long clock to prepare for. Candidate:
  it's the SAME lore as "why are the islands in the sky" — the mystery and the
  late-game purpose become one thing.
- Timescale layering is deliberate: daily (food) / seasonal (tribute) /
  monthly drift (morale) / irregular shocks (threats) / one long arc
  (apocalypse). There's never a moment when everything is fine.
- Late-game pivot for free: once you could survive without the outside,
  tribute becomes a choice — refusing it is a declaration of independence.

## Factions & the apocalypse (Eric — promising, NOT committed yet)
- **Tribute to the apocalypse itself**, not (only) to a faction: whatever keeps
  the islands aloft is failing, and tribute feeds it. Unifies three questions
  into one lore object: why islands float + what the apocalypse is + what
  tribute is. Nonpayment is visible: wards gutter, islands fall.
- **Factions defined by their answer to the end** (Alpha Centauri-style —
  ideologies, not map colors):
  - Escape faction — building a ship to leave the area
  - Magic faction — working to defeat the magical apocalypse
  - Dark magic faction — wants to control and ACCELERATE it (essential: someone
    must want the fire, or diplomacy goes flat)
- Faction projects are just stocks in their strategic sims ("60% of a hull")
  accumulating via normal flows → conflict over scarce apocalypse-resources
  generates itself; endgame = somebody's clock completes. Goal menu without
  scripting: back a faction's answer or race them all.
- **Shared origin**: all factions date to the creation/Fracture of the sky
  islands. Deeper stories (ideologies are inherited grudges) AND deeper stores
  (pre-Fracture ruins = expedition/archaeology content for the surveyor system).
- Genre note (Eric: drift toward strategy is fine): the hybrid's identity is
  **an administrator with a body** — strategy layer accumulates meaning, but
  interesting problems get solved by a character on tiles. That's what the
  two-resolution sim already builds.

## Open questions
- Are claims symmetric — do factions run the same claim + stock-flow machinery
  (living political map), and does the sim cap count their islands too?
- ~~Is the player a free agent among the factions?~~ Answered by the control
  plane: structurally free; faction alignment = whose keys you hold.
- What exactly does controlling an island give you (resource flows, taxes,
  shipping rights)?
- Active-island size? (previous strawman: ~60×60–100×100 tiles)
- Persistence: one continuous world per save? What does death mean?
- Why are the islands in the sky? — partially answered if tribute-to-apocalypse
  sticks (something holds them up, it's failing, tribute feeds it); the
  specifics of the Fracture still open.
- What lives below the islands / in the open sky?

## Ideation session 2026-07-10 (Eric — mechanics sweep, raw capture)

Post-v1 brainstorm. Wide net of possibly inter-related mechanics; captured
in basic form for later iteration. Grouped, not yet prioritized.

### Economy & items
- **Item differentiation** — current scrap is rudimentary placeholder.
  Differentiate items via the store: sales / periods of higher demand on
  certain items. Gives items identity and a reason to hoard (speculate on
  demand).
- **Farming system** — grow things; another production path alongside
  foraging and salvage.
- **Faction procurement quests** — fulfill quests for different factions,
  e.g. acquire a certain amount of items at different points in time.

### Player progression
- **Equipment** — player can equip different items (slots).
- **Progression = reputation + skills** (clarified in-session): reputation
  is the important one; skills + skill points potentially alongside (same
  idea as the scratchpad entry, not separate).
- **Task-specific reputation** — rep develops around being good at
  particular kinds of work: having/delivering items, exploring, timeliness.
  Rep is a track record per task type, not one global number.

### Ownership & the strategic layer (what freedom is for)
- **Buy your own island** — once free, buy access to an island of your own.
  The original island (Tether/store) remains visitable for trade.
- **Two acquisition modes**: (a) claim a pre-scouted island still full of
  danger — you clear it yourself; (b) buy an existing island outright.
- **Claim levels** — licensing tiers for your personal company. At the
  start you're only licensed to grab unlevelled islands; higher licenses
  unlock better acquisitions later.
- **Island trading** — trade or claim different islands as you grow, e.g.
  swap a mining outpost for a research lab.
- **Island flipping as a playstyle** — specialize in running your own
  search/scouting outfit: find islands, sell them undeveloped, profit on
  the spread.
- **Private stock + cycling** — build up your own private stock on your
  island, while still getting the practice/income of cycling on other
  people's islands (contract work doesn't stop when ownership starts).
- **Building on your island** — construct buildings that help you: e.g. a
  **trade beacon**, your **own store where you set the prices** — opening
  into a whole market system with factions and quests.
- **Blueprints / builds** (later) — island configurations as designable,
  maybe tradeable, artifacts.
- **Hiring** — hire NPCs to do work like scouting islands for you;
  resolved at higher abstraction or in tile-level depth as needed.
- **Play at the altitude you enjoy** — the player can progress world steps
  abstractly or dive in and do specific ones personally; the game supports
  working at whichever level you like most as it progresses.
- **Endgame paths this serves** (ties back to the original doc): delving /
  solving the mystery; adapting new people to the world and stabilizing
  the area; amassing enough wealth to escape; or accelerating it all into
  the void.
- **Eric's flagged hard part**: building the scaffolding that runs through
  all the different layers (tile → island → world/faction).

### World depth & difficulty
- **Difficulty ramp** — more and more difficult areas, with bigger and
  deeper treasures to match.
- **Dungeon islands** — islands with "dungeons" leading deeper underground,
  more intricate things going on inside.
- **Multiple layers / z-levels** — islands aren't just a top surface.
- **Better building generation** — deeper sets of buildings; the current
  generation needs improving to carry the above.

### NPC islands & the trading arc (Eric, late-session)
- **Latent island features** — island features with bonuses the player
  can't exploit yet at this stage: an old factory, an ore deposit, a
  magical inscription. (Valuable later via claims; meanwhile they enrich
  surveys/estimates and what an island is *worth*.)
- **NPC islands** — established islands you can trade with, gated behind
  manumission + a **transfer fee** to travel there. Selected from the
  same place as the contract board/trader. A whole extra trading layer
  built from existing systems.
- **Spatial demand** — different demand at different places (combined
  with demand-over-time = arbitrage between islands).
- **Rumor NPCs** — NPCs whose rumors say a particular established island
  is looking for item X right now. Information as content.
- NPC islands each have their **own features and rarer items** as needed.
- **Ticket out of system (endgame prototype)** — buy a ticket out from
  the correct faction once you find them. Gives: a base prototype of
  faction interaction, a post-manumission goal, and an exit ramp. (The
  escape ending from DESIGN.md, prototyped cheaply.)
- **Stock characters** — a few recurring characters on the NPC islands
  (including the starter island) to start developing character/personality.

### Seeds from the SI-0002 refinement cycle (Eric — future, out of v1 scope)
- **Event chains & branching** — economic events that resolve into
  follow-on events: wiring shortage resolved successfully → bandage
  plenitude (the shuttle got fixed); failed → a subsequent loss.
  Implies player trading can *influence* resolution — your wire sales
  are what fixes the shuttle. Chains/branching explicitly deferred.
- **Unfair stores** — a store "fairness" knob: some stores only buy
  cheap, especially from the indentured. Store personality as a def
  parameter; also a lever for how different NPC islands feel.
- **Gossip/conversation screen** — a talk overlay (transfer-UI-like)
  that delivers event context before trading. First step toward NPC
  conversation generally (stock characters, rumors).
- **Scarcity as absence** — shortages can mean an item is unavailable or
  restock-limited, not merely expensive.
- **Event directors** (Eric) — eventually a "director" chooses events in
  sequence or in response to the player, balancing tension; different
  directors have personalities, fair vs chaotic (à la RimWorld's
  storytellers / Randy Random). v1's weighted picker is the boring
  director; keep selection behind one function so a director can replace
  it. Could later govern more than econ events (visitors, world events).

### SI-0002 continued: draft events + shop expansion (Eric)
- **Shop changes**: greatly expand the store's inventory; offer some
  random stuff for sale each cycle (derived RNG grab bag on restock).
- **Traveling trader** — filed with SI-0005 (visitor checks): the first
  "visitor" the system rolls for.
- **Draft event list** (Eric's, to work off of):
  1. Patrol ship needs supplies for emergency repairs after a pirate
     encounter, plus medical supplies (multi-item demand).
  2. Food shortfall — pays extra for food items (category demand).
  3. Experimental genius — wants random items, provides random items
     (really a stock-character seed → SI-0005).
  4. Medicinal herb overgrowth — surplus (price down, stock up).
  5. Crashed, looted pirate ship — extra odd items in stock, cheap
     (a buying opportunity; events work in both directions).
- **Pirates enter the fiction** — first concrete antagonist, introduced
  as off-screen weather via events before any mechanics exist. Chips at
  the no-antagonist gap; candidate answer to "who threatens holdings"
  later (security-or-rent choice, marker raids…).

### The Conglomerate (Eric, 2026-07-11 — lore seed from event text)
Coined while writing patrol_repairs gossip; tentative but pointed:
- **An alliance of different companies that lay claim to the area** — the
  entity behind the "safe space" from the pressure discussion: the safe
  zones exist because the Conglomerate keeps them that way, and base
  upkeep in one is paying INTO it. Patrol ships are theirs.
- Meridian (the company store / Eric's indenture-holder) would be one
  member company among several — very Gilded Age: trusts above firms.
- Status: thrown out in gossip text, now soft canon; firm up before it
  spreads further through content.
- **Terminology coined alongside it** (2026-07-11 event text, all soft
  canon now):
  - **The Line** — the Conglomerate's patrolled perimeter; the boundary
    of the safe space. Lowercase "the patrol line" in formal speech,
    capital "the Line" in skiff-crew slang — both registers kept.
    Eric (2026-07-11): likes the Line as a FULL PLACE, not just a
    boundary — to explore later (what's stationed on it, living on the
    Line, inside/outside as identity).
  - **The abyss** — what's below the islands, in casual speech ("herbs
    were practically falling into the abyss").
  - **Privateer vs pirate** — Eric confirms the distinction is
    deliberate: privateers raid under charter, implying rival companies
    issue letters of marque. Antagonist ecology implied in one word;
    connects to the no-antagonist gap and pirate-as-weather events.
  - **The Conglomerate core** (Eric, 2026-07-12, via SI-0005 visitor
    "tourist from the Conglomerate core") — the Conglomerate has a HOME
    region, which makes the Tether a frontier. Tourists implies the
    core is safe, rich, and curious about the edge. Where escape
    tickets, refined goods, and eventually the player's story of
    "getting out" point toward — or away from.

### Writing principle: gossip shows, UI states (Eric, 2026-07-11)
From the patrol_repairs text review: gossip lines stay flavorful and
PARTIAL — indirect evidence ("quartermaster tried to buy our whole
medicine cabinet"), not announcements. The transfer UI's demand markers
and counter line are the explicit backstop. The player should feel
clever putting two and two together, not read a bulletin. Applies to
future gossip/rumor/NPC text.

### The two-pass plan (Eric, end of session — actioned into tasks/)
Session output crystallized into two sequenced passes:
- **First Freedom pass** — the trading arc above, plus: the travel-broker
  character is **visible at the Tether while you're still indentured**,
  just unavailable to you (the locked door you see before you have the
  key). Later option: start free, with the indenture as tutorial mode.
  **Visitor checks**: each island visit, roll whether visitors / named
  characters are present and what they're low on — *random for now,
  replaced by the real economic sim later* (stub the interface, upgrade
  the implementation). **Decorated interiors**: room insides are boring
  next to the exteriors; fix via prefab room components dropped onto
  islands for texture.
- **Bigger World pass** (after First Freedom): deeper dungeons, z-levels,
  hallways — the world-depth bucket, deliberately second.

### Discovery, tracking & the nebula
- **Terminology (clarifies "unlevelled")**: unlevelled islands ≈ islands
  we're not super familiar with — familiarity/knowledge-based, not a
  development tier.
- **Scanning system** — islands are *detected*, not simply seen.
- **The nebula** — islands sit in some nebula-like medium that prevents
  them from being easily found and kept track of.
- **Tracking is a budgeted resource** — keeping track of where an island
  is (given its trajectory) costs something limited: "compute" (or an
  in-fiction analog), or signal strength. Everyone — player and factions —
  has a finite tracking budget.
- **Islands erode / regenerate** — something strange about islands causes
  them to erode or be regenerated over time: the story reason the game
  doesn't have to keep track of all of them all the time.
- **Markers** — a faction keeps an island by placing a marker; markers are
  in limited supply. Holding territory = spending a scarce physical token.
- **Ships** — eventually need ships moving between marked islands, though
  Eric suspects they won't be the game's primary focus.

### Pressure as modular systems (Eric — "let's look at these first")
Framing: build pressure to exist in modular ways, at different layers;
customize how players interact with them. Three forms so far:
1. **Survival pressure** — the character's body. Hunger (built) is the
   template; HP and progression belong here; add **stamina and fatigue**
   as future knobs.
2. **Economic pressure** — starts as the indenture debt (built). Later:
   base upkeep — if your island is in a "safe" area you pay the faction
   that keeps it safe; strike out on your own and you either pay a
   security force or manage defenses yourself.
3. **Existential pressure** — the cataclysm getting worse; ticking clock
   to fix / stabilize / escape the sector (per DESIGN.md).

- **Tunable emphasis** — imagine modes/mods where one pressure dominates;
  some players want pressure low. A "safe space" playstyle: enjoy
  contracts, uncover mysteries and content, never touch the macro level —
  or opt all the way in.
- **Role playthroughs** — non-traditional roguelike runs where this
  playthrough is about being a trader, researcher, detective… "A little
  of everything if you want it to be, but we have a simulation we can put
  you into."
- **Hardest part (Eric)**: integrating a narrative.

### "Jerrymapping" (Eric — aesthetic north star, tentative)
Add small little parts, tinker, and it grows — new stuff happens, it can
affect the save, but it's about making small things that become a larger
whole. Offered with "don't know if that's a great idea or not."
Clarified in-session: meant primarily as a **dev-side** aesthetic (how the
project grows), not a player promise.

### Character stable (Eric — "fairly ambitious, just a thought")
- The player develops a **series of characters in the same world**. Not
  connected in-fiction (not the same org) — they just belong to the
  player. The only true connections: the shared world and the apocalypse
  clock.
- You could theoretically **go find your other character** in-world.
- **Parking**: leave a character in a "status quo" state — quietly on a
  ship or island doing their own thing — and jump back into them later.
- Touches the standing open question: persistence / what death means /
  "new debtor in the same living world."

### Gaps noted (Claude, on Eric's prompt — ranked)
Eric's framing: the game is the high-level economic sim + low-level
roguelike sim and their mixing, plus light narrative/storylets; worry is
being not-enough of one or the other.
1. **No people** — zero named characters in the whole design; every actor
   is an institution. Rep, hiring, trading, and storylets all silently
   assume individuals exist. Named NPCs serve both sims at once.
2. **Storylets unmechanized** — named as a core third element, but no
   trigger model or content format designed. Flavor pools are a seed
   (color, not story).
3. **No antagonist** — all pressure is ambient (tribute/hunger/shocks);
   nothing *wants* the player's holdings. Limited markers + finite
   tracking + flipping beg for a rival outfit racing for the same scarce
   things (the old employer is the obvious candidate).
4. **Tactical layer isn't sky-native** — falling/edge/wind/nebula have no
   tile-level mechanics; the generic-roguelike ideas (dungeons, z-levels)
   point away from the game's own signature fiction.
Balance note: the identity lives at the joints (survey-as-compress); gaps
1 and 3 rank highest because people and rivals exist at both layers.

### Guardrails & tone (Eric)
- Don't just copy existing roguelikes / over-develop those arenas — the
  strategic layer must keep developing in parallel, especially since the
  greater faction layer + system governs the overall story.
- Tone: **Gilded Age industrial titans × Bastion** — big companies at play,
  but not quite cyberpunk or steampunk.
