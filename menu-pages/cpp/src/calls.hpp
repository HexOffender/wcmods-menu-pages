// calls.hpp: WCModsCpp.menuPages's functions (calls.cpp), and the guard each runs through.
#pragma once

#include <exception>
#include <string>
#include <vector>

#include <lua.hpp>

#include <WCMods/Core.hpp>
#include <WCMods/Events.hpp>

namespace menu_pages
{
    // One of the table's functions: its name there, and the C function.
    struct Call
    {
        const char* name;
        lua_CFunction fn;
    };
    auto calls() -> const std::vector<Call>&;

    // Every call runs through this. Off the game thread it gives nil and why without touching the game (its objects
    // aren't safe there), unless `game_thread` is false for a call that reads none. A C++ exception becomes nil and
    // its message, never reaching Lua or the game. Only std::exception is caught: anything else could be Lua's own
    // error on its way up (a Lua built as C++ raises its errors as exceptions), which must go on to Lua.
    template <lua_CFunction Fn, bool game_thread = true>
    auto guard(lua_State* L) -> int
    {
        if (!lua_checkstack(L, 40)) return 0;   // no room for an answer: Lua reads nil
        if (game_thread && !wcmods::on_game_thread_now())
        {
            lua_pushnil(L);
            lua_pushstring(L, "called off the game thread: the game's objects aren't safe there");
            return 2;
        }
        try
        {
            return Fn(L);
        }
        catch (const std::exception& e)
        {
            lua_pushnil(L);
            const std::string why = std::string("C++ error: ") + e.what();
            lua_pushlstring(L, why.data(), why.size());
            return 2;
        }
    }
} // namespace menu_pages
