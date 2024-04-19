// SPDX-License-Identifier: GPL-3.0-or-later

%nodefaultctor QmlBackend;
%nodefaultdtor QmlBackend;
class QmlBackend : public QObject {
public:
  void notifyUI(const QString &command, const QVariant &data);
  static void cd(const QString &path);
  static QStringList ls(const QString &dir);
  static QString pwd();
  static bool exists(const QString &file);
  static bool isDir(const QString &file);
};

extern QmlBackend *Backend;

%nodefaultctor Client;
%nodefaultdtor Client;
class Client : public QObject {
public:
  void replyToServer(const QString &command, const QString &json_data);
  void notifyServer(const QString &command, const QString &json_data);

  LuaFunction callback;

  ClientPlayer *addPlayer(int id, const QString &name, const QString &avatar);
  void removePlayer(int id);
  void changeSelf(int id);

  void saveRecord(const QString &json, const QString &fname);
};

extern Client *ClientInstance;

%{
void Client::callLua(const QString& command, const QString& json_data, bool isRequest)
{
  Q_ASSERT(callback);

  lua_getglobal(L, "debug");
  lua_getfield(L, -1, "traceback");
  lua_replace(L, -2);

  lua_rawgeti(L, LUA_REGISTRYINDEX, callback);
  SWIG_NewPointerObj(L, this, SWIGTYPE_p_Client, 0);
  lua_pushstring(L, command.toUtf8());
  lua_pushstring(L, json_data.toUtf8());
  lua_pushboolean(L, isRequest);

  int error = lua_pcall(L, 4, 0, -6);

  if (error) {
    const char *error_msg = lua_tostring(L, -1);
    qCritical() << error_msg;
    lua_pop(L, 2);
  }
  lua_pop(L, 1);
}
%}
