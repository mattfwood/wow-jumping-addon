-- Jump: detects jumps, tracks combos and pays out coins.

local _, ns = ...

-- Minimum seconds between counted jumps; guards against double-fires.
local JUMP_DEBOUNCE = 0.25

local lastJumpTime = -math.huge
ns.combo = 0 -- jumps in the current chain (1 = a single jump)

local comboCoins = 0     -- coins earned during the current chain
local comboStartBest = 0 -- best combo before the current chain started
local comboOpen = false  -- a chain of 2+ jumps not yet reported as ended

-- Watches an open combo each frame so COMBO_ENDED fires the moment it runs out.
local watcher = CreateFrame("Frame")

-- Fires COMBO_ENDED(combo, coins, isNewBest) once when a chain of 2+ jumps
-- runs out of time.
function ns.CheckComboEnded(now)
    if not comboOpen or now - lastJumpTime <= ns.COMBO_WINDOW then return end
    comboOpen = false
    watcher:SetScript("OnUpdate", nil)
    ns.Fire("COMBO_ENDED", ns.combo, comboCoins, ns.combo > comboStartBest)
end

local function WatchCombo()
    ns.CheckComboEnded(GetTime())
end

-- Pure payout math, kept separate so it can be tested without the game.
-- `combo` is the chain length including this jump; `isCrit` is the roll.
function ns.CalculateJump(combo, isCrit)
    local base = ns.GetEffect("springBoots")
    local stacks = math.min(combo - 1, ns.COMBO_MAX_STACKS)
    local mult = 1 + stacks * ns.GetEffect("rhythm")
    if isCrit then
        mult = mult * ns.CRIT_MULTIPLIER
    end
    return base * mult
end

function ns.IsComboActive(now)
    return ns.combo > 1 and (now or GetTime()) - lastJumpTime <= ns.COMBO_WINDOW
end

function ns.ComboTimeLeft(now)
    return math.max(0, lastJumpTime + ns.COMBO_WINDOW - (now or GetTime()))
end

-- Counts one jump at time `now`. Returns the coins earned, or nil if the
-- press was ignored by the debounce.
function ns.RegisterJump(now, roll)
    local db = ns.db
    local sinceLast = now - lastJumpTime
    if sinceLast < JUMP_DEBOUNCE then return nil end

    -- Report the previous chain first, in case the watcher hasn't run yet.
    ns.CheckComboEnded(now)

    if sinceLast <= ns.COMBO_WINDOW then
        ns.combo = ns.combo + 1
    else
        ns.combo = 1
        comboCoins = 0
        comboStartBest = db.stats.bestCombo
    end
    lastJumpTime = now

    local isCrit = (roll or math.random()) < ns.GetEffect("luckyLanding")
    local earned = ns.CalculateJump(ns.combo, isCrit)

    db.coins = db.coins + earned
    db.lifetimeCoins = db.lifetimeCoins + earned
    db.totalJumps = db.totalJumps + 1
    if ns.combo > db.stats.bestCombo then db.stats.bestCombo = ns.combo end
    if isCrit then db.stats.crits = db.stats.crits + 1 end

    comboCoins = comboCoins + earned
    if ns.combo >= 2 and not comboOpen then
        comboOpen = true
        watcher:SetScript("OnUpdate", WatchCombo)
    end

    ns.Fire("JUMP", earned, isCrit, ns.combo)
    ns.Fire("COINS_CHANGED")
    return earned
end

-- JumpOrAscendStart fires on the jump key press. It also fires while
-- swimming/flying (ascend) or mid-air, so filter those out.
local function OnJumpPressed()
    if not ns.db then return end
    if IsFalling() or IsSwimming() or IsFlying() or UnitOnTaxi("player") then
        return
    end
    ns.RegisterJump(GetTime())
end

hooksecurefunc("JumpOrAscendStart", OnJumpPressed)
