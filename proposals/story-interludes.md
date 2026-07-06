# Proposal: Story Interludes & Dialog

*Draft 2026-07-04 — for discussion, nothing here is committed. Reference
point: Alpha Centauri's interludes — full-bleed art, a voice, a few
loaded choices, then back to the game.*

## What it is

A second presentation layer that takes over the whole screen: custom
pixel art spreads with narrated text, optionally a speaker, optionally
choices that change the game state. Three layouts, one system:

1. **Interlude** (the AC one): full-bleed art, text panel over the
   bottom third, Space to advance pages. For big story beats —
   arrivals, the Fracture lore, manumission, first warden.
2. **Conversation**: portrait beside a text column, choice list below.
   For NPCs — the coordinator with an odd off-book offer, the clerk,
   eventually faction contacts.
3. **Vignette** (cheap variant): no art or a small inset, styled text
   only. Lets story beats ship before their art exists — art is an
   upgrade, never a blocker.

## Aseprite setup (the practical numbers)

- **Game canvas is 640×360 at 1x** — everything is authored at final
  pixel size; the engine upscales with point filtering, so pixels stay
  crisp on desktop and web.
- **Full interlude spread: 640×360 canvas.** The text panel covers the
  bottom 132px (11 text rows) — compose so faces/focal points live in
  the top ~228px. (Alternative "cinematic band" if a full spread is too
  much painting: 640×228, engine fills the rest.)
- **Portraits: 96×96** (conversation layout). Optionally a 48×48
  small-portrait set later for log/chrome use.
- **Palette: Apollo, always.** Import from lospec (Aseprite palette
  file, or load our `palette.png` directly), work in indexed mode.
  The engine draws sprites RGB-as-is (tint `COLOR_TRUE_WHITE` = no-op),
  so nothing enforces this — it's an art-direction rule, and it's what
  keeps spreads feeling like the same object as the game.
- **Assembly**: everything packs into the single `sprites.png` atlas
  (one per project — engine constraint). Sheet dimensions must be
  multiples of 16. Suggested layout: 2048-wide sheet, spreads in a
  3-across grid (640×3 = 1920, leaving a 128px right-hand column for
  portraits stacked 96×96). 2048×2048 holds ~15 spreads + ~20 portraits.
- **Slices for the registry**: name each spread/portrait as an Aseprite
  *slice*; export slice JSON alongside the PNG. A ~30-line script turns
  that into `defs/art.lua` (`name -> {x, y, w, h}`), so art placement
  never gets hand-typed and re-exporting can't drift.

**Validation step zero — done, 2026-07-05.** Generated checkerboard
hue-gradient `sprites.png` test sheets at 1024/2048/3072/4096/6144/8192,
exported each to WEB, and eyeballed a whole-sheet thumbnail plus native-
scale corner/center crops in an actual browser (a silently-clamped
texture shows as corruption at the far offsets even with no console
error — a screenshot check, not just a build check).

**Result: every size through 8192×8192 rendered correctly, zero
corruption, on this machine** (Chrome, Apple M4 Max, WebGL reports
`MAX_TEXTURE_SIZE = 16384`). No errors at any size; the 6144/8192 sheets
just took longer to decode before the first frame (several seconds of
black before the click-to-play gate appears at the largest sizes — a
loading-screen concern, not a correctness one).

Caveat this doesn't resolve: 16384 is a high-end desktop ceiling; older
integrated GPUs and mobile Safari/WebView commonly cap at 4096, some
older mobile at 2048. We tested our own hardware's headroom, not the
floor across devices this might ship to.

**Decision: cap the atlas at 4096×4096.** Corroborated by the engine's
own source — `src/assets.rs` has a `MAX_SAFE_SPRITE_DIM` constant
(currently `8192`) with a comment from the author: "WebGL and older/
mobile GPUs commonly cap at 8192 (or less)... a sheet past the GPU
limit uploads clamped, so any sprite sourced beyond it samples black
with no error" — literally the failure mode we built the test to catch,
already anticipated upstream. Since even the engine's own conservative
default is a "some devices are lower" hedge, 4096 — half that, and
matching the mobile ceiling our own research note called out — is the
right place to plant the flag rather than riding the edge of a guess.
8192 stays available as a validated-on-desktop escape valve if content
ever outgrows 4096, not a first resort.

