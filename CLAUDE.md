# Jump Coins

A World of Warcraft addon and incremental game: jumping earns coins, and coins buy upgrades. Several people work on this repo, each with their own Claude sessions. Read [ROADMAP.md](ROADMAP.md) for the plan.

## Design rule

**Every coin comes from a jump.** Upgrades multiply what a jump is worth; nothing produces coins on its own. Push back on features that break this.

Addons can't press keys or move the character, so never design anything that jumps for the player.

## Team decisions

Settled; don't relitigate them in a feature PR. Changing one needs agreement from both of us and an update here and in ROADMAP.md.

- **Saves are split.** Coins, upgrades and stats are per character (`JumpCoinsDB`). Prestige (Phase 4) will be account-wide in a separate `## SavedVariables` table.
- **Plain code, no libraries.** No Ace3, LibDBIcon or other libraries.
- **Phase 2 is a light nudge.** Situational multipliers stay around 1.1×–1.5×.
- **Theme is plain coins.** Coins, upgrades and Feathers; no story theme or themed naming.

## Environment

- WoW runs **Lua 5.1**. No `goto`, integer division (`//`), bitwise operators or `utf8` library.
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
- `Debug.lua`: `/jc debug` commands for in-game testing. When a feature adds state worth poking at (a new boost, a zone list), add a debug command for it.
- `Slash.lua`: `/jc` commands.

Modules don't call each other's UI directly. Gameplay code fires events (`COINS_CHANGED`, `UPGRADE_BOUGHT`, `JUMP`) and UI code listens. When adding a file, add it to `JumpCoins.toc` in the right load order.

## Saved variables

Progress is per character in `JumpCoinsDB`. Any change to its shape needs:

1. A bump to `ns.SAVE_VERSION` in `Core.lua`.
2. A migration in `MIGRATIONS[newVersion]` that upgrades old saves without losing progress.
3. A test that loads an old-format save.

Two branches may both claim the same next version number. **Whoever merges second renumbers their migration** to come after the one already on `main`.

## Checks

Run these before opening a PR. CI runs the same commands and they must pass to merge.

```bash
luacheck .
```

```bash
luajit tests/run.lua
```

```bash
luajit tools/sim.lua
```

- `tests/run.lua` stubs the WoW API. When code uses a new WoW function, add a stub there and its name to `read_globals` in `.luacheckrc`.
- Add tests for new gameplay logic, upgrades and migrations.
- `tools/sim.lua` simulates a player buying upgrades and fails if the pacing targets (ROADMAP.md) are missed. Any change to upgrade costs, growth or effects, or new upgrades, must keep it passing, and the PR should include its output. Try a casual (`luajit tools/sim.lua 2.5 6`) and a skilled player (`1.1 40`) too. If the targets themselves should change, update them in both ROADMAP.md and `TARGETS` in the simulator.
- Tests should read prices and effects from `ns.UPGRADES_BY_ID` rather than hard-coding them, so balance changes don't break mechanics tests.
- A project hook runs luacheck on every Lua file you edit. If it reports problems, fix them before moving on.

## Workflow

Work is tracked in GitHub issues, and two people's Claudes work on this repo at once. To avoid building the same thing twice:

1. Before starting, run `gh issue list` and pick an issue nobody is assigned to. If the work has no issue, create one.
2. Claim it before writing code: `gh issue edit <number> --add-assignee "@me"`. If someone else is assigned, stop and ask.
3. Work on a branch named after the issue, for example `2-zone-bonus`. Never push to `main`; it's protected.
4. Open a PR that says `Closes #<number>`. Fill in the template, including the in-game checks from [TESTING.md](TESTING.md) that apply. If nobody has run it in game, say so and add the `needs in-game test` label.

Also:

- One feature per branch and PR. Keep PRs small so the other person's branch rebases easily.
- Keep upgrade numbers (costs, growth, effects) in the definitions table, and note balance changes in the PR.
- If an issue's notes conflict with the team decisions above, the decisions win; point out the conflict in the issue.
