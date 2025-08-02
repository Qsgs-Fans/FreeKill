#include "server/room/roombase.h"
#include "server/user/serverplayer.h"
#include "server/server.h"
#include "core/util.h"

using namespace Qt::Literals::StringLiterals;

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
  for (auto p : players) {
    if (p->getId() == id)
      return p;
  }
  return nullptr;
}

void RoomBase::doBroadcastNotify(const QList<ServerPlayer *> targets,
                             const QByteArray &command, const QByteArray &jsonData) {
  for (auto p : targets) {
    p->doNotify(command, jsonData);
  }
}

void RoomBase::chat(ServerPlayer *sender, const QByteArray &jsonData) {
  auto doc = QCborValue::fromCbor(jsonData).toMap();
  auto type = doc.value("type").toInteger();
  doc["sender"_L1] = sender->getId();
  auto msgkey = "msg"_L1;

  auto msg = doc.value(msgkey).toString();
  if (!server->checkBanWord(msg)) {
    return;
  }
  // 屏蔽.号和百分号，防止有人在HTML文本发链接，而正常发链接看不出来有啥改动
  msg.replace(".", "․");
  msg.replace("%", "％");
  // 300字限制，与客户端相同
  msg.erase(msg.begin() + 300, msg.end());
  doc[msgkey] = msg;

  if (type == 1) {
    doc["userName"_L1] = sender->getScreenName();
    doBroadcastNotify(players, "Chat", doc.toCborValue().toCbor());
  } else {
    doBroadcastNotify(players, "Chat", doc.toCborValue().toCbor());
    doBroadcastNotify(observers, "Chat", doc.toCborValue().toCbor());
  }

  qInfo("[Chat/%ls] %ls: %ls",
        qUtf16Printable(isLobby() ? "Lobby" :
                        QString("#%1").arg(qobject_cast<Room *>(this)->getId())),
        qUtf16Printable(sender->getScreenName()),
        qUtf16Printable(doc[msgkey].toString()));
}
