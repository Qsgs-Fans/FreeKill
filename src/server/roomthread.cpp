// SPDX-License-Identifier: GPL-3.0-or-later

#include "roomthread.h"
#include "server.h"
#include "util.h"

RoomThread::RoomThread(Server *m_server) {
  setObjectName("Room");
  this->m_server = m_server;
  m_capacity = 100; // TODO: server cfg
  terminated = false;

  L = CreateLuaState();
  DoLuaScript(L, "lua/freekill.lua");
  DoLuaScript(L, "lua/server/scheduler.lua");
  start();
}

RoomThread::~RoomThread() {
  tryTerminate();
  if (isRunning()) {
    wait();
  }
  lua_close(L);
  foreach (auto room, room_list) {
    room->deleteLater();
  }
}

Server *RoomThread::getServer() const {
  return m_server;
}

bool RoomThread::isFull() const {
  return room_list.count() >= m_capacity;
}

Room *RoomThread::getRoom(int id) const {
  return m_server->findRoom(id);
}

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
    sema_wake.acquire(sema_wake.available());
  }

  sema_wake.tryAcquire(1, ms);
}

void RoomThread::wakeUp() {
  sema_wake.release(1);
}

void RoomThread::tryTerminate() {
  terminated = true;
}

bool RoomThread::isTerminated() const {
  return terminated;
}
