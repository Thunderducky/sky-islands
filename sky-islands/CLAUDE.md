# Sky Islands — agent notes

ASCII roguelike on the Usagi engine (Rust host, Lua 5.5, raylib). Read in
this order when context matters: `../DESIGN.md` (game design, tagged
settled/leaning/proposed) → `SPEC.md` (technical contracts) → this file
(operational how-to). `../IDEAS.md` is the raw ideation log.

## Commands

- Run: `usagi dev .` (live reload on save; F5 = hard reset) or `usagi run .`
- Tests: `lua tests/run.lua` from this directory — headless, no engine,
  system Lua 5.4. ALWAYS run after changes; keep at 0 failures.
- Engine API reference: `meta/usagi.lua` (typed stubs), `USAGI.md` (docs).
  Grep those before assuming an engine call exists.
- Tasks: `dev/task.sh` (see "Task tracking" below). Test scenarios:
  `dev/scenario.sh {list|save|load|restore}` — swaps the live save between
  named dev fixtures (see TECHDEBT.md: these are regenerated, not migrated).
- Deploy: `usagi export --target web`, unzip over `../docs/play/`, fix the
  page `<title>` back to "Sky Islands", commit, push (see SPEC "Web
  export & deployment"). Live at https://thunderducky.github.io/sky-islands/
  — repo github.com/Thunderducky/sky-islands (Eric's PERSONAL account
  Thunderducky; never TeleVet). Repo root is `../` (roguelike/).
- **Releases**: every user-visible change gets a `../CHANGELOG.md` entry
  under `[Unreleased]`, promoted to a version + date when tagged. Tag
  with `git tag -a vX.Y.Z -m "..."`, push tags (`git push origin
  --tags`), and cut a GitHub release (`gh release create vX.Y.Z --notes
  "..."`) from that changelog section. Bugfix = patch bump. If the fix
  touches anything under `sky-islands/` outside `tests/`, re-export the
  web build (previous bullet) BEFORE tagging — the tag should match
  what's actually live.

## Task tracking

`dev/task.sh {new|list|show|move}` — kanban-in-folders under `tasks/`.
Each task is a markdown file, id `SI-####` stamped in its frontmatter and
filename; `move` relocates the file and rewrites its `status:` line.

- **backlog**: scratch ideas, can be disparate and half-formed. Low bar —
  just capture it.
- **todo**: promoted once it's scoped enough that Claude could implement
  it, AND Eric has said yes we definitely want to try this. Both bars,
  not just one.
- **in-progress**: meant to stay rare — actively building + verifying,
  ideally ~1 at a time. `task.sh move` warns (doesn't block) if something
  else is already here.
- **completed**: verified + accepted. Source material for CHANGELOG
  entries (see Releases below) — don't let these pile up unmined.
- `--spike` on `new` marks investigation work (try it on a branch, see
  what's learned, not committed to landing) rather than committed
  work — still moves through the same four folders.

## Hard rules (violating these breaks invisible contracts)

1. **Engine isolation**: only `main.lua`, `ui/`, and `game/states/` may call
   `gfx.*` / `input.*` / `usagi.*`. `world/`, `sim/`, `util/`, `defs/` are
   pure Lua — that's why tests run headless and modules are delegable.
2. **Substrate single-owner**: nothing outside `world/substrate.lua` touches
   raw layer arrays; always `sub.get/set/feature_at/pile_at`. This is the
   future Rust-kernel escape hatch's contract (see SPEC).
3. **No `math.random` anywhere.** All randomness via `util/rng.lua`
   instances; islands must be pure functions of their seed. Split streams
   (`rng:fork(tag)`) so cosmetic rolls never perturb generation.
4. **Glyphs are printable Basic Latin only** (0x20–0x7E). The bundled font
   silently skips unknown codepoints — an invisible glyph is a confusing bug.
5. **Reserved keys**: the engine pause menu intercepts Esc / P / Enter.
   Never bind them. Space = confirm/act, Backspace = close overlay.
6. **Lua 5.4 compatibility** in `world/ sim/ util/ defs/ tests/` (system
   Lua runs the tests). 5.3+ features (`//`, bitwise) are fine.
7. **Numbers live in defs, not code**: economy knobs in `defs/economy.lua`,
   stack sizes on item defs, slot caps on feature defs. Tuning = content
   editing.
8. Mutable game state lives ONLY in the global `State` (survives live
   reload); modules hold no state. `_init` rebuilds `State` from scratch.
9. **Determinism**: same seed + same actions = same world. All randomness
   derives from `(State.master, "domain:entity")` via `rng.derive`. NO
   `pairs()` where iteration order feeds RNG draws or mutation order —
   iterate by index (rendering-only `pairs()` is fine). No wall clock in
   sim code.
10. **Snapshots own their data**: `game/save.lua` deep-copies on both
    snapshot and restore — never share stack-list/array references across
    the save boundary. Saves are versioned and carry their own terrain
    id→int map; new player fields must default on load.

## Architecture map

- `main.lua` — engine callbacks, key table, builds State. Wiring only.
- `game/state.lua` — state STACK; overlays draw over play, top gets input.
- `game/states/` — intro (new/continue), play, transfer (two-pane
  container/shop/forage UI), inventory (pack + hunger meter + eat),
  examine, offers (contract board), report, rescued (retrieval invoice).
  Each: `{enter?, leave?, update?, draw, key?}`.
- `game/run.lua` — flow: new_game/continue_game → hub; offers();
  start_mission; return_to_hub (cycle++, restock, autosave); rescue()
  (collapse → debt + bunk). `game/save.lua` — versioned snapshots
  (see hard rule 10).
- `world/substrate.lua` — island + dense layers (terrain, fog) + sparse
  (features, item_piles). `world/islandgen.lua` — seed → island pipeline
  (incl. forage placement). `world/prefab.lua` + `world/hubgen.lua` —
  ASCII-authored maps; the hub (The Tether). `world/fov.lua` —
  shadowcasting; fog: 0 unknown / 1 remembered / 2 visible; sky is
  fog-exempt (always drawn).
- `sim/actions.lua` — turn verbs (move — incl. bump attack, toggle_door,
  wait, submit). `sim/turn.lua` — applies verb, advances clock, hunger
  tick, CREATURE PHASE, collapse checks (hunger or hp<=0 return
  "collapse"). `sim/needs.lua` — hunger states, passive regen, use()
  (nutrition eats / heal bandages). `sim/creatures.lua` — AI
  (wander/hunt, symmetric concealment via `conceals` terrain flag,
  per-turn derived RNG) + combat math + drops. `sim/inventory.lua` —
  slot/stack math (every holder is a capped slot list; only caps
  differ). `sim/contract.lua` — settle(): fee + bounty + coverage bonus,
  garnish clamped to debt owed; goods stay physical (company-town
  model). `defs/creatures.lua` — the roster; danger tiers scale spawns
  (economy.danger). Manumission at debt 0; rescue re-indentures.
- `ui/layout.lua` — THE 78x28 cell grid + margins; all positioning goes
  through `L.text/L.px/L.py`. `ui/draw.lua` — map/sidebar/log renderer.
- `defs/init.lua` — loader: id interning, copy_from inheritance (metatable),
  cross-reference checks that FAIL AT LOAD (keep it that way).
- `flavor.lua` — narration: event key → template pool → `{slot}` fill →
  log. Pools in `defs/flavor.lua`. `emit_once` for one-time beats.

## How to add things

- **Item**: one table in `defs/items.lua` (id, name, glyph, color, value,
  max_stack, desc). Appears in loot via `defs/features.lua` loot_tables.
- **Terrain**: one table in `defs/terrain.lua` (glyph, color, bg, walkable,
  opaque, desc). walkable/opaque are independent — tree = walkable+opaque.
  Reference it from `world/islandgen.lua` to actually place it.
- **Feature** (cache-like): `defs/features.lua` + placement in islandgen.
  Anything with `.loot`/`.stash`/`.stock` list is a container; the transfer
  UI works on it automatically via `container_here` in play.lua. Flags:
  `take_only` (forage; stow refused, emptied feature removed via
  `on_empty`), `prices` on the container (shop). `slots` caps it.
- **Food**: an item def with `nutrition`; **healing item**: `heal`. Both
  used from the inventory screen (Space).
- **Creature**: one table in `defs/creatures.lua` (glyph ASCII, max_hp,
  damage {min,max}, acc, speed mp/turn, aggro_radius — 0 = docile/
  retaliates, drops). Add to spawn mix in islandgen.spawn_creatures or
  economy.danger.spawns. AI behavior itself lives in sim/creatures.lua.
- **Hub amenity / authored map**: add a legend char + row art in
  `world/hubgen.lua` (rows must stay equal-width); container init in
  hubgen's post-stamp loop; interaction wiring in play.lua's `interact()`.
- **Hunger/needs knob**: `defs/economy.lua` `hunger` table + `rescue_fee`.
- **Narration**: add event pool in `defs/flavor.lua`, call
  `flavor.emit("key", {slot=...})` from sim code. Unknown keys log a
  warning, never crash.
- **Turn verb**: entry in `sim/actions.lua` returning an event table, wire a
  key in `game/states/play.lua`. FOV recompute triggers on kinds
  "move"/"door" in turn.lua.
- **Overlay/screen**: state table in `game/states/`, `State.stack:push/
  switch`. Close overlays on Backspace.
- **Economy knob**: `defs/economy.lua` only.

## Testing conventions

`tests/test_*.lua` return `{ name = function(t) ... end }`; helpers:
`t.eq/ok/near/deep_eq`. Runner auto-discovers. Islandgen changes: keep the
40-seed invariant tests passing (reachability, determinism). UI-adjacent
logic gets covered via `tests/test_integration.lua`, which stubs
`gfx/input/usagi` and drives real keys through the state stack — extend it
when adding states or bindings.

## Delegating to cheaper models

Works well: content defs, flavor plumbing, pure util modules, test files —
IF you pin exact API contracts in the prompt (see SPEC's build-order tags).
Keep here: islandgen taste, state wiring, renderer look, anything touching
State shape. Integration risk is interface drift; tests are the net.
