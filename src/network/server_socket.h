// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _SERVER_SOCKET_H
#define _SERVER_SOCKET_H

class ClientSocket;

class ServerSocket : public QObject {
  Q_OBJECT

public:
  ServerSocket();

  bool listen(const QHostAddress &address = QHostAddress::Any, ushort port = 9527u);

signals:
  void new_connection(ClientSocket *socket);

private slots:
  void processNewConnection();

private:
  QTcpServer *server;
};

#endif // _SERVER_SOCKET_H
