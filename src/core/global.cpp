#include "global.h"
#include <QtCore>

extern "C" {
    int luaopen_freekill(lua_State *);
}

lua_State *CreateLuaState()
{
    lua_State *L = luaL_newstate();
    luaL_openlibs(L);
    luaopen_freekill(L);

    return L;
}

bool DoLuaScript(lua_State *L, const char *script)
{
    int error = luaL_dofile(L, script);
    if (error) {
        QString error_msg = lua_tostring(L, -1);
        qDebug() << error_msg;
        return false;
    }
    return true;
}

