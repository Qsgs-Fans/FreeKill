#include "serverplayer.h"
#include "room.h"
#include "server.h"
#include "router.h"
#include "client_socket.h"

ServerPlayer::ServerPlayer(Room *room)
{
    socket = nullptr;
    router = new Router(this, socket, Router::TYPE_SERVER);

    this->room = room;
    server = room->getServer();
}

ServerPlayer::~ServerPlayer()
{
    // clean up, quit room and server
    room->removePlayer(this);
    if (room != nullptr) {
        // now we are in lobby, so quit lobby
        room->removePlayer(this);
    }
    server->removePlayer(getId());
    router->deleteLater();
}

void ServerPlayer::setSocket(ClientSocket *socket)
{
    if (this->socket != nullptr) {
        this->socket->disconnect(this);
        disconnect(this->socket);
        this->socket->deleteLater();
    }

    this->socket = nullptr;
    if (socket != nullptr) {
        connect(socket, &ClientSocket::disconnected, this, &ServerPlayer::disconnected);
        this->socket = socket;
    }

    router->setSocket(socket);
}

Server *ServerPlayer::getServer() const
{
    return server;
}

Room *ServerPlayer::getRoom() const
{
    return room;
}

void ServerPlayer::setRoom(Room* room)
{
    this->room = room;
}

void ServerPlayer::speak(const QString& message)
{
    ;
}

void ServerPlayer::doRequest(const QString& command, const QString& jsonData, int timeout)
{
    int type = Router::TYPE_REQUEST | Router::SRC_SERVER | Router::DEST_CLIENT;
    router->request(type, command, jsonData, timeout);
}

QString ServerPlayer::waitForReply()
{
    return router->waitForReply();
}

QString ServerPlayer::waitForReply(int timeout)
{
    return router->waitForReply(timeout);
}

void ServerPlayer::doNotify(const QString& command, const QString& jsonData)
{
    int type = Router::TYPE_NOTIFICATION | Router::SRC_SERVER | Router::DEST_CLIENT;
    router->notify(type, command, jsonData);
}

void ServerPlayer::prepareForRequest(const QString& command, const QString& data)
{
    requestCommand = command;
    requestData = data;
}
