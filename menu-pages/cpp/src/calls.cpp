// The functions of WCModsCpp.menuPages, one for each call in README.md's table (main.cpp has the list). Each takes
// what Lua gives it as it comes (calls.hpp's guard catches what C++ throws), checks it by hand and never raises a Lua
// error: a failure is nil and why, or false and why for a yes/no. Text is UTF-8 in Lua, wide in the SDK.
#include "calls.hpp"

#include <algorithm>
#include <map>
#include <set>
#include <string>
#include <utility>
#include <vector>

#include "lua_glue.hpp"

namespace menu_pages
{
    namespace
    {
        // ======================================================================================== the build
        // What wcmods found on this game build: offsets.json's game build, its native functions (each found where it
        // says, its code checked against its pattern) and the hidden members (found when it has an offset).
        auto f_status(lua_State* L) -> int
        {
            const Json& file = wcmods::detail::offsets_file();
            lua_createtable(L, 0, 3);
            const Json& build = file["game_build"];
            if (build.is_number()) field(L, "game_build", build.number());
            lua_newtable(L);
            lua_Integer i = 1;
            for (const std::string& name : file["functions"].keys())
            {
                lua_createtable(L, 0, 2);
                field(L, "name", std::string_view(name));
                field(L, "found", wcmods::native_address(wcmods::wide(name)) != nullptr);
                lua_rawseti(L, -2, i++);
            }
            lua_setfield(L, -2, "natives");
            lua_newtable(L);
            i = 1;
            for (const std::string& key : file["members"].keys())
            {
                const size_t colon = key.rfind(':');
                const std::string cls = colon == std::string::npos ? key : key.substr(0, colon);
                const std::string member = colon == std::string::npos ? std::string{} : key.substr(colon + 1);
                lua_createtable(L, 0, 3);
                field(L, "class", std::string_view(cls));
                field(L, "member", std::string_view(member));
                field(L, "found", wcmods::offset(wcmods::wide(cls), wcmods::wide(member)).has_value());
                lua_rawseti(L, -2, i++);
            }
            lua_setfield(L, -2, "hidden");
            return 1;
        }

        // ======================================================================================== items
        constexpr const wchar_t* ADD_ITEM = L"SwtQuestInventoryComponent:AddItem";

        auto f_inventory(lua_State* L) -> int
        {
            Json all = wcmods::inventory();
            if (!all.is_object())
                return fail(L, wcmods::inventory_component() ? "wcmods hasn't got the inventory's map on this game build (install again)"
                                                             : "no inventory: your cat isn't in the world");
            push_json(L, all);
            return 1;
        }

        // Why an item can't be added or taken now, or empty when it can.
        auto item_problem(const std::wstring& tag) -> std::string
        {
            if (!wcmods::inventory_component()) return "no inventory: your cat isn't in the world";
            if (!wcmods::is_item_tag(tag)) return "not an item's tag: " + wcmods::utf8(tag);
            if (!wcmods::native_address(ADD_ITEM)) return "wcmods hasn't got the game's AddItem on this build (install again)";
            return {};
        }

        auto f_add_item(lua_State* L) -> int
        {
            auto tag = text_arg(L, 1);
            if (!tag) return refuse(L, "tag: an item's tag expected");
            auto count = absent(L, 2) ? std::optional<int>(1) : int_arg(L, 2);
            if (!count || *count < 1) return refuse(L, "count: a whole number from 1 expected");
            auto popup = bool_arg(L, 3, true);
            if (!popup) return refuse(L, "popup: true, false or nil expected");
            if (auto why = item_problem(*tag); !why.empty()) return refuse(L, why);
            if (!wcmods::add_item(*tag, *count, *popup)) return refuse(L, "the game's AddItem failed (UE4SS.log says more)");
            return done(L);
        }

        auto f_remove_item(lua_State* L) -> int
        {
            auto tag = text_arg(L, 1);
            if (!tag) return refuse(L, "tag: an item's tag expected");
            auto count = absent(L, 2) ? std::optional<int>(1) : int_arg(L, 2);
            if (!count || *count < 1) return refuse(L, "count: a whole number from 1 expected");
            if (auto why = item_problem(*tag); !why.empty()) return refuse(L, why);
            auto have = wcmods::inventory_count(wcmods::utf8(*tag));
            if (!have) return refuse(L, "the inventory can't be read on this game build");
            if (*have <= 0) return refuse(L, "you have none of " + wcmods::utf8(*tag));
            if (!wcmods::remove_item(*tag, *count)) return refuse(L, "the game's AddItem failed (UE4SS.log says more)");
            return done(L);
        }

        auto f_item_tags(lua_State* L) -> int
        {
            push_texts(L, wcmods::item_tags());
            return 1;
        }

        auto f_item_info(lua_State* L) -> int
        {
            auto tag = text_arg(L, 1);
            if (!tag) return fail(L, "tag: an item's tag expected");
            auto info = wcmods::item_info(*tag);
            if (!info) return fail(L, "the item table has no " + wcmods::utf8(*tag));
            lua_createtable(L, 0, 15);
            field(L, "tag", info->tag);
            field(L, "name", info->name);
            field(L, "description", info->description);
            field(L, "icon", info->icon);
            field(L, "kind", info->kind);
            field(L, "rarity", info->rarity);
            field(L, "group", info->group);
            field(L, "colour", info->colour);
            field(L, "usable", info->usable);
            field(L, "effect", info->effect);
            field(L, "use_type", info->use_type);
            field(L, "target", info->target);
            field(L, "in_fights", info->in_fights);
            field(L, "exploring", info->exploring);
            field(L, "fight_only", info->fight_only);
            return 1;
        }

        // ======================================================================================== looks
        constexpr const wchar_t* SET_LOOK = L"SwtAdventureCustomizableMeshComponent:SetDefaultCustomData";
        constexpr const wchar_t* KEEP_LOOK = L"Customization:SaveCatCustomData";

        auto push_look(lua_State* L, const wcmods::Look& look) -> void
        {
            const auto& fields = wcmods::detail::look_struct_fields();
            lua_createtable(L, 0, static_cast<int>(fields.size()));
            for (const auto& f : fields)
            {
                std::visit(
                    [&](auto m) {
                        using T = std::remove_cvref_t<decltype(look.*m)>;
                        if constexpr (std::is_same_v<T, int>) push_number(L, look.*m);
                        else if constexpr (std::is_same_v<T, bool>) lua_pushboolean(L, look.*m ? 1 : 0);
                        else if constexpr (std::is_same_v<T, float>) lua_pushnumber(L, look.*m);
                        else push(L, look.*m);
                    },
                    f.member);
                lua_setfield(L, -2, wcmods::utf8(f.name).c_str());
            }
        }

