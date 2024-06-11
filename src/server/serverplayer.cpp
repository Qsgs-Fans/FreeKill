// SPDX-License-Identifier: GPL-3.0-or-later

#include "server/serverplayer.h"
#include "network/client_socket.h"
#include "server/room.h"
#include "server/roomthread.h"
#include "network/router.h"
#include "server/server.h"

ServerPlayer::ServerPlayer(RoomBase *room) {
  socket = nullptr;
  router = new Router(this, socket, Router::TYPE_SERVER);
  setState(Player::Online);
  this->room = room;
  server = room->getServer();
  connect(this, &ServerPlayer::kicked, this, &ServerPlayer::kick);
  connect(this, &Player::stateChanged, this, &ServerPlayer::onStateChanged);

  alive = true;
  m_busy = false;
  m_thinking = false;
}

ServerPlayer::~ServerPlayer() {
  // clean up, quit room and server
  room->removePlayer(this);
  if (room != nullptr) {
    // now we are in lobby, so quit lobby
    room->removePlayer(this);
  }
  if (server->findPlayer(getId()) == this)
    server->removePlayer(getId());
  router->deleteLater();
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

void ServerPlayer::doRequest(const QString &command, const QString &jsonData,
                             int timeout) {
  if (getState() != Player::Online)
    return;
  int type = Router::TYPE_REQUEST | Router::SRC_SERVER | Router::DEST_CLIENT;
  router->request(type, command, jsonData, timeout);
}

void ServerPlayer::abortRequest() { router->abortRequest(); }

QString ServerPlayer::waitForReply(int timeout) {
  QString ret;
  if (getState() != Player::Online) {
#ifndef QT_DEBUG
    QThread::sleep(1);
#endif
    ret = "__cancel";
  } else {
    ret = router->waitForReply(timeout);
  }
  return ret;
}

void ServerPlayer::doNotify(const QString &command, const QString &jsonData) {
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
  setSocket(client);
  alive = true;
  // client->disconnect(this);
  if (server->getPlayers().count() <= 10) {
    server->broadcast("ServerMessage", tr("%1 backed").arg(getScreenName()));
  }

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
  m_thinking_mutex.lock();
  bool ret = m_thinking;
  m_thinking_mutex.unlock();
  return ret;
}

void ServerPlayer::setThinking(bool t) {
  m_thinking_mutex.lock();
  m_thinking = t;
  m_thinking_mutex.unlock();
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

void ServerPlayer::onStateChanged() {
  auto _room = getRoom();
  if (!_room || _room->isLobby()) return;
  auto room = qobject_cast<Room *>(_room);
  if (room->isAbandoned()) return;

  auto state = getState();
  room->doBroadcastNotify(room->getPlayers(), "NetStateChanged",
      QString("[%1,\"%2\"]").arg(getId()).arg(getStateString()));

  if (state == Player::Online) {
    resumeGameTimer();
  } else {
    pauseGameTimer();
  }
}

void ServerPlayer::onDisconnected() {
  qInfo() << "Player" << getId() << "disconnected";
  if (server->getPlayers().count() <= 10) {
    server->broadcast("ServerMessage", tr("%1 logged out").arg(getScreenName()));
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
