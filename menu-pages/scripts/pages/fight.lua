-- Fight: both sides of a fight while you're in one.
return function(P)
    local Menu, THEME, words, itemName = P.Menu, P.THEME, P.words, P.itemName

    -- Extra drops. What a beaten animal gives comes from the game's character table, not from the
    -- fighter's own list (changing that list changes nothing), so the extra is handed out after the fight
    -- instead: a pickup by your cat holding as much again, once the fight is won.
    local extra = { items = {}, enemies = {}, note = nil }   -- enemies: actor address -> its health, last seen
    Game.every(0.5, function()
        local f = Game.fight()
        if f then
            for _, x in ipairs(f:enemies()) do
                local cat = x:cat()
                if cat then extra.enemies[tostring(cat.actor:GetAddress())] = cat:health() end
            end
            return
        end
        if next(extra.items) == nil then
            extra.enemies = {}
            return
        end
        if not (Game.cat() and Game.cat():location()) then return end   -- not back in the forest yet
        local won = next(extra.enemies) ~= nil
        for _, hp in pairs(extra.enemies) do won = won and hp ~= nil and hp <= 0 end
        if won then
            for tag, n in pairs(extra.items) do Game.items.drop(tag, n) end
            extra.note = "The extra drops are on the ground by your cat."
        else
            extra.note = "The fight wasn't won, so there are no extra drops."
        end
        extra.items, extra.enemies = {}, {}
    end)

    local function fighterRows(ui, x, enemy)
        local cat = x:cat()
        if not cat then return end
        local label = cat:name() or words(cat:kind() or "?")
        ui.text(label .. (enemy and ("   (" .. words(cat:kind() or "") .. ")") or ""), { color = THEME.heading })
        local hp, maxhp = cat:health(), cat:maxHealth()
        if hp and maxhp and maxhp > 0 then
            ui.progress("Health", hp / maxhp, { color = "#e06c6c", format = string.format("%.0f / %.0f", hp, maxhp) })
        end
        local cs, maxcs = cat:combatStamina(), cat:maxCombatStamina()
        if cs and maxcs and maxcs > 0 then
            ui.progress("Stamina", cs / maxcs, { color = "#6cc58a", format = string.format("%.0f / %.0f", cs, maxcs) })
        end
        local st = x:stats()
        ui.columns({ { "Level", x:level() }, { "Stance", x:stance() or "?" }, { "Prowess", st.Prowess }, { "Strength", st.Strength },
                     { "Resilience", st.Resilience }, { "Instinct", st.Instinct }, { "Agility", st.Agility } })
        local move = x:moveTag()
        if move and move ~= "None" and move ~= "" then ui.field("Move", (move:gsub("^Gameplay%.Combat%.Attack%.", ""))) end
        local hit = ui.buttons({ "Heal", "Weaken", "Cure status" }, { kinds = { "good", "danger" } })
        if hit == 1 then cat:heal()
        elseif hit == 2 then cat:setHealth(1)
        elseif hit == 3 then cat:clearStatus() end
        if enemy then
            local drops = cat:rewards()
            local parts = {}
            for tag, n in pairs(drops) do parts[#parts + 1] = string.format("%d %s", n, itemName(tag)) end
            if #parts > 0 then
                ui.field("Drops", table.concat(parts, ", "))
                if ui.button("Double what it drops") then
                    for tag, n in pairs(drops) do extra.items[tag] = (extra.items[tag] or 0) + n end
                end
            end
        end
        ui.space(6)
    end
    Menu.page("Fight", function(ui)
        ui.heading("Fight")
        local f = Game.fight()
        if not f then
            if extra.note then ui.note(extra.note) end
            ui.text("No fight now. During one, this page shows both sides (health, stamina, stats, stance and moves) and " ..
                    "lets you heal or weaken them.")
            ui.note("The game's own switches for fights (attacks that always land, a forced difficulty) are on Game switches.")
            return
        end
        local more = {}
        for tag, n in pairs(extra.items) do more[#more + 1] = string.format("%d %s", n, itemName(tag)) end
        if #more > 0 then ui.note("Extra drops if you win (by your cat after the fight): " .. table.concat(more, ", ")) end
        local order = {}
        for _, c in ipairs(f:turnOrder()) do order[#order + 1] = c:name() or words(c:kind() or "?") end
        local cur = f:current()
        ui.columns({ { "Fight", words((f:kind() or ""):gsub("^BP_", ""):gsub("_C$", "")) }, { "Turn order", table.concat(order, ", ") },
                     { "Whose turn", cur and (cur:name() or words(cur:kind() or "?")) or "?" } })
        ui.section("Your side", function()
            for _, x in ipairs(f:players()) do fighterRows(ui, x, false) end
        end, { id = "fight-players", open = true })
        ui.section("Against you", function()
            for _, x in ipairs(f:enemies()) do fighterRows(ui, x, true) end
        end, { id = "fight-enemies", open = true })
        ui.note("Damage comes from the move, both fighters' stats and levels, and the stances.")
    end, { order = 40, group = "fight" })
end
