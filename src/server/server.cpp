// SPDX-License-Identifier: GPL-3.0-or-later

#include "server/server.h"
#include "server/user/auth.h"
#include "server/user/serverplayer.h"
#include "server/room/room.h"
#include "server/room/lobby.h"
#include "server/gamelogic/roomthread.h"
#include "network/router.h"
#include "network/client_socket.h"
#include "network/server_socket.h"
#include "core/packman.h"
#include "core/c-wrapper.h"
#include "core/util.h"
#include "server/task/task_manager.h"
#include "server/task/task.h"

#include <QNetworkDatagram>
#include <memory>

using namespace Qt::Literals::StringLiterals;

Server *ServerInstance = nullptr;

Server::Server(QObject *parent) : QObject(parent) {
  ServerInstance = this;
  db = std::make_unique<Sqlite3>();
  gamedb = std::make_unique<Sqlite3>("./server/game.db", "./server/gamedb_init.sql");
  md5 = calcFileMD5();
  readConfig();

  m_task_manager = std::make_unique<TaskManager>();

  auth = std::make_unique<AuthManager>();
  server = new ServerSocket(this);
  connect(server, &ServerSocket::new_connection, this,
          &Server::processNewConnection);

  nextRoomId = 1;
  m_lobby = new Lobby(this);

  // 启动心跳包线程
  auto heartbeatThread = QThread::create([=]() {
    while (true) {
      for (auto p : this->players.values()) {
        if (p->getState() == Player::Online) {
          p->alive = false;
          p->doNotify("Heartbeat", "");
        }
      }

      for (int i = 0; i < 30; i++) {
        if (!this->isListening) {
          return;
        }
        QThread::sleep(1);
      }

      for (auto p : this->players.values()) {
        if (p->getState() == Player::Online && !p->alive) {
          emit p->kicked();
        }
      }
    }
  });
  heartbeatThread->setParent(this);
  heartbeatThread->setObjectName("Heartbeat");
  heartbeatThread->start();
}

Server::~Server() {
  isListening = false;
  // 虽然都是子对象 但析构顺序要抠一下
  // for (auto p : findChildren<ServerPlayer *>()) {
  //   delete p;
  // }

  // 得先清理threads及其Rooms 因为其中某些析构函数要调用sql
  for (auto thr : findChildren<RoomThread *>()) {
    delete thr;
  }

  ServerInstance = nullptr;
}

bool Server::listen(const QHostAddress &address, ushort port) {
  bool ret = server->listen(address, port);
  isListening = ret;
  if (ret) {
    uptime_counter.restart();
    qInfo("Server is listening on port %d", port);
  }
  return ret;
}

void Server::createRoom(ServerPlayer *owner, const QString &name, int capacity,
                        int timeout, const QByteArray &settings) {
  if (!checkBanWord(name)) {
    if (owner) {
      owner->doNotify("ErrorMsg", "unk error");
    }
    return;
  }

  auto room = new Room(getAvailableThread());
  rooms.insert(room->getId(), room);
  room->setName(name);
  room->setCapacity(capacity);
  room->setTimeout(timeout);
  room->setSettings(settings);
  room->addPlayer(owner);
  room->setOwner(owner);
}

void Server::removeRoom(int id) {
  rooms.remove(id);
}

Room *Server::findRoom(int id) const { return rooms.value(id); }

Lobby *Server::lobby() const { return m_lobby; }

TaskManager &Server::task_manager() const { return *m_task_manager; }

ServerPlayer *Server::findPlayer(int id) const { return players.value(id); }

ServerPlayer *Server::findPlayerByConnId(int connId) const {
  return players_conn.value(connId);
}

void Server::addPlayer(ServerPlayer *player) {
  int id = player->getId();
  if (id > 0) {
    if (players.contains(id))
      players.remove(id);

    players.insert(id, player);
  }

  players_conn.insert(player->getConnId(), player);
}

void Server::removePlayer(int id) {
  if (players[id]) {
    players.remove(id);
  }
}

void Server::removePlayerByConnId(int connId) {
  if (players_conn[connId]) {
    players_conn.remove(connId);
  }
}

