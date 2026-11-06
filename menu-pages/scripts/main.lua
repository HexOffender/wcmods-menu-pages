-- Menu pages: the in-game mod menu's pages about the game. The menu itself (its window, the side bar and
-- WCModsMenu, which any script adds pages with) comes with wcmods; this mod adds pages to it like any
-- other mod does:
--
--   Home       At a glance: your cat, where it is, the time and the fresh-kill pile, and a few buttons;
--              SDK map: every part of the SDK, whether this game has it, and its page
--   Your cat   Stats, Looks, Movement, Animations
--   World      World (the time of day, the fresh-kill pile), Travel, Nearby, Items, Animals, Walking cats,
--              Your own cats, Dens, Sky and sound, Camera, HUD and map
--   Story      Quests, Scenes, Talk, Bonds
--   Fight      both sides of a fight while you're in one, your cat's turns, and starting one
--   Cheats     the engine's cheats, the game's own developer switches, and its tuning
--   Tools      Engine, Tables, Words, Events, Save data, Game UI
--
-- Together they reach everything WCModsGame and the modules beside it can do, and with the mod's C++ part
-- (cpp/, WCModsCpp.menuPages) what only wcmods' C++ SDK can. A page whose part isn't in this wcmods says so.
-- It also keeps the line under the menu's title up to date with how your cat is doing (Menu.status).
-- The pages are in pages/<file>.lua; pages/common.lua has what they share.
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
for _, group in ipairs({ "cat", "body", "world", "creatures", "places", "story", "fight", "cheats", "tools" }) do
    local ok, err = pcall(function() require("pages." .. group)(P) end)
    if not ok then MOD.log("the %s pages didn't load: %s", group, tostring(err)) end
end

-- The status line, twice a second. An older wcmods without Menu.status has the menu's own line instead. A
-- wcmods with Menu.statusShown keeps a line for each script and chooses whose to show (this mod's on its own
-- pages), so this just keeps its line up to date. Before that (0.5.0 and older) the menu showed one script's
-- line, the last one set, while it was open: this one steps aside while another script's line is up, and
-- comes back once that's cleared; it would otherwise write over it within a second, as its own line changes
-- with the clock.
if Menu.status then
    -- This mod's last line, kept in a shared variable of its own: shared variables outlive a UE4SS hot reload,
    -- so after one it still knows which line up there is its own, and which is another script's.
    local KEY = "MenuPages.statusLine"
    local okMine, mine = pcall(function() return ModRef:GetSharedVariable(KEY) end)
    local shown = okMine and type(mine) == "string" and mine or nil
    -- On 0.5.0 and older, with no line of its own kept: a line up now may be this mod's from a version that kept
    -- none, hot-reloaded from, which would otherwise be taken for another script's and left up as it was for
    -- good. Once there's a cat (not here, as the mods load), it's taken for this mod's own if it's still the
    -- line up and starts as this mod's line for this cat does ("<name>, level "), and has its "   |   ".
    local maybeMine = shown == nil and not Menu.statusShown and Menu.shared and Menu.shared("status") or nil
    if maybeMine == "" then maybeMine = nil end
    local function put(line)
        shown = line
        pcall(function() ModRef:SetSharedVariable(KEY, line) end)
        Menu.status(line)
    end
    local function update()
        if Menu.statusShown then
            -- Kept up to date with the menu closed too: the menu reads the lines as it opens, before this could
            -- change it. A changed line keeps its place among the scripts' lines. (Not cleared when the menu
            -- closes: put up again at each open, it would always be the newest line, and show over other
            -- scripts' lines on the pages of mods that have none of their own, such as Overview.)
            -- While the cat is only away for a moment (a loading screen), the line stays as it was: taken down
            -- and put up again, it would be the newest line. It comes down at the main menu.
            local line = P.statusLine()
            if line == "" and shown and shown ~= "" and not tostring(Game.levelName() or ""):find("MainMenu", 1, true) then
                return
            end
            if line ~= shown then put(line) end
            return
        end
        local up = Menu.shared and Menu.shared("status")   -- the line the menu has now (nil: can't tell)
        if maybeMine then
            local name = P.statusLine():match("^(.-), level ")
            if name == "Your cat" then name = nil end   -- (P.statusLine's name for a cat whose name isn't read)
            if up ~= maybeMine then
                maybeMine = nil
            elseif name then   -- (no cat yet, a load, or its name not read yet: asked again at the next tick)
                if up:sub(1, #name + 8) == name .. ", level " and up:find("   |   ", 1, true) then shown = up end
                maybeMine = nil
            end
        end
        if up ~= nil and up ~= "" and up ~= shown then return end
        local line = Menu.isOpen() and P.statusLine() or ""
        if line ~= (up or shown) then put(line) end
    end
    Game.every(0.5, update)
    if not Menu.statusShown then
        -- On 0.5.0 and older the line is taken down while the menu is closed: as it opens, the line at once,
        -- rather than at the next tick.
        local wasOpen = false
        Game.onFrame(function()
            local open = Menu.isOpen()
            if open and not wasOpen then update() end
            wasOpen = open
        end)
    end
end
