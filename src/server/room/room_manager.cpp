#include "server/room/room_manager.h"
#include "server/room/room.h"
#include "server/room/lobby.h"
#include "server/user/serverplayer.h"
#include "server/gamelogic/roomthread_manager.h"
#include "server/server.h"

RoomManager::RoomManager() {
  m_lobby = std::make_unique<Lobby>();
}

void RoomManager::createRoom(std::shared_ptr<ServerPlayer> owner, const QString &name, int capacity,
                        int timeout, const QByteArray &settings) {
  if (!ServerInstance->checkBanWord(name)) {
    if (owner) {
      owner->doNotify("ErrorMsg", "unk error");
    }
    return;
  }
  auto &thread = ServerInstance->getThreadManager()->getAvailableThread();
  auto room = new Room(thread);

  m_rooms.insert(room->getId(), room);
  room->setName(name);
  room->setCapacity(capacity);
  room->setTimeout(timeout);
  room->setSettings(settings);
  room->addPlayer(owner);
  room->setOwner(owner);
}

void RoomManager::removeRoom(int id) {
  m_rooms.erase(id);
}

int RoomManager::getRoomId() { return nextRoomId++; }
