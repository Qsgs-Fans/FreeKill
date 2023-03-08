#include "router.h"
#include "client.h"
#include "client_socket.h"
#include <qjsondocument.h>
#ifndef FK_CLIENT_ONLY
#include "server.h"
#include "serverplayer.h"
#endif
#include "util.h"

Router::Router(QObject *parent, ClientSocket *socket, RouterType type)
  : QObject(parent)
{
  this->type = type;
  this->socket = nullptr;
  setSocket(socket);
  expectedReplyId = -1;
  replyTimeout = 0;
#ifndef FK_CLIENT_ONLY
  extraReplyReadySemaphore = nullptr;
#endif
}

Router::~Router()
{
  abortRequest();
}

ClientSocket* Router::getSocket() const
{
  return socket;
}

void Router::setSocket(ClientSocket *socket)
{
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

#ifndef FK_CLIENT_ONLY
void Router::setReplyReadySemaphore(QSemaphore *semaphore)
{
  extraReplyReadySemaphore = semaphore;
}
#endif

void Router::request(int type, const QString& command,
           const QString& jsonData, int timeout)
{
#ifndef FK_CLIENT_ONLY
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
#endif
}

void Router::reply(int type, const QString& command, const QString& jsonData)
{
  QJsonArray body;
  body << this->requestId;
  body << type;
  body << command;
  body << jsonData;

  emit messageReady(JsonArray2Bytes(body));
}

void Router::notify(int type, const QString& command, const QString& jsonData)
{
  QJsonArray body;
  body << -2;     // requestId = -2 mean this is for notification
  body << type;
  body << command;
  body << jsonData;

  emit messageReady(JsonArray2Bytes(body));
}

int Router::getTimeout() const
{
  return requestTimeout;
}

// cancel last request from the sender
void Router::cancelRequest()
{
#ifndef FK_CLIENT_ONLY
  replyMutex.lock();
  expectedReplyId = -1;
  replyTimeout = 0;
  extraReplyReadySemaphore = nullptr;
  replyMutex.unlock();

  if (replyReadySemaphore.available() > 0)
    replyReadySemaphore.acquire(replyReadySemaphore.available());
#endif
}

QString Router::waitForReply(int timeout)
{
  QString ret;
#ifndef FK_CLIENT_ONLY
  replyReadySemaphore.tryAcquire(1, timeout * 1000);
  replyMutex.lock();
  ret = m_reply;
  replyMutex.unlock();
#endif
  return ret;
}

void Router::abortRequest()
{
#ifndef FK_CLIENT_ONLY
  replyMutex.lock();
  if (expectedReplyId != -1) {
    replyReadySemaphore.release();
    if (extraReplyReadySemaphore)
      extraReplyReadySemaphore->release();
    expectedReplyId = -1;
    extraReplyReadySemaphore = nullptr;
  }
  replyMutex.unlock();
#endif
}

void Router::handlePacket(const QByteArray& rawPacket)
{
#ifndef FK_CLIENT_ONLY
  static QMap<QString, void (*)(ServerPlayer *, const QString &)> lobby_actions;
  if (lobby_actions.size() <= 0) {
    lobby_actions["UpdateAvatar"] = [](ServerPlayer *sender, const QString &jsonData){
      auto arr = String2Json(jsonData).array();
      auto avatar = arr[0].toString();
      static QRegularExpression nameExp("[\\000-\\057\\072-\\100\\133-\\140\\173-\\177]");
      if (!nameExp.match(avatar).hasMatch()) {
        auto sql = QString("UPDATE userinfo SET avatar='%1' WHERE id=%2;")
          .arg(avatar).arg(sender->getId());
        ExecSQL(ServerInstance->getDatabase(), sql);
        sender->setAvatar(avatar);
        sender->doNotify("UpdateAvatar", avatar);
      }
    };
    lobby_actions["UpdatePassword"] = [](ServerPlayer *sender, const QString &jsonData){
      auto arr = String2Json(jsonData).array();
      auto oldpw = arr[0].toString();
      auto newpw = arr[1].toString();
      auto sql_find = QString("SELECT password, salt FROM userinfo WHERE id=%1;")
        .arg(sender->getId());

      auto passed = false;
      auto arr2 = SelectFromDatabase(ServerInstance->getDatabase(), sql_find);
      auto result = arr2[0].toObject();
      passed = (result["password"].toString() ==
        QCryptographicHash::hash(
          oldpw.append(result["salt"].toString()).toLatin1(),
          QCryptographicHash::Sha256).toHex());
      if (passed) {
        auto sql_update = QString("UPDATE userinfo SET password='%1' WHERE id=%2;")
          .arg(QCryptographicHash::hash(
            newpw.append(result["salt"].toString()).toLatin1(),
            QCryptographicHash::Sha256).toHex())
          .arg(sender->getId());
        ExecSQL(ServerInstance->getDatabase(), sql_update);
      }

      sender->doNotify("UpdatePassword", passed ? "1" : "0");
    };
    lobby_actions["CreateRoom"] = [](ServerPlayer *sender, const QString &jsonData){
      auto arr = String2Json(jsonData).array();
      auto name = arr[0].toString();
      auto capacity = arr[1].toInt();
      auto settings = QJsonDocument(arr[2].toObject()).toJson(QJsonDocument::Compact);
      ServerInstance->createRoom(sender, name, capacity, settings);
    };
    lobby_actions["EnterRoom"] = [](ServerPlayer *sender, const QString &jsonData){
      auto arr = String2Json(jsonData).array();
      auto roomId = arr[0].toInt();
      ServerInstance->findRoom(roomId)->addPlayer(sender);
    };
    lobby_actions["ObserveRoom"] = [](ServerPlayer *sender, const QString &jsonData){
      auto arr = String2Json(jsonData).array();
      auto roomId = arr[0].toInt();
      ServerInstance->findRoom(roomId)->addObserver(sender);
    };
    lobby_actions["Chat"] = [](ServerPlayer *sender, const QString &jsonData){
      sender->getRoom()->chat(sender, jsonData);
    };
  }
#endif

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
      ClientInstance->callLua(command, jsonData);
#endif
    }
#ifndef FK_CLIENT_ONLY
    else
    {
      ServerPlayer *player = qobject_cast<ServerPlayer *>(parent());

      Room *room = player->getRoom();
      if (room->isLobby() && lobby_actions.contains(command))
        lobby_actions[command](player, jsonData);
      else {
        if (command == "QuitRoom") {
          room->removePlayer(player);
        } else if (command == "AddRobot") {
          room->addRobot(player);
        } else if (command == "Chat") {
          room->chat(player, jsonData);
        }
      }
    }
#endif
  }
  else if (type & TYPE_REQUEST) {
    this->requestId = requestId;
    this->requestTimeout = packet[4].toInt();

    if (type & DEST_CLIENT) {
#ifndef FK_SERVER_ONLY
      qobject_cast<Client *>(parent())->callLua(command, jsonData);
#endif
    } else {
      // requesting server is not allowed
      Q_ASSERT(false);
    }
  }
#ifndef FK_CLIENT_ONLY
  else if (type & TYPE_REPLY) {
    QMutexLocker locker(&replyMutex);

    if (requestId != this->expectedReplyId)
      return;

    this->expectedReplyId = -1;

    if (replyTimeout >= 0 && replyTimeout <
      requestStartTime.secsTo(QDateTime::currentDateTime()))
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
#endif
}

