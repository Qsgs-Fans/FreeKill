/*
  对房间调度模块的测试。需要测试的功能有这些：
  - 房间的启动
  - 房间的游戏结束
  - 房间的切出
  - 异步处理
*/
#include "server_thread.h"
#include "core/util.h"
#include "core/c-wrapper.h"
#include "client/client.h"
#include "client/clientplayer.h"
#include "server/server.h"
#include "server/room.h"
#include "server/roomthread.h"
#include "server/scheduler.h"
#include "server/serverplayer.h"
#include "network/router.h"

using namespace std::chrono_literals;

static ushort test_port = 39527;
static const char *test_name = "test_player";
static const char *test_name2 = "test_player2";
static const char *test_name3 = "test_player3";

class TestScheduler: public QObject {
  Q_OBJECT
private slots:
  void initTestCase();
  void testStartGame();
  void testReconnect();
  void testObserve();
  void cleanupTestCase();

private:
  ServerThread *server_thread;
  Client *client, *client2, *client3;
};

void TestScheduler::initTestCase() {
  qputenv("QT_FATAL_CRITICALS", "1"); // TODO: 找个办法在qCritical时候只是失败这个测试而不是把所有全部abort掉了
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

void TestScheduler::testStartGame() {
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

  // 直接等到spy3收到数据（大厅人数变动） c2加入房间一样的等待
  QVERIFY(spy3.wait());

  client2->notifyServer("EnterRoom", "[1,\"\"]");
  QVERIFY(spy3.wait());

  auto room = ServerInstance->findRoom(1);
  auto thread = room->getThread();
  QSignalSpy spy_roomthread_ready(thread, &RoomThread::scheduler_ready);
  QVERIFY(spy_roomthread_ready.wait());
  QSignalSpy spy_roomthread(thread, &RoomThread::pushRequest);

  // 下一步c1发出StartGame命令
  client->notifyServer("StartGame", "");
  QVERIFY(spy_roomthread.wait());
  args = spy_roomthread.takeFirst();
  QCOMPARE(args[0], "-1,1,newroom");
  QVERIFY(room->isStarted());

  // 关于startGame后续的测试...
}

void TestScheduler::testReconnect() {
  // 先踢了再说 强制掉线
  QSignalSpy spy_disconnet(client2, &Client::error_message);
  QVariantList args;
  auto splayer2 = ServerInstance->findPlayer(client2->getSelf()->getId());
  emit splayer2->kicked();
  QVERIFY(spy_disconnet.wait());
  QCOMPARE(splayer2->getState(), Player::Offline);

  // 再尝试重连
  delete client2;
  client2 = new Client;
  client2->setLoginInfo(test_name2, "1234");
  QSignalSpy spy2(client2->getRouter(), &Router::notification_got);
  client2->connectToHost("localhost", test_port);
  QVERIFY(spy2.wait()); qApp->processEvents(); // 收NetworkDelayTest 发第一个包
  // 然后应该是以下：
  // InstallKey, Setup, SetServerSettings, Reconnect, RoomOwner (AddSkill系列不管了)
  // 其中一直wait直到收到RoomOwner包只是为了确保client执行了Lua
  spy2.clear();
  while (spy2.count() < 5) spy2.wait(100);
  args = spy2[1];
  QCOMPARE(args[0].toString(), "Setup");
  auto setup_data = QJsonDocument::fromJson(args[1].toString().toUtf8()).array();
  // 格式应该是 [id，用户名，头像，延迟] 只检查是不是设置延迟了（一定要有）
  QCOMPARE(setup_data.count(), 4);
  args = spy2[3];
  QCOMPARE(args[0].toString(), "Reconnect");
}

void TestScheduler::testObserve() {
  QSignalSpy spy3(client3->getRouter(), &Router::notification_got);
  client3->notifyServer("ObserveRoom", "[1,\"\"]");
  QVERIFY(spy3.wait());
  qApp->processEvents();
}

void TestScheduler::cleanupTestCase() {
  client3->deleteLater();
  client2->deleteLater();
  client->deleteLater();
  server_thread->deleteLater();
}

QTEST_GUILESS_MAIN(TestScheduler)
#include "test_scheduler.moc"
