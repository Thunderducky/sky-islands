# Proposal: Art Budget & Pipeline

*Draft 2026-07-05 — speculation, nothing here is committed. Companion to
`story-interludes.md` (that doc covers the dialogue/scene SYSTEM; this
one covers art PRODUCTION PLANNING: how much space we have, what a
tileset would cost if we ever built one, and the tooling to manage
multiple art passes without hand-editing one atlas file).*

Working premise, per Eric: **the main map stays pure text, forever.**
No tilesheet for terrain/items/creatures is planned. That means the
4096×4096 cap from `story-interludes.md` is available entirely for
story art unless we later decide otherwise — which Part 2 argues we
shouldn't.

## Part 1 — Interlude & portrait budget at 4096×4096

**The atlas-space math, per asset type:**

| Asset | Native size | Packed footprint | Notes |
|---|---|---|---|
| Interlude spread | 640×360 canvas | **640×228** | text panel covers the bottom 132px (11 rows × 12px) — pack only the visible band, see below |
| Portrait | 96×96 | 128×128 (padded) | round grid cell, easy slicing |

**Optimization worth calling out**: the text panel in the interlude
layout is opaque and always covers the bottom 132px, so painting (and
packing) that band is wasted atlas space. Authors can still work in a
full 640×360 Aseprite canvas for composition (a character's legs can
extend under the "fold," useful if the crop line ever moves) — just
export/pack only the top **640×228**. That's a 36.7% atlas saving per
spread (230,400px² → 145,920px²) for zero art-direction cost.

**Recommended allocation** (4096×4096 = 16,777,216px² total):

- **Spreads**: a 6×6 grid of 640×228 slots → **36 interludes**,
  occupying 3840×1368px (5,253,120px², **31.3%** of the sheet).
- **Portraits**: an 8×8 grid of 128×128 slots → **64 portraits**,
  occupying 1024×1024px (1,048,576px², **6.25%** of the sheet).
- **Combined: 37.6% of the sheet.** The remaining **62.4%** is
  deliberately left unallocated — not a max-packing exercise.

Why leave well over half unclaimed: portraits are so much cheaper than
spreads (a spread costs 16–25× a portrait) that once spreads are
budgeted, portrait capacity stops being a real constraint — 64 is
already generous for named/recurring speakers, and could be doubled
for a fraction of a percent of the sheet if ever needed. **Spreads are
the one real lever here.** 36 is a solid multi-arc budget (more than
Alpha Centauri ships interludes, for reference) without pre-committing
Eric to more painting than the story currently calls for. Growing past
36 later costs nothing architecturally — it's just more slots in the
same grid, or a second sheet if it ever mattered (see Part 3's
multi-sheet support).

## Part 2 — What a tileset would cost, and why it should stay separate

**Current roster: 34 distinct visual entities** (11 terrain + 10 items
+ 8 features + 4 creatures + the player glyph — counted directly from
`defs/*.lua`, not estimated). The scratch pad's "Next features" list
(equipment, more skills, larger islands) all imply real growth here —
a generous planning ceiling of **~150–200 entities** (roughly 5–6× the
current roster) is a reasonable "even if this triples twice" number.

**Tile-size math, independent of the story-art sheet:**

| Tile size | Footprint | Max tiles @ 4096² | 200 entities = |
|---|---|---|---|
| 16×16 (engine default `sprite_size`) | 256px² | 65,536 | **0.3%** of a sheet |
| 32×32 | 1,024px² | 16,384 | **1.2%** of a sheet |
| 64×64 (chunky, arguably too big for this game) | 4,096px² | 4,096 | **4.9%** of a sheet |

**The finding: a tileset costs almost nothing in space, at any
reasonable tile size, even for a roster far larger than we have today.**
Even co-located with Part 1's budget at the chunkiest size tested
(64×64), a 200-entity tileset would eat under 5% of the sheet — it
would not require removing a single interlude or portrait slot from
the plan above.

**So the case for keeping it separate and moddable was never about
space — it's about everything else**, and the numbers just confirm we
don't have to trade one against the other:
- **Versioning**: story art ships with the game and changes with the
  narrative; a tileset is a visual skin that shouldn't force a
  re-export of story content (or vice versa) every time either changes.
- **Moddability** (Eric's instinct, and the right one — this is
  literally the UltiCa-for-CDDA pattern from the very start of this
  project): a tileset as a swappable file means players choose their
  own, the way CDDA ships ASCII-first with tilesets as an overlay.
