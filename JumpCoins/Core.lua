-- Core: shared namespace, event bus, saved variables and migrations.

local ADDON_NAME, ns = ...
ns.ADDON_NAME = ADDON_NAME

-------------------------------------------------------------------------------
-- Tiny event bus so modules don't need to know about each other.
-------------------------------------------------------------------------------

local listeners = {}

function ns.On(event, fn)
    listeners[event] = listeners[event] or {}
    table.insert(listeners[event], fn)
end

function ns.Fire(event, ...)
    local list = listeners[event]
    if not list then return end
    for i = 1, #list do
        list[i](...)
    end
end

function ns.Print(msg)
    print("|cffffd100Jump Coins:|r " .. msg)
end

-------------------------------------------------------------------------------
-- Saved variables
-------------------------------------------------------------------------------

ns.SAVE_VERSION = 2

ns.DEFAULT_FRAME_POS = { point = "CENTER", x = 0, y = 200 }

local DEFAULTS = {
    coins = 0,          -- spendable currency (may be fractional)
    lifetimeCoins = 0,  -- every coin ever earned
    totalJumps = 0,     -- every counted jump
    upgrades = {},      -- [upgradeId] = level
    stats = {
        bestCombo = 0,
        crits = 0,
    },
    frame = {
        point = ns.DEFAULT_FRAME_POS.point,
        x = ns.DEFAULT_FRAME_POS.x,
        y = ns.DEFAULT_FRAME_POS.y,
        shown = true,
        locked = false,
    },
}

-- MIGRATIONS[n] upgrades a save from version n-1 to version n.
local MIGRATIONS = {
    -- v1 (0.1.0) had coins, totalJumps and frame. Every coin came from one
    -- jump, so lifetime coins equals lifetime jumps.
    [2] = function(db)
        db.lifetimeCoins = db.totalJumps or db.coins or 0
    end,
}

local function ApplyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            ApplyDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

function ns.Migrate(db)
    if db.version == nil then
        -- Saves from before versioning have data but no version field.
        db.version = next(db) and 1 or ns.SAVE_VERSION
    end
    for v = db.version + 1, ns.SAVE_VERSION do
        if MIGRATIONS[v] then MIGRATIONS[v](db) end
        db.version = v
    end
    ApplyDefaults(db, DEFAULTS)
    return db
end

function ns.ResetProgress()
    local db = ns.db
    db.coins, db.lifetimeCoins, db.totalJumps = 0, 0, 0
    db.upgrades = {}
    db.stats = { bestCombo = 0, crits = 0 }
    ns.Fire("COINS_CHANGED")
    ns.Fire("UPGRADE_BOUGHT")
end

-------------------------------------------------------------------------------
-- Init
-------------------------------------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, name)
    if name ~= ADDON_NAME then return end
    JumpCoinsDB = ns.Migrate(JumpCoinsDB or {})
    ns.db = JumpCoinsDB
    self:UnregisterEvent("ADDON_LOADED")
    ns.Fire("LOADED")
end)
