-- Fight: both sides of a fight while you're in one, your cat's turns, and starting one (Game.fight, Game.fighter,
-- Game.combat; the C++ part's fighter moves with their damage, the fight AI's chances and its own auto fight).
return function(P)
    local Menu, THEME, words, itemName, show = P.Menu, P.THEME, P.words, P.itemName, P.show

    -- A fighter's cat by its actor, or nil. Not x:cat() or f:current(): on wcmods 0.5.0 and older Game.cat(nil) is
    -- your own cat, so a fighter whose body can't be read (or no one's turn) would show as you, and Weaken would hit you.
    local function catAt(actor) return actor and Game.cat(actor) or nil end
    local function catOf(x) return catAt(x:actor()) end

    -- Extra drops. What a beaten animal gives comes from the game's character table, not from the
    -- fighter's own list (changing that list changes nothing), so the extra is handed out after the fight
    -- instead: a pickup by your cat holding as much again, once the fight is won.
    local extra = { items = {}, enemies = {}, note = nil }   -- enemies: actor address -> its health, last seen
    Game.every(0.5, function()
        local f = Game.fight()
        if f then
            for _, x in ipairs(f:enemies()) do
                local cat = catOf(x)
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

    -- Hits made harder or softer: one hook on the combat director's OnRegisterDamage (Game.combat.onDamage), put on
    -- the first time a multiplier isn't 1 and left on (taking a hook off from inside a fight's call is what crashed
    -- the game once); it hands back the damage as the game had it while both are 1.
    local hits = { enemy = 1, mine = 1, hooked = false }
    local function hookDamage()
        if hits.hooked or not P.has("combat", "onDamage") then return end
        hits.hooked = Game.combat.onDamage(function(info)
            if hits.enemy == 1 and hits.mine == 1 then return nil end
            local x = info.target and Game.fighter(info.target)
            local team = x and x:team()
            local f = team == "Enemy" and hits.enemy or hits.mine
            if f == 1 or type(info.damage) ~= "number" then return nil end
            return info.damage * f
        end) ~= nil
    end

    local STATUS = { "Blinded", "Furious", "Poisoned", "Stressed" }
    local tiers = nil
    local function tierNames()
        if tiers then return tiers end
        tiers = {}
        for i = 1, 8 do
            local n = Game.enums.aiProfile[i]
            if n then tiers[#tiers + 1] = n end
        end
        return tiers
    end
    local limits = {}   -- actor address -> the move places the C++ part limited it to, as typed

    local function fighterRows(ui, x, enemy)
        local cat = catOf(x)
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
        local condition = cat:status()
        if condition and condition ~= "None" then ui.field("Condition", string.format("%s, %s rounds", condition, show(cat:statusRounds()))) end
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
        ui.section("Change " .. label, function()
            local lv = x:level()
            if type(lv) == "number" then
                local nl = ui.number(label .. ": level", lv, { min = 1, max = 20, step = 1, whole = true })
                if nl ~= lv then x:setLevel(nl) end
            end
            for _, name in ipairs(Game.statNames) do
                local v = st[name]
                if type(v) == "number" then
                    local nv = ui.number(label .. ": " .. name, v, { step = 1 })
                    if P.changed(nv, v) then x:setStat(name, nv) end
                end
            end
            if enemy and x.aiTier then
                local t = x:aiTier() or "None"
                local nt = ui.choice(label .. ": AI tier", t, tierNames())
                if nt ~= t then P.result("fight", label .. " plays at " .. nt .. ".", x:setAITier(nt)) end
            end
            local give = ui.buttons(STATUS)
            if give then P.result("fight", label .. " is " .. STATUS[give] .. ".", cat:applyStatus(STATUS[give])) end
            -- The move it picked (its AttackMove row, a struct), changed before it lands.
            local m = x:move()
            local dmg, acc = m ~= nil and Game.get(m, "Damage") or nil, m ~= nil and Game.get(m, "Accuracy") or nil
            if type(dmg) == "number" and type(acc) == "number" then
                local d = ui.number(label .. ": its move's damage", dmg, { step = 1 })
                local a = ui.number(label .. ": its move's accuracy", acc, { step = 0.05 })
                if P.changed(d, dmg) or P.changed(a, acc) then P.result("fight", "Its move changed.", x:setMove({ Damage = d, Accuracy = a })) end
            end
            if P.cpp() then
                local key = P.addr(x:actor())
                local moves = P.cached("fight.moves." .. tostring(key), 1, function() return P.callCpp("fighter_moves", key) end) or {}
                for i, mv in ipairs(moves) do
                    local f = {}
                    for _, kv in ipairs(mv.fields or {}) do
                        local n = tostring(kv.name)
                        if n == "Damage" or n == "Accuracy" or n:find("Stamina") then f[#f + 1] = n .. " " .. show(kv.value) end
                    end
                    ui.field(string.format("Move %d", i), tostring(mv.tag or "?"):gsub("^Gameplay%.Combat%.Attack%.", "") ..
                             (#f > 0 and ("  (" .. table.concat(f, ", ") .. ")") or ""))
                end
                if enemy and #moves > 0 then
                    local key = P.addr(x:actor())
                    limits[key] = ui.input(label .. ": only these moves", limits[key] or "", { hint = "1, 3" })
                    local h = ui.buttons({ "Limit its moves", "All its moves again" })
                    if h == 1 then
                        local places = {}
                        for n in tostring(limits[key]):gmatch("%d+") do places[#places + 1] = tonumber(n) end
                        P.result("fight", label .. " uses only those now.", P.callCpp("limit_moves", key, places))
                    elseif h == 2 then P.result("fight", label .. " has all its moves again.", P.callCpp("restore_moves", key)) end
                end
            end
        end, { id = "fight-change-" .. label, open = false })
        ui.space(6)
    end

    local chances = { tier = "Tier1" }
    Menu.page("Fight", function(ui)
        ui.heading("Fight")
        local f = Game.fight()
        P.said(ui, "fight")
        if not f then
            if extra.note then ui.note(extra.note) end
            ui.text("No fight now. During one, this page shows both sides (health, stamina, stats, stance and moves), lets " ..
                    "you heal or weaken them, and takes your cat's turns.")
            if P.has("combat", "start") and P.has("animals", "near") and Game.cat() then
                ui.section("Start one", function()
                    ui.note("Game.combat.start: your cat is put behind the animal and the game's pounce pressed. Beside a den " ..
                            "no pounce starts a fight.")
                    local near = P.cached("fight.near", 1, function() return Game.animals.near(4000) end) or {}
                    for i, a in ipairs(near) do
                        if i > 10 then break end
                        if Game.valid(a.actor) and ui.button(string.format("Fight the %s, %.0f m off", words(tostring(a.model or "animal"):gsub("^SK_", "")), a.distance / 100)) then
                            P.result("fight", "Pouncing.", Game.combat.start(a.actor))
                        end
                    end
                    if #near == 0 then ui.note("No animal near.") end
                end, { id = "fight-start", open = true })
            end
            ui.note("The game's own switches for fights (attacks that always land, a forced difficulty) are on Game switches.")
        else
            local more = {}
            for tag, n in pairs(extra.items) do more[#more + 1] = string.format("%d %s", n, itemName(tag)) end
            if #more > 0 then ui.note("Extra drops if you win (by your cat after the fight): " .. table.concat(more, ", ")) end
            local order = {}
            for _, c in ipairs(f:turnOrder()) do order[#order + 1] = c:name() or words(c:kind() or "?") end
            local cur = catAt(Game.get(f.director, "CurrentTurnAttackCharacter"))
            ui.columns({ { "Fight", words((f:kind() or ""):gsub("^BP_", ""):gsub("_C$", "")) }, { "Turn order", table.concat(order, ", ") },
                         { "Whose turn", cur and (cur:name() or words(cur:kind() or "?")) or "?" } })
            if P.has("combat", "menu") then
                ui.section("Your cat's turn", function()
                    local menu = Game.combat.menu()
                    if not menu then
                        ui.note("The fight menu shows on your cat's turn: its moves are here then.")
                    else
                        local moves = Game.combat.moves() or {}
                        for i, m in ipairs(moves) do
                            if ui.button(string.format("Attack with %s (%s stamina)%s", show(m.name), show(m.stamina), m.usable and "" or ", can't now")) then
                                P.result("fight", "Attacking with " .. show(m.name) .. ".", Game.combat.attack(i))
                            end
                        end
                        local hit = ui.buttons({ "Rest", "Flee", "Win now", "Lose now" }, { kinds = { nil, "danger", "good", "danger" } })
                        if hit == 1 then P.result("fight", "Resting.", Game.combat.rest())
                        elseif hit == 2 then P.result("fight", "Fleeing.", Game.combat.flee())
                        elseif hit == 3 then P.result("fight", "The enemies' health is 0: the game finishes the fight as a win.", Game.combat.finish(true))
                        elseif hit == 4 then P.result("fight", "Lost: your cat goes back to its respawn spot.", Game.combat.finish(false)) end
                    end
                    local d = Game.combat.dilemma()
                    if d then
                        ui.text(show(d.title) .. ": " .. show(d.question), { color = THEME.heading })
                        if d.bonus then ui.note(show(d.bonus)) end
                        local a = ui.buttons({ show(d.option1), show(d.option2) })
                        if a then P.result("fight", "Answered.", Game.combat.answerDilemma(a)) end
                    end
                    local auto = ui.switch("Take every turn for me", hits.auto == true)
                    if auto ~= (hits.auto == true) then
                        hits.auto = auto
                        Game.combat.autoFight(auto)
                    end
                    ui.field("Turns taken for you", show(Game.combat.autoFightTurns()))
                    if P.cpp() then
                        local cppAuto = ui.switch("Take every turn for me, by damage (the C++ part's)", hits.cppAuto == true)
                        if cppAuto ~= (hits.cppAuto == true) then
                            hits.cppAuto = cppAuto
                            P.callCpp("auto_fight", cppAuto)
                        end
                    end
                    ui.note("Lua's own player picks the move costing the most stamina it can use (it can't read a move's damage); " ..
                            "the C++ part's picks by damage.")
                end, { id = "fight-turn", open = true })
            end
            if P.has("combat", "onDamage") then
                ui.section("Hits", function()
                    hits.enemy = ui.slider("Hits on the enemy", hits.enemy, 0, 10, { step = 0.25, format = "x%.2f" })
                    hits.mine = ui.slider("Hits on your side", hits.mine, 0, 10, { step = 0.25, format = "x%.2f" })
                    if hits.enemy ~= 1 or hits.mine ~= 1 then hookDamage() end
                    ui.note("Game.combat.onDamage: each hit's damage, changed before the game applies it.")
                end, { id = "fight-hits", open = false })
            end
            ui.section("Your side", function()
                for _, x in ipairs(f:players()) do fighterRows(ui, x, false) end
            end, { id = "fight-players", open = true })
            ui.section("Against you", function()
                for _, x in ipairs(f:enemies()) do fighterRows(ui, x, true) end
            end, { id = "fight-enemies", open = true })
            ui.note("Damage comes from the move, both fighters' stats and levels, and the stances.")
        end
        ui.section("The fight AI's chances", function()
            if not P.needCpp(ui) then return end
            local names = P.cached("fight.tiers", 60, function() return P.callCpp("ai_tiers") end) or {}
            if #names > 0 then chances.tier = ui.choice("Tier", chances.tier, names) end
            local c = P.callCpp("ai_chances", chances.tier)
            if type(c) ~= "table" then ui.note("Not read (wcmods hasn't got the tuning's map on this build).") return end
            local keys = {}
            for k in pairs(c) do keys[#keys + 1] = k end
            table.sort(keys)
            for _, k in ipairs(keys) do
                local nv = ui.slider(words(k), c[k], 0, 1, { step = 0.05, format = "%.2f" })
                if P.changed(nv, c[k]) then P.result("fight", words(k) .. " set for every " .. chances.tier .. " fighter.", P.callCpp("set_ai_chance", chances.tier, k, nv)) end
            end
            ui.note("AICombatChances.csv as the game keeps it: each choice a fighter's tree makes is behind a chance by its tier.")
        end, { id = "fight-chances", open = false })
    end, { order = 40, group = "fight" })
end
