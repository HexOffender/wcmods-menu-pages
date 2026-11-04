-- World: the time of day and the fresh-kill pile, Travel, Nearby and Items.
return function(P)
    local Menu, now, refresh, changed, valid = P.Menu, P.now, P.refresh, P.changed, P.valid

    -- Held values: the World page can hold the time of day and keep the fresh-kill pile up, even with the
    -- menu closed (P.hold, which the status line shows). Going back to the main menu lets go of them, so a
    -- save loaded next doesn't start held.
    local hold = P.hold
    Game.every(1, function()
        if hold.time then Game.time.setSeconds(hold.timeAt) end
        if hold.pile then
            local v = Game.freshKill.value()
            if v and v < hold.pileAt then Game.freshKill.set(hold.pileAt) end
        end
    end)
    Game.on("level", function(level)
        if tostring(level or ""):find("MainMenu", 1, true) then hold.time, hold.pile = false, false end
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
            if math.abs(hours - s.secs / 3600) > 0.2 then
                Game.time.setSeconds(hours * 3600)
                hold.timeAt = hours * 3600
                refresh()
            end
            local hit = ui.buttons({ "Dawn 6:00", "Noon", "Dusk 19:00", "Night 23:00" })
            local at = ({ 6, 12, 19, 23 })[hit or 0]
            if at then P.setTime(at, 0) end
            local holding = ui.switch("Hold this time", hold.time)
            if holding and not hold.time then hold.timeAt = s.secs end
            hold.time = holding
            ui.note("A game day passes in about 20 minutes (DayNight.ClockSpeed 72).")
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
            if t and every then ui.field("Goes down by 1", string.format("in %.0f s (every %.0f s)", math.max(0, every - t), every)) end
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
    -- places.list: the spots as read (again with "Read it again"). Anything but no file yet or one list of
    -- spots isn't written over: places.bad says why, and saving waits until it's fixed or moved.
    local places = { list = nil, name = "", bad = nil }
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
    local function loadPlaces()
        if places.list then return places.list end
        places.list, places.bad = {}, nil
        local f, err, code = io.open(PLACES, "rb")
        if not f then
            -- 2: there's no file yet. Anything else, such as another program holding it, isn't "no spots".
            if code ~= 2 then places.bad = tostring(err) return places.list end
            local old = io.open(OLD, "rb")
            if old then
                old:close()
                places.bad = "it's missing, and places.json.old is there from a save that stopped part way: rename that " ..
                             "to places.json"
            end
            return places.list
        end
        local text, readErr = f:read("a")
        f:close()
        if not text then places.bad = tostring(readErr) return places.list end
        text = text:gsub("^\239\187\191", "")   -- a UTF-8 byte order mark (Notepad's)
        local start = text:find("%S")
        if not start then return places.list end
        local data, decodeErr = Game.json.decode(text)
        local stop = text:sub(start, start) == "[" and listEnd(text, start)
        if data == nil then
            places.bad = tostring(decodeErr or "not JSON")
        elseif not stop or text:find("%S", stop + 1) then
            places.bad = "not one list of spots"
        else
            places.list = data
        end
        return places.list
    end
    -- Write a new list of spots. It goes to places.json.new first and is read back before it takes the old
    -- file's place, so a write that fails part way (a full disk) leaves the spots as they were; the new list
    -- becomes the list only once it's in place.
    local function savePlaces(list)
        if places.bad then return false, "places.json couldn't be read (" .. places.bad .. "), so it's left as it is" end
        local ok, err = Menu.saveJson(NEW, Menu.list(list))
        if ok then
            local f = io.open(NEW, "rb")
            local back = f and Game.json.decode(f:read("a") or "")
            if f then f:close() end
            if type(back) ~= "table" or #back ~= #list then ok, err = false, "it didn't write whole" end
        end
        if ok then
            os.remove(OLD)
            local had = os.rename(PLACES, OLD)   -- (nil when there's no places.json yet)
            ok, err = os.rename(NEW, PLACES)
            if ok then
                os.remove(OLD)
            elseif had then
                os.rename(OLD, PLACES)
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
                ui.text("places.json couldn't be read (" .. places.bad .. "). It's left as it is: fix or move it, then " ..
                        "Read it again.", { color = P.THEME.danger })
            end
            for i, p in ipairs(list) do
                -- (a spot without a place, from a hand edit, is kept in the file but has no button)
                if type(p) == "table" and p.level == level and tonumber(p.X) and tonumber(p.Y) and tonumber(p.Z) then
                    shown = shown + 1
                    local h = ui.buttons({ "Go: " .. tostring(p.name), "Forget" }, { kinds = { "primary", "danger" } })
                    if h == 1 then jump({ X = tonumber(p.X), Y = tonumber(p.Y), Z = tonumber(p.Z) }, tostring(p.name), true)
                    elseif h == 2 then
                        local rest = copy(list)
                        table.remove(rest, i)
                        local ok, err = savePlaces(rest)
                        travel.note = ok and ("Forgot " .. tostring(p.name)) or ("Couldn't forget it: " .. tostring(err))
                        break
                    end
                end
            end
            if shown == 0 and not places.bad then ui.note("None yet. Name a spot above and press Save this spot.") end
            ui.note("Kept in " .. PLACES .. ".")
            if ui.button("Read it again") then places.list = nil end
        end, { id = "travel-saved", open = true })

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
    -- (for the game's saves), and at once when you pick something up.
    local inventory = { at = -1, items = {} }
    Game.on("itemPickedUp", function() inventory.at = -1 end)
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
    end, { order = 23, group = "world" })
end
