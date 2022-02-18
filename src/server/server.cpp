#include "server.h"
#include "server_socket.h"
#include "client_socket.h"
#include "room.h"
#include "serverplayer.h"

Server::Server(QObject* parent)
    : QObject(parent)
{
    server = new ServerSocket();
    server->setParent(this);
    connect(server, &ServerSocket::new_connection,
            this, &Server::processNewConnection);

    // create lobby
    createRoom(NULL, "Lobby", UINT32_MAX);
    connect(lobby(), &Room::playerAdded, this, &Server::updateRoomList);
}

Server::~Server()
{

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
    // TODO
    // room->addPlayer(owner);
    rooms.insert(room->getId(), room);
#ifdef QT_DEBUG
    qDebug() << "Room #" << room->getId() << " created.";
#endif
    emit roomCreated(room);
}

Room *Server::findRoom(uint id) const
{
    return rooms.value(id);
}

Room *Server::lobby() const
{
    return findRoom(0);
}

ServerPlayer *Server::findPlayer(uint id) const
{
    return players.value(id);
}

void Server::updateRoomList(ServerPlayer* user)
{
    // TODO
}

void Server::processNewConnection(ClientSocket* client)
{
    ServerPlayer *player = new ServerPlayer(lobby());
    player->setSocket(client);
#ifdef QT_DEBUG
    qDebug() << "ServerPlayer #" << player->getUid() << "connected.";
    qDebug() << "His address is " << client->peerAddress();
#endif

    player->doNotify("test", "{\"json\": \"lua\"}");

}

void Server::onRoomAbandoned()
{
    // TODO
}

void Server::onUserDisconnected()
{
    // TODO
}

void Server::onUserStateChanged()
{
    // TODO
}
