# Sky Islands — Vertical Slice Technical Spec

*Companion to ../DESIGN.md. This is the build plan for the survey-contract
slice: what each file is, what the data looks like, and how it fits together.*

## Ground rules

- Lua 5.5 on Usagi. Engine calls `_config` / `_init` / `_update(dt)` /
  `_draw(dt)` in `main.lua`; everything else is `require`d modules.
- **Engine isolation**: only `main.lua` and `ui/` may touch `gfx.*` /
  `input.*`. World, sim, and gen modules are pure Lua (data in, data out) —
  this is what makes them unit-testable and delegable.
- **Live reload**: mutable game state lives in the global `State` (survives
  reload); modules hold no mutable state of their own. `_init` rebuilds
  `State` from scratch (F5 = new game).
- **Determinism**: every island is a function of its seed. No bare
  `math.random` — all randomness through `util/rng.lua` instances, with
  separate streams for gen and flavor so cosmetic picks never perturb layout.
- Avoid Lua 5.5-only syntax in `world/`, `sim/`, `util/`, `defs/` so tests
  run on system Lua 5.4 (`brew` lua). 5.3+ features (`//`, bitwise) are fine.

## File tree

```
sky-islands/
  main.lua              -- usagi callbacks; owns State; loads debugflags
  flavor.lua            -- narration engine: pool pick + {slot} fill -> log
  debugflags.lua        -- OPTIONAL, gitignored: local dev flags (CLAUDE.md)
  palette.lua           -- Apollo ramp constants
  palette.png           -- Apollo palette
  sprites.png           -- packed art (art-src/ pipeline at repo root)
  SPEC.md               -- this file
  game/
    state.lua           -- state-stack machine (push/pop/switch, opaque)
    run.lua             -- game flow: new/continue, missions, sleep, rescue
    save.lua            -- versioned snapshot/restore (hard rule 10)
    states/
      titlescreen.lua   -- art banner -> intro
      intro.lua         -- new game / continue
      play.lua          -- the game: input->actions, interact, containers
      inventory.lua     -- overlay: pack + hunger meter + use item
      examine.lua       -- overlay: cursor look-around
      transfer.lua      -- two-pane container/shop UI (scroll, demand marks)
      offers.lua        -- contract board
      confirm.lua       -- generic y/n overlay (+extra_keys detours)
      gossip.lua        -- shopkeeper market-event news overlay
      sleepwipe.lua     -- sleep transition: wipe in, hold dark, wipe out
      report.lua        -- survey payout letter (opaque)
      rescued.lua       -- retrieval invoice
      manumission.lua   -- ACCOUNT CLOSED ending (opaque)
  world/
    substrate.lua       -- flat-array layers + sparse overlays (single owner)
    islandgen.lua       -- seed -> island (silhouette, buildings, caches, forage)
    prefab.lua          -- ASCII-authored maps
    hubgen.lua          -- The Tether (hand-authored prefab)
    authored.lua        -- mission island from a defs/islands.lua spec (no RNG)
    fov.lua             -- shadowcasting; fog layer + seen_count
  sim/
    actions.lua         -- turn verbs: move/bump, door, wait, submit
    turn.lua            -- applies a verb, clock, hunger, creatures, collapse
    contract.lua        -- coverage %, bounties, garnish math
    creatures.lua       -- AI, combat math, concealment, drops
    needs.lua           -- hunger states, regen, use (eat/heal)
    inventory.lua       -- slot/stack math for every holder
    market.lua          -- econ events: lifecycle, selection, restock
  ui/
    draw.lua            -- glyph-grid renderer (map, sidebar, log frame)
    log.lua             -- message ring buffer
    menu.lua            -- generic vertical list-picker widget
    layout.lua          -- the 78x28 cell geometry constants
  defs/
    init.lua            -- loader: interning, copy_from, cross-ref checks
    terrain.lua, items.lua, features.lua, creatures.lua
    islands.lua         -- hand-authored mission islands (map+legend specs)
    econ_events.lua     -- market events (human-authored text + effects)
    economy.lua         -- every tunable number (hard rule 7)
    flavor.lua          -- event-keyed narration template pools
    art.lua             -- sprite atlas slices
  util/
    rng.lua             -- SplitMix64: new/fork/derive (no math.random)
    grid.lua            -- idx<->xy helpers, neighbors, line, flood fill
  tests/
    run.lua             -- tiny assert runner: `lua tests/run.lua`
    test_substrate/fov/gen/contract/rng/grid/log/flavor/needs/
    inventory/creatures/market/integration.lua
```

