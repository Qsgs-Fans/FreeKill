#ifndef _ROOM_H
#define _ROOM_H

class Server;
class ServerPlayer;

class Room : public QThread {
    Q_OBJECT
public:
    explicit Room(Server *m_server);
    ~Room();

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
    QList<ServerPlayer*> getPlayers() const;
    QList<ServerPlayer *> getOtherPlayers(ServerPlayer *expect) const;
    ServerPlayer *findPlayer(int id) const;

    int getTimeout() const;
    void setTimeout(int timeout);

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

    lua_State *getLuaState() const;

    void initLua();
    void callLua(const QString &command, const QString &jsonData);
    LuaFunction callback;

    void roomStart();
    LuaFunction startGame;

signals:
    void abandoned();

    void playerAdded(ServerPlayer *player);
    void playerRemoved(ServerPlayer *player);

protected:
    virtual void run();

private:
    Server *server;
    int id;       // Lobby's id is 0
    QString name;   // “阴间大乱斗”
    int capacity;   // by default is 5, max is 8
    bool m_abandoned;   // If room is empty, delete it

    ServerPlayer *owner;    // who created this room?
    QList<ServerPlayer *> players;
    bool gameStarted;

    int timeout;

    lua_State *L;
};

#endif // _ROOM_H
