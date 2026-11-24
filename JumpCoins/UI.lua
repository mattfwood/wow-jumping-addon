-- UI: the coin display, combo counter and crit popup.

local _, ns = ...

local display

function ns.ApplyBackdrop(frame, alpha)
    if not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0, 0, 0, alpha or 0.7)
end

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil
ns.BACKDROP_TEMPLATE = BACKDROP_TEMPLATE

-------------------------------------------------------------------------------
-- Updates
-------------------------------------------------------------------------------

local function UpdateCoins()
    if not display then return end
    display.coins:SetText("Coins: |cffffd100" .. ns.FormatNumber(ns.db.coins) .. "|r")
end

local function UpdateCombo(self)
    if ns.IsComboActive() and ns.GetLevel("rhythm") > 0 then
        local stacks = math.min(ns.combo - 1, ns.COMBO_MAX_STACKS)
        local bonus = stacks * ns.GetEffect("rhythm")
        display.combo:SetText(string.format("Combo x%d  |cff40ff40+%s|r",
            ns.combo, ns.FormatPercent(bonus)))
    else
        display.combo:SetText("")
        display:SetScript("OnUpdate", nil)
    end
end

local function ShowCritPopup(earned)
    local popup = display.popup
    popup.text:SetText("+" .. ns.FormatNumber(earned) .. " CRIT!")
    popup.anim:Stop()
    popup:Show()
    popup.anim:Play()
    if SOUNDKIT and SOUNDKIT.LOOTWINDOW_COIN_SOUND then
        PlaySound(SOUNDKIT.LOOTWINDOW_COIN_SOUND)
    end
end

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------

local function ShowTooltip(self)
    local db = ns.db
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Jump Coins")
    GameTooltip:AddDoubleLine("Coins", ns.FormatNumber(db.coins), 1, 1, 1, 1, 0.82, 0)
    GameTooltip:AddDoubleLine("Coins per jump", ns.FormatNumber(ns.GetEffect("springBoots")), 1, 1, 1, 1, 1, 1)
    if ns.GetLevel("rhythm") > 0 then
        GameTooltip:AddDoubleLine("Max combo bonus",
            "+" .. ns.FormatPercent(ns.COMBO_MAX_STACKS * ns.GetEffect("rhythm")), 1, 1, 1, 1, 1, 1)
    end
    if ns.GetLevel("luckyLanding") > 0 then
        GameTooltip:AddDoubleLine("Crit chance", ns.FormatPercent(ns.GetEffect("luckyLanding")), 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Lifetime jumps", ns.FormatNumber(db.totalJumps), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
    GameTooltip:AddDoubleLine("Lifetime coins", ns.FormatNumber(db.lifetimeCoins), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
    GameTooltip:AddDoubleLine("Best combo", db.stats.bestCombo, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
    GameTooltip:AddDoubleLine("Crits", ns.FormatNumber(db.stats.crits), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click to open the shop. Drag to move.", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

-------------------------------------------------------------------------------
-- Display frame
-------------------------------------------------------------------------------

local function CreateCritPopup(parent)
    local popup = CreateFrame("Frame", nil, parent)
    popup:SetSize(200, 24)
    popup:SetPoint("BOTTOM", parent, "TOP", 0, 2)
    popup:Hide()

    popup.text = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    popup.text:SetPoint("CENTER")
    popup.text:SetTextColor(1, 0.82, 0)

    local anim = popup:CreateAnimationGroup()
    local move = anim:CreateAnimation("Translation")
    move:SetOffset(0, 30)
    move:SetDuration(1.0)
    local fade = anim:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetStartDelay(0.4)
    fade:SetDuration(0.6)
    anim:SetScript("OnFinished", function() popup:Hide() end)
    popup.anim = anim

    return popup
end

function ns.SetFramePosition(frame, pos)
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
end

local function CreateDisplay()
    local db = ns.db
    local f = CreateFrame("Frame", "JumpCoinsFrame", UIParent, BACKDROP_TEMPLATE)
    f:SetSize(160, 46)
    ns.SetFramePosition(f, db.frame)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    ns.ApplyBackdrop(f)

    f.coins = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.coins:SetPoint("TOP", 0, -8)
    f.coins:SetTextColor(1, 1, 1)

    f.combo = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.combo:SetPoint("BOTTOM", 0, 8)

    f.popup = CreateCritPopup(f)

    f:SetScript("OnMouseDown", function(self) self.dragged = false end)
    f:SetScript("OnDragStart", function(self)
        if db.frame.locked then return end
        self.dragged = true
        self:StartMoving()
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        db.frame.point, db.frame.x, db.frame.y = point, x, y
    end)
    f:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and not self.dragged then
            ns.ToggleShop()
        end
    end)
    f:SetScript("OnEnter", ShowTooltip)
    f:SetScript("OnLeave", GameTooltip_Hide)

    f:SetShown(db.frame.shown)
    display = f
    ns.display = f
    UpdateCoins()
end

ns.On("LOADED", CreateDisplay)
ns.On("COINS_CHANGED", UpdateCoins)
ns.On("JUMP", function(earned, isCrit)
    if not display then return end
    if isCrit then ShowCritPopup(earned) end
    UpdateCombo()
    if ns.IsComboActive() then
        display:SetScript("OnUpdate", UpdateCombo)
    end
end)
