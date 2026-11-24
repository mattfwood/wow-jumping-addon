-- Balance simulator: how fast does a player progress with the current upgrade
-- numbers? Loads the real Format.lua, Upgrades.lua and Jump.lua, so it always
-- matches the game's formulas.
--
-- Run from the repo root:
--   luajit tools/sim.lua [jump interval s] [combo length] [minutes]
-- Defaults: 1.3s between jumps, combos of 15 jumps, 120 minutes.
--
-- Player model: jumps nonstop, every `interval` seconds, in combos of
-- `combo length` jumps before slipping and starting over. Crits use expected
-- value. Buys immediately whenever it can afford the upgrade with the best
-- (coins per jump gained) / cost. Real players jump less, so real progress is
-- slower; treat this as the fastest plausible pace.

local INTERVAL = tonumber(arg[1]) or 1.3
local CHAIN = tonumber(arg[2]) or 15
local MINUTES = tonumber(arg[3]) or 120

-- Pacing targets (see ROADMAP.md). The simulator flags windows that miss them.
local TARGETS = {
    firstBuy = { min = 20, max = 60 },          -- seconds
    windows = {
        { from = 0,  to = 10,  minGap = 20,  maxGap = 90 },   -- seconds between buys
        { from = 10, to = 30,  minGap = 45,  maxGap = 180 },
        { from = 30, to = 60,  minGap = 90,  maxGap = 360 },
    },
}

-------------------------------------------------------------------------------
-- Load the addon's game logic with just enough WoW stubs
-------------------------------------------------------------------------------

local stubFrame = setmetatable({}, { __index = function() return function() end end })
CreateFrame = function() return stubFrame end
hooksecurefunc = function() end
GetTime = function() return 0 end

local ns = { db = { upgrades = {} } }
for _, file in ipairs({ "Format.lua", "Upgrades.lua", "Jump.lua" }) do
    assert(loadfile("JumpCoins/" .. file))("JumpCoins", ns)
end

-------------------------------------------------------------------------------
-- Simulation
-------------------------------------------------------------------------------

local levels = ns.db.upgrades

-- Average coins per jump across one combo of CHAIN jumps, crits as EV.
local function coinsPerJump()
    local crit = ns.GetEffect("luckyLanding")
    local total = 0
    for combo = 1, CHAIN do
        total = total + ns.CalculateJump(combo, false) * (1 - crit)
                      + ns.CalculateJump(combo, true) * crit
    end
    return total / CHAIN
end

local function bestBuy()
    local best, bestScore
    local now = coinsPerJump()
    for _, def in ipairs(ns.UPGRADES) do
        if not ns.IsMaxed(def.id) then
            levels[def.id] = ns.GetLevel(def.id) + 1
            local gain = coinsPerJump() - now
            levels[def.id] = levels[def.id] - 1
            local score = gain / ns.GetCost(def.id)
            if not bestScore or score > bestScore then
                best, bestScore = def.id, score
            end
        end
    end
    return best
end

local coins, t = 0, 0
local buyTimes = {}
local snapshots = {}
local nextSnap = { 1, 5, 10, 20, 30, 45, 60, 90, 120, 180, 240 }
local snapIndex = 1

while t < MINUTES * 60 do
    t = t + INTERVAL
    coins = coins + coinsPerJump()
    while true do
        local id = bestBuy()
        if not id or coins < ns.GetCost(id) then break end
        coins = coins - ns.GetCost(id)
        levels[id] = ns.GetLevel(id) + 1
        table.insert(buyTimes, t)
    end
    while nextSnap[snapIndex] and t >= nextSnap[snapIndex] * 60 do
        local row = { minute = nextSnap[snapIndex], perJump = coinsPerJump(), buys = #buyTimes }
        for _, def in ipairs(ns.UPGRADES) do row[def.id] = ns.GetLevel(def.id) end
        local id = bestBuy()
        row.nextIn = id and math.max(0, ns.GetCost(id) - coins) / row.perJump * INTERVAL or 0
        table.insert(snapshots, row)
        snapIndex = snapIndex + 1
    end
end

-------------------------------------------------------------------------------
-- Report
-------------------------------------------------------------------------------

local function median(list)
    if #list == 0 then return nil end
    table.sort(list)
    return list[math.ceil(#list / 2)]
end

local function gapsBetween(fromMin, toMin)
    local gaps, prev = {}, nil
    for _, bt in ipairs(buyTimes) do
        if bt >= fromMin * 60 and bt < toMin * 60 then
            if prev then table.insert(gaps, bt - prev) end
            prev = bt
        elseif bt < fromMin * 60 then
            prev = bt
        end
    end
    return gaps
end

print(string.format("Player: a jump every %.1fs, combos of %d, %d minutes\n", INTERVAL, CHAIN, MINUTES))

local header = string.format("%6s  %10s  %5s", "min", "coins/jump", "buys")
for _, def in ipairs(ns.UPGRADES) do header = header .. string.format("  %13s", def.name) end
print(header .. "  next buy in")
for _, row in ipairs(snapshots) do
    local line = string.format("%6d  %10s  %5d", row.minute, ns.FormatNumber(row.perJump), row.buys)
    for _, def in ipairs(ns.UPGRADES) do line = line .. string.format("  %13d", row[def.id]) end
    print(line .. string.format("  %6.0fs", row.nextIn))
end

print("")
local ok = true
local first = buyTimes[1]
local firstOk = first and first >= TARGETS.firstBuy.min and first <= TARGETS.firstBuy.max
ok = ok and firstOk
print(string.format("First purchase: %s  (target %d-%ds) %s",
    first and string.format("%.0fs", first) or "never",
    TARGETS.firstBuy.min, TARGETS.firstBuy.max, firstOk and "ok" or "MISS"))

for _, w in ipairs(TARGETS.windows) do
    if w.to <= MINUTES then
        local gaps = gapsBetween(w.from, w.to)
        local m = median(gaps)
        local inRange = m and m >= w.minGap and m <= w.maxGap
        ok = ok and inRange
        print(string.format("Minutes %2d-%-2d: %3d buys, median gap %s  (target %d-%ds) %s",
            w.from, w.to, #gaps + (m and 1 or 0), m and string.format("%.0fs", m) or "n/a",
            w.minGap, w.maxGap, inRange and "ok" or "MISS"))
    end
end

os.exit(ok and 0 or 1)