        // Lay a table's fields (the Look's names: TailIdx, ClanType, CatSize...) over a look. False, with why, for a name
        // the look hasn't got or a value of another kind (a whole number for the numbers but CatSize, text for the names,
        // true or false for the flags).
        auto overlay_look(lua_State* L, int i, wcmods::Look& look, std::string& why) -> bool
        {
            if (!lua_istable(L, i))
            {
                why = "fields: a table of the look's fields expected ({TailIdx = 3, ...})";
                return false;
            }
            i = lua_absindex(L, i);
            const auto& fields = wcmods::detail::look_struct_fields();
            lua_pushnil(L);
            while (lua_next(L, i) != 0)
            {
                if (lua_type(L, -2) != LUA_TSTRING)
                {
                    lua_pop(L, 2);
                    why = "fields: the keys are the look's field names";
                    return false;
                }
                size_t n = 0;
                const char* k = lua_tolstring(L, -2, &n);
                const std::wstring key = wcmods::wide(std::string_view(k, n));
                auto f = std::find_if(fields.begin(), fields.end(), [&](const auto& x) { return key == x.name; });
                if (f == fields.end())
                {
                    lua_pop(L, 2);
                    why = "the look has no field " + wcmods::utf8(key);
                    return false;
                }
                bool good = std::visit(
                    [&](auto m) -> bool {
                        using T = std::remove_cvref_t<decltype(look.*m)>;
                        if constexpr (std::is_same_v<T, int>)
                        {
                            auto v = int_arg(L, -1);
                            if (v) look.*m = *v;
                            return v.has_value();
                        }
                        else if constexpr (std::is_same_v<T, bool>)
                        {
                            if (lua_type(L, -1) != LUA_TBOOLEAN) return false;
                            look.*m = lua_toboolean(L, -1) != 0;
                            return true;
                        }
                        else if constexpr (std::is_same_v<T, float>)
                        {
                            auto v = number_arg(L, -1);
                            if (v) look.*m = static_cast<float>(*v);
                            return v.has_value();
                        }
                        else
                        {
                            auto v = text_arg(L, -1);
                            if (v) look.*m = *v;
                            return v.has_value();
                        }
                    },
                    f->member);
                lua_pop(L, 1);
                if (!good)
                {
                    lua_pop(L, 1);
                    why = "the look's " + wcmods::utf8(key) + " takes another kind of value";
                    return false;
                }
            }
            return true;
        }

        auto f_look(lua_State* L) -> int
        {
            std::string why;
            UObject* cat = actor_arg(L, 1, "actor", cat_candidates, why);
            if (!cat) return fail(L, why);
            auto look = wcmods::look(cat);
            if (!look) return fail(L, "it has no look (an animal?)");
            push_look(L, *look);
            return 1;
        }

        auto f_set_look(lua_State* L) -> int
        {
            std::string why;
            UObject* cat = actor_arg(L, 1, "actor", cat_candidates, why);
            if (!cat) return refuse(L, why);
            auto look = wcmods::look(cat);
            if (!look) return refuse(L, "it has no look (an animal?)");
            if (!overlay_look(L, 2, *look, why)) return refuse(L, why);
            if (!wcmods::native_address(SET_LOOK)) return refuse(L, "wcmods hasn't got the game's SetDefaultCustomData on this build (install again)");
            if (!wcmods::set_look(cat, *look)) return refuse(L, "the look couldn't be put on (a name the game hasn't got? UE4SS.log says)");
            return done(L);
        }

        auto f_keep_look(lua_State* L) -> int
        {
            UObject* me = wcmods::player();
            if (!me) return refuse(L, "your cat isn't in the world (a menu, loading or a fight)");
            auto look = wcmods::look(me);
            if (!look) return refuse(L, "your cat's look can't be read");
            std::string why;
            if (!overlay_look(L, 1, *look, why)) return refuse(L, why);
            if (!wcmods::native_address(KEEP_LOOK)) return refuse(L, "wcmods hasn't got the game's SaveCatCustomData on this build (install again)");
            if (!wcmods::keep_look(*look)) return refuse(L, "the look couldn't be kept (a name the game hasn't got? UE4SS.log says)");
            return done(L);
        }

        auto f_accessories(lua_State* L) -> int
        {
            auto all = wcmods::accessories();
            lua_createtable(L, static_cast<int>(all.size()), 0);
            lua_Integer i = 1;
            for (const auto& a : all)
            {
                lua_createtable(L, 0, 3);
                field(L, "id", a.id);
                field(L, "slot", a.slot);
                field(L, "variations", a.variations);
                lua_rawseti(L, -2, i++);
            }
            return 1;
        }

        auto f_wear(lua_State* L) -> int
        {
            std::string why;
            UObject* cat = actor_arg(L, 1, "actor", cat_candidates, why);
            if (!cat) return refuse(L, why);
            auto id = text_arg(L, 2);
            if (!id) return refuse(L, "id: an accessory's id expected (accessories())");
            auto variation = absent(L, 3) ? std::optional<int>(1) : int_arg(L, 3);
            if (!variation || *variation < 1) return refuse(L, "variation: a whole number from 1 expected");
            auto all = wcmods::accessories();
            auto a = std::find_if(all.begin(), all.end(), [&](const auto& x) { return x.id == *id; });
            if (a == all.end()) return refuse(L, "the game has no accessory " + wcmods::utf8(*id));
            if (a->variations > 0 && *variation > a->variations)
                return refuse(L, std::format("{} comes in {} looks", wcmods::utf8(*id), a->variations));
            if (!wcmods::look(cat)) return refuse(L, "it has no look (an animal?)");
            if (!wcmods::native_address(SET_LOOK)) return refuse(L, "wcmods hasn't got the game's SetDefaultCustomData on this build (install again)");
            if (!wcmods::wear(cat, *id, *variation)) return refuse(L, "the look couldn't be put on (UE4SS.log says)");
            return done(L);
        }

        auto f_take_off(lua_State* L) -> int
        {
            std::string why;
            UObject* cat = actor_arg(L, 1, "actor", cat_candidates, why);
            if (!cat) return refuse(L, why);
            auto slot = text_arg(L, 2);
            if (!slot || (*slot != L"Neck" && *slot != L"Paw" && *slot != L"Head" && *slot != L"Body"))
                return refuse(L, "slot: \"Neck\", \"Paw\", \"Head\" or \"Body\" expected");
            if (!wcmods::look(cat)) return refuse(L, "it has no look (an animal?)");
            if (!wcmods::take_off(cat, *slot)) return refuse(L, "the look couldn't be put on (UE4SS.log says)");
            return done(L);
        }

        // ======================================================================================== scenes
        auto f_play_scene(lua_State* L) -> int
        {
            auto tag = text_arg(L, 1);
            if (!tag) return refuse(L, "tag: a scene's tag expected");
            wcmods::PlayScene how;
            if (!absent(L, 2))
            {
                if (!lua_istable(L, 2)) return refuse(L, "options: a table {rate, length, pause_at_end} or nil expected");
                int t = raw_field(L, 2, "rate");
                if (t == LUA_TNUMBER) how.rate = lua_tonumber(L, -1);
                lua_pop(L, 1);
                if (t > LUA_TNIL && t != LUA_TNUMBER) return refuse(L, "rate: a number expected");
                t = raw_field(L, 2, "length");
                if (t == LUA_TNUMBER) how.length = lua_tonumber(L, -1);
                lua_pop(L, 1);
                if (t > LUA_TNIL && t != LUA_TNUMBER) return refuse(L, "length: a number expected");
                t = raw_field(L, 2, "pause_at_end");
                if (t == LUA_TBOOLEAN) how.pause_at_end = lua_toboolean(L, -1) != 0;
                lua_pop(L, 1);
                if (t > LUA_TNIL && t != LUA_TBOOLEAN) return refuse(L, "pause_at_end: true or false expected");
            }
            if (!(how.rate > 0)) return refuse(L, "rate: above 0 expected");
            if (!(how.length >= 0)) return refuse(L, "length: 0 or more expected");
            if (!wcmods::player()) return refuse(L, "your cat isn't in the world (a menu, loading or a fight)");
            if (!wcmods::scenes_playing().empty()) return refuse(L, "a scene is playing");
            if (!wcmods::native_address(L"SwtSequencerManager:PlaySequence"))
                return refuse(L, "wcmods hasn't got the game's PlaySequence on this build (install again)");
            auto all = wcmods::scenes();
            if (std::none_of(all.begin(), all.end(), [&](const auto& s) { return s.tag == *tag; }))
                return refuse(L, "the game has no scene " + wcmods::utf8(*tag));
            if (!wcmods::play_scene(*tag, how)) return refuse(L, "it didn't play (a scene held at its end? skip_scene() first)");
            return done(L);
        }

