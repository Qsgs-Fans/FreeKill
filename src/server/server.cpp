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
    m_lobby->deleteLater();
    lua_close(L);
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
    qDebug() << client->peerAddress() << "connected";
    // version check, file check, ban IP, reconnect, etc

    connect(client, &ClientSocket::disconnected, this, [client](){
        qDebug() << client->peerAddress() << "disconnected";
    });

    // network delay test
    QJsonArray body;
    body << -2;
    body << (Router::TYPE_NOTIFICATION | Router::SRC_SERVER | Router::DEST_CLIENT);
    body << "NetworkDelayTest";
    body << "[]";
    client->send(QJsonDocument(body).toJson(QJsonDocument::Compact));
    // Note: the client should send a setup string next
    connect(client, &ClientSocket::message_got, this, &Server::processRequest);
    client->timerSignup.start(30000);
}

void Server::processRequest(const QByteArray& msg)
{
    ClientSocket *client = qobject_cast<ClientSocket *>(sender());
    client->disconnect(this, SLOT(processRequest(const QByteArray &)));
    client->timerSignup.stop();

    bool valid = true;
    QJsonDocument doc = QJsonDocument::fromJson(msg);
    if (doc.isNull() || !doc.isArray()) {
        valid = false;
    } else {
        if (doc.array().size() != 4
            || doc[0] != -2
            || doc[1] != (Router::TYPE_NOTIFICATION | Router::SRC_CLIENT | Router::DEST_SERVER)
            || doc[2] != "Setup"
        )
            valid = false;
        else
            valid = (QJsonDocument::fromJson(doc[3].toString().toUtf8()).array().size() == 2);
    }

    if (!valid) {
        qDebug() << "Invalid setup string:" << msg;
        QJsonArray body;
        body << -2;
        body << (Router::TYPE_NOTIFICATION | Router::SRC_SERVER | Router::DEST_CLIENT);
        body << "ErrorMsg";
        body << "INVALID SETUP STRING";
        client->send(QJsonDocument(body).toJson(QJsonDocument::Compact));
        client->disconnectFromHost();
        return;
    }

    ServerPlayer *player = new ServerPlayer(lobby());
    player->setSocket(client);
    client->disconnect(this);
    connect(client, &ClientSocket::disconnected, this, [player](){
        qDebug() << "Player" << player->getUid() << "disconnected";
    });
    QJsonArray arr = QJsonDocument::fromJson(doc[3].toString().toUtf8()).array();
    player->setScreenName(arr[0].toString());
    player->setAvatar(arr[1].toString());
    players.insert(player->getUid(), player);
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
