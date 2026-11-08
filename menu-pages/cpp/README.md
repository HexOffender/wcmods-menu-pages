# Menu pages, C++ part

The pages are Lua (`../scripts/`). A Lua script can't reach the parts of the game only wcmods' C++ SDK reaches
(scripting.md, "What only C++ can do"): this C++ mod puts them in every Lua state as **`WCModsCpp.menuPages`**,
and the pages use them when it's there. Without the DLL (not built, or built for another UE4SS) the pages still
work, and the C++ rows say they need it.

It's built like any wcmods C++ mod: `python wcmods.py cpp build path\to\menu-pages` in a wcmods checkout that has
`cpp setup` done, which writes `dlls/main.dll` and `dlls/build.json` (not kept in git; `tools/pack.py` puts them
in the release zip, without this source).

## The Lua side: `WCModsCpp.menuPages`

Every function runs on the game thread (the pages call them from their draw), checks what it's given, and never
throws: a failure is `nil, why` (or `false, why` for a yes/no). Text is UTF-8. **An object is passed as its
address** (`actor:GetAddress()` in Lua), and the C++ looks it up among the live objects that function works on
(your cat, the animals and cats near it, the fight's fighters, the dens' hotspots) before using it: an address
that's none of those (gone since, or anything else) is refused, never dereferenced. `nil` for an actor means
your cat (in a fight, your fighter). Finding an address scans the game's objects of a few classes, so the pages
ask these at most a few times a second, never every frame. UE4SS's own object is taken too, by its address.

| Call | Gives or does |
|---|---|
| `version` | `1`, this table's version |
| `status()` | `{ game_build, natives = { {name, found}, ... }, hidden = { {class, member, found}, ... } }`: what wcmods found on this build (`offsets.json`) |
| **Items** | |
| `inventory()` | `{ [tag] = count }`, the inventory itself (`wcmods::inventory`) |
| `add_item(tag, count, popup)`, `remove_item(tag, count)` | As a pickup does (popup: the HUD's "OBTAINED", default true); true or false, why |
| `item_tags()`, `item_info(tag)` | Every item tag; an item's `ItemInfo` as a table (every field it has) |
| **Looks** | |
| `look(actor)` | A cat's look, `{ field = value }` (numbers, enum names as text) |
| `set_look(actor, fields)` | The look with `fields` laid over it, put on the cat (`wcmods::set_look`) |
| `keep_look(fields)` | Your cat's look with `fields` laid over it, kept in its save (`wcmods::keep_look`); it doesn't draw it: `set_look(nil, fields)` does |
| `accessories()`, `wear(actor, id, variation)`, `take_off(actor, slot)` | `{ {id, slot, variations}, ... }`; put one on, take a slot's off |
| **Scenes** | |
| `play_scene(tag, {rate, length, pause_at_end})`, `skip_scene()` | `wcmods::play_scene`, `skip_scene` |
| **Places** | |
| `places()` | `{ {tag, zone, at = {X, Y, Z}, unlocked}, ... }` |
| `unlock_place(tag, on)`, `map_travel(tag)` | Unlock (or lock) a place; the world map's own travel, with the travel map already open (Interact at a checkpoint, `Game.places.openTravelMap`) |
| **Dens** | |
| `decorations()` | `{ {tag, name, mesh, skeletal, animation, size, build_seconds, cost = {[tag] = n}, ...}, ... }` |
| `place_decoration(hotspot, tag)`, `build_decoration(hotspot, tag, seconds)` | A hotspot by its address |
| **Tuning** | |
| `tuning_keys()`, `tuning(key)`, `set_tuning(key, v)` | The 441 keys; a key's number; change it |
| `tuning_description(key)`, `tuning_named(key)` | Its description; `"read"`, `"pattern"`, `"not_named"` or nil |
| **Words and tables** | |
| `words(key, tbl)`, `set_words(key, text, tbl)`, `restore_words(key, tbl)` | `tbl` is `SwtStrings` when nil |
| `add_row(table, name, from)` | A row of the mod's own, a copy of `from` (or the defaults): true. A row the game has already is never replaced |
| **AI** | |
| `ai_tree(actor)`, `ai_task(actor)` | The tree running now; `{name, kind}` of the node running |
| `ai_tiers()`, `ai_chances(tier)`, `set_ai_chance(tier, column, chance)` | Tier names (Terrible, Tier1 to Tier6, Perfect); `{ [column] = chance }` by `AICombatChances.csv` column name (`SelectRandom`, `AttackWeakest`...) |
| `fighter_moves(actor)` | A fighter's moves: `{ {tag, fields = { {name, value}, ... }}, ... }` (each AttackMove row described) |
| `limit_moves(actor, {1, 3})`, `restore_moves(actor)` | Places counted from 1 |
| `auto_fight(on)`, `auto_fight_turns()`, `auto_fight_on()` | C++'s own player (picks by damage); whether it's on (it stays on through a mods reload) |
| **Bonds** | |
| `bonds()`, `bond(key)`, `set_bond(key, v)`, `add_bond(key, n)` | Each `Bond` as a table; one by key |
| `bond_thresholds()`, `bond_roles()` | |
| `talk_rows(prefix, limit)`, `bond_node(node)`, `answer_bond(node, role)` | Talk table rows (and, second, how many there are before `limit`, 1000 by default); whether an answer was given; give one |
| **Sky and sounds** | |
| `sky_values(preset)` | `{ {name, value}, ... }` of the sky's own copy |
| `set_sky_value(preset, field, number)`, `restore_sky_values()` | |
| `replace_sound(id, other)`, `restore_sound(id)` | |
| **Talks** | |
| `conversation_tags()` | The game's talk graphs by tag |
| `read_talk(tag)`, `story_talk(tag, time)` | A talk as `{tag, roots, nodes = { {index, speaker, words, answers = { {words, next}, ... }, next, action}, ... }}`, nodes counted from 1 |
| `play_conversation(tag, npc)`, `play_story_talk(tag, time, npc)` | Play one in the game's box; `npc` is nil, a name, or a cat's address. A story talk's bond answers move your bonds as the game's do |
| `talk_next(answer)`, `talk_state()`, `hide_talk()`, `say(speaker, words, answers)` | Answers count from 1 (nil: the first, or on from a line without any); `talk_state()`: `{playing, showing, speaker, line, answers}` |
| **The save** | |
| `save_state(key)`, `set_save_state(key, value)` | `Currency`, `Decorations`: the account-wide state as a Lua value |
