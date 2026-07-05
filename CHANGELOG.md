# Changelog

Notable changes to Sky Islands, release by release. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versioning is
`MAJOR.MINOR.PATCH` by feel rather than strict semver (this is a
prototype, not a library).

## [Unreleased]

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

[Unreleased]: https://github.com/Thunderducky/sky-islands/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/Thunderducky/sky-islands/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/Thunderducky/sky-islands/releases/tag/v1.0.0