        auto f_skip_scene(lua_State* L) -> int
        {
            if (!wcmods::skip_scene()) return refuse(L, "no scene to skip (the game's skip popup isn't up)");
            return done(L);
        }

        // ======================================================================================== places
        auto f_places(lua_State* L) -> int
        {
            auto all = wcmods::places();
            lua_createtable(L, static_cast<int>(all.size()), 0);
            lua_Integer i = 1;
            for (const auto& p : all)
            {
                lua_createtable(L, 0, 5);
                field(L, "tag", p.tag);
                field(L, "zone", p.zone);
                push_vec3(L, p.at);
                lua_setfield(L, -2, "at");
                field(L, "unlocked", p.unlocked);
                field(L, "at_start", p.at_start);
                lua_rawseti(L, -2, i++);
            }
            return 1;
        }

        auto place_named(const std::wstring& tag) -> std::optional<wcmods::Place>
        {
            for (auto& p : wcmods::places())
                if (p.tag == tag) return p;
            return std::nullopt;
        }

        auto f_unlock_place(lua_State* L) -> int
        {
            auto tag = text_arg(L, 1);
            if (!tag) return refuse(L, "tag: a place's tag expected (places())");
            auto on = bool_arg(L, 2, true);
            if (!on) return refuse(L, "on: true, false or nil expected");
            if (!wcmods::player()) return refuse(L, "your cat isn't in the world (a menu, loading or a fight)");
            if (!wcmods::native_address(L"Checkpoints:SetUnlocked"))
                return refuse(L, "wcmods hasn't got the game's SetCheckpointUnlockState on this build (install again)");
            auto place = place_named(*tag);
            if (!place) return refuse(L, "no place " + wcmods::utf8(*tag) + " here (places are the forest's checkpoints)");
            if (!wcmods::unlock_place(*place, *on)) return refuse(L, "the game's SetCheckpointUnlockState failed");
            return done(L);
        }

        auto f_map_travel(lua_State* L) -> int
        {
            auto tag = text_arg(L, 1);
            if (!tag) return refuse(L, "tag: a place's tag expected (places())");
            auto place = place_named(*tag);
            if (!place) return refuse(L, "no place " + wcmods::utf8(*tag) + " here (places are the forest's checkpoints)");
            if (!place->unlocked) return refuse(L, "your cat hasn't unlocked " + wcmods::utf8(*tag));
            auto [map, item] = wcmods::travel_map_item(*place);
            if (!map) return refuse(L, "the world map isn't open for travel (it opens at a checkpoint)");
            if (!item) return refuse(L, "the travel map has no item for that place");
            if (!wcmods::map_travel(*place)) return refuse(L, "the travel map couldn't be moved there (this build's map members?)");
            return done(L);
        }

        // ======================================================================================== dens
        // A decoration's cost as its row writes it ("Gameplay.Inventory.Materials.Fur,2;...") as {[tag] = n}.
        auto push_cost(lua_State* L, const std::wstring& cost) -> void
        {
            lua_newtable(L);
            size_t at = 0;
            while (at < cost.size())
            {
                size_t end = cost.find(L';', at);
                if (end == std::wstring::npos) end = cost.size();
                std::wstring part = cost.substr(at, end - at);
                at = end + 1;
                const size_t comma = part.find(L',');
                std::wstring tag = part.substr(0, comma);
                while (!tag.empty() && tag.back() == L' ') tag.pop_back();
                while (!tag.empty() && tag.front() == L' ') tag.erase(tag.begin());
                if (tag.empty()) continue;
                const double n = comma == std::wstring::npos ? 1.0 : std::wcstod(part.c_str() + comma + 1, nullptr);
                push(L, tag);
                push_number(L, n);
                lua_rawset(L, -3);
            }
        }

        auto f_decorations(lua_State* L) -> int
        {
            auto all = wcmods::decorations();
            lua_createtable(L, static_cast<int>(all.size()), 0);
            lua_Integer i = 1;
            for (const auto& d : all)
            {
                lua_createtable(L, 0, 12);
                field(L, "tag", d.tag);
                field(L, "name", d.name);
                field(L, "mesh", d.mesh);
                field(L, "skeletal", d.skeletal);
                field(L, "animation", d.animation);
                field(L, "size", d.size);
                field(L, "rarity", d.rarity);
                field(L, "build_seconds", d.build_seconds);
                field(L, "max", d.max);
                field(L, "hidden", d.hidden);
                push_cost(L, d.cost);
                lua_setfield(L, -2, "cost");
                field(L, "cost_text", d.cost);
                lua_rawseti(L, -2, i++);
            }
            return 1;
        }

        // A hotspot and decoration both checked, for place_decoration and build_decoration.
        auto hotspot_and_decoration(lua_State* L, UObject*& hotspot, std::wstring& tag, std::string& why) -> bool
        {
            auto at = address_arg(L, 1);
            if (!at || *at == 0)
            {
                why = "hotspot: a hotspot's address expected (obj:GetAddress())";
                return false;
            }
            hotspot = find_among(*at, hotspot_candidates());
            if (!hotspot)
            {
                why = "hotspot: that address isn't one of the dens' hotspots (gone since?)";
                return false;
            }
            auto t = text_arg(L, 2);
            if (!t)
            {
                why = "tag: a decoration's tag expected (decorations())";
                return false;
            }
            tag = *t;
            if (!wcmods::detail::known_decoration(tag))
            {
                why = "the dens have no decoration " + wcmods::utf8(tag);
                return false;
            }
            return true;
        }

        auto f_place_decoration(lua_State* L) -> int
        {
            UObject* hotspot{};
            std::wstring tag;
            std::string why;
            if (!hotspot_and_decoration(L, hotspot, tag, why)) return refuse(L, why);
            if (!wcmods::place_decoration(hotspot, tag)) return refuse(L, "the hotspot's OnOptionPicked couldn't be called");
            return done(L);
        }

        auto f_build_decoration(lua_State* L) -> int
        {
            UObject* hotspot{};
            std::wstring tag;
            std::string why;
            if (!hotspot_and_decoration(L, hotspot, tag, why)) return refuse(L, why);
            auto seconds = int_arg(L, 3);
            if (!seconds || *seconds < 1) return refuse(L, "seconds: a whole number from 1 expected");
            if (!wcmods::build_decoration(hotspot, tag, *seconds)) return refuse(L, "the hotspot's OnOptionPicked couldn't be called");
            return done(L);
        }

        // ======================================================================================== tuning
        auto tuning_missing(const std::wstring& key) -> std::string
        {
            if (wcmods::tuning_keys().empty()) return "wcmods hasn't got the tuning's map on this game build (install again)";
            return "the tuning has no key " + wcmods::utf8(key);
        }

        auto f_tuning_keys(lua_State* L) -> int
        {
            push_texts(L, wcmods::tuning_keys());
            return 1;
        }

