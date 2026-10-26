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
-- (the area gates tell the game when the cat crosses into one).
local lastArea = nil
Game.hook("/Script/Wrc.WrcZoneNameTrigger:OnOverlapBegin", function(self, _, other)
    local p = Game.player()
    if p and valid(other) and other:GetAddress() == p:GetAddress() then lastArea = Game.str(self.ZoneCode) end
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

-- The line under the menu's title: how your cat is doing. "" before you're in the world (the menu's own
-- line shows then).
function P.statusLine()
    local s = P.now()
    if not s.cat then return "" end
    local parts = { string.format("%s, level %s %s", s.name or "Your cat", tostring(s.level or "?"), s.rank or "") }
    if s.hp then parts[#parts + 1] = string.format("health %.0f/%.0f", s.hp, s.maxhp or s.hp) end
    if s.st then parts[#parts + 1] = string.format("stamina %.0f", s.st) end
    if s.territory then parts[#parts + 1] = s.territory .. (s.area and (", " .. s.area) or "") end
    if s.h then parts[#parts + 1] = string.format("%02d:%02d", s.h, s.m or 0) end
    if s.fk then parts[#parts + 1] = string.format("fresh-kill %.0f (%s)", s.fk, s.fkLevel or "?") end
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
function P.questsChanged() questCache.at = -1 end

return P
