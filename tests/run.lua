-- Offline test harness: stubs the WoW API, loads the addon in TOC order and
-- checks the game logic. Run from the repo root:  luajit tests/run.lua

local ADDON_DIR = "JumpCoins/"

-------------------------------------------------------------------------------
-- WoW API stubs
-------------------------------------------------------------------------------

local clock = 100
function GetTime() return clock end
function IsFalling() return false end
function IsSwimming() return false end
function IsFlying() return false end
function UnitOnTaxi() return false end
function strlower(s) return s:lower() end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function GameTooltip_Hide() end
function PlaySound() end
UISpecialFrames = {}
SlashCmdList = {}
BackdropTemplateMixin = {}
SOUNDKIT = { LOOTWINDOW_COIN_SOUND = 1 }
StaticPopupDialogs = {}
shownPopups = {}
function StaticPopup_Show(name) table.insert(shownPopups, name) end

local printed = {}
function print(msg) table.insert(printed, msg) end

local jumpHook
function hooksecurefunc(name, fn)
    assert(name == "JumpOrAscendStart", "unexpected hook " .. name)
    jumpHook = fn
end

-- Mock widget: records scripts/shown state, accepts any other method.
local frames = {}
local Mock = {}
local function NewMock(name)
    local m = setmetatable({ scripts = {}, shown = true, text = nil, name = name }, Mock)
    if name then frames[name] = m; _G[name] = m end
    return m
end
local methods = {
    CreateFontString = function() return NewMock() end,
    CreateTexture = function() return NewMock() end,
    CreateAnimationGroup = function() return NewMock() end,
    CreateAnimation = function() return NewMock() end,
    SetScript = function(self, k, fn) self.scripts[k] = fn end,
    GetScript = function(self, k) return self.scripts[k] end,
    Show = function(self) self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end,
    Hide = function(self) self.shown = false end,
    SetShown = function(self, v) if v then self:Show() else self:Hide() end end,
    IsShown = function(self) return self.shown end,
    SetText = function(self, t) self.text = t end,
    GetText = function(self) return self.text end,
    Enable = function(self) self.enabled = true end,
    Disable = function(self) self.enabled = false end,
    SetEnabled = function(self, v) self.enabled = v and true or false end,
    GetPoint = function() return "TOPLEFT", nil, nil, 12, -34 end,
    RegisterEvent = function(self, e) self.events = self.events or {}; self.events[e] = true end,
}
-- WoW widget methods are capitalized; lowercase keys are plain fields.
Mock.__index = function(_, k)
    if methods[k] then return methods[k] end
    if type(k) == "string" and k:match("^%u") then return function() end end
    return nil
end

function CreateFrame(_, name) return NewMock(name) end
GameTooltip = NewMock("GameTooltip")
UIParent = NewMock("UIParent")

-------------------------------------------------------------------------------
-- Load addon
-------------------------------------------------------------------------------

local ns = {}
local tocFiles = {}
for line in io.lines(ADDON_DIR .. "JumpCoins.toc") do
    if line:match("%.lua$") then table.insert(tocFiles, line) end
end

local function LoadAddon(savedVars)
    ns = {}
    JumpCoinsDB = savedVars
    for k in pairs(frames) do _G[k] = nil end
    frames = {}
    GameTooltip = NewMock("GameTooltip")
    local loader
    local realCreate = CreateFrame
    -- Frames the addon creates while loading (event loader, combo watcher...).
    loadFrames = {}
    CreateFrame = function(t, name, ...)
        local f = realCreate(t, name, ...)
        if not loader and not name then loader = f end
        table.insert(loadFrames, f)
        return f
    end
    for _, file in ipairs(tocFiles) do
        local chunk = assert(loadfile(ADDON_DIR .. file))
        chunk("JumpCoins", ns)
    end
    CreateFrame = realCreate
    loader.scripts.OnEvent(loader, "ADDON_LOADED", "SomeOtherAddon")
    assert(ns.db == nil, "loaded on another addon's ADDON_LOADED")
    loader.scripts.OnEvent(loader, "ADDON_LOADED", "JumpCoins")
    return ns
end

-------------------------------------------------------------------------------
-- Tiny test runner
-------------------------------------------------------------------------------

local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        io.write("FAIL: ", name, "\n  ", tostring(err), "\n")
    end
end
local function eq(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", msg or "value",
            tostring(expected), tostring(actual)), 2)
    end