        auto f_tuning(lua_State* L) -> int
        {
            auto key = text_arg(L, 1);
            if (!key) return fail(L, "key: a tuning key expected");
            auto v = wcmods::tuning(*key);
            if (!v) return fail(L, tuning_missing(*key));
            lua_pushnumber(L, *v);
            return 1;
        }

        auto f_set_tuning(lua_State* L) -> int
        {
            auto key = text_arg(L, 1);
            if (!key) return refuse(L, "key: a tuning key expected");
            auto v = number_arg(L, 2);
            if (!v || !std::isfinite(*v)) return refuse(L, "value: a number expected");
            if (!wcmods::set_tuning(*key, static_cast<float>(*v))) return refuse(L, tuning_missing(*key));
            return done(L);
        }

        auto f_tuning_description(lua_State* L) -> int
        {
            auto key = text_arg(L, 1);
            if (!key) return fail(L, "key: a tuning key expected");
            auto d = wcmods::tuning_description(*key);
            if (!d) return fail(L, tuning_missing(*key));
            push(L, *d);
            return 1;
        }

        auto f_tuning_named(lua_State* L) -> int
        {
            auto key = text_arg(L, 1);
            if (!key) return fail(L, "key: a tuning key expected");
            auto n = wcmods::tuning_named(*key);
            if (!n) return fail(L, "not in tuning_read.json (another game build, or a key it hasn't got)");
            push(L, *n);
            return 1;
        }

        // ======================================================================================== words and tables
        // The string table argument: SwtStrings for nil.
        auto table_arg(lua_State* L, int i, std::wstring& out) -> bool
        {
            if (absent(L, i))
            {
                out = std::wstring(wcmods::game_strings);
                return true;
            }
            auto t = text_arg(L, i);
            if (!t) return false;
            out = *t;
            return true;
        }

        auto f_words(lua_State* L) -> int
        {
            auto key = text_arg(L, 1);
            if (!key) return fail(L, "key: a key of the game's words expected");
            std::wstring tbl;
            if (!table_arg(L, 2, tbl)) return fail(L, "tbl: a string table's name or nil expected");
            auto w = wcmods::words(*key, tbl);
            if (!w) return fail(L, wcmods::utf8(tbl) + " has no key " + wcmods::utf8(*key));
            push(L, *w);
            return 1;
        }

        auto f_set_words(lua_State* L) -> int
        {
            auto key = text_arg(L, 1);
            if (!key) return refuse(L, "key: a key of the game's words expected");
            auto text = text_arg(L, 2);
            if (!text) return refuse(L, "text: the new words expected");
            std::wstring tbl;
            if (!table_arg(L, 3, tbl)) return refuse(L, "tbl: a string table's name or nil expected");
            if (!wcmods::set_words(*key, *text, tbl)) return refuse(L, wcmods::utf8(tbl) + " has no key " + wcmods::utf8(*key));
            return done(L);
        }

        auto f_restore_words(lua_State* L) -> int
        {
            auto key = text_arg(L, 1);
            if (!key) return refuse(L, "key: a key of the game's words expected");
            std::wstring tbl;
            if (!table_arg(L, 2, tbl)) return refuse(L, "tbl: a string table's name or nil expected");
            if (!wcmods::restore_words(*key, tbl)) return refuse(L, "set_words didn't change " + wcmods::utf8(*key));
            return done(L);
        }

        // The rows add_row made, by table: it replaces one of those, never one of the game's own.
        auto rows_added() -> std::set<std::pair<std::wstring, std::wstring>>&
        {
            static std::set<std::pair<std::wstring, std::wstring>> added;
            return added;
        }

        auto f_add_row(lua_State* L) -> int
        {
            auto name = text_arg(L, 1);
            if (!name) return refuse(L, "table: a DataTable's name or path expected");
            auto row = text_arg(L, 2);
            if (!row || row->empty()) return refuse(L, "name: the new row's name expected");
            std::wstring from;
            if (!absent(L, 3))
            {
                auto f = text_arg(L, 3);
                if (!f) return refuse(L, "from: a row's name or nil expected");
                from = *f;
            }
            wcmods::Table t = wcmods::table(*name);
            if (!t) return refuse(L, "no DataTable " + wcmods::utf8(*name) + " in memory");
            if (!from.empty() && !t.has(from)) return refuse(L, wcmods::utf8(t.name()) + " has no row " + wcmods::utf8(from));
            const auto key = std::make_pair(t.path(), *row);
            if (t.has(*row) && !rows_added().contains(key))
                return refuse(L, wcmods::utf8(t.name()) + " has a row " + wcmods::utf8(*row) + " of its own: give another name");
            if (!t.add_row(*row, from)) return refuse(L, "the row couldn't be made on this game build (UE4SS.log says)");
            rows_added().insert(key);
            return done(L);
        }

        // ======================================================================================== AI
        auto f_ai_tree(lua_State* L) -> int
        {
            std::string why;
            UObject* actor = actor_arg(L, 1, "actor", ai_candidates, why);
            if (!actor) return fail(L, why);
            if (!wcmods::ai_controller(actor)) return fail(L, "it has no AI (your cat, or a cat standing in camp)");
            UObject* tree = wcmods::ai_tree(actor);
            if (!tree) return fail(L, "its AI's logic is stopped");
            push(L, wcmods::name(tree));
            return 1;
        }

        auto f_ai_task(lua_State* L) -> int
        {
            std::string why;
            UObject* actor = actor_arg(L, 1, "actor", ai_candidates, why);
            if (!actor) return fail(L, why);
            if (!wcmods::ai_controller(actor)) return fail(L, "it has no AI (your cat, or a cat standing in camp)");
            wcmods::AiTask task = wcmods::ai_task(actor);
            if (!task) return fail(L, "nothing active (between nodes, or its logic is stopped)");
            lua_createtable(L, 0, 2);
            field(L, "name", task.name);
            field(L, "kind", task.kind);
            return 1;
        }

        constexpr const wchar_t* TIERS[] = {L"Terrible", L"Tier1", L"Tier2", L"Tier3", L"Tier4", L"Tier5", L"Tier6", L"Perfect"};

        auto f_ai_tiers(lua_State* L) -> int
        {
            lua_createtable(L, static_cast<int>(std::size(TIERS)), 0);
            lua_Integer i = 1;
            for (const wchar_t* t : TIERS)
            {
                push(L, t);
                lua_rawseti(L, -2, i++);
            }
            return 1;
        }

        auto f_ai_chances(lua_State* L) -> int
        {
            auto tier = text_arg(L, 1);
            if (!tier) return fail(L, "tier: a tier's name expected (ai_tiers())");
            auto c = wcmods::ai_chances(*tier);
            if (!c) return fail(L, "no tier " + wcmods::utf8(*tier) + " (or wcmods hasn't got AICombatChances on this build)");
            const float values[] = {c->cure_status, c->cure_health, c->exhausted, c->support, c->buff, c->debuff, c->attack_weakest,
                                    c->attack_slower, c->select_random, c->select_stance, c->select_aoe, c->select_powerful, c->select_status};
            lua_createtable(L, 0, 13);
            for (size_t k = 0; k < std::size(values); ++k)
            {
                lua_pushnumber(L, values[k]);
                lua_setfield(L, -2, wcmods::utf8(wcmods::detail::CHANCE_FIELDS[k]).c_str());
            }
            return 1;
        }

