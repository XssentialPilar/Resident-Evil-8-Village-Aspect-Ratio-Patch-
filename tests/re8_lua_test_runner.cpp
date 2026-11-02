extern "C" {
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
}
#include <iostream>
int main(int argc, char** argv) {
    if (argc != 3) return 2;
    auto* state = luaL_newstate();
    if (!state) return 3;
    luaL_openlibs(state);
    lua_pushstring(state, argv[2]);
    lua_setglobal(state, "display_script_path");
    const int status = luaL_dofile(state, argv[1]);
    if (status != LUA_OK) std::cerr << lua_tostring(state, -1) << '\n';
    lua_close(state);
    return status == LUA_OK ? 0 : 1;
}