## Screen layout (`ui/layout.lua`)

640×360, cell = 8×12 → **80 cols × 30 rows**. Bundled monogram font (5×7)
drawn per-cell inside each 8×12 cell for now; a baked 8×12 `font.png` is a
later polish task, no code change.

```
+--------------------------------------------------+--------------------+
| map viewport 58x25 (cells 0-57 x 0-24)           | sidebar 22x25      |
|   camera-follows player, island scrolls          |  SURVEY: Ilse-461  |
|                                                  |  coverage 62%      |
|                                                  |  credits/debt      |
|                                                  |  turn count        |
+--------------------------------------------------+--------------------+
| message log: 80x5 (rows 25-29), newest at bottom                      |
+-----------------------------------------------------------------------+
```

## Data shapes

### Island (built by `islandgen.generate(seed, params)`)

```lua
island = {
  seed = 12345, w = 48, h = 48,
  terrain    = {},  -- [idx] terrain def id (interned int, see defs)
  fog        = {},  -- [idx] 0=unknown 1=remembered 2=visible
  features   = {},  -- sparse: [idx] = {def="cache_small", loot={...}, opened=false}
  item_piles = {},  -- sparse: [idx] = { itemInstance, ... }
  start_idx  = i, extract_idx = j,
  land_count = n,   -- walkable+seeable tiles, denominator for coverage
}
-- idx = y * w + x, 0-based. util/grid.lua owns the arithmetic.
```

Flat arrays are 1-based Lua tables indexed `idx+1` internally; the module
boundary hides this — callers use `sub.get(island, "terrain", x, y)`.

### Defs (`defs/*.lua` return plain tables; `defs/init.lua` loads them)

```lua
-- terrain.lua
{ id = "floor_planks", glyph = ".", color = P.TAN + 4,
  walkable = true, opaque = false },
{ id = "door_closed", glyph = "+", color = P.TAN + 3,
  walkable = false, opaque = true,  door = { opens_to = "door_open" } },
{ id = "door_open",   glyph = "'", color = P.TAN + 3,
  walkable = true,  opaque = false, door = { closes_to = "door_closed" } },
{ id = "sky", glyph = " ", color = P.BLUE + 1, walkable = false,
  opaque = false, is_sky = true },

-- items.lua (value in credits; the slice economy is: value is everything)
{ id = "salvage_copper", name = "copper fittings", glyph = "$",
  color = P.GOLD + 4, value = 8, stack = true },

-- features.lua
{ id = "cache_small", name = "supply cache", glyph = "=", color = P.GOLD + 5,
  loot_table = "cache_small", reportable = true, bounty = 15 },
{ id = "extract_beacon", name = "extraction beacon", glyph = ">",
  color = P.MAGENTA + 4 },

-- GLYPH RULE: the bundled monogram font covers ~500 glyphs (Basic Latin,
-- Latin-1, Latin-ext-A, partial Greek). Defs stick to printable Basic
-- Latin (0x20-0x7E) — no box-drawing/geometric shapes. Missing codepoints
-- are silently skipped by the engine (invisible glyph = confusing bug).

-- copy_from: defs.init resolves it with a metatable chain at load time
{ id = "cache_sealed", copy_from = "cache_small", locked = true }
```

`defs.init` interns string ids to ints (CDDA-style) and exposes
`defs.terrain[id_or_int]`, `defs.intern(kind, "floor_planks")`. Content
authors only ever write strings.

### Flavor (`defs/flavor.lua`)

```lua
flavor.events = {
  cache_open = {
    "You pry the {feature} open — {contents}.",
    "The {feature}'s seal gives way. Inside: {contents}.",
  },
  first_sight_sky_edge = {
    "The ground simply stops. Below: sky, and more sky.",
  },
}
-- flavor.emit("cache_open", { feature = "supply cache",
--                             contents = "copper fittings x3" })
-- -> picks (flavor rng stream), fills {slots}, pushes to ui/log.
-- Unknown event key: log a dev warning, never crash.
```

### Player & run state

