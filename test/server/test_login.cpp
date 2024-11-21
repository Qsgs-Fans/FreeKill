#include <QTest>
#include <QSignalSpy>
#include <QThread>

#include "server_thread.h"
#include "server/server.h"
#include "client/client.h"
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

class TestLogin: public QObject {
  Q_OBJECT
private slots:
  void initTestCase();
  void testConnectToServer();
  void testPasswordError();
  void cleanupTestCase();

private:
  ServerThread *server_thread;
  Client *client, *client2, *client3;
};

void TestLogin::initTestCase() {
  while (!QFile::exists(".git")) QDir::setCurrent("..");
  server_thread = new ServerThread;

  QSignalSpy spy(server_thread, &ServerThread::listening);
  server_thread->start();
  spy.wait(10000);
  QCOMPARE(spy.count(), 1); // 应该是开始listen了，等Server加载完才可继续

  client = new Client;
}

void TestLogin::testConnectToServer() {
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

  // 然后应该是收到:
  // InstallKey, Setup, SetServerSettings, AddTotalGameTime, EnterLobby, UpdatePlayerNum
  // 显示房间列表由UI发起，建立连接时只有上述5条才是
  while (spy.count() < 6) spy.wait(100);
  QCOMPARE(spy.count(), 6);
  args = spy.takeFirst();
  QCOMPARE(args[0].toString(), "InstallKey");
  args = spy.takeFirst();
  QCOMPARE(args[0].toString(), "Setup");
  setup_data = QJsonDocument::fromJson(args[1].toString().toUtf8()).array();
  // 格式应该是 [id，用户名，头像，延迟]
  QCOMPARE(setup_data.count(), 4);
  QCOMPARE(setup_data[0].type(), QJsonValue::Double);
  QCOMPARE(setup_data[1].toString(), test_name); 
  args = spy.takeFirst();
  QCOMPARE(args[0].toString(), "SetServerSettings");
  args = spy.takeFirst();
  QCOMPARE(args[0].toString(), "AddTotalGameTime");
  args = spy.takeFirst();
  QCOMPARE(args[0].toString(), "EnterLobby");
  args = spy.takeFirst();
  QCOMPARE(args[0].toString(), "UpdatePlayerNum");
  qApp->processEvents();

  // 至此已完成单机启动的过程 接下来测试登录失败的情况
  client->getRouter()->getSocket()->disconnectFromHost();
  qApp->processEvents();
}

void TestLogin::testPasswordError() {
  QSignalSpy spy(client->getRouter(), &Router::notification_got);
  QSignalSpy spy2(client->getRouter(), &Router::messageReady);
  QVariantList args;

  client->setLoginInfo(test_name, "1234567890");
  client->connectToHost("localhost", test_port);

  QVERIFY(spy.wait(100)); qApp->processEvents(); // 发Setup
  spy.clear();
  // 然后应该是收到:
  // InstallKey, ErrorDlg
  while (spy.count() < 2) spy.wait(100);
  QCOMPARE(spy.count(), 2);
  args = spy.takeLast();
  QCOMPARE(args[0].toString(), "ErrorDlg");
  qApp->processEvents();
}

void TestLogin::cleanupTestCase() {
  server_thread->deleteLater();
}

QTEST_GUILESS_MAIN(TestLogin)
#include "test_login.moc"
