#include "test_create_room.h"
#include "globals.h"
#include "core/util.h"
#include "core/c-wrapper.h"
#include "server/server.h"
#include "server/room.h"
#include "server/roomthread.h"
#include "server/lobby.h"
#include "client/client.h"
#include "client/clientplayer.h"
#include "network/router.h"

void TestRoom::initTestCase() {
  auto client = clients[0], client2 = clients[1], client3 = clients[2];
  client->connectToHostAndSendSetup("localhost", test_port);
  client2->connectToHostAndSendSetup("localhost", test_port);
  client3->connectToHostAndSendSetup("localhost", test_port);
  QSignalSpy spy2(client->getRouter(), &Router::notification_got);
  while (spy2.wait(50))
    qApp->processEvents();
}

void TestRoom::testCreateRoom() {
  auto client = clients[0], client2 = clients[1], client3 = clients[2];
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

  // 然后检查Server端的数据，应该是创建了RoomThread，创建了Room
  // 并且修改了Room和Lobby中的玩家们
  auto server = ServerInstance;
  QCOMPARE(server->getThreads().count(), 1);
  auto thread = server->getThreads().first();
  QCOMPARE(server->lobby()->getPlayers().count(), 2);
  QCOMPARE(server->findRoom(1)->getPlayers().count(), 1);
  // 由于在S端手动创建房间，需要等待S端读取完lua
  QSignalSpy spy_roomthread_ready(thread, &RoomThread::scheduler_ready);
  QVERIFY(spy_roomthread_ready.wait());
  // Lua或许也值得一看？算了懒得看 至少不在此处

  // 然后检查Client中的数据（主要在lua中，狠狠用eval了）
  // 应该是发生过EnterRoom - UpdateGameData - SetOwner 就目前而言lua只用到了第一个
  // 那么Client应该有空白的AbstractRoom 然后players和alive_players有个自己
  auto L = client->getLua();
  QCOMPARE(L->eval("return #ClientInstance.players").toInt(), 1);
  QCOMPARE(L->eval("return #ClientInstance.alive_players").toInt(), 1);
  QCOMPARE(L->eval("return ClientInstance.players[1].id").toInt(), client->getSelf()->getId());
  // 感觉没什么好测试的，创建AbstractRoom的测试应放在Lua中
}

void TestRoom::testJoinRoom() {
  // 现在c1在room中 令c2正常加入
}

void TestRoom::cleanupTestCase() {
  server_thread->kickAllClients();
}