```lua
State = {
  stack   = {...},          -- game/state.lua machine
  island  = island,
  player  = { x=, y=, glyph="@", color=P.WHITE, inv={}, mp=100 },
  clock   = { turn = 0 },
  run     = {  -- the contract, in numbers
    fee = 120, share = 0.25,         -- scouting fee + proceeds share
    debt = 2000,                     -- indenture outstanding
    discovered = {},                 -- feature idxs found (for report)
  },
  log     = { ... },        -- ui/log ring buffer
  rng     = { gen = R1, flavor = R2, loot = R3 },
}
```

## State machine (`game/state.lua`)

A stack of state tables, each `{ enter?, leave?, update?, draw, key? }`.
`draw` is called for every state on the stack bottom-up (overlays render over
play); `key`/`update` only reach the top. Transitions:

```
intro --any key--> play --submit at beacon--> report --R--> play (new seed)
                     |                                 --Q--> quit
                     +--(i) push inventory / (x) push examine / esc pops
```

`main.lua` is ~30 lines: `_init` builds State and pushes intro; `_update`
translates `input.key_pressed(...)` into `stack:key(k)`; `_draw` calls
`stack:draw()`.

## Input (in `states/*.key`)

Raw `input.KEY_*` (roguelikes need the whole keyboard; the engine's 7-action
keymap is for pads). RESERVED: the engine's pause menu intercepts Esc / P /
Enter (pause_menu defaults true; we keep it for free volume/fullscreen/remap
UI) — never bind those. Slice bindings: arrows/hjkl+yubn move, `o` open/close
adjacent door, `g` pickup, `i` inventory, `x` examine, `.` wait, `Space`
confirm/submit-at-beacon and close overlays.

## Core loops

### Turn (`sim/turn.lua`)

Player-only for the slice, but shaped for more actors later:

```
states/play.key(k) -> actions.from_key(k, State)   -- nil if unbound/invalid
                   -> turn.take(State, action)
turn.take: validate -> apply (mutate island/player) -> clock.turn += 1
        -> post hooks (fov.recompute if moved/door toggled; flavor emits)
```

Actions are data: `{ kind="move", dx=1, dy=0 }`, `{ kind="open", x=, y= }`,
`{ kind="pickup" }`, `{ kind="submit" }`. `actions.lua` validates and applies;
adding a verb = one table + one apply function.

### FOV & fog (`world/fov.lua`)

Recursive shadowcasting, 8 octants, radius ~12. Only recomputed on
move/door-toggle (turn.take knows). Output: sets `fog[idx]=2` for visible,
demotes previously-visible to `1` (remembered). Rendering reads only `fog`.
Coverage = count(fog>0 over land tiles) / land_count — computed incrementally
(increment a counter when a tile first leaves 0).

### Rendering (`ui/draw.lua`)

Every frame, immediate mode (it's 80×30 text cells; no dirty tracking until
proven necessary):

```
for each viewport cell: world x,y from camera
  fog==0 -> skip (black)
  fog==1 -> glyph at dim color   (ramp step -2, floor of ramp base+1)
  fog==2 -> glyph at true color; item pile / feature / player override terrain
sidebar: coverage %, credits, debt, turn, context hints
log: last 5 lines, oldest dimmest (gray ramp)
```

Dimming rule lives in `palette.lua` as `P.dim(color_index)` — ramp arithmetic,
grays for anything that would fall off the bottom of its ramp.

## Island generation (`world/islandgen.lua`)

Pipeline, all off one `rng.gen` stream, pure function of (seed, params):

1. **Silhouette**: radial falloff + value noise threshold → land mask;
   take 2–4 "fracture bites" (circle punches) from the rim. Reject masks
   with land_count outside [900, 1600] and regenerate (bounded retries).
2. **Terrain**: land = grass/dirt/rock via second noise octave; rim ring
   gets `edge` variant (flavor hook for vertigo lines); everything off-mask
   is `sky`.
3. **Buildings**: 2–4 rectangular shells (walls, plank floors, 1–2 doors
   each) placed on flat-enough land, non-overlapping, min separation.
4. **Features**: 3–5 caches — biased inside buildings or against rim (risk
   vs. reward by placement); 1 extraction beacon near a rim; player start
   at the beacon.
5. **Loot**: roll each cache's loot_table with `rng.loot`.
6. **Validate**: flood-fill from start (util/grid): every cache adjacent-
   reachable and beacon reachable, else carve a path or reject. **An island
   that ships is always completable.**

`params` (island size, building count, cache count) is a plain table —
this is where survey-estimate constraints plug in post-slice.

## Contract math (`sim/contract.lua`)