        auto f_set_ai_chance(lua_State* L) -> int
        {
            auto tier = text_arg(L, 1);
            if (!tier) return refuse(L, "tier: a tier's name expected (ai_tiers())");
            auto column = text_arg(L, 2);
            if (!column) return refuse(L, "column: an AICombatChances.csv column expected (SelectRandom...)");
            auto chance = number_arg(L, 3);
            if (!chance || !(*chance >= 0 && *chance <= 1)) return refuse(L, "chance: a number from 0 to 1 expected");
            if (std::none_of(std::begin(wcmods::detail::CHANCE_FIELDS), std::end(wcmods::detail::CHANCE_FIELDS),
                             [&](const wchar_t* f) { return *column == f; }))
                return refuse(L, "AICombatChances.csv has no column " + wcmods::utf8(*column));
            if (!wcmods::ai_chances(*tier)) return refuse(L, "no tier " + wcmods::utf8(*tier) + " (or wcmods hasn't got AICombatChances on this build)");
            if (!wcmods::set_ai_chance(*tier, *column, *chance)) return refuse(L, "the chance couldn't be written");
            return done(L);
        }

        // A fight's fighter: nil is yours; an address is one of the fighters' actors (or their combat components).
        auto fighter_arg(lua_State* L, int i, wcmods::Fighter& out, std::string& why) -> bool
        {
            auto at = address_arg(L, i);
            if (!at)
            {
                why = "actor: a fighter's address (obj:GetAddress()) or nil (your cat) expected";
                return false;
            }
            if (!wcmods::combat_active())
            {
                why = "no fight is on";
                return false;
            }
            if (*at == 0)
            {
                out = wcmods::fight_cat();
                if (!out) why = "your cat's fighter isn't there";
                return static_cast<bool>(out);
            }
            for (auto& f : fighters())
            {
                UObject* actor = f.actor();
                if ((actor && reinterpret_cast<uintptr_t>(actor) == *at) || reinterpret_cast<uintptr_t>(f.component) == *at)
                {
                    out = f;
                    return true;
                }
            }
            why = "actor: that address isn't one of the fight's fighters";
            return false;
        }

        auto f_fighter_moves(lua_State* L) -> int
        {
            wcmods::Fighter f;
            std::string why;
            if (!fighter_arg(L, 1, f, why)) return fail(L, why);
            if (!f.move_count()) return fail(L, "wcmods hasn't got the fighters' moves on this game build (install again)");
            auto moves = f.moves();
            lua_createtable(L, static_cast<int>(moves.size()), 0);
            lua_Integer i = 1;
            for (const Value& m : moves)
            {
                lua_createtable(L, 0, 2);
                field(L, "tag", wcmods::get(m, L"AttackMoveTag.TagName").string());
                push_fields(L, m);
                lua_setfield(L, -2, "fields");
                lua_rawseti(L, -2, i++);
            }
            return 1;
        }

        auto f_limit_moves(lua_State* L) -> int
        {
            wcmods::Fighter f;
            std::string why;
            if (!fighter_arg(L, 1, f, why)) return refuse(L, why);
            if (!lua_istable(L, 2)) return refuse(L, "places: a list of the moves' places expected, from 1 ({1, 3})");
            std::vector<int> places;
            const lua_Unsigned n = lua_rawlen(L, 2);
            for (lua_Unsigned k = 1; k <= n; ++k)
            {
                lua_rawgeti(L, 2, static_cast<lua_Integer>(k));
                auto p = int_arg(L, -1);
                lua_pop(L, 1);
                if (!p || *p < 1) return refuse(L, "places: whole numbers from 1 expected");
                places.push_back(*p - 1);
            }
            if (places.empty()) return refuse(L, "places: at least one move expected");
            if (!f.move_count()) return refuse(L, "wcmods hasn't got the fighters' moves on this game build (install again)");
            const int have = static_cast<int>(f.moves().size());
            for (size_t k = 0; k < places.size(); ++k)
            {
                if (places[k] >= have) return refuse(L, std::format("it has {} moves", have));
                if (std::find(places.begin(), places.begin() + static_cast<std::ptrdiff_t>(k), places[k]) != places.begin() + static_cast<std::ptrdiff_t>(k))
                    return refuse(L, "places: a move given twice");
            }
            if (!wcmods::limit_moves(f, places)) return refuse(L, "its moves couldn't be limited");
            return done(L);
        }

        auto f_restore_moves(lua_State* L) -> int
        {
            wcmods::Fighter f;
            std::string why;
            if (!fighter_arg(L, 1, f, why)) return refuse(L, why);
            if (!wcmods::restore_moves(f)) return refuse(L, "limit_moves didn't limit its moves");
            return done(L);
        }

        auto f_auto_fight(lua_State* L) -> int
        {
            if (lua_type(L, 1) != LUA_TBOOLEAN) return refuse(L, "on: true or false expected");
            wcmods::auto_fight(lua_toboolean(L, 1) != 0);
            return done(L);
        }

        auto f_auto_fight_turns(lua_State* L) -> int
        {
            lua_pushinteger(L, wcmods::auto_fight_turns());
            return 1;
        }

        // Whether the player is on. It outlives a mods reload (this DLL stays loaded; the pages' Lua starts again), so the
        // Fight page asks rather than remembering. (The SDK has no call for it: its own state, as auto_fight keeps it.)
        auto f_auto_fight_on(lua_State* L) -> int
        {
            lua_pushboolean(L, wcmods::detail::auto_fight_state().on);
            return 1;
        }

        // ======================================================================================== bonds
        auto push_bond(lua_State* L, const wcmods::Bond& b) -> void
        {
            lua_createtable(L, 0, 8);
            field(L, "key", b.key);
            field(L, "clan", b.clan);
            field(L, "value", b.value);
            field(L, "rank", b.rank);
            field(L, "base", b.base);
            field(L, "giver_role", b.giver_role);
            field(L, "giver_index", b.giver_index);
            field(L, "cat_name", b.cat_name);
        }

        auto bond_missing(const std::wstring& key) -> std::string
        {
            if (!wcmods::player()) return "your cat isn't in the world (a menu, loading or a fight)";
            if (!wcmods::native_address(L"Bonding:GetClan") || !wcmods::native_address(L"Bonding:GetPersonal"))
                return "wcmods hasn't got the game's bond functions on this build (install again)";
            return "no clan or story role " + wcmods::utf8(key);
        }

        auto f_bonds(lua_State* L) -> int
        {
            if (!wcmods::player()) return fail(L, "your cat isn't in the world (a menu, loading or a fight)");
            auto all = wcmods::bonds();
            lua_createtable(L, static_cast<int>(all.size()), 0);
            lua_Integer i = 1;
            for (const auto& b : all)
            {
                push_bond(L, b);
                lua_rawseti(L, -2, i++);
            }
            return 1;
        }

        auto f_bond(lua_State* L) -> int
        {
            auto key = text_arg(L, 1);
            if (!key) return fail(L, "key: a clan (RiverClan) or a story role (TheMistrustfulLeader) expected");
            auto v = wcmods::bond(*key);
            if (!v) return fail(L, bond_missing(*key));
            // The role's own (base, which cat plays it) when the game set it up for this game; else the value alone.
            for (const auto& b : wcmods::bonds())
                if (b.key == *key)
                {
                    push_bond(L, b);
                    return 1;
                }
            wcmods::Bond b;
            b.key = *key;
            b.clan = std::any_of(std::begin(wcmods::BOND_CLANS), std::end(wcmods::BOND_CLANS), [&](const wchar_t* c) { return *key == c; });
            b.value = *v;
            b.rank = b.clan ? wcmods::clan_bond_name(wcmods::clan_bond(*v)) : wcmods::bond_rank_name(wcmods::bond_rank(*v));
            push_bond(L, b);
            return 1;
        }

