#include "server/room/lobby.h"
#include "server/room/room.h"
#include "server/server.h"
#include "server/user/serverplayer.h"
#include "core/util.h"
#include "core/c-wrapper.h"
#include "server/task/task_manager.h"
#include "server/task/task.h"

using namespace Qt::Literals::StringLiterals;

Lobby::Lobby(Server *server) {
  this->server = server;
  setParent(server);
}

void Lobby::addPlayer(ServerPlayer *player) {
  if (!player) return;

  players.append(player);
  player->setRoom(this);

  if (player->getState() == Player::Robot) {
    removePlayer(player);
    player->deleteLater();
  } else {
    player->doNotify("EnterLobby", QCborValue().toCbor());
  }

  server->updateOnlineInfo();
}

void Lobby::removePlayer(ServerPlayer *player) {
  players.removeOne(player);

  auto &tm = ServerInstance->task_manager();
  auto connId = player->getConnId();
  tm.removeAllTasksByUser(connId);

  server->updateOnlineInfo();
}

void Lobby::updateAvatar(ServerPlayer *sender, const QByteArray &jsonData) {
  auto avatar = QCborValue::fromCbor(jsonData).toString();

  if (Sqlite3::checkString(avatar)) {
    auto sql = QString("UPDATE userinfo SET avatar='%1' WHERE id=%2;")
      .arg(avatar)
      .arg(sender->getId());
    ServerInstance->database().exec(sql);
    sender->setAvatar(avatar);
    sender->doNotify("UpdateAvatar", avatar.toUtf8());
  }
}

void Lobby::updatePassword(ServerPlayer *sender, const QByteArray &jsonData) {
  auto arr = QCborValue::fromCbor(jsonData).toArray();
  auto oldpw = arr[0].toString();
  auto newpw = arr[1].toString();
  auto sql_find =
    QString("SELECT password, salt FROM userinfo WHERE id=%1;")
    .arg(sender->getId());

  auto passed = false;
  auto arr2 = ServerInstance->database().select(sql_find);
  auto result = arr2[0];
  passed = (result["password"] == QCryptographicHash::hash(
    oldpw.append(result["salt"]).toLatin1(),
    QCryptographicHash::Sha256)
  .toHex());
  if (passed) {
    auto sql_update =
      QString("UPDATE userinfo SET password='%1' WHERE id=%2;")
      .arg(QCryptographicHash::hash(
            newpw.append(result["salt"]).toLatin1(),
            QCryptographicHash::Sha256)
          .toHex())
      .arg(sender->getId());
    ServerInstance->database().exec(sql_update);
  }

  sender->doNotify("UpdatePassword", passed ? "1" : "0");
}

void Lobby::createRoom(ServerPlayer *sender, const QByteArray &jsonData) {
  auto arr = QCborValue::fromCbor(jsonData).toArray();
  auto name = arr[0].toString();
  auto capacity = arr[1].toInteger();
  auto timeout = arr[2].toInteger();
  auto settings = arr[3].toCbor();
  ServerInstance->createRoom(sender, name, capacity, timeout, settings);
}

void Lobby::getRoomConfig(ServerPlayer *sender, const QByteArray &jsonData) {
  auto arr = String2Json(jsonData).array();
  auto roomId = arr[0].toInt();
  auto room = ServerInstance->findRoom(roomId);
  if (room) {
    auto settings = room->getSettings();
    // 手搓JSON数组 跳过编码解码
    sender->doNotify("GetRoomConfig", QCborArray { roomId, settings }.toCborValue().toCbor());
  } else {
    sender->doNotify("ErrorMsg", "no such room");
  }
}

void Lobby::enterRoom(ServerPlayer *sender, const QByteArray &jsonData) {
  auto arr = QCborValue::fromCbor(jsonData).toArray();
  auto roomId = arr[0].toInteger();
  auto room = ServerInstance->findRoom(roomId);
  if (room) {
    auto settings = room->getSettingsObject();
    auto password = settings["password"_L1].toString();
    if (password.isEmpty() || arr[1].toString() == password) {
      if (room->isOutdated()) {
        sender->doNotify("ErrorMsg", "room is outdated");
      } else {
        room->addPlayer(sender);
      }
    } else {
      sender->doNotify("ErrorMsg", "room password error");
    }
  } else {
    sender->doNotify("ErrorMsg", "no such room");
  }
}

void Lobby::observeRoom(ServerPlayer *sender, const QByteArray &jsonData) {
  auto arr = QCborValue::fromCbor(jsonData).toArray();
  auto roomId = arr[0].toInteger();
  auto room = ServerInstance->findRoom(roomId);
  if (room) {
    auto settings = room->getSettingsObject();
    auto password = settings["password"_L1].toString();
    if (password.isEmpty() || arr[1].toString() == password) {
      if (room->isOutdated()) {
        sender->doNotify("ErrorMsg", "room is outdated");
      } else {
        room->addObserver(sender);
      }
    } else {
      sender->doNotify("ErrorMsg", "room password error");
    }
  } else {
    sender->doNotify("ErrorMsg", "no such room");
  }
}

void Lobby::refreshRoomList(ServerPlayer *sender, const QByteArray &) {
  ServerInstance->updateRoomList(sender);
};

void Lobby::handleTask(ServerPlayer *sender, const QByteArray &cbor) {
  auto arr = QCborValue::fromCbor(cbor).toArray();
  if (arr.size() != 2) return;
  auto type = arr[0].toString();
  auto data = arr[1].toCbor();

  auto &tm = ServerInstance->task_manager();
  auto &task = tm.createTask(type, data);
  tm.attachTaskToUser(task.getId(), sender->getConnId());
  task.start();
}

typedef void (Lobby::*room_cb)(ServerPlayer *, const QByteArray &);

void Lobby::handlePacket(ServerPlayer *sender, const QByteArray &command,
                        const QByteArray &jsonData) {
  static const QMap<QString, room_cb> lobby_actions = {
    {"UpdateAvatar", &Lobby::updateAvatar},
    {"UpdatePassword", &Lobby::updatePassword},
    {"CreateRoom", &Lobby::createRoom},
    {"GetRoomConfig", &Lobby::getRoomConfig},
    {"EnterRoom", &Lobby::enterRoom},
    {"ObserveRoom", &Lobby::observeRoom},
    {"RefreshRoomList", &Lobby::refreshRoomList},
    {"LobbyTask", &Lobby::handleTask},
    {"Chat", &Lobby::chat},
  };

  auto func = lobby_actions[command];
  if (func) (this->*func)(sender, jsonData);
}
