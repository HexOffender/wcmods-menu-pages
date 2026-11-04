-- Cheats: the engine's cheats, and the game's own developer switches.
return function(P)
    local Menu, THEME, valid, log, words = P.Menu, P.THEME, P.valid, P.log, P.words

    -- ---------- Game switches ----------
    local FULL = { "Health", "Stamina", "StaminaCombat", "FreshKill", "Currency", "Level" }
    local FULL_LABEL = { Health = "Health", Stamina = "Stamina", StaminaCombat = "Fight stamina", FreshKill = "Fresh-kill pile",
                         Currency = "Currency", Level = "Experience" }
    -- The game's own god mode: GodMode on its cheats manager, a set of flags (EGodModeTypeFlag).
    local GOD = { { "Infinite life", 1 }, { "Combat", 2 }, { "Stealth", 4 }, { "Avoid combat", 8 } }
    local switches, switchesAt = {}, -1
    Menu.page("Game switches", function(ui)
        ui.heading("The game's developer switches")
        ui.note("The developers' own settings in the game's cheats manager. The release build obeys some of them and ignores " ..
                "others; some can break a quest or a save, so back up first (Settings and repair in Clan Mod Studio). They " ..
                "reset when the game restarts.")
        local m = Game.dev.manager()
        if not m then
            ui.text("No cheats manager yet.")
            return
        end
        ui.section("Always full", function()
            local full = Game.map(Game.get(m, "AlwaysHasFullResource"))
            for _, kind in ipairs(FULL) do
                local key = Game.enums.resource[kind]
                local was = full[key] == true
                local on = ui.toggle(FULL_LABEL[kind], was)
                if on ~= was then Game.dev.fullResource(kind, on) end
            end
        end, { id = "switches-full", open = true })
        local god = Game.dev.get("GodMode")
        if type(god) == "number" then
            ui.section("God mode (the game's own)", function()
                god = math.floor(god + 0.5)
                local want = god
                for _, f in ipairs(GOD) do
                    local was = math.floor(god / f[2]) % 2 == 1
                    if ui.toggle(f[1], was) ~= was then want = want + (was and -f[2] or f[2]) end
                end
                if want ~= god then Game.dev.set("GodMode", want) switchesAt = -1 end
                ui.note("GodMode in the cheats manager (EGodModeTypeFlag). Whether the release build obeys each isn't " ..
                        "known yet. The Cheats page's God mode is the engine's instead.")
            end, { id = "switches-god", open = true })
        end
        ui.section("Every switch", function()
            if os.clock() - switchesAt > 1 then switches, switchesAt = Game.dev.list(), os.clock() end
            for _, p in ipairs(switches) do
                if p.name == "GodMode" and type(god) == "number" then   -- (its flags are above)
                elseif p.type == "BoolProperty" then
                    local on = ui.toggle(words(p.name:gsub("^b", "")), p.value == true)
                    if on ~= (p.value == true) then Game.dev.set(p.name, on) switchesAt = -1 end
                elseif type(p.value) == "number" then
                    local v = ui.number(words(p.name), p.value, { step = 1, whole = P.INTEGER[p.type] })
                    if math.abs(v - p.value) > 1e-6 then Game.dev.set(p.name, P.asType(v, p.type)) switchesAt = -1 end
                end
            end
        end, { id = "switches-all", open = false })
    end, { order = 51, group = "cheats" })

    -- ---------- Cheats ----------
    -- Cheats are the engine's cheat manager on the player controller, as in the game's own debug builds
    -- (the release build leaves it out). With it, the console's cheat commands work (god, slomo,
    -- teleport ...), and the page below has the handy ones. Flying and size are done here instead of with
    -- the engine's fly, ghost and changesize, which the game undoes (see below).
    -- settings.json "cheats" says whether they start on; the page switches them live.
    -- god: whether this page turned god mode on (the game makes the cat safe by itself at times too).
    -- speedSet: whether the game speed has been set in this level (a new level starts at 1 again).
    local cheats = { on = MOD.settings.cheats == true, movement = "Walk", speed = 1, speedSet = false, size = 1, god = false,
                     flySpeed = 900, command = "", note = nil }

    -- An engine call that fails here goes to the log once (not every frame), so a game update that breaks
    -- flying, size or game speed shows in UE4SS.log rather than just doing nothing.
    local logged, nlogged = {}, 0
    local function logOnce(what, err)
        local line = what .. ": " .. tostring(err)
        if logged[line] or nlogged >= 50 then return end
        logged[line], nlogged = true, nlogged + 1
        log("%s", line)
    end
    local function statics() return Game.library("GameplayStatics") end

    local function cheatManager(c)
        local ok, cm = pcall(function() return c.CheatManager end)
        if ok and valid(cm) then return cm end
        return nil
    end

    local function makeCheatManager(c)
        if cheatManager(c) then return cheatManager(c) end
        local cls = c.CheatClass   -- the game's own cheat class when it has one
        if not valid(cls) then cls = StaticFindObject("/Script/Engine.CheatManager") end
        if not valid(cls) then return nil end
        local cm = StaticConstructObject(cls, c, FName("None"))
        if not valid(cm) then return nil end
        c.CheatManager = cm
        pcall(function() cm:ReceiveInitCheatManager() end)
        log("cheats on (%s)", cls:GetFName():ToString())
        return cm
    end

    -- Game speed: the world's time dilation. cheats.speed is the speed chosen here, which the timer below sets
    -- again in a new level; speedNow reads what the game has, which the page shows when it's different (a
    -- `slomo`, or a new level before the timer has set it again).
    local function setSpeed(c, v)
        local ok, err = pcall(function() statics():SetGlobalTimeDilation(c, v) end)
        if ok then cheats.speedSet = true else logOnce("game speed", err) end
    end
    local function speedNow(c)
        local ok, v = pcall(function() return statics():GetGlobalTimeDilation(c) end)
        return ok and type(v) == "number" and v or nil
    end
    -- A new cat (a new level, or another save loaded) is a new world, at speed 1 again.
    Game.on("player", function() cheats.speedSet = false end)

    local function pawnOf(c)
        local ok, p = pcall(function() return c.Pawn end)
        if ok and valid(p) then return p end
        return nil
    end

    -- ---- flying, done here ----
    -- The engine's Fly and Ghost switch the cat's movement mode, and the game sets it straight back each
    -- frame. So while Fly or Ghost is on, the cat has no gravity and its movement component stands still
    -- (MOVE_None), and this moves it each frame where the game's own controls point it (the way it would
    -- W A S D and the left stick, by the camera), with Space and Left Ctrl (or the triggers) for up and
    -- down. Fly stops at walls; Ghost turns collision off.
    local MOVE_NONE, MOVE_FALLING = 0, 3
    local function key(name) return { KeyName = FName(name) } end
    local keys = {
        up = key("SpaceBar"), down = key("LeftControl"), w = key("W"), a = key("A"), s = key("S"), d = key("D"),
        stickX = key("Gamepad_LeftX"), stickY = key("Gamepad_LeftY"),
        rise = key("Gamepad_RightTriggerAxis"), sink = key("Gamepad_LeftTriggerAxis"),
    }
    local held   -- { pawn = its address, gravity = the game's GravityScale } while flying

    local function land(pawn)
        if held and pawn and pawn:GetAddress() == held.pawn then
            pcall(function()
                local m = pawn.CharacterMovement
                m.GravityScale = held.gravity
                m:SetMovementMode(MOVE_FALLING, 0)
            end)
            pcall(function() pawn:SetActorEnableCollision(true) end)
        end
        held = nil
    end

    local function setMovement(c, move)
        local pawn = pawnOf(c)
        if move == "Walk" then land(pawn) end
        if pawn and move ~= "Walk" then pcall(function() pawn:SetActorEnableCollision(move ~= "Ghost") end) end
        cheats.movement = move
    end

    local function down(c, k)
        local ok, yes = pcall(function() return c:IsInputKeyDown(k) end)
        return ok and yes
    end

    local function flyTick()
        if not cheats.on or cheats.movement == "Walk" then return end
        local c = Game.controller()
        local pawn = c and pawnOf(c)
        if not pawn then return end
        local m = pawn.CharacterMovement
        if not valid(m) then return end
        if not held or held.pawn ~= pawn:GetAddress() then   -- a new cat (a new area): start it flying
            held = { pawn = pawn:GetAddress(), gravity = m.GravityScale }
            pawn:SetActorEnableCollision(cheats.movement ~= "Ghost")
        end
        m.GravityScale = 0
        if m.MovementMode ~= MOVE_NONE then m:SetMovementMode(MOVE_NONE, 0) end
        m.Velocity = { X = 0, Y = 0, Z = 0 }
        if Menu.isOpen() then return end   -- the menu has the controls
        -- The game stops updating its own movement direction while the cat floats (it would keep the
        -- last one), so this reads the controls itself: W A S D (the game's own keys, which the key
        -- remapper sends too) and the left stick, by the camera's direction.
        pcall(function() pawn:ConsumeMovementInputVector() end)   -- don't let the game's input pile up
        local function axis(k)
            local ok, v = pcall(function() return c:GetInputAnalogKeyState(k) end)
            if ok and math.abs(v or 0) > 0.2 then return v end
            return 0
        end
        local f = (down(c, keys.w) and 1 or 0) - (down(c, keys.s) and 1 or 0) + axis(keys.stickY)
        local r = (down(c, keys.d) and 1 or 0) - (down(c, keys.a) and 1 or 0) + axis(keys.stickX)
        local dx, dy = 0, 0
        if f ~= 0 or r ~= 0 then
            local yaw = math.rad(c.PlayerCameraManager:GetCameraRotation().Yaw)
            dx = f * math.cos(yaw) - r * math.sin(yaw)
            dy = f * math.sin(yaw) + r * math.cos(yaw)
            local n = math.sqrt(dx * dx + dy * dy)
            if n > 1 then dx, dy = dx / n, dy / n end
        end
        local dz = (down(c, keys.up) and 1 or 0) - (down(c, keys.down) and 1 or 0) + axis(keys.rise) - axis(keys.sink)
        if dx == 0 and dy == 0 and dz == 0 then return end
        local step = cheats.flySpeed * statics():GetWorldDeltaSeconds(c)
        local l = pawn:K2_GetActorLocation()
        pawn:K2_SetActorLocation({ X = l.X + dx * step, Y = l.Y + dy * step, Z = l.Z + dz * step },
                                 cheats.movement == "Fly", {}, false)
        if dx ~= 0 or dy ~= 0 then
            pawn:K2_SetActorRotation({ Pitch = 0, Yaw = math.deg(math.atan(dy, dx)), Roll = 0 }, false)
        end
    end
    Game.onFrame(function()
        local ok, err = pcall(flyTick)
        if not ok then logOnce("flying", err) end
    end)

    -- ---- size, done here ----
    -- The engine's ChangeSize resizes the cat's collision capsule and sets its mesh's scale, but leaves
    -- the mesh where it was in the capsule (so a bigger cat floats), and the game sets the mesh's scale
    -- back. Scaling the whole cat (the actor) grows the capsule and everything on it together; growing
    -- lifts it by the capsule's extra height so it doesn't start inside the ground.
    -- bases: each cat's own scale (the game's) by its address, and the size this set it to. A cat that still
    -- has that size keeps its base, so coming back to it (after the controller had another pawn, in a fight)
    -- doesn't take the size this set for the cat's own and grow it again.
    local bases, basesFor = {}, nil   -- basesFor: the controller they're for
    -- The bases for this controller. A new controller is a new level: its cats are new, and the old ones'
    -- addresses may be reused. Only then are they forgotten (forgetting a cat's base while it still has the
    -- size this set would grow it again), and the page and the timer both come through here, so neither
    -- forgets what the other just wrote down.
    local function basesOf(c)
        local a = c:GetAddress()
        if a ~= basesFor then bases, basesFor = {}, a end
        return bases
    end

    local function setSize(c, f)
        local pawn = pawnOf(c)
        if not pawn then return end
        local okC, cap = pcall(function() return pawn.CapsuleComponent end)
        if not (okC and valid(cap)) then return end   -- not a cat: something else the controller has
        local addr, now, known = pawn:GetAddress(), pawn:GetActorScale3D(), basesOf(c)
        local rec = known[addr]
        if not (rec and math.abs(now.X - rec.base.X * rec.f) <= 0.01 * rec.base.X * rec.f) then
            rec = { base = { X = now.X, Y = now.Y, Z = now.Z }, f = 1 }
            known[addr] = rec
        end
        local before = cap:GetScaledCapsuleHalfHeight()
        local b = rec.base
        pawn:SetActorScale3D({ X = b.X * f, Y = b.Y * f, Z = b.Z * f })
        local after = cap:GetScaledCapsuleHalfHeight()
        if after > before then
            local l = pawn:K2_GetActorLocation()
            pawn:K2_SetActorLocation({ X = l.X, Y = l.Y, Z = l.Z + (after - before) + 1 }, false, {}, true)
        end
        cheats.size, rec.f = f, f
        if f == 1 then known[addr] = nil end
    end
    -- Whether Cat size holds the cat's size (the Stats page's Size slider steps aside then).
    function P.sizeHeld() return cheats.on and cheats.size ~= 1 end

    local function cheatsOff(c)
        local cm, pawn = cheatManager(c), pawnOf(c)
        if cheats.movement ~= "Walk" then setMovement(c, "Walk") end
        if cheats.size ~= 1 then
            local ok, err = pcall(setSize, c, 1)
            if not ok then logOnce("size", err) end
        end
        if cm then
            if cheats.god and pawn and not pawn.bCanBeDamaged then pcall(function() cm:God() end) end
            if not pcall(function() c.CheatManager = nil end) then c.CheatManager = CreateInvalidObject() end
            log("cheats off")
        end
        if (speedNow(c) or cheats.speed) ~= 1 then setSpeed(c, 1) end
        cheats.movement, cheats.speed, cheats.size, cheats.god = "Walk", 1, 1, false
        bases = {}
    end

    -- A new level brings a new player controller without a cheat manager, a new cat, and game speed 1: give
    -- them the cheats that are on. The game may set the cat's scale again too, so the size is checked each
    -- second.
    Game.every(1, function()
        if not cheats.on then return end
        local c = Game.controller()
        local pawn = c and pawnOf(c)
        if not pawn then return end
        if not cheatManager(c) then
            if not makeCheatManager(c) then return end   -- (tried again next second)
            cheats.god = false
        end
        if cheats.speed ~= 1 and not cheats.speedSet then setSpeed(c, cheats.speed) end
        if cheats.size ~= 1 then
            local rec, now = basesOf(c)[pawn:GetAddress()], pawn:GetActorScale3D()
            local want = rec and rec.base.X * cheats.size
            if not want or math.abs(now.X - want) > 0.01 * want then setSize(c, cheats.size) end
        end
    end)

    -- Run a console command as if typed in the game's console.
    local function console(c, cmd)
        local lib = StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
        if valid(lib) then lib:ExecuteConsoleCommand(c, cmd, c) end
    end

    Menu.page("Cheats", function(ui)
        ui.heading("Cheats")
        ui.note("The engine's cheat commands, as in the game's debug builds. Some can break a quest or a save: back up " ..
                "first (Settings and repair in Clan Mod Studio) if you're unsure.")
        local startOn = MOD.settings.cheats == true
        local want = ui.switch("Start with cheats on", startOn)
        if want ~= startOn then
            MOD.settings.cheats = want
            local saved, why = MOD.save()
            cheats.note = saved and ("Cheats start " .. (want and "on" or "off") .. " from the next time the game starts.")
                          or ("Couldn't save that: " .. tostring(why))
        end
        if cheats.note then ui.note(cheats.note) end
        local c = Game.controller()
        if not c then
            ui.text("No player yet.")
            return
        end
        local on = ui.switch("Cheats", cheats.on)
        if on ~= cheats.on then
            cheats.on = on
            if on then
                if not makeCheatManager(c) then ui.text("Couldn't make a cheat manager.", { color = THEME.danger }) end
            else
                cheatsOff(c)
            end
        end
        if not cheats.on then return end
        local cm = cheatManager(c)
        if not cm then
            cm = makeCheatManager(c)
            if not cm then
                ui.text("Couldn't make a cheat manager.", { color = THEME.danger })
                return
            end
        end
        local pawn = c.Pawn

        ui.separator()
        if valid(pawn) then
            local god = ui.toggle("God mode (nothing hurts you)", not pawn.bCanBeDamaged)
            if god == pawn.bCanBeDamaged then
                cm:God()
                cheats.god = god
            end
            ui.note("The engine's god mode (the cat can't be damaged); whether the game's own damage obeys it isn't " ..
                    "checked yet. The game's own god mode is on Game switches.")
            local move = ui.radio("Moving", cheats.movement, { "Walk", "Fly", "Ghost" })
            if move ~= cheats.movement then setMovement(c, move) end
            if cheats.movement ~= "Walk" then
                ui.note("W A S D or the left stick move you the way the camera faces; Space and Left Ctrl (or the triggers) " ..
                        "go up and down. Fly stops at walls; Ghost goes through them.")
                cheats.flySpeed = ui.slider("Flying speed", cheats.flySpeed, 200, 4000, { step = 100, format = "%.0f cm/s" })
            end
            local size = ui.slider("Cat size", cheats.size, 0.25, 4, { step = 0.05, format = "x%.2f" })
            -- To the slider's steps: a mouse drag doesn't keep to them, and x1.00 has to be 1 to let go of the size.
            size = math.floor(size * 20 + 0.5) / 20
            if math.abs(size - cheats.size) > 0.001 then setSize(c, size) end
            if ui.button("Teleport to where the camera looks") then cm:Teleport() end
        else
            ui.note("Movement cheats show once you're in the world.")
        end
        local speed = ui.slider("Game speed", cheats.speed, 0.1, 4, { step = 0.05, format = "x%.2f" })
        if math.abs(speed - cheats.speed) > 0.001 then
            cheats.speed = speed
            setSpeed(c, speed)
        end
        local actual = speedNow(c)
        if actual and math.abs(actual - cheats.speed) > 0.005 then
            local pending = not cheats.speedSet and cheats.speed ~= 1   -- a new level the timer hasn't set yet
            ui.note(pending and string.format("The game runs at x%.2f now: a new level, which this sets to x%.2f again " ..
                                              "within a second.", actual, cheats.speed)
                    or string.format("The game runs at x%.2f now (a `slomo` in the console?). Move the slider to set " ..
                                     "it.", actual))
        end

        ui.separator()
        cheats.command = ui.input("Engine command", cheats.command, { hint = "e.g. stat fps" })
        local hit = ui.buttons({ "Run", "stat fps", "stat unit" })
        if hit == 1 and cheats.command ~= "" then console(c, cheats.command)
        elseif hit == 2 then console(c, "stat fps")
        elseif hit == 3 then console(c, "stat unit") end

        ui.separator()
        ui.note("The game's own developer switches (always full health or stamina, attacks that always land, " ..
                "fast den building ...) are on the Game switches page.")
    end, { order = 50, group = "cheats" })
end
