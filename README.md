# Menu pages

Pages for the in-game mod menu of [wcmods](https://github.com/HexOffender/warrior-cats-mods) (Clan Mod Studio), the
mod manager for *Warrior Cats: Clans of the Forest*. The menu itself (the window that Insert opens, its
side bar, its Overview, Installed mods and Tools pages, and the `WCModsMenu` module that mods add pages
with) comes with wcmods. This mod adds the pages about the game, the same way any mod adds a page. Together
they give everything wcmods' SDK can reach in the game a place: all of `WCModsGame` and the modules beside it
(Lua), and, through the mod's C++ part, what only the C++ SDK can do. **SDK map** lists every part of the SDK,
whether this game has it, and the page it's on.

| Group | Pages |
|---|---|
| Home | **At a glance**: your cat's health, stamina and experience, where it is, the time, the fresh-kill pile, the quest you follow, and Heal, Full stamina, Morning and Evening; **SDK map**: every part of the SDK (Lua and C++), whether this game has it, its page, the C++ mods in the game and values shared with them |
| Your cat | **Stats**: health, stamina and its regeneration, fight stamina, size, level and experience, the six stats, its condition; **Looks** (its whole look by the game's names, any cat near; put a look on, keep it in the save, wear and take off accessories (C++), a look from the save's text); **Movement** (its own speeds, jump and gravity, its time, the scent sense); **Animations** (mods' animations, the game's by tag and by path, on your cat or a cat or animal near) |
| World | **World** (the clock, which can be held, and the fresh-kill pile, which can be kept up; going back to the main menu lets go of both. On a wcmods with its one shared hold of the clock, `Game.time.hold`, the clock is held through that, so it and another script's hold, such as Tweaks' Hold the clock, don't fight: the last to hold it has it), **Travel** (saved spots, checkpoints, every area, and Back), **Nearby** (what's around your cat, marked on screen if you like), **Items** (what you carry, an item to drop by your cat, what an item is, and the live inventory with items put in and taken out (C++)), **Animals** (the animals near and their AI: stop it, call it, make it ignore or notice your cat, flee, follow you, its detection, senses, blackboard and trees, what it's doing now (C++); stealth for every animal near; any of the game's 323 kinds put in the world; the behaviour trees read as data), **Walking cats** (the clan cats walking about: stop them, give them a path, steer their AI; the save's clan cats), **Your own cats** (cats of the page's own with your colours: walk, follow, label, Talk prompt and a line in the game's dialogue box, map marker), **Dens** (every clan's dens, going in, their hotspots, a decoration taken off, or built at once or timed (C++)), **Sky and sound** (sky presets held or once, the sky's own values (C++); every sound played, muted or swapped (C++); volumes, pausing, music; the game's visual effects), **Camera** (the following camera's settings, photo mode and pictures, what the camera sees), **HUD and map** (markers on the minimap and world map, the objective panel, banners, the HUD's parts hidden) |
| Story | **Quests**: the one you follow and its objectives, with "Go to objective", collecting a target and finishing an objective, every quest by state, mods' own too, starting or handing out one by its tag, a quest's state by its story id, and a quest of the page's own; **Scenes** (every scene, the ones playing and seen, Skip; played at a rate or length (C++)); **Talk** (the game's dialogue box; the game's own talks read, played and answered (C++)); **Bonds** (your bonds with the clans and story cats, set; their ranks and roles; the talk tables and bond answers (C++)) |
| Fight | **Fight**: both sides during a fight, with Heal, Weaken, Cure status and "Double what it drops"; your cat's turns (attack, rest, flee, win or lose now), dilemmas, a player that takes every turn, hits made harder or softer; each fighter's level, stats, tier, condition and move, and its moves with their damage, limited (C++); the fight AI's chances by tier (C++); outside a fight, starting one with an animal near |
| Cheats | **Cheats** (the engine's cheat manager: god mode, fly, ghost, cat size, game speed, teleport, engine commands), **Game switches** (the developers' own, with the game's own god mode as its four flags, and the enum switches by name), **Tuning** (TuningData.csv's 441 numbers, live (C++)) |
| Tools | **Engine** (the managers, function libraries, enums, mapped values and what wcmods found on this build, the console, the game's commands, its screens), **Tables** (every DataTable, row by row: change a value, take a row out, add one (C++)), **Words** (the game's words by key, changed (C++)), **Events** (every event as it happens, your own, keys and buttons, timers, a hook's calls counted), **Save data** (save now, the save browsed, progression, mood and the account's numbers), **Game UI** (a tab of its own in the pause screen, an overlay, `WCModsCpp.ui`'s theme, a `WCModsDraw` panel) |

It also keeps the line under the menu's title saying how your cat is doing, with "(held)" on a time it holds
(and "(held by Tweaks)" on another script's, on a wcmods with the shared hold) and "(kept at N+)" on a pile kept
up. On a wcmods that keeps a line for each script (`Menu.statusShown`), the menu chooses whose line to show; on an
older one, while another script's line is up there, it leaves that one alone.

## Getting it

- **In Clan Mod Studio:** on the Mods page, Get set up's "Add all four" (or Add on Menu pages' row of the
  card of mods that go with Clan Mod Studio) downloads this repository's latest release and adds it to your
  mods. "Get the latest" on its card updates it, keeping whether it's on and its settings. (On wcmods 0.2.0
  and 0.3.0 it's Get set up's "Add the menu's pages" step, with its "Add it" button.)
- **From the command line:** `python wcmods.py menu-pages` in your wcmods folder does the same
  (`--zip file` for a .zip you downloaded).
- **By hand:** download `menu-pages-<version>.zip` from [Releases](../../releases) and drop it on
  Clan Mod Studio's Mods page, or `python wcmods.py add menu-pages-<version>.zip`.

It's an in-game Lua script with a C++ part, so like any script it runs only with **mods that run code allowed**
(Options, on Clan Mod Studio's Settings and repair page). Then Apply to game (or press Play).

It needs wcmods 0.2.0 or newer, the version that built the menu in and moved these pages out of wcmods. The
pages after the first release's (everything but At a glance, Stats, World, Travel, Nearby, Items, Quests, Fight,
Cheats and Game switches) need the wcmods after 0.5.0; on an older one each says what it's missing.

**The C++ part** (`cpp/`, built into `dlls/main.dll`) puts the calls only wcmods' C++ SDK has into every script as
`WCModsCpp.menuPages` (`cpp/README.md` lists them), and brings `WCModsCpp.ui`. It's built for one UE4SS: an
install leaves it out on another, and the pages' C++ rows then say they need it. Everything else still works.

## Settings

`settings.json` in the mod's folder:

- `"cheats"`: whether the Cheats page starts with cheats on each time the game starts. The page's
  "Start with cheats on" switch changes it, as does `python wcmods.py cheats on|off`.

Saved travel spots are kept in `%LOCALAPPDATA%\Wrc\Saved\WCMods\places.json`, beside the game's saves,
so they stay when the mod is updated. It's a JSON list of `{ "name", "level", "X", "Y", "Z" }`, and you can
edit it by hand: Save this spot and Forget read it again first, and "Read it again" shows your edits. A
file that isn't one JSON list (or can't be opened, or is read-only) is left as it is, and saving waits until
it's fixed; an empty file is no spots. A save writes `places.json.new` and reads it back before it takes the
old file's place, which is moved aside to `places.json.old` meanwhile. If the game stops in between, there's
no `places.json`: the spots from that save, in `places.json.new`, are put in its place when the page next
reads the file. A `places.json.old` with no `places.json` and no good `places.json.new` beside it has the
spots from before a save that didn't finish, and saving waits until you rename it to `places.json`.