        auto f_set_bond(lua_State* L) -> int
        {
            auto key = text_arg(L, 1);
            if (!key) return refuse(L, "key: a clan or a story role expected");
            auto v = int_arg(L, 2);
            if (!v || *v < 0 || *v > 100) return refuse(L, "value: a whole number from 0 to 100 expected");
            if (!wcmods::bond(*key)) return refuse(L, bond_missing(*key));
            if (!wcmods::set_bond(*key, *v)) return refuse(L, "the game's bond change failed (UE4SS.log says)");
            return done(L);
        }

        auto f_add_bond(lua_State* L) -> int
        {
            auto key = text_arg(L, 1);
            if (!key) return refuse(L, "key: a clan or a story role expected");
            auto n = int_arg(L, 2);
            if (!n) return refuse(L, "amount: a whole number expected");
            if (!wcmods::bond(*key)) return refuse(L, bond_missing(*key));
            if (!wcmods::add_bond(*key, *n)) return refuse(L, "the game's bond change failed (UE4SS.log says)");
            return done(L);
        }

        auto f_bond_thresholds(lua_State* L) -> int
        {
            const wcmods::BondThresholds t = wcmods::bond_thresholds();
            lua_createtable(L, 0, 6);
            field(L, "neutral", t.neutral);
            field(L, "friendly", t.friendly);
            field(L, "friend", t.friend_);
            field(L, "close", t.close);
            field(L, "clan_negative", t.clan_negative);
            field(L, "clan_positive", t.clan_positive);
            return 1;
        }

        auto f_bond_roles(lua_State* L) -> int
        {
            push_texts(L, wcmods::bond_roles());
            return 1;
        }

        auto f_talk_rows(lua_State* L) -> int
        {
            auto prefix = text_arg(L, 1);
            if (!prefix) return fail(L, "prefix: the start of the rows' names expected");
            auto limit = absent(L, 2) ? std::optional<int>(1000) : int_arg(L, 2);
            if (!limit || *limit < 0) return fail(L, "limit: a whole number from 0, or nil (1000) expected");
            auto rows = wcmods::talk_rows(*prefix);
            std::sort(rows.begin(), rows.end(), [](const auto& a, const auto& b) { return a.name < b.name; });
            const size_t shown = std::min(rows.size(), static_cast<size_t>(*limit));
            lua_createtable(L, static_cast<int>(shown), 0);
            for (size_t k = 0; k < shown; ++k)
            {
                const auto& r = rows[k];
                lua_createtable(L, 0, 9);
                field(L, "name", r.name);
                field(L, "score", r.score);
                field(L, "clan_bonding", r.clan_bonding);
                field(L, "talker", r.talker);
                field(L, "trait", r.trait);
                field(L, "string_key", r.string_key);
                field(L, "debug_text", r.debug_text);
                field(L, "voice", r.voice);
                field(L, "text", r.text());
                lua_rawseti(L, -2, static_cast<lua_Integer>(k + 1));
            }
            lua_pushinteger(L, static_cast<lua_Integer>(rows.size()));   // how many there are, past the limit too
            return 2;
        }

        auto f_bond_node(lua_State* L) -> int
        {
            auto node = text_arg(L, 1);
            if (!node) return fail(L, "node: an answer's row name expected");
            auto had = wcmods::bond_node(*node);
            if (!had)
                return fail(L, wcmods::player() ? "wcmods hasn't got the game's HasNode on this build (install again)"
                                                : "your cat isn't in the world (a menu, loading or a fight)");
            lua_pushboolean(L, *had ? 1 : 0);
            return 1;
        }

        auto f_answer_bond(lua_State* L) -> int
        {
            auto node = text_arg(L, 1);
            if (!node) return fail(L, "node: an answer's row name expected (talk_rows())");
            std::wstring role;
            if (!absent(L, 2))
            {
                auto r = text_arg(L, 2);
                if (!r) return fail(L, "role: a story role or nil expected");
                role = *r;
            }
            if (!wcmods::player()) return fail(L, "your cat isn't in the world (a menu, loading or a fight)");
            auto row = wcmods::talk_row(*node);
            if (!row) return fail(L, "no talk row " + wcmods::utf8(*node));
            if (row->trait == 0) return fail(L, "that row has no trait: it isn't a bond talk's answer");
            auto a = wcmods::answer_bond(*node, role);
            if (!a) return fail(L, "not given (a role that isn't a story cat's, or the game's bond functions aren't on this build)");
            lua_createtable(L, 0, 8);
            field(L, "node", a->node);
            field(L, "trait", a->trait);
            field(L, "bonus", a->bonus);
            field(L, "first", a->first);
            field(L, "role", a->role);
            field(L, "personal", a->personal);
            field(L, "clan", a->clan);
            field(L, "clan_change", a->clan_change);
            return 1;
        }

        // ======================================================================================== sky and sounds
        auto f_sky_values(lua_State* L) -> int
        {
            auto preset = text_arg(L, 1);
            if (!preset) return fail(L, "preset: a sky preset's name expected (Night, ThunderClan...)");
            if (!wcmods::sky()) return fail(L, "there's no sky (a menu, or loading)");
            Value row = wcmods::sky_values(*preset);
            if (row.kind != Value::Kind::Struct) return fail(L, "the sky has no preset " + wcmods::utf8(*preset) + " (or wcmods hasn't got its map on this build)");
            push_fields(L, row);
            return 1;
        }

        auto f_set_sky_value(lua_State* L) -> int
        {
            auto preset = text_arg(L, 1);
            if (!preset) return refuse(L, "preset: a sky preset's name expected");
            auto name = text_arg(L, 2);
            if (!name) return refuse(L, "field: a field's name expected (FogDensity, SunColor.R...)");
            auto v = number_arg(L, 3);
            if (!v || !std::isfinite(*v)) return refuse(L, "value: a number expected");
            if (!wcmods::sky()) return refuse(L, "there's no sky (a menu, or loading)");
            if (wcmods::sky_values(*preset).kind != Value::Kind::Struct) return refuse(L, "the sky has no preset " + wcmods::utf8(*preset));
            if (!wcmods::set_sky_value(*preset, *name, *v)) return refuse(L, "the preset has no number " + wcmods::utf8(*name));
            return done(L);
        }

        auto f_restore_sky_values(lua_State* L) -> int
        {
            wcmods::restore_sky_values();
            return done(L);
        }

        auto f_replace_sound(lua_State* L) -> int
        {
            auto id = text_arg(L, 1);
            if (!id) return refuse(L, "id: a sound id expected (cat_step...)");
            auto other = text_arg(L, 2);
            if (!other) return refuse(L, "other: the id of the sound to play instead expected");
            if (!wcmods::sound_of(*id)) return refuse(L, "the game has no sound " + wcmods::utf8(*id));
            if (!wcmods::sound_of(*other)) return refuse(L, "the game has no sound " + wcmods::utf8(*other));
            if (!wcmods::replace_sound(*id, *other)) return refuse(L, "the sound couldn't be replaced");
            return done(L);
        }

