# Sky Islands — Design Document

*Draft for review — 2026-07-04. Distilled from IDEAS.md (the running ideation
log). Each section is tagged: **[settled]** agreed in discussion, **[leaning]**
direction chosen but details open, **[proposed]** Claude's proposal awaiting
Eric's call.*

## Pitch

A grid-based ASCII roguelike / strategy hybrid. You arrive in a fractured
archipelago of floating islands, in debt, with nothing. The islands are kept
aloft by something that is failing, and everyone who lives here is organized
around an answer to that fact. You run contracts, claim land, administer
islands, and put your thumb on the scale of which ending the world gets —
or just get rich enough to buy your way out before it happens.

**You are an administrator with a body**: the strategy layer is where meaning
accumulates, but the interesting problems get solved by a character standing
on tiles.

## Prototype status (2026-07-04)

Built and playtested (see sky-islands/SPEC.md for technical detail):
- **Vertical slice**: generated islands, fog-as-coverage, caches, doors,
  survey contract, report/payout. Roadmap phases 1–2 done except combat.
- **The Tether** (hub, hand-authored prefab): bunk (sleep = save + stash),
  company store (transfer UI + prices, voluntary debt payments), mission
  coordinator (contract board), skiff dock. Pulled forward from phase 4.
- **Company-town economics [settled]**: contract money = fee + bounties +
  coverage bonus, garnished; goods stay physical and sell at store margins.
  The store's spread is the real garnish.
- **Persistence + determinism [settled]**: versioned snapshots, sleep/
  homecoming saves; all RNG derives from (master, domain:entity) — split
  generators per Eric's requirement, interactions can't perturb islands.
- **Hunger clock**: thresholds → warnings; collapse → company retrieval,
  rescue fee onto the debt, mission forfeit, wake at bunk. The rescue
  path is the generic fail-state, ready for combat to reuse.
- **Foraging [settled]**: one-way (take-only) containers — berry bushes
  strip and vanish. Free food attacks the store's margins. Future:
  regrowth on a day clock; crafting berries into preserves.
- **Combat v0 [built]**: fauna + shard-wardens guarding ruin caches,
  attack-on-sight/wander AI, bump attacks, symmetric concealment in
  thickets, hunting drops meat, healing ladder (regen < bed rest <
  bandages), danger-tiered contracts with occasionally-wrong reports,
  injury collapse → retrieval + medical surcharge. No death, ever.
- **Manumission [built — the v1 ending]**: debt 0 (either payment path)
  → ACCOUNT CLOSED screen; freed agents keep full payouts; rescue
  re-indentures. Freedom is a state you can fall out of.

**V1 SHIPPED 2026-07-04**: repo github.com/Thunderducky/sky-islands,
playable at https://thunderducky.github.io/sky-islands/ (web export +
controls page in docs/). 88 headless tests.

Next (undesigned): what freedom is FOR — first claim, faction contact,
buying the skiff outright. That conversation opens phase 3+ of the
roadmap (strategic sim, claims).

## Design pillars [settled]

1. **One sim, many resolutions.** The world is one consistent simulation
   viewed at different levels of detail. Never two rulesets that can disagree.
2. **The constraint is the fiction.** Engineering limits surface as mechanics:
   the sim budget is the claim system, the world's edge is open sky, the
   active-island swap hides inside travel time.
3. **Content-first.** Systems are shared substrates; content is Lua data
   tables. A new monster, item, or building is one table.
4. **Pressure without a mandate.** The world pushes back at every timescale;
   no scripted goal is required for stakes to exist.
5. **Roles are permissions, not modes.** One world, one command set; what
   changes is which levers you're allowed to pull.

## The world [leaning]

- A small archipelago of floating islands; the sky is the world's edge.
  Falling is a mechanic, not an error state.
- **The Fracture**: the event that created the sky islands. All factions date
  their origin to it; their ideologies are inherited grudges. Pre-Fracture
  ruins in the deep sky are expedition content. *(Specifics of the Fracture:
  open.)*
- **The apocalypse**: whatever holds the islands up is failing. This is the
  long clock the whole setting runs on.
- **Tribute feeds the failing thing** *(leaning, not committed)*: the periodic
  resource sink isn't (only) rent to a power — it keeps your island aloft.
  Nonpayment is visible: wards gutter, islands fall. Unifies why-islands-float,
  what-the-apocalypse-is, and what-tribute-is into one lore object.
- Open: what lives below the islands / in the open sky; how altitude works.

## Player fantasy & arc [settled]

- **Day one**: you arrive indentured to a scouting company (see Opening
  scenario). Debt payments sit on the event queue beneath tribute. Nobody
  helps a debtor — that's why outside help is limited.
