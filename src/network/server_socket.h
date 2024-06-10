// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _SERVER_SOCKET_H
#define _SERVER_SOCKET_H

class ClientSocket;

// 只是对QTcpServer的简单封装
class ServerSocket : public QObject {
  Q_OBJECT

public:
  ServerSocket(QObject *parent = nullptr);

  bool listen(const QHostAddress &address = QHostAddress::Any, ushort port = 9527u);

signals:
  void new_connection(ClientSocket *socket);

private slots:
  // 新建一个ClientSocket，然后立刻交给Server相关函数处理。
  void processNewConnection();
  void readPendingDatagrams();

private:
  QTcpServer *server;
  QUdpSocket *udpSocket;  // 服务器列表页面显示服务器信息用
  void processDatagram(const QByteArray &msg, const QHostAddress &addr, uint port);
};

#endif // _SERVER_SOCKET_H
