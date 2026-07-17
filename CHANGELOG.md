# Changelog

Notable changes to Sky Islands, release by release. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versioning is
`MAJOR.MINOR.PATCH` by feel rather than strict semver (this is a
prototype, not a library).

## [Unreleased]

## [1.4.0] - 2026-07-14
### Added
- The trading triangle (SI-0006a): once free, the travel agent on the
  Tether pier will sell you passage to the **Conglomerate Core** — which
  pays silly money for frontier goods and drowns in cheap manufactured
  stock — and the **Patrol Outpost** on the Line, hungry for hull plate,
  medicine, and anything edible. Fares cost credits AND cycles: markets
  move while you fly. Each destination has its own store, its own
  contract board, and a rentable room (bunk + lockbox, per-cycle rent,
  lapses if you can't pay — resting away from home never saves).
  Debtors fly company routes only.
- A retired trader drinks at the Core and will tell you how the spread
  works, roughly in order of how much money it will make you.
- Passage out: the Core's agent sells an out-of-sector ticket. Buy it
  and the surveyor retires — a real ending, standing in for a deeper
  one.

- **Portraits**: people have faces now. Talking to someone frames
  their portrait beside the conversation, and looking at them ([x])
  pops it at the map's corner. The store runner's is the first real
  one (96x96, Eric's art); everyone else wears the placeholder until
  their sitting.
- Debt is payable only at the company's own counter on the Tether —
  the Core does not accept payments on someone else's ledger.
- Ports read as PORT in the sidebar (not SURVEY); the manumission
  letter no longer overlaps its own banner.

### Fixed
- Look ([x]) now sees people — every character has a proper
  description — and long descriptions wrap into the log area instead
  of running off the screen.
- The "a structure—" survey beat no longer fires at the Tether or in
  towns, where buildings are hardly news.
- Store screen: the hint and market lines get a solid backdrop (map
  glyphs no longer show through the lettering).
- Trading from a conversation hides the dialogue box while the store
  is open instead of stacking the two.
- Arriving at a destination no longer maroons you in open sky (the
  authored arrival cell was being skipped; saves that recorded a bad
  arrival self-heal on load).

## [1.3.0] - 2026-07-12
### Added
- People at the Tether (SI-0005): the store runner and quest broker now
  stand at their posts, and visitors — a ship's quartermaster, a tourist
  from the Core, a wildlife researcher — dock at the pier berths some
  cycles (the quartermaster near-always while a patrol ship is in for
  repairs). Press [T] next to someone to talk: greeting, a few topics,
  a trade option for the ones willing (small stock, steep spread), and
  goodbye. People are solid — you walk around them, not through them —
  and greetings change once your account is closed.
- Veteran charters: with the indenture cleared, the contract board gains
  a fourth, deep-sky offer at a premium fee. The quest broker was telling
  the truth.
- The store runner's trade opens the store itself — talk to him or use
  the counter, same shelves either way. Station glyphs became furniture
  (a gold store counter, a blue contract desk) now that actual people
  stand beside them.

## [1.2.0] - 2026-07-11
### Added
- Latent island features (SI-0003): islands can now carry an old
  factory, ore deposit, magical inscription, freshwater spring, or
  grand pre-Fracture ruin — worth nothing to use yet, worth real money
  to report. Big features are surveyed on sight; deposits and
  inscriptions demand assay work on the tile ([Space], costs a turn).
  Bounties are itemized on the survey letter under a "notable features"
  line, separate from cache bounties. Nastier islands carry better
  bones.
- Feature footprints (SI-0023): the big latent features now occupy real
  space — the grand ruin is a walled shell of pre-Fracture masonry with
  ways in, the factory a rubble-floored hulk, the ore deposit a cross
  of broken stone, the spring a small pool. Masked prefabs (not just
  rectangles); spotting any part of one surveys it, and assay work can
  be done from anywhere inside it. Island generation routes the beacon
  and caches around their walls — and a cache can legitimately turn up
  inside a ruin.
- Sleep transition (SI-0013): the bunk asks first (y/n, with [G] to
  open the lockbox), then a black wipe rolls in from the left and the
  night holds at full dark — "you sleep. [Space] rise" — for as long as
  you like (the save/heal/hunger tick happens at dark). Space brings
  the morning sweeping back in.

## [1.1.0] - 2026-07-11
### Added
- Title screen with art banner (art banner -> instructions -> game),
  backed by a new `art-src/` pipeline (rough/ready folders + an
  Aseprite-backed sprite packer). Updated title art and sprites ship
  with this release.
- **Market events at the company store** (SI-0002): multi-cycle economic
  events with diegetic causes — a mauled patrol ship buying repair goods,
  food shortfalls, a herb glut, looted pirate wreckage sold cheap. Events
  shift both sides of the counter by semantic demand level (all numbers
  in `defs/economy.lua demand_levels`), can thin or flood restock, and
  are announced by shopkeeper gossip (new overlay) the first visit
  they're news. Event text lives in `defs/econ_events.lua` as
  human-editable tables (current text is stubs pending Eric's rewrite).
- New trade goods: hull plate, tin of sealant, insulated wiring,
  medicinal herbs (foragable from some bushes; a weak usable heal).
  Added to cache loot tables and the store's rotation.
- Company store overhaul: deep reserves (60 slots, was 14), data-driven
  restock — staples plus a random grab bag each cycle — and a scrolling
  transfer pane with demand markers (^ dear / v cheap) plus a "word at
  the counter" line naming the active event.
- Leaving an island now asks first: a y/n confirm on the extraction
  beacon before the survey is submitted and the skiff called (SI-0011).
  The confirm overlay (`game/states/confirm.lua`) is generic and
  reusable; it deliberately ignores Space so a double-tap can't blow
  through it. From the prompt, [G] detours into the skiff hold to check
  cargo before deciding (SI-0016).

### Fixed
- Inventory screen: using an item no longer resets the selection to the
  top — the cursor stays on its slot, clamping to the nearest remaining
  one when the stack is consumed (SI-0012).

## [1.0.1] - 2026-07-04
### Fixed
- Contract board (`states/offers.lua`): the fee price overlapped the
  "survey and report" blurb on each row, and the row overflowed the
  panel's right edge. Danger label shortened to one colored word
  (CALM/UNEASY/HOSTILE); columns re-laid out with real gaps.

## [1.0.0] - 2026-07-04
Initial release. The full survey-contract loop, playable start to finish.

### Added
- Generated islands under fog of war (coverage = survey quality),
  buildings/doors, caches, foraging (take-only containers), item
  stacking with slot caps.
- **The Tether** (hub): bunk (sleep/save + stash), company store
  (buy/sell + voluntary debt payments), mission coordinator
  (danger-tiered contracts, sometimes-wrong danger reports), skiff dock.
- Company-town economics: contract payout = fee + bounties + coverage
  bonus, garnished against the indenture; recovered goods stay physical
  and sell at store margins.
- Hunger clock with passive regen, bed rest, and bandages; collapse (from
  hunger or injury) routes through company retrieval — billed, never
  fatal.
- Combat v0: fauna + pre-Fracture guardians, attack-on-sight/wander AI,
  symmetric concealment in thickets, bump attacks, hunting drops meat.
- Manumission: paying the indenture to zero (either path) ends the run
  with an ACCOUNT CLOSED screen; freed agents keep full payouts;
  a later rescue re-opens the account.
- Deterministic world generation and AI (all randomness derives from a
  master seed + domain tag); versioned save/continue.
- Web export + landing page; live at
  https://thunderducky.github.io/sky-islands/.
- 88 headless tests (`sky-islands/tests/run.lua`).

[Unreleased]: https://github.com/Thunderducky/sky-islands/compare/v1.4.0...HEAD
[1.4.0]: https://github.com/Thunderducky/sky-islands/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/Thunderducky/sky-islands/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/Thunderducky/sky-islands/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/Thunderducky/sky-islands/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/Thunderducky/sky-islands/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/Thunderducky/sky-islands/releases/tag/v1.0.0
