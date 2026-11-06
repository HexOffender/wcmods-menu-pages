// Menu pages, the C++ part: the parts of the game only wcmods' C++ SDK reaches, for the pages (Lua, ../../scripts/),
// put in every Lua mod's state as WCModsCpp.menuPages. ../README.md is the contract; in short:
//
//   version                                     1, this table's version
//   status()                                    {game_build, natives = {{name, found}...}, hidden = {{class, member, found}...}}
//   inventory()                                 {[tag] = count}, the inventory itself
//   add_item(tag, count, popup)                 as a pickup does (popup: the HUD's "OBTAINED", default true); true or false, why
//   remove_item(tag, count)                     true or false, why
//   item_tags()                                 every item tag
//   item_info(tag)                              an item's ItemInfo as a table
//   look(actor)                                 a cat's look, {field = value} (numbers, enum names as text)
//   set_look(actor, fields)                     the look with fields laid over it, put on the cat
//   keep_look(fields)                           your cat's look with fields laid over it, kept in its save
//   accessories()                               {{id, slot, variations}...}
//   wear(actor, id, variation)                  put an accessory on
//   take_off(actor, slot)                       take a slot's off
//   play_scene(tag, {rate, length, pause_at_end}), skip_scene()
//   places()                                    {{tag, zone, at = {X, Y, Z}, unlocked}...}
//   unlock_place(tag, on), map_travel(tag)      unlock (or lock) a place; the world map's own travel
//   decorations()                               {{tag, name, mesh, skeletal, animation, size, build_seconds, cost = {[tag] = n}...}...}
//   place_decoration(hotspot, tag), build_decoration(hotspot, tag, seconds)   a hotspot by its address
//   tuning_keys(), tuning(key), set_tuning(key, v)
//   tuning_description(key), tuning_named(key)  its description; "read", "pattern", "not_named" or nil
//   words(key, tbl), set_words(key, text, tbl), restore_words(key, tbl)   tbl is SwtStrings when nil
//   add_row(table, name, from)                  a row of the mod's own, a copy of from (or the defaults)
//   ai_tree(actor), ai_task(actor)              the tree running now; {name, kind} of the node running
//   ai_tiers(), ai_chances(tier), set_ai_chance(tier, column, chance)   {[column] = chance} by AICombatChances.csv column
//   fighter_moves(actor)                        {{tag, fields = {{name, value}...}}...}
//   limit_moves(actor, {1, 3}), restore_moves(actor)   places counted from 1
//   auto_fight(on), auto_fight_turns()          C++'s own player (picks by damage)
//   bonds(), bond(key), set_bond(key, v), add_bond(key, n)   each Bond as a table; one by key
//   bond_thresholds(), bond_roles()
//   talk_rows(prefix, limit), bond_node(node), answer_bond(node, role)
//   sky_values(preset)                          {{name, value}...} of the sky's own copy
//   set_sky_value(preset, field, number), restore_sky_values()
//   replace_sound(id, other), restore_sound(id)
//   conversation_tags()                         the game's talk graphs by tag
//   read_talk(tag), story_talk(tag, time)       {tag, roots, nodes = {{index, speaker, words, answers = {{words, next}...}, next, action}...}}
//   play_conversation(tag, npc), play_story_talk(tag, time, npc)   play one in the game's box
//   talk_next(answer), talk_state(), hide_talk(), say(speaker, words, answers)   talk_state(): {playing, showing, speaker, line, answers}
//   save_state(key), set_save_state(key, value) Currency, Decorations: the account-wide state as a Lua value
//
// Every call runs on the game thread, checks what it's given and never raises a Lua error: a failure is nil, why
// (or false, why). An object comes as its address (obj:GetAddress()), looked up among the live objects that call
// works on before it's used; nil for an actor is your cat.
#include <WCMods/WCMods.hpp>

#include "calls.hpp"

class MenuPagesCpp : public wcmods::ModBase
{
  public:
    auto on_unreal_init() -> void override
    {
        // settings.json is the Lua script's, which has its own page: without this the menu would show a second one.
        wcmods::settings_page(false);
        // The calls check they're on the game thread, which the SDK knows from the first frame its tick runs: start it.
        wcmods::on_game_thread([] {});
        wcmods::log(L"loaded: WCModsCpp.menuPages, {} calls", menu_pages::calls().size());
    }

    // Each Lua mod's state gets WCModsCpp from ModBase (the mod menu's tables, WCModsCpp.ui), then the pages' calls.
    auto on_lua_start(RC::StringViewType mod_name, RC::LuaMadeSimple::Lua& lua, RC::LuaMadeSimple::Lua& main_lua,
                      RC::LuaMadeSimple::Lua& async_lua, RC::LuaMadeSimple::Lua* hook_lua) -> void override
    {
        wcmods::ModBase::on_lua_start(mod_name, lua, main_lua, async_lua, hook_lua);
        lua_State* L = lua.get_lua_state();
        const int top = lua_gettop(L);
        lua_getglobal(L, "WCModsCpp");
        if (!lua_istable(L, -1))
        {
            lua_settop(L, top);
            return;
        }
        const auto& calls = menu_pages::calls();
        lua_createtable(L, 0, static_cast<int>(calls.size()) + 1);
        lua_pushinteger(L, 1);
        lua_setfield(L, -2, "version");
        for (const auto& c : calls)
        {
            lua_pushcfunction(L, c.fn);
            lua_setfield(L, -2, c.name);
        }
        lua_setfield(L, -2, "menuPages");
        lua_settop(L, top);
    }
};

WCMODS_MOD(MenuPagesCpp)