## How it's made

`menu-pages/` is the mod as it goes in your mods folder:

```
menu-pages/
  mod.json              its name, version, and "uses": ["mod-menu"] (it has pages in the menu)
  settings.json         its settings (MOD.settings in the script)
  scripts/main.lua      starts the pages, and the status line
  scripts/pages/        the pages: cat (At a glance, Stats), body (Looks, Movement, Animations), world (World,
                        Travel, Nearby, Items), creatures (Animals, Walking cats, Your own cats), places (Dens,
                        Sky and sound, Camera, HUD and map), story, fight, cheats (and Tuning), tools (SDK map,
                        Engine, Tables, Words, Events, Save data, Game UI); common.lua has what they share
  cpp/                  the C++ part's source (README.md: its calls, WCModsCpp.menuPages)
  dlls/                 the C++ part, built (main.dll, build.json): not in git, in the release zip
```

It uses only what any mod can: `WCModsMenu` (`Menu.page`, `Menu.status`), `WCModsGame`, `WCModsWorld`,
`WCModsDraw`, `WCModsView`, `WCModsNames` (the game's names for items, areas and quests), `WCModsCpp.ui`, and
wcmods' C++ SDK (`WCMods.hpp`) in its C++ part, documented in wcmods'
[docs/SDK.md](https://github.com/HexOffender/warrior-cats-mods/blob/main/docs/SDK.md#wcmodsmenu) and
[docs/scripting.md](https://github.com/HexOffender/warrior-cats-mods/blob/main/docs/scripting.md). So it's also an
example of a bigger script mod. Three things it does are for older versions of wcmods. On a wcmods without
`Menu.statusShown` (0.5.0 and older), the status line reads `Menu.shared("status")`, the one line the menu
showed then, so it can leave another script's line alone; wcmods' SDK.md now says the menu's shared variables
aren't for scripts, and a newer wcmods keeps a line for each script itself. On one without `Game.time.hold` (0.5.0
and older too), World's Hold this time puts the clock back itself each second, so it and Tweaks' Hold the clock
fight over the hour when both are on; a newer wcmods has one hold of the clock that every script goes through. And
the Fight page reads whose turn it is from the fight's `director` (in scripting.md's Fights), not `Fight:current()`,
which gave your own cat when it was nobody's turn before wcmods' fixes for these pages.

To try a change: copy `menu-pages/` into your mods folder (or `python wcmods.py add path\to\menu-pages`),
then install. wcmods' agent test for the menu drives these pages in the running game: install with
`python wcmods.py agent install --with path\to\menu-pages`, which on wcmods 0.4.0 and newer uses the mod
even on a game build its mod.json doesn't list yet (on 0.2.0 and 0.3.0, choose "Use it anyway" on its card
first), then run `python wcmods.py agent test tests/game/test_menu.py`. Check that none of the tests of
these pages was skipped, whatever the reason: they're the ones that skip with "the Menu pages mod isn't in
the game" when it's missing. The file's other tests skip for reasons of their own (Game Tweaks not
installed, the game window not in front), which aren't about these pages.

## Releasing

1. Raise `"version"` in `menu-pages/mod.json`. After a game update, try the pages on the new build
   (wcmods' agent test, as above, with none of its Menu pages tests skipped) and add its number to `"game_builds"`
   (`python wcmods.py game build` shows it); until then wcmods leaves the mod out on that build, unless
   the player chooses "Use it anyway".
2. Build the C++ part for the game's UE4SS: `python wcmods.py cpp build path\to\menu-pages` in a wcmods checkout
   with `cpp setup` done (and its SDK at least as new as the one the pages were written for).
3. Commit, then `python tools/pack.py` makes `dist/menu-pages-<version>.zip`. In a git checkout it refuses
   while `menu-pages/` has changes that aren't committed, or files git doesn't keep (a test run's "Start
   with cheats on" writes its settings.json, for one), and when git can't tell it, so the zip is what's
   in git. The built `dlls/` goes in as it is (git doesn't keep it), and `cpp/` stays out; it refuses without
   a build, or with one older than `cpp/` (`--lua-only` packs without the C++ part).
4. Make a GitHub release tagged `v<version>` with that .zip attached. Get set up takes the latest
   release's `menu-pages-*.zip`.
