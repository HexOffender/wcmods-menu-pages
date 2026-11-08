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

-- ---------- What the pages about the rest of the SDK share ----------

-- Whether this wcmods has a part of WCModsGame (Game.ai, Game.tables...): the newer pages ask before they
-- draw, so on an older wcmods they say what's missing instead of failing.
function P.has(...)
    local t = Game
    for _, k in ipairs({ ... }) do
        if type(t) ~= "table" then return false end
        t = t[k]
    end
    return t ~= nil
end
function P.needs(ui, ...)
    if P.has(...) then return true end
    ui.note("This needs a newer wcmods: Game." .. table.concat({ ... }, ".") .. " isn't in the one installed (" ..
            tostring(Game.wcmods or "0.5.0 or older") .. ").")
    return false
end

-- The C++ part's calls (cpp/README.md): WCModsCpp.menuPages, which this mod's own DLL puts in every script's Lua
-- state as it starts. nil without it: not built, or built for another UE4SS (the install leaves it out then).
function P.cpp()
    local all = rawget(_G, "WCModsCpp")
    local c = type(all) == "table" and all.menuPages or nil
    return type(c) == "table" and c or nil
end
P.CPP_HELP = "This needs Menu pages' C++ part (its dlls/main.dll), which isn't in the game: build it with " ..
             "`python wcmods.py cpp build menu-pages` and install, or use a release that has it."
function P.needCpp(ui)
    if P.cpp() then return true end
    ui.note(P.CPP_HELP)
    return false
end
-- A C++ part's call: its results, or nil and why (no C++ part, no such call, or an error in it).
function P.callCpp(name, ...)
    local c = P.cpp()
    if not c then return nil, "the C++ part isn't loaded" end
    if type(c[name]) ~= "function" then return nil, "the C++ part has no " .. name end
    local r = table.pack(pcall(c[name], ...))
    if not r[1] then return nil, tostring(r[2]) end
    return table.unpack(r, 2, r.n)
end

