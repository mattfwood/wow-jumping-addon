# Jump Coins

A World of Warcraft addon and incremental game: jumping earns coins, and coins buy upgrades. Several people work on this repo, each with their own Claude sessions. Read [ROADMAP.md](ROADMAP.md) for the plan.

## Design rule

**Every coin comes from a jump.** Upgrades multiply what a jump is worth; nothing produces coins on its own. Push back on features that break this.

Addons can't press keys or move the character, so never design anything that jumps for the player.

## Environment

- WoW runs **Lua 5.1**. No `goto`, integer division (`//`), bitwise operators or `utf8` library.
- No libraries (no Ace3) unless the team decides otherwise.
- The addon must work on Classic and Retail clients (see `## Interface` in `JumpCoins/JumpCoins.toc`). Use only APIs that exist on both, and guard optional ones (`if SOUNDKIT and ... then`).
- You cannot run the game. Anything visual or API-dependent is unverified until someone tests it in game; say so in the PR.

## Code layout

Files in `JumpCoins/` load in TOC order and share state through the addon namespace (`local _, ns = ...`). Don't create new globals except saved variables and slash command registrations.

- `Core.lua`: event bus (`ns.On`, `ns.Fire`), saved variables, save migrations, `ns.Print`.
- `Format.lua`: `ns.FormatNumber`, `ns.FormatPercent`. Always use these for numbers shown to players.
- `Upgrades.lua`: upgrade definitions in `ns.UPGRADES`, costs, buying. New upgrades go here.
- `Jump.lua`: jump detection, combos, crits, payouts. Keep payout math in pure functions (like `ns.CalculateJump`) so it's testable.
- `UI.lua`: coin display, combo counter, crit popup.
- `Shop.lua`: shop window.
- `Slash.lua`: `/jc` commands.

Modules don't call each other's UI directly. Gameplay code fires events (`COINS_CHANGED`, `UPGRADE_BOUGHT`, `JUMP`) and UI code listens. When adding a file, add it to `JumpCoins.toc` in the right load order.

## Saved variables

Progress is per character in `JumpCoinsDB`. Any change to its shape needs:

1. A bump to `ns.SAVE_VERSION` in `Core.lua`.
2. A migration in `MIGRATIONS[newVersion]` that upgrades old saves without losing progress.
3. A test that loads an old-format save.

Two branches may both claim the same next version number. **Whoever merges second renumbers their migration** to come after the one already on `main`.

## Checks

Run both before opening a PR. CI runs the same commands and must pass to merge.

```bash
luacheck .
```

```bash
luajit tests/run.lua
```

- `tests/run.lua` stubs the WoW API. When code uses a new WoW function, add a stub there and its name to `read_globals` in `.luacheckrc`.
- Add tests for new gameplay logic, upgrades and migrations.

## Workflow

- Never push to `main`; it's protected. Work on a branch and open a PR.
- One feature per branch, ideally tied to a GitHub issue or roadmap item.
- Keep upgrade numbers (costs, growth, effects) in the definitions table, and note balance changes in the PR.
- In the PR, fill in the "Tested in game" section honestly. If nobody has run it in game, say so.
