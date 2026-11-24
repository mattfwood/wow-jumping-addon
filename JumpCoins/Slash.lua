-- Slash: /jc commands.

local _, ns = ...

local HELP = "Commands: /jc [toggle|show|hide|shop|lock|count|resetpos|reset]"

SLASH_JUMPCOINS1 = "/jc"
SLASH_JUMPCOINS2 = "/jumpcoins"
SlashCmdList.JUMPCOINS = function(input)
    local db, display = ns.db, ns.display
    if not db or not display then return end

    local cmd = strlower(strtrim(input or ""))
    if cmd == "" or cmd == "toggle" then
        db.frame.shown = not display:IsShown()
        display:SetShown(db.frame.shown)
    elseif cmd == "show" then
        db.frame.shown = true
        display:Show()
    elseif cmd == "hide" then
        db.frame.shown = false
        display:Hide()
    elseif cmd == "shop" then
        ns.ToggleShop()
    elseif cmd == "lock" then
        db.frame.locked = not db.frame.locked
        ns.Print(db.frame.locked and "Frame locked." or "Frame unlocked.")
    elseif cmd == "count" then
        ns.Print(string.format("%s coins, %s lifetime jumps.",
            ns.FormatNumber(db.coins), ns.FormatNumber(db.totalJumps)))
    elseif cmd == "resetpos" then
        local pos = ns.DEFAULT_FRAME_POS
        db.frame.point, db.frame.x, db.frame.y = pos.point, pos.x, pos.y
        ns.SetFramePosition(display, db.frame)
    elseif cmd == "reset" then
        ns.Print("This wipes all coins, upgrades and stats. Type |cffffd100/jc reset confirm|r to do it.")
    elseif cmd == "reset confirm" then
        ns.ResetProgress()
        ns.Print("Progress reset.")
    else
        ns.Print(HELP)
    end
end
