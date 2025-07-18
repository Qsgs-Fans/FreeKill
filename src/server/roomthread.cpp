// SPDX-License-Identifier: GPL-3.0-or-later

#include "server/roomthread.h"
#include "server/server.h"
#include "core/util.h"
#include "core/c-wrapper.h"
#include "core/rpc-lua.h"
#include "server/roomthread-rpc.h"
#include "server/serverplayer.h"

#ifndef FK_SERVER_ONLY
#include "client/client.h"
#endif

Scheduler::Scheduler(RoomThread *thread) {
  if (!ServerInstance->isRpcEnabled()) {
    L = new Lua;
    if (QFile::exists("packages/freekill-core") &&
      !GetDisabledPacks().contains("freekill-core")) {
      // 危险的cd操作，记得在lua中切回游戏根目录
      QDir::setCurrent("packages/freekill-core");
    }

    L->dofile("lua/freekill.lua");
    L->dofile("lua/server/scheduler.lua");
    L->call("InitScheduler", { QVariant::fromValue(thread) });

  } else {
    qDebug("Using RpcLua");
    L = new RpcLua(ServerRpcMethods);
  }
}

Scheduler::~Scheduler() {
  delete L;
}

void Scheduler::handleRequest(const QString &req) {
  auto bytes = req.toUtf8();
  L->call("HandleRequest", { bytes });
}

void Scheduler::doDelay(int roomId, int ms) {
  QTimer::singleShot(ms, [=](){ resumeRoom(roomId, "delay_done"); });
}

bool Scheduler::resumeRoom(int roomId, const char *reason) {
  auto room = ServerInstance->findRoom(roomId);
  return L->call("ResumeRoom", { roomId, reason }).toBool();
}

RoomThread::RoomThread(Server *server) {
  setObjectName("Room");
  setParent(server);
  m_server = server;
  m_capacity = server->getConfig("roomCountPerThread").toInt(200);
  md5 = server->getMd5();

  // 需要等待scheduler创建完毕 不然极端情况下可能导致玩家发的信号接收不到
  QEventLoop loop;
  connect(this, &RoomThread::scheduler_ready, &loop, &QEventLoop::quit);
  start();
  loop.exec();
}

RoomThread::~RoomThread() {
  if (isRunning()) {
    quit(); wait();
  }
  delete m_scheduler;
}

void RoomThread::run() {
  // 在run中创建，这样就能在接下来的exec中处理事件了
  m_scheduler = new Scheduler(this);
  connect(this, &RoomThread::pushRequest, m_scheduler, &Scheduler::handleRequest);
  connect(this, &RoomThread::delay, m_scheduler, &Scheduler::doDelay);
  connect(this, &RoomThread::wakeUp, m_scheduler, &Scheduler::resumeRoom);
  emit scheduler_ready();
  exec();
}

Server *RoomThread::getServer() const {
  return m_server;
}

bool RoomThread::isFull() const {
  return m_capacity <= findChildren<Room *>().length();
}

QString RoomThread::getMd5() const { return md5; }

Room *RoomThread::getRoom(int id) const {
  return m_server->findRoom(id);
}

bool RoomThread::isConsoleStart() const {
#ifndef FK_SERVER_ONLY
  if (!ClientInstance) return false;
  return ClientInstance->isConsoleStart();
#else
  return false;
#endif
}

bool RoomThread::isOutdated() {
  bool ret = md5 != m_server->getMd5();
  if (ret) {
    // 让以后每次都outdate
    // 不然反复disable/enable的情况下会出乱子
    md5 = QStringLiteral("");
  }
  return ret;
}

LuaInterface *RoomThread::getLua() const {
  return m_scheduler->getLua();
}

void RoomThread::onRoomAbandoned() {
  auto room = qobject_cast<Room *>(sender());
  m_server->removeRoom(room->getId());
  m_server->updateOnlineInfo();

  if (room->getRefCount() == 0) {
    room->deleteLater();
  } else {
    wakeUp(room->getId(), "abandon");
  }
}
