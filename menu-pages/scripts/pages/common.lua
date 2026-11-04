-- What the pages share: helpers, your cat and the world (read twice a second, for the pages and the
-- menu's status line), jumping to a place, and quests with the game's own titles.
local Menu = require("WCModsMenu")
local P = { Menu = Menu, THEME = Menu.theme, valid = Game.valid, log = MOD.log }
local valid = P.valid

-- The game's names for items, areas and quests (WCModsNames, from its tables at install). An older wcmods
-- has no areas or quests in it: codes and tags show instead.
local okNames, NAMES = pcall(require, "WCModsNames")
if not okNames or type(NAMES) ~= "table" then NAMES = {} end

P.INTEGER = { IntProperty = true, Int8Property = true, Int16Property = true, Int64Property = true, UInt16Property = true,
              UInt32Property = true, UInt64Property = true, ByteProperty = true, EnumProperty = true }
-- A number for a property of this type: whole for integers, bytes and enums.
function P.asType(v, t) return P.INTEGER[t] and math.floor(v + 0.5) or v end
function P.changed(a, b) return a ~= nil and b ~= nil and math.abs(a - b) > 1e-4 end
function P.words(s) return (tostring(s):gsub("_", " "):gsub("(%l)(%u)", "%1 %2"):gsub("(%u)(%u%l)", "%1 %2")) end
local words = P.words
-- "Gameplay.Inventory.Consumable.MediumHealingHerb" -> "Marigold" (the game's name), or "Medium Healing
-- Herb" from its tag
function P.itemName(tag)
    local name = NAMES.item and NAMES.item(tostring(tag))
    return name or words(tostring(tag):match("([^%.]+)$") or tag)
end
function P.rankOf(level)
    if not level then return nil end
    if level <= 6 then return "Apprentice" elseif level <= 11 then return "Warrior" elseif level <= 15 then return "Deputy" end
    return "Leader"
end
-- "R-05" -> "Willow-Weep"
function P.areaName(code)
    if not code or code == "" then return nil end
    return NAMES.area and NAMES.area(code) or code
end
local TERRITORY = { "ThunderClan", "ShadowClan", "RiverClan", "WindClan", "Moonpool", "the Island" }   -- ELocationsType 1-6

-- Where your cat is: the territory the game puts it in, and the last area whose name the game showed
-- (the area gates tell the game when the cat crosses into one). Forgotten at the main menu, so another save
-- doesn't start with this one's area.
local lastArea = nil
Game.hook("/Script/Wrc.WrcZoneNameTrigger:OnOverlapBegin", function(self, _, other)
    local p = Game.player()
    if p and valid(other) and other:GetAddress() == p:GetAddress() then lastArea = Game.str(self.ZoneCode) end
end)
Game.on("level", function(level)
    if tostring(level or ""):find("MainMenu", 1, true) then lastArea = nil end
end)
local function territory()
    local lib, loc, px = Game.library("AdventureGameState"), {}, {}
    local ok, found = pcall(function() return lib:GetCharacterLocationType(Game.player(), loc, px) end)
    if ok and found then return TERRITORY[loc.Location] end
    return nil
end

-- The cat and the world, read twice a second.
local snap = { at = -1 }
function P.now()
    if os.clock() - snap.at < 0.5 then return snap end
    local s = { at = os.clock() }
    local cat = Game.cat()
    s.cat = cat
    if cat then
        s.name, s.clan, s.level = cat:name(), cat:clan(), cat:level()
        s.rank = P.rankOf(s.level)
        s.hp, s.maxhp, s.st, s.maxst = cat:health(), cat:maxHealth(), cat:stamina(), cat:maxStamina()
        s.xp, s.xpNeeded = cat:xp(), cat:xpNeeded()
        s.territory, s.area = territory(), P.areaName(lastArea)
    end
    s.h, s.m = Game.time.get()
    s.secs = Game.time.seconds()
    s.fk, s.fkLevel = Game.freshKill.value(), Game.freshKill.level()
    s.fight = Game.fight()
    snap = s
    return s
end
function P.refresh() snap.at = -1 end

-- Held values: the World page can hold the time of day and keep the fresh-kill pile up, even with the
-- menu closed (the pile's timer is in world.lua). They're here so every page's time buttons move the held
-- time too, and so the status line and At a glance can say they're on.
P.hold = { time = false, timeAt = 12 * 3600, pile = false, pileAt = 100 }
-- The clock is held through wcmods' shared hold where there is one (Game.time.hold, wcmods #112 on): one hold for
-- every script, the last to hold it has it, and the rest give way, so Hold this time and another script's hold
-- (Tweaks' Hold the clock, a mod being tested) don't fight over the hour. An older wcmods has none: World's own
-- timer puts the clock back each second (P.hold.time, P.hold.timeAt).
P.HOLDER = "Menu pages"
P.sharedHold = Game.time.hold ~= nil and Game.time.held ~= nil
-- The hour held, in seconds, and whose hold it is (nil for none): any script's with the shared hold, else this
-- mod's own.
function P.timeHeld()
    if P.sharedHold then return Game.time.held() end
    if P.hold.time then return P.hold.timeAt, P.HOLDER end
    return nil
end
function P.holdingTime() return select(2, P.timeHeld()) == P.HOLDER end
-- Hold the clock at secs, taking the hold over from another script's; nil lets go of this mod's.
function P.holdTime(secs)
    if P.sharedHold then
        Game.time.hold(secs, P.HOLDER)
    else
        P.hold.time = secs ~= nil
        if secs then
            P.hold.timeAt = secs
            Game.time.setSeconds(secs)
        end
    end
    P.refresh()
end
-- Set the clock. A hold of this mod's moves with it; another script's puts it back.
function P.setSeconds(secs)
    if P.holdingTime() then
        P.holdTime(secs)
    else
        Game.time.setSeconds(secs)
        P.hold.timeAt = secs
    end
    P.refresh()
end
function P.setTime(h, m) P.setSeconds(h * 3600 + (m or 0) * 60) end
-- "07:00", "07:00 (held)", "07:00 (held by Tweaks)"; "80, Abundant", "80, Abundant (kept at 70+)".
function P.timeText(s)
    if not s.h then return nil end
    local _, by = P.timeHeld()
    return string.format("%02d:%02d", s.h, s.m or 0) ..
           (by == P.HOLDER and " (held)" or by and (" (held by " .. tostring(by) .. ")") or "")
end
function P.pileText(s)
    if not s.fk then return nil end
    return string.format("%.0f, %s", s.fk, s.fkLevel or "?") .. (P.hold.pile and string.format(" (kept at %.0f+)", P.hold.pileAt) or "")
end

-- The line under the menu's title: how your cat is doing. "" before you're in the world (the menu's own
-- line shows then).
function P.statusLine()
    local s = P.now()
    if not s.cat then return "" end
    local parts = { string.format("%s, level %s %s", s.name or "Your cat", tostring(s.level or "?"), s.rank or "") }
    if s.hp then parts[#parts + 1] = string.format("health %.0f/%.0f", s.hp, s.maxhp or s.hp) end
    if s.st then parts[#parts + 1] = string.format("stamina %.0f", s.st) end
    if s.territory then parts[#parts + 1] = s.territory .. (s.area and (", " .. s.area) or "") end
    if s.h then parts[#parts + 1] = P.timeText(s) end
    if s.fk then parts[#parts + 1] = "fresh-kill " .. P.pileText(s) end
    if s.fight then parts[#parts + 1] = "IN A FIGHT" end
    return table.concat(parts, "   |   ")
end

-- Travel: jump to a place (onto the ground below it), and back again.
P.travel = { back = nil, note = nil }
function P.jump(to, label, onGround)
    local cat = Game.cat()
    if not (cat and to) then return false end
    P.travel.back = cat:location()
    local z = to.Z
    if not onGround then z = Game.ground(to.X, to.Y, to.Z) or to.Z end
    local ok = cat:teleport(to.X, to.Y, z + 60)
    P.travel.note = (ok and "Went to " or "Couldn't go to ") .. label
    P.refresh()
    return ok
end

-- Quests: titles from the game's quest text (for your cat's rank), and each quest's objectives.
function P.questTitle(q)
    local title = q.tag and NAMES.quest and NAMES.quest(q.tag, P.now().rank)
    return title or words(q.id or "?")
end
P.STATUS_TEXT = { None = "not started", QuestAvailable = "available", OngoingQuest = "in progress",
                  QuestComplete = "ready to hand in", QuestTurnedIn = "done", DialogueProgress = "talking" }
local questCache = { at = -1, list = {} }
function P.quests()
    if os.clock() - questCache.at > 1 then questCache = { at = os.clock(), list = Game.quests.all() } end
    return questCache.list
end
-- A quest's objectives, read once a second (Game.quests.objectives looks through every objective object
-- in the game, too much for every frame).
local objectiveCache = { at = -1, quest = nil, list = {} }
function P.objectives(q)
    local addr = q and q:GetAddress()
    if addr ~= objectiveCache.quest or os.clock() - objectiveCache.at > 1 then
        objectiveCache = { at = os.clock(), quest = addr, list = Game.quests.objectives(q) }
    end
    return objectiveCache.list
end
function P.questsChanged() questCache.at, objectiveCache.at = -1, -1 end

return P
