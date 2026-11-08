-- World: Animals, Walking cats and Your own cats (Game.animals, Game.ai, Game.walkers, Game.npcs and
-- Game.dialogue; the C++ part's ai_tree and ai_task say what an AI is doing).
return function(P)
    local Menu, show, words = P.Menu, P.show, P.words

    -- ---------- An AI's state and controls, the same for an animal, a walking cat and a mod's cat ----------
    local function aiState(ui, actor)
        local cols = { { "Logic", Game.ai.running(actor) and "running" or "stopped" }, { "Asleep", show(Game.ai.asleep(actor)) },
                       { "Moving", show(Game.ai.moving(actor)) }, { "Following", show(Game.ai.following(actor)) } }
        if P.cpp() then
            -- (Asked twice a second: the C++ part finds an actor by its address among the game's objects each time.)
            local key = tostring(P.addr(actor))
            cols[#cols + 1] = { "Tree now", show(P.cached("ai.tree." .. key, 0.5, function() return P.callCpp("ai_tree", P.addr(actor)) end)) }
            local task = P.cached("ai.task." .. key, 0.5, function() return P.callCpp("ai_task", P.addr(actor)) end)
            cols[#cols + 1] = { "Doing", type(task) == "table" and show(task.name) or "-" }
        end
        ui.columns(cols)
    end
    -- An animal walked into your cat catches it as a chase does (a fight starts), so animals stop a few metres off.
    local function aiControls(ui, actor, page, animal)
        local me = Game.player()
        local running = Game.ai.running(actor)
        local hit = ui.buttons({ running and "Stop its AI" or "Start its AI again", "Come to me", "Face me", "Stop moving" },
                               { kinds = { running and "danger" or "good" } })
        if hit == 1 then
            if running then P.result(page, "Its AI is stopped: it stands where it is. Start it again before you go.", Game.ai.stop(actor))
            else P.result(page, "Its AI runs again, from its tree's start.", Game.ai.restart(actor)) end
        elseif hit == 2 and me then
            P.result(page, "On its way to you.", Game.ai.moveTo(actor, me, { radius = animal and 300 or 150, restartAfter = true,
                done = function(r) P.say(page, "Its walk ended: " .. tostring(r) .. ".") end }))
        elseif hit == 3 and me then P.result(page, "Facing you.", Game.ai.face(actor, me))
        elseif hit == 4 then P.result(page, "Stopped.", Game.ai.stopMoving(actor)) end
        local following = Game.ai.following(actor)
        if ui.button(following and "Stop following you" or "Follow you about") and me then
            if following then P.result(page, "It stopped following you.", Game.ai.stopFollowing(actor, true))
            else P.result(page, "It follows you about.", Game.ai.follow(actor, me, { distance = animal and 300 or 150 })) end
        end
    end
    local treeChoice = {}
    local function treeRows(ui, actor, page)
        local trees = Game.ai.trees(actor)
        if trees then ui.columns({ { "Its own tree", show(trees.roaming) }, { "In a fight", show(trees.fight) } }) end
        treeChoice[page] = ui.choice("Tree", treeChoice[page] or Game.ai.TREES[1], Game.ai.TREES)
        local hit = ui.buttons({ "Run it now", "Make it its own tree" })
        if hit == 1 then
            P.result(page, "Running " .. treeChoice[page] .. ": the game starts its own trees again on its own occasions.",
                     Game.ai.runTree(actor, treeChoice[page]))
        elseif hit == 2 then
            P.result(page, treeChoice[page] .. " is its own tree now (it runs when its controller next starts one).",
                     Game.ai.setTrees(actor, treeChoice[page], nil))
        end
    end

    -- ---------- Animals ----------
    local animals = { radius = 3000, stealth = false, spawned = {}, ignoreNew = true, respawn = false, tree = "BT_Enemy" }
    local DETECT = { { "Vision", 1 }, { "Sound", 2 }, { "Cone", 4 }, { "In pursuit", 8 } }
    Menu.page("Animals", function(ui)
        ui.heading("Animals")
        if not P.needs(ui, "ai") or not P.needs(ui, "animals") then return end
        if not Game.cat() then ui.text("Not in the world yet.") return end
        local stealth = ui.switch("Every animal near ignores your cat", animals.stealth)
        if stealth ~= animals.stealth then
            animals.stealth = stealth
            P.result("animals", stealth and "Stealth: the animals within 50 m ignore your cat." or "The animals notice your cat again.",
                     Game.ai.ignorePlayerEverywhere(stealth))
        end
        animals.radius = ui.slider("Within", animals.radius, 500, 10000, { step = 500, format = "%.0f cm" })
        local list = P.cached("animals.near." .. animals.radius, 0.5, function() return Game.animals.near(animals.radius) end) or {}
        local labels, chosen = { "(none)" }, P.picked("animals", list)
        local now = "(none)"
        for i, a in ipairs(list) do
            labels[#labels + 1] = string.format("%d. %s", i, words(tostring(a.model or "?"):gsub("^SK_", "")))
            if a == chosen then now = labels[#labels] end
        end
        ui.field("Near", string.format("%d animal%s", #list, #list == 1 and "" or "s"))
        local want = ui.choice("Pick one", now, labels)
        if want ~= now then
            local i = tonumber(want:match("^(%d+)%."))
            chosen = i and list[i] or nil
            P.pick("animals", chosen and chosen.actor)
        end
        P.said(ui, "animals")
        if chosen and Game.valid(chosen.actor) then
            local a = chosen.actor
            local c = Game.cat(a)
            ui.columns({ { "Kind", show(Game.animals.kind(a) or chosen.kind or "the game's own") }, { "Model", show(chosen.model) },
                         { "Away", string.format("%.0f m", chosen.distance / 100) },
                         { "Health", c and string.format("%s / %s", show(c:health()), show(c:maxHealth())) or "-" } })
            aiState(ui, a)
            ui.columns({ { "Tracks your cat", show(Game.ai.trackingPlayer(a)) }, { "Ignores your cat", show(Game.ai.ignoringPlayer(a)) } })
            aiControls(ui, a, "animals", true)
            local ignoring = Game.ai.ignoringPlayer(a)
            local hit = ui.buttons({ ignoring and "Notice your cat again" or "Ignore your cat", "Notice your cat now", "Lose your cat",
                                     "Run away", "Fight it", "Take it away" }, { kinds = { nil, "danger", nil, nil, "danger", "danger" } })
            if hit == 1 then P.result("animals", ignoring and "It notices your cat again." or "It ignores your cat.", Game.ai.ignorePlayer(a, not ignoring))
            elseif hit == 2 then P.result("animals", "It noticed your cat: it gives chase after its reaction time.", Game.ai.noticePlayer(a))
            elseif hit == 3 then P.result("animals", "It lost your cat: back where it started, then roaming.", Game.ai.calm(a))
            elseif hit == 4 then P.result("animals", "It runs from your cat.", Game.ai.flee(a, Game.player(), 800))
            elseif hit == 5 and P.has("combat", "start") then
                P.result("animals", "Pouncing: a fight starts in a moment if the spot allows.", Game.combat.start(a))
            elseif hit == 6 then P.result("animals", "Taken away.", Game.animals.remove(a)) P.forget("animals.near." .. animals.radius) end
            ui.section("Its detection and senses", function()
                local flags = Game.ai.detectionFlags(a)
                if flags then
                    local nf = flags
                    for _, f in ipairs(DETECT) do
                        local on = math.floor(flags / f[2]) % 2 == 1
                        if ui.toggle("Detects by " .. f[1], on) ~= on then nf = nf + (on and -f[2] or f[2]) end
                    end
                    if nf ~= flags then Game.ai.setDetectionFlags(a, nf) end
                    ui.note("Its detection mask (Game.ai.detectionFlags). The roaming tree passes flags of its own, so 0 alone " ..
                            "doesn't stop it noticing your cat: Ignore your cat does.")
                end
                local senses = c and c:senses()
                if type(senses) == "table" then
                    local names = {}
                    for k, v in pairs(senses) do if type(v) == "number" then names[#names + 1] = k end end
                    table.sort(names)
                    ui.field("Size class", show(senses.Range))
                    for _, k in ipairs(names) do
                        local nv = ui.number(words(k), senses[k], { step = 1 })
                        if P.changed(nv, senses[k]) then c:setSense(k, nv) end
                    end
                    ui.note("Its own copy of its size class's tuning (cat:senses, setSense): a change is this animal's alone.")
                end
            end, { id = "animals-senses", open = false })
            ui.section("Its blackboard", function() P.blackboardRows(ui, a, "animals") end, { id = "animals-bb", open = false })
            ui.section("Its trees", function() treeRows(ui, a, "animals") end, { id = "animals-trees", open = false })
        else
            ui.note("Pick one to see and steer its AI.")
        end

        ui.section("Put an animal in the world", function()
            ui.note("Game.animals.spawn: a kind is a fight party's tag from the game's table (DT_Combat_Generator). One of the " ..
                    "game's generators is borrowed and spawns it a few metres ahead of your cat; it's given back once the animal is gone.")
            animals.ignoreNew = ui.toggle("It ignores your cat as it lands (else it may chase you into a fight)", animals.ignoreNew)
            animals.respawn = ui.toggle("A new one each time it's gone", animals.respawn)
            local kinds = P.cached("animals.kinds", 60, Game.animals.kinds) or {}
            P.pager(ui, "animals-kinds", kinds, function(k)
                local party = {}
                for i, t in ipairs(k.party or {}) do
                    party[#party + 1] = words(tostring(t):match("([^%.]+)$") or t) .. (k.levels and k.levels[i] and (" " .. k.levels[i]) or "")
                end
                local label = tostring(k.tag):gsub("^Gameplay%.Combat%.Generator%.", "") .. "  (" .. table.concat(party, ", ") .. ")"
                if ui.button(label) then
                    local at = P.spot(500)
                    local made, why = Game.animals.spawn(k.tag, at, { respawn = animals.respawn })
                    if made then
                        animals.spawned[#animals.spawned + 1] = made
                        if animals.ignoreNew then Game.ai.ignorePlayer(made, true) end
                        P.forget("animals.near." .. animals.radius)
                    end
                    P.result("animals", "Put a " .. label .. " ahead of your cat.", made ~= nil, why)
                end
            end, { text = function(k) return tostring(k.tag) .. " " .. table.concat(k.party or {}, " ") end, size = 10,
                   hint = "Rabbit, Fox, Boss..." })
            local alive = {}
            for _, s in ipairs(animals.spawned) do if Game.valid(s) then alive[#alive + 1] = s end end
            animals.spawned = alive
            if #alive > 0 and ui.button(string.format("Take away the %d this page put there", #alive), { kind = "danger" }) then
                for _, s in ipairs(alive) do Game.animals.remove(s) end
                animals.spawned = {}
                P.say("animals", "Taken away, and their generators given back.")
            end
        end, { id = "animals-spawn", open = false })

        ui.section("The game's behaviour trees", function()
            animals.tree = ui.choice("Tree", animals.tree, Game.ai.TREES)
            ui.field("Its blackboard", show(Game.ai.treeBlackboard(animals.tree)))
            local nodes = P.cached("animals.tree." .. animals.tree, 60, function() return Game.ai.treeNodes(animals.tree) end) or {}
            P.pager(ui, "animals-tree", nodes, function(n)
                local s = {}
                for _, kv in ipairs(n.settings or {}) do s[#s + 1] = tostring(kv.name) .. " " .. tostring(kv.value) end
                ui.field(string.rep("   ", math.max(0, (n.depth or 1) - 1)) .. tostring(n.name), string.format("%s, %s%s",
                         tostring(n.role), tostring(n.kind), #s > 0 and ("; " .. table.concat(s, ", ")) or ""))
            end, { size = 20 })
            ui.note("A tree read as data (Game.ai.treeNodes): each node after the decorators that guard it.")
        end, { id = "animals-trees-all", open = false })
    end, { order = 24, group = "world" })

    -- ---------- Walking cats ----------
    local walk = { radius = 8000 }
    -- Four points round your cat, `r` cm out: a path to walk round and round.
    local function square(r)
        local h = P.here()
        if not h then return nil end
        return { { X = h.X + r, Y = h.Y, Z = h.Z }, { X = h.X, Y = h.Y + r, Z = h.Z }, { X = h.X - r, Y = h.Y, Z = h.Z },
                 { X = h.X, Y = h.Y - r, Z = h.Z } }
    end
    Menu.page("Walking cats", function(ui)
        ui.heading("Walking cats")
        if not P.needs(ui, "walkers") then return end
        if not Game.cat() then ui.text("Not in the world yet.") return end
        ui.note("The clan cats walking about (the game's and mods' own) and their paths (Game.walkers), and their AI (Game.ai).")
        walk.radius = ui.slider("Within", walk.radius, 1000, 30000, { step = 1000, format = "%.0f cm" })
        -- (Their names are read with the list, twice a second, not each frame.)
        local list = P.cached("walkers." .. walk.radius, 0.5, function()
            local out = Game.walkers.near(walk.radius) or {}
            for _, w in ipairs(out) do
                local c = Game.valid(w.actor) and Game.cat(w.actor)
                w.name = c and c:name() or nil
            end
            return out
        end) or {}
        local labels, chosen, now = { "(none)" }, P.picked("walkers", list), "(none)"
        for i, w in ipairs(list) do
            labels[#labels + 1] = string.format("%d. %s", i, w.name or "a clan cat")
            if w == chosen then now = labels[#labels] end
        end
        local want = ui.choice("Pick one", now, labels)
        if want ~= now then
            local i = tonumber(want:match("^(%d+)%."))
            chosen = i and list[i] or nil
            P.pick("walkers", chosen and chosen.actor)
        end
        P.said(ui, "walkers")
        if chosen and Game.valid(chosen.actor) then
            local a = chosen.actor
            ui.columns({ { "Walking", show(chosen.walking) }, { "Path", string.format("%d points, %s", #(chosen.points or {}),
                         chosen.loop and "round and round" or "there and back") }, { "A mod's path", show(chosen.modPath) },
                         { "Away", string.format("%.0f m", chosen.distance / 100) } })
            local hit = ui.buttons({ chosen.walking and "Stop" or "Walk on", "Its own path back", "Walk round you", "There and back to you" })
            if hit == 1 then
                if chosen.walking then P.result("walkers", "It stands where it is.", Game.walkers.stop(a))
                else P.result("walkers", "It walks on along its path.", Game.walkers.walkAgain(a)) end
            elseif hit == 2 then P.result("walkers", "It has its own path again.", Game.walkers.ownPath(a))
            elseif hit == 3 then
                P.result("walkers", "It walks a square round where you stand.", Game.walkers.walkPath(a, square(400), { loop = true, speed = 100 }))
            elseif hit == 4 then
                local c, h = Game.cat(a), P.here()
                local l = c and c:location()
                if l and h then P.result("walkers", "It walks to you and back.", Game.walkers.walkPath(a, { l, h }, { loop = false }))
                else P.say("walkers", "Couldn't: " .. (h and "where it stands can't be read" or "your cat isn't in the world")) end
            end
            if hit then P.forget("walkers." .. walk.radius) end
            aiState(ui, a)
            aiControls(ui, a, "walkers", false)
            ui.section("Its blackboard", function() P.blackboardRows(ui, a, "walkers") end, { id = "walkers-bb", open = false })
            ui.section("Its trees", function() treeRows(ui, a, "walkers") end, { id = "walkers-trees", open = false })
            ui.note("A script's paths and stopped cats stay so after the script ends: give each its own path back first.")
        else
            ui.note("Pick one to stop it, give it a path or steer its AI.")
        end
        ui.section("The clans' cats in your save", function()
            if not P.has("clanCats") then ui.note("Needs a newer wcmods (Game.clanCats).") return end
            local cats = P.cached("clanCats", 10, Game.clanCats) or {}
            P.pager(ui, "walkers-clan", cats, function(c)
                ui.field(tostring(c.name or "?"), string.format("%s, %s%s", show(c.clan), show(c.role),
                         c.storyRoles and #c.storyRoles > 0 and ("; plays " .. table.concat(c.storyRoles, ", ")) or ""))
            end, { text = function(c) return tostring(c.name) .. " " .. tostring(c.clan) .. " " .. tostring(c.role) end })
            ui.note("Every cat the save keeps for your cat's game (NPCData), as of its last save (Game.clanCats).")
        end, { id = "walkers-clan", open = false })
    end, { order = 25, group = "world" })

    -- ---------- Your own cats ----------
    local made = { name = "Brindlemoon", title = "Elder", size = 0.9, eyes = 15, fur = "#8c919e", pattern = "#3a3d47",
                   markings = "#f2f2f7", nose = "#c98a92", paws = "#d9a0a8", line = "Good hunting.", icon = "talk" }
    local per = setmetatable({}, { __mode = "k" })   -- each cat's own label, prompt and line, by its Game.npcs object
    local ICONS = { "talk", "search", "barter", "freshkill", "trainer", "den", "outpost", "skirmish", "madcat",
                    "ThunderClan", "ShadowClan", "RiverClan", "WindClan" }
    local talking = nil   -- the cat whose line is in the dialogue box
    -- The cat picked, by its Game.npcs object, not its actor: a cat just made has no actor yet, and its actor changes
    -- when its level loads again.
    local pickedNpc = nil
    if P.has("npcs", "onInteract") then
        Game.npcs.onInteract(function(who)
            if who == nil then
                if talking then Game.dialogue.hide() talking = nil end
                return
            end
            local o = per[who]
            if o and o.line ~= "" and (not Game.dialogue.busy() or talking) and Game.dialogue.claim() then
                talking = who
                Game.dialogue.say(o.name, o.line)
            end
        end)
    end
    local function myCats()
        local out = {}
        for _, n in ipairs(Game.npcs.all()) do if not n.removed then out[#out + 1] = n end end
        return out
    end
    Menu.page("Your own cats", function(ui)
        ui.heading("Your own cats")
        if not P.needs(ui, "npcs", "spawn") then return end
        if not Game.cat() then ui.text("Not in the world yet.") return end
        ui.note("Cats of this page's own (Game.npcs): one of the game's walking cats with the colours you give it, kept in " ..
                "the world while the game runs, never in your save.")
        ui.section("Make one", function()
            made.name = ui.input("Name over its head", made.name)
            made.title = ui.input("Title under it", made.title)
            made.size = ui.slider("Size", made.size, 0.4, 1.2, { step = 0.05, format = "%.2f" })
            made.eyes = ui.number("Eye colour slot", made.eyes, { min = 0, max = 24, step = 1, whole = true })
            for _, k in ipairs({ "fur", "pattern", "markings", "nose", "paws" }) do made[k] = ui.color(words(k), made[k]) end
            made.line = ui.input("What it says when you talk to it", made.line)
            if ui.button("Put it by my cat", { kind = "primary" }) then
                local at, yaw = P.spot()
                local npc, why = Game.npcs.spawn({ at = at, yaw = yaw, size = made.size, eyes = math.floor(made.eyes),
                    colours = { fur = made.fur, pattern = made.pattern, markings = made.markings, nose = made.nose, paws = made.paws } })
                if npc then
                    per[npc] = { name = made.name, title = made.title, line = made.line, icon = made.icon }
                    if made.name ~= "" then npc:label({ name = made.name, title = made.title }) end
                    if made.line ~= "" then npc:prompt("Talk") end
                    npc:face()
                    pickedNpc = npc
                end
                P.result("npcs", "It's by your cat. Its look past the colours is made up each time it's spawned.", npc ~= nil, why)
            end
        end, { id = "npcs-make", open = true })
        local cats = myCats()
        local labels, chosen, now = { "(none)" }, nil, "(none)"
        for i, n in ipairs(cats) do
            labels[#labels + 1] = string.format("%d. %s", i, per[n] and per[n].name ~= "" and per[n].name or "a cat")
            if n == pickedNpc then chosen, now = n, labels[#labels] end
        end
        if not chosen then pickedNpc = nil end   -- (taken away)
        local want = ui.choice("Pick one", now, labels)
        if want ~= now then
            local i = tonumber(want:match("^(%d+)%."))
            chosen = i and cats[i] or nil
            pickedNpc = chosen
        end
        P.said(ui, "npcs")
        if not chosen then return end
        local o = per[chosen] or { name = "", title = "", line = "", icon = "talk" }
        per[chosen] = o
        ui.columns({ { "In the world", show(chosen:valid()) }, { "Away", chosen:distance() and string.format("%.0f m", chosen:distance() / 100) or "-" },
                     { "Walking", show(chosen:walking()) }, { "Last walk", show(chosen.walkResult) } })
        local h = P.here()
        local hit = ui.buttons({ "Face me", "Walk to me", "Stop", "Come here at once", "Walk round me", "Take it away" },
                               { kinds = { nil, nil, nil, nil, nil, "danger" } })
        if hit == 1 then chosen:face() P.say("npcs", "Facing you.")
        elseif hit == 2 and h then
            P.result("npcs", "Walking to you.", chosen:walkTo(h.X, h.Y, h.Z, { radius = 150, done = function(_, r) P.say("npcs", "Its walk ended: " .. tostring(r) .. ".") end }))
        elseif hit == 3 then chosen:stop() P.say("npcs", "Stopped.")
        elseif hit == 4 then
            local at = P.spot()
            if at then P.result("npcs", "Moved by you.", chosen:moveTo(at.X, at.Y, at.Z)) end
        elseif hit == 5 then P.result("npcs", "Walking round you.", Game.walkers.walkPath(chosen, square(400), { loop = true, speed = 100 }))
        elseif hit == 6 then chosen:remove() pickedNpc = nil P.say("npcs", "Taken away.") return end
        local a = chosen:actorOrNil()
        if a and P.has("ai", "follow") then
            local following = Game.ai.following(a)
            if ui.button(following and "Stop following you" or "Follow you about") then
                if following then P.result("npcs", "It stopped following you.", Game.ai.stopFollowing(a, false))
                else P.result("npcs", "It follows you about.", Game.ai.follow(a, Game.player(), { distance = 150 })) end
            end
        end
        ui.section("Its label, prompt, talk and map marker", function()
            o.name = ui.input("Name", o.name)
            o.title = ui.input("Title", o.title)
            o.extra = ui.input("Line above it (green)", o.extra or "")
            local lh = ui.buttons({ "Put the label on", "Take it off" })
            if lh == 1 then chosen:label({ name = o.name, title = o.title, extra = o.extra ~= "" and o.extra or nil, icon = "available" })
            elseif lh == 2 then chosen:label(nil) end
            o.line = ui.input("What it says", o.line)
            local ph = ui.buttons({ "Talk prompt on", "Prompt off" })
            if ph == 1 then chosen:prompt("Talk") elseif ph == 2 then chosen:prompt(nil) end
            ui.note("Walk up to it and press Interact: it says its line in the game's dialogue box (Game.npcs.onInteract, " ..
                    "Game.dialogue.say); Interact again puts the box away.")
            o.icon = ui.choice("Map marker", o.icon, ICONS)
            local mh = ui.buttons({ "Marker on", "Marker off" })
            if mh == 1 then chosen:mapMarker(o.icon) elseif mh == 2 then chosen:mapMarker(nil) end
        end, { id = "npcs-label", open = false })
        if a then ui.section("Its blackboard", function() P.blackboardRows(ui, a, "npcs") end, { id = "npcs-bb", open = false }) end
    end, { order = 26, group = "world" })
end