        auto f_restore_sound(lua_State* L) -> int
        {
            auto id = text_arg(L, 1);
            if (!id) return refuse(L, "id: a sound id expected");
            if (!wcmods::restore_sound(*id)) return refuse(L, wcmods::utf8(*id) + " wasn't replaced or muted");
            return done(L);
        }

        // ======================================================================================== talks
        // The speaker a node names: its own for a Custom one, else who (ETalkingSource's name: NPC, Player, Current_Character).
        auto speaker_of(const wcmods::TalkNode& n) -> std::wstring
        {
            if (n.source == 3 || !n.source_words.empty()) return n.source_words;
            switch (n.source)
            {
            case 0: return L"NPC";
            case 1: return L"Player";
            case 2: return L"Current_Character";
            default: return std::to_wstring(n.source);
            }
        }

        // A talk as a table; its node numbers counted from 1, as Lua's lists are (nodes[next] is the next node). `tag` is
        // the talk's own (a story talk's rows' prefix), else the one it was asked for by.
        auto push_talk(lua_State* L, const wcmods::Talk& talk, const std::wstring& asked) -> void
        {
            lua_createtable(L, 0, 3);
            field(L, "tag", talk.tag.empty() ? asked : talk.tag);
            lua_createtable(L, static_cast<int>(talk.roots.size()), 0);
            lua_Integer i = 1;
            for (int r : talk.roots)
            {
                lua_pushinteger(L, r + 1);
                lua_rawseti(L, -2, i++);
            }
            lua_setfield(L, -2, "roots");
            lua_createtable(L, static_cast<int>(talk.nodes.size()), 0);
            for (size_t k = 0; k < talk.nodes.size(); ++k)
            {
                const wcmods::TalkNode& n = talk.nodes[k];
                lua_createtable(L, 0, 9);
                field(L, "index", static_cast<int>(k + 1));
                field(L, "line", n.line);
                field(L, "kind", n.kind);
                if (n.line)
                {
                    field(L, "speaker", speaker_of(n));
                    field(L, "source", n.source);
                    field(L, "words", n.words);
                    if (!n.by_bond.empty())
                    {
                        push_texts(L, n.by_bond);
                        lua_setfield(L, -2, "by_bond");
                    }
                }
                else
                {
                    field(L, "action", n.kind);
                }
                if (!n.next.empty()) field(L, "next", n.next.front() + 1);
                if (!n.sub_tag.empty()) field(L, "sub_tag", n.sub_tag);
                lua_createtable(L, static_cast<int>(n.answers.size()), 0);
                lua_Integer a = 1;
                for (const auto& answer : n.answers)
                {
                    lua_createtable(L, 0, 6);
                    field(L, "words", answer.words);
                    if (answer.to >= 0) field(L, "next", answer.to + 1);
                    field(L, "option", answer.option);
                    field(L, "trait", answer.trait);
                    field(L, "score", answer.score);
                    field(L, "bonding", answer.bonding);
                    lua_rawseti(L, -2, a++);
                }
                lua_setfield(L, -2, "answers");
                lua_rawseti(L, -2, static_cast<lua_Integer>(k + 1));
            }
            lua_setfield(L, -2, "nodes");
        }

        // A conversation's talk by its tag (conversation_tags()), or a talk graph's object path ("/Game/..."). Its own
        // tag stays as read_talk gives it: the talk's tag is where its bond answers' rows are looked up.
        auto conversation_talk(const std::wstring& tag) -> wcmods::Talk
        {
            UObject* graph = wcmods::conversation(tag);
            if (!graph && !tag.empty() && tag.front() == L'/') graph = wcmods::load(tag);
            return wcmods::read_talk(graph);
        }

        auto f_conversation_tags(lua_State* L) -> int
        {
            push_texts(L, wcmods::conversation_tags());
            return 1;
        }

        auto f_read_talk(lua_State* L) -> int
        {
            auto tag = text_arg(L, 1);
            if (!tag || tag->empty()) return fail(L, "tag: a conversation's tag expected (conversation_tags())");
            wcmods::Talk talk = conversation_talk(*tag);
            if (!talk) return fail(L, "no conversation " + wcmods::utf8(*tag));
            push_talk(L, talk, *tag);
            return 1;
        }

        auto f_story_talk(lua_State* L) -> int
        {
            auto tag = text_arg(L, 1);
            if (!tag) return fail(L, "tag: a story talk's tag expected");
            auto time = absent(L, 2) ? std::optional<int>(1) : int_arg(L, 2);
            if (!time || *time < 1) return fail(L, "time: a whole number from 1 expected");
            wcmods::Talk talk = wcmods::story_talk(*tag, *time);
            if (!talk) return fail(L, "no story talk " + wcmods::utf8(*tag) + " for that time (or no rows for it)");
            push_talk(L, talk, *tag);
            return 1;
        }

        // Who the talk is with: nil (its own names), a name, or a cat's address (its name, and its story role for the
        // bond answers).
        auto npc_arg(lua_State* L, int i, std::wstring& name, wcmods::TalkHooks& hooks, std::string& why) -> bool
        {
            if (absent(L, i)) return true;
            if (auto t = text_arg(L, i))
            {
                name = *t;
                return true;
            }
            auto at = address_arg(L, i);
            UObject* cat = at && *at ? find_among(*at, cat_candidates()) : nullptr;
            if (!cat)
            {
                why = "npc: a name, a cat's address or nil expected (and a cat that's still here)";
                return false;
            }
            name = wcmods::cat_name(cat);
            hooks.cat = cat;
            return true;
        }

        auto f_play_conversation(lua_State* L) -> int
        {
            auto tag = text_arg(L, 1);
            if (!tag || tag->empty()) return refuse(L, "tag: a conversation's tag expected (conversation_tags())");
            std::wstring name;
            wcmods::TalkHooks hooks;
            std::string why;
            if (!npc_arg(L, 2, name, hooks, why)) return refuse(L, why);
            wcmods::Talk talk = conversation_talk(*tag);
            if (!talk) return refuse(L, "no conversation " + wcmods::utf8(*tag));
            if (!wcmods::play_talk(std::move(talk), name, hooks)) return refuse(L, "it has no line to show, or the talk box can't be made");
            return done(L);
        }

        auto f_play_story_talk(lua_State* L) -> int
        {
            auto tag = text_arg(L, 1);
            if (!tag) return refuse(L, "tag: a story talk's tag expected");
            auto time = absent(L, 2) ? std::optional<int>(1) : int_arg(L, 2);
            if (!time || *time < 1) return refuse(L, "time: a whole number from 1 expected");
            std::wstring name;
            wcmods::TalkHooks hooks;
            std::string why;
            if (!npc_arg(L, 3, name, hooks, why)) return refuse(L, why);
            wcmods::Talk talk = wcmods::story_talk(*tag, *time);
            if (!talk) return refuse(L, "no story talk " + wcmods::utf8(*tag) + " for that time (or no rows for it)");
            // Its answers move your bonds as the game's do, with the story cat the tag names (or the cat given).
            if (!hooks.cat)
            {
                const auto roles = wcmods::bond_roles();
                size_t at = 0;
                while (at <= tag->size())
                {
                    size_t end = tag->find(L'.', at);
                    if (end == std::wstring::npos) end = tag->size();
                    std::wstring part = tag->substr(at, end - at);
                    if (std::find(roles.begin(), roles.end(), part) != roles.end())
                    {
                        hooks.role = part;
                        break;
                    }
                    at = end + 1;
                }
            }
            if (!wcmods::play_talk(std::move(talk), name, hooks)) return refuse(L, "it has no line to show, or the talk box can't be made");
            return done(L);
        }

