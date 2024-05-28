#include "server/roombase.h"
#include "server/serverplayer.h"
#include "server/server.h"
#include "core/util.h"

Server *RoomBase::getServer() const { return server; }

bool RoomBase::isLobby() const {
  return inherits("Lobby");
}

QList<ServerPlayer *> RoomBase::getPlayers() const { return players; }

QList<ServerPlayer *> RoomBase::getOtherPlayers(ServerPlayer *expect) const {
  QList<ServerPlayer *> others = getPlayers();
  others.removeOne(expect);
  return others;
}

ServerPlayer *RoomBase::findPlayer(int id) const {
  foreach (ServerPlayer *p, players) {
    if (p->getId() == id)
      return p;
  }
  return nullptr;
}

void RoomBase::doBroadcastNotify(const QList<ServerPlayer *> targets,
                             const QString &command, const QString &jsonData) {
  foreach (ServerPlayer *p, targets) {
    p->doNotify(command, jsonData);
  }
}

void RoomBase::chat(ServerPlayer *sender, const QString &jsonData) {
  auto doc = String2Json(jsonData).object();
  auto type = doc["type"].toInt();
  doc["sender"] = sender->getId();

  // 屏蔽.号，防止有人在HTML文本发链接，而正常发链接看不出来有啥改动
  auto msg = doc["msg"].toString();
  msg.replace(".", "․");
  // 300字限制，与客户端相同
  msg.erase(msg.begin() + 300, msg.end());
  doc["msg"] = msg;
  if (!server->checkBanWord(msg)) {
    return;
  }

  if (type == 1) {
    doc["userName"] = sender->getScreenName();
    auto json = QJsonDocument(doc).toJson(QJsonDocument::Compact);
    doBroadcastNotify(players, "Chat", json);
  } else {
    auto json = QJsonDocument(doc).toJson(QJsonDocument::Compact);
    doBroadcastNotify(players, "Chat", json);
    doBroadcastNotify(observers, "Chat", json);
  }

  qInfo("[Chat] %s: %s", sender->getScreenName().toUtf8().constData(),
        doc["msg"].toString().toUtf8().constData());
}
