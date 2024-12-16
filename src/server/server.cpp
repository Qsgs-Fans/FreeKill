// SPDX-License-Identifier: GPL-3.0-or-later

#include "server/server.h"
#include "server/auth.h"
#include "server/room.h"
#include "server/lobby.h"
#include "server/roomthread.h"
#include "server/serverplayer.h"
#include "network/router.h"
#include "network/client_socket.h"
#include "network/server_socket.h"
#include "core/packman.h"
#include "core/c-wrapper.h"
#include "core/util.h"

#include <QNetworkDatagram>

Server *ServerInstance = nullptr;

Server::Server(QObject *parent) : QObject(parent) {
  ServerInstance = this;
  db = new Sqlite3;
  md5 = calcFileMD5();
  readConfig();

  auth = new AuthManager(this);
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
  ServerInstance = nullptr;
  for (auto i = players.cbegin(); i != players.cend(); i++) {
    // deleteLater时顺序无法确定 需要在此立刻delete掉以触发析构函数
    delete i.value();
  }
  // 得先清理threads及其Rooms 因为其中某些析构函数要调用sql
  for (auto thr : findChildren<RoomThread *>()) {
    delete thr;
  }
  delete db;
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
  Room *room;
  RoomThread *thread = nullptr;

  for (auto t : findChildren<RoomThread *>()) {
    if (!t->isFull() && !t->isOutdated()) {
      thread = t;
      break;
    }
  }

  if (!thread) {
    thread = new RoomThread(this);
  }

  room = new Room(thread);

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

ServerPlayer *Server::findPlayer(int id) const { return players.value(id); }

void Server::addPlayer(ServerPlayer *player) {
  int id = player->getId();
  if (players.contains(id))
    players.remove(id);

  players.insert(id, player);
}

void Server::removePlayer(int id) {
  if (players[id]) {
    players.remove(id);
  }
}

void Server::updateRoomList(ServerPlayer *teller) {
  QJsonArray arr;
  QJsonArray avail_arr;
  for (Room *room : rooms) {
    QJsonArray obj;
    auto settings = QJsonDocument::fromJson(room->getSettings());
    auto password = settings["password"].toString();
    auto count = room->getPlayers().count(); // playerNum
    auto cap = room->getCapacity();          // capacity

    obj << room->getId();        // roomId
    obj << room->getName();      // roomName
    obj << settings["gameMode"]; // gameMode
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
  auto jsonData = JsonArray2Bytes(arr);
  teller->doNotify("UpdateRoomList", jsonData);
}

void Server::updateOnlineInfo() {
  lobby()->doBroadcastNotify(lobby()->getPlayers(), "UpdatePlayerNum",
                             JsonArray2Bytes(QJsonArray({
                                 lobby()->getPlayers().length(),
                                 this->players.count(),
                             })));
}

Sqlite3 *Server::getDatabase() { return db; }

void Server::broadcast(const QByteArray &command, const QByteArray &jsonData) {
  for (ServerPlayer *p : players.values()) {
    p->doNotify(command, jsonData);
  }
}

void Server::sendEarlyPacket(ClientSocket *client, const QByteArray &type, const QByteArray &msg) {
  QJsonArray body;
  body << -2;
  body << (Router::TYPE_NOTIFICATION | Router::SRC_SERVER |
          Router::DEST_CLIENT);
  body << type.constData();
  body << msg.constData();
  client->send(JsonArray2Bytes(body));
}

void Server::setupPlayer(ServerPlayer *player, bool all_info) {
  // tell the lobby player's basic property
  QJsonArray arr;
  arr << player->getId();
  arr << player->getScreenName();
  arr << player->getAvatar();
  arr << QDateTime::currentMSecsSinceEpoch();
  player->doNotify("Setup", JsonArray2Bytes(arr));

  if (all_info) {
    player->doNotify("SetServerSettings", JsonArray2Bytes({
          getConfig("motd"),
          getConfig("hiddenPacks"),
          getConfig("enableBots"),
          }));
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
  sendEarlyPacket(client, "NetworkDelayTest", auth->getPublicKey().toUtf8());
  // Note: the client should send a setup string next
  connect(client, &ClientSocket::message_got, this, &Server::processRequest);
  client->timerSignup.start(30000);
}

void Server::processRequest(const QByteArray &msg) {
  ClientSocket *client = qobject_cast<ClientSocket *>(sender());
  disconnect(client, &ClientSocket::message_got, this, &Server::processRequest);
  client->timerSignup.stop();

  bool valid = true;
  QJsonDocument doc = QJsonDocument::fromJson(msg);
  if (doc.isNull() || !doc.isArray()) {
    valid = false;
  } else {
    if (doc.array().size() != 4 || doc[0] != -2 ||
        doc[1] != (Router::TYPE_NOTIFICATION | Router::SRC_CLIENT |
                   Router::DEST_SERVER) ||
        doc[2] != "Setup")
      valid = false;
    else
      valid = (String2Json(doc[3].toString()).array().size() == 5);
  }

  if (!valid) {
    qWarning() << "Invalid setup string:" << msg;
    sendEarlyPacket(client, "ErrorDlg", "INVALID SETUP STRING");
    client->disconnectFromHost();
    return;
  }

  QJsonArray arr = String2Json(doc[3].toString()).array();

  if (!auth->checkClientVersion(client, arr[3].toString())) return;

  auto uuid_str = arr[4].toString();
  Sqlite3::QueryResult result2 = { {} };
  if (Sqlite3::checkString(uuid_str)) {
    result2 = db->select(QString("SELECT * FROM banuuid WHERE uuid='%1';").arg(uuid_str));
  }

  if (!result2.isEmpty()) {
    sendEarlyPacket(client, "ErrorDlg", "you have been banned!");
    qInfo() << "Refused banned UUID:" << uuid_str;
    client->disconnectFromHost();
    return;
  }

  auto md5_str = arr[2].toString();
  if (md5 != md5_str) {
    sendEarlyPacket(client, "ErrorMsg", "MD5 check failed!");
    sendEarlyPacket(client, "UpdatePackage", Pacman->getPackSummary().toUtf8());
    client->disconnectFromHost();
    return;
  }

  auto name = arr[0].toString();
  auto password = arr[1].toString();
  auto obj = auth->checkPassword(client, name, password);
  if (obj.isEmpty()) return;

  // update lastLoginIp
  int id = obj["id"].toInt();
  beginTransaction();
  auto sql_update =
    QString("UPDATE userinfo SET lastLoginIp='%1' WHERE id=%2;")
    .arg(client->peerAddress())
    .arg(id);
  db->exec(sql_update);

  auto uuid_update = QString("REPLACE INTO uuidinfo (id, uuid) VALUES (%1, '%2');")
    .arg(id).arg(uuid_str);
  db->exec(uuid_update);

  // 来晚了，有很大可能存在已经注册但是表里面没数据的人
  db->exec(QString("INSERT OR IGNORE INTO usergameinfo (id) VALUES (%1);").arg(id));
  auto info_update = QString("UPDATE usergameinfo SET lastLoginTime=%2 where id=%1;").arg(id).arg(QDateTime::currentSecsSinceEpoch());
  db->exec(info_update);
  endTransaction();

  // create new ServerPlayer and setup
  ServerPlayer *player = new ServerPlayer(lobby());
  player->setSocket(client);
  client->disconnect(this);
  player->setScreenName(name);
  player->setAvatar(obj["avatar"]);
  player->setId(id);
  player->setUuid(uuid_str);
  if (players.count() <= 10) {
    broadcast("ServerMessage", tr("%1 logged in").arg(player->getScreenName()).toUtf8());
  }
  players.insert(player->getId(), player);

  setupPlayer(player);

  auto result = db->select(QString("SELECT totalGameTime FROM usergameinfo WHERE id=%1;").arg(id));
  auto time = result[0]["totalGameTime"].toInt();
  player->addTotalGameTime(time);
  player->doNotify("AddTotalGameTime", JsonArray2Bytes({ id, time }));

  lobby()->addPlayer(player);
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

  // defaults
  SET_DEFAULT_CONFIG("description", "FreeKill Server");
  SET_DEFAULT_CONFIG("iconUrl", "default");
  SET_DEFAULT_CONFIG("capacity", 100);
  SET_DEFAULT_CONFIG("tempBanTime", 20);
  SET_DEFAULT_CONFIG("motd", "Welcome!");
  SET_DEFAULT_CONFIG("hiddenPacks", QJsonArray());
  SET_DEFAULT_CONFIG("enableBots", true);
  SET_DEFAULT_CONFIG("roomCountPerThread", 200);
}

QJsonValue Server::getConfig(const QString &key) { return config.value(key); }

bool Server::checkBanWord(const QString &str) {
  auto arr = getConfig("banwords").toArray();
  if (arr.isEmpty()) {
    return true;
  }
  for (auto v : arr) {
    auto s = v.toString();
    if (str.indexOf(s) != -1) {
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
        room->doBroadcastNotify(room->getPlayers(), "GameLog",
            "{\"type\":\"#RoomOutdated\",\"toast\":true}");
      }
    }
  }
  for (auto thread : findChildren<RoomThread *>()) {
    if (thread->isOutdated() && thread->findChildren<Room *>().isEmpty())
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