```
findings_value = Σ value of items recovered + Σ bounty of reportable
                 features discovered
payout   = fee + share * findings_value
coverage_bonus = round(payout * coverage_bonus_curve(coverage))  -- e.g. +20% at 90%
to_debt  = floor((payout + coverage_bonus) * debt_garnish)        -- e.g. 60% garnished
kept     = rest
```

One pure function: `contract.settle(run, island) -> report table` consumed by
`states/report.lua`, which renders it line by line (fee, findings, coverage,
garnish, kept, debt remaining). All knobs live in `defs/` not code, so tuning
is content editing.

## Inventory & containers (added post-slice)

Minecraft-style: items carry `max_stack`; the player has
`economy.player_slots` slots (8 — deliberately tight; the ferry loop is the
game). `sim/inventory.lua` is the pure stacking math: `add` (capped, tops up
stacks then opens slots, returns moved/leftover), `merge` (containers are
unlimited, merge by id), `value`, `summary`.

Anything with an `.items` list is a container: cache loot (stays inside on
discovery), the skiff hold (`hold` on the beacon feature — findings =
pack + hold at settle), ground piles. `[g]` opens
`game/states/transfer.lua`, the two-pane UI: Space moves the selected
stack, g moves a single unit, Tab/h/l switch panes, Backspace closes
(Backspace = universal overlay-close everywhere). Transfers are free actions until combat gives
time a price.

## Hub, missions, persistence (added post-slice)

Game flow (`game/run.lua`): `new_game` → **The Tether** (hand-authored hub,
`world/hubgen.lua` prefab stamped via `world/prefab.lua`) → coordinator
(`states/offers.lua`, 3 contracts/cycle) → mission island → beacon →
report → `return_to_hub` (cycle++, trader restocks, autosave). Islands
persist in `State.world.islands[id]`; `State.island` is the active pointer.

**Company-town economics**: contract money = fee + bounties + coverage
bonus, garnished by `debt_garnish`. Goods are NEVER converted at settle —
pack + skiff hold come home physical, to sell at the store (`buy_mult` /
`sell_mult` margins). The skiff hold lives on `State.skiff`, not on any
island. Voluntary debt payments (`[d]`) at the store.

**Containers, one interface**: any feature with an `.items`-shaped list
opens the transfer UI. Variants by flag: `prices` = shop (credits move
opposite to goods), `take_only` = forage (stowing refused; `on_empty`
callback removes stripped features). Hub amenities: bunk (`stash` +
Space = sleep/save), trader (`stock`), coordinator, skiff dock.

**Hunger** (`sim/needs.lua`): +`per_turn` per turn; thresholds peckish /
hungry / starving warn on worsening transitions only; `collapse` ends the
mission — `run.rescue()`: wake at the bunk, `rescue_fee` added to debt,
contract forfeit, goods retained, autosave, retrieval-invoice screen
(`states/rescued.lua`). Eat from the inventory screen (Space); food =
items with `nutrition`.

**Saves** (`game/save.lua`): versioned full snapshots via `usagi.save`.
Invariants: snapshot/restore DEEP-COPY (shared references = retroactive
mutation bugs); saves carry their own terrain id→int map and load remaps
(def load order must not scramble old saves); saving is hub-only (no
mission state in saves). Sparse int-keyed tables serialize as record
arrays. New player fields default on load (`snap.player.hunger or 0`).

**Determinism rules**: same seed + same actions = same world.
- All streams derive from `(State.master, domain..":"..entity)` via
  `rng.derive` — "island:<seed>", "missions:<cycle>", "market:<cycle>",
  "flavor". Interacting with one system never perturbs another. Prefer
  derive-with-counter over saving advancing stream state.
- NO `pairs()` iteration anywhere that feeds RNG draws or mutation order
  (Lua hash order is not guaranteed) — iterate by index. Rendering-only
  `pairs()` is fine.
- No wall clock in sim; `os.time` only seeds `new_game`.

## Combat v0 (BUILT 2026-07-04 — this section is now descriptive)

Scope guard: no equipment, no armor, no damage types this pass — one
damage number, simple healing. No death: hp 0 routes through the rescue
system with a medical surcharge. AI is deliberately dumb (attack on
sight, wander otherwise); smarter behaviors come with the simulation
work later.