- **Scope honesty**: ASCII is the stated aesthetic (`SPEC.md`'s glyph
  rule), not a placeholder. A first-party tileset is real, separate
  scope — worth deferring to a genuine polish phase rather than
  smuggling in as "just some extra atlas space since it's free."

**Mechanically**: a tileset should load through the `gfx.load_image` /
`ImageBank` patch from `story-interludes.md`'s research section — its
own independently-loaded, user-swappable file (e.g. a `tileset.png` a
player drops in, mirroring how CDDA tileset packs work), never packed
into the story-art `sprites.png`. It gets the *same* WebGL safety cap
(≤4096, per the tested/engine-corroborated finding) as its own budget,
entirely independent of story art's.

**Tinting stretches whatever tileset budget we do spend.** Raylib's
`tint` parameter (already exposed via `gfx.spr_ex`/`sspr_ex`, and
already resolving through our Apollo palette via `tint_idx`) multiplies
the sampled pixel by the tint color per channel — a standard modulate
blend. Authored as clean grayscale/white-based silhouettes (shading as
luminance, not baked hue), one base tile can stand in for many
"variants" at runtime: a single generic bird silhouette tinted four
ways covers four species' worth of visual distinction for the storage
cost of one tile. This is the same reuse principle as the mosaic idea
in `story-interludes.md`, applied to creatures/items instead of
scenes — and because tint indices resolve through Apollo, every tinted
variant is automatically palette-consistent for free. Combined with
the space finding above: even a visually varied bestiary is a small,
tint-multiplied tile sheet, not a painting-per-monster commitment.

**Bottom line for Part 2**: don't build this now (matches Eric's
"polish phase" instinct); when we do, build it as a separate moddable
texture via the `ImageBank` patch, size it independently (small either
way), and lean on tinting to multiply a modest tile count into a varied
roster.

## Part 3 — The stitcher (keeping art versions separate until merge)

The problem this solves: hand-editing one shared `sprites.png` directly
means every artist, every draft, every experiment fights over the same
file. The fix is the same pattern this session already used twice (the
Apollo `palette.png` generator, the WebGL size-probe checkerboards) —
**source files stay small and separate; a script assembles the shipped
atlas from them.** Nothing here is built yet; this is the shape it
should take when there's real art to manage.

**Layout:**
```
art-src/                     -- sibling to sky-islands/, not shipped
  interludes/
    manifest.txt              -- ordered list: filename -> slot
    first_warden.png          -- 640x228, exported from Aseprite
    manumission.png
    ...
  portraits/
    manifest.txt
    coordinator.png            -- 128x128
    ...
  tileset/                     -- Part 2's, if/when it exists — SEPARATE
    manifest.txt               -- output, own sheet, own cap, never merged
    ...                           into sprites.png
_preview/                      -- gitignored scratch output, see below
```

**The manifest, not alphabetical order, decides slot placement.** A
plain ordered list per zone (`filename -> slot index`), not "sort
filenames and pack." Nothing save-critical depends on art placement
(unlike terrain ids, which DO need the id-remap discipline from
`SPEC.md` — this is lower stakes), but a stable manifest means adding
one new spread doesn't reshuffle every rect in `defs/art.lua` and turn
a one-line diff into a wall of noise.

**The pack script** (~100–150 lines Python, no dependencies — same raw
PNG read/write approach already used for the palette and test-sheet
generators, directly extendable from code already in this repo):
1. Reads each manifest, verifies every listed PNG matches its zone's
   expected slot size (640×228, 128×128, whatever the tileset zone
   defines) — loud error on mismatch, not a silent stretch/crop.
2. Stamps each into its assigned pixel offset in the output canvas.
3. Writes the merged sheet AND regenerates `defs/art.lua` (name →
   `{x,y,w,h}`) from the same manifest, so code and placement can never
   drift — the same cross-reference-at-load-time discipline `defs/
   init.lua` already applies to loot tables and copy_from.

**Draft-then-commit, for "different versions, merged at the end":**
`--draft` writes to `art-src/_preview/sprites_draft.png` (gitignored)
instead of touching the real `sky-islands/sprites.png` — a draft can be
booted in a throwaway test project (the exact technique from the WebGL
size probe) and reviewed without risk to what's live. `--commit`
promotes a reviewed draft to real with a straight file copy. This
mirrors how this project already treats proposals vs. `DESIGN.md`:
draft freely, promote deliberately.

**When to build it**: not now — there's no art to stitch yet. First
real trigger is whenever the first handful of interlude spreads exist
and hand-placing them in one PNG starts being annoying. Small enough to
build in an afternoon when that day comes.
