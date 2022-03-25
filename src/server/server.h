#ifndef _SERVER_H
#define _SERVER_H

#include <QObject>
#include <QHash>
#include <QMap>
#include <QHostAddress>
#include <lua.hpp>
#include <sqlite3.h>

class ServerSocket;
class ClientSocket;
class Room;
class ServerPlayer;

typedef int LuaFunction;

class Server : public QObject {
    Q_OBJECT

public:
    explicit Server(QObject *parent = nullptr);
    ~Server();

    bool listen(const QHostAddress &address = QHostAddress::Any, ushort port = 9527u);

    void createRoom(ServerPlayer *owner, const QString &name, uint capacity);
    Room *findRoom(uint id) const;
    Room *lobby() const;

    ServerPlayer *findPlayer(uint id) const;
    void removePlayer(uint id);

    void updateRoomList();

    void callLua(const QString &command, const QString &jsonData);
    LuaFunction callback;

    void roomStart(Room *room);
    LuaFunction startRoom;

signals:
    void roomCreated(Room *room);
    void playerAdded(ServerPlayer *player);
    void playerRemoved(ServerPlayer *player);

public slots:
    void processNewConnection(ClientSocket *client);
    void processRequest(const QByteArray &msg);

    void onRoomAbandoned();
    void onUserDisconnected();
    void onUserStateChanged();

private:
    ServerSocket *server;
    Room *m_lobby;
    QMap<uint, Room *> rooms;
    QHash<uint, ServerPlayer *> players;

    lua_State *L;
    sqlite3 *db;

    void handleNameAndPassword(ClientSocket *client, const QString &name, const QString &password);
};

extern Server *ServerInstance;

#endif // _SERVER_H
