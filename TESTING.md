# Testing in game

CI and Claude can't run WoW, so a person checks pull requests in game. This takes a few minutes with the debug commands. In the PR, note your client and version, and which sections you ran.

## Setup

1. Symlink or copy `JumpCoins/` into your `Interface/AddOns` folder and check out the PR branch.
2. Log in on a test character, or back up `WTF/Account/<account>/<realm>/<character>/SavedVariables/JumpCoins.lua` first. Debug commands change real progress.
3. If the game was already running, `/reload` after switching branches.
4. Watch for Lua errors: `/console scriptErrors 1`, or use BugSack.

## Debug commands

| Command | What it does |
| --- | --- |
| `/jc debug coins 1e6` | Set coins |
| `/jc debug add 500` | Add coins |
| `/jc debug level rhythm 10` | Set an upgrade's level (id or name) |
| `/jc debug jump 50` | Simulate 50 chained jumps ending now |
| `/jc debug crit` | Simulate one guaranteed crit |
| `/jc debug status` | Print coins and upgrade levels |

## Core checklist (every PR that touches addon code)

- [ ] Addon loads with no Lua errors and isn't marked out of date.
- [ ] Real jumps on the ground add coins. Pressing jump while swimming, flying, mid-air or on a flight path adds nothing.
- [ ] The coin window drags, stays put after `/reload`, and a click (not a drag) opens the shop.
- [ ] `/jc debug coins 1e6`, then buy each upgrade in the shop. The coin count drops, the level and "Next" text update, and buttons grey out when you can't afford them.
- [ ] `/jc debug level rhythm 5`, then jump repeatedly. The combo counter shows and disappears about 1.5s after you land and stop jumping.
- [ ] Mid-combo, jump off a ledge or down a slope. The combo survives the long fall.
- [ ] `/jc debug jump 25`, then wait. About 1.8s later a gold "25x COMBO!" banner appears at the top of the screen with the raid warning sound and a chat line, then fades out. `/jc debug jump 60` shows purple "EPIC", `/jc debug jump 120` orange "LEGENDARY".
- [ ] `/jc debug crit` shows the "+N CRIT!" popup and plays the coin sound.
- [ ] Big numbers format correctly (`/jc debug coins 123456789` shows 123M).
- [ ] `/reload`, and coins, upgrades and window position are kept.
- [ ] Escape closes the shop.
- [ ] The shop's **Reset progress** button opens a confirmation. Cancel (or Escape) changes nothing. Reset sets coins, upgrades and stats to zero, and the shop and coin window update straight away.

## Save format changes

If the PR bumps `SAVE_VERSION`:

- [ ] Start from a save made on `main` (log in on `main`, jump a bit, log out), then switch to the branch and log in. Progress is kept and nothing errors.

## Feature-specific checks

Add a short list of extra checks for the feature in the PR description, for example "jump in two new subzones; each pays the bonus once".
