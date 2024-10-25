// SPDX-License-Identifier: GPL-3.0-or-later

#include "server/scheduler.h"
#include "server/roomthread.h"
#include "core/util.h"

Scheduler::Scheduler(RoomThread *thread) {
  m_thread = thread;
  L = CreateLuaState();
  if (QFile::exists("packages/freekill-core") &&
      !GetDisabledPacks().contains("freekill-core")) {
    // 危险的cd操作，记得在lua中切回游戏根目录
    QDir::setCurrent("packages/freekill-core");
  }
  DoLuaScript(L, "lua/freekill.lua");
  DoLuaScript(L, "lua/server/scheduler.lua");
  tellThreadToLua();
}

Scheduler::~Scheduler() {
  lua_close(L);
}

void Scheduler::handleRequest(const QString &req) {
  lua_getglobal(L, "HandleRequest");
  auto bytes = req.toUtf8();
  lua_pushstring(L, bytes.data());

  int err = lua_pcall(L, 1, 1, 0);
  const char *result = lua_tostring(L, -1);
  if (err) {
    qCritical() << result;
    lua_pop(L, 1);
  }
  lua_pop(L, 1);
}

void Scheduler::doDelay(int roomId, int ms) {
  QTimer::singleShot(ms, [=](){ resumeRoom(roomId, "delay_done"); });
}

bool Scheduler::resumeRoom(int roomId, const char *reason) {
  lua_getglobal(L, "ResumeRoom");
  lua_pushnumber(L, roomId);
  lua_pushstring(L, reason);

  int err = lua_pcall(L, 2, 1, 0);
  if (err) {
    const char *result = lua_tostring(L, -1);
    qCritical() << result;
    lua_pop(L, 1);
    return true;
  }
  auto ret = lua_toboolean(L, -1);
  return ret;
}
