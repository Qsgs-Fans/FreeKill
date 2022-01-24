#include "server_socket.h"
#include "client_socket.h"
#include <QTcpServer>

ServerSocket::ServerSocket()
{
    server = new QTcpServer(this);
    connect(server, &QTcpServer::newConnection,
            this, &ServerSocket::processNewConnection);
}

bool ServerSocket::listen(const QHostAddress &address, ushort port)
{
    return server->listen(address, port);
}

void ServerSocket::processNewConnection()
{
    QTcpSocket *socket = server->nextPendingConnection();
    ClientSocket *connection = new ClientSocket(socket);
    emit new_connection(connection);
}

