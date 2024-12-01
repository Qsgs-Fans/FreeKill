// SPDX-License-Identifier: GPL-3.0-or-later

#include "server/scheduler.h"
#include "server/roomthread.h"
#include "core/util.h"
#include "core/c-wrapper.h"

Scheduler::Scheduler(RoomThread *thread) {
  L = new Lua;
  if (QFile::exists("packages/freekill-core") &&
      !GetDisabledPacks().contains("freekill-core")) {
    // 危险的cd操作，记得在lua中切回游戏根目录
    QDir::setCurrent("packages/freekill-core");
  }
  L->dofile("lua/freekill.lua");
  L->dofile("lua/server/scheduler.lua");
  L->call("InitScheduler", { QVariant::fromValue(thread) });
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
  return L->call("ResumeRoom", { roomId, reason }).toBool();
}
