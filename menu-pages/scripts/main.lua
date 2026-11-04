-- Menu pages: the in-game mod menu's pages about the game. The menu itself (its window, the side bar and
-- WCModsMenu, which any script adds pages with) comes with wcmods; this mod adds pages to it like any
-- other mod does:
--
--   Home       At a glance: your cat, where it is, the time and the fresh-kill pile, and a few buttons
--   Your cat   Stats: health, stamina, level, stats, size
--   World      World (the time of day, the fresh-kill pile), Travel, Nearby, Items
--   Story      Quests: the one you follow, its objectives, every quest's state
--   Fight      both sides of a fight while you're in one
--   Cheats     the engine's cheats, and the game's own developer switches
--
-- It also keeps the line under the menu's title up to date with how your cat is doing (Menu.status).
-- Each group's pages are in pages/<group>.lua; pages/common.lua has what they share.
local okMenu, Menu = pcall(require, "WCModsMenu")
if not okMenu then
    MOD.log("WCModsMenu didn't load, so there's no menu to add pages to: %s", tostring(Menu))
    return
end
if not Game then
    MOD.log("WCModsGame didn't load, so the pages about the game are left out")
    return
end

local P = require("pages.common")
for _, group in ipairs({ "cat", "world", "story", "fight", "cheats" }) do
    local ok, err = pcall(function() require("pages." .. group)(P) end)
    if not ok then MOD.log("the %s pages didn't load: %s", group, tostring(err)) end
end

-- The status line: while the menu is open, twice a second. An older wcmods without Menu.status has the
-- menu's own line instead. The menu shows one script's line at a time (the last one set), so this one
-- steps aside while another script's line is up, and comes back once that's cleared; it would otherwise
-- write over it within a second, as its own line changes with the clock.
if Menu.status then
    local shown = nil
    Game.every(0.5, function()
        local up = Menu.shared and Menu.shared("status")   -- the line the menu has now (nil: can't tell)
        if up ~= nil and up ~= "" and up ~= shown then return end
        local line = Menu.isOpen() and P.statusLine() or ""
        if line ~= (up or shown) then
            shown = line
            Menu.status(line)
        end
    end)
end
