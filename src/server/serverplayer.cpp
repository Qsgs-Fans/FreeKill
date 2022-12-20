#include "serverplayer.h"
#include "room.h"
#include "server.h"
#include "router.h"
#include "client_socket.h"

ServerPlayer::ServerPlayer(Room *room)
{
  socket = nullptr;
  router = new Router(this, socket, Router::TYPE_SERVER);
  setState(Player::Online);
  this->room = room;
  server = room->getServer();
}

ServerPlayer::~ServerPlayer()
{
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

void ServerPlayer::setSocket(ClientSocket *socket)
{
  if (this->socket != nullptr) {
    this->socket->disconnect(this);
    disconnect(this->socket);
    this->socket->deleteLater();
  }

  this->socket = nullptr;
  if (socket != nullptr) {
    connect(socket, &ClientSocket::disconnected, this, &ServerPlayer::disconnected);
    this->socket = socket;
  }

  router->setSocket(socket);
}

ClientSocket *ServerPlayer::getSocket() const
{
  return socket;
}

Server *ServerPlayer::getServer() const
{
  return server;
}

Room *ServerPlayer::getRoom() const
{
  return room;
}

void ServerPlayer::setRoom(Room* room)
{
  this->room = room;
}

void ServerPlayer::speak(const QString& message)
{
  ;
}

void ServerPlayer::doRequest(const QString& command, const QString& jsonData, int timeout)
{
  if (getState() != Player::Online) return;
  int type = Router::TYPE_REQUEST | Router::SRC_SERVER | Router::DEST_CLIENT;
  router->request(type, command, jsonData, timeout);
}

void ServerPlayer::abortRequest()
{
  router->abortRequest();
}

QString ServerPlayer::waitForReply()
{
  QString ret;
  Player::State state = getState();
  if (state != Player::Online) {
    if (state != Player::Run)
      QThread::sleep(1);
    ret = QString("__state=%1").arg(getStateString());
  } else {
    ret = router->waitForReply();
  }
  return ret;
}

QString ServerPlayer::waitForReply(int timeout)
{
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

void ServerPlayer::doNotify(const QString& command, const QString& jsonData)
{
  if (getState() != Player::Online) return;
  int type = Router::TYPE_NOTIFICATION | Router::SRC_SERVER | Router::DEST_CLIENT;
  router->notify(type, command, jsonData);
}

void ServerPlayer::prepareForRequest(const QString& command, const QString& data)
{
  requestCommand = command;
  requestData = data;
}
