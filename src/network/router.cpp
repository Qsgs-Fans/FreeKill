// SPDX-License-Identifier: GPL-3.0-or-later

#include "network/router.h"
#include "network/client_socket.h"
#include "core/util.h"
#include <qnamespace.h>

Router::Router(QObject *parent, ClientSocket *socket, RouterType type)
    : QObject(parent) {
  this->type = type;
  this->socket = nullptr;
  setSocket(socket);
  expectedReplyIds.clear();
  replyTimeout = 0;
  extraReplyReadySemaphore = nullptr;
}

Router::~Router() {}

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
    socket->setParent(this);
    this->socket = socket;
  }
}

void Router::removeSocket() {
  socket->disconnect(this);
  socket = nullptr;
}

void Router::setReplyReadySemaphore(QSemaphore *semaphore) {
  extraReplyReadySemaphore = semaphore;
}

void Router::request(int type, const QByteArray &command, const QByteArray &cborData,
                     int timeout, qint64 timestamp) {
  // In case a request is called without a following waitForReply call
  if (replyReadySemaphore.available() > 0)
    replyReadySemaphore.acquire(replyReadySemaphore.available());

  static int requestId = 0;
  requestId++;
  if (requestId > 10000000) requestId = 1;

  replyMutex.lock();
  expectedReplyIds.push_back(requestId);
  replyTimeout = timeout;
  requestStartTime = QDateTime::currentDateTime();
  m_reply = QByteArrayLiteral("__notready");
  replyMutex.unlock();

  auto data = cborData;
  // TODO: 这些注释过几个版本再解锁，先只实现端解析压缩传输的那部分
  // if (cborData.size() > 1024) {
  //   data = qCompress(cborData);
  //   type |= COMPRESSED;
  // }

  QCborArray body {
    requestId,
    type,
    command,
    data,
    timeout,
    (timestamp <= 0 ? requestStartTime.toMSecsSinceEpoch() : timestamp)
  };

  sendMessage(body.toCborValue().toCbor());
}

void Router::reply(int type, const QByteArray &command, const QByteArray &cborData) {
  auto data = cborData;
  // if (cborData.size() > 1024) {
  //   data = qCompress(cborData);
  //   type |= COMPRESSED;
  // }

  QCborArray body {
    this->requestId,
    type,
    command,
    data,
  };

  sendMessage(body.toCborValue().toCbor());
}

void Router::notify(int type, const QByteArray &command, const QByteArray &cborData) {
  auto data = cborData;
  // if (cborData.size() > 1024) {
  //   data = qCompress(cborData);
  //   type |= COMPRESSED;
  // }

  QCborArray body {
    -2,
    type,
    command,
    data,
  };

  sendMessage(body.toCborValue().toCbor());
}

int Router::getTimeout() const { return requestTimeout; }

// cancel last request from the sender
void Router::cancelRequest() {
  replyMutex.lock();
  expectedReplyIds.pop_back();
  replyTimeout = 0;
  extraReplyReadySemaphore = nullptr;
  replyMutex.unlock();

  if (replyReadySemaphore.available() > 0)
    replyReadySemaphore.acquire(replyReadySemaphore.available());
}

QByteArray Router::waitForReply(int timeout) {
  QByteArray ret;
  replyReadySemaphore.tryAcquire(1, timeout * 1000);
  replyMutex.lock();
  ret = m_reply;
  replyMutex.unlock();
  return ret;
}

void Router::handlePacket(const QCborArray &packet) {
  int requestId = packet[0].toInteger();
  int type = packet[1].toInteger();
  auto command = packet[2].toByteArray();
  auto cborData = packet[3].toByteArray();

  if (type & COMPRESSED) {
    cborData = qUncompress(cborData);
  }

  if (type & TYPE_NOTIFICATION) {
    emit notification_got(command, cborData);
  } else if (type & TYPE_REQUEST) {
    this->requestId = requestId;
    this->requestTimeout = packet[4].toInteger();
    this->requestTimestamp = packet[5].toInteger();

    emit request_got(command, cborData);
  } else if (type & TYPE_REPLY) {
    QMutexLocker locker(&replyMutex);

    auto it = std::find(expectedReplyIds.begin(), expectedReplyIds.end(), requestId);
    if (it == expectedReplyIds.end())
      return;

    expectedReplyIds.erase(it);

    if (replyTimeout >= 0 &&
      replyTimeout < requestStartTime.secsTo(QDateTime::currentDateTime()))
      return;

    m_reply = cborData;
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

void Router::sendMessage(const QByteArray &msg) {
  emit messageReady(msg);
}
