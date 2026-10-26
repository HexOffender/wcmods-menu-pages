-- Story: Quests, the game's and mods' own.
return function(P)
    local Menu, questTitle, STATUS_TEXT = P.Menu, P.questTitle, P.STATUS_TEXT

    local questView = { filter = "Active" }
    local FILTER = { Active = { OngoingQuest = true, QuestComplete = true, DialogueProgress = true }, Available = { QuestAvailable = true },
                     Done = { QuestTurnedIn = true } }
    Menu.page("Quests", function(ui)
        ui.heading("Quests")
        if not Game.cat() then
            ui.text("Not in the world yet.")
            return
        end
        local tracked = Game.quests.tracked()
        ui.section("The quest you follow", function()
            if not tracked then
                ui.text("You aren't following a quest. Follow one below, or in the game's quest log.")
                return
            end
            local q = Game.quests.describe(tracked)
            ui.columns({ { "Quest", questTitle(q) }, { "State", STATUS_TEXT[q.status] or q.status or "?" }, { "Kind", q.type or "?" } })
            for i, o in ipairs(Game.quests.objectives(tracked)) do
                local label = string.format("Objective %d", i)
                local progress = (o.target and o.target > 0) and string.format("%d / %d", o.current or 0, o.target) or ""
                ui.field(label, (o.status or "?") .. (progress ~= "" and ("   " .. progress) or ""))
                if o.point and ui.button("Go to objective " .. i) then P.jump(Game.cat(o.point):location(), "the objective") end
            end
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
        local own = Game.quests.reported()
        for _, q in ipairs(own) do
            if questView.filter == "All" or (MOD_FILTER[questView.filter] or {})[q.status] then
                n = n + 1
                local now = q.status == "active" and q.objective ~= "" and
                    (q.objective .. (q.progress ~= "" and ("   " .. q.progress) or "")) or (MOD_STATUS[q.status] or q.status)
                ui.field(q.title, now)
            end
        end
        if n == 0 then ui.note("None.") end
        ui.note(string.format("%d quests in all. Their titles are the game's own, for your cat's rank.", #list) ..
                (#own > 0 and string.format(" %d more from mods.", #own) or ""))
    end, { order = 30, group = "story" })
end
