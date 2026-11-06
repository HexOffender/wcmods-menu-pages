// lua_glue.hpp: what the calls in calls.cpp share. Reading Lua's arguments without raising its errors (a Lua
// error longjmps over C++ frames, so nothing here calls lua_error or luaL_check*), pushing values back as plain
// Lua tables, and finding an object Lua names by its address among the live objects a call works on: an
// address is compared with theirs and never followed, so one that's gone since is refused, not read.
#pragma once

#include <cmath>
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include <WCMods/WCMods.hpp>

namespace menu_pages
{
    using wcmods::Json;
    using wcmods::UObject;
    using wcmods::Value;

    // ============================================================================================ results
    inline auto push(lua_State* L, std::string_view text) -> void { lua_pushlstring(L, text.data(), text.size()); }
    inline auto push(lua_State* L, std::wstring_view text) -> void { push(L, std::string_view(wcmods::utf8(text))); }
    // A whole number as a Lua integer (so math.type says so), anything else as a float.
    inline auto push_number(lua_State* L, double v) -> void
    {
        if (std::isfinite(v) && v == std::floor(v) && std::fabs(v) < 9.0e15) lua_pushinteger(L, static_cast<lua_Integer>(v));
        else lua_pushnumber(L, v);
    }

    // A failure: nil and why (or false and why, for a yes/no).
    inline auto fail(lua_State* L, std::string_view why) -> int
    {
        lua_pushnil(L);
        push(L, why);
        return 2;
    }
    inline auto fail(lua_State* L, std::wstring_view why) -> int { return fail(L, std::string_view(wcmods::utf8(why))); }
    inline auto refuse(lua_State* L, std::string_view why) -> int
    {
        lua_pushboolean(L, 0);
        push(L, why);
        return 2;
    }
    inline auto refuse(lua_State* L, std::wstring_view why) -> int { return refuse(L, std::string_view(wcmods::utf8(why))); }
    inline auto done(lua_State* L) -> int
    {
        lua_pushboolean(L, 1);
        return 1;
    }

    // Fields of the table on the top of the stack (one made here: no metatable, so setting a field calls nothing).
    inline auto field(lua_State* L, const char* key, std::wstring_view v) -> void
    {
        push(L, v);
        lua_setfield(L, -2, key);
    }
    inline auto field(lua_State* L, const char* key, const wchar_t* v) -> void { field(L, key, std::wstring_view(v)); }
    inline auto field(lua_State* L, const char* key, const std::wstring& v) -> void { field(L, key, std::wstring_view(v)); }
    inline auto field(lua_State* L, const char* key, std::string_view v) -> void
    {
        push(L, v);
        lua_setfield(L, -2, key);
    }
    inline auto field(lua_State* L, const char* key, bool v) -> void
    {
        lua_pushboolean(L, v ? 1 : 0);
        lua_setfield(L, -2, key);
    }
    inline auto field(lua_State* L, const char* key, double v) -> void
    {
        push_number(L, v);
        lua_setfield(L, -2, key);
    }
    inline auto field(lua_State* L, const char* key, int v) -> void { field(L, key, static_cast<double>(v)); }
    inline auto field(lua_State* L, const char* key, int64_t v) -> void { field(L, key, static_cast<double>(v)); }
    inline auto field(lua_State* L, const char* key, float v) -> void { field(L, key, static_cast<double>(v)); }

    // A list of texts.
    inline auto push_texts(lua_State* L, const std::vector<std::wstring>& items) -> void
    {
        lua_createtable(L, static_cast<int>(items.size()), 0);
        lua_Integer i = 1;
        for (const auto& t : items)
        {
            push(L, t);
            lua_rawseti(L, -2, i++);
        }
    }
    // A place as UE4SS's Lua writes a vector: {X, Y, Z}.
    inline auto push_vec3(lua_State* L, const wcmods::Vec3& v) -> void
    {
        lua_createtable(L, 0, 3);
        field(L, "X", v.x);
        field(L, "Y", v.y);
        field(L, "Z", v.z);
    }

