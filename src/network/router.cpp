// SPDX-License-Identifier: GPL-3.0-or-later

#include "network/router.h"
#include "network/client_socket.h"
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

bool Router::isConsoleStart() const {
  return socket->peerAddress() == "127.0.0.1";
}

void Router::setReplyReadySemaphore(QSemaphore *semaphore) {
  extraReplyReadySemaphore = semaphore;
}

void Router::request(int type, const QByteArray &command, const QByteArray &jsonData,
                     int timeout, qint64 timestamp) {
  // In case a request is called without a following waitForReply call
  if (replyReadySemaphore.available() > 0)
    replyReadySemaphore.acquire(replyReadySemaphore.available());

  static int requestId = 0;
  requestId++;

  replyMutex.lock();
  expectedReplyId = requestId;
  replyTimeout = timeout;
  requestStartTime = QDateTime::currentDateTime();
  m_reply = QStringLiteral("__notready");
  replyMutex.unlock();

  QJsonArray body;
  body << requestId;
  body << type;
  body << command.constData();
  body << jsonData.constData();
  body << timeout;
  body << (timestamp <= 0 ? requestStartTime.toMSecsSinceEpoch() : timestamp);

  sendMessage(JsonArray2Bytes(body));
}

void Router::reply(int type, const QByteArray &command, const QByteArray &jsonData) {
  QJsonArray body;
  body << this->requestId;
  body << type;
  body << command.constData();
  body << jsonData.constData();

  sendMessage(JsonArray2Bytes(body));
}

void Router::notify(int type, const QByteArray &command, const QByteArray &jsonData) {
  QJsonArray body;
  body << -2; // requestId = -2 mean this is for notification
  body << type;
  body << command.constData();
  body << jsonData.constData();

  sendMessage(JsonArray2Bytes(body));
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
    emit notification_got(command, jsonData);
  } else if (type & TYPE_REQUEST) {
    this->requestId = requestId;
    this->requestTimeout = packet[4].toInt();
    this->requestTimestamp = packet[5].toInteger();

    emit request_got(command, jsonData);
  } else if (type & TYPE_REPLY) {
    QMutexLocker locker(&replyMutex);

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

// 当发信息系列函数用于游戏中时（player:doNotify等），那个线程只发出信号就立刻返回了
// 在许多场合，信号的发送速度会比socket::send的速度快不少 导致队列中堆积不少信号
// 而如果玩家此时掉线那么队列中的信号疑似永远留在了队中（久而久之占用大量内存）
// 所以这里需要特地为此考虑多线程同步
void Router::sendMessage(const QByteArray &msg) {
  auto mainThr = this->thread();
  auto curThr = QThread::currentThread();
  emit messageReady(msg, QThread::currentThread());
  if (mainThr != curThr) socket->sendSema.acquire();
}