### Creatures
`defs/creatures.lua`, one table per species:
```lua
{ id = "rim_shrike", name = "rim shrike", glyph = "r", color = P.RED + 4,
  max_hp = 5, damage = { 1, 3 }, acc = 0.75, speed = 100,
  aggro_radius = 9, drops = { { item = "game_meat", min = 1, max = 1, chance = 0.6 } },
  desc = "..." }
```
- `speed`: mp gained per world turn; acts while mp >= 100 (50 = half
  speed, 200 = double). Most fauna 100.
- `aggro_radius = 0` = docile: wanders, retaliates only when hurt.
Roster: **dust-hen** 'h' (docile, drops meat — the hunting target),
**rim shrike** 'r' (fast, weak, aggressive), **thorn-hog** 'q' (tougher,
found near thickets), **shard-warden** 'W' (magenta, slow speed 50,
tough; parked adjacent to ruin caches so the best loot has teeth).

Instances persist on the island (and in saves) like features:
`island.creatures = { { def = "<id>", x, y, hp, mp, state = "wander"|"hunt",
last_x, last_y }, ... }`. 4–8 per island: linear scans, no occupancy
grid until profiling demands one.

### Turn order
player action (turn.take) → hunger tick → **creature phase** (each gains
`speed` mp, acts while mp >= 100) → collapse check (hunger OR hp <= 0) →
FOV update. `turn.take` returns "collapse" as today; `run.rescue(reason)`
— reason "injury" adds `medical_fee` to the invoice and swaps flavor.

### Creature AI (v0, deliberately dumb)
- `can_see(c, player)`: distance <= aggro_radius AND clear `G.line` ray
  (intermediate tiles not opaque) AND the concealment rule below.
- **wander**: 50% idle, 50% random adjacent walkable step.
- sees player → **hunt**, `last_seen` = player pos. Hunt: greedy step
  toward last_seen (reduce the larger axis first; blocked → try the
  other; else idle). Adjacent → attack. Reaches last_seen without
  reacquiring → wander. (`dijkstra.lua` remains the upgrade path.)
- **Determinism**: each creature-turn draws from
  `rng.derive(State.master, "ai:"..island.seed..":"..i..":"..clock.turn)`
  — pure derivation keyed by the turn counter; nothing to save, replays
  exactly. Same pattern for combat rolls ("combat:<turn>").

### Concealment — the LOS asymmetry
Shadowcasting ignores the origin tile's opacity, so you already see OUT
of a bush normally. The asymmetry is a rule, not an algorithm change:
- terrain gets `conceals = true` (tree, bush).
- Seeing an opaque tile ≠ seeing what's inside it: anything standing on
  concealing terrain is invisible to observers unless ADJACENT.
- Symmetric as a rule: creatures hide from you in thickets too — they
  draw only when their tile is visible AND not concealed-at-range.
- Breaking LOS mid-hunt works through `last_seen`: they search where you
  were, not where you are.

### Combat math
- Bump attack: moving into an occupied tile attacks instead.
- Hit roll: attacker `acc` (player 0.8). Damage `r:int(dmg[1], dmg[2])`;
  player unarmed damage and hp live in `defs/economy.lua` (`player`
  table). No armor, no types — those arrive with equipment.
- Creature death: removed; `drops` roll into a ground pile (hunting
  closes the buy/forage/hunt triangle); flavor line.
- Player hp 0: "collapse" → rescue, medical surcharge.

### Health & healing
- `player.hp` / `max_hp` (20, economy defs); persists in saves (older
  saves default to max). Sidebar hp line colored by fraction.
- Passive regen in `needs.tick`: +1 hp per `regen_turns` (10) when below
  max and not starving.
- Sleep (bunk): advances `sleep_turns` (60) of clock+hunger, but hunger
  CLAMPS below collapse (wake starving, never billed in bed); heals at
  `sleep_heal_every` (5) — 1 hp per 5 turns slept, i.e. **double the
  natural rate** (12 hp/sleep vs 6 passively over the same span). Bed
  rest is the fastest free healing; bandages are the fastest, period.
- Still saves on sleep.
- Bandage item: `heal = 8`. Inventory Space generalizes from "eat" to
  **use** (`needs.use`: nutrition eats, heal bandages, refused at full
  hp). Store stock + occasional cache loot.
- `game_meat`: nutrition 180, from fauna. (Spoilage: future.)

