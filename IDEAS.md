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
