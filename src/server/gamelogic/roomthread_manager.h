#pragma once

class RoomThread;

class RoomThreadManager {
public:
  explicit RoomThreadManager();
  RoomThreadManager(RoomThreadManager &) = delete;

  std::unique_ptr<RoomThread> &getAvailableThread();

private:
  std::vector<std::unique_ptr<RoomThread>> m_threads;
};
