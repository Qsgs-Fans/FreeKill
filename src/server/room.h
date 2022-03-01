#ifndef _ROOM_H
#define _ROOM_H

#include <QThread>
#include <QList>
class Server;
class ServerPlayer;
class GameLogic;

class Room : public QThread {
    Q_OBJECT
public:
    explicit Room(Server *m_server);
    ~Room();

    // Property reader & setter
    // ==================================={
    Server *getServer() const;
    uint getId() const;
    bool isLobby() const;
    QString getName() const;
    void setName(const QString &name);
    uint getCapacity() const;
    void setCapacity(uint capacity);
    bool isFull() const;
    bool isAbandoned() const;

    ServerPlayer *getOwner() const;
    void setOwner(ServerPlayer *owner);

    void addPlayer(ServerPlayer *player);
    void removePlayer(ServerPlayer *player);
    QList<ServerPlayer*> getPlayers() const;
    ServerPlayer *findPlayer(uint id) const;

    void setGameLogic(GameLogic *logic);
    GameLogic *getGameLogic() const;
    // ====================================}

    void startGame();
    void doRequest(const QList<ServerPlayer *> targets, int timeout);
    void doNotify(const QList<ServerPlayer *> targets, int timeout);

    void doBroadcastNotify(
        const QList<ServerPlayer *> targets,
        const QString &command,
        const QString &json_data
    );

signals:
    void abandoned();

    void aboutToStart();
    void started();
    void finished();

    void playerAdded(ServerPlayer *player);
    void playerRemoved(ServerPlayer *player);

protected:
    virtual void run();

private:
    Server *server;
    uint id;       // Lobby's id is 0
    QString name;   // “阴间大乱斗”
    uint capacity;   // by default is 5, max is 8
    bool m_abandoned;   // If room is empty, delete it

    ServerPlayer *owner;    // who created this room?
    QList<ServerPlayer *> players;
    GameLogic *logic;
};

#endif // _ROOM_H