### Danger tiers & contract pricing
Offers gain a danger tier: `offer = { seed, fee, danger }` (1–3, rolled
from the missions stream; fee = base roll + danger premium from
`defs/economy.lua`). `islandgen.generate(seed, defs, danger)` scales the
spawn table: tier 1 mostly docile fauna; tier 2 adds aggressives; tier 3
more of them plus a roaming warden beyond the cache guardians. The
island is a pure function of (seed, danger), and danger comes from the
missions stream — determinism holds.

The coordinator shows a ROUGH estimate — "reported: calm / uneasy /
hostile", colored — with a chance (`danger_misreport`, ~0.2) that the
report is off by one tier. Survey estimates being imperfect is the
expedition gamble from DESIGN.md arriving in v0: the calm-priced
contract that turns out hostile is exactly the story we want.

### Spawning
islandgen: fauna count and mix by danger tier (indexed iteration, gen
rng), biased away from the beacon; one shard-warden adjacent to each
ruin cache. The hub spawns nothing — home is safe, for now.

### Files touched when built
`defs/creatures.lua` + `sim/creatures.lua` (new); turn.lua (creature
phase, hp collapse), actions.lua (bump), needs.lua (use + regen),
run.lua (rescue reason, sleep), islandgen.lua (spawns), save.lua
(creatures + hp defaults), draw.lua (creatures, hp), economy/items/
flavor defs. Tests: AI unit on hand-built maps (see/hunt/lose/wander),
concealment rule, combat math, regen gating, sleep clamp, integration
(provoke → kill → drops; collapse-by-injury → medical invoice).

## Manumission (built — the v1 ending)

Freedom is derived, not stored: free = `State.persist.debt == 0`. The
transition is detected at the two payment sites and fires the
ACCOUNT CLOSED screen (`states/manumission.lua`) exactly once per
zero-crossing:
- settle: `report.lua` [R] routes through manumission when
  `debt_before > 0 and debt_after == 0`, then home.
- store: the `[d]` payment that lands on 0 pops the shop and pushes it.
Rules: garnish clamps to what's owed (`min(garnish, debt)` in
contract.settle — freed agents keep full payouts); the sidebar debt
line reads FREE; the store hides `[d]` and refuses payments with
`no_debt`; **rescue fees re-open the account** (re-indenture, with
flavor) — the door out swings both ways, so the hunger clock still
matters post-"win".

## Market events (BUILT 2026-07-11 — this section is descriptive)

Multi-cycle economic events at the company store: diegetic causes
("patrol ship in for repairs") that move prices on BOTH sides of the
counter and reshape restock. SI-0002; the trading arc's ground floor.

### Event defs (`defs/econ_events.lua`)
One self-contained table per event — authoring guide comment sits at the
top of the file. Fields: `id, name, weight, duration = {min,max},
cooldown, min_cycle, effects, add_stock?, gossip = {lines}, log`.
- `effects[]`: `{ match, demand?, restock_mult? }`. `match` is
  `{ id = "item_id" }` or `{ has = "field" }` (property predicate:
  `nutrition` = food, `heal` = medical — no tag system). First matching
  effect wins (`market.effect_for`).
- `demand` is a SEMANTIC LEVEL — glut | low | high | critical — mapped
  to numbers in ONE place: `economy.demand_levels[level] = {pay, charge}`.
  Events never carry raw multipliers.
- `add_stock` uses the loot-table entry shape `{item, min, max, chance}`.
- Load-time cross-ref checks in `defs/init.lua` fail on unknown item ids,
  unknown demand levels, missing gossip/log/duration.

### Price contract (`game/states/transfer.lua` + `sim/market.lua`)
The store's container gets `prices = { buy, sell, market = true }` (set
in play.lua's `container_here`). With `market` set:
- store charges: `max(1, ceil(value * buy_mult * charge_mult))`
- store pays:    `floor(value * sell_mult * pay_mult)`
`charge_mult`/`pay_mult` come from the active event's matching effect's
demand level, else 1. The spread (the garnish) survives all events.

### State & lifecycle (`sim/market.lua`)
`State.market = { event = {id, cycles_left, gossip_seen}|nil,
cooldowns = {[id]=n}, last_event }` — created by `market.init()` in
new_game, serialized in saves (version 1, defaults on load; events whose
defs vanished are dropped).

`market.advance(S)` runs EXACTLY ONCE per cycle increment (called from
return_to_hub and rescue, right after cycle++):
1. decrement cooldowns
2. active event ticks down; on end: set its cooldown, record last_event,
   return { ended } — an ending cycle is ALWAYS quiet (no new roll)
