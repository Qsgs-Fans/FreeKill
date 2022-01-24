%module freekill

%{
#include "client.h"
#include "server.h"
#include "serverplayer.h"
#include "clientplayer.h"
#include "room.h"
#include "qmlbackend.h"
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

class QThread {};

class QmlBackend : public QObject {
public:
    void emitNotifyUI(const char *command, const char *json_data);
};

extern QmlBackend *Backend;

class Client : public QObject {
public:
    void requestServer(const QString &command,
                   const QString &json_data, int timeout = -1);
    void replyToServer(const QString &command, const QString &json_data);
    void notifyServer(const QString &command, const QString &json_data);

    LuaFunction callback;
};

extern Client *ClientInstance;

%{
void Client::callLua(const QString& command, const QString& json_data)
{
    Q_ASSERT(callback);

    lua_rawgeti(L, LUA_REGISTRYINDEX, callback);
    SWIG_NewPointerObj(L, this, SWIGTYPE_p_Client, 0);
    lua_pushstring(L, command.toUtf8());
    lua_pushstring(L, json_data.toUtf8());

    int error = lua_pcall(L, 3, 0, 0);
    if (error) {
        const char *error_msg = lua_tostring(L, -1);
        qDebug() << error_msg;
    }
}
%}

class Server : public QObject {
public:
    void createRoom(ServerPlayer *owner, const QString &name, unsigned int capacity);
    Room *findRoom(unsigned int id) const;
    Room *lobby() const;

    ServerPlayer *findPlayer(unsigned int id) const;

    void updateRoomList(ServerPlayer *user);

    LuaFunction callback;
};

%{
void Server::callLua(const QString& command, const QString& json_data)
{
    Q_ASSERT(callback);

    lua_rawgeti(L, LUA_REGISTRYINDEX, callback);
    SWIG_NewPointerObj(L, this, SWIGTYPE_p_Server, 0);
    lua_pushstring(L, command.toUtf8());
    lua_pushstring(L, json_data.toUtf8());

    int error = lua_pcall(L, 3, 0, 0);
    if (error) {
        const char *error_msg = lua_tostring(L, -1);
        qDebug() << error_msg;
    }
}
%}

extern Server *ServerInstance;

class Player : public QObject {
    enum State{
        Invalid,
        Online,
        Trust,
        Offline
    };

    unsigned int getId() const;
    void setId(unsigned int id);

    QString getScreenName() const;
    void setScreenName(const QString &name);

    QString getAvatar() const;
    void setAvatar(const QString &avatar);

    State getState() const;
    QString getStateString() const;
    void setState(State state);
    void setStateString(const QString &state);

    bool isReady() const;
    void setReady(bool ready);
};

class ClientPlayer : public Player {
public:
    ClientPlayer(unsigned int id, QObject *parent = nullptr);
    ~ClientPlayer();
};

extern ClientPlayer *Self;

class ServerPlayer : public Player {
public:
    explicit ServerPlayer(Room *room);
    ~ServerPlayer();

    unsigned int getUid() const;

    void setSocket(ClientSocket *socket);

    Server *getServer() const;
    Room *getRoom() const;
    void setRoom(Room *room);

    void speak(const QString &message);

    void doRequest(const QString &command,
                   const QString &json_data, int timeout = -1);
    void doReply(const QString &command, const QString &json_data);
    void doNotify(const QString &command, const QString &json_data);

    void prepareForRequest(const QString &command,
                           const QVariant &data = QVariant());
};

class Room : public QThread {
public:
    explicit Room(Server *m_server);
    ~Room();

    // Property reader & setter
    // ==================================={
    Server *getServer() const;
    unsigned int getId() const;
    bool isLobby() const;
    QString getName() const;
    void setName(const QString &name);
    unsigned int getCapacity() const;
    void setCapacity(unsigned int capacity);
    bool isFull() const;
    bool isAbandoned() const;

    ServerPlayer *getOwner() const;
    void setOwner(ServerPlayer *owner);

    void addPlayer(ServerPlayer *player);
    void removePlayer(ServerPlayer *player);
    QHash<unsigned int, ServerPlayer*> getPlayers() const;
    ServerPlayer *findPlayer(unsigned int id) const;

    void setGameLogic(GameLogic *logic);
    GameLogic *getGameLogic() const;
    // ====================================}

    void startGame();
    void doRequest(const QList<ServerPlayer *> targets, int timeout);
    void doNotify(const QList<ServerPlayer *> targets, int timeout);
};
