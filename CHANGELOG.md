# Changelog

Notable changes to Sky Islands, release by release. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versioning is
`MAJOR.MINOR.PATCH` by feel rather than strict semver (this is a
prototype, not a library).

## [Unreleased]

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

[Unreleased]: https://github.com/Thunderducky/sky-islands/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/Thunderducky/sky-islands/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/Thunderducky/sky-islands/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/Thunderducky/sky-islands/releases/tag/v1.0.0
