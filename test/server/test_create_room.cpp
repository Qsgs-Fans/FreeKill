#include "server_thread.h"
#include "core/util.h"
#include "core/c-wrapper.h"
#include "client/client.h"
#include "client/clientplayer.h"
#include "network/router.h"

static ushort test_port = 39527;
static const char *test_name = "test_player";
static const char *test_name2 = "test_player2";
static const char *test_name3 = "test_player3";

// ~ 房间创建篇 ~
class TestRoom: public QObject {
  Q_OBJECT
private slots:
  void initTestCase();
  void testCreateRoom();
  // void testDeleteRoom();
  void cleanupTestCase();

private:
  ServerThread *server_thread;
  Client *client, *client2, *client3;
};

void TestRoom::initTestCase() {
  while (!QFile::exists(".git")) QDir::setCurrent("..");
  server_thread = new ServerThread;

  QSignalSpy spy(server_thread, &ServerThread::listening);
  server_thread->start();
  spy.wait(10000);
  QCOMPARE(spy.count(), 1); // 应该是开始listen了，等Server加载完才可继续

  client = new Client;
  client->setLoginInfo(test_name, "1234");
  client2 = new Client;
  client2->setLoginInfo(test_name2, "1234");
  client3 = new Client;
  client3->setLoginInfo(test_name3, "1234");

  client->connectToHost("localhost", test_port);
  client2->connectToHost("localhost", test_port);
  client3->connectToHost("localhost", test_port);
  spy.wait(100);
  qApp->processEvents();
  QSignalSpy spy2(client->getRouter(), &Router::notification_got);
  while (spy2.wait(50));
}

void TestRoom::testCreateRoom() {
  // 现在大家都在lobby中
  // 要测试的有 CreateRoom EnterRoom ObserveRoom
  static auto room_config = QJsonObject({
    { "gameMode", "aaa_role_mode" },
    { "enableFreeAssign", true },
    { "enableDeputy", false },
    { "generalNum", 5 },
    { "luckTime", 0 },
    { "password", "" },
    { "disabledPack", QJsonArray() },
    { "disabledGenerals", QJsonArray() },
  });

  QSignalSpy spy(client->getRouter(), &Router::notification_got);
  QSignalSpy spy2(client2->getRouter(), &Router::notification_got);
  QSignalSpy spy3(client3->getRouter(), &Router::notification_got);
  QVariantList args;

  client->notifyServer("CreateRoom", JsonArray2Bytes({
    "test_room1", 2, 90, room_config,
  }));

  // Server应该发回以下几个包：
  // EnterRoom, 0个[AddPlayer, UpdateGameData], 0个RoomOwner, UpdateGameData
  // (接lobby::removePlayer) client2和client3应该收到UpdatePlayerNum
  // client再收到RoomOwner知道自己是房主
  if (spy2.count() == 0) QVERIFY(spy2.wait());
  if (spy3.count() == 0) QVERIFY(spy3.wait());
  if (spy.count() < 3) QVERIFY(spy.wait());
  args = spy.takeFirst();
  auto arr = QJsonDocument::fromJson(args[1].toString().toUtf8()).array();
  QCOMPARE(arr.count(), 3);
  QCOMPARE(arr[0].toInt(), 2);
  QCOMPARE(arr[1].toInt(), 90);
  QCOMPARE(arr[2], room_config);
  args = spy.takeFirst();
  QCOMPARE(args[0].toString(), "UpdateGameData");
  args = spy.takeFirst();
  QCOMPARE(args[0].toString(), "RoomOwner");
  QCOMPARE(args[1].toString(), QString("[%1]").arg(client->getSelf()->getId()));
  args = spy2.takeFirst();
  QCOMPARE(args[0].toString(), "UpdatePlayerNum");
  QCOMPARE(args[1].toString(), "[2,3]");
  args = spy3.takeFirst();
  QCOMPARE(args[0].toString(), "UpdatePlayerNum");
  QCOMPARE(args[1].toString(), "[2,3]");

  // 然后检查Server端的数据

  // 然后检查Client中的数据（主要在lua中，狠狠用eval了）
}

void TestRoom::cleanupTestCase() {
  client3->deleteLater();
  client2->deleteLater();
  client->deleteLater();
  server_thread->deleteLater();
}

QTEST_GUILESS_MAIN(TestRoom)
#include "test_create_room.moc"
