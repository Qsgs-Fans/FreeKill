#include "server/lobby.h"
#include "server/server.h"
#include "server/serverplayer.h"
#include "core/util.h"

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
    player->doNotify("EnterLobby", "[]");
  }

  server->updateOnlineInfo();
}

void Lobby::removePlayer(ServerPlayer *player) {
  players.removeOne(player);
  server->updateOnlineInfo();
}

void Lobby::updateAvatar(ServerPlayer *sender, const QString &jsonData) {
  auto arr = String2Json(jsonData).array();
  auto avatar = arr[0].toString();

  if (CheckSqlString(avatar)) {
    auto sql = QString("UPDATE userinfo SET avatar='%1' WHERE id=%2;")
      .arg(avatar)
      .arg(sender->getId());
    ExecSQL(ServerInstance->getDatabase(), sql);
    sender->setAvatar(avatar);
    sender->doNotify("UpdateAvatar", avatar);
  }
}

void Lobby::updatePassword(ServerPlayer *sender, const QString &jsonData) {
  auto arr = String2Json(jsonData).array();
  auto oldpw = arr[0].toString();
  auto newpw = arr[1].toString();
  auto sql_find =
    QString("SELECT password, salt FROM userinfo WHERE id=%1;")
    .arg(sender->getId());

  auto passed = false;
  auto arr2 = SelectFromDatabase(ServerInstance->getDatabase(), sql_find);
  auto result = arr2[0].toObject();
  passed = (result["password"].toString() ==
      QCryptographicHash::hash(
        oldpw.append(result["salt"].toString()).toLatin1(),
        QCryptographicHash::Sha256)
      .toHex());
  if (passed) {
    auto sql_update =
      QString("UPDATE userinfo SET password='%1' WHERE id=%2;")
      .arg(QCryptographicHash::hash(
            newpw.append(result["salt"].toString()).toLatin1(),
            QCryptographicHash::Sha256)
          .toHex())
      .arg(sender->getId());
    ExecSQL(ServerInstance->getDatabase(), sql_update);
  }

  sender->doNotify("UpdatePassword", passed ? "1" : "0");
}

void Lobby::createRoom(ServerPlayer *sender, const QString &jsonData) {
  auto arr = String2Json(jsonData).array();
  auto name = arr[0].toString();
  auto capacity = arr[1].toInt();
  auto timeout = arr[2].toInt();
  auto settings =
    QJsonDocument(arr[3].toObject()).toJson(QJsonDocument::Compact);
  ServerInstance->createRoom(sender, name, capacity, timeout, settings);
}

void Lobby::getRoomConfig(ServerPlayer *sender, const QString &jsonData) {
  auto arr = String2Json(jsonData).array();
  auto roomId = arr[0].toInt();
  auto room = ServerInstance->findRoom(roomId);
  if (room) {
    auto settings = room->getSettings();
    // 手搓JSON数组 跳过编码解码
    sender->doNotify("GetRoomConfig", QString("[%1,%2]").arg(roomId).arg(settings));
  } else {
    sender->doNotify("ErrorMsg", "no such room");
  }
}

void Lobby::enterRoom(ServerPlayer *sender, const QString &jsonData) {
  auto arr = String2Json(jsonData).array();
  auto roomId = arr[0].toInt();
  auto room = ServerInstance->findRoom(roomId);
  if (room) {
    auto settings = QJsonDocument::fromJson(room->getSettings());
    auto password = settings["password"].toString();
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

void Lobby::observeRoom(ServerPlayer *sender, const QString &jsonData) {
  auto arr = String2Json(jsonData).array();
  auto roomId = arr[0].toInt();
  auto room = ServerInstance->findRoom(roomId);
  if (room) {
    auto settings = QJsonDocument::fromJson(room->getSettings());
    auto password = settings["password"].toString();
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

void Lobby::refreshRoomList(ServerPlayer *sender, const QString &) {
  ServerInstance->updateRoomList(sender);
};

typedef void (Lobby::*room_cb)(ServerPlayer *, const QString &);

void Lobby::handlePacket(ServerPlayer *sender, const QString &command,
                        const QString &jsonData) {
  static const QMap<QString, room_cb> lobby_actions = {
    {"UpdateAvatar", &Lobby::updateAvatar},
    {"UpdatePassword", &Lobby::updatePassword},
    {"CreateRoom", &Lobby::createRoom},
    {"GetRoomConfig", &Lobby::getRoomConfig},
    {"EnterRoom", &Lobby::enterRoom},
    {"ObserveRoom", &Lobby::observeRoom},
    {"RefreshRoomList", &Lobby::refreshRoomList},
    {"Chat", &Lobby::chat},
  };

  auto func = lobby_actions[command];
  if (func) (this->*func)(sender, jsonData);
}
