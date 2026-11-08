-- Story: Quests (the game's and mods' own), Scenes, Talk and Bonds (Game.quests, Game.scenes, Game.dialogue; the
-- C++ part plays scenes and talks and reads and sets bonds).
return function(P)
    local Menu, questTitle, STATUS_TEXT, show, words = P.Menu, P.questTitle, P.STATUS_TEXT, P.show, P.words

    local questView = { filter = "Active", tag = "", alias = "" }
    local FILTER = { Active = { OngoingQuest = true, QuestComplete = true, DialogueProgress = true }, Available = { QuestAvailable = true },
                     Done = { QuestTurnedIn = true } }
    local own = { title = "A quest of Menu pages' own", status = "active", objective = "Try every page", progress = "1 / 3",
                  description = "Reported with Game.quests.report: it shows here and on any page that reads Game.quests.reported." }
    Menu.page("Quests", function(ui)
        ui.heading("Quests")
        if not Game.cat() then
            ui.text("Not in the world yet.")
            return
        end
        local tracked = Game.quests.tracked()
        P.said(ui, "quests")
        ui.section("The quest you follow", function()
            if not tracked then
                ui.text("You aren't following a quest. Follow one below, or in the game's quest log.")
                return
            end
            local q = Game.quests.describe(tracked)
            ui.columns({ { "Quest", questTitle(q) }, { "State", STATUS_TEXT[q.status] or q.status or "?" }, { "Kind", q.type or "?" },
                         { "Story id", show(q.alias) } })
            -- (Compared by address: two of UE4SS's handles on one object needn't be equal as Lua values.)
            local current = P.has("quests", "current") and P.addr(Game.quests.current(tracked)) or nil
            for i, o in ipairs(P.objectives(tracked)) do
                local isNow = current ~= nil and current == P.addr(o.objective)
                local label = string.format("Objective %d%s", i, isNow and " (now)" or "")
                local progress = (o.target and o.target > 0) and string.format("%d / %d", o.current or 0, o.target) or ""
                ui.field(label, (o.status or "?") .. (progress ~= "" and ("   " .. progress) or ""))
                if o.point and ui.button("Go to objective " .. i) then
                    local point = Game.cat(o.point)   -- (nil once the game has unloaded it)
                    if point then P.jump(point:location(), "the objective") end
                end
                for _, t in ipairs(o.targets or {}) do
                    ui.field("   " .. P.itemName(t.tag or "?"), string.format("%s / %s, %d out in the world", show(t.current), show(t.target), #(t.actors or {})))
                    local a = t.actors and t.actors[1]
                    if a and Game.valid(a) and P.has("quests", "collect") and ui.button("Collect one " .. P.itemName(t.tag or "?")) then
                        P.result("quests", "Collecting: your cat goes to it and back.", Game.quests.collect(a))
                        P.questsChanged()
                    end
                end
                if isNow and P.has("quests", "finishObjective") then
                    local hit = ui.buttons({ "Finish objective " .. i, "Fail it" }, { kinds = { "good", "danger" } })
                    if hit then
                        P.result("quests", hit == 1 and "Finished: the quest goes on." or "Failed.", Game.quests.finishObjective(o.objective, hit == 1))
                        P.questsChanged()
                    end
                end
            end
            if ui.button("Stop following it") then Game.quests.track(tracked, false) P.questsChanged() end
        end, { id = "quests-tracked", open = true })
        questView.filter = ui.radio("Show", questView.filter, { "Active", "Available", "Done", "All" })
        local list, n = P.quests(), 0
        for _, q in ipairs(list) do
            if questView.filter == "All" or (FILTER[questView.filter] or {})[q.status or ""] then
                n = n + 1
                ui.field(questTitle(q), STATUS_TEXT[q.status] or q.status or "?")
                if FILTER.Active[q.status or ""] and not q.tracked and ui.button("Follow " .. questTitle(q)) then
                    Game.quests.track(q.quest, true)
                    P.questsChanged()
                end
            end
        end
        -- Mods' own quests (Game.quests.report), filtered the same way.
        local MOD_FILTER = { Active = { active = true }, Available = { available = true }, Done = { done = true } }
        local MOD_STATUS = { active = "in progress", available = "available", done = "done" }
        local reported = Game.quests.reported()
        for _, q in ipairs(reported) do
            if questView.filter == "All" or (MOD_FILTER[questView.filter] or {})[q.status] then
                n = n + 1
                local now = q.status == "active" and q.objective ~= "" and
                    (q.objective .. (q.progress ~= "" and ("   " .. q.progress) or "")) or (MOD_STATUS[q.status] or q.status)
                ui.field(q.title, now)
            end
        end
        if n == 0 then ui.note("None.") end
        ui.note(string.format("%d quests in all. Their titles are the game's own, for your cat's rank.", #list) ..
                (#reported > 0 and string.format(" %d more from mods.", #reported) or ""))

        ui.section("Start or hand out a quest", function()
            ui.note("The quest manager's own StartQuestOfTag and GiveQuestOfTag, by a quest graph's tag. They can move the " ..
                    "story on: back up your save first.")
            questView.tag = ui.input("Quest tag", questView.tag, { hint = "Quest.Procedural.Survival.Gather" })
            local hit = ui.buttons({ "Start it", "Hand it out" }, { kinds = { "danger", "danger" } })
            if hit and questView.tag ~= "" then
                P.result("quests", hit == 1 and "Started." or "Handed out.", (hit == 1 and Game.quests.start or Game.quests.give)(questView.tag))
                P.questsChanged()
            end
            local tags, seen = {}, {}
            for _, q in ipairs(list) do
                if q.tag and not seen[q.tag] then seen[q.tag] = true tags[#tags + 1] = q.tag end
            end
            table.sort(tags)
            P.pager(ui, "quests-tags", tags, function(t)
                if ui.button("Use " .. t) then questView.tag = t end
            end, { text = function(t) return t end, size = 8 })
        end, { id = "quests-start", open = false })

        ui.section("A quest by its story id", function()
            questView.alias = ui.input("Story id", questView.alias, { hint = "Quest.Main.1" })
            if questView.alias ~= "" then
                ui.columns({ { "State", show(Game.quests.status(questView.alias)) }, { "Result", show(Game.quests.result(questView.alias)) },
                             { "Successes", show(Game.quests.successes(questView.alias)) } })
            end
            ui.field("Chapter", show(Game.quests.chapter()))
            ui.note("The game keeps a quest's progress by its story id (alias). An id no quest has reads nil: asking the " ..
                    "game itself would add it to the save.")
        end, { id = "quests-alias", open = false })

        ui.section("A quest of this page's own", function()
            own.title = ui.input("Title", own.title)
            own.status = ui.radio("Its state", own.status, { "available", "active", "done" })
            own.objective = ui.input("Objective", own.objective)
            own.progress = ui.input("Progress", own.progress)
            own.description = ui.input("About it", own.description)
            local hit = ui.buttons({ "Report it", "Take it off" })
            if hit == 1 then
                Game.quests.report("menu-pages-own", { title = own.title, status = own.status, objective = own.objective,
                                   progress = own.progress, by = "Menu pages", description = own.description })
            elseif hit == 2 then Game.quests.report("menu-pages-own", nil) end
            ui.note("Game.quests.report lists a mod's own quest on this page, for any script to read with Game.quests.reported.")
        end, { id = "quests-own", open = false })
    end, { order = 30, group = "story" })

    -- ---------- Scenes ----------
    local scenes = { kind = "All", rate = 1, length = 0, pause = false }
    Menu.page("Scenes", function(ui)
        ui.heading("Scenes")
        if not P.needs(ui, "scenes") then return end
        local playing = Game.scenes.playing() or {}
        ui.columns({ { "Playing now", #playing > 0 and table.concat(playing, ", ") or "none" },
                     { "Your cat has seen", table.concat(Game.scenes.seen() or {}, ", ") } })
        if ui.button("Skip the scene playing") then
            P.result("scenes", "Skipping (the skip button held for 2.5 s).", Game.scenes.skip(), "no scene the game lets you skip is playing")
        end
        P.said(ui, "scenes")
        local list = P.cached("scenes.list", 30, Game.scenes.list) or {}
        local kinds, seenKind = { "All" }, {}
        for _, s in ipairs(list) do
            if s.kind and not seenKind[s.kind] then seenKind[s.kind] = true kinds[#kinds + 1] = s.kind end
        end
        scenes.kind = ui.radio("Kind", scenes.kind, kinds)
        local canPlay = P.cpp() ~= nil
        if canPlay then
            scenes.rate = ui.slider("Rate", scenes.rate, 0.25, 4, { step = 0.25, format = "x%.2f" })
            scenes.length = ui.number("Or last this many seconds (0: its own)", scenes.length, { min = 0, max = 600, step = 1 })
            scenes.pause = ui.toggle("Hold its last frame until skipped", scenes.pause)
        else
            ui.note("Playing a scene is the C++ part's play_scene (the game's call for it is native). " .. P.CPP_HELP)
        end
        local shown = {}
        for _, s in ipairs(list) do
            if scenes.kind == "All" or s.kind == scenes.kind then shown[#shown + 1] = s end
        end
        P.pager(ui, "scenes-list", shown, function(s)
            local label = string.format("%s  (%s, %s%s)", tostring(s.tag):gsub("^Gameplay%.", ""), show(s.kind), show(s.sequence),
                                        s.hidesHud and ", hides the HUD" or "")
            if canPlay then
                if ui.button("Play " .. label) then
                    P.result("scenes", "Playing " .. tostring(s.tag) .. ".", P.callCpp("play_scene", s.tag,
                             { rate = scenes.rate, length = scenes.length > 0 and scenes.length or nil, pause_at_end = scenes.pause }))
                end
            else
                ui.field(tostring(s.tag), label)
            end
        end, { text = function(s) return tostring(s.tag) .. " " .. tostring(s.sequence) end, size = 12 })
        ui.note("A story scene is only the film: what the game does round it (marking it seen, the ceremony after) isn't run. " ..
                "The fight cameras (Combat) are a fight's own.")
    end, { order = 31, group = "story" })

    -- ---------- Talk ----------
    local talk = { name = "Brindlemoon", line = "Good hunting.", tag = "", time = 1, npc = "", read = nil }
    Menu.page("Talk", function(ui)
        ui.heading("Talk")
        if not P.needs(ui, "dialogue") then return end
        P.said(ui, "talk")
        ui.section("The game's dialogue box", function()
            ui.columns({ { "Showing", show(Game.dialogue.showing()) }, { "Another mod's cat is talking", show(Game.dialogue.busy()) } })
            talk.name = ui.input("Who says it", talk.name)
            talk.line = ui.input("The line", talk.line)
            local hit = ui.buttons({ "Say it", "Put the box away", "Take the box for this page" })
            if hit == 1 then P.result("talk", "Said.", Game.dialogue.say(talk.name, talk.line))
            elseif hit == 2 then Game.dialogue.hide()
            elseif hit == 3 then P.result("talk", "The box is this page's while it's up.", Game.dialogue.claim(), "another mod's cat has it") end
            ui.note("Game.dialogue: the box is only the picture. While it's up your cat is \"in a talk\": no animal notices it.")
        end, { id = "talk-box", open = true })
        ui.section("The game's own talks", function()
            if not P.needCpp(ui) then return end
            local st = P.callCpp("talk_state") or {}
            ui.columns({ { "Playing", show(st.playing) }, { "Speaker", show(st.speaker) }, { "Line", show(st.line) } })
            local answers = st.answers or {}
            if #answers > 0 then
                local labels = {}
                for i, a in ipairs(answers) do labels[i] = show(a) end
                local hit = ui.buttons(labels)
                if hit then P.result("talk", "Answered.", P.callCpp("talk_next", hit)) end   -- (answers count from 1)
            end
            local hit = ui.buttons({ "Next line", "Stop the talk" })
            if hit == 1 then P.result("talk", "On.", P.callCpp("talk_next"))
            elseif hit == 2 then P.result("talk", "Stopped.", P.callCpp("hide_talk")) end
            talk.npc = ui.input("The cat talked to (its name in the box)", talk.npc)
            ui.separator()
            talk.tag = ui.input("A story talk's tag", talk.tag, { hint = "Gameplay.Dialogue.Story.Short.TheMistrustfulLeader.Main.7" })
            talk.time = ui.number("The time you have it (1 the first)", talk.time, { min = 1, max = 9, step = 1, whole = true })
            local sh = ui.buttons({ "Read the story talk", "Play it" })
            if sh == 1 and talk.tag ~= "" then talk.read = P.callCpp("story_talk", talk.tag, math.floor(talk.time))
            elseif sh == 2 and talk.tag ~= "" then
                P.result("talk", "Playing. Its bond answers move your bonds as the game's talks do.",
                         P.callCpp("play_story_talk", talk.tag, math.floor(talk.time), talk.npc ~= "" and talk.npc or nil))
            end
            local tags = P.cached("talk.tags", 60, function() return P.callCpp("conversation_tags") end) or {}
            P.pager(ui, "talk-tags", tags, function(t)
                local h = ui.buttons({ t, "Read", "Play" })
                if h == 1 then talk.tag = t
                elseif h == 2 then talk.read = P.callCpp("read_talk", t)
                elseif h == 3 then P.result("talk", "Playing " .. t .. ".", P.callCpp("play_conversation", t, talk.npc ~= "" and talk.npc or nil)) end
            end, { text = function(t) return t end, size = 10, label = "Find a talk" })
            if type(talk.read) == "table" then
                ui.text(string.format("%s: %d lines", show(talk.read.tag), #(talk.read.nodes or {})), { color = P.THEME.heading })
                P.pager(ui, "talk-read", talk.read.nodes or {}, function(n)
                    local a = {}
                    for _, x in ipairs(n.answers or {}) do a[#a + 1] = show(x.words) end
                    ui.field(string.format("%s. %s", show(n.index), show(n.speaker)), show(n.words) ..
                             (#a > 0 and ("  [" .. table.concat(a, " | ") .. "]") or "") .. (n.action and ("  (" .. show(n.action) .. ")") or ""))
                end, { size = 10 })
            end
        end, { id = "talk-game", open = false })
    end, { order = 32, group = "story" })

    -- ---------- Bonds ----------
    local bonds = { prefix = "", role = "", node = "" }
    Menu.page("Bonds", function(ui)
        ui.heading("Bonds")
        ui.note("Your cat's bonds with the clans and the story cats, through the game's own bond code (the C++ part's Bonds.hpp).")
        if not P.needCpp(ui) then return end
        if not Game.cat() then ui.text("Not in the world yet.") return end
        P.said(ui, "bonds")
        local list = P.cached("bonds", 1, function() return P.callCpp("bonds") end) or {}
        for _, b in ipairs(list) do
            local label = (b.cat_name and b.cat_name ~= "" and (b.cat_name .. ", ") or "") .. tostring(b.key)
            ui.field(label, string.format("%s, %s (base %s)", show(b.value), show(b.rank), show(b.base)))
            if type(b.value) == "number" then
                local nv = ui.number("Set " .. label, b.value, { min = 0, max = 100, step = 1, whole = true })
                if nv ~= b.value then
                    P.result("bonds", label .. " set.", P.callCpp("set_bond", b.key, math.floor(nv)))
                    P.forget("bonds")
                end
            end
        end
        if #list == 0 then ui.note("No bonds read (in a menu, or wcmods hasn't got the game's bond code on this build).") end
        ui.section("Ranks and roles", function()
            ui.text(show(P.cached("bonds.t", 30, function() return P.callCpp("bond_thresholds") end)))
            local roles = P.cached("bonds.roles", 60, function() return P.callCpp("bond_roles") end) or {}
            P.pager(ui, "bonds-roles", roles, function(r)
                local b = P.cached("bonds.role." .. r, 2, function() return P.callCpp("bond", r) end)
                ui.field(r, type(b) == "table" and string.format("%s, %s", show(b.value), show(b.rank)) or show(b))
            end, { text = function(r) return r end, size = 10 })
        end, { id = "bonds-roles", open = false })
        ui.section("The talk tables' rows", function()
            bonds.prefix = ui.input("Rows starting with", bonds.prefix, { hint = "e.g. Bonding" })
            local rows = bonds.prefix ~= "" and P.cached("bonds.rows." .. bonds.prefix, 5, function() return P.callCpp("talk_rows", bonds.prefix, 200) end) or {}
            P.pager(ui, "bonds-rows", rows or {}, function(r)
                local fields = {}
                for k, v in pairs(r) do if k ~= "name" then fields[#fields + 1] = k .. " " .. show(v) end end
                table.sort(fields)
                if ui.button(tostring(r.name)) then bonds.node = tostring(r.name) end
                ui.note(table.concat(fields, ", "))
            end, { size = 8 })
            bonds.node = ui.input("A bond answer's row", bonds.node)
            bonds.role = ui.input("The story cat talked to (its role, or empty)", bonds.role)
            if bonds.node ~= "" then ui.field("Given already", show(P.callCpp("bond_node", bonds.node))) end
            if ui.button("Give that answer", { kind = "danger" }) and bonds.node ~= "" then
                local r, why = P.callCpp("answer_bond", bonds.node, bonds.role)
                P.result("bonds", "Given: " .. show(r), r ~= nil, why)
                P.forget("bonds")
            end
        end, { id = "bonds-rows", open = false })
    end, { order = 33, group = "story" })
end
