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
                     { "Time", P.timeText(s) or "?" }, { "Fresh-kill pile", P.pileText(s) or "?" } })
        local tracked = Game.quests.tracked()
        local followed = nil
        if tracked then followed = P.questTitle(Game.quests.describe(tracked)) end
        ui.field("Following", followed or "no quest")
        if s.fight then ui.text("You're in a fight. The Fight page has both sides.", { color = THEME.heading }) end
        local hit = ui.buttons({ "Heal", "Full stamina", "Morning", "Evening" }, { kinds = { "good" } })
        if hit == 1 then s.cat:heal()
        elseif hit == 2 and s.maxst then s.cat:setStamina(s.maxst)
        elseif hit == 3 then P.setTime(7, 0)
        elseif hit == 4 then P.setTime(19, 0) end
        if hit then refresh() end
    end, { order = 1, group = "home" })

    -- Traits come from the last save, which takes reading and decoding the whole save file: every ten
    -- seconds is plenty.
    local traits = { at = -1, text = "" }
    -- A number box's options with its range stretched to take the value it shows: a box clamps a value
    -- outside its range, and that would look like you changing it (and write the clamped value to the game).
    -- It stretches past the value to the next power of two, so there's room to raise it too. Each box keeps
    -- its range (by its label) while the value is the one the box gave back (gave, after the box): a range
    -- worked out again from each value written would double with each drag to the top, and a box whose range
    -- changes goes back to the game's value mid-drag. When the game or a script changes the value, the range
    -- is worked out again, so it comes back down too. (wcmods' own number box does the same from #112 on.)
    local ranges = {}
    Game.on("player", function() traits.at, ranges = -1, {} end)   -- another cat (another save)
    local function around(label, v, lo, hi, opts)
        local r = ranges[label]
        if not r or r.lo0 ~= lo or r.hi0 ~= hi
           or (r.gave and math.abs(r.gave - v) > math.max(1e-3, math.abs(v) * 1e-6)) then   -- (a float's rounding)
            r = { lo0 = lo, hi0 = hi, lo = lo, hi = hi }
            ranges[label] = r
        end
        if v > r.hi then r.hi = 2 ^ (math.floor(math.log(v, 2)) + 1) end
        if v < r.lo then r.lo = v < 0 and -2 ^ (math.floor(math.log(-v, 2)) + 1) or 0 end
        opts.min, opts.max = r.lo, r.hi
        return opts
    end
    local function gave(label, v)
        if ranges[label] then ranges[label].gave = v end
        return v
    end

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
        if traits.at < 0 or os.clock() - traits.at > 10 then traits.at, traits.text = os.clock(), table.concat(cat:traits(), ", ") end
        ui.columns({ { "Name", s.name or "?" }, { "Clan", s.clan or "?" }, { "Rank", s.rank or "?" }, { "Traits", traits.text } })
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
            local r = gave("regen", ui.number("Stamina back per second", regen, around("regen", regen, 0, 500, { step = 1 })))
            if changed(r, regen) then cat:setStaminaRegen(r) end
        end
        ui.field("Fight stamina", string.format("%s (0.4 x Prowess + Stamina)", tostring(cat:maxCombatStamina())))
        local scale = cat:scale()
        if scale and P.sizeHeld and P.sizeHeld() then
            -- The Cheats page's Cat size puts the size back each second, so a slider here would be undone.
            ui.field("Size", string.format("x%.2f   (Cat size on the Cheats page holds it)", scale))
        elseif scale then
            local size = ui.slider("Size", scale, 0.25, 4, { step = 0.05, format = "x%.2f" })
            if changed(size, scale) then cat:setScale(size) end
        end
        -- The level is a whole number in the game; experience and the stats are fractional (FloatProperty), so
        -- their boxes aren't whole-number ones: a whole-number box rounds what it shows, which reads as a
        -- change and would write the rounded value back to your cat just by opening this page.
        ui.section("Level and experience", function()
            local lv = gave("level", ui.number("Level", s.level or 1, around("level", s.level or 1, 1, 20, { step = 1, whole = true })))
            if changed(lv, s.level) then cat:setLevel(math.floor(lv + 0.5)) refresh() end
            if s.xpNeeded and s.xpNeeded > 0 then
                local xp = gave("xp", ui.number("Experience", s.xp or 0, around("xp", s.xp or 0, 0, s.xpNeeded, { step = 10 })))
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
                    local nv = gave("stat " .. name, ui.number(name, v, around("stat " .. name, v, 0, 2000, { step = 1 })))
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