3. else roll `econ_events.start_chance` from
   `rng.derive(master, "econ-event:<cycle>")`; weighted pick over defs
   eligible by cooldown/min_cycle/not-last_event; roll duration;
   return { started }
Caller (run.lua `turn_market`) narrates via flavor keys `market_news`
(fills `{line}` with the def's `log`) and `market_settled`. advance()
itself never logs — it is the DIRECTOR SEAM: a tension-balancing/
personality director later replaces this picker without touching defs.

### Restock (`market.build_stock`)
Rebuilt every cycle from `rng.derive(master, "market:<cycle>")`:
`economy.store.staples` (always) + `economy.store.grab_bag` (loot-table
rolls) — each scaled by the matching effect's `restock_mult` (0 = absent)
— then the active event's `add_stock` appended. Grab-bag chance+count
are rolled UNCONDITIONALLY so an active event never shifts the draw
sequence of unrelated entries.

### Surfacing
- Gossip overlay (`states/gossip.lua`): shown once per event instance —
  play.lua's trader interact pushes it over the transfer UI while
  `event.gossip_seen` is false. Line pick derives from
  (master, "gossip:<id>:<cycle>").
- Transfer UI: `^`/`v` demand markers per matched row (DEMAND_MARK),
  "word at the counter: <event name>" line, panes scroll past MAX_ROWS.
- Writing principle (Eric): gossip shows, UI states — lines are partial
  and observational; markers carry the explicit facts.

### Files
`defs/econ_events.lua`, `sim/market.lua`, `defs/economy.lua`
(demand_levels, econ_events, store, trader_slots), `game/run.lua`
(turn_market + data-driven restock), `game/save.lua` (market field),
`game/states/{gossip,transfer,play}.lua`, `defs/flavor.lua`
(market_news/market_settled), `tests/test_market.lua`.

## Latent island features (BUILT 2026-07-11 — descriptive)

Features worth nothing to USE yet, worth money to REPORT (SI-0003):
old factory, ore deposit, magical inscription, freshwater spring, grand
pre-Fracture ruin. The claims system exploits them later — for free,
because islands are pure functions of seed (no storage needed).

- **Defs** (`defs/features.lua`): `latent = true, discover =
  "sight"|"assay", reportable = true, bounty, weight`. Load-time check
  enforces discover mode + bounty.
- **Two discovery modes**: `sight` features are surveyed the moment
  first rendered visible (`sim/discovery.lua scan_sight`, called after
  every FOV update — turn.lua post-hooks and enter_island). `assay`
  features need deliberate work: Space on the tile → `assay` turn verb
  (sim/actions.lua) → costs a turn. Thoroughness is now a choice
  distinct from coverage.
- **Found list**: `S.run.notable` — SEPARATE from run.discovered so
  caches_found stays honest. settle() pays bounties from both and
  returns `notable = {names}`; the report letter shows a "notable
  features (n)" line (row 9). `f.found` persists via the feature
  serializer.
- **Placement** (`world/islandgen.lua`, after caches): counts per
  danger tier from `economy.danger.latent`, weighted def pick, any
  reachable open tile. Hostile islands have better bones.
- **Flavor keys**: latent_sighted, assay_hint (stepping on unconfirmed),
  assay_done, assay_already.
- **Footprints (SI-0023, built 2026-07-11)**: a latent def may carry
  `footprint = { rows, legend }` — prefab-style, but SPACE CELLS ARE
  OUTSIDE THE MASK (untouched ground; shapes can be rings/crosses/Ls).
  Exactly one `@` cell (legend `rep = true`): the representative tile
  that carries the feature entry, bounty, and instance origin
  (`f.ox/f.oy`, serialized as scalars). Membership = origin + offset
  against the mask via `sub.feature_covering(island, x, y)` — no
  per-tile entries. Sight discovery fires when ANY mask tile becomes
  visible; assay/Space work from any mask tile. Footprints stamp their
  own terrain (wall_stone / rubble / water_shallow, all `built = true`)
  and are placed BEFORE the beacon+cache flood so pathing routes around
  their walls; island validity requires every rep tile reachable.
  Instances without an origin (debug force_latent, authored maps)
  degrade to single-tile behavior. Caches may land inside footprints —
  a ruin wrapping a strongbox is emergent, not a bug.
- Deferred (noted in tasks/): seen-but-unconfirmed features listed as
  "unconfirmed" in the report — estimate-error fiction in miniature;
  footprints that CONTAIN things by design (SI-0010 on-ramp).

## Web export & deployment (v1)

- `usagi export --target web` (run in this directory) → `sky-islands-web.zip`
  (index.html + usagi.{js,wasm} + game.usagi).
- The repo root is `../` (the roguelike/ folder); GitHub Pages serves
  `../docs/` on main: `docs/index.html` is the hand-written landing page
  (controls + framed iframe), `docs/play/` is the unzipped export.
- **To redeploy after changes**: re-export, `unzip -o sky-islands-web.zip
  -d ../docs/play`, restore the `<title>Sky Islands</title>` (export
  writes "Usagi"), commit, push. Pages rebuilds automatically.
- Live: https://thunderducky.github.io/sky-islands/ (repo:
  github.com/Thunderducky/sky-islands, public).

