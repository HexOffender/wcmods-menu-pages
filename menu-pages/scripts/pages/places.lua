-- World: Dens, Sky and sound, Camera, HUD and map (Game.dens, Game.sky, Game.sounds, Game.music, Game.effects,
-- Game.camera, Game.photo, WCModsView, Game.hud, Game.mapMarker and WCModsCpp.ui's HUD; the C++ part builds
-- decorations and changes the sky's own values and the game's sounds).
return function(P)
    local Menu, show, words = P.Menu, P.show, P.words

    -- ---------- Dens ----------
    -- The den picked is kept by its door's address and its rank: a clan's rank dens share one door.
    local dens = { clan = "All", decoration = nil, seconds = 30, pick = nil }
    local function denKey(d) return d and P.addr(d.door) and (tostring(P.addr(d.door)) .. "/" .. tostring(d.rank)) or nil end
    Menu.page("Dens", function(ui)
        ui.heading("Dens")
        if not P.needs(ui, "dens") then return end
        if not Game.cat() then ui.text("Not in the world yet.") return end
        dens.clan = ui.radio("Clan", dens.clan, { "All", "ThunderClan", "ShadowClan", "RiverClan", "WindClan" })
        local list = P.cached("dens." .. dens.clan, 2, function() return Game.dens.list(dens.clan ~= "All" and dens.clan or nil) end) or {}
        local chosen = nil
        for _, d in ipairs(dens.pick and list or {}) do
            if denKey(d) == dens.pick then chosen = d break end
        end
        P.said(ui, "dens")
        P.pager(ui, "dens-list", list, function(d)
            local label = string.format("%s %s den", show(d.clan), d.rank ~= "" and words(d.rank) or "shared")
            local hit = ui.buttons({ (d == chosen and "> " or "") .. label, "Go inside" }, { kinds = { d == chosen and "primary" or nil } })
            if hit == 1 then dens.pick, chosen = denKey(d), d
            elseif hit == 2 then P.result("dens", "Inside the " .. label .. ".", Game.dens.enter(d)) end
        end, { size = 10 })
        local decos = P.cached("dens.decorations", 30, Game.dens.decorations) or {}
        local names, byName = {}, {}
        for _, d in ipairs(decos) do
            local n = string.format("%s  (%s)", tostring(d.name or d.tag), tostring(d.tag):match("(%d+)$") or "?")
            names[#names + 1], byName[n] = n, d
        end
        if not chosen then
            ui.note("Pick a den to see its hotspots, the places a decoration can be built.")
        else
            ui.section("Its hotspots", function()
                local canCpp = P.cpp() ~= nil
                if canCpp and #names > 0 then
                    dens.decoration = ui.choice("Decoration to build", dens.decoration or names[1], names)
                    dens.seconds = ui.number("Build time for a timed build (s)", dens.seconds, { min = 1, max = 3600, step = 5, whole = true })
                else
                    ui.note("Building a decoration is the C++ part's (the game's own cost row goes through a native lookup). " ..
                            (canCpp and "" or P.CPP_HELP))
                end
                -- (Read every 2 s: Game.dens.hotspots looks through every door and hotspot and the decorations' table.)
                local spotsKey = "dens.hotspots." .. tostring(dens.pick)
                for i, h in ipairs(P.cached(spotsKey, 2, function() return Game.dens.hotspots(chosen) end) or {}) do
                    ui.field(string.format("Hotspot %d (%s, %s)", i, show(h.size), words(show(h.rank))),
                             string.format("%s now; saved: %s %s", show(h.decoration), show(h.savedStatus), show(h.savedDecoration)))
                    local labels = { "Take it off" }
                    if canCpp then labels[2], labels[3] = "Build it now", "Timed build" end
                    local hit = ui.buttons(labels, { kinds = { "danger", "good" } })
                    local deco = byName[dens.decoration or ""]
                    if hit == 1 then P.result("dens", "Taken off.", Game.dens.removeDecoration(h))
                    elseif hit == 2 and deco then
                        P.result("dens", "Built " .. tostring(deco.name) .. ", nothing paid.", P.callCpp("place_decoration", P.addr(h.actor), deco.tag))
                    elseif hit == 3 and deco then
                        P.result("dens", string.format("Building %s: it shows in %d s.", tostring(deco.name), dens.seconds),
                                 P.callCpp("build_decoration", P.addr(h.actor), deco.tag, math.floor(dens.seconds)))
                    end
                    if hit then P.forget(spotsKey) end
                end
            end, { id = "dens-hotspots", open = true })
        end
        ui.section("Every decoration", function()
            local full = P.cpp() and P.cached("dens.cpp", 30, function() return P.callCpp("decorations") end) or nil
            local costs = {}
            for _, d in ipairs(type(full) == "table" and full or {}) do costs[d.tag] = d end
            P.pager(ui, "dens-decos", decos, function(d)
                local c = costs[d.tag]
                local extra = c and string.format("; size %s, %s s, costs %s", show(c.size), show(c.build_seconds), show(c.cost)) or ""
                ui.field(tostring(d.name or d.tag), tostring(d.tag) .. "; " .. show(d.mesh or d.skeletal) .. extra)
            end, { text = function(d) return tostring(d.name) .. " " .. tostring(d.tag) end })
        end, { id = "dens-decos", open = false })
    end, { order = 27, group = "world" })

    -- ---------- Sky and sound ----------
    local sky = { preset = "Night", valuesFor = nil }
    local snd = { id = nil, played = {}, volumes = { Master = 1, Music = 1, Effects = 1, VoiceOver = 1 }, fade = 1,
                  instead = "", effects = {}, scale = 1, system = "" }
    Menu.page("Sky and sound", function(ui)
        ui.heading("Sky, sound and effects")
        if not P.needs(ui, "sky") then return end
        P.said(ui, "sky")
        ui.section("Sky", function()
            local presets = P.cached("sky.presets", 30, Game.sky.presets) or {}
            ui.columns({ { "Held", show(Game.sky.held()) }, { "Sky now", show(Game.sky.actor()) } })
            if #presets > 0 then sky.preset = ui.choice("Preset", sky.preset, presets) end
            local hit = ui.buttons({ "Put it on and hold it", "Put it on once", "The area's own sky" })
            if hit == 1 then P.result("sky", sky.preset .. " is held until you let go.", Game.sky.set(sky.preset, true))
            elseif hit == 2 then P.result("sky", sky.preset .. " is on: the game fades back to the area's within about 5 s.", Game.sky.set(sky.preset, false))
            elseif hit == 3 then P.result("sky", "The area's own sky is back.", Game.sky.followArea()) end
            ui.note("Game.sky.set: the game fades back to the area's sky by itself, so a held preset is put on again every frame.")
            if not P.cpp() then
                ui.note("The sky's own values (its fog, sun, clouds) are the C++ part's sky_values. " .. P.CPP_HELP)
                return
            end
            local values = P.cached("sky.values." .. sky.preset, 1, function() return P.callCpp("sky_values", sky.preset) end) or {}
            P.pager(ui, "sky-values", values, function(v)
                if type(v.value) == "number" then
                    local nv = ui.number(v.name, v.value, { step = 0.01 })
                    if P.changed(nv, v.value) then
                        P.result("sky", v.name .. " set: it shows the next time " .. sky.preset .. " goes on.",
                                 P.callCpp("set_sky_value", sky.preset, v.name, nv))
                        P.forget("sky.values." .. sky.preset)
                    end
                else
                    ui.field(v.name, show(v.value))
                end
            end, { text = function(v) return v.name end, size = 12 })
            if ui.button("Put the sky's values back") then P.result("sky", "The sky's values are the game's again.", P.callCpp("restore_sky_values")) end
        end, { id = "sky-sky", open = true })

        ui.section("Sounds", function()
            local ids = P.cached("sounds.ids", 60, Game.sounds.ids) or {}
            ui.columns({ { "Sounds", #ids }, { "All paused", show(Game.sounds.paused()) } })
            local paused = Game.sounds.paused() == true
            if ui.switch("Pause every sound", paused) ~= paused then Game.sounds.pause(not paused) end
            P.pager(ui, "sounds-ids", ids, function(id)
                local hit = ui.buttons({ (snd.id == id and "> " or "") .. id, "Mute", "Unmute" }, { kinds = { snd.id == id and "primary" or nil, "danger" } })
                if hit == 1 then
                    snd.id = id
                    local c = Game.sounds.play(id)
                    if c then table.insert(snd.played, 1, c) end
                    P.result("sky", string.format("Playing %s (%s s).", id, show(Game.sounds.duration(id))), c ~= nil)
                elseif hit == 2 then P.result("sky", id .. " is muted.", Game.sounds.mute(id))
                elseif hit == 3 then P.result("sky", id .. " is back.", Game.sounds.restore(id)) end
            end, { text = function(id) return id end, size = 10, hint = "mus_, cat_, ui_, vo_..." })
            local hit = ui.buttons({ "Play the picked one at my cat", "Stop what this page played" })
            if hit == 1 and snd.id then
                local c = Game.sounds.play(snd.id, P.here())
                if c then table.insert(snd.played, 1, c) end
                P.result("sky", "Playing " .. snd.id .. " where your cat is.", c ~= nil, "a menu sound has no place")
            elseif hit == 2 then
                for _, c in ipairs(snd.played) do pcall(Game.sounds.stop, c) end
                snd.played = {}
            end
            while #snd.played > 20 do table.remove(snd.played) end
            if snd.id and P.cpp() then
                snd.instead = ui.input("Play another sound for " .. snd.id, snd.instead, { hint = "an id, e.g. ui_select" })
                local r = ui.buttons({ "Swap it", "Give it its own back" })
                if r == 1 and snd.instead ~= "" then
                    P.result("sky", snd.id .. " plays " .. snd.instead .. " from now on.", P.callCpp("replace_sound", snd.id, snd.instead))
                elseif r == 2 then P.result("sky", snd.id .. " plays its own sound again.", P.callCpp("restore_sound", snd.id)) end
            end
            ui.note("Game.sounds: a press plays one heard everywhere and picks it. Mute sets its sound's own volume to 0 " ..
                    "(another id with the same sound goes quiet too). Swapping a sound is the C++ part's replace_sound.")
        end, { id = "sky-sounds", open = false })

        ui.section("Volumes and music", function()
            for _, k in ipairs({ "Master", "Music", "Effects", "VoiceOver" }) do
                local v = ui.slider(words(k) .. " volume", snd.volumes[k], 0, 1, { step = 0.05, format = "%.2f" })
                if P.changed(v, snd.volumes[k]) then
                    snd.volumes[k] = v
                    Game.sounds.setVolume(k, v)
                end
            end
            ui.note("As the game's Audio settings set them (Game.sounds.setVolume). The game's own levels can't be read, so " ..
                    "these start at 1 and set only when moved.")
            local now = Game.music.now()
            ui.field("Music now", now and show(now.id) or "none")
            snd.fade = ui.slider("Fade out over", snd.fade, 0, 5, { step = 0.5, format = "%.1f s" })
            if ui.button("Stop the music") then P.result("sky", "The music fades out.", Game.music.stop(snd.fade)) end
            local tracks = {}
            for _, id in ipairs(P.cached("sounds.ids", 60, Game.sounds.ids) or {}) do
                if id:find("^mus_") then tracks[#tracks + 1] = id end
            end
            P.pager(ui, "music", tracks, function(id)
                if ui.button("Play " .. id) then P.result("sky", "Playing " .. id .. " until the game changes track.", Game.music.play(id)) end
            end, { size = 10 })
        end, { id = "sky-music", open = false })

        if P.has("effects") then
            ui.section("Visual effects", function()
                snd.scale = ui.slider("Size", snd.scale, 0.2, 5, { step = 0.1, format = "x%.1f" })
                local names = P.cached("effects.names", 30, Game.effects.names) or {}
                for i = 1, #names, 4 do
                    local row = {}
                    for j = i, math.min(#names, i + 3) do row[#row + 1] = names[j] end
                    local hit = ui.buttons(row)
                    if hit then
                        local e, why = Game.effects.game(row[hit], P.here(), snd.scale)
                        if e then table.insert(snd.effects, 1, e) end
                        P.result("sky", row[hit] .. " plays at your cat.", e ~= nil, why)
                    end
                end
                snd.system = ui.input("A Niagara system's path", snd.system, { hint = "/Game/.../NS_Something.NS_Something" })
                local hit = ui.buttons({ "Play it at my cat", "Stop every effect this page played" })
                if hit == 1 and snd.system ~= "" then
                    local e, why = Game.effects.spawn(snd.system, P.here(), snd.scale)
                    if e then table.insert(snd.effects, 1, e) end
                    P.result("sky", "Playing it.", e ~= nil, why)
                elseif hit == 2 then
                    for _, e in ipairs(snd.effects) do pcall(e.stop, e) end
                    snd.effects = {}
                end
                while #snd.effects > 20 do table.remove(snd.effects) end
                ui.note("Game.effects.game plays one of the game's own by name; Game.effects.spawn any Niagara system.")
            end, { id = "sky-effects", open = false })
        end
    end, { order = 28, group = "world" })

    -- ---------- Camera ----------
    local CAM = { distance = { "Distance", 20, 1000, 1 }, fov = { "Field of view", 20, 150, 1 }, pitch = { "Pitch", -60, 60, 1 },
                  speedDistance = { "Speed: distance", 0, 300, 1 }, speedFov = { "Speed: field of view", 0, 60, 1 },
                  lag = { "Lag", 0, 50, 0.5 }, rotationLag = { "Turning lag", 0, 50, 0.5 }, turnYaw = { "Turning: sideways", 0, 400, 1 },
                  turnPitch = { "Turning: up and down", 0, 400, 1 }, pitchMin = { "Lowest pitch", -89, 0, 1 }, pitchMax = { "Highest pitch", 0, 89, 1 } }
    local CAM_ORDER = { "distance", "fov", "pitch", "speedDistance", "speedFov", "lag", "rotationLag", "turnYaw", "turnPitch", "pitchMin", "pitchMax" }
    local photo = { scale = 1, ui = true }
    local okView, View = pcall(require, "WCModsView")
    Menu.page("Camera", function(ui)
        ui.heading("Camera and photos")
        if not P.needs(ui, "camera") then return end
        if not Game.cat() then ui.text("Not in the world yet.") return end
        P.said(ui, "camera")
        ui.section("The camera following your cat", function()
            local v = Game.camera.view()
            if v then ui.columns({ { "From your cat", string.format("%.0f cm", v.distance or 0) }, { "Field of view", show(v.fov) } }) end
            local s = Game.camera.settings() or {}
            local set = {}
            for _, k in ipairs(CAM_ORDER) do
                local d, now = CAM[k], s[k]
                if type(now) == "number" then
                    local nv = ui.slider(d[1], now, math.min(d[2], now), math.max(d[3], now), { step = d[4], format = "%.1f" })
                    if P.changed(nv, now) then set[k] = nv end
                end
            end
            if next(set) then Game.camera.set(set) end
            if ui.button("Put the game's camera back") then P.result("camera", "The game's camera settings are back.", Game.camera.reset()) end
            ui.note("Game.camera.set: the camera eases to them over about a second. The turning ones are your cat's.")
        end, { id = "camera-follow", open = true })
        ui.section("Photo mode", function()
            local active = Game.photo.active() == true
            if ui.switch("Photo mode", active) ~= active then
                P.result("camera", active and "Photo mode is off." or "Photo mode opens (about two seconds).", Game.photo.mode(not active))
            end
            local shown = ui.switch("Photo mode's menus shown", photo.ui)
            if shown ~= photo.ui then
                photo.ui = shown
                Game.photo.ui(shown)
            end
            photo.scale = ui.slider("Picture size (x the window)", photo.scale, 1, 4, { step = 1, format = "x%.0f" })
            if ui.button("Take a picture", { kind = "primary" }) then
                P.result("camera", "Saved in " .. show(Game.photo.folder()) .. ".", Game.photo.take(math.floor(photo.scale)))
            end
            ui.field("Pictures go in", show(Game.photo.folder()))
            ui.field("Photo mode's camera", show(Game.photo.camera()))
        end, { id = "camera-photo", open = false })
        if okView then
            ui.section("What the camera sees (WCModsView)", function()
                local v = View.current()
                if not v then ui.note("No view yet.") return end
                ui.columns({ { "At", show(v.location) }, { "Pitch", show(v.rotation and v.rotation.Pitch) }, { "Yaw", show(v.rotation and v.rotation.Yaw) },
                             { "Field of view", show(v.fov) }, { "Viewport", string.format("%s x %s", show(v.width), show(v.height)) } })
                local h = P.here()
                if h then
                    local x, y, depth = View.worldToScreen(h, v)
                    ui.field("Your cat on screen", x and string.format("%.0f, %.0f, %.0f cm in front", x, y, depth) or "behind the camera")
                end
            end, { id = "camera-view", open = false })
        end
    end, { order = 29, group = "world" })

    -- ---------- HUD and map ----------
    local ICONS = { "search", "talk", "barter", "freshkill", "trainer", "den", "outpost", "skirmish", "madcat",
                    "ThunderClan", "ShadowClan", "RiverClan", "WindClan" }
    local hud = { icon = "search", markers = {}, title = "A test quest", location = "The old oak", activity = "Find three herbs",
                  goals = { { name = "Herbs", progress = "1/3" }, { name = "", progress = "" }, { name = "", progress = "" } },
                  banner = "begin", bannerTitle = "A test quest", bannerText = "Find three herbs", seconds = 4.5, hidden = {} }
    local PARTS = { "mcGuiMinimap", "mcGuiEnergyBar", "mcGuiQuestObjective", "mcGuiHealthBar", "mcGuiCompass", "mcGuiNotifications" }
    Menu.page("HUD and map", function(ui)
        ui.heading("The HUD and the map")
        if not P.needs(ui, "hud") then return end
        if not Game.cat() then ui.text("Not in the world yet.") return end
        P.said(ui, "hud")
        ui.section("Markers on the minimap and the world map", function()
            if not P.needs(ui, "mapMarker") then return end
            hud.icon = ui.choice("Icon", hud.icon, ICONS)
            local hit = ui.buttons({ "Mark where your cat stands", "Take them all off" })
            if hit == 1 then
                local m, why = Game.mapMarker(P.here(), { icon = hud.icon })
                if m then hud.markers[#hud.markers + 1] = { m = m, at = P.here(), icon = hud.icon } end
                P.result("hud", "Marked.", m ~= nil, why)
            elseif hit == 2 then
                for _, e in ipairs(hud.markers) do pcall(e.m.remove, e.m) end
                hud.markers = {}
            end
            for i, e in ipairs(hud.markers) do
                if ui.button(string.format("Take off %s at %s", e.icon, show(e.at))) then
                    pcall(e.m.remove, e.m)
                    table.remove(hud.markers, i)
                    break
                end
            end
            ui.note("Game.mapMarker: the game's own point of interest, kept at the minimap's edge when it's further off.")
        end, { id = "hud-markers", open = true })
        ui.section("The objective panel", function()
            hud.title = ui.input("Title", hud.title)
            hud.location = ui.input("Place", hud.location)
            hud.activity = ui.input("What to do now", hud.activity)
            for i, g in ipairs(hud.goals) do
                g.name = ui.input("Goal " .. i, g.name)
                g.progress = ui.input("Goal " .. i .. " progress", g.progress, { hint = "1/3" })
            end
            local hit = ui.buttons({ "Show it", "Put it away" })
            if hit == 1 then
                local goals = {}
                for _, g in ipairs(hud.goals) do
                    if g.name ~= "" then goals[#goals + 1] = { name = g.name, progress = g.progress } end
                end
                P.result("hud", "Showing.", Game.hud.objective({ title = hud.title, location = hud.location, activity = hud.activity, goals = goals }))
            elseif hit == 2 then P.result("hud", "Put away.", Game.hud.objective(nil)) end
            ui.note("Game.hud.objective: the game's own panel on the left. The game puts its own quest's back when it has one.")
        end, { id = "hud-objective", open = false })
        ui.section("A banner", function()
            hud.banner = ui.radio("Kind", hud.banner, { "begin", "update", "done", "failed" })
            hud.bannerTitle = ui.input("Banner title", hud.bannerTitle)
            hud.bannerText = ui.input("Banner text", hud.bannerText)
            hud.seconds = ui.slider("For", hud.seconds, 1, 15, { step = 0.5, format = "%.1f s" })
            if ui.button("Show the banner") then
                P.result("hud", "Shown.", Game.hud.banner(hud.banner, { title = hud.bannerTitle, text = hud.bannerText, seconds = hud.seconds }))
            end
        end, { id = "hud-banner", open = false })
        ui.section("The HUD's parts", function()
            local cui = rawget(_G, "WCModsCpp") and WCModsCpp.ui
            if not cui then
                ui.note("Hiding the HUD's parts goes through WCModsCpp.ui, which any C++ mod built with wcmods' SDK brings " ..
                        "(this mod's C++ part does).")
                return
            end
            for _, name in ipairs(PARTS) do
                local ok, w = pcall(cui.hud, name)
                if ok and w then
                    local shown = not hud.hidden[name]
                    if ui.toggle(name, shown) ~= shown then
                        hud.hidden[name] = shown or nil
                        pcall(cui.visible, w, not shown)
                    end
                end
            end
            ui.note("WCModsCpp.ui.hud(part) and visible: parts this game build hasn't got aren't listed. A new HUD (a load) " ..
                    "shows them all again.")
        end, { id = "hud-parts", open = false })
    end, { order = 30, group = "world" })
end
