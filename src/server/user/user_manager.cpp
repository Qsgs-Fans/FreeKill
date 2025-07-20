#include "server/user/user_manager.h"
#include "server/user/serverplayer.h"
#include "server/user/auth.h"

UserManager::UserManager() {
  auth = std::make_unique<AuthManager>();
}

UserManager::~UserManager() {
}

auto &UserManager::getPlayer(const QString &connId) const {
  return playerConnIdMap.at(connId);
}

auto &UserManager::getPlayerById(int id) const {
  return playerIdMap.at(id);
}

void UserManager::addPlayer(std::shared_ptr<ServerPlayer> player) {
  playerConnIdMap.insert({ player->getConnId(), std::move(player) });
  playerIdMap.insert({ player->getId(), player });
}

void UserManager::removePlayer(const QString &connid) {
  playerConnIdMap.erase(connid);
}

void UserManager::removePlayerById(int id) {
  playerIdMap.erase(id);
}

std::unordered_map<int, std::shared_ptr<ServerPlayer>> UserManager::getPlayers() {
  return playerIdMap;
}