## Rust escape hatch (design constraint, not current work)

If an operation ever outgrows Lua, the path is **move data ownership, not
data**: hot dense layers (opacity, fog, fields, cost maps) become a
Rust-owned buffer (mlua userdata) inside a forked Usagi; Lua keeps calling
`sub.get/set` through cheap FFI methods, and bulk kernels (FOV, Dijkstra,
field ticks) run entirely Rust-side, writing results in place. Nothing
marshals per call. Tiers: (1) probably never — PUC Lua shadowcasts 48×48 in
<1ms and we're turn-based; (2) per-call kernel in `api.rs`, layer passed as a
byte string (zero-copy borrow inbound) — ~a day; (3) userdata substrate +
ported kernels — ~a weekend, WASM-safe so web export survives.

What this costs us NOW (and is already reflected above):
- **One owner per layer.** Nothing outside `world/substrate.lua` may hold or
  cache raw layer arrays. All access via `sub.get/set/...` — no exceptions,
  even where inlining would be faster today.
- Hot loops operate on **int layers** (interned ids), never on def tables.
- Cold sparse data (features, item_piles, defs, flavor, run state) is Lua
  forever; only dense layers are migration candidates.

## Testing (`tests/`)

`lua tests/run.lua` on system Lua (no engine): requires each `test_*.lua`,
plain asserts, prints pass/fail counts. Non-negotiable coverage:

- `rng`: same seed → same sequence; streams independent.
- `substrate`: get/set roundtrip, bounds, idx math.
- `fov`: hand-built 10×10 maps with expected visible sets (pillar shadow,
  closed vs. open door, radius clip).
- `gen`: for 50 seeds — land_count in range, beacon+caches reachable from
  start, no feature on sky, determinism (same seed twice → identical arrays).
- `contract`: settle() against hand-computed cases (incl. 0% and 100% coverage).

## Build order & delegation

Each step lands compilable + testable. **[cheap]** = fine for a cheaper
model with this spec + tests as the contract; **[mid]** = cheaper model
drafts, review the diff; **[here]** = judgment/taste, do it in this session.

1. `util/rng.lua` + `util/grid.lua` + tests — **[cheap]** (pure, spec'd)
2. `defs/init.lua` loader (intern, copy_from) + terrain/items tables —
   loader **[mid]**, content tables **[cheap]**
3. `world/substrate.lua` + tests — **[mid]**
4. `game/state.lua` + `main.lua` wiring + `intro` stub — **[here]** (glue,
   engine-facing, small)
5. `ui/layout.lua` + `ui/draw.lua` + `ui/log.lua` — draw **[here]** first
   pass (it's the game's face), log **[cheap]**, menu widget **[cheap]**
6. `world/fov.lua` + tests — **[mid]** (known algorithm, tests are the net)
7. `world/islandgen.lua` — **[here]** (taste: this is whether islands feel
   like places); validation pass **[mid]**
8. `sim/actions.lua` + `sim/turn.lua` — **[here]** (core feel)
9. `defs/flavor.lua` + `flavor emit` — plumbing **[cheap]**, writing the
   actual lines: Eric + [here] (it's authorship, not code)
10. `sim/contract.lua` + `states/report.lua` + tests — **[mid]**
11. `states/inventory.lua` / `examine.lua` off the menu widget — **[cheap]**
12. Tune gen params, playtest, cut what drags — **[here]** (and Eric)

Definition of done for the slice: fresh seed → intro → land → explore under
fog → open a door, loot a cache, read the narration → reach beacon → submit →
report screen shows honest math → debt goes down → R restarts with a new
island. All tests green on system Lua.
