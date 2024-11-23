#pragma once

class ServerSocket;
class ClientSocket;

class TestSocket : public QObject {
  Q_OBJECT

private slots:

  // 所有测试开始之前，首先制订一个server和三个client
  void initTestCase();

  void testConnect();
  void testSendMessages();
  void testEncryptedMessages();

  // 释放最开始创建的对象
  void cleanupTestCase();

private:
  ServerSocket *server;
  ClientSocket *client, *client_server = nullptr; // 前者模拟客户端，后者模拟服务端创建的用于通信的
  ushort test_port = 39529;

  void processNewConnection(ClientSocket *);
};
