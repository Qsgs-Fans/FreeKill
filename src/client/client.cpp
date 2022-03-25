#include "client.h"
#include "client_socket.h"
#include "clientplayer.h"

Client *ClientInstance;
ClientPlayer *Self;

Client::Client(QObject* parent)
    : QObject(parent), callback(0)
{
    ClientInstance = this;
    Self = nullptr;

    ClientSocket *socket = new ClientSocket;
    connect(socket, &ClientSocket::error_message, this, &Client::error_message);
    router = new Router(this, socket, Router::TYPE_CLIENT);

    L = CreateLuaState();
    DoLuaScript(L, "lua/freekill.lua");
    DoLuaScript(L, "lua/client/client.lua");
}

Client::~Client()
{
    ClientInstance = nullptr;
    lua_close(L);
    router->getSocket()->disconnectFromHost();
    router->getSocket()->deleteLater();
}

void Client::connectToHost(const QHostAddress& server, ushort port)
{
    router->getSocket()->connectToHost(server, port);
}

void Client::replyToServer(const QString& command, const QString& jsonData)
{
    int type = Router::TYPE_REPLY | Router::SRC_CLIENT | Router::DEST_SERVER;
    router->reply(type, command, jsonData);
}

void Client::notifyServer(const QString& command, const QString& jsonData)
{
    int type = Router::TYPE_NOTIFICATION | Router::SRC_CLIENT | Router::DEST_SERVER;
    router->notify(type, command, jsonData);
}