- **Early game** — *runner*: STALKER-style contract work. Runs into dangerous
  places, haul, sell, gear up, one more run. First milestone: buy out the
  indenture.
- **Mid game** — *tenant, then steward*: a micro home-base plot on a host
  island; faction rep unlocks administrator access to islands you don't own.
- **Late game** — *claimant / scale-shifter*: your own claims, your own
  contracts commissioned, your weight thrown behind (or against) a faction's
  answer to the end of the world.
- **Two ending registers, one system** *(lean: no hard mode split)*: wealth is
  fungible — every coin can buy your personal escape or fund an outcome.
  Individual escape can literally be passage on the escape faction's ark, so
  the personal ending still routes through the faction race.
- The arc doubles as the dev roadmap (see Roadmap).

## Simulation model [settled]

Two resolutions, one island active at a time.

- **Active island** (exactly one): full tile-level simulation — substrates,
  fields, creatures, combat. The roguelike. Travel time between islands masks
  the activation swap; the boundary is open sky, so there is no seam.
- **Strategic mode** (claimed, inactive islands): a stock-and-flow model.
  Stocks (food, ore, population, morale…) + flow rates (mine output/day,
  consumption/day) + discrete events (ship arrives, stock hits zero, global
  event). No pathfinding, no tiles — daily aggregates only.
- **Solve, don't tick**: trajectories are piecewise-linear, so strategic sim
  is an event queue. Solve forward to the next inflection point; query any
  island's state on any date by interpolation. Global events invalidate and
  re-solve from their date. Side effect: the game knows the future of inactive
  islands — rumors, urgency, and drama for free.
- **Consistency rule**: flow rates live in content defs and BOTH resolutions
  read the same numbers. A `miner` def eats 1 food/day, mines 2 ore/day —
  tactical spends it through meals and actions, strategic as a rate. One
  source of truth; the resolutions cannot drift.
- **Compress / materialize**: leaving an island tallies survivors and intact
  buildings into rates (player actions cross into strategic automatically);
  landing decompresses strategic state back into tiles.
- **Simulation LOD ladder**: active (tiles) → claimed (stock-flow) →
  known-unclaimed (static estimate) → unknown (not yet generated).

## Claims, discovery, expansion [settled]

- **Claims are the sim budget**: claimed islands get strategic sims; the soft
  cap on claims is the soft cap on simulations, and it's diegetic — territory
  costs tribute.
- **Discovery flow**: locate island → surveyors return a rough *estimate* →
  player decides if the expedition is worth it.
- **Estimates are generation constraints** *(proposed)*: islands aren't
  generated until first landing, seeded to match the estimate ± surveyor
  error. Better surveyors, tighter bars; wrong estimates are the expedition
  gamble.
- **Abandon / cede**: claims can be dropped or transferred to factions.
  Abandoned islands decay — computed lazily on re-entry from time elapsed.
- Open: are claims symmetric (factions run the same machinery, and does the
  cap count their islands)? *(Lean: yes — a living political map for the cost
  of more small sims.)*

## Economy, contracts, pressure [settled]

- All pressure is strategic-sim content — stocks, flows, events. No new
  machinery per pressure type.
- **Timescale layering** (deliberate): daily subsistence / periodic tribute
  and debt / monthly morale drift / irregular external shocks / one long
  apocalypse arc. There is never a moment when everything is fine.
- **Contracts fall out of deficits**: faction stock shortfalls ARE contract
  offers ("hull short 200 timber"). No quest tables — query faction event
  queues, post the gaps as work. Sabotage is the same structure with the sign
  flipped.
- **Morale caution**: it's the classic death-spiral ingredient. Exit ramps
  from day one: recovery floors, morale keyed to trajectory not level, cheap
  interventions (festival, speech).
- **Independence pivot**: once you could survive without the outside, tribute
  becomes a choice; refusing it is a declaration.

## Factions [leaning — promising, not committed]

Factions are defined by their answer to the apocalypse (ideologies, not map
colors):

- **Escape** — building a ship/ark to leave.
- **Counter-magic** — working to defeat the magical apocalypse.
- **Dark magic** — wants to control and *accelerate* it. Load-bearing:
  someone must want the fire, or diplomacy goes flat.

