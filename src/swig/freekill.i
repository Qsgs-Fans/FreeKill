%module freekill

%{
#include "client.h"
#include "server.h"
#include "room.h"
%}

// ------------------------------------------------------
// type bindings
// ------------------------------------------------------

// LuaFunction(int) and lua function
%naturalvar LuaFunction;
%typemap(in) LuaFunction
%{
if (lua_isfunction(L, $input)) {
    lua_pushvalue(L, $input);
    $1 = luaL_ref(L, LUA_REGISTRYINDEX);
} else {
    $1 = 0;
}
%}

%typemap(out) LuaFunction
%{
lua_rawgeti(L, LUA_REGISTRYINDEX, $1);
SWIG_arg ++;
%}

// QString and lua string
%naturalvar QString;

%typemap(in, checkfn = "lua_isstring") QString
%{ $1 = lua_tostring(L, $input); %}

%typemap(out) QString
%{ lua_pushstring(L, $1.toUtf8()); SWIG_arg++; %}

// const QString &
%typemap(in, checkfn = "lua_isstring") QString const &
%{
    if (1) {    // to avoid 'Jump bypasses variable initialization' error
        QString $1_str = QString::fromUtf8(lua_tostring(L, $input));
        $1 = &$1_str;
    }
%}

%typemap(out) QString const &
%{ lua_pushstring(L, $1.toUtf8()); SWIG_arg++; %}

// ------------------------------------------------------
// classes and functions
// ------------------------------------------------------

class QObject {
public:
    QString objectName();
    void setObjectName(const char *name);
    bool inherits(const char *class_name);
    bool setProperty(const char *name, const QVariant &value);
    QVariant property(const char *name) const;
    void setParent(QObject *parent);
    void deleteLater();
};

class Client : public QObject {
public:
    void requestServer(const QString &command,
                   const QString &json_data, int timeout = -1);
    void replyToServer(const QString &command, const QString &json_data);
    void notifyServer(const QString &command, const QString &json_data);
};

extern Client *ClientInstance;

class Server : public QObject {
public:
    void createRoom(ServerPlayer *owner, const QString &name, uint capacity);
    Room *findRoom(uint id) const;
    Room *lobby() const;

    ServerPlayer *findPlayer(uint id) const;

    void updateRoomList(ServerPlayer *user);
};

extern Server *ServerInstance;