end
local function near(actual, expected, msg)
    if math.abs(actual - expected) > 1e-9 then
        error(string.format("%s: expected %s, got %s", msg or "value",
            tostring(expected), tostring(actual)), 2)
    end
end

-- Jump through the real hook at a given time. roll is fixed to "no crit"
-- unless overridden, by stubbing math.random.
local realRandom = math.random
local function jump(at, roll)
    clock = at
    math.random = function() return roll or 0.999 end
    jumpHook()
    math.random = realRandom
end

-------------------------------------------------------------------------------
-- Tests
-------------------------------------------------------------------------------

test("fresh save gets current version and defaults", function()
    LoadAddon(nil)
    eq(ns.db.version, ns.SAVE_VERSION, "version")
    eq(ns.db.coins, 0, "coins")
    eq(ns.db.frame.shown, true, "frame shown")
    eq(type(ns.db.upgrades), "table", "upgrades")
end)

test("v1 save migrates and keeps progress", function()
    LoadAddon({ coins = 42, totalJumps = 50,
        frame = { point = "TOP", x = 5, y = -5, shown = false, locked = true } })
    eq(ns.db.version, ns.SAVE_VERSION, "version")
    eq(ns.db.coins, 42, "coins kept")
    eq(ns.db.lifetimeCoins, 50, "lifetime from jumps")
    eq(ns.db.frame.point, "TOP", "frame point kept")
    eq(ns.db.frame.shown, false, "frame shown kept")
    eq(ns.db.stats.bestCombo, 0, "stats defaulted")
end)

test("current-version save is left alone", function()
    LoadAddon({ version = ns.SAVE_VERSION or 2, coins = 7, lifetimeCoins = 99 })
    eq(ns.db.lifetimeCoins, 99, "lifetime not overwritten")
end)

test("number formatting", function()
    LoadAddon(nil)
    local F = ns.FormatNumber
    eq(F(0), "0"); eq(F(7.9), "7"); eq(F(999), "999")
    eq(F(1000), "1.00K"); eq(F(1234), "1.23K"); eq(F(45678), "45.7K")
    eq(F(999499), "999K"); eq(F(999600), "1.00M")
    eq(F(1.5e9), "1.50B"); eq(F(2e12), "2.00T")
    eq(ns.FormatPercent(0.05), "5%"); eq(ns.FormatPercent(0.07 * 1), "7%")
    eq(ns.FormatPercent(0.125), "12.5%")
end)

test("one coin per jump with no upgrades", function()
    LoadAddon(nil)
    jump(10); jump(20); jump(30)
    eq(ns.db.coins, 3, "coins"); eq(ns.db.totalJumps, 3, "jumps")
end)

test("ignored while falling, swimming, flying or on taxi", function()
    LoadAddon(nil)
    for _, name in ipairs({ "IsFalling", "IsSwimming", "IsFlying", "UnitOnTaxi" }) do
        local orig = _G[name]
        _G[name] = function() return true end
        jump(clock + 10)
        _G[name] = orig
    end
    eq(ns.db.totalJumps, 0, "jumps")
end)

test("debounce drops presses under 0.25s apart", function()
    LoadAddon(nil)
    jump(1000); jump(1000.1); jump(1000.3)
    eq(ns.db.totalJumps, 2, "jumps")
end)

test("buying Spring Boots raises cost and coins per jump", function()
    LoadAddon({ version = 2, coins = 10 })
    eq(ns.GetCost("springBoots"), 10, "first cost")
    eq(ns.CanBuy("springBoots"), true, "affordable")
    assert(ns.Buy("springBoots"))
    eq(ns.db.coins, 0, "coins spent")
    eq(ns.GetLevel("springBoots"), 1, "level")
    eq(ns.GetCost("springBoots"), 11, "second cost (10 * 1.15)")
    eq(ns.Buy("springBoots"), false, "can't afford")
    jump(2000)
    eq(ns.db.coins, 2, "2 coins per jump")
end)

test("combo needs Rhythm to pay, caps at max stacks, resets after window", function()
    LoadAddon(nil)
    -- No Rhythm: chained jumps still pay 1 each.
    jump(3000); jump(3001)
    eq(ns.db.coins, 2, "no bonus without rhythm")
    eq(ns.combo, 2, "combo still tracked")

    ns.db.upgrades.rhythm = 2 -- +10% per stack
    ns.db.coins = 0
    jump(3002)                      -- combo 3, 2 stacks -> 1.2
    near(ns.db.coins, 1.2, "two stacks")
    for i = 1, 20 do jump(3002 + i) end
    eq(ns.combo, 23, "combo keeps counting")
    near(ns.CalculateJump(ns.combo, false), 1 + 10 * 0.1, "capped at 10 stacks")
    eq(ns.db.stats.bestCombo, 23, "best combo")

    jump(3022 + ns.COMBO_WINDOW + 0.01)
    eq(ns.combo, 1, "combo reset after window")
end)

