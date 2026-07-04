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
  main.lua              -- usagi callbacks; owns State; delegates to game/state
  palette.lua           -- Apollo ramp constants (exists)
  palette.png           -- Apollo palette (exists)
  SPEC.md               -- this file
  game/
    state.lua           -- state-stack machine (push/pop/switch)
    states/
      intro.lua         -- situation text, contract terms, "press any key"
      play.lua          -- the game: input->actions, camera, turn advance
      inventory.lua     -- overlay: list menu over play
      examine.lua       -- overlay: cursor look-around
      report.lua        -- payout math screen; restart/quit
  world/
    substrate.lua       -- Grid: flat-array layers + sparse overlays
    islandgen.lua       -- seed -> island (silhouette, buildings, caches)
    fov.lua             -- shadowcasting; writes fog layer
  sim/
    actions.lua         -- action defs: move/open/close/pickup/wait/submit
    turn.lua            -- applies an action, advances clock, ticks hooks
    contract.lua        -- coverage %, findings, payout math
  ui/
    draw.lua            -- glyph-grid renderer (map, sidebar, log frame)
    log.lua             -- message ring buffer
    menu.lua            -- generic vertical list-picker widget
    layout.lua          -- the 80x30 cell geometry constants
  defs/
    init.lua            -- def loader: registers tables, resolves copy_from
    terrain.lua         -- floors, walls, doors, sky
    items.lua           -- slice item set
    features.lua        -- caches, extraction beacon
    flavor.lua          -- event-keyed narration template pools
  util/
    rng.lua             -- seedable PRNG (no math.random)
    grid.lua            -- idx<->xy helpers, neighbors, line, flood fill
  tests/
    run.lua             -- tiny assert runner: `lua tests/run.lua`
    test_substrate.lua, test_fov.lua, test_gen.lua, test_contract.lua,
    test_rng.lua
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