        auto f_talk_next(lua_State* L) -> int
        {
            auto answer = absent(L, 1) ? std::optional<int>(1) : int_arg(L, 1);
            if (!answer || *answer < 1) return refuse(L, "answer: an answer's number from 1, or nil expected");
            if (!wcmods::talk_playing()) return refuse(L, "no talk is playing");
            if (const wcmods::TalkNode* n = wcmods::talk_at(); n && !n->answers.empty() && static_cast<size_t>(*answer) > n->answers.size())
                return refuse(L, std::format("the line has {} answers", n->answers.size()));
            if (!wcmods::talk_next(*answer - 1)) return refuse(L, "the talk has ended");
            return done(L);
        }

        auto f_talk_state(lua_State* L) -> int
        {
            lua_createtable(L, 0, 5);
            field(L, "playing", wcmods::talk_playing());
            field(L, "showing", wcmods::talk_showing());
            field(L, "speaker", wcmods::talk_speaker());
            field(L, "line", wcmods::talk_line());
            push_texts(L, wcmods::talk_answers());
            lua_setfield(L, -2, "answers");
            return 1;
        }

        auto f_hide_talk(lua_State* L) -> int
        {
            if (!wcmods::hide_talk()) return refuse(L, "the talk box wasn't up");
            return done(L);
        }

        auto f_say(lua_State* L) -> int
        {
            auto speaker = text_arg(L, 1);
            if (!speaker) return refuse(L, "speaker: a name expected");
            auto words = text_arg(L, 2);
            if (!words) return refuse(L, "words: what's said expected");
            std::vector<std::wstring> answers;
            if (!absent(L, 3))
            {
                auto list = texts_arg(L, 3);
                if (!list || list->size() > 4) return refuse(L, "answers: a list of up to four texts, or nil expected");
                answers = std::move(*list);
            }
            if (!wcmods::controller()) return refuse(L, "there's no player to show it to (loading?)");
            if (!wcmods::say(*speaker, *words, answers)) return refuse(L, "the talk box can't be made (the game hasn't loaded it)");
            return done(L);
        }

        // ======================================================================================== the save
        auto f_save_state(lua_State* L) -> int
        {
            auto key = text_arg(L, 1);
            if (!key) return fail(L, "key: a part of the state expected (Currency, Decorations)");
            if (!wcmods::save_manager()) return fail(L, "the save manager isn't there yet");
            const std::string text = wcmods::utf8(wcmods::save_state_text(*key));
            if (text.empty() || text == "null") return fail(L, "the state has no " + wcmods::utf8(*key));
            std::string why;
            auto parsed = Json::parse(text, &why);
            if (!parsed) return fail(L, "the state's " + wcmods::utf8(*key) + " isn't JSON (" + why + ")");
            push_json(L, *parsed);
            return 1;
        }

        auto f_set_save_state(lua_State* L) -> int
        {
            auto key = text_arg(L, 1);
            if (!key) return refuse(L, "key: a part of the state expected (Currency, Decorations)");
            if (absent(L, 2)) return refuse(L, "value: the part's new value expected");
            Json value;
            std::string why;
            if (lua_type(L, 2) == LUA_TSTRING)
            {
                // Text is the part's JSON itself (for what a table can't say: an empty list).
                size_t n = 0;
                const char* s = lua_tolstring(L, 2, &n);
                auto parsed = Json::parse(std::string_view(s, n), &why);
                if (!parsed) return refuse(L, "value: text that isn't JSON (" + why + ")");
                value = std::move(*parsed);
            }
            else if (!json_of(L, 2, value, why))
            {
                return refuse(L, "value: " + why);
            }
            if (!wcmods::save_manager()) return refuse(L, "the save manager isn't there yet");
            if (!wcmods::set_save_state(*key, value)) return refuse(L, "the save manager's SetStateJsonDataFromString couldn't be called");
            return done(L);
        }
    } // namespace

    auto calls() -> const std::vector<Call>&
    {
        static const std::vector<Call> all = {
            {"status", guard<f_status, false>},
            {"inventory", guard<f_inventory>},
            {"add_item", guard<f_add_item>},
            {"remove_item", guard<f_remove_item>},
            {"item_tags", guard<f_item_tags>},
            {"item_info", guard<f_item_info>},
            {"look", guard<f_look>},
            {"set_look", guard<f_set_look>},
            {"keep_look", guard<f_keep_look>},
            {"accessories", guard<f_accessories>},
            {"wear", guard<f_wear>},
            {"take_off", guard<f_take_off>},
            {"play_scene", guard<f_play_scene>},
            {"skip_scene", guard<f_skip_scene>},
            {"places", guard<f_places>},
            {"unlock_place", guard<f_unlock_place>},
            {"map_travel", guard<f_map_travel>},
            {"decorations", guard<f_decorations>},
            {"place_decoration", guard<f_place_decoration>},
            {"build_decoration", guard<f_build_decoration>},
            {"tuning_keys", guard<f_tuning_keys>},
            {"tuning", guard<f_tuning>},
            {"set_tuning", guard<f_set_tuning>},
            {"tuning_description", guard<f_tuning_description>},
            {"tuning_named", guard<f_tuning_named>},
            {"words", guard<f_words>},
            {"set_words", guard<f_set_words>},
            {"restore_words", guard<f_restore_words>},
            {"add_row", guard<f_add_row>},
            {"ai_tree", guard<f_ai_tree>},
            {"ai_task", guard<f_ai_task>},
            {"ai_tiers", guard<f_ai_tiers, false>},
            {"ai_chances", guard<f_ai_chances>},
            {"set_ai_chance", guard<f_set_ai_chance>},
            {"fighter_moves", guard<f_fighter_moves>},
            {"limit_moves", guard<f_limit_moves>},
            {"restore_moves", guard<f_restore_moves>},
            {"auto_fight", guard<f_auto_fight>},
            {"auto_fight_turns", guard<f_auto_fight_turns, false>},
            {"auto_fight_on", guard<f_auto_fight_on, false>},
            {"bonds", guard<f_bonds>},
            {"bond", guard<f_bond>},
            {"set_bond", guard<f_set_bond>},
            {"add_bond", guard<f_add_bond>},
            {"bond_thresholds", guard<f_bond_thresholds>},
            {"bond_roles", guard<f_bond_roles>},
            {"talk_rows", guard<f_talk_rows>},
            {"bond_node", guard<f_bond_node>},
            {"answer_bond", guard<f_answer_bond>},
            {"sky_values", guard<f_sky_values>},
            {"set_sky_value", guard<f_set_sky_value>},
            {"restore_sky_values", guard<f_restore_sky_values>},
            {"replace_sound", guard<f_replace_sound>},
            {"restore_sound", guard<f_restore_sound>},
            {"conversation_tags", guard<f_conversation_tags>},
            {"read_talk", guard<f_read_talk>},
            {"story_talk", guard<f_story_talk>},
            {"play_conversation", guard<f_play_conversation>},
            {"play_story_talk", guard<f_play_story_talk>},
            {"talk_next", guard<f_talk_next>},
            {"talk_state", guard<f_talk_state>},
            {"hide_talk", guard<f_hide_talk>},
            {"say", guard<f_say>},
            {"save_state", guard<f_save_state>},
            {"set_save_state", guard<f_set_save_state>},
        };
        return all;
    }
} // namespace menu_pages
