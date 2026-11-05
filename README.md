# Menu pages

Pages for the in-game mod menu of [wcmods](https://github.com/HexOffender/warrior-cats-mods) (Clan Mod Studio), the
mod manager for *Warrior Cats: Clans of the Forest*. The menu itself (the window that Insert opens, its
side bar, its Overview, Installed mods and Tools pages, and the `WCModsMenu` module that mods add pages
with) comes with wcmods. This mod adds the pages about the game, the same way any mod adds a page:

| Group | Pages |
|---|---|
| Home | **At a glance**: your cat's health, stamina and experience, where it is, the time, the fresh-kill pile, the quest you follow, and Heal, Full stamina, Morning and Evening |
| Your cat | **Stats**: health, stamina and its regeneration, size, level and experience, the six stats |
| World | **World** (the clock, which can be held, and the fresh-kill pile, which can be kept up; going back to the main menu lets go of both. On a wcmods with its one shared hold of the clock, `Game.time.hold`, the clock is held through that, so it and another script's hold, such as Tweaks' Hold the clock, don't fight: the last to hold it has it), **Travel** (saved spots, checkpoints, every area, and Back), **Nearby** (what's around your cat, marked on screen if you like), **Items** (what you carry, and an item to drop by your cat) |
| Story | **Quests**: the one you follow and its objectives, with "Go to objective", and every quest by state, mods' own too |
| Fight | **Fight**: both sides during a fight, with Heal, Weaken, Cure status and "Double what it drops" |
| Cheats | **Cheats** (the engine's cheat manager: god mode, fly, ghost, cat size, game speed, teleport, engine commands), **Game switches** (the developers' own, with the game's own god mode as its four flags) |

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

It's an in-game Lua script, so like any script it runs only with **mods that run code allowed**
(Options, on Clan Mod Studio's Settings and repair page). Then Apply to game (or press Play).

It needs wcmods 0.2.0 or newer, the version that built the menu in and moved these pages out of wcmods.

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
  scripts/pages/        one file per group: cat, world, story, fight, cheats; common.lua has what they share
```

It uses only what any mod can: `WCModsMenu` (`Menu.page`, `Menu.status`), `WCModsGame`, `WCModsWorld`,
`WCModsDraw` and `WCModsNames` (the game's names for items, areas and quests), documented in wcmods'
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
2. Commit, then `python tools/pack.py` makes `dist/menu-pages-<version>.zip`. In a git checkout it refuses
   while `menu-pages/` has changes that aren't committed, or files git doesn't keep (a test run's "Start
   with cheats on" writes its settings.json, for one), and when git can't tell it, so the zip is what's
   in git.
3. Make a GitHub release tagged `v<version>` with that .zip attached. Get set up takes the latest
   release's `menu-pages-*.zip`.
