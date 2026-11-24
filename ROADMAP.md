# Jump Coins roadmap

## Design rule

**Every coin comes from a jump.** Upgrades make each jump worth more; nothing earns coins on its own. This keeps the jump key at the center of the game.

Platform limit: addons can't press keys or move the character, so the game can reward the player but never jump for them.

## Phase 0: Foundation (done)

- Count jumps through the `JumpOrAscendStart` hook. Ignore presses while falling, swimming, flying or on a flight path.
- One coin per jump, a draggable coin display, `/jc` commands.
- Per-character save with separate `coins` and `totalJumps`.

## Phase 1: First upgrades

Goal: give coins something to buy.

- **Shop window** opened from the coin display. Upgrade prices rise with each purchase.
- **Spring Boots:** +1 coin per jump.
- **Rhythm (combo):** jumps chained within 1.5s build combo stacks that multiply coins. A combo counter shows while active.
- **Lucky Landing:** chance for a "crit" jump worth 10×, with a visual pop.
- **Under the hood:** save version number with migrations; big-number formatting (1.2K, 3.4M).

## Phase 2: Jumping around the world

Goal: reward normal play, not just standing in a city mashing space.

- **First jump in a zone** pays a bonus; new subzones pay a smaller one.
- **Jump types:** small multipliers for jumping while mounted, in combat, in a dungeon or in water.
- **Boosts from playing:** a temporary jump multiplier after leveling up, turning in a quest or landing a killing blow.
- **Daily first jump** bonus.

## Phase 3: Passive multipliers

Goal: make time away matter without passive income.

- **Charge** builds over time, including offline (measured with `time()` at login, capped). Each jump spends charge for bonus coins.
- **Generators that boost jumps** instead of producing coins, such as Trampolines adding +x% per jump.

## Phase 4: Prestige ("Ascend")

Goal: long-term progress and a reason to start over.

- **Ascend:** reset coins and upgrades for **Feathers**, based on lifetime coins.
- **Feather shop:** permanent upgrades such as starting coins, a longer combo window, faster charge or automatic purchases.

## Phase 5: Goals and polish

- **Milestones** (100 jumps, 10K jumps, a jump in every zone) with small permanent bonuses.
- **Stats page:** lifetime jumps, best combo, top zones, time played.
- **Minimap button,** sounds and a settings page.
- **Account-wide** prestige or a leaderboard across your characters.

## Decisions

Decided 2026-11-24. These are also in CLAUDE.md so every Claude session follows them.

- **Saves are split.** Coins, upgrades and stats are per character. Prestige (Feathers, Phase 4) is account-wide, so alts start stronger.
- **Plain code, no libraries.** No Ace3 or LibDBIcon, including for Phase 5 settings and the minimap button.
- **Phase 2 is a light nudge.** Situational multipliers stay around 1.1×–1.5×. Normal play pays a bit more, but standing and jumping is still fine.
- **Theme is plain coins.** Coins, upgrades and Feathers, with no story theme for now.

Work is tracked as [GitHub issues](https://github.com/mattfwood/wow-jumping-addon/issues).
