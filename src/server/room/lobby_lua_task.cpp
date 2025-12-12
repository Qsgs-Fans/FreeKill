#include "server/room/lobby_lua_task.h"

LobbyLuaTask::LobbyLuaTask(std::string type, std::string data)
    : taskType { type }, data { data }
{
  static int nextId = -1;
  id = nextId--;
  if (nextId < -10000000)
    nextId = -1;
}

int LobbyLuaTask::getId() const {
  return id;
}