test("crits pay 10x and respect max level", function()
    LoadAddon({ version = 2, coins = 0, upgrades = { luckyLanding = 5 } }) -- 10%
    jump(4000, 0.05)  -- roll under 10% -> crit
    eq(ns.db.coins, 10, "crit pays 10x")
    eq(ns.db.stats.crits, 1, "crit counted")
    jump(4010, 0.5)
    eq(ns.db.coins, 11, "normal jump")

    ns.db.upgrades.luckyLanding = 25
    ns.db.coins = 1e12
    eq(ns.IsMaxed("luckyLanding"), true, "maxed")
    eq(ns.Buy("luckyLanding"), false, "can't buy past max")
end)

test("shop rows reflect affordability and max", function()
    LoadAddon({ version = 2, coins = 60, upgrades = { luckyLanding = 25 } })
    ns.ToggleShop(true)
    local shop = JumpCoinsShop
    eq(shop:IsShown(), true, "shop shown")
    local rows = shop.rows
    eq(rows[1].buy.enabled, true, "spring boots affordable")
    eq(rows[1].buy.text, "10", "spring boots cost")
    eq(rows[2].buy.enabled, true, "rhythm affordable at 60")
    eq(rows[3].buy.text, "Maxed", "lucky maxed")
    eq(rows[3].buy.enabled, false, "lucky disabled")

    rows[2].buy.scripts.OnClick()   -- buy rhythm for 50
    eq(ns.GetLevel("rhythm"), 1, "rhythm bought via button")
    eq(rows[2].buy.enabled, false, "rhythm now unaffordable")
    eq(rows[1].buy.enabled, true, "spring boots still affordable (10)")
end)

test("display updates and click opens shop but drag does not", function()
    LoadAddon({ version = 2, coins = 1234 })
    local d = JumpCoinsFrame
    assert(d.coins.text:find("1.23K"), "coin text: " .. tostring(d.coins.text))
    d.scripts.OnMouseDown(d)
    d.scripts.OnDragStart(d)
    d.scripts.OnDragStop(d)
    d.scripts.OnMouseUp(d, "LeftButton")
    eq(JumpCoinsShop, nil, "drag didn't open shop")
    eq(ns.db.frame.point, "TOPLEFT", "position saved")
    d.scripts.OnMouseDown(d)
    d.scripts.OnMouseUp(d, "LeftButton")
    eq(JumpCoinsShop:IsShown(), true, "click opened shop")
    d.scripts.OnEnter(d) -- tooltip shouldn't error
end)

test("combo text shows with Rhythm and clears after window", function()
    LoadAddon({ version = 2, upgrades = { rhythm = 1 } })
    local d = JumpCoinsFrame
    jump(5000); jump(5001)
    assert(d.combo.text:find("Combo x2"), "combo text: " .. tostring(d.combo.text))
    assert(d.scripts.OnUpdate, "OnUpdate running")
    clock = 5001 + ns.COMBO_WINDOW + 0.1
    d.scripts.OnUpdate(d)
    eq(d.combo.text, "", "combo cleared")
    eq(d.scripts.OnUpdate, nil, "OnUpdate stopped")
end)

test("slash commands", function()
    LoadAddon({ version = 2, coins = 5 })
    SlashCmdList.JUMPCOINS("hide")
    eq(JumpCoinsFrame:IsShown(), false, "hidden"); eq(ns.db.frame.shown, false, "saved hidden")
    SlashCmdList.JUMPCOINS("")
    eq(JumpCoinsFrame:IsShown(), true, "toggled back")
    SlashCmdList.JUMPCOINS("reset")
    eq(ns.db.coins, 5, "reset needs confirm")
    SlashCmdList.JUMPCOINS("  RESET confirm ")
    eq(ns.db.coins, 0, "reset confirmed")
    SlashCmdList.JUMPCOINS("shop")
    eq(JumpCoinsShop:IsShown(), true, "shop opened")
    SlashCmdList.JUMPCOINS("count")
    SlashCmdList.JUMPCOINS("resetpos")
    SlashCmdList.JUMPCOINS("bogus")
end)