-- What a call costs to ask every frame is asked at most every `seconds`: P.cached("animals", 0.5, fn).
-- Keys can be made from what the player types (Words' prefix, a talk table's rows), so once there are more than
-- `limit`, the ones past their time are dropped: they'd be asked again anyway.
local caches, ncaches, limit = {}, 0, 200
local function prune(now)
    local n = 0
    for k, c in pairs(caches) do
        if now - c.at >= c.seconds then caches[k] = nil else n = n + 1 end
    end
    ncaches, limit = n, math.max(200, n * 2)   -- (so a cache full of fresh keys isn't looked through for each new one)
end
function P.cached(key, seconds, fn)
    local c = caches[key]
    if c and os.clock() - c.at < seconds then return c.value end
    local ok, v = pcall(fn)
    local new = caches[key] == nil
    c = { at = os.clock(), seconds = seconds, value = ok and v or nil }
    caches[key] = c
    if new then
        ncaches = ncaches + 1
        if ncaches > limit then prune(os.clock()) end
    end
    if not ok then P.logOnce(key, v) end
    return c.value
end
function P.forget(key)
    if caches[key] ~= nil then caches[key], ncaches = nil, ncaches - 1 end
end

-- An error said once in UE4SS.log (a page draws every frame, so the same error would fill it).
local said, nsaid = {}, 0
function P.logOnce(what, err)
    local line = tostring(what) .. ": " .. tostring(err)
    if said[line] or nsaid >= 100 then return end
    said[line], nsaid = true, nsaid + 1
    MOD.log("%s", line)
end

-- Each page's last word on what a button did ("Spawned a rabbit", "Couldn't: no generator free").
local notes = {}
function P.say(page, text) notes[page] = text end
function P.said(ui, page)
    if notes[page] then ui.note(notes[page]) end
end
-- Say how a call went: `done` when it worked, else "Couldn't: why". A call failed when it gave false, or nil and
-- a reason; one that gives nothing back at all (a setter) worked.
function P.result(page, done, ok, why)
    local failed = ok == false or (ok == nil and why ~= nil)
    notes[page] = failed and ("Couldn't: " .. tostring(why or "the game said no")) or done
    return not failed
end

-- Anything as short readable text: numbers without trailing zeros, places as "x, y, z", the game's objects by
-- name, tables a few entries deep.
function P.show(v, depth)
    local t = type(v)
    if t == "number" then
        if v == math.floor(v) and math.abs(v) < 1e15 then return string.format("%d", v) end
        local s = string.format("%.3f", v):gsub("0+$", ""):gsub("%.$", "")
        return s
    elseif t == "boolean" then return v and "yes" or "no"
    elseif t == "nil" then return "-"
    elseif t == "string" then return v
    elseif t == "table" then
        if type(v.X) == "number" and type(v.Y) == "number" and type(v.Z) == "number" then
            return string.format("%.0f, %.0f, %.0f", v.X, v.Y, v.Z)
        end
        if (depth or 0) >= 2 then return "{...}" end
        local parts, n = {}, 0
        for k, x in pairs(v) do
            n = n + 1
            if n > 8 then parts[#parts + 1] = "..." break end
            parts[#parts + 1] = (math.type(k) == "integer" and "" or (tostring(k) .. " ")) .. P.show(x, (depth or 0) + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    elseif t == "userdata" then
        local ok, s = pcall(Game.str, v)
        if ok and type(s) == "string" and s ~= "" then return s end
        if Game.valid(v) then return Game.name(v) or "?" end
        local okS, shown = pcall(Game.show, v)
        return okS and tostring(shown) or "?"
    end
    return tostring(v)
end

-- A long list a page of rows at a time, with a filter box when `opts.text(item)` gives an item's text:
-- render(item, i) draws an item's rows. Each list keeps its filter and page by `id`.
local pagers = {}
function P.pager(ui, id, list, render, opts)
    opts = opts or {}
    local st = pagers[id] or { filter = "", page = 1 }
    pagers[id] = st
    local size, shown = opts.size or 15, list or {}
    if opts.text then
        local f = ui.input(opts.label or "Find", st.filter, { hint = opts.hint or "part of its name" })
        if f ~= st.filter then st.filter, st.page = f, 1 end
        if st.filter ~= "" then
            local want, out = st.filter:lower(), {}
            for _, it in ipairs(shown) do
                if tostring(opts.text(it) or ""):lower():find(want, 1, true) then out[#out + 1] = it end
            end
            shown = out
        end
    end
    local pages = math.max(1, math.ceil(#shown / size))
    if st.page > pages then st.page = pages end
    local first, last = (st.page - 1) * size + 1, math.min(#shown, st.page * size)
    for i = first, last do render(shown[i], i) end
    if #shown == 0 then ui.note(opts.empty or "None.") end
    if pages > 1 then
        local hit = ui.buttons({ "Previous " .. size, "Next " .. size })
        if hit == 1 then st.page = math.max(1, st.page - 1) end
        if hit == 2 then st.page = math.min(pages, st.page + 1) end
        ui.note(string.format("%d to %d of %d", first, last, #shown))
    end
    return shown
end

-- An actor picked from a list, kept by its address and looked up again in each new list, so one that has gone
-- since is never used (asking a gone actor anything crashes the game).
local picks = {}
function P.pick(id, actor) picks[id] = actor and Game.valid(actor) and actor:GetAddress() or nil end
function P.picked(id, list, actorOf)
    local want = picks[id]
    if not want then return nil end
    for _, it in ipairs(list or {}) do
        local a = actorOf and actorOf(it) or it.actor
        if a and Game.valid(a) and a:GetAddress() == want then return it end
    end
    return nil
end
function P.pickedId(id) return picks[id] end

-- A place a few metres in front of your cat with room for a cat (Game.npcs.spot), or right ahead of it.
function P.spot(cm)
    if P.has("npcs", "spot") then
        local ok, at, yaw = pcall(Game.npcs.spot, cm)
        if ok and at then return at, yaw end
    end
    local cat = Game.cat()
    local l = cat and cat:location()
    if not l then return nil end
    return { X = l.X + (cm or 220), Y = l.Y, Z = l.Z }
end

-- Where your cat is, nil in menus.
function P.here()
    local cat = Game.cat()
    return cat and cat:location() or nil
end
function P.addr(actor) return actor and Game.valid(actor) and actor:GetAddress() or nil end

-- A blackboard's keys as rows: switches for Bool keys, number boxes for Float and Int, the rest shown; Clear on
-- each key that's set (Game.ai: the tree sees a change at once).
function P.blackboardRows(ui, actor, page)
    local keys = Game.ai.keys(actor) or {}
    if #keys == 0 then ui.note("No blackboard (no AI).") return end
    for _, k in ipairs(keys) do
        local v = Game.ai.get(actor, k.name)
        if k.type == "Bool" then
            local now = v == true
            if ui.toggle(k.name, now) ~= now then P.result(page, k.name .. " set", Game.ai.set(actor, k.name, not now)) end
        elseif k.type == "Float" or k.type == "Int" then
            local n = tonumber(v) or 0
            local nv = ui.number(k.name, n, { step = k.type == "Int" and 1 or 0.1, whole = k.type == "Int" })
            if math.abs(nv - n) > 1e-6 then P.result(page, k.name .. " set", Game.ai.set(actor, k.name, nv)) end
        else
            ui.field(k.name .. "  (" .. k.type .. ")", P.show(v))
            if v ~= nil and (k.type == "Vector" or k.type == "Object") and ui.button("Clear " .. k.name) then
                P.result(page, k.name .. " cleared", Game.ai.clear(actor, k.name))
            end
        end
    end
end

-- A struct's fields (a DataTable row's, say): { {name, type}, ... } from its UScriptStruct, nil when it can't
-- be read.
function P.structFields(struct)
    if not Game.valid(struct) then return nil end
    local out = {}
    local ok = pcall(function()
        local s = struct
        while Game.valid(s) do
            s:ForEachProperty(function(p)
                local okT, t = pcall(function() return p:GetClass():GetFName():ToString() end)
                out[#out + 1] = { name = p:GetFName():ToString(), type = okT and t or "?" }
            end)
            local okS, super = pcall(function() return s:GetSuperStruct() end)
            s = okS and super or nil
        end
    end)
    return ok and out or nil
end

return P
