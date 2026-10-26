-- Home: At a glance, and Your cat: Stats.
return function(P)
    local Menu, THEME, now, refresh, changed = P.Menu, P.THEME, P.now, P.refresh, P.changed

    Menu.page("At a glance", function(ui)
        ui.heading("At a glance")
        local s = now()
        if not s.cat then
            ui.text("Not in the world yet. The pages about your cat and the world fill in once you're playing.")
            return
        end
        ui.columns({ { "Cat", s.name or "?" }, { "Clan", s.clan or "?" }, { "Level", s.level }, { "Rank", s.rank or "?" } })
        if s.hp and s.maxhp and s.maxhp > 0 then
            ui.progress("Health", s.hp / s.maxhp, { color = "#e06c6c", format = string.format("%.0f / %.0f", s.hp, s.maxhp) })
        end
        if s.st and s.maxst and s.maxst > 0 then
            ui.progress("Stamina", s.st / s.maxst, { color = "#6cc58a", format = string.format("%.0f / %.0f", s.st, s.maxst) })
        end
        if s.xpNeeded and s.xpNeeded > 0 then
            ui.progress("Experience", (s.xp or 0) / s.xpNeeded, { format = string.format("%.0f / %.0f", s.xp or 0, s.xpNeeded) })
        else
            ui.field("Experience", s.level == 20 and "top level" or tostring(s.xp or "?"))
        end
        ui.columns({ { "Territory", s.territory or "?" }, { "Area", s.area or "(shows once you cross into one)" },
                     { "Time", s.h and string.format("%02d:%02d", s.h, s.m or 0) or "?" },
                     { "Fresh-kill pile", s.fk and string.format("%.0f, %s", s.fk, s.fkLevel or "?") or "?" } })
        local tracked = Game.quests.tracked()
        local followed = nil
        if tracked then followed = P.questTitle(Game.quests.describe(tracked)) end
        ui.field("Following", followed or "no quest")
        if s.fight then ui.text("You're in a fight. The Fight page has both sides.", { color = THEME.heading }) end
        local hit = ui.buttons({ "Heal", "Full stamina", "Morning", "Evening" }, { kinds = { "good" } })
        if hit == 1 then s.cat:heal()
        elseif hit == 2 and s.maxst then s.cat:setStamina(s.maxst)
        elseif hit == 3 then Game.time.set(7, 0)
        elseif hit == 4 then Game.time.set(19, 0) end
        if hit then refresh() end
    end, { order = 1, group = "home" })

    Menu.page("Stats", function(ui)
        ui.heading("Your cat")
        local s = now()
        local cat = s.cat
        if not cat then
            ui.text("Not in the world yet.")
            return
        end
        ui.note("Live values. A change applies at once and lasts until the game changes it again (a level-up, a fight, " ..
                "loading); the game saves what it holds at its next save.")
        ui.columns({ { "Name", s.name or "?" }, { "Clan", s.clan or "?" }, { "Rank", s.rank or "?" },
                     { "Traits", table.concat(cat:traits(), ", ") } })
        if s.hp and s.maxhp then
            local hp = ui.slider("Health", s.hp, 0, s.maxhp, { step = 1, format = "%.0f", color = "#e06c6c" })
            if changed(hp, s.hp) then cat:setHealth(hp) refresh() end
        end
        if s.st and s.maxst then
            local st = ui.slider("Stamina", s.st, 0, s.maxst, { step = 1, format = "%.0f", color = "#6cc58a" })
            if changed(st, s.st) then cat:setStamina(st) refresh() end
        end
        local regen = cat:staminaRegen()
        if regen then
            local r = ui.number("Stamina back per second", regen, { min = 0, max = 500, step = 1 })
            if changed(r, regen) then cat:setStaminaRegen(r) end
        end
        ui.field("Fight stamina", string.format("%s (0.4 x Prowess + Stamina)", tostring(cat:maxCombatStamina())))
        local scale = cat:scale()
        if scale then
            local size = ui.slider("Size", scale, 0.25, 4, { step = 0.05, format = "x%.2f" })
            if changed(size, scale) then cat:setScale(size) end
        end
        ui.section("Level and experience", function()
            local lv = ui.number("Level", s.level or 1, { min = 1, max = 20, step = 1, whole = true })
            if changed(lv, s.level) then cat:setLevel(math.floor(lv + 0.5)) refresh() end
            if s.xpNeeded and s.xpNeeded > 0 then
                local xp = ui.number("Experience", s.xp or 0, { min = 0, max = s.xpNeeded, step = 10, whole = true })
                if changed(xp, s.xp) then cat:setXp(xp) refresh() end
                ui.field("Needed for the next level", string.format("%.0f", s.xpNeeded))
            end
        end, { id = "stats-level", open = true })
        ui.section("Stats", function()
            ui.note("Kept with the level; a level-up works them out again from the growth tables. Prowess is health.")
            local stats = cat:stats() or {}
            for _, name in ipairs(Game.statNames) do
                local v = stats[name]
                if v then
                    local nv = ui.number(name, v, { min = 0, max = 2000, step = 1, whole = true })
                    if changed(nv, v) then cat:setStat(name, nv) end
                end
            end
        end, { id = "stats-stats", open = true })
        ui.section("Looks", function()
            local look = cat:customization() or {}
            ui.columns({ { "Body", look.BodyValue }, { "Ears", look.EarIdx }, { "Face", look.FaceValue }, { "Tail", look.TailIdx } })
            ui.columns({ { "Coat colour", look.FurColorIdx }, { "Pattern", look.PatternIdx }, { "Markings", look.MarkingIdx },
                         { "Eyes", tostring(look.EyeLeftColorIdx) .. " / " .. tostring(look.EyeRightColorIdx) } })
            ui.note("Your cat's colours have a page of their own when the colours mod is on (Colours).")
        end, { id = "stats-looks", open = false })
    end, { order = 10, group = "cat" })
end