    // ============================================================================================ arguments
    inline auto absent(lua_State* L, int i) -> bool { return lua_type(L, i) <= LUA_TNIL; }   // none or nil

    // Text: a Lua string only (a number isn't taken for one).
    inline auto text_arg(lua_State* L, int i) -> std::optional<std::wstring>
    {
        if (lua_type(L, i) != LUA_TSTRING) return std::nullopt;
        size_t n = 0;
        const char* s = lua_tolstring(L, i, &n);
        return wcmods::wide(std::string_view(s, n));
    }
    inline auto number_arg(lua_State* L, int i) -> std::optional<double>
    {
        if (lua_type(L, i) != LUA_TNUMBER) return std::nullopt;
        return static_cast<double>(lua_tonumber(L, i));
    }
    // A whole number that fits an int (2 and 2.0 both).
    inline auto int_arg(lua_State* L, int i) -> std::optional<int>
    {
        auto n = number_arg(L, i);
        if (!n || *n != std::floor(*n) || *n < -2147483648.0 || *n > 2147483647.0) return std::nullopt;
        return static_cast<int>(*n);
    }
    // A bool; `fallback` for nil or nothing; nullopt for anything else.
    inline auto bool_arg(lua_State* L, int i, bool fallback) -> std::optional<bool>
    {
        if (absent(L, i)) return fallback;
        if (lua_type(L, i) != LUA_TBOOLEAN) return std::nullopt;
        return lua_toboolean(L, i) != 0;
    }
    // A list of texts (a table 1..n of strings); nullopt for anything else.
    inline auto texts_arg(lua_State* L, int i) -> std::optional<std::vector<std::wstring>>
    {
        if (!lua_istable(L, i)) return std::nullopt;
        std::vector<std::wstring> out;
        const lua_Unsigned n = lua_rawlen(L, i);
        for (lua_Unsigned k = 1; k <= n; ++k)
        {
            lua_rawgeti(L, i, static_cast<lua_Integer>(k));
            auto t = text_arg(L, -1);
            lua_pop(L, 1);
            if (!t) return std::nullopt;
            out.push_back(std::move(*t));
        }
        return out;
    }
    // A table's field by name, read raw (no __index to call), pushed; its Lua type.
    inline auto raw_field(lua_State* L, int table, const char* key) -> int
    {
        table = lua_absindex(L, table);
        lua_pushstring(L, key);
        return lua_rawget(L, table);
    }

    // An object Lua names: its address (obj:GetAddress()), or the object itself as UE4SS's Lua wraps it (then its
    // address, read from the wrapper, not from the object). 0 for nil; nullopt for anything else. The address is
    // only compared with live objects' (find_among), never followed.
    inline auto address_arg(lua_State* L, int i) -> std::optional<uintptr_t>
    {
        if (absent(L, i)) return uintptr_t{0};
        if (lua_type(L, i) == LUA_TNUMBER)
        {
            int whole = 0;
            const lua_Integer v = lua_tointegerx(L, i, &whole);
            if (!whole || v <= 0) return std::nullopt;
            return static_cast<uintptr_t>(v);
        }
        if (wcmods::detail::uilua::is_object_userdata(L, i))
        {
            UObject* o = wcmods::detail::uilua::object_at(L, i);
            if (o) return reinterpret_cast<uintptr_t>(o);
        }
        return std::nullopt;
    }

    // ============================================================================================ the objects a call works on
    // Your cat: the player's pawn, or in a fight (where the controller holds the fight's own pawn) your fighter's actor.
    inline auto my_cat() -> UObject*
    {
        if (UObject* p = wcmods::player()) return p;
        wcmods::Fighter f = wcmods::fight_cat();
        return f ? f.actor() : nullptr;
    }

