#ifndef _GLOBAL_H
#define _GLOBAL_H

#include <lua.hpp>

// utilities
typedef int LuaFunction;

lua_State *CreateLuaState();
bool DoLuaScript(lua_State *L, const char *script);

#endif // _GLOBAL_H
