#include "c-wrapper.h"
#include <lua.hpp>
#include <sqlite3.h>

extern "C" {
int luaopen_fk(lua_State *);
}

Lua::Lua() {
  L = luaL_newstate();
  luaL_openlibs(L);
  luaopen_fk(L);
}

Lua::~Lua() {
  lua_close(L);
}

bool Lua::needLock() {
  auto thr = QThread::currentThread();
  bool ret = false;
  if (current_thread != thr) {
    current_thread = thr;
    ret = true;
  }
  return ret;
}

bool Lua::dofile(const char *path) {
  QMutexLocker locker(needLock() ? &interpreter_lock : nullptr);

  lua_getglobal(L, "debug");
  lua_getfield(L, -1, "traceback");
  lua_replace(L, -2);

  luaL_loadfile(L, path);
  int error = lua_pcall(L, 0, 0, -2);

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
  QMutexLocker locker(needLock() ? &interpreter_lock : nullptr);

  lua_getglobal(L, "debug");
  lua_getfield(L, -1, "traceback");
  lua_replace(L, -2);

  auto nargs = params.length();
  lua_getglobal(L, func_name.toLatin1().data());

  for (auto v : params) {
    pushValue(L, v);
  }

  // handler位于function位置的前一个
  int err = lua_pcall(L, nargs, 1, -nargs - 2);
  if (err) {
    qCritical() << lua_tostring(L, -1);
    lua_pop(L, 2);
    return QVariant();
  }
  auto result = readValue(L);
  lua_pop(L, 2);

  return result;
}

QVariant Lua::eval(const QString &lua) {
  QMutexLocker locker(needLock() ? &interpreter_lock : nullptr);

  lua_getglobal(L, "debug");
  lua_getfield(L, -1, "traceback");
  lua_replace(L, -2);

  int err;
  err = luaL_loadstring(L, lua.toUtf8().constData());
  if (err != LUA_OK) {
    qCritical() << lua_tostring(L, -1);
    lua_pop(L, 2);
    return QVariant();
  }
  err = lua_pcall(L, 0, 1, -2);
  if (err) {
    qCritical() << lua_tostring(L, -1);
    lua_pop(L, 2);
    return QVariant();
  }
  auto result = readValue(L);
  lua_pop(L, 2);

  return result;
}

// -----------------------------------------------------------------------

Sqlite3::Sqlite3(const QString &filename, const QString &initSql) {
  int rc;

  QFile file(initSql);
  if (!file.open(QIODevice::ReadOnly)) {
    qFatal("cannot open %s. Quit now.", initSql.toUtf8().data());
    qApp->exit(1);
  }
  QTextStream in(&file);

  if (!QFile::exists(filename)) {
    char *err_msg;
    sqlite3_open(filename.toLatin1().data(), &db);
    rc = sqlite3_exec(db, in.readAll().toLatin1().data(), nullptr, nullptr,
                      &err_msg);

    if (rc != SQLITE_OK) {
      qCritical() << "sqlite error:" << err_msg;
      sqlite3_free(err_msg);
      sqlite3_close(db);
      qApp->exit(1);
    }
  } else {
    rc = sqlite3_open(filename.toLatin1().data(), &db);
    if (rc != SQLITE_OK) {
      qCritical() << "Cannot open database:" << sqlite3_errmsg(db);
      sqlite3_close(db);
      qApp->exit(1);
    }

    char *err_msg;
    rc = sqlite3_exec(db, in.readAll().toLatin1().data(), nullptr, nullptr,
                      &err_msg);

    if (rc != SQLITE_OK) {
      qCritical() << "sqlite error:" << err_msg;
      sqlite3_free(err_msg);
      sqlite3_close(db);
      qApp->exit(1);
    }
  }
}

Sqlite3::~Sqlite3() {
  sqlite3_close(db);
}

bool Sqlite3::checkString(const QString &str) {
  static const QRegularExpression exp("['\";#* /\\\\?<>|:]+|(--)|(/\\*)|(\\*/)|(--\\+)");
  return (!exp.match(str).hasMatch());
}

// callback for handling SELECT expression
static int callback(void *jsonDoc, int argc, char **argv, char **cols) {
  QMap<QString, QString> obj;
  for (int i = 0; i < argc; i++) {
    obj[cols[i]] = argv[i] ? argv[i] : "#null";
  }
  ((Sqlite3::QueryResult *)jsonDoc)->append(obj);
  return 0;
}

Sqlite3::QueryResult Sqlite3::select(const QString &sql) {
  static QMutex select_lock;
  QueryResult arr;
  char *err = NULL;
  auto bytes = sql.toUtf8();
  QMutexLocker locker(&select_lock);
  sqlite3_exec(db, bytes.data(), callback, (void *)&arr, &err);
  if (err) {
    qCritical() << err;
    sqlite3_free(err);
  }
  return arr;
}

QString Sqlite3::selectJson(const QString &sql) {
  auto ret = select(sql);
  QJsonArray arr;
  for (auto map : ret) {
    QJsonObject obj;
    for (auto i = map.cbegin(), end = map.cend(); i != end; i++) {
      obj[i.key()] = i.value();
    }
    arr.append(obj);
  }
  return QJsonDocument(arr).toJson(QJsonDocument::Compact);
}

void Sqlite3::exec(const QString &sql) {
  auto bytes = sql.toUtf8();
  sqlite3_exec(db, bytes.data(), nullptr, nullptr, nullptr);
}

quint64 Sqlite3::getMemUsage() {
  return sqlite3_memory_used();
}
