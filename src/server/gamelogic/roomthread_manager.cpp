#include "server/gamelogic/roomthread_manager.h"
#include "server/gamelogic/roomthread.h"

std::unique_ptr<RoomThread> &RoomThreadManager::getAvailableThread() {
  for (auto &t : m_threads) {
    if (!t->isFull() && !t->isOutdated()) {
      return t;
    }
  }

  auto thread = std::make_unique<RoomThread>();
  m_threads.push_back(std::move(thread));

  return m_threads.back();
}
