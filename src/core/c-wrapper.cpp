#include "c-wrapper.h"
#include <lua.hpp>

extern "C" {
int luaopen_fk(lua_State *);
}

// 基于RAII的栈清理工具 这样就懒得写lua_pop了
// 但是目前仍在TODO
class StackCleaner {
public:
  StackCleaner(lua_State *l): L(l) {}
  ~StackCleaner() {
  }
private:
  lua_State *L;
};

Lua::Lua() {
  L = luaL_newstate();
  luaL_openlibs(L);
  luaopen_fk(L);
}

Lua::~Lua() {
  lua_close(L);
}

bool Lua::dofile(const char *path) {
  lua_getglobal(L, "debug");
  lua_getfield(L, -1, "traceback");
  lua_replace(L, -2);

  luaL_loadfile(L, path);
  int error = lua_pcall(L, 0, LUA_MULTRET, -2);

  if (error) {
    const char *error_msg = lua_tostring(L, -1);
    qCritical() << error_msg;
    lua_pop(L, 2);
    return false;
  }
  lua_pop(L, 1);
  return true;
}

void Lua::dumpStack() {
  int top = lua_gettop(L);
  for (int i = 1; i <= top; i++) {
    printf("%d\t%s\t", i, luaL_typename(L, i));
    switch (lua_type(L, i)) {
    case LUA_TNUMBER:
      printf("%g\n", lua_tonumber(L, i));
      break;
    case LUA_TSTRING:
      printf("%s\n", lua_tostring(L, i));
      break;
    case LUA_TBOOLEAN:
      printf("%s\n", (lua_toboolean(L, i) ? "true" : "false"));
      break;
    case LUA_TNIL:
      printf("%s\n", "nil");
      break;
    default:
      printf("%p\n", lua_topointer(L, i));
      break;
    }
  }
}

QVariant Lua::call(const QString &func_name, QVariantList params) {
  lua_getglobal(L, "debug");
  lua_getfield(L, -1, "traceback");
  lua_replace(L, -2);

  lua_getglobal(L, func_name.toLatin1().data());

  foreach (QVariant v, params) {
    pushValue(L, v);
  }

  int err = lua_pcall(L, params.length(), 1, -params.length() - 2);
  if (err) {
    qCritical() << lua_tostring(L, -1);
    lua_pop(L, 2);
    return QVariant();
  }
  auto result = readValue(L);
  lua_pop(L, 1);

  return result;
}

QVariant Lua::eval(const QString &lua) {
  int err;
  err = luaL_loadstring(L, lua.toUtf8().constData());
  if (err != LUA_OK) {
    qCritical() << lua_tostring(L, -1);
    lua_pop(L, 1);
    return "";
  }
  err = lua_pcall(L, 0, 1, 0);
  if (err) {
    qCritical() << lua_tostring(L, -1);
    lua_pop(L, 1);
    return QVariant();
  }
  auto result = readValue(L);
  lua_pop(L, 1);

  return result;
}