    // Both sides of the fight now (none outside one).
    inline auto fighters() -> std::vector<wcmods::Fighter>
    {
        std::vector<wcmods::Fighter> out = wcmods::fight_players();
        for (auto& f : wcmods::fight_enemies()) out.push_back(f);
        return out;
    }
    inline auto fighter_actors() -> std::vector<UObject*>
    {
        std::vector<UObject*> out;
        for (auto& f : fighters())
            if (UObject* a = f.actor()) out.push_back(a);
        return out;
    }
    inline auto add_all(std::vector<UObject*>& into, const wchar_t* cls) -> void
    {
        for (UObject* o : wcmods::find_all(cls)) into.push_back(o);
    }
    // The cats a look call takes: your cat, the walking and camp cats (nearby()'s Cats, in the whole level, a mod's
    // own spawned cats among them), and a fight's fighters.
    inline auto cat_candidates() -> std::vector<UObject*>
    {
        std::vector<UObject*> out;
        if (UObject* me = wcmods::player()) out.push_back(me);
        add_all(out, STR("SwtAdventureWalkingNPC"));
        add_all(out, STR("SwtAdventureQuestActor"));
        for (UObject* a : fighter_actors()) out.push_back(a);
        return out;
    }
    // The actors an AI call takes: your cat (which has none: it says so), the roaming animals (nearby()'s Creatures),
    // the walking and camp cats, and a fight's fighters.
    inline auto ai_candidates() -> std::vector<UObject*>
    {
        std::vector<UObject*> out;
        if (UObject* me = wcmods::player()) out.push_back(me);
        add_all(out, STR("WrcRoamingEnemy"));
        add_all(out, STR("SwtAdventureWalkingNPC"));
        add_all(out, STR("SwtAdventureQuestActor"));
        for (UObject* a : fighter_actors()) out.push_back(a);
        return out;
    }
    // The dens' hotspots (hotspots()'s actors).
    inline auto hotspot_candidates() -> std::vector<UObject*>
    {
        std::vector<UObject*> out;
        add_all(out, STR("SwtAdventureHousingHotspot"));
        return out;
    }

    // The candidate whose address this is, or nullptr. Only addresses are compared: nothing at `at` is read. A match
    // is then checked as an object still staying in the world (not marked to be destroyed) and not a class's default.
    inline auto find_among(uintptr_t at, const std::vector<UObject*>& candidates) -> UObject*
    {
        for (UObject* c : candidates)
            if (c && reinterpret_cast<uintptr_t>(c) == at)
                return wcmods::detail::object_staying(c, nullptr) && wcmods::detail::live(c) ? c : nullptr;
        return nullptr;
    }

    // An actor argument: nil is your cat; an address must be one of `candidates`. The object, or why not in `why`.
    template <typename Candidates>
    auto actor_arg(lua_State* L, int i, const char* what, Candidates&& candidates, std::string& why) -> UObject*
    {
        auto at = address_arg(L, i);
        if (!at)
        {
            why = std::string(what) + ": an address (obj:GetAddress()) or nil (your cat) expected";
            return nullptr;
        }
        if (*at == 0)
        {
            UObject* me = my_cat();
            if (!me) why = "your cat isn't in the world (a menu, or loading)";
            return me;
        }
        UObject* o = find_among(*at, candidates());
        if (!o) why = std::string(what) + ": that address isn't one of the live objects this call takes (gone since?)";
        return o;
    }