test("debug coins, add and level", function()
    LoadAddon(nil)
    SlashCmdList.JUMPCOINS("debug coins 1e6")
    eq(ns.db.coins, 1e6, "coins set")
    SlashCmdList.JUMPCOINS("debug add 500")
    eq(ns.db.coins, 1000500, "coins added")
    SlashCmdList.JUMPCOINS("debug add -9e9")
    eq(ns.db.coins, 0, "coins never negative")
    SlashCmdList.JUMPCOINS("debug level Spring Boots 4")
    eq(ns.GetLevel("springBoots"), 4, "level by name")
    SlashCmdList.JUMPCOINS("debug level rhythm 3")
    eq(ns.GetLevel("rhythm"), 3, "level by id")
    SlashCmdList.JUMPCOINS("debug level luckylanding 99")
    eq(ns.GetLevel("luckyLanding"), 25, "clamped to max")
    SlashCmdList.JUMPCOINS("debug level nope 3")
    SlashCmdList.JUMPCOINS("debug coins abc")
    eq(ns.db.coins, 0, "bad input ignored")
end)

test("debug jump simulates a chained combo ending now", function()
    LoadAddon({ version = 2, upgrades = { rhythm = 2 } }) -- +10% per stack
    clock = 6000
    SlashCmdList.JUMPCOINS("debug jump 12")
    eq(ns.db.totalJumps, 12, "jumps")
    eq(ns.combo, 12, "combo chained")
    -- stacks 0..10, capped: 1 + 1.1 + ... + 2.0 + 2.0
    local expected = 0
    for c = 1, 12 do expected = expected + 1 + math.min(c - 1, 10) * 0.1 end
    near(ns.db.coins, expected, "combo payouts")
    eq(ns.IsComboActive(6000), true, "combo still active for real jumps")
    jump(6001)
    eq(ns.combo, 13, "real jump continues simulated combo")
end)

test("debug jump works right after a real jump", function()
    LoadAddon(nil)
    jump(7000)
    clock = 7000.1 -- within debounce of the real jump
    SlashCmdList.JUMPCOINS("debug jump 3")
    eq(ns.db.totalJumps, 4, "simulated jumps not debounced")
end)

test("debug crit always crits and popup only shows once", function()
    LoadAddon(nil)
    clock = 8000
    SlashCmdList.JUMPCOINS("debug crit")
    eq(ns.db.coins, 10, "crit pays 10x at 0% chance")
    eq(ns.db.stats.crits, 1, "crit counted")
    eq(ns.simulating, false, "simulating flag cleared")
    assert(JumpCoinsFrame.popup.text.text:find("CRIT"), "popup shown")
end)

test("debug help and status don't error", function()
    LoadAddon(nil)
    SlashCmdList.JUMPCOINS("debug")
    SlashCmdList.JUMPCOINS("debug status")
    SlashCmdList.JUMPCOINS("debugger") -- not a debug command, falls to help
end)

-- Records COMBO_ENDED events for the currently loaded addon.
local function captureComboEnds()
    local events = {}
    ns.On("COMBO_ENDED", function(combo, coins, isNewBest)
        table.insert(events, { combo = combo, coins = coins, best = isNewBest })
    end)
    return events
end

-- Jumps `count` times, 1s apart, starting at `start`. Returns the last time.
local function chain(start, count)
    for i = 0, count - 1 do jump(start + i) end
    return start + count - 1
end

