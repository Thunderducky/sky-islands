# art-src

Source art for the story-art atlas (`sky-islands/sprites.png`). Not
part of the game runtime — this is where art lives before it's baked
into the shipped sheet. See `../proposals/story-interludes.md` and
`../proposals/art-pipeline.md` for the design/budget this feeds.

## The only rule: rough/ vs ready/

```
rough/<zone>/     work in progress. Sketches, references, anything not
                  finished. The packer never looks in here.
ready/<zone>/     finished .aseprite / .ase / .png files. Every run of
                  the packer picks up everything here.
```

Move a file from `rough/` to `ready/` when it's done. That's the whole
workflow — no manifest, no naming convention beyond "the filename
becomes the sprite's name in code" (so name files the way you'd want
to reference them: `first_warden.png`, not `spread_03.png`).

Zones today: `interludes/` (640×228 — the visible band above the text
panel; see art-pipeline.md for why it's not 640×360), `portraits/`
(96×96). Add a new zone by making a matching pair of `rough/<zone>/`
and `ready/<zone>/` folders — `pack.py` discovers zones automatically.

## Packing

```
python3 pack.py            # bakes ready/ into sky-islands/sprites.png
                            # + sky-islands/defs/art.lua
python3 pack.py --draft    # same, but writes to _build/ instead —
                            # review before touching what's live
python3 pack.py --max-size 2048   # override the 4096 safety cap
```

Requires the Aseprite CLI (Steam or itch build — the trial doesn't
have batch mode). `pack.py` looks in the usual install locations
automatically; edit `ASEPRITE_CANDIDATES` at the top of the script if
yours lives somewhere else.

The packer is Aseprite's own bin-packer (`--sheet-type packed`), not a
custom one — it fits mixed sizes tighter than a fixed grid and emits
the name→rect data in the same pass. `defs/art.lua` is fully
regenerated every run; never hand-edit it.

The sheet auto-sizes to whatever content exists — running with 2 files
doesn't pad out to a mostly-empty 4096×4096 canvas. If real content
ever pushes the sheet past the 4096 safety cap, the script warns
loudly rather than silently shipping something that can render as
black sprites on lower-end/mobile GPUs (see art-pipeline.md Part 1 for
why 4096, not the engine's own 8192 ceiling).

`_build/` is scratch output (draft sheets, the intermediate JSON) —
gitignored, safe to delete anytime.
