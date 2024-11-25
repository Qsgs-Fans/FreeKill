// SPDX-License-Identifier: GPL-3.0-or-later

// ------------------------------------------------------
// type bindings
// ------------------------------------------------------

%{
#include "core/c-wrapper.h"
#include "client/client.h"
#include "server/roomthread.h"

void Lua::pushValue(lua_State *L, QVariant v) {
  QVariantList list;
  QVariantMap map;
  auto typeId = v.typeId();
  switch (typeId) {
  case QMetaType::Bool:
    lua_pushboolean(L, v.toBool());
    break;
  case QMetaType::Int:
  case QMetaType::UInt:
    lua_pushinteger(L, v.toInt());
    break;
  case QMetaType::LongLong:
    lua_pushinteger(L, v.toLongLong());
    break;
  case QMetaType::Double:
    lua_pushnumber(L, v.toDouble());
    break;
  case QMetaType::QString: {
    auto bytes = v.toString().toUtf8();
    lua_pushstring(L, bytes.data());
    break;
  }
  case QMetaType::QByteArray: {
    lua_pushstring(L, v.toByteArray().data());
    break;
  }
  case QMetaType::QVariantList:
    lua_newtable(L);
    list = v.toList();
    for (int i = 1; i <= list.length(); i++) {
      lua_pushinteger(L, i);
      pushValue(L, list[i - 1]);
      lua_settable(L, -3);
    }
    break;
  case QMetaType::QVariantMap:
    lua_newtable(L);
    map = v.toMap();
    for (auto i = map.cbegin(), end = map.cend(); i != end; i++) {
      auto bytes = i.key().toUtf8();
      lua_pushstring(L, bytes.data());
      pushValue(L, i.value());
      lua_settable(L, -3);
    }
    break;
  case QMetaType::Nullptr:
  case QMetaType::UnknownType: // 应该是 undefined，感觉很危险
    lua_pushnil(L);
    break;
  default:
    // 继续判自定义MetaType，这些不能在case语句判
    if (typeId == QMetaType::fromType<Client *>().id()) {
      SWIG_NewPointerObj(L, v.value<Client *>(), SWIGTYPE_p_Client, 0);
    } else if (typeId == QMetaType::fromType<RoomThread *>().id()) {
      SWIG_NewPointerObj(L, v.value<RoomThread *>(), SWIGTYPE_p_RoomThread, 0);
    } else {
      qCritical() << "cannot handle QVariant type" << v.typeId();
      lua_pushnil(L);
    }
    break;
  }
}

QVariant Lua::readValue(lua_State *L, int index, QHash<const void *, bool> stack) {
  if (index == 0) index = lua_gettop(L);
  auto tp = lua_type(L, index);
  switch (tp) {
    case LUA_TNIL:
      return QVariant::fromValue(nullptr);
    case LUA_TBOOLEAN:
      return QVariant((bool)lua_toboolean(L, index));
    case LUA_TNUMBER:
      return QVariant(lua_tonumber(L, index));
    case LUA_TSTRING:
      return QVariant(lua_tostring(L, index));
    case LUA_TTABLE: {
      auto p = lua_topointer(L, index);
      if (stack[p]) {
        luaL_error(L, "circular reference detected");
        return QVariant(); // won't return
      }
      stack[p] = true;

      lua_len(L, index);
      int length = lua_tointeger(L, -1);
      lua_pop(L, 1);

      if (length == 0) {
        bool empty = true;
        QVariantMap map;

        lua_pushnil(L);
        while (lua_next(L, index) != 0) {
          if (lua_type(L, -2) != LUA_TSTRING) {
            luaL_error(L, "key of object must be string");
            return QVariant();
          }

          const char *key = lua_tostring(L, -2);
          auto value = readValue(L, lua_gettop(L), stack);
          lua_pop(L, 1);

          map[key] = value;
          empty = false;
        }

        if (empty) {
          return QVariantList();
        } else {
          return map;
        }
      } else {
        QVariantList arr;
        for (int i = 1; i <= length; i++) {
          lua_rawgeti(L, index, i);
          arr << readValue(L, lua_gettop(L), stack);
          lua_pop(L, 1);
        }
        return arr;
      }
      break;
    }

    // ignore function, userdata and thread
    default:
      luaL_error(L, "unexpected value type %s", lua_typename(L, tp));
  }
  return QVariant(); // won't return
}
%}

// Lua 5.4 特有的不能pushnumber， swig迟迟不更只好手动调教
%typemap(out) int
%{
lua_pushinteger(L, $1);
SWIG_arg ++;
%}

// QString and lua string
%naturalvar QString;

%typemap(in, checkfn = "lua_isstring") QString
%{ $1 = lua_tostring(L, $input); %}

%typemap(out) QString
%{
  // FIXME: 这里针对高频出现的字符串减少toUtf8调用避免创建新的bytearray...
  if ($1.isEmpty()) {
    lua_pushstring(L, "");
  } else if ($1 == "__notready") {
    lua_pushstring(L, "__notready");
  } else {
    lua_pushstring(L, $1.toUtf8());
  }
  SWIG_arg++;
%}

// const QString &

%typemap(in, checkfn = "lua_isstring") QString const & ($*1_ltype temp)
%{
  temp = QString::fromUtf8(lua_tostring(L, $input));
  $1 = &temp;
%}

%typemap(out) QString const &
%{
  if ($1.isEmpty()) {
    lua_pushstring(L, "");
  } else if ($1 == "__notready") {
    lua_pushstring(L, "__notready");
  } else {
    lua_pushstring(L, $1.toUtf8());
  }
  SWIG_arg++;
%}

// 解决函数重载中类型检测问题
%typecheck(SWIG_TYPECHECK_STRING) QString, QString const& {
  $1 = lua_isstring(L,$input);
}

// QStringList
%naturalvar QStringList;

/* 没有从lua传入QStringList的情况，注释！
%typemap(in, checkfn = "lua_istable") QStringList
%{
for (size_t i = 0; i < lua_rawlen(L, $input); ++i) {
  lua_rawgeti(L, $input, i + 1);
  const char *elem = luaL_checkstring(L, -1);
  $1 << QString::fromUtf8(QByteArray(elem));
  lua_pop(L, 1);
}
%}
*/

%typemap(out) QStringList
%{
lua_createtable(L, $1.length(), 0);

for (int i = 0; i < $1.length(); i++) {
  QString str = $1.at(i);
  auto bytes = str.toUtf8();
  lua_pushstring(L, bytes.constData());
  lua_rawseti(L, -2, i + 1);
}

SWIG_arg++;
%}

%typemap(typecheck) QStringList
%{
  $1 = lua_istable(L, $input) ? 1 : 0;
%}

// QByteArray: 仅out

%typemap(out) QByteArray
%{
  lua_pushstring(L, $1.constData());
  SWIG_arg++;
%}

// const QByteArray &: 仅in
%typemap(arginit) QByteArray const &
  "QByteArray $1_str;"

%typemap(in, checkfn = "lua_isstring") QByteArray const &
%{
  $1_str = QByteArray(lua_tostring(L, $input));
  $1 = &$1_str;
%}

// QVariant: 用于json，out
%typemap(out) QVariant
%{
  Lua::pushValue(L, $1);
  SWIG_arg++;
%}

// const QVariant &: 用于json，in
%typemap(arginit) QVariant const &
  "QVariant $1_var;"

%typemap(in) QVariant const &
%{
  $1_var = Lua::readValue(L, $input);
  $1 = &$1_var;
%}
