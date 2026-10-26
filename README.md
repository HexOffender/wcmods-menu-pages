# Menu pages

Pages for the in-game mod menu of [wcmods](https://github.com/HexOffender/warrior-cats-mods) (Clan Mod Studio), the
mod manager for *Warrior Cats: Clans of the Forest*. The menu itself (the window that Insert opens, its
side bar, its Overview, Installed mods and Tools pages, and the `WCModsMenu` module that mods add pages
with) comes with wcmods. This mod adds the pages about the game, the same way any mod adds a page:

| Group | Pages |
|---|---|
| Home | **At a glance**: your cat's health, stamina and experience, where it is, the time, the fresh-kill pile, the quest you follow, and Heal, Full stamina, Morning and Evening |
| Your cat | **Stats**: health, stamina and its regeneration, size, level and experience, the six stats |
| World | **World** (the clock, which can be held, and the fresh-kill pile), **Travel** (saved spots, checkpoints, every area, and Back), **Nearby** (what's around your cat, marked on screen if you like), **Items** (what you carry, and an item to drop by your cat) |
| Story | **Quests**: the one you follow and its objectives, with "Go to objective", and every quest by state, mods' own too |
| Fight | **Fight**: both sides during a fight, with Heal, Weaken, Cure status and "Double what it drops" |
| Cheats | **Cheats** (the engine's cheat manager: god mode, fly, ghost, cat size, game speed, teleport, engine commands), **Game switches** (the developers' own) |

It also keeps the line under the menu's title saying how your cat is doing.

## Getting it

- **In Clan Mod Studio:** Get set up, on the Mods page, has "Add the menu's pages". It downloads this
  repository's latest release and adds it to your mods. "Get the latest" on its card updates it,
  keeping whether it's on and its settings.
- **From the command line:** `python wcmods.py menu-pages` in your wcmods folder does the same
  (`--zip file` for a .zip you downloaded).
- **By hand:** download `menu-pages-<version>.zip` from [Releases](../../releases) and drop it on
  Clan Mod Studio's Mods page, or `python wcmods.py add menu-pages-<version>.zip`.

It's an in-game Lua script, so like any script it runs only with **mods that run code allowed**
(Options, on Clan Mod Studio's Settings and repair page). Then Apply to game (or press Play).

It needs a wcmods with the menu built in (from the version that moved these pages out of wcmods).

## Settings

`settings.json` in the mod's folder:

- `"cheats"`: whether the Cheats page starts with cheats on each time the game starts. The page's
  "Start with cheats on" switch changes it, as does `python wcmods.py cheats on|off`.

Saved travel spots are kept in `%LOCALAPPDATA%\Wrc\Saved\WCMods\places.json`, beside the game's saves,
so they stay when the mod is updated.

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
`WCModsDraw` and `WCModsNames` (the game's names for items, areas and quests), all documented in wcmods'
[docs/SDK.md](https://github.com/HexOffender/warrior-cats-mods/blob/main/docs/SDK.md#wcmodsmenu) and
[docs/scripting.md](https://github.com/HexOffender/warrior-cats-mods/blob/main/docs/scripting.md). So it's also an
example of a bigger script mod.

To try a change: copy `menu-pages/` into your mods folder (or `python wcmods.py add path\to\menu-pages`),
then install. wcmods' agent test for the menu (`python wcmods.py agent test tests/game/test_menu.py`)
drives these pages in the running game.

## Releasing

1. Raise `"version"` in `menu-pages/mod.json`.
2. `python tools/pack.py` makes `dist/menu-pages-<version>.zip`.
3. Make a GitHub release tagged `v<version>` with that .zip attached. Get set up takes the latest
   release's `menu-pages-*.zip`.
