#ifndef _LUA_WRAPPER_H
#define _LUA_WRAPPER_H

// 为C库提供一层C++包装 方便操作
// 主要是lua和sqlite

struct lua_State;
struct sqlite3;

class LuaInterface {
public:
  // LuaInterface() {}
  virtual ~LuaInterface() {}

  virtual bool dofile(const char *path) = 0;
  virtual QVariant call(const QString &func_name,
                        QVariantList params = QVariantList()) = 0;
  virtual QVariant eval(const QString &lua) = 0;
};

class Lua : public LuaInterface {
public:
  Lua();
  Lua(Lua &) = delete;
  Lua(Lua &&) = delete;
  ~Lua();

  bool dofile(const char *path);
  void dumpStack();

  // 之所以static是因为swig的naturalvar环节处理QVariant需要
  // 函数的定义在naturalvar.i中
  static void pushValue(lua_State *L, QVariant v);
  static QVariant
  readValue(lua_State *L, int index = 0,
            QHash<const void *, bool> stack = QHash<const void *, bool>());

  QVariant call(const QString &func_name, QVariantList params = QVariantList());
  QVariant eval(const QString &lua);

private:
  lua_State *L;
  QMutex interpreter_lock;
  QThread *current_thread = nullptr;

  bool needLock();
};

class Sqlite3 {
public:
  Sqlite3(const QString &filename = QStringLiteral("./server/users.db"),
          const QString &initSql = QStringLiteral("./server/init.sql"));
  Sqlite3(Sqlite3 &) = delete;
  Sqlite3(Sqlite3 &&) = delete;
  ~Sqlite3();

  static bool checkString(const QString &str);

  typedef QList<QMap<QString, QString>> QueryResult;
  QueryResult select(const QString &sql);
  QString selectJson(const QString &sql);
  void exec(const QString &sql);

  quint64 getMemUsage();

private:
  sqlite3 *db;
  std::unique_ptr<QLockFile> locker;
};

#endif // _LUA_WRAPPER_H
