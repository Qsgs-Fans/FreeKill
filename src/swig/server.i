%nodefaultctor Server;
%nodefaultdtor Server;
class Server : public QObject {
public:
    void createRoom(ServerPlayer *owner, const QString &name, int capacity);
    Room *findRoom(int id) const;
    ServerPlayer *findPlayer(int id) const;

    sqlite3 *getDatabase();

    LuaFunction callback;
    LuaFunction startRoom;
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

void Server::roomStart(Room *room) {
    Q_ASSERT(startRoom);

    lua_rawgeti(L, LUA_REGISTRYINDEX, startRoom);
    SWIG_NewPointerObj(L, this, SWIGTYPE_p_Server, 0);
    SWIG_NewPointerObj(L, room, SWIGTYPE_p_Room, 0);

    int error = lua_pcall(L, 2, 0, 0);
    if (error) {
        const char *error_msg = lua_tostring(L, -1);
        qDebug() << error_msg;
    }
}
    
%}

extern Server *ServerInstance;

%nodefaultctor Room;
%nodefaultdtor Room;
class Room : public QThread {
public:
    // Property reader & setter
    // ==================================={
    Server *getServer() const;
    int getId() const;
    bool isLobby() const;
    QString getName() const;
    void setName(const QString &name);
    int getCapacity() const;
    void setCapacity(int capacity);
    bool isFull() const;
    bool isAbandoned() const;

    ServerPlayer *getOwner() const;
    void setOwner(ServerPlayer *owner);

    void addPlayer(ServerPlayer *player);
    void removePlayer(ServerPlayer *player);
    QList<ServerPlayer *> getPlayers() const;
    ServerPlayer *findPlayer(int id) const;

    int getTimeout() const;

    bool isStarted() const;
    // ====================================}

    void doRequest(const QList<ServerPlayer *> targets, int timeout);
    void doNotify(const QList<ServerPlayer *> targets, int timeout);
    void doBroadcastNotify(
        const QList<ServerPlayer *> targets,
        const QString &command,
        const QString &jsonData
    );
    
    void gameOver();
};

