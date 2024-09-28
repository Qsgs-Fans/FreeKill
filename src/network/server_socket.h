// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _SERVER_SOCKET_H
#define _SERVER_SOCKET_H

class ClientSocket;

/**
  \brief 向Server转达新的连接请求，并负责显示服务器信息。

  ServerSocket是对QTcpServer与QUdpSocket的封装。

  功能有：
  - 当接受到TCP连接请求时，创建新的\ref ClientSocket 并向\ref Server 发送信号。
  - 当接受到格式正确的UDP报文时，发回关于服务器的信息。
*/
class ServerSocket : public QObject {
  Q_OBJECT

public:
  /**
    创建新的ServerSocket对象。

    仅用于\ref Server 的构造函数中，作为Server的一个子成员。
   */
  ServerSocket(QObject *parent = nullptr);

  /// 监听端口port，TCP和UDP的都监听
  bool listen(const QHostAddress &address = QHostAddress::Any, ushort port = 9527u);

signals:
  /// 接收到新连接时，创建新的socket对象并发出该信号
  void new_connection(ClientSocket *socket);

private slots:
  /// 新建一个ClientSocket，然后立刻交给Server相关函数处理。
  void processNewConnection();
  /// 对每条收到的UDP报文调用processDatagram
  void readPendingDatagrams();

private:
  QTcpServer *server; ///< 监听TCP连接用
  QUdpSocket *udpSocket;  ///< 显示服务器信息用

  /// 对udp报文`msg`进行分析，addr和port是报文发送者传来的信息
  void processDatagram(const QByteArray &msg, const QHostAddress &addr, uint port);
};

#endif // _SERVER_SOCKET_H
