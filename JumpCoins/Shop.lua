-- Shop: window for buying upgrades.

local _, ns = ...

local ROW_HEIGHT = 52
local WIDTH = 360
local HEADER = 44

local shop

local function RefreshRow(row)
    local def = row.def
    local level = ns.GetLevel(def.id)
    local maxed = ns.IsMaxed(def.id)

    row.name:SetText(def.name)
    if maxed then
        row.level:SetText("|cff40ff40MAX|r")
    else
        row.level:SetText("Lv " .. level)
    end

    local now = def.formatEffect(def.effect(level))
    if maxed then
        row.effect:SetText(now)
    else
        local nextText = def.formatEffect(def.effect(level + 1))
        row.effect:SetText(now .. "  |cff808080Next:|r |cff40ff40" .. nextText .. "|r")
    end

    if maxed then
        row.buy:SetText("Maxed")
        row.buy:Disable()
    else
        row.buy:SetText(ns.FormatNumber(ns.GetCost(def.id)))
        row.buy:SetEnabled(ns.CanBuy(def.id))
    end
end

local function Refresh()
    if not shop or not shop:IsShown() then return end
    shop.coins:SetText("Coins: |cffffd100" .. ns.FormatNumber(ns.db.coins) .. "|r")
    for _, row in ipairs(shop.rows) do
        RefreshRow(row)
    end
end

local function CreateRow(parent, def, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(WIDTH - 20, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 10, -HEADER - (index - 1) * ROW_HEIGHT)
    row:EnableMouse(true)
    row.def = def

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(36, 36)
    row.icon:SetPoint("LEFT", 4, 0)
    row.icon:SetTexture(def.icon)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -2)

    row.level = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.level:SetPoint("LEFT", row.name, "RIGHT", 6, 0)

    row.buy = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.buy:SetSize(80, 22)
    row.buy:SetPoint("RIGHT", -4, 0)
    row.buy:SetScript("OnClick", function() ns.Buy(def.id) end)

    row.effect = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.effect:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 2)
    row.effect:SetPoint("RIGHT", row.buy, "LEFT", -6, 0)
    row.effect:SetJustifyH("LEFT")

    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(def.name)
        GameTooltip:AddLine(def.desc, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)

    return row
end

local function CreateShop()
    local f = CreateFrame("Frame", "JumpCoinsShop", UIParent, ns.BACKDROP_TEMPLATE)
    f:SetSize(WIDTH, HEADER + #ns.UPGRADES * ROW_HEIGHT + 12)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    ns.ApplyBackdrop(f, 0.9)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 14, -12)
    f.title:SetText("Jump Coins Shop")

    f.coins = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.coins:SetPoint("TOPRIGHT", -36, -14)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    f.rows = {}
    for i, def in ipairs(ns.UPGRADES) do
        f.rows[i] = CreateRow(f, def, i)
    end

    f:SetScript("OnShow", Refresh)
    f:Hide()

    -- Close with Escape.
    table.insert(UISpecialFrames, "JumpCoinsShop")
    return f
end

function ns.ToggleShop(show)
    shop = shop or CreateShop()
    if show == nil then show = not shop:IsShown() end
    shop:SetShown(show)
end

ns.On("COINS_CHANGED", Refresh)
ns.On("UPGRADE_BOUGHT", Refresh)
