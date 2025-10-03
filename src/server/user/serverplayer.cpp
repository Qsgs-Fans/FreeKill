// SPDX-License-Identifier: GPL-3.0-or-later

#include "server/user/serverplayer.h"
#include "network/client_socket.h"
#include "server/room/room.h"
#include "server/gamelogic/roomthread.h"
#include "network/router.h"
#include "server/server.h"
#include "core/c-wrapper.h"

using namespace Qt::Literals::StringLiterals;

ServerPlayer::ServerPlayer(RoomBase *roombase) {
  socket = nullptr;
  router = new Router(this, socket, Router::TYPE_SERVER);
  connect(router, &Router::notification_got, this, &ServerPlayer::onNotificationGot);
  connect(router, &Router::replyReady, this, &ServerPlayer::onReplyReady);

  setState(Player::Online);
  room = roombase;
  server = room->getServer();
  connect(this, &ServerPlayer::kicked, this, &ServerPlayer::kick);
  connect(this, &Player::stateChanged, this, &ServerPlayer::onStateChanged);
  connect(this, &Player::readyChanged, this, &ServerPlayer::onReadyChanged);

  connId = QUuid::createUuid().toString();
  alive = true;
  m_thinking = false;
}

ServerPlayer::~ServerPlayer() {
  // 机器人直接被Room删除了
  if (getId() < 0) return;

  // 真人的话 需要先退出房间，再退出大厅
  room->removePlayer(this);
  if (room != nullptr) {
    room->removePlayer(this);
  }

  // 最后服务器删除他
  if (server->findPlayer(getId()) == this)
    server->removePlayer(getId());

  server->removePlayerByConnId(connId);
}

void ServerPlayer::setSocket(ClientSocket *socket) {
  if (this->socket != nullptr) {
    this->socket->disconnect(this);
    disconnect(this->socket);
    this->socket->deleteLater();
  }

  this->socket = nullptr;
  if (socket != nullptr) {
    connect(socket, &ClientSocket::disconnected, this,
            &ServerPlayer::onDisconnected);
    this->socket = socket;
  }

  router->setSocket(socket);
}

ClientSocket *ServerPlayer::getSocket() const { return socket; }

QString ServerPlayer::getPeerAddress() const {
  auto p = server->findPlayer(getId());
  if (!p || p->getState() != Player::Online)
    return "";
  return p->getSocket()->peerAddress();
}

QString ServerPlayer::getUuid() const {
  return uuid_str;
}

void ServerPlayer::setUuid(QString uuid) {
  uuid_str = uuid;
}

// 处理跑路玩家专用，就单纯把socket置为null
// 因为后面还会用到socket所以不删除
void ServerPlayer::removeSocket() {
  socket->disconnect(this);
  socket = nullptr;
  router->removeSocket();
}

Server *ServerPlayer::getServer() const { return server; }

RoomBase *ServerPlayer::getRoom() const { return room; }

void ServerPlayer::setRoom(RoomBase *room) { this->room = room; }

void ServerPlayer::speak(const QString &message) { ; }

void ServerPlayer::doRequest(const QByteArray &command, const QByteArray &jsonData,
                             int timeout, qint64 timestamp) {
  if (getState() != Player::Online)
    return;

  int type = Router::TYPE_REQUEST | Router::SRC_SERVER | Router::DEST_CLIENT;
  router->request(type, command, jsonData, timeout, timestamp);
}

void ServerPlayer::abortRequest() { router->abortRequest(); }

QByteArray ServerPlayer::waitForReply(int timeout) {
  QByteArray ret;
  if (getState() != Player::Online) {
#ifndef QT_DEBUG
    QThread::sleep(1);
#endif
    ret = QByteArrayLiteral("__cancel");
  } else {
    ret = router->waitForReply(timeout);
  }
  return ret;
}

