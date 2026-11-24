-- Debug: /jc debug commands for testing in game without jumping thousands of
-- times. These change progress directly, so they're for development only.

local _, ns = ...

local SIM_JUMP_SPACING = 0.5 -- seconds between simulated jumps (keeps a combo)

local HELP = {
    "/jc debug coins <n>  - set coins (accepts 1e6)",
    "/jc debug add <n>  - add coins",
    "/jc debug level <upgrade> <n>  - set an upgrade's level",
    "/jc debug jump [n]  - simulate n chained jumps (default 1)",
    "/jc debug crit  - simulate one guaranteed crit jump",
    "/jc debug status  - print coins and upgrade levels",
}

local function DebugPrint(msg)
    ns.Print("|cffff8040[debug]|r " .. msg)
end

-- Matches an upgrade by id or name, ignoring case and spaces.
local function FindUpgrade(query)
    query = (query or ""):lower():gsub("%s", "")
    if query == "" then return nil end
    for _, def in ipairs(ns.UPGRADES) do
        if def.id:lower() == query or def.name:lower():gsub("%s", "") == query then
            return def
        end
    end
end

local function UpgradeIds()
    local ids = {}
    for _, def in ipairs(ns.UPGRADES) do table.insert(ids, def.id) end
    return table.concat(ids, ", ")
end

local function SetCoins(n)
    ns.db.coins = math.max(0, n)
    ns.Fire("COINS_CHANGED")
end

-- Simulates `count` jumps ending now, spaced closely enough to chain a combo.
function ns.SimulateJumps(count, roll)
    ns.ResetJumpState()
    local now = GetTime()
    local total = 0
    for i = 1, count do
        -- Only the last jump shows crit popups/sounds, so big batches stay quiet.
        ns.simulating = i < count
        local at = now - (count - i) * SIM_JUMP_SPACING
        total = total + (ns.RegisterJump(at, roll) or 0)
    end
    ns.simulating = false
    return total
end

local COMMANDS = {}

function COMMANDS.coins(arg)
    local n = tonumber(arg)
    if not n then return DebugPrint("Usage: /jc debug coins <n>") end
    SetCoins(n)
    DebugPrint("Coins set to " .. ns.FormatNumber(ns.db.coins) .. ".")
end

function COMMANDS.add(arg)
    local n = tonumber(arg)
    if not n then return DebugPrint("Usage: /jc debug add <n>") end
    SetCoins(ns.db.coins + n)
    DebugPrint("Coins now " .. ns.FormatNumber(ns.db.coins) .. ".")
end

function COMMANDS.level(arg)
    local name, level = (arg or ""):match("^(.-)%s+(%-?%d+)$")
    local def = FindUpgrade(name)
    level = tonumber(level)
    if not def or not level then
        return DebugPrint("Usage: /jc debug level <upgrade> <n>. Upgrades: " .. UpgradeIds())
    end
    level = math.max(0, level)
    if def.maxLevel then level = math.min(level, def.maxLevel) end
    ns.db.upgrades[def.id] = level
    ns.Fire("UPGRADE_BOUGHT", def.id)
    DebugPrint(string.format("%s set to level %d (%s).", def.name, level,
        def.formatEffect(def.effect(level))))
end

function COMMANDS.jump(arg)
    local count = math.floor(tonumber(arg) or 1)
    if count < 1 or count > 10000 then
        return DebugPrint("Usage: /jc debug jump [1-10000]")
    end
    local earned = ns.SimulateJumps(count)
    DebugPrint(string.format("Simulated %d jumps for %s coins.", count, ns.FormatNumber(earned)))
end

function COMMANDS.crit()
    -- A roll below zero always beats the crit chance, even at 0%.
    local earned = ns.SimulateJumps(1, -1)
    DebugPrint("Simulated a crit for " .. ns.FormatNumber(earned) .. " coins.")
end

function COMMANDS.status()
    DebugPrint("Coins: " .. ns.FormatNumber(ns.db.coins))
    for _, def in ipairs(ns.UPGRADES) do
        local level = ns.GetLevel(def.id)
        DebugPrint(string.format("  %s (%s): level %d, %s", def.name, def.id, level,
            def.formatEffect(def.effect(level))))
    end
end

function ns.HandleDebug(input)
    local cmd, arg = (input or ""):match("^(%S*)%s*(.-)$")
    local handler = COMMANDS[cmd]
    if handler then
        handler(arg)
    else
        for _, line in ipairs(HELP) do DebugPrint(line) end
    end
end
