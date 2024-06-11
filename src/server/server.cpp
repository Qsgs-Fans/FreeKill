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
#include "core/util.h"

#include <QNetworkDatagram>

Server *ServerInstance = nullptr;

Server::Server(QObject *parent) : QObject(parent) {
  ServerInstance = this;
  db = OpenDatabase();
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
      foreach (auto p, this->players.values()) {
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

      foreach (auto p, this->players.values()) {
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
  m_lobby->deleteLater();
//  foreach (auto room, idle_rooms) {
//    room->deleteLater();
//  }
  foreach (auto thread, threads) {
    thread->deleteLater();
  }
  sqlite3_close(db);
}

bool Server::listen(const QHostAddress &address, ushort port) {
  bool ret = server->listen(address, port);
  isListening = ret;
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

  foreach (auto t, threads) {
    if (!t->isFull() && !t->isOutdated()) {
      thread = t;
      break;
    }
  }

  if (!thread) {
    thread = createThread();
  }

  if (!idle_rooms.isEmpty()) {
    room = idle_rooms.pop();
    room->setId(nextRoomId);
    nextRoomId++;
    room->setAbandoned(false);
    thread->addRoom(room);
    rooms.insert(room->getId(), room);
  } else {
    room = new Room(thread);
    connect(room, &Room::abandoned, this, &Server::onRoomAbandoned);
    rooms.insert(room->getId(), room);
  }

  room->setName(name);
  room->setCapacity(capacity);
  room->setTimeout(timeout);
  room->setSettings(settings);
  room->addPlayer(owner);
  room->setOwner(owner);
}

Room *Server::findRoom(int id) const { return rooms.value(id); }

Lobby *Server::lobby() const { return m_lobby; }

RoomThread *Server::createThread() {
  RoomThread *thread = new RoomThread(this);
  threads.append(thread);
  return thread;
}

void Server::removeThread(RoomThread *thread) {
  threads.removeOne(thread);
}

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
  foreach (Room *room, rooms) {
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
  foreach (auto v, avail_arr) {
    arr.prepend(v);
  }
  auto jsonData = JsonArray2Bytes(arr);
  teller->doNotify("UpdateRoomList", QString(jsonData));
}

void Server::updateOnlineInfo() {
  lobby()->doBroadcastNotify(lobby()->getPlayers(), "UpdatePlayerNum",
                             QString(JsonArray2Bytes(QJsonArray({
                                 lobby()->getPlayers().length(),
                                 this->players.count(),
                             }))));
}

sqlite3 *Server::getDatabase() { return db; }

void Server::broadcast(const QString &command, const QString &jsonData) {
  foreach (ServerPlayer *p, players.values()) {
    p->doNotify(command, jsonData);
  }
}

void Server::sendEarlyPacket(ClientSocket *client, const QString &type, const QString &msg) {
  QJsonArray body;
  body << -2;
  body << (Router::TYPE_NOTIFICATION | Router::SRC_SERVER |
          Router::DEST_CLIENT);
  body << type;
  body << msg;
  client->send(JsonArray2Bytes(body));
}

void Server::setupPlayer(ServerPlayer *player, bool all_info) {
  // tell the lobby player's basic property
  QJsonArray arr;
  arr << player->getId();
  arr << player->getScreenName();
  arr << player->getAvatar();
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
  auto result = SelectFromDatabase(
      db, QString("SELECT * FROM banip WHERE ip='%1';").arg(addr));

  auto errmsg = QString();

  if (!result.isEmpty()) {
    errmsg = "you have been banned!";
  } else if (temp_banlist.contains(addr)) {
    errmsg = "you have been temporarily banned!";
  } else if (players.count() >= getConfig("capacity").toInt()) {
    errmsg = "server is full!";
  }

  if (!errmsg.isEmpty()) {
    sendEarlyPacket(client, "ErrorDlg", errmsg);
    qInfo() << "Refused banned IP:" << addr;
    client->disconnectFromHost();
    return;
  }

  connect(client, &ClientSocket::disconnected, this,
          [client]() { qInfo() << client->peerAddress() << "disconnected"; });

  // network delay test
  sendEarlyPacket(client, "NetworkDelayTest", auth->getPublicKey());
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
  auto result2 = QJsonArray({1});
  if (CheckSqlString(uuid_str)) {
    result2 = SelectFromDatabase(
        db, QString("SELECT * FROM banuuid WHERE uuid='%1';").arg(uuid_str));
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
    sendEarlyPacket(client, "UpdatePackage", Pacman->getPackSummary());
    client->disconnectFromHost();
    return;
  }

  auto name = arr[0].toString();
  auto password = arr[1].toString();
  auto obj = auth->checkPassword(client, name, password);
  if (obj.isEmpty()) return;

  // update lastLoginIp
  int id = obj["id"].toString().toInt();
  beginTransaction();
  auto sql_update =
    QString("UPDATE userinfo SET lastLoginIp='%1' WHERE id=%2;")
    .arg(client->peerAddress())
    .arg(id);
  ExecSQL(db, sql_update);

  auto uuid_update = QString("REPLACE INTO uuidinfo (id, uuid) VALUES (%1, '%2');")
    .arg(id).arg(uuid_str);
  ExecSQL(db, uuid_update);

  // 来晚了，有很大可能存在已经注册但是表里面没数据的人
  ExecSQL(db, QString("INSERT OR IGNORE INTO usergameinfo (id) VALUES (%1);").arg(id));
  auto info_update = QString("UPDATE usergameinfo SET lastLoginTime=%2 where id=%1;").arg(id).arg(QDateTime::currentSecsSinceEpoch());
  ExecSQL(db, info_update);
  endTransaction();

  // create new ServerPlayer and setup
  ServerPlayer *player = new ServerPlayer(lobby());
  player->setSocket(client);
  client->disconnect(this);
  player->setScreenName(name);
  player->setAvatar(obj["avatar"].toString());
  player->setId(id);
  if (players.count() <= 10) {
    broadcast("ServerMessage", tr("%1 logged in").arg(player->getScreenName()));
  }
  players.insert(player->getId(), player);

  setupPlayer(player);

  auto result = SelectFromDatabase(db, QString("SELECT totalGameTime FROM usergameinfo WHERE id=%1;").arg(id));
  auto time = result[0].toObject()["totalGameTime"].toString().toInt();
  player->addTotalGameTime(time);
  player->doNotify("AddTotalGameTime", JsonArray2Bytes({ id, time }));

  lobby()->addPlayer(player);
}

void Server::onRoomAbandoned() {
  Room *room = qobject_cast<Room *>(sender());
  // room->gameOver(); // Lua会出手
  rooms.remove(room->getId());
  updateOnlineInfo();
  // 按理说这时候就可以删除了，但是这里肯定比Lua先检测到。
  // 倘若在Lua的Room:gameOver时C++的Room被删除了问题就大了。
  // FIXME: 但是这终归是内存泄漏！以后啥时候再改吧。
  // room->deleteLater();
  idle_rooms.push(room);
  room->getThread()->wakeUp(room->getId());
  room->getThread()->removeRoom(room);
}

#define SET_DEFAULT_CONFIG(k, v) do {\
  if (config.value(k).isUndefined()) { \
    config[k] = (v); \
  } } while (0)

void Server::readConfig() {
  QFile file("freekill.server.config.json");
  QByteArray json = "{}";
  if (file.open(QIODevice::ReadOnly)) {
    json = file.readAll();
  }
  config = QJsonDocument::fromJson(json).object();

  // defaults
  SET_DEFAULT_CONFIG("description", "FreeKill Server");
  SET_DEFAULT_CONFIG("iconUrl", "https://img1.imgtp.com/2023/07/01/DGUdj8eu.png");
  SET_DEFAULT_CONFIG("capacity", 100);
  SET_DEFAULT_CONFIG("tempBanTime", 20);
  SET_DEFAULT_CONFIG("motd", "Welcome!");
  SET_DEFAULT_CONFIG("hiddenPacks", QJsonArray());
  SET_DEFAULT_CONFIG("enableBots", true);
}

QJsonValue Server::getConfig(const QString &key) { return config.value(key); }

bool Server::checkBanWord(const QString &str) {
  auto arr = getConfig("banwords").toArray();
  if (arr.isEmpty()) {
    return true;
  }
  foreach (auto v, arr) {
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
    auto result = SelectFromDatabase(db, sql_find);
    if (result.isEmpty())
      return;

    auto obj = result[0].toObject();
    addr = obj["lastLoginIp"].toString();
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
  ExecSQL(db, "BEGIN;");
}

void Server::endTransaction() {
  ExecSQL(db, "COMMIT;");
  transaction_mutex.unlock();
}

const QString &Server::getMd5() const {
  return md5;
}

void Server::refreshMd5() {
  md5 = calcFileMD5();
  foreach (auto room, rooms) {
    if (room->isOutdated()) {
      if (!room->isStarted()) {
        foreach (auto p, room->getPlayers()) {
          p->doNotify("ErrorMsg", "room is outdated");
          p->kicked();
        }
      } else {
        room->doBroadcastNotify(room->getPlayers(), "GameLog",
            "{\"type\":\"#RoomOutdated\",\"toast\":true}");
      }
    }
  }
  foreach (auto p, lobby()->getPlayers()) {
    emit p->kicked();
  }
}