Faction projects are ordinary stocks in their strategic sims ("60% of a
hull"). Conflict over scarce apocalypse-resources generates itself; an endgame
is somebody's clock completing. The player's role is **shifting the scales** —
the marginal actor deciding which big slow machine finishes first.

## Control plane [settled]

- **Data plane** = the sim; runs identically regardless of ownership.
  **Control plane** = a small verb set: commission building, post contract,
  set route, claim, abandon…
- **Roles are permissions over verbs**: runner (read + execute contracts) →
  tenant (write access to a plot; rent is a flow) → steward (rep unlocks admin
  verbs on a faction's island) → claimant (full set on your own).
- **Rep is the keyring.** Faction alignment = whose keys you hold; the player
  is structurally a free agent.
- **Faction AI is a control-plane client**: NPC administrators issue the same
  commands through the same API as the player. Build the command layer once.
- The control plane is attackable: kill an administrator and the island stops
  issuing commands; forge credentials and it issues yours.
- Implementation note: ownership is a tile/building attribute in the tactical
  sim (an ownership substrate) — needed for plots and tenancy.

## Combat — v0 [scoped & agreed 2026-07-04]

Build spec lives in sky-islands/SPEC.md ("Combat v0"). Agreed v0 scope:
fauna + one ruin guardian, attack-on-sight/wander AI, bump attacks with a
single damage number (types/armor arrive with equipment, deferred),
concealment rule for thickets (see out, hidden unless adjacent — both
ways, Eric's call: full coverage should be dangerous), hunting drops
meat, healing via regen / bed rest (double the natural rate) / bandages,
danger-tiered contracts (higher fee for nastier islands, coordinator
gives a rough — occasionally wrong — danger report), and **no death**:
hp 0 = company retrieval with a medical surcharge — you can't die, you
can only owe more. The original full proposal below stands as the
eventual target.

Primitive on purpose; built from substrates so it composes with everything
else rather than being its own island of rules.

- **Turn economy**: move-point scheduler (~100 points/turn); attacks and moves
  spend points. Speed differences emerge from cost differences.
- **Bump attack**: melee = move into an occupied tile. No stance/limb/grapple
  systems in v0.
- **To-hit**: attacker skill vs. defender evasion → hit chance; single roll.
- **Damage types**: blunt / cut / pierce / fire. Armor is flat reduction per
  type (a leather coat stops cut better than blunt). Item and creature
  materials come from the same defs the economy uses.
- **HP**: single pool per creature in v0. No limbs yet — the def format
  should leave room for parts later, but do not build it now.
- **Effects, not special cases**: on-hit riders are stacking `effect`
  instances (bleed = damage over time, stun = lose move points, burning =
  fire-typed DoT). The same effect system the environment uses — standing in
  a fire field applies `burning`, a torch attack applies the same `burning`.
- **Fields participate**: fire spreads to flammable tiles and creatures;
  smoke blocks FOV. First proof of substrate composition (fire + materials +
  effects + FOV) doubles as the first combat content.
- **Death**: creature becomes a corpse item (economy object: haulable,
  sellable, maybe tribute-relevant). Strategic shadow: combat deaths change
  the population tally at compress time — a massacre you commit on an active
  island IS a strategic event when you leave.
- **Ranged**: v0.5. Straight-line projectile, same to-hit and damage model.
  No cover math beyond "solid tiles block."
- Explicitly out of scope for v0: limbs, grappling, martial arts, weapon
  durability, ammo variety, stealth (beyond FOV), morale-in-combat.

## Opening scenario & vertical slice [settled]

The game opens — and the prototype proves itself — with a survey contract:

- **Setup**: the player is indentured to a **scouting company**. This is the
  debt from day one, made concrete: who you owe, and why you're out here.
- **The contract**: survey a floating island; discover a limited cache.
  Payment: a scouting fee + a share of proceeds of anything found.
- **The job**: land on a generated island, explore it (FOV + examine), find
  the cache, and produce a **survey report**. The report is literally the
  compress() operation done by hand — it becomes the island's strategic-layer
  estimate, and its accuracy depends on coverage and what you examined. The
  player personally performs, once, the system they'll later commission
  abstractly. (Tutorial, pitch, and control-plane ladder in one.)
- **The temptation (emergent, not scripted)**: the company's cut is computed
  from YOUR report. Under-report the cache and skim the difference; rep is
  the cost, the buyout is the motive.
- **First milestone**: buy out the indenture — get out from under the
  scouting company. A measurable, economic goal that exercises the whole
  loop: explore → find → report → get paid → chip at debt.

**Slice scope (Eric)**: one generated island with a few buildings and doors,
a few resource caches to discover, a few items. At the end the player submits
the report and receives credits — some counting against the indenture debt,
some kept to buy equipment. Explore → discover → get paid → chip the debt:
a complete simple game by itself.

As a development test, the slice requires: island generation, substrate +
rendering, FOV + **fog of war**, movement/turn loop, doors, items + caches,
examine/survey verbs, **flavor narration + message log**, contract math
(fee + split vs. debt), and a completion state. If this loop plays, the game
exists.

- **Fog of war** [settled]: three tile states — unknown / explored-remembered
  (drawn dim) / visible (true colors). A substrate layer (seen flag +
  remembered glyph). Load-bearing: **% explored IS survey coverage**, which
  sets report quality and payout — the UI meaning and the economic meaning
  are the same number. Rendering via ramp arithmetic: remembered tiles draw
  two steps down-ramp or in grays; no second art set.
- **Flavor narration** [settled]: discovery events narrated via
  human-editable Lua tables — event key → pool of template strings with
  substitution slots ("You pry the {container} open — {contents}."), weighted
  pick against repetition. v0 is lookup → pick → fill → message log;
  conditional pools (biome, weather, first-time) later. Requires a message
  log panel in the 80×30 layout — not chrome; surveying makes the log half
  the game.

## Island generation [settled — needed for the slice]

- Islands are **randomly generated**, fractured — a floating silhouette
  against open sky (mask/noise shape with bites taken from the edges); edges
  are the world edge, falling is real.
- Layers into the substrate arrays: terrain, then features/hazards, then
  placement (cache, points of interest, things that make survey coverage
  non-trivial).
- Slice scope: ONE biome, one island, modest size. Real generation, not a
  hand-authored map.
- Later phases: estimates constrain generation (island generated at first
  landing to match the surveyor's estimate ± error). The opening inverts
  this: there is no estimate yet — the player is making one.

## Prototype presentation [settled]

- **ASCII glyphs on a grid**, Apollo 46-color palette (already wired:
  `palette.png` + `palette.lua` in the project).
- 640×360 via `_config()` → 80×30 glyphs at 8×12. Usagi's default bundled
  font initially; custom `font.png` later if wanted.
- Palette ramps are semantic: field intensity indexes into a ramp (fire 1–6 =
  gold ramp 1–6, scent = greens, etc.).
- Full graphical tiles: explicitly deferred, maybe never. ASCII is the
  aesthetic, not a placeholder.

## Architecture sketch

- `substrate.lua` — flat-array tile layers (terrain, fields, ownership…),
  indexed `y*w+x`, behind one module boundary
- `islandgen.lua` — fractured-island generation: silhouette mask → terrain
  layers → placement; seeded, later constrained by survey estimates
- `defs/` — content tables; `copy_from` inheritance via metatable; defs carry
  tactical behavior AND strategic flow rates
- `turnloop.lua` — move-point scheduler (active island)
- `strategic.lua` — stock/flow/event-queue sim for claimed islands
- `control.lua` — the command verb set + permissions (player, faction AI, and
  events all call through this)
- `fov.lua` — shadowcasting, recompute only on change; feeds the fog-of-war
  layer (unknown / remembered / visible)
- `flavor.lua` + `defs/flavor/` — event-keyed narration pools, template
  substitution, message log
- `dijkstra.lua` — one flow field, all monsters descend it
- `effects.lua` — stacking timed effects on creatures
- Perf escape hatch if ever needed: native Rust kernels in the engine exposed
  to Lua (Usagi is public domain). NOT a LuaJIT port (loses Lua 5.5 + web
  export).

## Roadmap

The player's arc is the build order; playable at every phase. Phases 1–2
together deliver the vertical slice (the survey-contract opening).

1. **One island, one body** — substrate, island generation (buildings,
   doors), turn loop, FOV + fog of war, defs, rendering, message log. Walk
   around a generated island. Fire field as the first composed system.
2. **The survey contract (vertical slice)** — items + caches, examine/survey,
   flavor narration, the report, contract math (fee + split vs. indenture
   debt), completion + payout screen. Combat v0 and basic needs as the
   island's teeth.
3. **Strategic sim** — stocks/flows/event queue for ONE island while you're
   on it conceptually "elsewhere"; compress/materialize round-trip. Then a
   second island and real travel.
4. **Claims + economy** — tribute, debt, contracts from deficits, surveyors,
   estimates-as-generation.
5. **Control plane + factions** — verbs, permissions, rep, NPC administrators,
   faction projects and clocks.
6. **The apocalypse** — the long clock, endings.

## Open questions

- Specifics of the Fracture; what lives below / in the open sky.
- Faction symmetry (lean yes) and how many claims the world budget allows.
- What controlling an island yields precisely (flows to you? taxes? rights?).
- Active-island tile size (earlier strawman: ~60×60–100×100).
- Death & persistence: permadeath? bloodline? new debtor in the same living
  world? (The persistent world makes "new character, same world" attractive.)
- Combat v0 numbers (all of the Combat section is proposal until played).
