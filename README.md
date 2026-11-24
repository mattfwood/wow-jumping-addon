# Jump Coins

A World of Warcraft incremental game addon: every jump earns coins, and coins buy upgrades that make each jump worth more. See [ROADMAP.md](ROADMAP.md) for where it's headed.

## Install

Copy or symlink the `JumpCoins` folder into your WoW AddOns directory. For example:

```
/Applications/World of Warcraft/_classic_era_/Interface/AddOns/JumpCoins
```

Use the folder for your game flavor (`_retail_`, `_classic_`, `_classic_era_`, and so on).

## Playing

- A small draggable window shows your coins. Hover over it for your stats; click it to open the shop.
- Combo stacks and crits show on the window as they happen.

### Upgrades

| Upgrade | Effect per level | Starting cost | Cost growth |
| --- | --- | --- | --- |
| Spring Boots | +1 coin per jump | 10 | ×1.15 |
| Rhythm | +5% per combo stack. Jumps within 1.5s build a combo, up to 10 stacks. | 50 | ×1.25 |
| Lucky Landing | +2% chance for a jump to pay 10× (max level 25) | 100 | ×1.35 |

### Commands

- `/jc` or `/jc toggle` shows or hides the window.
- `/jc show` and `/jc hide` show or hide it directly.
- `/jc shop` opens the shop.
- `/jc lock` locks or unlocks dragging.
- `/jc count` prints your totals in chat.
- `/jc resetpos` moves the window back to its starting spot.
- `/jc reset confirm` wipes all coins, upgrades and stats.

## How jumps are detected

The addon hooks `JumpOrAscendStart`, which runs when you press the jump key. A press doesn't count while you're falling, swimming, flying or on a flight path. Two presses within 0.25s count as one. Holding the jump key down counts only the first hop.

## Code layout

Files in `JumpCoins/` load in the order listed in `JumpCoins.toc`:

- `Core.lua`: shared namespace, event bus (`ns.On` / `ns.Fire`), saved variables and save migrations.
- `Format.lua`: big-number and percent formatting.
- `Upgrades.lua`: upgrade definitions, costs and buying. Add new upgrades here.
- `Jump.lua`: jump detection, combos, crits and payouts.
- `UI.lua`: coin display, combo counter and crit popup.
- `Shop.lua`: shop window.
- `Slash.lua`: `/jc` commands.

Progress is saved per character in `JumpCoinsDB`. When the save format changes, bump `ns.SAVE_VERSION` in `Core.lua` and add a migration.

## Tests and lint

The tests fake the WoW API and run the addon outside the game. They need LuaJIT, which uses the same Lua version as WoW. luacheck catches misspelled globals and other mistakes that would otherwise only show up in game.

```bash
brew install luajit luacheck
```

```bash
luacheck .
```

```bash
luajit tests/run.lua
```

CI runs both on every pull request, and they must pass before merging.

## Contributing

`main` is protected: work on a branch and open a pull request. Project rules for people and Claude alike are in [CLAUDE.md](CLAUDE.md). Work is tracked in [GitHub issues](https://github.com/mattfwood/wow-jumping-addon/issues): assign yourself before you start. [TESTING.md](TESTING.md) has the in-game checklist and `/jc debug` commands for testing quickly.
