# Sky Islands

An ASCII roguelike about debt. You are a surveyor indentured to the
Meridian Survey Company, charting floating islands out past the safe
lanes. Land, chart under fog of war, open what you find, come back
alive. The company garnishes 60% of everything — but what you haul back
is yours, to sell at their store, at their prices. Work the debt to
zero and you're free. Collapse from hunger or injury and retrieval is,
of course, billable.

Built with the [Usagi engine](https://usagiengine.com/) (Lua 5.5),
46-color [Apollo palette](https://lospec.com/palette-list/apollo),
pure ASCII — the aesthetic, not a placeholder.

## Play

```
cd sky-islands
usagi dev .     # live reload; F5 = hard reset
```

**Controls**: arrows/hjkl move (yubn diagonals) · `g` open container /
loot · `Space` interact (coordinator, beacon, bunk, store) · `i` pack
(Space to eat/bandage) · `x` examine · `o` doors · `.` wait ·
`Backspace` close menus · `Esc` engine pause menu.

## Develop

- Docs: [DESIGN.md](DESIGN.md) (game design) →
  [sky-islands/SPEC.md](sky-islands/SPEC.md) (technical contracts) →
  [sky-islands/CLAUDE.md](sky-islands/CLAUDE.md) (agent/contributor notes).
  [IDEAS.md](IDEAS.md) is the raw ideation log.
- Tests (headless, no engine, Lua 5.4+):
  `cd sky-islands && lua tests/run.lua`

Everything is deterministic: same seed + same actions = same world.