void Server::updateRoomList(ServerPlayer *teller) {
  QCborArray arr;
  QCborArray avail_arr;
  for (Room *room : rooms) {
    QCborArray obj;
    auto settings = room->getSettingsObject();
    auto password = settings["password"_L1].toString();
    auto count = room->getPlayers().count(); // playerNum
    auto cap = room->getCapacity();          // capacity

    obj << room->getId();        // roomId
    obj << room->getName();      // roomName
    obj << settings["gameMode"_L1].toString(); // gameMode
    obj << count;
    obj << cap;
    obj << !password.isEmpty();
    obj << room->isOutdated();

    if (count == cap)
      arr << obj;
    else
      avail_arr << obj;
  }
  for (auto v : avail_arr) {
    arr.prepend(v);
  }
  teller->doNotify("UpdateRoomList", arr.toCborValue().toCbor());
}

void Server::updateOnlineInfo() {
  lobby()->doBroadcastNotify(lobby()->getPlayers(), "UpdatePlayerNum",
                             QCborArray{
                                 lobby()->getPlayers().length(),
                                 this->players.count(),
                             }.toCborValue().toCbor());
}

Sqlite3 &Server::database() { return *db; }
Sqlite3 &Server::gameDatabase() { return *gamedb; }

void Server::broadcast(const QByteArray &command, const QByteArray &jsonData) {
  for (ServerPlayer *p : players.values()) {
    p->doNotify(command, jsonData);
  }
}

void Server::sendEarlyPacket(ClientSocket *client, const QByteArray &type, const QByteArray &msg) {
  QCborArray body {
    -2,
    (Router::TYPE_NOTIFICATION | Router::SRC_SERVER | Router::DEST_CLIENT),
    type,
    msg,
  };
  client->send(body.toCborValue().toCbor());
}

void Server::createNewPlayer(ClientSocket *client, const QString &name, const QString &avatar, int id, const QString &uuid_str) {
  // create new ServerPlayer and setup
  ServerPlayer *player = new ServerPlayer(lobby());
  player->setSocket(client);
  player->setParent(this);
  client->disconnect(this);
  player->setScreenName(name);
  player->setAvatar(avatar);
  player->setId(id);
  player->setUuid(uuid_str);
  if (players.count() <= 10) {
    broadcast("ServerMessage", tr("%1 logged in").arg(player->getScreenName()).toUtf8());
  }
  addPlayer(player);

  setupPlayer(player);

  auto result = db->select(QString("SELECT totalGameTime FROM usergameinfo WHERE id=%1;").arg(id));
  auto time = result[0]["totalGameTime"].toInt();
  player->addTotalGameTime(time);
  player->doNotify("AddTotalGameTime", QCborArray{ id, time }.toCborValue().toCbor());

  lobby()->addPlayer(player);
}

void Server::setupPlayer(ServerPlayer *player, bool all_info) {
  // tell the lobby player's basic property
  QCborArray arr;
  arr << player->getId();
  arr << player->getScreenName();
  arr << player->getAvatar();
  arr << QDateTime::currentMSecsSinceEpoch();
  player->doNotify("Setup", arr.toCborValue().toCbor());

  if (all_info) {
    player->doNotify("SetServerSettings", QCborArray {
          getConfig("motd").toString(),
          QCborValue::fromJsonValue(getConfig("hiddenPacks")),
          getConfig("enableBots").toBool(),
          }.toCborValue().toCbor());
  }
}

void Server::processNewConnection(ClientSocket *client) {
  auto addr = client->peerAddress();
  qInfo() << addr << "connected";

  // check ban ip
  auto result = db->select(QString("SELECT * FROM banip WHERE ip='%1';").arg(addr));

  const char *errmsg = nullptr;

  if (!result.isEmpty()) {
    errmsg = "you have been banned!";
  } else if (temp_banlist.contains(addr)) {
    errmsg = "you have been temporarily banned!";
  } else if (players.count() >= getConfig("capacity").toInt()) {
    errmsg = "server is full!";
  }

  if (errmsg) {
    sendEarlyPacket(client, "ErrorDlg", errmsg);
    qInfo() << "Refused banned IP:" << addr;
    client->disconnectFromHost();
    return;
  }

  connect(client, &ClientSocket::disconnected, this,
          [client]() { qInfo() << client->peerAddress() << "disconnected"; });

  // network delay test
  sendEarlyPacket(client, "NetworkDelayTest", QCborValue(auth->getPublicKey().toUtf8()).toCbor());
  // Note: the client should send a setup string next
  connect(client, &ClientSocket::message_got, auth.get(), &AuthManager::processNewConnection);
  client->timerSignup.start(30000);
}

