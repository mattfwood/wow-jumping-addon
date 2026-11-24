-- luacheck config. Run from the repo root:  luacheck .

std = "lua51"
max_line_length = 140

-- WoW event handlers and scripts often receive arguments they don't use.
unused_args = false

exclude_files = { ".luarocks", "lua_modules" }

files["JumpCoins/"] = {
    -- Globals the addon defines or writes.
    globals = {
        "JumpCoinsDB",
        "SLASH_JUMPCOINS1",
        "SLASH_JUMPCOINS2",
        "SlashCmdList",
    },
    -- WoW API the addon reads. Add new API functions here when you use them.
    read_globals = {
        "BackdropTemplateMixin",
        "CreateFrame",
        "GameTooltip",
        "GameTooltip_Hide",
        "GetTime",
        "hooksecurefunc",
        "IsFalling",
        "IsFlying",
        "IsSwimming",
        "PlaySound",
        "SOUNDKIT",
        "STANDARD_TEXT_FONT",
        "strlower",
        "strtrim",
        "UIParent",
        "UISpecialFrames",
        "UnitOnTaxi",
    },
}

-- The test harness and dev tools stub the WoW API by defining globals on
-- purpose. 131 (unused global) is ignored because the addon files, not the
-- harness, use the stubs, which only shows when a file is linted on its own.
local harness = {
    std = "+max",
    allow_defined_top = true,
    ignore = { "111", "112", "113", "121", "122", "131", "142", "143" },
}
files["tests/"] = harness
files["tools/"] = harness
