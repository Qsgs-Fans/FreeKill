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
  bool isConsoleStart() const;

  void setReplyReadySemaphore(QSemaphore *semaphore);

  void request(int type, const QByteArray &command,
              const QByteArray &jsonData, int timeout, qint64 timestamp = -1);
  void reply(int type, const QByteArray &command, const QByteArray &jsonData);
  void notify(int type, const QByteArray &command, const QByteArray &jsonData);

  int getTimeout() const;

  void cancelRequest();
  void abortRequest();

  QString waitForReply(int timeout);

  int getRequestId() const { return requestId; }
  qint64 getRequestTimestamp() { return requestTimestamp; }

signals:
  void messageReady(const QByteArray &msg);
  void replyReady();

  void notification_got(const QString &command, const QString &jsonData);
  void request_got(const QString &command, const QString &jsonData);

protected:
  void handlePacket(const QByteArray &rawPacket);

private:
  ClientSocket *socket;
  RouterType type;

  // For client side
  int requestId;
  int requestTimeout;
  qint64 requestTimestamp;

  // For server side
  QDateTime requestStartTime;
  QMutex replyMutex;
  int expectedReplyId;
  int replyTimeout;
  QString m_reply;    // should be json string
  QSemaphore replyReadySemaphore;
  QSemaphore *extraReplyReadySemaphore;

  void sendMessage(const QByteArray &msg);
};

#endif // _ROUTER_H
