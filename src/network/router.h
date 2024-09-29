// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _ROUTER_H
#define _ROUTER_H

class ClientSocket;

/** @brief 实现通信协议，负责传输结构化消息而不是字面上的文本信息。

  Router是对\ref ClientSocket 的又一次封装。ClientSocket解决的是传输字符串的
  问题，Router要解决的则是实现协议中的两种类型消息的传输：Request-Reply以及
  Notify这两种。
  */
class Router : public QObject {
  Q_OBJECT

public:
  /**
    该枚举揭示了一个Packet的类型，在实际使用中，Packet的类型以TYPE、SRC、
    DEST这几种枚举通过按位与的方式拼接而成。
    */
  enum PacketType {
    TYPE_REQUEST = 0x100,      ///< 类型为Request的包
    TYPE_REPLY = 0x200,        ///< 类型为Reply的包
    TYPE_NOTIFICATION = 0x400, ///< 类型为Notify的包
    SRC_CLIENT = 0x010,        ///< 从客户端发出的包
    SRC_SERVER = 0x020,        ///< 从服务端发出的包
    SRC_LOBBY = 0x040,
    DEST_CLIENT = 0x001,
    DEST_SERVER = 0x002,
    DEST_LOBBY = 0x004
  };

  enum RouterType {
    TYPE_SERVER,
    TYPE_CLIENT
  };
  Router(QObject *parent, ClientSocket *socket, RouterType type);
  ~Router();

  ClientSocket *getSocket() const;
  void setSocket(ClientSocket *socket);
  void removeSocket();
  void installAESKey(const QByteArray &key);
  bool isConsoleStart() const;

  void setReplyReadySemaphore(QSemaphore *semaphore);

  void request(int type, const QString &command,
              const QString &jsonData, int timeout);
  void reply(int type, const QString &command, const QString &jsonData);
  void notify(int type, const QString &command, const QString &jsonData);

  int getTimeout() const;

  void cancelRequest();
  void abortRequest();

  QString waitForReply(int timeout);

signals:
  void messageReady(const QByteArray &message);
  void unknownPacket(const QByteArray &packet);
  void replyReady();

protected:
  void handlePacket(const QByteArray &rawPacket);

private:
  ClientSocket *socket;
  RouterType type;

  // For sender
  int requestId;
  int requestTimeout;

  // For receiver
  QDateTime requestStartTime;
  QMutex replyMutex;
  int expectedReplyId;
  int replyTimeout;
  QString m_reply;    // should be json string
  QSemaphore replyReadySemaphore;
  QSemaphore *extraReplyReadySemaphore;

  // Two Lua global table for callbacks and interactions
  // stored in the lua_State of the sender
  // LuaTable interactions;
  // LuaTable callbacks;
};

#endif // _ROUTER_H
