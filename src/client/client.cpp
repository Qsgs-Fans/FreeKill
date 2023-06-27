// SPDX-License-Identifier: GPL-3.0-or-later

#include "client.h"
#include "client_socket.h"
#include "clientplayer.h"
#include "util.h"

Client *ClientInstance = nullptr;
ClientPlayer *Self = nullptr;

static ClientPlayer dummyPlayer(0, nullptr);

Client::Client(QObject *parent) : QObject(parent), callback(0) {
  ClientInstance = this;
  Self = new ClientPlayer(0, this);
  self = Self;
  QQmlApplicationEngine *engine = Backend->getEngine();
  engine->rootContext()->setContextProperty("ClientInstance", ClientInstance);
  engine->rootContext()->setContextProperty("Self", Self);

  ClientSocket *socket = new ClientSocket;
  connect(socket, &ClientSocket::error_message, this, &Client::error_message);
  router = new Router(this, socket, Router::TYPE_CLIENT);

  L = CreateLuaState();
  DoLuaScript(L, "lua/freekill.lua");
  DoLuaScript(L, "lua/client/client.lua");
}

Client::~Client() {
  ClientInstance = nullptr;
  // Self->deleteLater();
  Self = nullptr;
  Backend->getEngine()->rootContext()->setContextProperty("Self", &dummyPlayer);
  lua_close(L);
  router->getSocket()->disconnectFromHost();
  router->getSocket()->deleteLater();
}

void Client::connectToHost(const QString &server, ushort port) {
  router->getSocket()->connectToHost(server, port);
}

void Client::replyToServer(const QString &command, const QString &jsonData) {
  int type = Router::TYPE_REPLY | Router::SRC_CLIENT | Router::DEST_SERVER;
  router->reply(type, command, jsonData);
}

void Client::notifyServer(const QString &command, const QString &jsonData) {
  int type =
      Router::TYPE_NOTIFICATION | Router::SRC_CLIENT | Router::DEST_SERVER;
  router->notify(type, command, jsonData);
}

ClientPlayer *Client::addPlayer(int id, const QString &name,
                                const QString &avatar) {
  ClientPlayer *player = new ClientPlayer(id);
  player->setScreenName(name);
  player->setAvatar(avatar);

  players[id] = player;
  return player;
}

void Client::removePlayer(int id) {
  ClientPlayer *p = players[id];
  p->deleteLater();
  players[id] = nullptr;
}

void Client::clearPlayers() { players.clear(); }

void Client::changeSelf(int id) {
  auto p = players[id];
  Self = p ? p : self;
  Backend->getEngine()->rootContext()->setContextProperty("Self", Self);
}

lua_State *Client::getLuaState() { return L; }

void Client::installAESKey(const QByteArray &key) { router->installAESKey(key); }

void Client::saveRecord(const QString &json, const QString &fname) {
  if (!QDir("recording").exists()) {
    QDir(".").mkdir("recording");
  }
  QFile c("recording/" + fname + ".fk.rep");
  c.open(QIODevice::WriteOnly);
  c.write(qCompress(json.toUtf8()));
  c.close();
}
