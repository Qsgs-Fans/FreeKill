#pragma once

class RoomThread;

class LobbyLuaTask {
public:
  LobbyLuaTask(std::string type, std::string data);
  LobbyLuaTask(const LobbyLuaTask&) = delete;
  LobbyLuaTask(LobbyLuaTask&&) = delete;

  int getId() const;

  // 启动 or 继续执行 对应coro.resume
  void resume();
  // 中途关闭，对应coro.close
  void abort();

private:
  int id; // 负数
  int userConnId = 0; // 关联的用户，0表示无
  int expectedReplyId = 0; // 正在等待的requestId

  std::string taskType;
  std::string data;

  // 很遗憾，负责执行Lua代码的那个类命名成这样了 导致在这里有点违和
  RoomThread *m_thread;
};
