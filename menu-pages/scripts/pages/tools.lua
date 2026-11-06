-- Home: SDK map. Tools: Engine, Tables, Words, Events, Save data and Game UI (WCModsGame's objects, managers, enums,
-- mapped values, console and commands, the DataTables and words, timers, keys, events and hooks, the save, and
-- WCModsCpp.ui, WCModsDraw and WCModsMenu; the C++ part adds rows, changes words and says what wcmods found).
return function(P)
    local Menu, show, words, THEME = P.Menu, P.show, P.words, P.THEME

    -- ---------- SDK map ----------
    -- Every part of the SDK a script or a C++ mod can use, whether this game has it, and the page it's on. `has`
    -- is the WCModsGame table that shows the Lua side is there; `cpp` the C++ part's calls, when there are some.
    local MAP = {
        { "Your cat", {
            { "Your cat's values", "Game.cat(): health, stamina, level, stats, condition, size", { "cat" }, nil, "Stats" },
            { "Looks and accessories", "cat:look, cat:role, Game.lookFields, Game.accessories, Game.lookFromText", { "lookFields" },
              "set_look, keep_look, wear, take_off", "Looks" },
            { "Speeds and movement", "Game.speeds, cat:movement, setJumpSpeed, setGravity, setTimeDilation, Game.useSense", { "speeds" }, nil, "Movement" },
            { "Animations", "Game.anims, cat:animate, cat:playMontage", { "anims" }, nil, "Animations" } } },
        { "World", {
            { "The clock and the pile", "Game.time (and its shared hold), Game.freshKill", { "time" }, nil, "World" },
            { "Travel", "Game.places, cat:teleport, Game.ground, Game.trace", { "places" }, "places, unlock_place, map_travel", "Travel" },
            { "What's around", "WCModsWorld, WCModsDraw's markers", nil, nil, "Nearby" },
            { "Items", "Game.items", { "items" }, "inventory, add_item, remove_item, item_tags, item_info", "Items" },
            { "Animals and their AI", "Game.animals, Game.ai, cat:senses", { "ai" }, "ai_tree, ai_task", "Animals" },
            { "Walking cats", "Game.walkers, Game.ai, Game.clanCats", { "walkers" }, nil, "Walking cats" },
            { "Cats of a mod's own", "Game.npcs (label, prompt, walk, map marker), Game.dialogue", { "npcs" }, nil, "Your own cats" },
            { "Dens", "Game.dens", { "dens" }, "decorations, place_decoration, build_decoration", "Dens" },
            { "Sky, sound and effects", "Game.sky, Game.sounds, Game.music, Game.effects", { "sky" }, "sky_values, set_sky_value, replace_sound", "Sky and sound" },
            { "Camera and photos", "Game.camera, Game.photo, WCModsView", { "camera" }, nil, "Camera" },
            { "The HUD and the map", "Game.hud, Game.mapMarker, WCModsCpp.ui.hud", { "hud" }, nil, "HUD and map" } } },
        { "Story", {
            { "Quests", "Game.quests (start, track, collect, finish, report)", { "quests" }, nil, "Quests" },
            { "Scenes", "Game.scenes", { "scenes" }, "play_scene", "Scenes" },
            { "Talk", "Game.dialogue", { "dialogue" }, "the game's talks: read_talk, story_talk, play, talk_next", "Talk" },
            { "Bonds", nil, nil, "bonds, set_bond, bond_roles, talk_rows, answer_bond", "Bonds" } } },
        { "Fight", {
            { "Fights", "Game.fight, Game.fighter, Game.combat (turns, dilemmas, onDamage, autoFight)", { "combat" },
              "fighter_moves, limit_moves, ai_chances, auto_fight", "Fight" } } },
        { "Cheats", {
            { "The engine's cheats", "the player controller's CheatManager, GameplayStatics", nil, nil, "Cheats" },
            { "Developer switches", "Game.dev", { "dev" }, nil, "Game switches" },
            { "Tuning", nil, nil, "tuning_keys, tuning, set_tuning", "Tuning" } } },
        { "Tools", {
            { "Objects and the engine", "Game.get/set/call, find, managers, libraries, enums, hidden, console, command, screens", nil, "status", "Engine" },
            { "DataTables", "Game.tables", { "tables" }, "add_row", "Tables" },
            { "Words", "Game.words, Game.wordKeys", { "words" }, "set_words, restore_words", "Words" },
            { "Timers, keys, events, hooks", "Game.every/after/onKey/onPress/on/emit/hook", nil, nil, "Events" },
            { "The save", "Game.save, Game.progression, Game.mood", { "save" }, nil, "Save data" },
            { "The game's own UI", "WCModsCpp.ui, WCModsDraw, WCModsMenu", nil, nil, "Game UI" },
            { "Any object's members", "Game.properties, Game.functions (wcmods' own Inspector page)", nil, nil, "Inspector" },
            { "Lua, live", "the game bridge (wcmods' own Lua (advanced) page)", nil, nil, "Lua console" } } },
    }
    local share = { name = "", value = "", read = "" }
    Menu.page("SDK map", function(ui)
        ui.heading("SDK map")
        ui.note("Every part of wcmods' SDK a mod can use, Lua (WCModsGame and the modules beside it) and C++ (WCMods.hpp), " ..
                "whether this game has it, and the page that has it here.")
        local cpp = P.cpp()
        local cppStatus = cpp and P.cached("sdk.status", 10, function() return P.callCpp("status") end) or nil
        local nat, natFound = 0, 0
        for _, n in ipairs(type(cppStatus) == "table" and cppStatus.natives or {}) do
            nat = nat + 1
            if n.found then natFound = natFound + 1 end
        end
        ui.columns({ { "wcmods", tostring(Game.wcmods or "0.5.0 or older") }, { "Level", show(Game.levelName()) },
                     { "C++ part", cpp and ("version " .. show(cpp.version)) or "not loaded" },
                     { "Native calls found", cpp and string.format("%d of %d", natFound, nat) or "-" },
                     { "WCModsCpp.ui", show(rawget(_G, "WCModsCpp") ~= nil and WCModsCpp.ui ~= nil) } })
        if not cpp then ui.note(P.CPP_HELP) end
        for _, g in ipairs(MAP) do
            ui.section(g[1], function()
                for _, e in ipairs(g[2]) do
                    local area, lua, has, cppCalls, page = e[1], e[2], e[3], e[4], e[5]
                    local parts = {}
                    if lua then
                        local here = not has or P.has(table.unpack(has))
                        parts[#parts + 1] = "Lua: " .. lua .. (here and "" or "  (needs a newer wcmods)")
                    end
                    if cppCalls then parts[#parts + 1] = "C++: " .. cppCalls .. (cpp and "" or "  (needs the C++ part)") end
                    ui.text(area, { color = THEME.heading })
                    ui.note(table.concat(parts, "\n"))
                    if ui.button("Open " .. page) then Menu.open(page) end
                end
            end, { id = "sdk-" .. g[1], open = false })
        end
        ui.section("C++ mods in the game, and values shared with them", function()
            local all = rawget(_G, "WCModsCpp")
            local mods = type(all) == "table" and all.mods or {}
            local ids = {}
            for id in pairs(mods) do ids[#ids + 1] = id end
            table.sort(ids)
            if #ids == 0 then ui.note("No C++ mod built with wcmods' SDK is in the game.") end
            for _, id in ipairs(ids) do
                local m = mods[id]
                local okP, pages = pcall(m.pages)
                local okK, keys = pcall(m.keys)
                ui.field(id, string.format("%d page%s; keys: %s", okP and #pages or 0, okP and #pages == 1 and "" or "s",
                         okK and keys ~= "" and keys:gsub("\t", " "):gsub("\n", ", ") or "none"))
            end
            ui.note("WCModsCpp.share(name, value) reaches every C++ mod's shared(name); a C++ mod's share is read with " ..
                    "WCModsCpp.mods[id].get(name).")
            share.name = ui.input("Name", share.name)
            share.value = ui.input("Value", share.value)
            local hit = ui.buttons({ "Share it with every C++ mod", "Read it from each" })
            if hit == 1 and share.name ~= "" and type(all) == "table" and all.share then
                all.share(share.name, tonumber(share.value) or (share.value == "true" and true) or (share.value == "false" and false) or share.value)
                share.read = "Shared."
            elseif hit == 2 and share.name ~= "" then
                local out = {}
                for _, id in ipairs(ids) do
                    local ok, v = pcall(mods[id].get, share.name)
                    out[#out + 1] = id .. ": " .. show(ok and v or nil)
                end
                share.read = table.concat(out, "; ")
            end
            if share.read ~= "" then ui.note(share.read) end
        end, { id = "sdk-cpp", open = false })
        ui.section("The mod menu (WCModsMenu)", function()
            local line, by = nil, nil
            if Menu.statusShown then line, by = Menu.statusShown() end
            ui.columns({ { "Status line shown", show(line) }, { "Whose", show(by) }, { "Open", show(Menu.isOpen()) } })
            ui.note("Menu.page, Menu.status, Menu.statusShown, Menu.open, Menu.key, Menu.saveJson and the ui rows every page " ..
                    "here is made of (SDK.md, WCModsMenu).")
        end, { id = "sdk-menu", open = false })
    end, { order = 2, group = "home" })

    -- ---------- Engine ----------
    local engine = { enum = nil, path = "/Script/SwtQuest.EGiverRole", console = "", screenCommand = "Button_Back", hiddenClass = nil }
    Menu.page("Engine", function(ui)
        ui.heading("Objects and the engine")
        P.said(ui, "engine")
        ui.section("The game's managers", function()
            local names = {}
            for n in pairs(Game.managers or {}) do names[#names + 1] = n end
            table.sort(names)
            for _, n in ipairs(names) do
                local m = Game.manager(n)
                ui.field(n, Game.valid(m) and Game.className(m) or "(not there now)")
            end
            ui.note("Game.manager(name): the game instance's managers, for Game.get and Game.call. The Inspector page opens any of them.")
        end, { id = "engine-managers", open = false })
        ui.section("Function libraries", function()
            local names = {}
            for n, path in pairs(Game.libraries or {}) do names[#names + 1] = { n, path } end
            table.sort(names, function(a, b) return a[1] < b[1] end)
            for _, e in ipairs(names) do ui.field(e[1], tostring(e[2])) end
            ui.note("Game.library(name): their static functions, e.g. Game.library(\"GameplayStatics\"):GetGlobalTimeDilation(world).")
        end, { id = "engine-libraries", open = false })
        ui.section("Enums", function()
            local names = {}
            for n in pairs(Game.enums or {}) do names[#names + 1] = n end
            table.sort(names)
            if #names > 0 then
                engine.enum = ui.choice("Game.enums", engine.enum or names[1], names)
                local e, list = Game.enums[engine.enum], {}
                for i = 0, 200 do
                    local name = e and e[i]
                    if name then list[#list + 1] = string.format("%d  %s", i, name) end
                end
                ui.text(table.concat(list, ",  "))
            end
            engine.path = ui.input("Any of the game's enums, by its path", engine.path)
            local map, order = Game.enumNames(engine.path)
            if map then
                local list = {}
                for _, n in ipairs(order or {}) do list[#list + 1] = string.format("%s %s", n, show(map[n])) end
                ui.text(table.concat(list, ",  "))
            else
                ui.note("No such enum (the path is the module the class dump lists it under, and its name).")
            end
        end, { id = "engine-enums", open = false })
        ui.section("Mapped values", function()
            ui.note("The game's values that aren't reflected, which wcmods maps by their offsets (Game.hidden): health, stamina, " ..
                    "level, the stats, the clock... They read and write like any property.")
            local classes = {}
            for cls in pairs(Game.hidden or {}) do classes[#classes + 1] = cls end
            table.sort(classes)
            if #classes > 0 then
                engine.hiddenClass = ui.choice("Class", engine.hiddenClass or classes[1], classes)
                for _, d in ipairs(Game.hidden[engine.hiddenClass] or {}) do
                    ui.field(tostring(d.name or d[1]), string.format("offset %s, %s", show(d.offset or d[2]), show(d.type or d[3])))
                end
            end
            local st = P.cpp() and P.cached("sdk.status", 10, function() return P.callCpp("status") end) or nil
            if type(st) == "table" then
                ui.text("What wcmods found on game build " .. show(st.game_build) .. " (the C++ part's status)", { color = THEME.heading })
                for _, n in ipairs(st.natives or {}) do ui.field(tostring(n.name), n.found and "found" or "NOT FOUND") end
                for _, h in ipairs(st.hidden or {}) do
                    if not h.found then ui.field(tostring(h.class) .. "." .. tostring(h.member), "NOT FOUND") end
                end
            end
        end, { id = "engine-hidden", open = false })
        ui.section("Console and commands", function()
            if not P.needs(ui, "command") then return end
            engine.console = ui.input("Console command", engine.console, { hint = "stat fps, r.Fog 0" })
            if ui.button("Run it") and engine.console ~= "" then P.result("engine", "Ran it.", Game.console(engine.console)) end
            ui.note("Game.console: as the console runs it. Cheat commands need the Cheats page's cheats on.")
            local _, cmds = Game.enumNames("/Script/SwtEngine.ECommands")
            P.pager(ui, "engine-commands", cmds or {}, function(c)
                if ui.button("Press " .. c) then P.result("engine", "Pressed " .. c .. ".", Game.command(c)) end
            end, { text = function(c) return c end, size = 10, label = "Find a command", hint = "Player_" })
            ui.note("Game.command: one of the game's controls (ECommands), pressed through your cat's input, as its key does.")
        end, { id = "engine-console", open = false })
        ui.section("The game's screens up now", function()
            if not P.needs(ui, "screen") then return end
            local screens = Game.screens() or {}
            if #screens == 0 then ui.note("None (you're just playing). Open the inventory or the map with a command above to see one.") end
            engine.screenCommand = ui.input("Command to send", engine.screenCommand, { hint = "Button_Back, Button_Confirm, Button_Left" })
            for _, s in ipairs(screens) do
                local name = Game.valid(s) and Game.className(s) or show(s)
                local hit = ui.buttons({ name, "Send it", "Close it" }, { kinds = { nil, nil, "danger" } })
                if hit == 2 then P.result("engine", "Sent.", Game.send(s, engine.screenCommand))
                elseif hit == 3 then P.result("engine", "Closed.", Game.close(s)) end
            end
        end, { id = "engine-screens", open = false })
    end, { order = 70, group = "tools" })

    -- ---------- Tables ----------
    local tbl = { name = nil, row = nil, newRow = "", confirm = false, edit = {} }
    Menu.page("Tables", function(ui)
        ui.heading("The game's tables")
        if not P.needs(ui, "tables") then return end
        ui.note("The DataTables in memory (Game.tables): items, characters, fights, animations, the sky, dens... A row is " ..
                "the game's own: a change is what it reads from then on, until it loads the table again (a restart).")
        P.said(ui, "tables")
        local list = P.cached("tables.list", 10, Game.tables.list) or {}
        if not tbl.name then
            P.pager(ui, "tables-list", list, function(t)
                if ui.button(string.format("%s  (%d rows of %s)", t.name, t.rows or 0, show(t.rowStruct))) then tbl.name, tbl.row = t.name, nil end
            end, { text = function(t) return t.name .. " " .. tostring(t.rowStruct) end })
            return
        end
        local t = Game.tables.get(tbl.name)
        if not t then tbl.name = nil return end
        if ui.button("Back to every table") then tbl.name, tbl.row = nil, nil return end
        ui.field("Table", tbl.name)
        local rows = Game.tables.rowNames(t) or {}
        if not tbl.row then
            P.pager(ui, "tables-rows-" .. tbl.name, rows, function(r)
                if ui.button(tostring(r)) then tbl.row, tbl.confirm, tbl.edit = r, false, {} end
            end, { text = function(r) return r end, label = "Find a row" })
            return
        end
        if ui.button("Back to its rows") then tbl.row = nil return end
        local row = Game.tables.row(t, tbl.row)
        if not row then tbl.row = nil return end
        ui.field("Row", tbl.row)
        local fields = P.cached("tables.fields." .. tbl.name, 60, function() return P.structFields(Game.get(t, "RowStruct")) end)
        if not fields then ui.note("Its fields can't be listed here; Game.get(row, \"Field\") still reads one by name.") end
        for _, f in ipairs(fields or {}) do
            local v = Game.get(row, f.name)
            if f.type == "BoolProperty" then
                local now = v == true
                if ui.toggle(f.name, now) ~= now then P.result("tables", f.name .. " set.", Game.tables.set(t, tbl.row, f.name, not now)) end
            elseif type(v) == "number" then
                local nv = ui.number(f.name, v, { step = P.INTEGER[f.type] and 1 or 0.1, whole = P.INTEGER[f.type] == true })
                if P.changed(nv, v) then P.result("tables", f.name .. " set.", Game.tables.set(t, tbl.row, f.name, P.asType(nv, f.type))) end
            elseif f.type == "StrProperty" or f.type == "NameProperty" then
                local s = show(v)
                local ns = ui.input(f.name, s)
                if ns ~= s then tbl.edit[f.name] = ns end
            else
                ui.field(f.name .. "  (" .. words(tostring(f.type):gsub("Property$", "")) .. ")", show(v))
            end
        end
        if next(tbl.edit) and ui.button("Write the text changes") then
            for k, v in pairs(tbl.edit) do P.result("tables", "Written.", Game.tables.set(t, tbl.row, k, v)) end
            tbl.edit = {}
        end
        ui.section("Add a row, or take this one out", function()
            if P.cpp() then
                tbl.newRow = ui.input("A new row's name", tbl.newRow)
                if ui.button("Add it, a copy of this row") and tbl.newRow ~= "" then
                    P.result("tables", "Added " .. tbl.newRow .. ".", P.callCpp("add_row", tbl.name, tbl.newRow, tbl.row))
                end
            else
                ui.note("Adding a row is the C++ part's (UE4SS's AddRow can't on this engine). " .. P.CPP_HELP)
            end
            tbl.confirm = ui.toggle("I know it's gone until the game restarts", tbl.confirm)
            if tbl.confirm and ui.button("Take this row out", { kind = "danger" }) then
                if P.result("tables", tbl.row .. " is out.", Game.tables.removeRow(t, tbl.row)) then tbl.row = nil end
            end
        end, { id = "tables-rows", open = false })
    end, { order = 71, group = "tools" })

    -- ---------- Words ----------
    local wordsPage = { prefix = "STR_CAT_NAME", key = nil, text = "" }
    Menu.page("Words", function(ui)
        ui.heading("The game's words")
        if not P.needs(ui, "words") then return end
        ui.note("Every line the game shows is a key of its string table (SwtStrings): Game.words reads one. Changing them " ..
                "is the C++ part's set_words.")
        P.said(ui, "words")
        local prefix = ui.input("Keys starting with", wordsPage.prefix, { hint = "STR_ITEM, STR_CAT_NAME..." })
        if prefix ~= wordsPage.prefix then wordsPage.prefix = prefix end
        local keys = P.cached("words.keys." .. wordsPage.prefix, 30, function() return Game.wordKeys(wordsPage.prefix) end) or {}
        P.pager(ui, "words-keys", keys, function(k)
            local w = P.cached("words." .. k, 5, function() return Game.words(k) end)
            if ui.button(k .. ":  " .. show(w)) then wordsPage.key, wordsPage.text = k, show(w) end
        end, { text = function(k) return k end, size = 12, label = "Find a key" })
        if wordsPage.key then
            ui.text(wordsPage.key, { color = THEME.heading })
            if P.needCpp(ui) then
                wordsPage.text = ui.input("Its words", wordsPage.text)
                local hit = ui.buttons({ "Change them", "The game's words back" })
                if hit then P.forget("words." .. wordsPage.key) end
                if hit == 1 then
                    P.result("words", "Changed: what the game makes from now on shows them.", P.callCpp("set_words", wordsPage.key, wordsPage.text))
                elseif hit == 2 then
                    P.result("words", "Back as the game had them.", P.callCpp("restore_words", wordsPage.key))
                    wordsPage.text = show(Game.words(wordsPage.key))
                end
            end
        end
    end, { order = 72, group = "tools" })

    -- ---------- Events ----------
    local events = { log = {}, paused = false, name = "MenuPages.hello", text = "", keys = "T, Gamepad_DPad_Up", key = "F9",
                     watch = "", hook = "/Script/Engine.PlayerController:ClientRestart", hooks = {}, listening = {}, every = nil, ticks = 0 }
    local function logEvent(name, ...)
        if events.paused then return end
        local parts = {}
        for i = 1, select("#", ...) do parts[#parts + 1] = show((select(i, ...))) end
        table.insert(events.log, 1, { at = os.date("%H:%M:%S"), name = name, text = table.concat(parts, ", ") })
        while #events.log > 200 do table.remove(events.log) end
    end
    for _, name in ipairs({ "level", "player", "phase", "combatStart", "combatEnd", "itemPickedUp", "questStatus", "genericEvent",
                            "damage", "turnEnded", "status" }) do
        Game.on(name, function(...) logEvent(name, ...) end)
    end
    Menu.page("Events", function(ui)
        ui.heading("Timers, keys, events and hooks")
        ui.note("Every WCModsGame event as it happens (Game.on): level, player, phase, combatStart and combatEnd, itemPickedUp, " ..
                "questStatus, genericEvent, damage, turnEnded and status.")
        events.paused = ui.switch("Pause the log", events.paused)
        if ui.button("Clear it") then events.log = {} end
        P.pager(ui, "events-log", events.log, function(e)
            ui.field(e.at .. "  " .. e.name, e.text)
        end, { text = function(e) return e.name .. " " .. e.text end, size = 12, label = "Find in the log", empty = "Nothing yet." })
        ui.section("Send one of your own", function()
            events.name = ui.input("Event", events.name)
            events.text = ui.input("With", events.text)
            if ui.button("Send it (Game.emit)") and events.name ~= "" then
                if not events.listening[events.name] then
                    local n = events.name
                    Game.on(n, function(...) logEvent(n, ...) end)
                    events.listening[n] = true
                end
                Game.emit(events.name, events.text)
            end
            ui.note("Game.emit reaches the listeners in the same script: this page listens to what it sends.")
        end, { id = "events-emit", open = false })
        ui.section("Keys and buttons", function()
            events.keys = ui.input("The game's own keys and buttons", events.keys, { hint = "T, Gamepad_FaceButton_Top" })
            if ui.button("Log them as they're pressed (Game.onPress)") then
                local list = {}
                for k in events.keys:gmatch("[^,%s]+") do list[#list + 1] = k end
                P.result("events", "Listening.", Game.onPress(list, function(key) logEvent("pressed", key) end))
            end
            events.key = ui.input("A UE4SS key", events.key, { hint = "F9, CONTROL..." })
            if ui.button("Log it as it's pressed (Game.onKey)") then
                local k = events.key
                P.result("events", "Listening to " .. k .. ".", Game.onKey(k, function() logEvent("key", k) end, nil, "Logged on the Events page"))
            end
            events.watch = ui.input("Is this held now? (Game.keyDown)", events.watch, { hint = "LeftShift" })
            if events.watch ~= "" then ui.field(events.watch, show(Game.keyDown(events.watch))) end
            ui.note("onPress hears the game's own input (and the controller) while it has the focus; onKey hears UE4SS's " ..
                    "names anywhere. The menu has the keyboard while it's open: close it to press them.")
        end, { id = "events-keys", open = false })
        ui.section("Timers", function()
            local on = events.every ~= nil
            if ui.switch("Log a tick every second (Game.every)", on) ~= on then
                if on then
                    Game.cancel(events.every)
                    events.every = nil
                else
                    events.every = Game.every(1, function()
                        events.ticks = events.ticks + 1
                        logEvent("tick", events.ticks)
                    end)
                end
            end
            if ui.button("Log a line in 3 seconds (Game.after)") then Game.after(3, function() logEvent("after", "3 s later") end) end
        end, { id = "events-timers", open = false })
        ui.section("Hooks", function()
            ui.note("Game.hook runs a function each time the game calls one of its own (\"/Script/<Module>.<Class>:<Function>\"; " ..
                    "the Inspector lists a class's functions). This counts the calls. A native function a Blueprint calls hands " ..
                    "a hook its caller's variables, so only the count and who's called are shown.")
            events.hook = ui.input("Function", events.hook)
            if ui.button("Hook it") and events.hook ~= "" then
                local e = { path = events.hook, calls = 0, last = nil }
                local ok, h = pcall(Game.hook, events.hook, function(self)
                    e.calls = e.calls + 1
                    e.last = Game.valid(self) and Game.className(self) or nil
                end)
                if ok and h then
                    e.handle = h
                    events.hooks[#events.hooks + 1] = e
                    P.say("events", "Hooked.")
                else
                    P.say("events", "Couldn't hook it: " .. tostring(h))
                end
            end
            for i, e in ipairs(events.hooks) do
                ui.field(e.path, string.format("%d calls%s", e.calls, e.last and (", last on a " .. e.last) or ""))
                if ui.button("Unhook " .. e.path) then
                    -- Taken off a moment later, never from inside a call to it (that crashed the game once).
                    local h = e.handle
                    Game.after(0, function() Game.unhook(h) end)
                    table.remove(events.hooks, i)
                    break
                end
            end
            P.said(ui, "events")
        end, { id = "events-hooks", open = false })
    end, { order = 73, group = "tools" })

    -- ---------- Save data ----------
    local save = { root = "Your cat's slot", path = "", progression = "FreshKill/Cycle", primary = "", sub = "", setValue = 0,
                   moodPrimary = "", moodSub = "", stateKey = "Currency" }
    local function walk(t, path)
        for part in path:gmatch("[^%.]+") do
            if type(t) ~= "table" then return nil end
            t = t[tonumber(part) or part]
        end
        return t
    end
    Menu.page("Save data", function(ui)
        ui.heading("The save")
        if not P.needs(ui, "save", "file") then return end
        P.said(ui, "save")
        ui.columns({ { "Hash", show(Game.save.hash and Game.save.hash()) }, { "Save slot", show(Game.save.slot()) },
                     { "Scripts' folder", show(Game.save.folder and Game.save.folder()) } })
        if ui.button("Save now (the game's own save)", { kind = "primary" }) then P.result("save", "Saved.", Game.save.write()) end
        ui.section("Browse the save", function()
            save.root = ui.radio("From", save.root, { "Your cat's slot", "The whole save" })
            local root = save.root == "The whole save" and Game.save.file() or Game.save.slotData()
            if type(root) ~= "table" then ui.note("No save read yet.") return end
            ui.field("Path", save.path ~= "" and save.path or "(the top)")
            if save.path ~= "" and ui.button("Up") then save.path = save.path:match("^(.*)%.[^%.]+$") or "" end
            local here = walk(root, save.path)
            local keys = {}
            if type(here) == "table" then
                for k in pairs(here) do keys[#keys + 1] = k end
                table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
            end
            P.pager(ui, "save-browse", keys, function(k)
                local v = here[k]
                if type(v) == "table" then
                    local n = 0
                    for _ in pairs(v) do n = n + 1 end
                    if ui.button(string.format("%s  (%d)", tostring(k), n)) then save.path = (save.path ~= "" and (save.path .. ".") or "") .. tostring(k) end
                else
                    ui.field(tostring(k), show(v))
                end
            end, { text = function(k) return tostring(k) end, size = 15 })
            ui.note("Game.save.file and slotData: the save as of the game's last save (WrcGame.json), read only.")
        end, { id = "save-browse", open = true })
        ui.section("Progression, mood and the account's numbers", function()
            save.progression = ui.input("Your cat's progression, by path", save.progression)
            ui.field("Game.progression", show(Game.progression and Game.progression(save.progression)))
            ui.separator()
            save.moodPrimary = ui.input("Mood: primary key", save.moodPrimary)
            save.moodSub = ui.input("Mood: sub key", save.moodSub)
            if save.moodPrimary ~= "" and save.moodSub ~= "" and Game.mood then
                local m = Game.mood(save.moodPrimary, save.moodSub)
                ui.field("Game.mood", show(m))
                local nv = ui.number("Set the mood", m or 0, { step = 1, whole = true })
                if m ~= nil and nv ~= m then P.result("save", "Mood set.", Game.setMood(save.moodPrimary, save.moodSub, nv)) end
            end
            ui.separator()
            ui.note("The account-wide stores (not your cat's slot): reading a progression key that isn't there writes it " ..
                    "into the save as 0, so these read only on a press.")
            save.primary = ui.input("Primary key", save.primary)
            save.sub = ui.input("Sub key", save.sub)
            save.setValue = ui.number("Value to set", save.setValue, { step = 1, whole = true })
            local hit = ui.buttons({ "Read progression", "Set progression", "Read setting", "Set setting" }, { kinds = { nil, "danger", nil, "danger" } })
            if hit and save.primary ~= "" and save.sub ~= "" then
                if hit == 1 then P.say("save", "Progression: " .. show(Game.save.progression(save.primary, save.sub)))
                elseif hit == 2 then P.result("save", "Set.", Game.save.setProgression(save.primary, save.sub, save.setValue))
                elseif hit == 3 then P.say("save", "Setting: " .. show(Game.save.setting(save.primary, save.sub)))
                elseif hit == 4 then P.result("save", "Set.", Game.save.setSetting(save.primary, save.sub, save.setValue)) end
            end
            save.stateKey = ui.radio("Account state", save.stateKey, { "Currency", "Decorations" })
            if Game.save.stateText then ui.text(show(Game.save.stateText(save.stateKey))) end
        end, { id = "save-numbers", open = false })
    end, { order = 74, group = "tools" })

    -- ---------- Game UI ----------
    -- WCModsCpp.ui: the game's own screens and HUD, from any C++ mod built with the SDK (this mod's C++ part too).
    local gui = { tab = nil, tabSeen = 0, tabHeal = nil, overlay = false, label = nil, draw = false, drawn = false, painter = nil }
    local okDraw, Draw = pcall(require, "WCModsDraw")
    local function cui() return rawget(_G, "WCModsCpp") and WCModsCpp.ui or nil end
    Game.onFrame(function()
        local u = cui()
        if not u then return end
        if gui.tab then
            local ok, page, generation = pcall(u.tab_page, gui.tab)
            if ok and page and generation ~= gui.tabSeen then
                gui.tabSeen = generation
                local s = P.now()
                gui.tabHeal = u.button("Heal your cat")
                u.add(page, { u.heading("Menu pages"), u.text(P.statusLine() ~= "" and P.statusLine():gsub("   |   ", "\n") or "Not in the world."),
                              gui.tabHeal, u.note("A tab of Menu pages' own in the game's pause screen (WCModsCpp.ui.tab).") })
                if not s.cat then gui.tabHeal = nil end
            end
            if gui.tabHeal and u.clicked(gui.tabHeal) and Game.cat() then Game.cat():heal() end
        end
        if gui.overlay then
            if not gui.label or not u.valid(gui.label) then
                local canvas = u.overlay("menu-pages")
                gui.label = u.text("", { size = 40 })
                u.add(canvas, gui.label)
                u.at(gui.label, 60, 60)
            end
            local h = P.here()
            u.text(gui.label, h and string.format("%.0f, %.0f, %.0f", h.X, h.Y, h.Z) or "")
        end
    end)
    Menu.page("Game UI", function(ui)
        ui.heading("The game's own UI")
        local u = cui()
        if not u then
            ui.note("WCModsCpp.ui comes with any C++ mod built with wcmods' SDK, and isn't in the game. " .. P.CPP_HELP)
        else
            local vw, vh, vs = u.viewport()
            ui.columns({ { "Viewport", string.format("%s x %s", show(vw), show(vh)) }, { "Scale", show(vs) }, { "Tabs", show(#(u.tabs() or {})) } })
            local on = gui.tab ~= nil
            if ui.switch("A Menu pages tab in the pause screen", on) ~= on then
                if on then
                    pcall(u.remove_tab, gui.tab)
                    gui.tab, gui.tabHeal = nil, nil
                else
                    gui.tab, gui.tabSeen = u.tab("WBP_GuiScreenPause_C", "Menu pages", "menu-pages"), 0
                end
            end
            local over = ui.switch("Your cat's place over the game (an overlay)", gui.overlay)
            if over ~= gui.overlay then
                gui.overlay = over
                if not over then pcall(u.remove_overlay, "menu-pages") gui.label = nil end
            end
            ui.text(show(u.theme()))
            ui.note("WCModsCpp.ui.tab puts a tab in one of the game's screens (pause, inventory, settings), overlay a canvas " ..
                    "of the script's own; theme is how its controls look.")
        end
        if okDraw then
            ui.separator()
            local d = ui.switch("A panel drawn with WCModsDraw", gui.draw)
            if d ~= gui.draw then
                gui.draw = d
                if d and not gui.painter then
                    gui.painter = Draw.onFrame(function(pt)
                        if not gui.draw then return end
                        local y = pt.panel(40, 200, 300, 110, "WCModsDraw")
                        local h = pt.player
                        pt.text(52, y, h and string.format("%.0f, %.0f, %.0f", h.X, h.Y, h.Z) or "no cat", { size = 16 })
                        if pt.button(52, y + 30, 140, 28, "Heal") and Game.cat() then Game.cat():heal() end
                    end)
                end
            end
            local visible = Draw.isVisible()
            if ui.switch("Show what this mod draws (markers and panels)", visible) ~= visible then Draw.setVisible(not visible) end
            ui.note("WCModsDraw paints over the game each frame (the Nearby page's markers are drawn with it); its buttons " ..
                    "take clicks while the cursor shows.")
        end
    end, { order = 75, group = "tools" })
end
