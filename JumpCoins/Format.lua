-- Format: big-number display (1.23K, 45.6M, 789B ...).

local _, ns = ...

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function Scaled(n, tier)
    local scaled = n / (1000 ^ tier)
    if scaled < 10 then
        return string.format("%.2f", scaled)
    elseif scaled < 100 then
        return string.format("%.1f", scaled)
    end
    return string.format("%.0f", scaled)
end

function ns.FormatNumber(n)
    n = math.floor(n or 0)
    if n < 1000 then
        return string.format("%d", n)
    end

    local tier = 0
    while n >= 1000 ^ (tier + 1) do
        tier = tier + 1
    end

    local text = Scaled(n, tier)
    -- Rounding can push 999.6K up to "1000K"; move to the next suffix instead.
    if tonumber(text) >= 1000 then
        tier = tier + 1
        text = Scaled(n, tier)
    end

    if tier >= #SUFFIXES then
        return string.format("%.2e", n)
    end
    return text .. SUFFIXES[tier + 1]
end

-- Percent with no trailing ".0" (0.05 -> "5%", 0.125 -> "12.5%").
function ns.FormatPercent(fraction)
    -- Round to one decimal first so float noise (0.07 * 100) doesn't show.
    local pct = math.floor(fraction * 1000 + 0.5) / 10
    if pct == math.floor(pct) then
        return string.format("%d%%", pct)
    end
    return string.format("%.1f%%", pct)
end
