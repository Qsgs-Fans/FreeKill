// SPDX-License-Identifier: GPL-3.0-or-later

#include "serverplayer.h"
#include "client_socket.h"
#include "room.h"
#include "roomthread.h"
#include "router.h"
#include "server.h"

ServerPlayer::ServerPlayer(Room *room) {
  socket = nullptr;
  router = new Router(this, socket, Router::TYPE_SERVER);
  setState(Player::Online);
  this->room = room;
  server = room->getServer();
  connect(this, &ServerPlayer::kicked, this, &ServerPlayer::kick);

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
            &ServerPlayer::disconnected);
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

Room *ServerPlayer::getRoom() const { return room; }

void ServerPlayer::setRoom(Room *room) { this->room = room; }

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
  if (socket != nullptr) {
    socket->disconnectFromHost();
  }
  setSocket(nullptr);
}

bool ServerPlayer::thinking() const {
  return m_thinking;
}

void ServerPlayer::setThinking(bool t) {
  m_thinking = t;
}
