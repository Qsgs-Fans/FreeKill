#include <QTest>
#include <QThread>

#include "pch.h"
#include "server/server.h"
#include "client/client.h"
#include "core/packman.h"

/*
 * 测试服务端整体
 * 因为代码写的太烂了拆不出更小的单元，只好这样
 * 至少比每次手动点开可执行程序然后单机启动要强一点
 *
 * 既然没分出单元那至少手动分一下这里想要测试的功能
 * 1. 测试登录
 * 2. 测试游戏房间
*/

static ushort test_port = 39527;

class ServerThread: public QThread {
  Q_OBJECT

public:
  ~ServerThread() { quit(); wait(); }

protected:
  virtual void run();

private:
  Server *server;
};

void ServerThread::run() {
  server = new Server;
  if (!server->listen(QHostAddress::Any, test_port)) {
    qFatal("cannot listen on port %d!\n", test_port);
    qApp->exit(1);
  }
  exec();
}

class ClientThread: public QThread {
  Q_OBJECT

public:
  ~ClientThread() { quit(); wait(); }

signals:
  void send(const QString &);

protected:
  virtual void run();

private:
  Client *client;
};

void ClientThread::run() {
  client = new Client;
  exec();
}

class TestServer: public QObject {
  Q_OBJECT
private slots:
  void initTestCase();
  void testConnectToServer();
  void cleanupTestCase();

private:
  ServerThread *server_thread;
  ClientThread *client_thread, *client_thread2;
};

void TestServer::initTestCase() {
  QDir::setCurrent("..");
  Pacman = new PackMan;
  server_thread = new ServerThread;
  client_thread = new ClientThread;
  client_thread2 = new ClientThread;

  server_thread->start();
}

void TestServer::testConnectToServer() {
  auto client = new Client;
  client->connectToHost("localhost", test_port);
}

void TestServer::cleanupTestCase() {
  server_thread->deleteLater();
  Pacman->deleteLater();
}

QTEST_MAIN(TestServer)
#include "test_server.moc"
