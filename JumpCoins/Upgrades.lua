-- Upgrades: definitions, costs and purchasing.
--
-- To add an upgrade, append an entry to ns.UPGRADES. `effect(level)` returns
-- the upgrade's value at a level; gameplay code reads it with ns.GetEffect.

local _, ns = ...

ns.COMBO_WINDOW = 1.5     -- seconds allowed between jumps to keep a combo
ns.COMBO_MAX_STACKS = 10  -- combo stacks beyond the first jump that count
ns.CRIT_MULTIPLIER = 10

ns.UPGRADES = {
    {
        id = "springBoots",
        name = "Spring Boots",
        icon = "Interface\\Icons\\INV_Boots_02",
        desc = "Each jump earns more coins.",
        baseCost = 10,
        growth = 1.15,
        effect = function(level) return 1 + level end,
        formatEffect = function(v)
            return ns.FormatNumber(v) .. " per jump"
        end,
    },
    {
        id = "rhythm",
        name = "Rhythm",
        icon = "Interface\\Icons\\Ability_Rogue_Sprint",
        desc = string.format(
            "Jump again within %.1fs of landing to build a combo. Each stack (up to %d) adds a bonus.",
            ns.COMBO_WINDOW, ns.COMBO_MAX_STACKS),
        baseCost = 50,
        growth = 1.25,
        effect = function(level) return 0.05 * level end,
        formatEffect = function(v)
            return "+" .. ns.FormatPercent(v) .. " per combo stack"
        end,
    },
    {
        id = "luckyLanding",
        name = "Lucky Landing",
        icon = "Interface\\Icons\\INV_Misc_Coin_01",
        desc = string.format("Chance for a jump to pay %dx coins.", ns.CRIT_MULTIPLIER),
        baseCost = 100,
        growth = 1.35,
        maxLevel = 25,
        effect = function(level) return 0.02 * level end,
        formatEffect = function(v)
            return ns.FormatPercent(v) .. " crit chance"
        end,
    },
}

ns.UPGRADES_BY_ID = {}
for _, def in ipairs(ns.UPGRADES) do
    ns.UPGRADES_BY_ID[def.id] = def
end

function ns.GetLevel(id)
    return ns.db.upgrades[id] or 0
end

function ns.GetEffect(id)
    return ns.UPGRADES_BY_ID[id].effect(ns.GetLevel(id))
end

function ns.IsMaxed(id)
    local def = ns.UPGRADES_BY_ID[id]
    return def.maxLevel ~= nil and ns.GetLevel(id) >= def.maxLevel
end

-- Cost to buy the next level.
function ns.GetCost(id)
    local def = ns.UPGRADES_BY_ID[id]
    return math.floor(def.baseCost * def.growth ^ ns.GetLevel(id))
end

function ns.CanBuy(id)
    return not ns.IsMaxed(id) and ns.db.coins >= ns.GetCost(id)
end

function ns.Buy(id)
    if not ns.CanBuy(id) then return false end
    ns.db.coins = ns.db.coins - ns.GetCost(id)
    ns.db.upgrades[id] = ns.GetLevel(id) + 1
    ns.Fire("UPGRADE_BOUGHT", id)
    ns.Fire("COINS_CHANGED")
    return true
end
