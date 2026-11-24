-- Jump: detects jumps, tracks combos and pays out coins.
--
-- Combo timing: the combo window starts when you land, not when you press
-- jump, so long jumps and jumps down slopes don't eat into it. WoW has no
-- landing event, so a watcher polls IsFalling() each frame after a jump.

local _, ns = ...

-- Minimum seconds between counted jumps; guards against double-fires.
local JUMP_DEBOUNCE = 0.25
-- If a counted jump never leaves the ground (rooted, stunned), the window
-- starts from the press once this many seconds pass without a takeoff.
local TAKEOFF_GRACE = 0.3

local lastJumpTime = -math.huge -- time of the last counted jump press
ns.combo = 0 -- jumps in the current chain (1 = a single jump)

-- Flight of the last counted jump.
local awaitingTakeoff = false   -- pressed, not yet seen falling
local inAir = false             -- seen falling, not yet landed
local comboAnchor = -math.huge  -- when the combo window started (landing)

local comboCoins = 0     -- coins earned during the current chain
local comboStartBest = 0 -- best combo before the current chain started
local comboOpen = false  -- a chain of 2+ jumps not yet reported as ended

-- Runs each frame after a counted jump until its combo window has run out.
local watcher = CreateFrame("Frame")

-------------------------------------------------------------------------------
-- Takeoff and landing
-------------------------------------------------------------------------------

-- Advances the flight state for one frame. `isFalling` is IsFalling().
function ns.UpdateAir(now, isFalling)
    if awaitingTakeoff then
        if isFalling then
            awaitingTakeoff = false
            inAir = true
        elseif now - lastJumpTime > TAKEOFF_GRACE then
            awaitingTakeoff = false
            comboAnchor = lastJumpTime
        end
    elseif inAir and not isFalling then
        inAir = false
        comboAnchor = now
    end
end

-- Time the current combo runs out, or math.huge while still in the air.
function ns.ComboDeadline(now)
    if inAir then return math.huge end
    if awaitingTakeoff then
        if now - lastJumpTime <= TAKEOFF_GRACE then return math.huge end
        return lastJumpTime + ns.COMBO_WINDOW -- never took off
    end
    return comboAnchor + ns.COMBO_WINDOW
end

-------------------------------------------------------------------------------
-- Combo state
-------------------------------------------------------------------------------

-- Fires COMBO_ENDED(combo, coins, isNewBest) once for a chain of 2+ jumps.
local function EndCombo()
    comboOpen = false
    ns.Fire("COMBO_ENDED", ns.combo, comboCoins, ns.combo > comboStartBest)
end

function ns.CheckComboEnded(now)
    if comboOpen and now > ns.ComboDeadline(now) then
        EndCombo()
    end
end

local function WatchJump()
    local now = GetTime()
    ns.UpdateAir(now, IsFalling())
    ns.CheckComboEnded(now)
    if now > ns.ComboDeadline(now) then
        watcher:SetScript("OnUpdate", nil)
    end
end

function ns.IsComboActive(now)
    now = now or GetTime()
    return ns.combo > 1 and now <= ns.ComboDeadline(now)
end

-- Seconds left in the combo window; the full window while in the air.
function ns.ComboTimeLeft(now)
    now = now or GetTime()
    local deadline = ns.ComboDeadline(now)
    if deadline == math.huge then return ns.COMBO_WINDOW end
    return math.max(0, deadline - now)
end

-------------------------------------------------------------------------------
-- Payouts
-------------------------------------------------------------------------------

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

-- Counts one jump at time `now`. Returns the coins earned, or nil if the
-- press was ignored by the debounce. The player is on the ground when this
-- runs (presses mid-air are filtered out before it).
function ns.RegisterJump(now, roll)
    local db = ns.db
    if now - lastJumpTime < JUMP_DEBOUNCE then return nil end

    -- We're on the ground, so finish the last flight if the watcher hasn't,
    -- and report the previous chain if it ran out.
    ns.UpdateAir(now, false)
    ns.CheckComboEnded(now)

    if now <= ns.ComboDeadline(now) then
        ns.combo = ns.combo + 1
    else
        ns.combo = 1
        comboCoins = 0
        comboStartBest = db.stats.bestCombo
    end

    lastJumpTime = now
    awaitingTakeoff, inAir = true, false
    watcher:SetScript("OnUpdate", WatchJump)

    local isCrit = (roll or math.random()) < ns.GetEffect("luckyLanding")
    local earned = ns.CalculateJump(ns.combo, isCrit)

    db.coins = db.coins + earned
    db.lifetimeCoins = db.lifetimeCoins + earned
    db.totalJumps = db.totalJumps + 1
    if ns.combo > db.stats.bestCombo then db.stats.bestCombo = ns.combo end
    if isCrit then db.stats.crits = db.stats.crits + 1 end

    comboCoins = comboCoins + earned
    if ns.combo >= 2 then comboOpen = true end

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