void ServerPlayer::doNotify(const QByteArray &command, const QByteArray &jsonData) {
  if (getState() != Player::Online)
    return;
  int type =
      Router::TYPE_NOTIFICATION | Router::SRC_SERVER | Router::DEST_CLIENT;
  router->notify(type, command, jsonData);
}

void ServerPlayer::prepareForRequest(const QString &command,
                                     const QString &data) {
  requestCommand = command;
  requestData = data;
}

void ServerPlayer::kick() {
  setState(Player::Offline);
  if (socket != nullptr) {
    socket->disconnectFromHost();
  } else {
    // 还是得走一遍这个流程才行
    onDisconnected();
  }
  setSocket(nullptr);
}

void ServerPlayer::reconnect(ClientSocket *client) {
  if (server->getPlayers().count() <= 10) {
    server->broadcast("ServerMessage", tr("%1 backed").arg(getScreenName()).toUtf8());
  }

  setState(Player::Online);
  setSocket(client);
  alive = true;
  // client->disconnect(this);

  if (room && !room->isLobby()) {
    server->setupPlayer(this, true);
    qobject_cast<Room *>(room)->pushRequest(QString("%1,reconnect").arg(getId()));
  } else {
    // 懒得处理掉线玩家在大厅了！踢掉得了
    doNotify("ErrorMsg", "Unknown Error");
    emit kicked();
  }
}

bool ServerPlayer::thinking() {
  QMutexLocker locker(&m_thinking_mutex);
  return m_thinking;
}

void ServerPlayer::setThinking(bool t) {
  QMutexLocker locker(&m_thinking_mutex);
  m_thinking = t;
}

void ServerPlayer::startGameTimer() {
  gameTime = 0;
  gameTimer.start();
}

void ServerPlayer::pauseGameTimer() {
  gameTime += gameTimer.elapsed() / 1000;
}

void ServerPlayer::resumeGameTimer() {
  gameTimer.start();
}

int ServerPlayer::getGameTime() {
  return gameTime + (getState() == Player::Online ? gameTimer.elapsed() / 1000 : 0);
}

void ServerPlayer::onNotificationGot(const QByteArray &c, const QByteArray &j) {
  if (c == "Heartbeat") {
    alive = true;
    return;
  }

  room->handlePacket(this, c, j);
}

void ServerPlayer::onReplyReady() {
  setThinking(false);
  if (!room->isLobby()) {
    auto _room = qobject_cast<Room *>(room);
    auto thread = qobject_cast<RoomThread *>(_room->parent());
    thread->wakeUp(_room->getId(), "reply");
  }
}

void ServerPlayer::onStateChanged() {
  auto _room = getRoom();
  if (!_room || _room->isLobby()) return;
  auto room = qobject_cast<Room *>(_room);
  if (room->hasObserver(this)) return;

  auto thread = qobject_cast<RoomThread *>(room->parent());
  if (thread) {
    emit thread->setPlayerState(connId, room->getId());
  }

  if (room->isAbandoned()) return;

  auto state = getState();
  room->doBroadcastNotify(room->getPlayers(), "NetStateChanged",
      QCborArray { getId(), getStateString() }.toCborValue().toCbor());

  if (state == Player::Online) {
    resumeGameTimer();
  } else {
    pauseGameTimer();
  }
}

void ServerPlayer::onReadyChanged() {
  if (room && !room->isLobby()) {
    room->doBroadcastNotify(room->getPlayers(), "ReadyChanged",
                            QCborArray { getId(), isReady() }.toCborValue().toCbor());
  }
}

