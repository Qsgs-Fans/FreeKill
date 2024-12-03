// SPDX-License-Identifier: GPL-3.0-or-later

#include "server/roomthread.h"
#include "server/scheduler.h"
#include "server/server.h"

#ifndef FK_SERVER_ONLY
#include "client/client.h"
#endif

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
    md5 = "";
  }
  return ret;
}

Lua *RoomThread::getLua() const {
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