    // ============================================================================================ values
    // JSON as Lua: objects and arrays as tables (arrays from 1), null as nil.
    inline auto push_json(lua_State* L, const Json& v, int depth = 0) -> void
    {
        if (depth > 32 || !lua_checkstack(L, 4))
        {
            lua_pushnil(L);
            return;
        }
        switch (v.type())
        {
        case Json::Type::Null: lua_pushnil(L); break;
        case Json::Type::Bool: lua_pushboolean(L, v.boolean() ? 1 : 0); break;
        case Json::Type::Number: push_number(L, v.number()); break;
        case Json::Type::String: push(L, std::string_view(v.string())); break;
        case Json::Type::Array:
        {
            lua_createtable(L, static_cast<int>(v.size()), 0);
            lua_Integer i = 1;
            for (const Json& e : v.values())
            {
                push_json(L, e, depth + 1);
                lua_rawseti(L, -2, i++);
            }
            break;
        }
        case Json::Type::Object:
        {
            lua_createtable(L, 0, static_cast<int>(v.size()));
            for (size_t k = 0; k < v.size(); ++k)
            {
                push(L, std::string_view(v.keys()[k]));
                push_json(L, v.values()[k], depth + 1);
                lua_rawset(L, -3);
            }
            break;
        }
        }
    }

    // A Lua value as JSON: a table with keys 1..n is an array, any other table an object (number keys written as
    // text); an empty table is an empty object. False, with why, for a function, a userdata, a cycle or too deep.
    inline auto json_of(lua_State* L, int i, Json& out, std::string& why, int depth = 0) -> bool
    {
        i = lua_absindex(L, i);
        if (depth > 32 || !lua_checkstack(L, 4))
        {
            why = "a table nested too deep (or one that holds itself)";
            return false;
        }
        switch (lua_type(L, i))
        {
        case LUA_TNONE:
        case LUA_TNIL: out = Json(); return true;
        case LUA_TBOOLEAN: out = Json(lua_toboolean(L, i) != 0); return true;
        case LUA_TNUMBER:
            out = lua_isinteger(L, i) ? Json(static_cast<double>(lua_tointeger(L, i))) : Json(static_cast<double>(lua_tonumber(L, i)));
            return true;
        case LUA_TSTRING:
        {
            size_t n = 0;
            const char* s = lua_tolstring(L, i, &n);
            out = Json(std::string(s, n));
            return true;
        }
        case LUA_TTABLE:
        {
            // A list only when every key is 1..n: a border alone (lua_rawlen) can sit past a hole.
            const lua_Unsigned n = lua_rawlen(L, i);
            bool list = n > 0;
            lua_Unsigned count = 0;
            lua_pushnil(L);
            while (lua_next(L, i) != 0)
            {
                if (!lua_isinteger(L, -2) || lua_tointeger(L, -2) < 1 || static_cast<lua_Unsigned>(lua_tointeger(L, -2)) > n) list = false;
                ++count;
                lua_pop(L, 1);
            }
            if (list && count == n)
            {
                out = Json::array();
                for (lua_Unsigned k = 1; k <= n; ++k)
                {
                    lua_rawgeti(L, i, static_cast<lua_Integer>(k));
                    Json e;
                    const bool good = json_of(L, -1, e, why, depth + 1);
                    lua_pop(L, 1);
                    if (!good) return false;
                    out.push(std::move(e));
                }
                return true;
            }
            out = Json::object();
            lua_pushnil(L);
            while (lua_next(L, i) != 0)
            {
                std::string key;
                // The key is read without lua_tolstring on a number, which would change it in place and lose lua_next.
                if (lua_type(L, -2) == LUA_TSTRING)
                {
                    size_t kn = 0;
                    const char* ks = lua_tolstring(L, -2, &kn);
                    key.assign(ks, kn);
                }
                else if (lua_type(L, -2) == LUA_TNUMBER)
                {
                    key = lua_isinteger(L, -2) ? std::to_string(lua_tointeger(L, -2)) : std::format("{}", lua_tonumber(L, -2));
                }
                else
                {
                    lua_pop(L, 2);
                    why = "a table key that isn't text or a number";
                    return false;
                }
                Json e;
                if (!json_of(L, -1, e, why, depth + 1))
                {
                    lua_pop(L, 2);
                    return false;
                }
                out.set(key, std::move(e));
                lua_pop(L, 1);
            }
            return true;
        }
        default: why = std::string("a ") + lua_typename(L, lua_type(L, i)) + " can't be JSON"; return false;
        }
    }

