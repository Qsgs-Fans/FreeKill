#include "test_scheduler.h"
#include "globals.h"
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

void TestScheduler::initTestCase() {
  auto client = clients[0], client2 = clients[1], client3 = clients[2];
  client->connectToHostAndSendSetup("localhost", test_port);
  client2->connectToHostAndSendSetup("localhost", test_port);
  client3->connectToHostAndSendSetup("localhost", test_port);
  QSignalSpy spy2(client->getRouter(), &Router::notification_got);
  while (spy2.wait(50))
    qApp->processEvents();
}

void TestScheduler::testStartGame() {
  auto client = clients[0], client2 = clients[1], client3 = clients[2];
  QSignalSpy spy(client->getRouter(), &Router::notification_got);
  QSignalSpy spy2(client2->getRouter(), &Router::notification_got);
  QSignalSpy spy3(client3->getRouter(), &Router::notification_got);
  QVariantList args;

  client->notifyServer("CreateRoom", JsonArray2Bytes({
    "test_room2", 2, 90, room_config,
  }));

  // 直接等到spy3收到数据（大厅人数变动） c2加入房间一样的等待
  QVERIFY(spy3.wait());

  client2->notifyServer("EnterRoom", "[2,\"\"]");
  QVERIFY(spy3.wait());

  auto room = ServerInstance->findRoom(2);
  auto thread = room->getThread();
  QSignalSpy spy_roomthread(thread, &RoomThread::pushRequest);

  // 下一步c1发出StartGame命令
  client->notifyServer("StartGame", "");
  QVERIFY(spy_roomthread.wait());
  args = spy_roomthread.takeFirst();
  QCOMPARE(args[0], "-1,2,newroom");
  QVERIFY(room->isStarted());

  // 关于startGame后续的测试...
}

void TestScheduler::testReconnect() {
  // 先踢了再说 强制掉线
  auto client = clients[0], client2 = clients[1], client3 = clients[2];
  QSignalSpy spy_disconnet(client2, &Client::error_message);
  QVariantList args;
  auto splayer2 = ServerInstance->findPlayer(client2->getSelf()->getId());
  emit splayer2->kicked();
  QVERIFY(spy_disconnet.wait());
  QCOMPARE(splayer2->getState(), Player::Offline);

  // 再尝试重连
  delete client2;
  client2 = new TesterClient(test_name2, "1234");
  clients[1] = client2;
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
  auto client = clients[0], client2 = clients[1], client3 = clients[2];
  QSignalSpy spy3(client3->getRouter(), &Router::notification_got);
  client3->notifyServer("ObserveRoom", "[2,\"\"]");
  QVERIFY(spy3.wait());
  qApp->processEvents();
}

void TestScheduler::cleanupTestCase() {
  server_thread->kickAllClients();
}
