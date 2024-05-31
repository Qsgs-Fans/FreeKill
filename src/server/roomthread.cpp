// SPDX-License-Identifier: GPL-3.0-or-later

#include "server/roomthread.h"
#include "server/scheduler.h"
#include "server/server.h"

#ifndef FK_SERVER_ONLY
#include "client/client.h"
#endif

RoomThread::RoomThread(Server *m_server) {
  setObjectName("Room");
  this->m_server = m_server;
  m_capacity = 100; // TODO: server cfg
  md5 = m_server->getMd5();

  start();
}

RoomThread::~RoomThread() {
  if (isRunning()) {
    quit();
  }
  delete m_scheduler;
  m_server->removeThread(this);
  // foreach (auto room, room_list) {
  //   room->deleteLater();
  // }
}

void RoomThread::run() {
  // 在run中创建，这样就能在接下来的exec中处理事件了
  m_scheduler = new Scheduler(this);
  connect(this, &RoomThread::pushRequest, m_scheduler, &Scheduler::handleRequest);
  connect(this, &RoomThread::delay, m_scheduler, &Scheduler::doDelay);
  connect(this, &RoomThread::wakeUp, m_scheduler, &Scheduler::resumeRoom);
  exec();
}

Server *RoomThread::getServer() const {
  return m_server;
}

bool RoomThread::isFull() const {
  // return room_list.count() >= m_capacity;
  return m_capacity <= 0;
}

QString RoomThread::getMd5() const { return md5; }

Room *RoomThread::getRoom(int id) const {
  return m_server->findRoom(id);
}

void RoomThread::addRoom(Room *room) {
  room->setThread(this);
  m_capacity--;
}

void RoomThread::removeRoom(Room *room) {
  room->setThread(nullptr);
  m_capacity++;
  if (m_capacity == 100 // TODO: server cfg
      && isOutdated()) {
    deleteLater();
  }
}

/*
QString RoomThread::fetchRequest() {
  // if (!gameStarted)
  //   return "";
  request_queue_mutex.lock();
  QString ret = "";
  if (!request_queue.isEmpty()) {
    ret = request_queue.dequeue();
  }
  request_queue_mutex.unlock();
  return ret;
}

void RoomThread::pushRequest(const QString &req) {
  // if (!gameStarted)
  //   return;
  request_queue_mutex.lock();
  request_queue.enqueue(req);
  request_queue_mutex.unlock();
  wakeUp();
}

void RoomThread::clearRequest() {
  request_queue_mutex.lock();
  request_queue.clear();
  request_queue_mutex.unlock();
}

bool RoomThread::hasRequest() {
  request_queue_mutex.lock();
  auto ret = !request_queue.isEmpty();
  request_queue_mutex.unlock();
  return ret;
}

void RoomThread::trySleep(int ms) {
  if (sema_wake.available() > 0) {
    sema_wake.tryAcquire(sema_wake.available(), ms);
    return;
  }

  sema_wake.tryAcquire(1, ms);
}

void RoomThread::wakeUp() {
  sema_wake.release(1);
}

void RoomThread::tryTerminate() {
  terminated = true;
  wakeUp();
}

bool RoomThread::isTerminated() const {
  return terminated;
}
*/

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
