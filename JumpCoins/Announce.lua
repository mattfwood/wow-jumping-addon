-- Announce: big on-screen announcement when a long combo is dropped.

local _, ns = ...

ns.COMBO_ANNOUNCE_MIN = 20

-- Bigger combos get a bigger title and a rarer color (item quality colors).
local TIERS = {
    { min = 100, title = "LEGENDARY COMBO", r = 1.00, g = 0.50, b = 0.00 },
    { min = 50,  title = "EPIC COMBO",      r = 0.64, g = 0.21, b = 0.93 },
    { min = 20,  title = "COMBO",           r = 1.00, g = 0.82, b = 0.00 },
}

local HOLD_SECONDS = 2.5
local FADE_IN_SECONDS = 0.15
local FADE_OUT_SECONDS = 0.8

local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

local banner

function ns.GetComboTier(combo)
    for _, tier in ipairs(TIERS) do
        if combo >= tier.min then return tier end
    end
end

local function CreateBanner()
    local f = CreateFrame("Frame", "JumpCoinsAnnounce", UIParent)
    f:SetSize(700, 110)
    f:SetPoint("TOP", UIParent, "TOP", 0, -150)
    f:SetFrameStrata("HIGH")
    f:EnableMouse(false)
    f:Hide()

    f.title = f:CreateFontString(nil, "OVERLAY")
    f.title:SetFont(FONT, 44, "THICKOUTLINE")
    f.title:SetPoint("TOP", 0, 0)
    f.title:SetShadowOffset(2, -2)

    f.subtitle = f:CreateFontString(nil, "OVERLAY")
    f.subtitle:SetFont(FONT, 18, "OUTLINE")
    f.subtitle:SetPoint("TOP", f.title, "BOTTOM", 0, -8)
    f.subtitle:SetTextColor(1, 1, 1)

    local anim = f:CreateAnimationGroup()
    local fadeIn = anim:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(FADE_IN_SECONDS)
    fadeIn:SetOrder(1)
    local fadeOut = anim:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetStartDelay(HOLD_SECONDS)
    fadeOut:SetDuration(FADE_OUT_SECONDS)
    fadeOut:SetOrder(2)
    anim:SetScript("OnFinished", function() f:Hide() end)
    f.anim = anim

    return f
end

function ns.AnnounceComboDrop(combo, coins, isNewBest)
    local tier = ns.GetComboTier(combo)
    if not tier then return end

    banner = banner or CreateBanner()
    banner.title:SetText(string.format("%dx %s!", combo, tier.title))
    banner.title:SetTextColor(tier.r, tier.g, tier.b)

    local subtitle = "+" .. ns.FormatNumber(coins) .. " coins in the chain"
    if isNewBest then
        subtitle = subtitle .. "  |cff40ff40NEW BEST!|r"
    end
    banner.subtitle:SetText(subtitle)

    banner.anim:Stop()
    banner:Show()
    banner.anim:Play()

    if SOUNDKIT and SOUNDKIT.RAID_WARNING then
        PlaySound(SOUNDKIT.RAID_WARNING)
    end
    ns.Print(string.format("%dx combo dropped: +%s coins%s.", combo,
        ns.FormatNumber(coins), isNewBest and " (new best!)" or ""))
end

ns.On("COMBO_ENDED", function(combo, coins, isNewBest)
    -- Combos are only visible once Rhythm is bought, so only announce then.
    if combo < ns.COMBO_ANNOUNCE_MIN or ns.GetLevel("rhythm") == 0 then return end
    ns.AnnounceComboDrop(combo, coins, isNewBest)
end)
