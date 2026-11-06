-- World: the time of day and the fresh-kill pile, Travel, Nearby and Items.
return function(P)
    local Menu, now, refresh, changed, valid = P.Menu, P.now, P.refresh, P.changed, P.valid

    -- Held values: the World page can hold the time of day and keep the fresh-kill pile up, even with the
    -- menu closed (P.hold, and the clock's hold in common.lua, which the status line shows). Going back to the
    -- main menu lets go of them, so a save loaded next doesn't start held.
    local hold = P.hold
    if P.sharedHold then
        -- The shared hold is kept up by the Lua state that holds it: after a UE4SS hot reload, the old state has
        -- gone, and its hold would be no hold 3 s after its last word. A hold of this mod's from before the reload
        -- is taken up again at the first frame (counted from when this state loaded: 3 s from the hold's last word,
        -- which may be up to 0.5 s before the old state went, so a reload of up to about 2.5 s keeps it).
        Game.after(0, function()
            local at, by = Game.time.held()
            if at and by == P.HOLDER then Game.time.hold(at, P.HOLDER) end
        end)
    end
    Game.every(1, function()
        if not P.sharedHold and hold.time then Game.time.setSeconds(hold.timeAt) end
        if hold.pile then
            local v = Game.freshKill.value()
            if v and v < hold.pileAt then Game.freshKill.set(hold.pileAt) end
        end
    end)
    Game.on("level", function(level)
        if tostring(level or ""):find("MainMenu", 1, true) then
            if P.holdingTime() then P.holdTime(nil) end
            hold.time, hold.pile = false, false
        end
    end)

    Menu.page("World", function(ui)
        ui.heading("The world")
        local s = now()
        if not s.secs then
            ui.text("Not in the world yet.")
            return
        end
        ui.columns({ { "Territory", s.territory or "?" }, { "Area", s.area or "(shows once you cross into one)" },
                     { "Time", P.timeText(s) or "?" }, { "Level", Game.levelName() or "?" } })
        ui.section("Time of day", function()
            local hours = ui.slider("Clock", s.secs / 3600, 0, 23.99, { step = 0.25, format = "%.2f h" })
            if math.abs(hours - s.secs / 3600) > 0.2 then P.setSeconds(hours * 3600) end
            local hit = ui.buttons({ "Dawn 6:00", "Noon", "Dusk 19:00", "Night 23:00" })
            local at = ({ 6, 12, 19, 23 })[hit or 0]
            if at then P.setTime(at, 0) end
            local heldAt, heldBy = P.timeHeld()
            local mine = heldBy == P.HOLDER
            local holding = ui.switch("Hold this time", mine)
            if holding ~= mine then P.holdTime(holding and s.secs or nil) end
            if heldAt and not mine then
                ui.note(string.format("Held by %s at %02d:%02d: the clock goes back to that, so Clock and the buttons " ..
                                      "above are put back. Hold this time takes the hold over.", tostring(heldBy),
                                      math.floor(heldAt / 3600), math.floor(heldAt % 3600 / 60)))
            end
            ui.note("A game day passes in about 20 minutes (DayNight.ClockSpeed 72). Going back to the main menu lets go " ..
                    "of a held time or pile." .. (P.sharedHold and (" Hold this time holds the clock through wcmods' one " ..
                    "hold for every script (Game.time.hold): the last to hold it has it, and Tweaks' Hold the clock gives " ..
                    "way to it.") or ""))
        end, { id = "world-time", open = true })
        ui.section("Fresh-kill pile", function()
            if not s.fk then
                ui.text("No fresh-kill pile here.")
                return
            end
            local fk = ui.slider("Pile", s.fk, 0, 100, { step = 1, format = "%.0f" })
            if changed(fk, s.fk) then
                Game.freshKill.set(fk)
                hold.pileAt = fk
                refresh()
            end
            ui.field("The pile is", s.fkLevel or "?")
            local t, every = Game.freshKill.timer(), Game.freshKill.decayTime()
            if t and every then
                ui.field("Goes down by 1", string.format("in %.0f s (every %.0f s)", math.max(0, every - t), every))
                local nv = ui.number("Seconds between drops", every, { min = 1, max = 600, step = 5 })
                if changed(nv, every) then Game.freshKill.setDecayTime(nv) end
            end
            local holding = ui.switch("Keep it at least here", hold.pile)
            if holding and not hold.pile then hold.pileAt = s.fk end
            hold.pile = holding
            ui.note("Full (90+) and Abundant (70+) give your cat bonuses; Scarcity (below 50) and Critical (below 25) cost it.")
        end, { id = "world-pile", open = true })
    end, { order = 20, group = "world" })

    -- ---------- Travel ----------
    local travel, jump = P.travel, P.jump
    -- Saved spots are kept beside the game's saves (WCMods in its Saved folder, which every install makes),
    -- so they stay when this mod is updated.
    local folder = Game.save.folder and Game.save.folder()
                   or (Game.save.path():gsub("[\\/]SaveGames[\\/][^\\/]*$", "\\WCMods"))
    local PLACES = folder .. "\\places.json"
    local NEW, OLD = PLACES .. ".new", PLACES .. ".old"
    -- places.list: the spots as read (again with "Read it again"). Anything but no file yet, an empty one or
    -- one list of spots isn't written over: places.bad says why (places.fix what to do, when it's not "fix or
    -- move it"), and saving waits until it's fixed or moved.
    local places = { list = nil, name = "", bad = nil, fix = nil }
    -- Where the list that starts at i ends (its "]"), skipping strings; nil if it doesn't. Game.json.decode
    -- stops after the first value, so this is how text after the list is caught.
    local function listEnd(text, i)
        local depth, inString, escaped = 0, false, false
        for j = i, #text do
            local c = text:sub(j, j)
            if inString then
                if escaped then escaped = false
                elseif c == "\\" then escaped = true
                elseif c == '"' then inString = false end
            elseif c == '"' then inString = true
            elseif c == "[" or c == "{" then depth = depth + 1
            elseif c == "]" or c == "}" then
                depth = depth - 1
                if depth == 0 then return j end
            end
        end
        return nil
    end
    -- An SDK error without the "...\WCModsGame.lua:499: " that says where in wcmods it was raised (the decoder's
    -- error, an assert in Menu.saveJson): that says nothing about the file.
    local function unplace(err) return (tostring(err):gsub("^.-:%d+: ", "")) end
    -- The spots in a file: its list, or nil, why and (when it couldn't be opened) io.open's error code, 2 for
    -- no file. An empty file is no spots, and says so (true after the list).
    local function readList(path)
        local f, err, code = io.open(path, "rb")
        if not f then return nil, tostring(err), code end
        local text, readErr = f:read("a")
        f:close()
        if not text then return nil, tostring(readErr) end
        text = text:gsub("^\239\187\191", "")   -- a UTF-8 byte order mark (Notepad's)
        local start = text:find("%S")
        if not start then return {}, true end
        local data, decodeErr = Game.json.decode(text)
        local stop = text:sub(start, start) == "[" and listEnd(text, start)
        if data == nil then return nil, unplace(decodeErr or "not JSON") end
        if not stop or text:find("%S", stop + 1) then return nil, "not one list of spots" end
        return data
    end
    local function loadPlaces()
        if places.list then return places.list end
        places.list, places.bad, places.fix = {}, nil, nil
        local list, why, code = readList(PLACES)
        if list then
            places.list = list
        elseif code ~= 2 then
            -- Anything but no file yet (another program holding it, say) isn't "no spots".
            places.bad = why
        else
            -- No places.json. A save that didn't finish took it away: the new list is in places.json.new, written
            -- and read back before places.json was moved to places.json.old, and the list before it is in .old.
            -- The new list is taken and put in places.json's place, which finishes that save.
            local new, newWhy, newCode = readList(NEW)
            local old = io.open(OLD, "rb")
            if old then old:close() end
            if new and newWhy ~= true then
                local moved, err = os.rename(NEW, PLACES)
                places.list = new
                if moved then
                    -- The list before that save is out of date now (and, left there, would be taken for the one
                    -- to rename back if places.json went missing again).
                    os.remove(OLD)
                    travel.note = "places.json was missing: the spots from its last save, left in places.json.new, " ..
                                  "are back in it"
                else
                    places.bad = "it's missing, and places.json.new, which has the spots from its last save, couldn't " ..
                                 "take its place (" .. tostring(err) .. ")"
                    places.fix = "Rename places.json.new to places.json, then Read it again."
                end
            elseif old then
                places.bad = "it's missing; places.json.old has the spots from before a save that didn't finish" ..
                             (new == nil and newCode ~= 2 and (", and places.json.new is no good (" .. tostring(newWhy) .. ")") or "")
                places.fix = "Rename places.json.old to places.json, then Read it again."
            end
            -- (A places.json.new that's empty or no good, with no places.json.old beside it, is from the first save,
            -- stopped before it was written whole: there were no spots before it, and the next save writes over it.)
        end
        return places.list
    end
    -- Write a new list of spots. It goes to places.json.new first and is read back before it takes the old
    -- file's place, so a write that fails part way (a full disk) leaves the spots as they were; the new list
    -- becomes the list only once it's in place.
    local function savePlaces(list)
        if places.bad then
            return false, "places.json couldn't be read (" .. places.bad .. ")" ..
                          (places.fix and (". " .. places.fix) or ", so it's left as it is")
        end
        -- A read-only places.json is left as it is: Windows would let it be moved aside, and the read-only
        -- places.json.old couldn't then be removed, which would stop every save after.
        local probe, perr, pcode = io.open(PLACES, "r+b")
        if probe then
            probe:close()
        elseif pcode ~= 2 then
            return false, "places.json can't be written (" .. tostring(perr) .. "): is it read-only, or open in another program?"
        end
        local ok, err = Menu.saveJson(NEW, Menu.list(list))
        if not ok then err = unplace(err) end
        if ok then
            local back = readList(NEW)
            if type(back) ~= "table" or #back ~= #list then ok, err = false, "it didn't write whole" end
        end
        if ok then
            local gone, rerr, rcode = os.remove(OLD)
            if not gone and rcode ~= 2 then ok, err = false, "couldn't remove places.json.old (" .. tostring(rerr) .. ")" end
        end
        if ok then
            local had, aerr, acode = os.rename(PLACES, OLD)   -- (fails with 2 when there's no places.json yet)
            if not had and acode ~= 2 then
                ok, err = false, "couldn't move places.json aside (" .. tostring(aerr) .. ")"
            else
                ok, err = os.rename(NEW, PLACES)
                if ok then
                    os.remove(OLD)
                else
                    err = "couldn't put places.json.new in its place (" .. tostring(err) .. ")"
                    if had and not os.rename(OLD, PLACES) then
                        -- Nor could the old one be put back: there's no places.json now, and the page reads the
                        -- file again.
                        err = err .. "; the spots are in places.json.old now"
                        places.list = nil
                    end
                end
            end
        end
        os.remove(NEW)
        if ok then places.list = list end
        return ok, err
    end
    local function copy(list)
        local out = {}
        for i, v in ipairs(list) do out[i] = v end
        return out
    end
    local spots = { at = -1, checkpoints = {}, areas = {} }
    local function findSpots()
        if os.clock() - spots.at < 5 then return spots end
        local s = { at = os.clock(), checkpoints = {}, areas = {} }
        for _, c in ipairs(Game.findAll("SwtQuestCheckpoint")) do
            local code = Game.str(Game.get(c, "ZoneCode", ""))
            local ok, l = pcall(function() return c:K2_GetActorLocation() end)
            if ok then s.checkpoints[#s.checkpoints + 1] = { code = code, label = P.areaName(code) or Game.name(c), at = { X = l.X, Y = l.Y, Z = l.Z } } end
        end
        table.sort(s.checkpoints, function(a, b) return a.code < b.code end)
        local seen = {}
        for _, z in ipairs(Game.findAll("WrcZoneNameTrigger")) do
            local code = Game.str(Game.get(z, "ZoneCode", ""))
            if code ~= "" and not seen[code] then
                local ok, l = pcall(function() return z:K2_GetActorLocation() end)
                if ok then
                    seen[code] = true
                    s.areas[#s.areas + 1] = { code = code, label = P.areaName(code), at = { X = l.X, Y = l.Y, Z = l.Z } }
                end
            end
        end
        table.sort(s.areas, function(a, b) return a.code < b.code end)
        spots = s
        return s
    end
    local TERRITORY_OF = { T = "ThunderClan", S = "ShadowClan", R = "RiverClan", W = "WindClan", M = "Moonpool", I = "the Island" }

    Menu.page("Travel", function(ui)
        ui.heading("Travel")
        local cat = Game.cat()
        if not cat then
            ui.text("Not in the world yet.")
            return
        end
        local here = cat:location()
        local s = now()
        ui.field("You're at", string.format("%.0f, %.0f, %.0f   (%s%s)", here.X, here.Y, here.Z, s.territory or "?",
                                             s.area and (", " .. s.area) or ""))
        if travel.note then ui.note(travel.note) end
        local hit = ui.buttons({ "Back", "Save this spot" })
        if hit == 1 and travel.back then jump(travel.back, "where you were", true) end
        if hit == 2 then
            places.list = nil   -- from the file as it is now, so a hand edit made while the game runs isn't written over
            local list = copy(loadPlaces())
            local name = places.name ~= "" and places.name or string.format("Spot %d", #list + 1)
            list[#list + 1] = { name = name, level = Game.levelName(), X = here.X, Y = here.Y, Z = here.Z }
            local ok, err = savePlaces(list)
            if ok then
                travel.note, places.name = "Saved " .. name, ""
            else
                travel.note = "Couldn't save the spot: " .. tostring(err)
            end
        end
        places.name = ui.input("Name for a saved spot", places.name, { hint = "e.g. the big oak" })

        ui.section("Saved spots", function()
            local list, level, shown = loadPlaces(), Game.levelName(), 0
            if places.bad then
                ui.text("places.json couldn't be read (" .. places.bad .. "). " ..
                        (places.fix or "It's left as it is: fix or move it, then Read it again."), { color = P.THEME.danger })
            end
            for _, p in ipairs(list) do
                -- (a spot without a place, from a hand edit, is kept in the file but has no button)
                if type(p) == "table" and p.level == level and tonumber(p.X) and tonumber(p.Y) and tonumber(p.Z) then
                    shown = shown + 1
                    local h = ui.buttons({ "Go: " .. tostring(p.name), "Forget" }, { kinds = { "primary", "danger" } })
                    if h == 1 then jump({ X = tonumber(p.X), Y = tonumber(p.Y), Z = tonumber(p.Z) }, tostring(p.name), true)
                    elseif h == 2 then
                        -- From the file as it is now (as Save), and this spot by what it is, not where it was in the list.
                        places.list = nil
                        local rest, at = copy(loadPlaces()), nil
                        for j, q in ipairs(rest) do
                            if type(q) == "table" and q.name == p.name and q.level == p.level and q.X == p.X and q.Y == p.Y
                                and q.Z == p.Z then
                                at = j
                                break
                            end
                        end
                        if at or places.bad then
                            if at then table.remove(rest, at) end
                            local ok, err = savePlaces(rest)
                            travel.note = ok and ("Forgot " .. tostring(p.name)) or ("Couldn't forget it: " .. tostring(err))
                        else
                            travel.note = tostring(p.name) .. " isn't in places.json any more (it was edited since); the " ..
                                          "list below is the file as it is now."
                        end
                        break
                    end
                end
            end
            if shown == 0 and not places.bad then ui.note("None yet. Name a spot above and press Save this spot.") end
            ui.note("Kept in " .. PLACES .. ".")
            if ui.button("Read it again") then places.list, travel.note = nil, nil end
        end, { id = "travel-saved", open = true })

        if P.has("places", "list") then
            ui.section("The game's travel points", function()
                ui.note("Game.places: the checkpoints your cat can travel to, and whether its save has them unlocked (as of " ..
                        "its last save). Travel puts your cat there with no loading screen." ..
                        (P.cpp() and (" Unlock and Through the map are the C++ part's: the game's own unlock, and its world " ..
                                      "map's travel, which needs the travel map open (the button below, at a checkpoint).") or ""))
                if ui.button("Open the travel map (standing at a checkpoint)") then
                    P.result("travel", "The travel map is open.", Game.places.openTravelMap())
                end
                local canCpp = P.cpp() ~= nil
                for _, pl in ipairs(P.cached("travel.places", 2, Game.places.list) or {}) do
                    local name = string.format("%s  (%s)%s", P.areaName(pl.zone) or tostring(pl.zone), tostring(pl.tag):gsub("^Gameplay%.Checkpoints%.", ""),
                                               pl.unlocked and "" or ", locked")
                    local labels = { "Travel: " .. name }
                    if canCpp then
                        labels[2] = pl.unlocked and "Lock" or "Unlock"
                        labels[3] = "Through the map"
                    end
                    local hit = ui.buttons(labels, { kinds = { pl.unlocked and "primary" or nil } })
                    if hit == 1 then
                        P.result("travel", "Went to " .. name .. ".", Game.places.travel(pl))
                    elseif hit == 2 then
                        P.result("travel", (pl.unlocked and "Locked " or "Unlocked ") .. name .. ".",
                                 P.callCpp("unlock_place", pl.tag, not pl.unlocked))
                        P.forget("travel.places")
                    elseif hit == 3 then
                        P.result("travel", "Travelling to " .. name .. " through the world map.", P.callCpp("map_travel", pl.tag))
                    end
                end
                P.said(ui, "travel")
            end, { id = "travel-places", open = false })
        end

        local found = findSpots()
        ui.section("Checkpoints", function()
            ui.note("The game's own checkpoints, by area.")
            for _, c in ipairs(found.checkpoints) do
                if ui.button(string.format("%s  (%s)", c.label, c.code)) then jump(c.at, c.label, true) end
            end
        end, { id = "travel-checkpoints", open = false })
        for _, letter in ipairs({ "T", "S", "R", "W", "M", "I" }) do
            local list = {}
            for _, a in ipairs(found.areas) do
                if a.code:sub(1, 1) == letter then list[#list + 1] = a end
            end
            if #list > 0 then
                ui.section("Areas: " .. TERRITORY_OF[letter], function()
                    for _, a in ipairs(list) do
                        if ui.button(string.format("%s  (%s)", a.label or a.code, a.code)) then jump(a.at, a.label or a.code) end
                    end
                end, { id = "travel-" .. letter, open = false })
            end
        end
        ui.note("A jump puts your cat on the ground at the place (an area's own entrance). Back returns to where you " ..
                "were. Quest objectives you can travel to are on the Quests page.")
    end, { order = 21, group = "world" })

    -- ---------- Nearby ----------
    -- Nearby things, through WCModsWorld: any kinds at once, each in its own colour, in the list and (with
    -- "Mark them on screen") as markers drawn with WCModsDraw.
    local okWorld, World = pcall(require, "WCModsWorld")
    local okDraw, Draw = pcall(require, "WCModsDraw")
    if okWorld then
        local show, marks = P.show, {}
        local look = { radius = 3000, mark = false, on = { pickups = true }, colors = {} }
        local function colorOf(kind) return look.colors[kind] or World.kindColor(kind) end
        local found, foundAt, foundKey = {}, nil, ""
        local function nearby()
            local kinds = {}
            for _, k in ipairs(World.kindOrder()) do
                if look.on[k] then kinds[#kinds + 1] = k end
            end
            local key = table.concat(kinds, ",") .. "@" .. look.radius
            if foundAt == nil or key ~= foundKey or os.clock() - foundAt >= 0.5 then
                foundAt, foundKey = os.clock(), key
                local all = {}
                for _, k in ipairs(kinds) do
                    for _, it in ipairs(World.nearby(k, look.radius)) do
                        it.kind = k
                        all[#all + 1] = it
                    end
                end
                table.sort(all, function(a, b) return a.distance < b.distance end)
                found = all
            end
            return found
        end
        Menu.page("Nearby", function(ui)
            ui.heading("Nearby")
            ui.note("What's around your cat, from the game's own objects (WCModsWorld). Tick the kinds to show; " ..
                    "each has its own colour, here and on screen.")
            local r = ui.slider("Within", look.radius, 500, 20000, { step = 500, format = "%.0f cm" })
            if math.abs(r - look.radius) >= 1 then look.radius, foundAt = r, nil end
            if okDraw then look.mark = ui.switch("Mark them on screen", look.mark) end
            for _, k in ipairs(World.kindOrder()) do
                look.on[k] = ui.toggle(World.kindLabel(k), look.on[k] or false, { swatch = colorOf(k) })
            end
            ui.section("Colours", function()
                for _, k in ipairs(World.kindOrder()) do look.colors[k] = ui.color(World.kindLabel(k), colorOf(k)) end
            end, { open = false })
            ui.separator()
            if not World.player() then
                ui.text("Not in the world yet.")
                return
            end
            local list = nearby()
            ui.field("Found", #list)
            -- One of them picked (by its address, so it's looked up again in each new list): what it is, and going to it.
            ui.section("One of them", function()
                local labels, chosen = { "(none)" }, P.picked("nearby", list)
                for i, it in ipairs(list) do
                    if i > 40 then break end
                    labels[#labels + 1] = string.format("%d. %s", i, it.label)
                end
                local now = "(none)"
                for i, it in ipairs(list) do
                    if it == chosen and i <= 40 then now = labels[i + 1] end
                end
                local want = ui.choice("Pick", now, labels)
                if want ~= now then
                    local i = tonumber(want:match("^(%d+)%."))
                    P.pick("nearby", i and list[i] and list[i].actor or nil)
                    chosen = i and list[i] or nil
                end
                if not chosen then
                    ui.note("Pick one to see what it is (WCModsWorld.describe), go to it or mark it on the map.")
                    return
                end
                local d = World.describe(chosen.actor)
                if d then
                    ui.columns({ { "Name", show(d.name) }, { "Class", show(d.class) }, { "Where", show(d.location) },
                                 { "Away", string.format("%.0f m", chosen.distance / 100) } })
                    ui.field("Made from", table.concat(d.parents or {}, ", "))
                end
                local hit = ui.buttons({ "Go to it", "Mark it on the map", "Take the marks off" })
                if hit == 1 then P.jump(chosen.location, chosen.label)
                elseif hit == 2 and P.has("mapMarker") then
                    local m, why = Game.mapMarker(chosen.actor, { icon = "search" })
                    if m then marks[#marks + 1] = m end
                    P.result("nearby", "Marked on the minimap and the world map.", m ~= nil, why)
                elseif hit == 3 then
                    for _, m in ipairs(marks) do pcall(m.remove, m) end
                    marks = {}
                    P.say("nearby", "Marks taken off.")
                end
                P.said(ui, "nearby")
            end, { id = "nearby-one", open = false })
            for i, it in ipairs(list) do
                if i > 40 then
                    ui.note(string.format("... and %d more", #list - 40))
                    break
                end
                ui.field(string.format("%.0f m", it.distance / 100), it.label .. "   (" .. World.kindLabel(it.kind) .. ")",
                         { color = colorOf(it.kind) })
            end
        end, { order = 22, group = "world" })
        if okDraw then
            Draw.onFrame(function(d)
                if not look.mark then return end
                local shown, per = 0, {}
                for _, it in ipairs(nearby()) do
                    if shown >= 80 then break end
                    per[it.kind] = (per[it.kind] or 0) + 1
                    if per[it.kind] <= 20 and valid(it.actor) then
                        shown = shown + 1
                        d.marker(it.location, it.label, { color = colorOf(it.kind), size = 9, textSize = 13 })
                    end
                end
            end)
        end
    end

    -- ---------- Items ----------
    -- What "Get some" can drop by your cat: every consumable and material in the game's tables.
    local ITEMS = {
        "Consumable.SmallHealingHerb", "Consumable.MediumHealingHerb", "Consumable.BigHealingHerb",
        "Consumable.FullHealingHerb", "Consumable.SuperHealingHerb", "Consumable.HealingHerbPouch",
        "Consumable.SmallCatnip", "Consumable.MediumCatnip", "Consumable.BigCatnip", "Consumable.CatnipPouch",
        "Consumable.ThistlePouch", "Consumable.FishScalePouch", "Consumable.CatThymePouch", "Consumable.FeatherPouch",
        "Consumable.HerbSpicesPouch", "Consumable.EyewortPouch", "Consumable.ChamomilePouch",
        "Consumable.AntidoteHerbPouch", "Consumable.ValerianRootPouch", "Consumable.PeppermintPouch",
        "Consumable.GingerRootPouch", "Consumable.ChestnutPouch", "Consumable.LavenderPouch", "Consumable.TurmericPouch",
        "Consumable.SagePouch",
        "Materials.BerryFern", "Materials.Birdnest", "Materials.Bone", "Materials.Borage", "Materials.Broom",
        "Materials.Burdock", "Materials.CattailReed", "Materials.Cobwebs", "Materials.Comfrey", "Materials.Cotton",
        "Materials.Dandelion", "Materials.DirtMound", "Materials.Fur", "Materials.Goldenrod", "Materials.Heather",
        "Materials.Ivy", "Materials.Juniper", "Materials.Leaves", "Materials.Moss", "Materials.Oakgall", "Materials.Pine",
        "Materials.Poppy", "Materials.Rock", "Materials.Rope", "Materials.SharpeningTreeBark", "Materials.Thyme",
        "Materials.Willow",
    }
    local itemName = P.itemName
    local drop = { item = ITEMS[1], count = 1, note = nil }
    local CATEGORY = { Consumable = "Herbs and pouches", Materials = "Materials", Cosmetic = "Accessories", Decoration = "Den decorations" }
    -- What you carry: Game.items.list reads and decodes the whole save file, so it's read every ten seconds
    -- (for the game's saves), and at once when you pick something up or there's another cat (another save).
    local inventory = { at = -1, items = {} }
    Game.on("itemPickedUp", function() inventory.at = -1 end)
    Game.on("player", function() inventory.at = -1 end)
    Menu.page("Items", function(ui)
        ui.heading("Items")
        if not Game.cat() then
            ui.text("Not in the world yet.")
            return
        end
        ui.note("As of the game's last save, with what you've picked up since.")
        if inventory.at < 0 or os.clock() - inventory.at > 10 then inventory.at, inventory.items = os.clock(), Game.items.list() end
        local items, groups = inventory.items, {}
        for tag, n in pairs(items) do
            local cat = tostring(tag):match("^Gameplay%.Inventory%.(%w+)%.") or "Other"
            groups[cat] = groups[cat] or {}
            groups[cat][#groups[cat] + 1] = { tag = tag, n = n }
        end
        local any = false
        for _, cat in ipairs({ "Consumable", "Materials", "Cosmetic", "Decoration", "Other" }) do
            local list = groups[cat]
            if list then
                any = true
                table.sort(list, function(a, b) return a.tag < b.tag end)
                ui.section(CATEGORY[cat] or cat, function()
                    for _, it in ipairs(list) do ui.field(itemName(it.tag), it.n) end
                end, { id = "items-" .. cat, open = true })
            end
        end
        if not any then ui.text("Nothing yet.") end
        ui.separator()
        ui.heading("Get some")
        local function label(t) return itemName(t) .. "  (" .. (CATEGORY[tostring(t):match("^(%w+)%.") or ""] or "Other") .. ")" end
        local names, byName = {}, {}
        for i, t in ipairs(ITEMS) do names[i] = label(t) byName[names[i]] = t end
        drop.item = byName[ui.choice("Item", label(drop.item), names)] or drop.item
        drop.count = ui.number("How many", drop.count, { min = 1, max = 99, step = 1, whole = true })
        if ui.button("Put it by my cat", { kind = "primary" }) then
            local a, err = Game.items.drop("Gameplay.Inventory." .. drop.item, math.floor(drop.count + 0.5))
            drop.note = a and ("A pickup with " .. math.floor(drop.count + 0.5) .. " " .. itemName(drop.item) .. " is by your cat.")
                        or ("Couldn't: " .. tostring(err))
        end
        if drop.note then ui.note(drop.note) end
        ui.note("It's a pickup on the ground: walk to it and pick it up as usual.")

        local tag = "Gameplay.Inventory." .. drop.item
        ui.section("What it is", function()
            local isItem = P.has("items", "isItem") and Game.items.isItem(tag)
            ui.columns({ { "Tag", tag }, { "Kind", P.show(Game.items.type(tag)) }, { "One of the game's items", P.show(isItem) },
                         { "You have", P.show(items[tag] or 0) } })
            local info = Game.items.info(tag)
            if type(info) == "table" and next(info) then ui.text(P.show(info)) end
            if P.cpp() then
                local full = P.cached("items.info." .. tag, 5, function() return P.callCpp("item_info", tag) end)
                if type(full) == "table" then
                    for _, k in ipairs((function() local o = {} for key in pairs(full) do o[#o + 1] = key end table.sort(o) return o end)()) do
                        ui.field(P.words(k), P.show(full[k]))
                    end
                end
            end
        end, { id = "items-info", open = false })

        ui.section("Your inventory, live", function()
            if not P.needCpp(ui) then return end
            ui.note("The inventory itself (the C++ part's inventory: what the game will save), and items put in or taken " ..
                    "out as a pickup does, with the HUD's message. Uses the item and count above.")
            local hit = ui.buttons({ "Put them in", "Take them out" }, { kinds = { "good", "danger" } })
            local n = math.floor(drop.count + 0.5)
            if hit == 1 then
                P.result("items", string.format("Put %d %s in.", n, itemName(drop.item)), P.callCpp("add_item", tag, n, true))
                P.forget("items.live")
            elseif hit == 2 then
                P.result("items", string.format("Took %d %s out.", n, itemName(drop.item)), P.callCpp("remove_item", tag, n))
                P.forget("items.live")
            end
            P.said(ui, "items")
            local live = P.cached("items.live", 1, function() return P.callCpp("inventory") end)
            if type(live) ~= "table" then
                ui.note("The inventory can't be read here (in a menu, or wcmods hasn't got it on this build).")
                return
            end
            local list = {}
            for t, c in pairs(live) do list[#list + 1] = { tag = t, n = c } end
            table.sort(list, function(a, b) return a.tag < b.tag end)
            P.pager(ui, "items-live", list, function(it)
                local h = ui.buttons({ string.format("%s: %s", itemName(it.tag), P.show(it.n)), "+1", "-1" }, { kinds = { nil, "good", "danger" } })
                if h == 2 then P.callCpp("add_item", it.tag, 1, false) P.forget("items.live")
                elseif h == 3 then P.callCpp("remove_item", it.tag, 1) P.forget("items.live") end
            end, { text = function(it) return itemName(it.tag) .. " " .. it.tag end, empty = "Nothing." })
        end, { id = "items-live", open = false })

        ui.section("Every item the game has", function()
            if not P.needCpp(ui) then return end
            local tags = P.cached("items.tags", 30, function() return P.callCpp("item_tags") end) or {}
            P.pager(ui, "items-all", tags, function(t)
                if ui.button(itemName(t) .. "  (" .. t:gsub("^Gameplay%.Inventory%.", "") .. ")") then
                    P.result("items", "Put 1 " .. itemName(t) .. " in.", P.callCpp("add_item", t, 1, true))
                    P.forget("items.live")
                end
            end, { text = function(t) return itemName(t) .. " " .. t end, size = 12 })
            ui.note("A press puts one in your inventory (the C++ part's add_item, as a pickup does).")
        end, { id = "items-all", open = false })
    end, { order = 23, group = "world" })
end