void ServerPlayer::onDisconnected() {
  qInfo() << "Player" << getId() << "disconnected";
  if (server->getPlayers().count() <= 10) {
      server->broadcast("ServerMessage", tr("%1 logged out").arg(getScreenName()).toUtf8());;
  }

  auto _room = getRoom();
  if (_room->isLobby()) {
    setState(Player::Robot); // 大厅！然而又不能设Offline
    deleteLater();
  } else {
    auto room = qobject_cast<Room *>(_room);
    if (room->isStarted()) {
      if (room->getObservers().contains(this)) {
        room->removeObserver(this);
        deleteLater();
        return;
      }
      if (thinking()) {
        auto thread = qobject_cast<RoomThread *>(room->parent());
        thread->wakeUp(room->getId(), "player_disconnect");
      }
      setState(Player::Offline);
      setSocket(nullptr);
      // TODO: add a robot
    } else {
      setState(Player::Robot); // 大厅！然而又不能设Offline
      // 这里有一个多线程问题，可能与Room::gameOver同时deleteLater导致出事
      // FIXME: 这种解法肯定不安全
      if (!room->insideGameOver)
        deleteLater();
    }
  }
}

void ServerPlayer::saveState(const QString &jsonData) {
  if (getId() < 0) return;
  auto room_base = getRoom();
  if (!room_base) return;
  auto room = dynamic_cast<Room *>(room_base);
  if (!room) return;
  QString mode { room->getSettingsObject()["gameMode"_L1].toString() };

  if (!Sqlite3::checkString(mode)) {
    qWarning("Invalid mode string for saveState: %ls", qUtf16Printable(mode));
    return;
  }

  auto hexData = jsonData.toUtf8().toHex();
  auto gamedb = ServerInstance->getGameDatabase();
  auto sql = QString("REPLACE INTO gameSaves (uid, mode, data) VALUES (%1,'%2',X'%3')").arg(getId()).arg(mode).arg(hexData);

  gamedb->exec(sql);
}

QString ServerPlayer::getSaveState() {
  auto room_base = getRoom();
  if (!room_base) return "{}";
  auto room = dynamic_cast<Room *>(room_base);
  if (!room) return "{}";
  QString mode { room->getSettingsObject()["gameMode"_L1].toString() };

  if (!Sqlite3::checkString(mode)) {
    qWarning("Invalid mode string for saveState: %ls", qUtf16Printable(mode));
    return "{}";
  }

  auto sql = QString("SELECT data FROM gameSaves WHERE uid = %1 AND mode = '%2'").arg(getId()).arg(mode);

  auto result = ServerInstance->getGameDatabase()->select(sql);
  if (result.empty() || result[0].count("data") == 0 || result[0]["data"] == "#null") {
    return "{}";
  }

  const auto& data = result[0]["data"];
  if (!data.isEmpty() && (data[0] == '{' || data[0] == '[')) {
    return data;
  }

  qWarning("Returned data is not valid JSON: %ls", qUtf16Printable(data));
  return "{}";
}

void ServerPlayer::saveGlobalState(const QString &key, const QString &jsonData) {
  if (getId() < 0) return;
  if (!Sqlite3::checkString(key)) {
    qWarning("Invalid key string for saveGlobalState: %ls", qUtf16Printable(key));
    return;
  }

  auto hexData = jsonData.toUtf8().toHex();
  auto gamedb = ServerInstance->getGameDatabase();
  auto sql = QString("REPLACE INTO globalSaves (uid, key, data) VALUES (%1,'%2',X'%3')").arg(getId()).arg(key).arg(hexData);

  gamedb->exec(sql);
}

QString ServerPlayer::getGlobalSaveState(const QString &key) {
  if (!Sqlite3::checkString(key)) {
    qWarning("Invalid key string for getGlobalSaveState: %ls", qUtf16Printable(key));
    return "{}";
  }

  auto sql = QString("SELECT data FROM globalSaves WHERE uid = %1 AND key = '%2'").arg(getId()).arg(key);

  auto result = ServerInstance->getGameDatabase()->select(sql);
  if (result.empty() || result[0].count("data") == 0 || result[0]["data"] == "#null") {
    return "{}";
  }

  const auto& data = result[0]["data"];
  if (!data.isEmpty() && (data[0] == '{' || data[0] == '[')) {
    return data;
  }

  qWarning("Returned data is not valid JSON: %ls", qUtf16Printable(data));
  return "{}";
}
