// SPDX-License-Identifier: GPL-3.0-or-later

#include "server_socket.h"
#include "client_socket.h"
#include "server.h"
#include "util.h"

ServerSocket::ServerSocket(QObject *parent) : QObject(parent) {
  server = new QTcpServer(this);
  connect(server, &QTcpServer::newConnection, this,
          &ServerSocket::processNewConnection);

  udpSocket = new QUdpSocket(this);
  connect(udpSocket, &QUdpSocket::readyRead,
          this, &ServerSocket::readPendingDatagrams);
}

bool ServerSocket::listen(const QHostAddress &address, ushort port) {
  udpSocket->bind(port);
  return server->listen(address, port);
}

void ServerSocket::processNewConnection() {
  QTcpSocket *socket = server->nextPendingConnection();
  ClientSocket *connection = new ClientSocket(socket);
  connect(connection, &ClientSocket::disconnected, this,
          [connection]() { connection->deleteLater(); });
  emit new_connection(connection);
}

void ServerSocket::readPendingDatagrams() {
  while (udpSocket->hasPendingDatagrams()) {
    QNetworkDatagram datagram = udpSocket->receiveDatagram();
    if (datagram.isValid()) {
      processDatagram(datagram.data(), datagram.senderAddress(), datagram.senderPort());
    }
  }
}

void ServerSocket::processDatagram(const QByteArray &msg, const QHostAddress &addr, uint port) {
  auto server = qobject_cast<Server *>(parent());
  if (msg == "fkDetectServer") {
    udpSocket->writeDatagram("me", addr, port);
  } else if (msg.startsWith("fkGetDetail,")) {
    udpSocket->writeDatagram(JsonArray2Bytes(QJsonArray({
            FK_VERSION,
            server->getConfig("iconUrl"),
            server->getConfig("description"),
            server->getConfig("capacity"),
            server->getPlayers().count(),
            msg.sliced(12).constData(),
            })), addr, port);
  }
  udpSocket->flush();
}
