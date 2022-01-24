#include "serverplayer.h"
#include "room.h"
#include "server.h"

ServerPlayer::ServerPlayer(Room *room)
    : uid(0)
{
    static int m_playerid = 0;
    m_playerid++;

    uid = m_playerid;

    socket = nullptr;
    router = new Router(this, socket, Router::TYPE_SERVER);

    this->room = room;
}

ServerPlayer::~ServerPlayer()
{
    router->deleteLater();
}

uint ServerPlayer::getUid() const
{
    return uid;
}

void ServerPlayer::setSocket(ClientSocket *socket)
{
    this->socket = socket;
    router->setSocket(socket);
}

Server *ServerPlayer::getServer() const
{
    return room->getServer();
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

void ServerPlayer::doRequest(const QString& command, const QString& json_data, int timeout)
{
    int type = Router::TYPE_REQUEST | Router::SRC_SERVER | Router::DEST_CLIENT;
    router->request(type, command, json_data, timeout);
}

void ServerPlayer::doReply(const QString& command, const QString& json_data)
{
    int type = Router::TYPE_REPLY | Router::SRC_SERVER | Router::DEST_CLIENT;
    router->reply(type, command, json_data);
}

void ServerPlayer::doNotify(const QString& command, const QString& json_data)
{
    int type = Router::TYPE_NOTIFICATION | Router::SRC_SERVER | Router::DEST_CLIENT;
    router->notify(type, command, json_data);
}

void ServerPlayer::prepareForRequest(const QString& command, const QVariant& data)
{
    ;
}