#define SET_DEFAULT_CONFIG(k, v) do {\
  if (config.value(k).isUndefined()) { \
    config[k] = (v); \
  } } while (0)

void Server::readConfig() {
  QFile file("freekill.server.config.json");
  QByteArray json = QByteArrayLiteral("{}");
  if (file.open(QIODevice::ReadOnly)) {
    json = file.readAll();
  }
  config = QJsonDocument::fromJson(json).object();

  auto whitelist_json = getConfig("whitelist");
  if (whitelist_json.isArray()) {
    hasWhitelist = true;
    whitelist = whitelist_json.toArray().toVariantList();
  }

  // defaults
  SET_DEFAULT_CONFIG("description", "FreeKill Server");
  SET_DEFAULT_CONFIG("iconUrl", "default");
  SET_DEFAULT_CONFIG("capacity", 100);
  SET_DEFAULT_CONFIG("tempBanTime", 20);
  SET_DEFAULT_CONFIG("motd", "Welcome!");
  SET_DEFAULT_CONFIG("hiddenPacks", QJsonArray());
  SET_DEFAULT_CONFIG("enableBots", true);
  SET_DEFAULT_CONFIG("roomCountPerThread", 2000);
  SET_DEFAULT_CONFIG("maxPlayersPerDevice", 5);
}

QJsonValue Server::getConfig(const QString &key) { return config.value(key); }

bool Server::checkBanWord(const QString &str) {
  auto arr = getConfig("banwords").toArray();
  if (arr.isEmpty()) {
    return true;
  }
  for (auto v : arr) {
    auto s = v.toString().toUpper();
    if (str.toUpper().indexOf(s) != -1) {
      return false;
    }
  }
  return true;
}

void Server::temporarilyBan(int playerId) {
  auto player = findPlayer(playerId);
  if (!player) return;

  auto socket = player->getSocket();
  QString addr;
  if (!socket) {
    QString sql_find = QString("SELECT * FROM userinfo \
        WHERE id=%1;").arg(playerId);
    auto result = db->select(sql_find);
    if (result.isEmpty())
      return;

    auto obj = result[0];
    addr = obj["lastLoginIp"];
  } else {
    addr = socket->peerAddress();
  }
  temp_banlist.append(addr);

  auto time = getConfig("tempBanTime").toInt();
  QTimer::singleShot(time * 60000, this, [=]() {
      temp_banlist.removeOne(addr);
      });
  emit player->kicked();
}

void Server::beginTransaction() {
  transaction_mutex.lock();
  db->exec("BEGIN;");
}

void Server::endTransaction() {
  db->exec("COMMIT;");
  transaction_mutex.unlock();
}

const QString &Server::getMd5() const {
  return md5;
}

void Server::refreshMd5() {
  md5 = calcFileMD5();
  for (auto room : rooms) {
    if (room->isOutdated()) {
      if (!room->isStarted()) {
        for (auto p : room->getPlayers()) {
          p->doNotify("ErrorMsg", "room is outdated");
          p->kicked();
        }
      } else {
        room->doBroadcastNotify(room->getPlayers(), "GameLog", QCborMap {
          { "type", "#RoomOutdated" },
          { "toast", true },
        }.toCborValue().toCbor());
      }
    }
  }
  for (auto thread : findChildren<RoomThread *>()) {
    if (thread->isOutdated() && thread->findChildren<Room *>().isEmpty() && thread->getRefCount() == 0)
      thread->deleteLater();
  }
  for (auto p : lobby()->getPlayers()) {
    emit p->kicked();
  }
}

qint64 Server::getUptime() const {
  if (!uptime_counter.isValid()) return 0;
  return uptime_counter.elapsed();
}

bool Server::nameIsInWhiteList(const QString &name) const {
  if (!hasWhitelist) return true;
  return whitelist.length() > 0 && whitelist.contains(name);
}

RoomThread *Server::getAvailableThread() {
  for (auto t : findChildren<RoomThread *>()) {
    if (!t->isFull() && !t->isOutdated()) {
      return t;
    }
  }

  return new RoomThread(this);
}
