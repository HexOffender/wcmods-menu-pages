-- Your cat: Looks, Movement and Animations (WCModsGame's looks, speeds, movement, scent sense and animations; the
-- C++ part puts a look on and keeps it).
return function(P)
    local Menu, show, cpp, callCpp = P.Menu, P.show, P.cpp, P.callCpp

    -- ---------- Whose: your cat, or a cat or animal near it ----------
    -- The pages here act on one cat at a time. The others near are looked up again each time (by address, P.pick),
    -- so one that has gone since is never used.
    -- The labels are names, numbered when two share one, and the list is asked again every two seconds, so the
    -- drop-down's options don't change under the mouse each frame.
    local function whoList(withAnimals)
        return P.cached("body.who." .. tostring(withAnimals), 2, function()
            local list, seen = { { label = "Your cat", actor = nil } }, {}
            local function add(name, actor)
                seen[name] = (seen[name] or 0) + 1
                list[#list + 1] = { label = seen[name] > 1 and (name .. " " .. seen[name]) or name, actor = actor }
            end
            if P.has("walkers", "near") then
                for _, w in ipairs(Game.walkers.near(3000)) do
                    if #list > 8 then break end
                    local c = Game.valid(w.actor) and Game.cat(w.actor)
                    add((c and c:name() or "A clan cat") .. " (walking)", w.actor)
                end
            end
            if withAnimals and P.has("animals", "near") then
                for _, a in ipairs(Game.animals.near(3000)) do
                    if #list > 14 then break end
                    add(P.words(tostring(a.model or "Animal"):gsub("^SK_", "")), a.actor)
                end
            end
            if P.has("npcs", "all") then
                for _, n in ipairs(Game.npcs.all()) do
                    local a = not n.removed and n:actorOrNil()
                    if a then add("Your own cat", a) end
                end
            end
            return list
        end) or { { label = "Your cat" } }
    end
    -- A choice of whose, drawn as a row: gives the entry (nil actor: your cat).
    local function whoRow(ui, page, withAnimals)
        local list = whoList(withAnimals)
        local labels, chosen = {}, list[1]
        local want = P.pickedId(page)
        for i, e in ipairs(list) do
            labels[i] = e.label
            if want and e.actor and P.addr(e.actor) == want then chosen = e end
        end
        if want and chosen == list[1] then P.pick(page, nil) end   -- (gone since)
        local label = ui.choice("Whose", chosen.label, labels)
        if label ~= chosen.label then
            for _, e in ipairs(list) do
                if e.label == label then
                    P.pick(page, e.actor)
                    chosen = e
                end
            end
        end
        return chosen
    end
    P.whoRow = whoRow

    -- ---------- Looks ----------
    -- A look's fields by group, from the names the game gives them (Game.lookFields, its CustomData).
    local function groupOf(name)
        if name == "ClanType" or name == "Role" then return "Clan and role" end
        if name:find("Accesory") or name:find("Accessory") then return "Accessories" end
        if name:find("Scar") then return "Scars" end
        if name:find("Name") then return "Name" end
        if name:find("Color") or name:find("Colour") then return "Colours" end
        return "Shape and size"
    end
    local GROUPS = { "Clan and role", "Name", "Shape and size", "Colours", "Accessories", "Scars" }
    local edits, lookText = {}, ""   -- edits: field -> the value it's to have, until put on or forgotten
    local accessoryVariation = 1
    local function asText(v)
        if type(v) == "userdata" then return show(v) end
        return v
    end
    Menu.page("Looks", function(ui)
        ui.heading("Looks")
        if not P.needs(ui, "lookFields") then return end
        if not Game.cat() then ui.text("Not in the world yet.") return end
        local who = whoRow(ui, "looks")
        local cat = who.actor and Game.cat(who.actor) or Game.cat()
        if not cat then return end
        if edits._who ~= who.label then edits = { _who = who.label } end   -- (another cat's changes aren't this one's)
        local look = cat:look() or {}
        local canEdit = cpp() ~= nil
        ui.note("The look the game has now, by its own names (Game.lookFields). " .. (canEdit and
                "Change fields, then Put it on (the C++ part's set_look: meshes, colours, accessories and scars follow); " ..
                "Keep it in the save makes it your cat's for good." or P.CPP_HELP))
        local role = cat:role()
        if role then ui.columns({ { "Clan", show(role.clan) }, { "Role", show(role.role) }, { "Story role", show(role.storyRole) } }) end
        local byGroup = {}
        for _, name in ipairs(Game.lookFields) do
            local g = groupOf(name)
            byGroup[g] = byGroup[g] or {}
            byGroup[g][#byGroup[g] + 1] = name
        end
        for _, g in ipairs(GROUPS) do
            if byGroup[g] then
                ui.section(g, function()
                    for _, name in ipairs(byGroup[g]) do
                        local v = asText(look[name])
                        local want = edits[name]
                        if want == nil then want = v end
                        if not canEdit then
                            ui.field(name, show(v))
                        elseif type(v) == "number" then
                            local n = ui.number(name, want, { step = math.type(v) == "integer" and 1 or 0.05, whole = math.type(v) == "integer" })
                            if n ~= want then edits[name] = n end
                        elseif type(v) == "boolean" then
                            local b = ui.toggle(name, want)
                            if b ~= want then edits[name] = b end
                        else
                            local s = ui.input(name, tostring(want or ""))
                            if s ~= tostring(want or "") then edits[name] = s end
                        end
                    end
                end, { id = "looks-" .. g, open = g == "Clan and role" or g == "Colours" })
            end
        end
        if canEdit then
            local changes, n = {}, 0
            for k, v in pairs(edits) do
                if k ~= "_who" then changes[k], n = v, n + 1 end
            end
            if n > 0 then ui.note(string.format("%d field%s changed, not put on yet.", n, n == 1 and "" or "s")) end
            local hit = ui.buttons({ "Put it on", "Keep it in the save", "Forget the changes" }, { kinds = { "primary", nil, "danger" } })
            if hit == 1 then
                if P.result("looks", "Put on.", callCpp("set_look", P.addr(who.actor), changes)) then edits = { _who = who.label } end
            elseif hit == 2 then
                if who.actor then
                    P.say("looks", "Only your cat's look is kept in a save.")
                elseif P.result("looks", "Put on and kept as your cat's look: the game's next save writes it.", callCpp("keep_look", changes)) then
                    -- (keep_look only writes the save's look; set_look draws it on the cat now.)
                    callCpp("set_look", nil, changes)
                    edits = { _who = who.label }
                end
            elseif hit == 3 then edits = { _who = who.label } end
        end
        P.said(ui, "looks")

        ui.section("Accessories", function()
            local all = P.cached("accessories", 30, Game.accessories) or {}
            ui.note(string.format("The game's %d accessories, by slot. Wearing one goes through the C++ part's wear.", #all))
            if canEdit then
                accessoryVariation = ui.number("Variation", accessoryVariation, { min = 1, max = 8, step = 1, whole = true })
                local slots = ui.buttons({ "Take off Neck", "Take off Paw", "Take off Head", "Take off Body" }, { kinds = { "danger", "danger", "danger", "danger" } })
                if slots then
                    local slot = ({ "Neck", "Paw", "Head", "Body" })[slots]
                    P.result("looks", "Took off the " .. slot .. " accessory.", callCpp("take_off", P.addr(who.actor), slot))
                end
            end
            P.pager(ui, "looks-accessories", all, function(a)
                local label = string.format("%s  (%s, %s variation%s)", a.id, a.slot ~= "" and a.slot or "?", show(a.variations),
                                            a.variations == 1 and "" or "s")
                if canEdit then
                    if ui.button("Wear " .. label) then
                        P.result("looks", "Wearing " .. a.id .. ".", callCpp("wear", P.addr(who.actor), a.id, math.floor(accessoryVariation)))
                    end
                else
                    ui.field(a.id, (a.slot ~= "" and a.slot or "?") .. ", " .. show(a.variations) .. " variations")
                end
            end, { text = function(a) return a.id .. " " .. tostring(a.slot) end, size = 12 })
        end, { id = "looks-accessories", open = false })

        ui.section("A look from the save's text", function()
            ui.note("A cat's look as the save keeps it in NPCData, \"(ClanType=ShadowClan,Role=Leader,TailIdx=8,...)\" (Game.lookFromText).")
            lookText = ui.input("Look text", lookText, { hint = "(ClanType=...,BodyValue=...)" })
            if lookText ~= "" then
                local ok, parsed = pcall(Game.lookFromText, lookText)
                if ok and type(parsed) == "table" then
                    local parts = {}
                    for k, v in pairs(parsed) do parts[#parts + 1] = k .. "=" .. show(v) end
                    table.sort(parts)
                    ui.text(table.concat(parts, ", "))
                    if canEdit and ui.button("Use it for the changes above") then
                        for k, v in pairs(parsed) do edits[k] = asText(v) end
                    end
                else
                    ui.note("Not a look: " .. tostring(parsed))
                end
            end
        end, { id = "looks-text", open = false })
    end, { order = 11, group = "cat" })

    -- ---------- Movement ----------
    local SPEEDS = { { "walk", "Walking speed", 50, 1500, 5 }, { "run", "Running speed", 50, 3000, 10 },
                     { "walkAcceleration", "Walking acceleration", 10, 3000, 5 }, { "runAcceleration", "Running acceleration", 10, 3000, 5 },
                     { "crouch", "Crouching (x walking)", 0.1, 2, 0.05 }, { "climb", "Climbing (x)", 0.1, 5, 0.05 } }
    Menu.page("Movement", function(ui)
        ui.heading("Movement")
        local cat = Game.cat()
        if not cat then ui.text("Not in the world yet.") return end
        if P.has("speeds") then
            ui.section("Your cat's own speeds", function()
                local s = Game.speeds() or {}
                ui.columns({ { "Running", show(s.running) }, { "Crouching", show(s.crouching) }, { "Climbing", show(s.climbing) } })
                local set = {}
                for _, d in ipairs(SPEEDS) do
                    local v = s[d[1]]
                    if type(v) == "number" then
                        local nv = ui.slider(d[2], v, math.min(d[3], v), math.max(d[4], v), { step = d[5], format = d[5] < 1 and "%.2f" or "%.0f" })
                        if P.changed(nv, v) then set[d[1]] = nv end
                    end
                end
                if next(set) then P.result("movement", "Speeds set.", Game.setSpeeds(set)) end
                if ui.button("Put the game's speeds back") then
                    P.result("movement", "The game's speeds are back.", Game.resetSpeeds() ~= false)
                end
                ui.note("Game.speeds and setSpeeds: the game takes them the next frame. Back puts what the game had before the first change.")
            end, { id = "movement-speeds", open = true })
        end
        if cat.movement then
            ui.section("Movement component", function()
                local m = cat:movement() or {}
                ui.columns({ { "Walking", show(m.walkSpeed) }, { "Crouched", show(m.crouchedSpeed) }, { "Acceleration", show(m.acceleration) },
                             { "Step height", show(m.stepHeight) }, { "Mode", show(m.mode) } })
                if type(m.jumpSpeed) == "number" then
                    local j = ui.slider("Jump speed", m.jumpSpeed, 0, math.max(2000, m.jumpSpeed), { step = 10, format = "%.0f" })
                    if P.changed(j, m.jumpSpeed) then P.result("movement", "Jump speed set.", cat:setJumpSpeed(j)) end
                end
                if type(m.gravity) == "number" then
                    local g = ui.slider("Gravity", m.gravity, 0, math.max(3, m.gravity), { step = 0.05, format = "x%.2f" })
                    if P.changed(g, m.gravity) then P.result("movement", "Gravity set.", cat:setGravity(g)) end
                end
                ui.note("cat:movement(), setJumpSpeed and setGravity: the game leaves them as set. Your cat's walking speed is " ..
                        "set every frame from its own speeds (above), so setWalkSpeed is for other cats and animals.")
            end, { id = "movement-component", open = true })
        end
        ui.section("Its own time", function()
            local now = tonumber(Game.get(cat.actor, "CustomTimeDilation")) or 1
            local t = ui.slider("Time (x)", now, 0.1, 4, { step = 0.05, format = "x%.2f" })
            if P.changed(t, now) then cat:setTimeDilation(t) end
            ui.note("cat:setTimeDilation: this cat's own time, 2 twice as fast. Game speed for the whole world is on Cheats.")
        end, { id = "movement-time", open = false })
        if P.has("useSense") then
            ui.section("Scent sense", function()
                ui.progress("Showing", Game.sense() or 0, { text = string.format("%.0f%%", 100 * (Game.sense() or 0)) })
                if ui.button("Use the scent sense") then P.result("movement", "Sniffing.", Game.useSense() ~= false) end
                ui.note("The game's own scent sense (Q), through its command (Game.useSense); Game.sense says how much it shows.")
            end, { id = "movement-sense", open = false })
        end
        P.said(ui, "movement")
    end, { order = 12, group = "cat" })

    -- ---------- Animations ----------
    local anim = { loop = false, speed = 1, blend = 0.25, path = "", tag = "Animation.Exploration.Meow", table = nil, rate = 1 }
    local TAGS = { "Animation.Exploration.Meow", "Animation.Exploration.Interaction.Dig", "Animation.Exploration.Interaction.Sniff",
                   "Animation.Combat.Hit.1" }
    Menu.page("Animations", function(ui)
        ui.heading("Animations")
        if not P.needs(ui, "anims") then return end
        if not Game.cat() then ui.text("Not in the world yet.") return end
        local who = whoRow(ui, "anims", true)
        local actor = who.actor or Game.player()
        if not Game.valid(actor) then return end
        local c = Game.cat(actor)
        ui.columns({ { "Plays now", show(Game.anims.playing(actor)) }, { "A montage", show(c and c:montagePlaying()) },
                     { "Skeleton", show(Game.anims.kind(actor)) } })
        if ui.button("Stop", { kind = "danger" }) then
            P.say("anims", Game.anims.stop(actor, anim.blend) and "Stopped." or "Nothing Game.anims.play started was playing on it.")
        end
        P.said(ui, "anims")
        ui.section("Mods' animations", function()
            anim.loop = ui.switch("Loop", anim.loop)
            anim.speed = ui.slider("Speed", anim.speed, 0.1, 3, { step = 0.05, format = "x%.2f" })
            anim.blend = ui.slider("Blend in and out", anim.blend, 0, 1, { step = 0.05, format = "%.2f s" })
            local list = {}
            for id, a in pairs(Game.anims.list() or {}) do list[#list + 1] = { id = id, a = a } end
            table.sort(list, function(x, y) return x.id < y.id end)
            P.pager(ui, "anims-mods", list, function(e)
                if ui.button(string.format("Play %s  (%s, %s s%s)", e.id, show(e.a.kind), show(e.a.seconds), e.a.key and (", key " .. e.a.key) or "")) then
                    local m, why = Game.anims.play(actor, e.id, { loop = anim.loop, speed = anim.speed, blend = anim.blend })
                    P.result("anims", "Playing " .. e.id .. ".", m ~= nil, why)
                end
            end, { text = function(e) return e.id end, empty = "No mod has animations (animations.json) installed." })
        end, { id = "anims-mods", open = true })
        ui.section("The game's animations, by tag", function()
            ui.note("cat:playMontage(tag): one of the game's own, as it plays them (its animation table's row), cutting off what plays.")
            anim.rate = ui.slider("Rate", anim.rate, 0.1, 3, { step = 0.05, format = "x%.2f" })
            anim.tag = ui.input("Tag", anim.tag, { hint = "Animation.Exploration.Meow" })
            local hit = ui.buttons({ "Play it", "Meow", "Dig", "Sniff", "Hit" })
            local tag = hit == 1 and anim.tag or (hit and TAGS[hit - 1])
            if tag and c then P.result("anims", "Playing " .. tag .. ".", c:playMontage(tag, anim.rate) ~= nil) end
            local tables = P.cached("anims.tables", 30, function()
                local out = {}
                for _, t in ipairs(Game.tables.list()) do
                    if t.rowStruct == "SwtAnimationStruct" then out[#out + 1] = t.name end
                end
                table.sort(out)
                return out
            end) or {}
            if #tables > 0 then
                anim.table = ui.choice("The fight animations of", anim.table or tables[1], tables)
                -- The game plays a row by its tag (its GameplayTag field), not by the row's name.
                local rows = P.cached("anims.rows." .. anim.table, 30, function()
                    local out = {}
                    for _, r in ipairs(Game.tables.rows(anim.table)) do
                        local okT, tag = pcall(Game.tagName, Game.get(r.row, "GameplayTag"))
                        out[#out + 1] = { name = r.name, tag = okT and tag ~= "" and tag ~= "None" and tag or nil }
                    end
                    return out
                end) or {}
                P.pager(ui, "anims-rows", rows, function(r)
                    if ui.button(string.format("Play %s  (%s)", r.name, r.tag or "no tag")) and c then
                        if r.tag then P.result("anims", "Playing " .. r.tag .. ".", c:playMontage(r.tag, anim.rate) ~= nil)
                        else P.say("anims", "Couldn't: " .. r.name .. " has no tag to play it by.") end
                    end
                end, { text = function(r) return r.name .. " " .. tostring(r.tag) end, size = 10 })
            end
        end, { id = "anims-game", open = false })
        ui.section("One of the game's sequences, by path", function()
            ui.note("Game.anims.play with an animation sequence's path, played over what the cat is doing.")
            anim.path = ui.input("Path", anim.path, { hint = "/Game/Art/Characters/CatMaster/Animations/A_CatMaster_Stretch_1.A_CatMaster_Stretch_1" })
            if ui.button("Play the sequence") and anim.path ~= "" then
                local m, why = Game.anims.play(actor, anim.path, { loop = anim.loop, speed = anim.speed, blend = anim.blend })
                P.result("anims", "Playing it.", m ~= nil, why)
            end
        end, { id = "anims-path", open = false })
    end, { order = 13, group = "cat" })
end
