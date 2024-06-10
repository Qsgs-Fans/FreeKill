// SPDX-License-Identifier: GPL-3.0-or-later

#include "network/router.h"
#include "client/client.h"
#include "network/client_socket.h"
#include "server/roomthread.h"
#include "server/server.h"
#include "server/serverplayer.h"
#include "core/util.h"

Router::Router(QObject *parent, ClientSocket *socket, RouterType type)
    : QObject(parent) {
  this->type = type;
  this->socket = nullptr;
  setSocket(socket);
  expectedReplyId = -1;
  replyTimeout = 0;
  extraReplyReadySemaphore = nullptr;
}

Router::~Router() { abortRequest(); }

ClientSocket *Router::getSocket() const { return socket; }

void Router::setSocket(ClientSocket *socket) {
  if (this->socket != nullptr) {
    this->socket->disconnect(this);
    disconnect(this->socket);
    this->socket->deleteLater();
  }

  this->socket = nullptr;
  if (socket != nullptr) {
    connect(this, &Router::messageReady, socket, &ClientSocket::send);
    connect(socket, &ClientSocket::message_got, this, &Router::handlePacket);
    connect(socket, &ClientSocket::disconnected, this, &Router::abortRequest);
    socket->setParent(this);
    this->socket = socket;
  }
}

void Router::removeSocket() {
  socket->disconnect(this);
  socket = nullptr;
}

void Router::installAESKey(const QByteArray &key) {
  socket->installAESKey(key);
}

bool Router::isConsoleStart() const {
  return socket->peerAddress() == "127.0.0.1";
}

void Router::setReplyReadySemaphore(QSemaphore *semaphore) {
  extraReplyReadySemaphore = semaphore;
}

void Router::request(int type, const QString &command, const QString &jsonData,
                     int timeout) {
  // In case a request is called without a following waitForReply call
  if (replyReadySemaphore.available() > 0)
    replyReadySemaphore.acquire(replyReadySemaphore.available());

  static int requestId = 0;
  requestId++;

  replyMutex.lock();
  expectedReplyId = requestId;
  replyTimeout = timeout;
  requestStartTime = QDateTime::currentDateTime();
  m_reply = "__notready";
  replyMutex.unlock();

  QJsonArray body;
  body << requestId;
  body << type;
  body << command;
  body << jsonData;
  body << timeout;

  emit messageReady(JsonArray2Bytes(body));
}

void Router::reply(int type, const QString &command, const QString &jsonData) {
  QJsonArray body;
  body << this->requestId;
  body << type;
  body << command;
  body << jsonData;

  emit messageReady(JsonArray2Bytes(body));
}

void Router::notify(int type, const QString &command, const QString &jsonData) {
  QJsonArray body;
  body << -2; // requestId = -2 mean this is for notification
  body << type;
  body << command;
  body << jsonData;

  emit messageReady(JsonArray2Bytes(body));
}

int Router::getTimeout() const { return requestTimeout; }

// cancel last request from the sender
void Router::cancelRequest() {
  replyMutex.lock();
  expectedReplyId = -1;
  replyTimeout = 0;
  extraReplyReadySemaphore = nullptr;
  replyMutex.unlock();

  if (replyReadySemaphore.available() > 0)
    replyReadySemaphore.acquire(replyReadySemaphore.available());
}

QString Router::waitForReply(int timeout) {
  QString ret;
  replyReadySemaphore.tryAcquire(1, timeout * 1000);
  replyMutex.lock();
  ret = m_reply;
  replyMutex.unlock();
  return ret;
}

void Router::abortRequest() {
  replyMutex.lock();
  if (expectedReplyId != -1) {
    replyReadySemaphore.release();
    if (extraReplyReadySemaphore)
      extraReplyReadySemaphore->release();
    expectedReplyId = -1;
    extraReplyReadySemaphore = nullptr;
  }
  replyMutex.unlock();
}

void Router::handlePacket(const QByteArray &rawPacket) {
  QJsonDocument packet = QJsonDocument::fromJson(rawPacket);
  if (packet.isNull() || !packet.isArray())
    return;

  int requestId = packet[0].toInt();
  int type = packet[1].toInt();
  QString command = packet[2].toString();
  QString jsonData = packet[3].toString();

  if (type & TYPE_NOTIFICATION) {
    if (type & DEST_CLIENT) {
#ifndef FK_SERVER_ONLY
      ClientInstance->callLua(command, jsonData, false);
#endif
    } else {
      ServerPlayer *player = qobject_cast<ServerPlayer *>(parent());
      if (command == "Heartbeat") {
        player->alive = true;
        return;
      }

      auto room = player->getRoom();
      room->handlePacket(player, command, jsonData);
    }
  } else if (type & TYPE_REQUEST) {
    this->requestId = requestId;
    this->requestTimeout = packet[4].toInt();

    if (type & DEST_CLIENT) {
#ifndef FK_SERVER_ONLY
      qobject_cast<Client *>(parent())->callLua(command, jsonData, true);
#endif
    } else {
      // requesting server is not allowed
      Q_ASSERT(false);
    }
  } else if (type & TYPE_REPLY) {
    QMutexLocker locker(&replyMutex);

    ServerPlayer *player = qobject_cast<ServerPlayer *>(parent());
    player->setThinking(false);
    auto _room = player->getRoom();
    if (!_room->isLobby()) {
      auto room = qobject_cast<Room *>(_room);
      if (room->getThread()) {
        room->getThread()->wakeUp(room->getId());
        // TODO: signal
      }
    }

    if (requestId != this->expectedReplyId)
      return;

    this->expectedReplyId = -1;

    if (replyTimeout >= 0 &&
        replyTimeout < requestStartTime.secsTo(QDateTime::currentDateTime()))
      return;

    m_reply = jsonData;
    // TODO: callback?

    replyReadySemaphore.release();
    if (extraReplyReadySemaphore) {
      extraReplyReadySemaphore->release();
      extraReplyReadySemaphore = nullptr;
    }

    locker.unlock();
    emit replyReady();
  }
}
