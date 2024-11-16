#include <QTcpSocket>
#include <QUdpSocket>
#include <QTcpServer>
#include <QTimer>
#include <QSignalSpy>
#include <QTest>

#include "network/server_socket.h"
#include "network/client_socket.h"

// 测试ServerSocket与ClientSocket
// 想不出测试各种网络异常的方法，所以只有这些简单的了
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
  ushort test_port = 39527;

  void processNewConnection(ClientSocket *);
};


void TestSocket::initTestCase() {
  server = new ServerSocket;
  client = new ClientSocket;
  client_server = nullptr;

  connect(server, &ServerSocket::new_connection,
          this, &TestSocket::processNewConnection);

  auto isListening = server->listen(QHostAddress::Any, test_port);
  QCOMPARE(isListening, true);
}

void TestSocket::testConnect() {
  QSignalSpy spy(client, &ClientSocket::error_message);
  client->send("Hello!"); // 应该有error
  QCOMPARE(spy.count(), 1);

  client->connectToHost("127.0.0.1", test_port);
  qApp->processEvents(); // 让server处理一下new_conntion信号
  QCOMPARE_NE(client_server, nullptr);
}

void TestSocket::testSendMessages() {
  QByteArray msg = "Hello";
  QByteArray long_msg = msg.repeated(2000);
  QSignalSpy spy(client_server, &ClientSocket::message_got);
  QVariantList arguments;

  client->send(msg);
  qApp->processEvents();
  QCOMPARE(spy.count(), 1);
  arguments = spy.takeFirst();
  QCOMPARE(arguments.at(0).toByteArray(), msg);

  // compressed
  spy.clear();
  client->send(long_msg);
  qApp->processEvents();
  QCOMPARE(spy.count(), 1);
  arguments = spy.takeFirst();
  QCOMPARE(arguments.at(0).toByteArray(), long_msg);
}

void TestSocket::testEncryptedMessages() {
  // 合法密钥（表示128bit串的十六进制字符串）
  const char *aeskey = "00000000000000000000000000000000";
  // 不合法密钥（字节数不对）
  const char *aeskey2 = "deadbeef";
  // 不合法密钥（32字节但是不合法）
  const char *aeskey3 = "main(){system('pacman -syuad');}"; // 32位
  QByteArray msg = "Hello";
  QSignalSpy spy(client_server, &ClientSocket::message_got);
  QVariantList arguments;
  
  client->installAESKey(aeskey2);
  QVERIFY(!client->aesReady());
  client->installAESKey(aeskey3);
  QVERIFY(!client->aesReady());
  client->installAESKey(aeskey);
  QVERIFY(client->aesReady());

  client_server->installAESKey(aeskey);
  client->send(msg);
  qApp->processEvents();
  QCOMPARE(spy.count(), 1);
  arguments = spy.takeFirst();
  QCOMPARE(arguments.at(0).toByteArray(), msg);
}

void TestSocket::cleanupTestCase() {
  server->deleteLater();
  client->deleteLater();
  if (client_server) {
    client_server->deleteLater();
  }
}

void TestSocket::processNewConnection(ClientSocket *client) {
  if (client_server) {
    client_server->deleteLater();
  }
  client_server = client;
}

QTEST_MAIN(TestSocket)

#include "test_socket.moc"