test("COMBO_ENDED fires once when the window runs out", function()
    LoadAddon({ version = 2, upgrades = { rhythm = 1 } }) -- +5% per stack
    local ends = captureComboEnds()
    local last = chain(9000, 5)
    ns.CheckComboEnded(last + 1)
    eq(#ends, 0, "not yet: still inside the window")
    ns.CheckComboEnded(last + ns.COMBO_WINDOW + 0.01)
    eq(#ends, 1, "fired after window")
    eq(ends[1].combo, 5, "final combo")
    local expected = 0
    for c = 1, 5 do expected = expected + 1 + (c - 1) * 0.05 end
    near(ends[1].coins, expected, "coins earned in the chain")
    eq(ends[1].best, true, "first chain is a new best")
    ns.CheckComboEnded(last + 10)
    eq(#ends, 1, "fires only once")
end)

test("the in-game watcher reports the drop on its own", function()
    LoadAddon(nil)
    local ends = captureComboEnds()
    local last = chain(9500, 3)
    -- Simulate one game frame: run every OnUpdate the addon has registered.
    local function tick()
        for _, f in ipairs(loadFrames) do
            if f.scripts.OnUpdate then f.scripts.OnUpdate(f, 0.016) end
        end
    end
    clock = last + 1
    tick()
    eq(#ends, 0, "still inside the window")
    clock = last + ns.COMBO_WINDOW + 0.5
    tick()
    eq(#ends, 1, "watcher reported the drop")
    eq(ends[1].combo, 3, "combo length")
    tick()
    eq(#ends, 1, "watcher stopped after reporting")
end)

test("single jumps never fire COMBO_ENDED", function()
    LoadAddon(nil)
    local ends = captureComboEnds()
    jump(9800); jump(9810); jump(9820)
    ns.CheckComboEnded(9900)
    eq(#ends, 0, "no combo, no event")
end)

test("a new chain reports the old one even if the watcher missed it", function()
    LoadAddon(nil)
    local ends = captureComboEnds()
    chain(10000, 4)
    jump(10100) -- long after: starts a new chain
    eq(#ends, 1, "old chain reported")
    eq(ends[1].combo, 4, "old chain length")
    eq(ns.combo, 1, "new chain started")
end)

test("new best only when beating the best from before the chain", function()
    LoadAddon(nil)
    local ends = captureComboEnds()
    chain(11000, 6); ns.CheckComboEnded(11100)
    chain(11200, 4); ns.CheckComboEnded(11300)
    chain(11400, 8); ns.CheckComboEnded(11500)
    eq(ends[1].best, true, "first is best")
    eq(ends[2].best, false, "shorter is not")
    eq(ends[3].best, true, "longer is")
    eq(ns.db.stats.bestCombo, 8, "best saved")
end)

test("big announcement for a dropped 20+ combo with Rhythm", function()
    LoadAddon({ version = 2, upgrades = { rhythm = 1 } })
    local last = chain(12000, 19)
    ns.CheckComboEnded(last + 5)
    eq(JumpCoinsAnnounce, nil, "19 doesn't announce")

    last = chain(12100, 23)
    ns.CheckComboEnded(last + 5)
    local banner = JumpCoinsAnnounce
    assert(banner, "banner created")
    eq(banner:IsShown(), true, "banner shown")
    eq(banner.title.text, "23x COMBO!", "title")
    assert(banner.subtitle.text:find("coins in the chain"), "subtitle: " .. tostring(banner.subtitle.text))
    assert(banner.subtitle.text:find("NEW BEST"), "new best shown")

    last = chain(12200, 55)
    ns.CheckComboEnded(last + 5)
    eq(banner.title.text, "55x EPIC COMBO!", "epic tier")
    last = chain(12300, 20)
    ns.CheckComboEnded(last + 5)
    eq(banner.title.text, "20x COMBO!", "exactly 20 announces")
    assert(not banner.subtitle.text:find("NEW BEST"), "not a new best")
    eq(ns.GetComboTier(150).title, "LEGENDARY COMBO", "legendary tier")
end)

test("debug jump closes an open combo correctly", function()
    LoadAddon(nil)
    local ends = captureComboEnds()
    chain(14000, 5)              -- open real combo of 5
    clock = 14005
    SlashCmdList.JUMPCOINS("debug jump 3")
    eq(#ends, 1, "old combo reported once")
    eq(ends[1].combo, 5, "reported with its real length")
    eq(ns.combo, 3, "simulated chain")
    ns.CheckComboEnded(clock + 5)
    eq(#ends, 2, "simulated chain reported")
    eq(ends[2].combo, 3, "simulated chain length")
end)

test("debug jump 25 triggers the big announcement", function()
    LoadAddon({ version = 2, upgrades = { rhythm = 1 } })
    clock = 15000
    SlashCmdList.JUMPCOINS("debug jump 25")
    ns.CheckComboEnded(clock + 5)
    eq(JumpCoinsAnnounce.title.text, "25x COMBO!", "announced")
end)

-- Landing-based combo timing. These drive the per-frame watcher like the game
-- would: `fly` takes off at `up`, stays airborne, and lands at `down`.
local falling = false
IsFalling = function() return falling end

local function tick(at)
    clock = at
    for _, f in ipairs(loadFrames) do
        if f.scripts.OnUpdate then f.scripts.OnUpdate(f, 0.016) end
    end
end

local function fly(up, down)
    falling = true
    tick(up)
    tick((up + down) / 2)
    falling = false
    tick(down)
end

test("a long jump doesn't break the combo", function()
    LoadAddon(nil)
    jump(20000)
    fly(20000.05, 20003)   -- 3s in the air (down a cliff)
    jump(20004)            -- 1s after landing, 4s after the press
    eq(ns.combo, 2, "combo continues")
end)

test("the window counts from landing", function()
    LoadAddon(nil)
    jump(21000)
    fly(21000.05, 21001)
    jump(21001 + ns.COMBO_WINDOW + 0.1) -- just too late after landing
    eq(ns.combo, 1, "combo reset")
    jump(21010)
    fly(21010.05, 21011)
    jump(21011 + ns.COMBO_WINDOW - 0.1) -- just in time
    eq(ns.combo, 2, "combo kept")
end)

test("a combo never ends mid-air", function()
    LoadAddon(nil)
    local ends = captureComboEnds()
    jump(22000); fly(22000.05, 22001)
    jump(22001.5)           -- combo 2
    falling = true
    tick(22001.6)           -- takeoff
    tick(22010)             -- 8s in the air
    eq(#ends, 0, "still airborne, combo alive")
    eq(ns.IsComboActive(22010), true, "active while airborne")
    falling = false
    tick(22011)             -- land
    tick(22011 + ns.COMBO_WINDOW - 0.1)
    eq(#ends, 0, "inside window after landing")
    tick(22011 + ns.COMBO_WINDOW + 0.1)
    eq(#ends, 1, "ended after the window from landing")
    eq(ends[1].combo, 2, "combo length")
end)

test("a jump that never takes off falls back to the press time", function()
    LoadAddon(nil)
    local ends = captureComboEnds()
    jump(23000)
    jump(23001)             -- combo 2, never airborne (rooted)
    tick(23001.1)
    eq(ns.IsComboActive(23001.1), true, "active during grace")
    tick(23001.5)           -- grace over: window counts from the press
    tick(23001 + ns.COMBO_WINDOW - 0.05)
    eq(#ends, 0, "inside window from the press")
    tick(23001 + ns.COMBO_WINDOW + 0.05)
    eq(#ends, 1, "ended")
end)

test("landing missed by the watcher still counts at the next jump", function()
    LoadAddon(nil)
    jump(24000)
    falling = true
    tick(24000.05)          -- took off; landing frame never ticked
    falling = false
    jump(24003)             -- on the ground again: treated as just landed
    eq(ns.combo, 2, "combo continues")
end)

test("watcher stops once the window runs out", function()
    LoadAddon(nil)
    jump(25000)
    fly(25000.05, 25001)
    local watcher
    for _, f in ipairs(loadFrames) do
        if f.scripts.OnUpdate and f ~= JumpCoinsFrame then watcher = f end
    end
    assert(watcher, "watcher running after a jump")
    tick(25001 + ns.COMBO_WINDOW + 0.1)
    eq(watcher.scripts.OnUpdate, nil, "watcher stopped")
end)

test("no announcement without Rhythm", function()
    LoadAddon(nil)
    local last = chain(13000, 30)
    ns.CheckComboEnded(last + 5)
    eq(JumpCoinsAnnounce, nil, "no banner without rhythm")
end)

test("shop reset button asks first, then resets everything", function()
    LoadAddon({ version = 2, coins = 5000, lifetimeCoins = 9000, totalJumps = 300,
        upgrades = { springBoots = 4, rhythm = 2 }, stats = { bestCombo = 12, crits = 3 } })
    ns.ToggleShop(true)
    local shop = JumpCoinsShop
    shownPopups = {}
    shop.reset.scripts.OnClick()
    eq(#shownPopups, 1, "confirmation shown")
    local popup = StaticPopupDialogs[shownPopups[1]]
    assert(popup and popup.OnAccept, "popup registered with OnAccept")
    eq(ns.db.coins, 5000, "nothing reset before confirming")
    eq(popup.hideOnEscape, true, "escape cancels")

    popup.OnAccept()
    eq(ns.db.coins, 0, "coins reset")
    eq(ns.db.lifetimeCoins, 0, "lifetime coins reset")
    eq(ns.db.totalJumps, 0, "jumps reset")
    eq(ns.GetLevel("springBoots"), 0, "upgrades reset")
    eq(ns.db.stats.bestCombo, 0, "stats reset")
    eq(shop.rows[1].level.text, "Lv 0", "shop refreshed")
    assert(JumpCoinsFrame.coins.text:find("Coins: |cffffd1000|r", 1, true), "display refreshed")
    shop.reset.scripts.OnEnter(shop.reset) -- tooltip shouldn't error
end)

io.write(string.format("%d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