## Research: loading textures beyond `sprites.png`

Checked against the engine's actual Rust source (`assets.rs`,
`session.rs`, `vfs.rs`), not just its docs — and the answer is
genuinely small.

**The draw calls are already texture-agnostic.** `gfx.spr`/`gfx.sspr`
are thin Lua closures that borrow one `Option<&Texture2D>`
(`sprites_ref`, captured from the single `SpriteSheet`) and call
raylib's `draw_texture_rec`/`draw_texture_pro`. Nothing about those
raylib calls is specific to *which* texture — they take any
`&Texture2D`. The "one sheet" limit is entirely in what gets loaded and
handed to the closure, not in how drawing works.

**The multi-file loading pattern already exists — for `sfx/`.**
`VirtualFs` already has `sfx_stems() -> Vec<String>`, `read_sfx(stem)`,
and `sfx_manifest()` (mtimes), implemented for both the dev (disk) and
bundled (export) backends. That's exactly the shape a directory of
named story-art images would need — `image_stems()` / `read_image(name)`
/ `image_manifest()` — as a copy of a pattern that's already proven to
work in both the live-reload dev flow and the export/bundle flow.

**The patch, concretely:**
1. `VirtualFs`: add the sfx-shaped trio for an `images/` directory (2
   trait impls, ~30 lines each, following `sfx`'s exactly).
2. `ImageBank` struct paralleling `SpriteSheet`: `HashMap<String,
   Texture2D>`, loaded via the *same* `load_texture_and_pixels`-style
   decode-and-upload call already used for `sprites.png`.
3. Two new Lua calls: `gfx.load_image(name) -> ok` (loads into the bank
   if not already resident) and `gfx.dspr(name, sx,sy,sw,sh,dx,dy,...)`
   (identical body to `sspr`/`sspr_ex`, resolving the texture from the
   bank instead of the `sprites_ref` singleton).
4. Bundle export: sweep `images/` into the bundle the same way
   `bundle.rs` already sweeps `sfx/`.

No fighting the engine's design, no unsafe, no new lifetime puzzles —
it's the sfx pattern, transposed. Rough estimate holds at "about a
day," now backed by reading the code rather than guessing. Since Usagi
is public domain, this could even go upstream as a real PR rather than
staying a private fork.

**We don't need this yet.** 4096² already gives room, and the layered-
compositing approach below stretches that room further before the
patch becomes necessary.

**Concrete atlas budget and allocation**: see `proposals/art-pipeline.md`
Part 1 — 36 spread slots + 64 portrait slots (37.6% of the sheet),
using the visible-band optimization below.

## Making the budget go further (no engine changes needed)

The atlas cap is exactly the kind of constraint Eric wants leaned into
— it forces curating what's *worth* a unique pixel, and rewards reusable
pieces over one-off paintings. Three techniques, all buildable today
with calls we already have:

- **Flat/gradient color layers under sprite detail.** Most illustrated
  compositions are mostly sky, wall, ground — exactly what
  `gfx.rect_fill` / `gfx.clear` / a manual per-row gradient (see the
  title screen's letter-gradient in `intro.lua` for the technique
  already in the codebase) render for free, zero atlas cost. Only the
  silhouettes and focal detail need real pixels on top. A 640×360
  interlude might spend its whole art budget on a 200×150 character
  and prop cutout, procedurally-backed.
- **Mosaic composition from a shared piece library.** Instead of one
  unique 640×360 painting per scene, build scenes from a kit of reusable
  tile-sized pieces (a sky band, three cloud shapes, a generic wall
  texture, a handful of expression variants for a recurring speaker)
  assembled via multiple `sspr` calls per frame. Cost stops scaling with
  *scene count* and starts scaling with *how many distinct pieces exist*
  — the same content-reuse principle as `defs/` copy_from, applied to
  art. A returning character's face costs nothing the second time.
- **Parallax/layer decomposition.** A step past mosaic: split a spread
  into 2–4 depth layers (backdrop gradient, midground silhouette,
  foreground character) drawn back-to-front each with its own small
  reusable piece set. Buys subtle depth (a slight offset or scroll
  between layers) for free, and layers are individually reusable across
  scenes in a way one flattened painting never is.

**Explicitly out of scope for this proposal** (Eric's call, and
correctly so — this is its own research topic): anything *automatic* —
segmenting a painted spread into reusable parts after the fact,
content-aware packing, procedural variation of a base piece. Worth
returning to once we have enough real scenes to know what we'd actually
want automated. For now: art-direct the reuse by hand, the same way
`defs/terrain.lua` hand-picks what `copy_from`s from what.

**Engine constraint, checked in source**: one `sprites.png` is the
entire texture API — no `load_image`, no second sheet, no render
targets. (It does hot-reload on save, so the Aseprite iteration loop is
instant.) If the atlas ever genuinely cramps, the escape hatch is the
same one reserved for Rust kernels: extend the engine (public domain)
with `gfx.load_image(path) -> handle` — ~a day of work, upstreamable.
The slice-JSON registry keeps the art pipeline identical either way:
`defs/art.lua` would just store filenames instead of rects.

## System design (fits what we have)

- **A state, like everything else**: `states/interlude.lua` pushed onto
  the stack — play freezes underneath, Backspace does nothing (story is
  modal), Space advances, choices use the same j/k + Space grammar as
  every menu we have. Typewriter text via the state `update(dt)` hook
  (first Space completes the page, second advances — standard).
- **Content-first, like everything else**: scenes are Lua tables in
  `defs/story.lua`:

  ```lua
  { id = "first_warden",
    trigger = { event = "creature_notice", def = "shard_warden", once = true },
    pages = {
      { art = "warden_closeup", speaker = "field notes",
        text = "It was here before the company. It will be here after..." },
    },
    choices = {
      { label = "Back away slowly", effects = {} },
      { label = "Sketch it for the record", effects = { credits = 15, flag = "sketched_warden" } },
    } }
  ```

- **Triggers piggyback on the flavor event stream**: `flavor.emit`
  already fires at every interesting moment (cache_open, manumitted,
  rescued, creature_notice, game_start, hub_arrive...). A story hook
  checks each emit against scene triggers — no new event system, and
  every future flavor event is automatically a story hook.
- **Effects are a small verb set** (credits/debt/items/set_flag to
  start) — deliberately the seed of the control-plane verb list from
  DESIGN.md.
- **Flags persist**: `State.persist.flags` (additive save change,
  defaults `{}` on old saves). Seen-scenes live there too, so `once`
  survives save/load. Deterministic: no RNG in story (variants, if ever,
  derive from master + scene id).
- **Headless-testable**: scenes are data; the runner is pure state-stack
  logic. Unit tests: triggers fire once, choices apply effects, flags
  survive a save round-trip, every referenced art name exists in
  `defs/art.lua` (load-time cross-check, same as loot tables).

## Scope sketch

- **v1 slice**: vignette layout (no art needed) + trigger/flag/effect
  plumbing + one real scene wired to `manumitted`. Proves the whole
  pipe. ~a session.
- **v2**: sprites.png pipeline + interlude layout + slice-JSON script +
  Eric's first spread (suggest: the manumission scene or the skiff
  arrival at The Tether — both bookend-worthy).
- **v3**: conversation layout + portraits + a coordinator scene with
  a choice that matters (an off-book contract?).

## Open questions

- Interruption rules: can a story fire mid-mission (warden sighting),
  or only at safe points (hub, mission start/end)? Lean: both, but
  mid-mission scenes never fire while adjacent to a hostile.
- Skippability: settings flag for "seen it" replays on later runs?
- Do choices ever gate on inventory/flags (show-but-disabled vs
  hidden)? Lean: hidden until we need otherwise.
- Art count ambition for the first pass — 3 spreads is a lot of pixel
  art; the vignette layout means the writing can run ahead of it.
