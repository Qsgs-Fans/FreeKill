#include <QRandomGenerator>
#include <QVariant>

extern "C" {
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
}

// 元表名称
static const char *QRandomGenerator_MT = "QRandomGenerator";

// 创建新的QRandomGenerator对象
static int qrandomgen_new(lua_State *L) {
  unsigned int seed = luaL_optinteger(L, 1, 1);
  QRandomGenerator **ud = (QRandomGenerator **)lua_newuserdata(L, sizeof(QRandomGenerator *));
  *ud = new QRandomGenerator(seed);

  // 设置元表
  luaL_getmetatable(L, QRandomGenerator_MT);
  lua_setmetatable(L, -2);

  return 1;
}

// 调用random方法
static int qrandomgen_random(lua_State *L) {
  QRandomGenerator *gen = *(QRandomGenerator **)luaL_checkudata(L, 1, QRandomGenerator_MT);

  int low = luaL_optinteger(L, 2, -1);
  int high = luaL_optinteger(L, 3, -1);

  if (high < 0) {
    if (low < 1) {
      // 返回0-1之间的随机浮点数
      double val = gen->bounded(0, 100000001) / 100000000.0;
      lua_pushnumber(L, val);
    } else {
      // 返回1-low之间的随机整数
      int val = gen->bounded(1, low + 1);
      lua_pushinteger(L, val);
    }
  } else {
    // 返回low-high之间的随机整数
    int val = gen->bounded(low, high + 1);
    lua_pushinteger(L, val);
  }

  return 1;
}

// GC方法
static int qrandomgen_gc(lua_State *L) {
  QRandomGenerator *gen = *(QRandomGenerator **)luaL_checkudata(L, 1, QRandomGenerator_MT);
  delete gen;
  return 0;
}

// 元表方法
static const luaL_Reg qrandomgen_meta[] = {
  {"random", qrandomgen_random},
  {"__gc", qrandomgen_gc},
  {NULL, NULL}
};

// 模块方法
static const luaL_Reg qrandomgen_lib[] = {
  {"new", qrandomgen_new},
  {NULL, NULL}
};

// 注册模块
extern "C" int luaopen_qrandomgen(lua_State *L) {
  // 创建元表
  luaL_newmetatable(L, QRandomGenerator_MT);

  // 设置元表方法
  luaL_setfuncs(L, qrandomgen_meta, 0);

  // 设置元表索引
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");

  // 创建模块表
  luaL_newlib(L, qrandomgen_lib);

  return 1;
}