    // A property's value as Lua: a bool, a number, text (an enum by its name), an object by its name, a gameplay tag
    // as its name, a struct as {field = value}, an array as a list and a map as {[key] = value} (or a list of
    // {key, value} for keys that can't be a table's), each to a few levels deep and a few hundred elements; deeper
    // as the text Value::shown() gives.
    inline auto push_value(lua_State* L, const Value& v, int depth = 0) -> void;
    inline auto tag_name(const Value& v) -> std::optional<std::wstring>
    {
        if (v.kind != Value::Kind::Struct) return std::nullopt;
        auto members = wcmods::describe(v);
        if (members.size() == 1 && members[0].name == L"TagName") return members[0].value.string();
        return std::nullopt;
    }
    inline auto push_value(lua_State* L, const Value& v, int depth) -> void
    {
        constexpr int deepest = 4;
        constexpr size_t most = 256;
        if (!lua_checkstack(L, 6))
        {
            lua_pushnil(L);
            return;
        }
        switch (v.kind)
        {
        case Value::Kind::None: lua_pushnil(L); return;
        case Value::Kind::Bool: lua_pushboolean(L, v.b ? 1 : 0); return;
        case Value::Kind::Int: push_number(L, static_cast<double>(v.i)); return;
        case Value::Kind::Float: lua_pushnumber(L, v.f); return;
        case Value::Kind::Text: push(L, v.text); return;
        case Value::Kind::Enum:
            if (!v.text.empty()) push(L, v.text);
            else push_number(L, static_cast<double>(v.i));
            return;
        case Value::Kind::Object:
            if (v.object) push(L, wcmods::name(v.object));
            else lua_pushnil(L);
            return;
        case Value::Kind::Struct:
        {
            if (auto tag = tag_name(v))
            {
                push(L, *tag);
                return;
            }
            if (depth >= deepest) break;
            lua_newtable(L);
            for (const auto& m : wcmods::describe(v))
            {
                push(L, m.name);
                push_value(L, m.value, depth + 1);
                lua_rawset(L, -3);
            }
            return;
        }
        case Value::Kind::Array:
        {
            if (depth >= deepest) break;
            lua_newtable(L);
            lua_Integer i = 1;
            for (const Value& e : wcmods::elements(v))
            {
                if (static_cast<size_t>(i) > most) break;
                push_value(L, e, depth + 1);
                lua_rawseti(L, -2, i++);
            }
            return;
        }
        case Value::Kind::Map:
        {
            if (depth >= deepest) break;
            lua_newtable(L);
            lua_Integer i = 1;
            for (const auto& [k, e] : wcmods::map_entries(v))
            {
                if (static_cast<size_t>(i) > most) break;
                const bool keyed = k.kind == Value::Kind::Text || k.kind == Value::Kind::Enum || k.kind == Value::Kind::Int
                                   || (k.kind == Value::Kind::Struct && tag_name(k));
                if (keyed)
                {
                    push_value(L, k, depth + 1);
                    push_value(L, e, depth + 1);
                    lua_rawset(L, -3);
                }
                else
                {
                    lua_createtable(L, 0, 2);
                    push_value(L, k, depth + 1);
                    lua_setfield(L, -2, "key");
                    push_value(L, e, depth + 1);
                    lua_setfield(L, -2, "value");
                    lua_rawseti(L, -2, i);
                }
                ++i;
            }
            return;
        }
        default: break;
        }
        push(L, v.shown());
    }

    // A struct's fields in order, each {name, value}.
    inline auto push_fields(lua_State* L, const Value& v) -> void
    {
        lua_newtable(L);
        lua_Integer i = 1;
        for (const auto& m : wcmods::describe(v))
        {
            lua_createtable(L, 0, 2);
            field(L, "name", m.name);
            push_value(L, m.value, 1);
            lua_setfield(L, -2, "value");
            lua_rawseti(L, -2, i++);
        }
    }
} // namespace menu_pages
