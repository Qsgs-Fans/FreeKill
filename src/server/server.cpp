#include "server.h"
#include "server_socket.h"
#include "client_socket.h"
#include "room.h"
#include "serverplayer.h"
#include "global.h"
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

Server *ServerInstance;

Server::Server(QObject* parent)
    : QObject(parent)
{
    ServerInstance = this;
    server = new ServerSocket();
    server->setParent(this);
    connect(server, &ServerSocket::new_connection,
            this, &Server::processNewConnection);

    // create lobby
    createRoom(NULL, "Lobby", UINT32_MAX);
    connect(lobby(), &Room::playerAdded, this, &Server::updateRoomList);

    L = CreateLuaState();
    DoLuaScript(L, "lua/freekill.lua");
    DoLuaScript(L, "lua/server/server.lua");
}

Server::~Server()
{
    ServerInstance = nullptr;
}

bool Server::listen(const QHostAddress& address, ushort port)
{
    return server->listen(address, port);
}

void Server::createRoom(ServerPlayer* owner, const QString &name, uint capacity)
{
    Room *room = new Room(this);
    connect(room, &Room::abandoned, this, &Server::onRoomAbandoned);
    room->setName(name);
    room->setCapacity(capacity);
    room->setOwner(owner);
    room->addPlayer(owner);
    if (room->isLobby())
        m_lobby = room;
    else
        rooms.insert(room->getId(), room);
#ifdef QT_DEBUG
    qDebug() << "Room #" << room->getId() << " created.";
#endif
}

Room *Server::findRoom(uint id) const
{
    return rooms.value(id);
}

Room *Server::lobby() const
{
    return m_lobby;
}

ServerPlayer *Server::findPlayer(uint id) const
{
    return players.value(id);
}

void Server::updateRoomList()
{
    QJsonArray arr;
    foreach (Room *room, rooms) {
        QJsonArray obj;
        obj << (int)room->getId();  // roomId
        obj << room->getName();     // roomName
        obj << "Role";              // gameMode
        obj << room->getPlayers().count();  // playerNum
        obj << (int)room->getCapacity();    // capacity
        arr << obj;
    }
    lobby()->doBroadcastNotify(
        lobby()->getPlayers(),
        "UpdateRoomList",
        QJsonDocument(arr).toJson()
    );
}

void Server::processNewConnection(ClientSocket* client)
{
    // version check, file check, ban IP, reconnect, etc
    ServerPlayer *player = new ServerPlayer(lobby());
    player->setSocket(client);
    players.insert(player->getUid(), player);
#ifdef QT_DEBUG
    qDebug() << "ServerPlayer #" << player->getUid() << "connected.";
    qDebug() << "His address is " << client->peerAddress();
#endif

    lobby()->addPlayer(player);
}

void Server::onRoomAbandoned()
{
    Room *room = qobject_cast<Room *>(sender());
    rooms.remove(room->getId());
    updateRoomList();
    room->deleteLater();
}

void Server::onUserDisconnected()
{
    qobject_cast<ServerPlayer *>(sender())->setStateString("offline");
}

void Server::onUserStateChanged()
{
    // TODO
}
