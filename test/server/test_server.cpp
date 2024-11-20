#include <QTest>
#include <QSignalSpy>
#include <QThread>

#include "server/server.h"
#include "client/client.h"
#include "core/packman.h"
#include "network/client_socket.h"
#include "network/router.h"

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
static const char *test_name = "test_player";
static const char *test_name2 = "test_player2";
static const char *test_name3 = "test_player3";

class ServerThread: public QThread {
  Q_OBJECT

public:
  ~ServerThread() { quit(); wait(); }

signals:
  void listening();

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
  emit listening();
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
  Client *client, *client2, *client3;
};

void TestServer::initTestCase() {
  while (!QFile::exists(".git")) QDir::setCurrent("..");
  Pacman = new PackMan;
  server_thread = new ServerThread;

  QSignalSpy spy(server_thread, &ServerThread::listening);
  server_thread->start();
  spy.wait(10000);
  QCOMPARE(spy.count(), 1); // 应该是开始listen了，等Server加载完才可继续
}

void TestServer::testConnectToServer() {
  client = new Client;
  QVariantList args;
  QSignalSpy spy(client->getRouter(), &Router::notification_got);
  QSignalSpy spy2(client->getRouter(), &Router::messageReady);

  client->setLoginInfo(test_name, "1234");
  client->connectToHost("localhost", test_port);

  spy.wait(100);
  QCOMPARE(spy.count(), 1); // 应该是收到一条NetworkDelay
  args = spy.takeFirst();
  QCOMPARE(args[0].toString(), "NetworkDelayTest");
  qApp->processEvents(); // 让client处理
  QCOMPARE(spy2.count(), 1); // 应该是发出一条Setup
  args = spy2.takeFirst();
  auto setup_data = QJsonDocument::fromJson(args[0].toString().toUtf8()).array();
  setup_data = QJsonDocument::fromJson(setup_data[3].toString().toUtf8()).array();
  // 格式应该是 [用户名，密文，md5，版本，uuid]
  QCOMPARE(setup_data.count(), 5);
  QCOMPARE(setup_data[0].toString(), test_name);
  QCOMPARE(setup_data[2].toString(), ServerInstance->getMd5());
  QCOMPARE(setup_data[3].toString(), FK_VERSION);

  // auth.cpp 检测密码中
  spy.clear(); spy.wait(100);
  QCOMPARE(spy.count(), 1); // 然后应该是收到了一条InstallKey
  args = spy.takeFirst();
  QCOMPARE(args[0].toString(), "InstallKey");
  qApp->processEvents();

  spy.clear(); spy.wait(100);
  QCOMPARE(spy.count(), 1); // 然后应该是收到了一条Setup
  args = spy.takeFirst();
  QCOMPARE(args[0].toString(), "Setup");
  setup_data = QJsonDocument::fromJson(args[1].toString().toUtf8()).array();
  // 格式应该是 [id，用户名，头像，延迟]
  QCOMPARE(setup_data.count(), 4);
  QCOMPARE(setup_data[0].type(), QJsonValue::Double);
  QCOMPARE(setup_data[1].toString(), test_name); 
  qApp->processEvents();

  // 至此已完成单机启动的过程 接下来测试登录失败的情况
  client->getRouter()->getSocket()->disconnectFromHost();
  qApp->processEvents();
  client->setLoginInfo(test_name, "1234567890");
  client->connectToHost("localhost", test_port);
  spy.wait(100); qApp->processEvents(); // 发Setup
  spy.wait(100); // 收到InstallKey
  spy.clear(); spy.wait(100);
  QCOMPARE(spy.count(), 1); // 然后应该是收到了一条ErrorDlg (弹窗)
  args = spy.takeFirst();
  QCOMPARE(args[0].toString(), "ErrorDlg");
  qApp->processEvents();

  // 最后正常登录 准备下一个测试
  client->setLoginInfo("player", "1234");
  client->connectToHost("localhost", test_port);
}

void TestServer::cleanupTestCase() {
  server_thread->deleteLater();
  Pacman->deleteLater();
}

QTEST_MAIN(TestServer)
#include "test_server.moc"
