// SPDX-License-Identifier: GPL-3.0-or-later

#include "room.h"

#include <qjsonarray.h>
#include <qjsondocument.h>

#include "server.h"
#include "serverplayer.h"
#include "util.h"

Room::Room(Server *server) {
  setObjectName("Room");
  id = server->nextRoomId;
  server->nextRoomId++;
  this->server = server;
  setParent(server);
  m_abandoned = false;
  owner = nullptr;
  gameStarted = false;
  robot_id = -2; // -1 is reserved in UI logic
  timeout = 15;

  // 如果是普通房间而不是大厅，就初始化Lua，否则置Lua为nullptr
  L = nullptr;
  if (!isLobby()) {
    // 如果不是大厅，那么：
    // * 只要房间添加人了，那么从大厅中移掉这个人
    // * 只要有人离开房间，那就把他加到大厅去
    connect(this, &Room::playerAdded, server->lobby(), &Room::removePlayer);
    connect(this, &Room::playerRemoved, server->lobby(), &Room::addPlayer);

    L = CreateLuaState();
    DoLuaScript(L, "lua/freekill.lua");
    DoLuaScript(L, "lua/server/room.lua");
    initLua();
  }
}

Room::~Room() {
  if (isRunning()) {
    wait();
  }
  if (L)
    lua_close(L);
}

Server *Room::getServer() const { return server; }

int Room::getId() const { return id; }

void Room::setId(int id) { this->id = id; }

bool Room::isLobby() const { return id == 0; }

QString Room::getName() const { return name; }

void Room::setName(const QString &name) { this->name = name; }

int Room::getCapacity() const { return capacity; }

void Room::setCapacity(int capacity) { this->capacity = capacity; }

bool Room::isFull() const { return players.count() == capacity; }

const QByteArray Room::getSettings() const { return settings; }

void Room::setSettings(QByteArray settings) { this->settings = settings; }

bool Room::isAbandoned() const {
  if (isLobby())
    return false;

  if (players.isEmpty())
    return true;

  foreach (ServerPlayer *p, players) {
    if (p->getState() == Player::Online)
      return false;
  }
  return true;
}

void Room::setAbandoned(bool abandoned) { m_abandoned = abandoned; }

ServerPlayer *Room::getOwner() const { return owner; }

void Room::setOwner(ServerPlayer *owner) {
  this->owner = owner;
  QJsonArray jsonData;
  jsonData << owner->getId();
  doBroadcastNotify(players, "RoomOwner", JsonArray2Bytes(jsonData));
}

void Room::addPlayer(ServerPlayer *player) {
  if (!player)
    return;

  // 如果要加入的房间满员了，或者已经开战了，就不能再加入
  if (isFull() || gameStarted) {
    player->doNotify("ErrorMsg", "Room is full or already started!");
    if (runned_players.contains(player->getId())) {
      player->doNotify("ErrorMsg", "Running away is shameful.");
    }
    // 此时player仍在lobby中，别管就行了
    // emit playerRemoved(player);
    return;
  }

  QJsonArray jsonData;

  // 告诉房里所有玩家有新人进来了
  if (!isLobby()) {
    jsonData << player->getId();
    jsonData << player->getScreenName();
    jsonData << player->getAvatar();
    jsonData << player->isReady();
    doBroadcastNotify(getPlayers(), "AddPlayer", JsonArray2Bytes(jsonData));
  }

  players.append(player);
  player->setRoom(this);

  if (isLobby()) {
    // 有机器人进入大厅（可能因为被踢），那么改为销毁
    if (player->getState() == Player::Robot) {
      removePlayer(player);
      player->deleteLater();
    } else {
      player->doNotify("EnterLobby", "[]");
    }
  } else {
    // Second, let the player enter room and add other players
    jsonData = QJsonArray();
    jsonData << this->capacity;
    jsonData << this->timeout;
    jsonData << QJsonDocument::fromJson(this->settings).object();
    player->doNotify("EnterRoom", JsonArray2Bytes(jsonData));

    foreach (ServerPlayer *p, getOtherPlayers(player)) {
      jsonData = QJsonArray();
      jsonData << p->getId();
      jsonData << p->getScreenName();
      jsonData << p->getAvatar();
      jsonData << p->isReady();
      player->doNotify("AddPlayer", JsonArray2Bytes(jsonData));
    }

    if (this->owner != nullptr) {
      jsonData = QJsonArray();
      jsonData << this->owner->getId();
      player->doNotify("RoomOwner", JsonArray2Bytes(jsonData));
    }

    // 玩家手动启动
    // if (isFull() && !gameStarted)
    //  start();
  }
  emit playerAdded(player);
}

void Room::addRobot(ServerPlayer *player) {
  if (player != owner || isFull())
    return;

  ServerPlayer *robot = new ServerPlayer(this);
  robot->setState(Player::Robot);
  robot->setId(robot_id);
  robot->setAvatar("guanyu");
  robot->setScreenName(QString("COMP-%1").arg(robot_id));
  robot->setReady(true);
  robot_id--;

  // FIXME: 会触发Lobby:removePlayer
  addPlayer(robot);
}

void Room::removePlayer(ServerPlayer *player) {
  // 如果是旁观者的话，就清旁观者
  if (observers.contains(player)) {
    removeObserver(player);
    return;
  }

  if (!gameStarted) {
    // 游戏还没开始的话，直接删除这名玩家
    if (players.contains(player) && !players.isEmpty()) {
      players.removeOne(player);
    }
    emit playerRemoved(player);

    if (isLobby())
      return;

    QJsonArray jsonData;
    jsonData << player->getId();
    doBroadcastNotify(getPlayers(), "RemovePlayer", JsonArray2Bytes(jsonData));
  } else {
    // 否则给跑路玩家召唤个AI代打
    // TODO: if the player is died..

    // 首先拿到跑路玩家的socket，然后把玩家的状态设为逃跑，这样自动被机器人接管
    ClientSocket *socket = player->getSocket();
    player->setState(Player::Run);
    player->removeSocket();

    // 然后基于跑路玩家的socket，创建一个新ServerPlayer对象用来通信
    ServerPlayer *runner = new ServerPlayer(this);
    runner->setSocket(socket);
    connect(runner, &ServerPlayer::disconnected, server,
            &Server::onUserDisconnected);
    connect(runner, &Player::stateChanged, server, &Server::onUserStateChanged);
    runner->setScreenName(player->getScreenName());
    runner->setAvatar(player->getAvatar());
    runner->setId(player->getId());

    // 最后向服务器玩家列表中增加这个人
    // 原先的跑路机器人会在游戏结束后自动销毁掉
    server->addPlayer(runner);

    // 发出信号，让大厅添加这个人
    emit playerRemoved(runner);
  }

  // 如果房间空了，就把房间标为废弃，Server有信号处理函数的
  if (isAbandoned()) {
    bool tmp = m_abandoned;
    m_abandoned = true;
    // 只释放一次信号就行了，他销毁机器人的时候会多次调用removePlayer
    if (!tmp) {
      emit abandoned();
    }
  } else if (player == owner) {
    setOwner(players.first());
  }
}

QList<ServerPlayer *> Room::getPlayers() const { return players; }

QList<ServerPlayer *> Room::getOtherPlayers(ServerPlayer *expect) const {
  QList<ServerPlayer *> others = getPlayers();
  others.removeOne(expect);
  return others;
}

ServerPlayer *Room::findPlayer(int id) const {
  foreach (ServerPlayer *p, players) {
    if (p->getId() == id)
      return p;
  }
  return nullptr;
}

void Room::addObserver(ServerPlayer *player) {
  // 首先只能旁观在运行的房间，因为旁观是由Lua处理的
  if (!gameStarted) {
    player->doNotify("ErrorMsg", "Can only observe running room.");
    return;
  }

  // 向observers中追加player，并从大厅移除player，然后将player的room设为this
  observers.append(player);
  player->setRoom(this);
  emit playerAdded(player);
  pushRequest(QString("%1,observe").arg(player->getId()));
}

void Room::removeObserver(ServerPlayer *player) {
  if (observers.contains(player)) {
    observers.removeOne(player);
  }
  emit playerRemoved(player);

  if (player->getState() == Player::Online) {
    QJsonArray arr;
    arr << player->getId();
    arr << player->getScreenName();
    arr << player->getAvatar();
    player->doNotify("Setup", JsonArray2Bytes(arr));
  }
  pushRequest(QString("%1,leave").arg(player->getId()));
}

QList<ServerPlayer *> Room::getObservers() const { return observers; }

int Room::getTimeout() const { return timeout; }

void Room::setTimeout(int timeout) { this->timeout = timeout; }

bool Room::isStarted() const { return gameStarted; }

void Room::doBroadcastNotify(const QList<ServerPlayer *> targets,
                             const QString &command, const QString &jsonData) {
  foreach (ServerPlayer *p, targets) {
    p->doNotify(command, jsonData);
  }
}

void Room::chat(ServerPlayer *sender, const QString &jsonData) {
  auto doc = String2Json(jsonData).object();
  auto type = doc["type"].toInt();
  doc["sender"] = sender->getId();

  // 屏蔽.号，防止有人在HTML文本发链接，而正常发链接看不出来有啥改动
  auto msg = doc["msg"].toString();
  msg.replace(".", "․");
  doc["msg"] = msg;

  if (type == 1) {
    doc["userName"] = sender->getScreenName();
    auto json = QJsonDocument(doc).toJson(QJsonDocument::Compact);
    doBroadcastNotify(players, "Chat", json);
  } else {
    auto json = QJsonDocument(doc).toJson(QJsonDocument::Compact);
    doBroadcastNotify(players, "Chat", json);
    doBroadcastNotify(observers, "Chat", json);
  }

  qInfo("[Chat] %s: %s", sender->getScreenName().toUtf8().constData(),
        doc["msg"].toString().toUtf8().constData());
}

void Room::updateWinRate(int id, const QString &general, const QString &mode,
                         int game_result) {
  static const QString findWinRate =
      QString("SELECT win, lose, draw "
              "FROM winRate WHERE id = %1 and general = '%2' and mode = '%3';");

  static const QString updateRate =
      QString("UPDATE winRate "
              "SET win = %4, lose = %5, draw = %6 "
              "WHERE id = %1 and general = '%2' and mode = '%3';");

  static const QString insertRate =
      QString("INSERT INTO winRate "
              "(id, general, mode, win, lose, draw) "
              "VALUES (%1, '%2', '%3', %4, %5, %6);");

  if (!CheckSqlString(general))
    return;
  if (!CheckSqlString(mode))
    return;

  int win = 0;
  int lose = 0;
  int draw = 0;

  switch (game_result) {
  case 1:
    win++;
    break;
  case 2:
    lose++;
    break;
  case 3:
    draw++;
    break;
  default:
    break;
  }

  QJsonArray result =
      SelectFromDatabase(server->getDatabase(),
                         findWinRate.arg(QString::number(id), general, mode));

  if (result.isEmpty()) {
    ExecSQL(server->getDatabase(),
            insertRate.arg(QString::number(id), general, mode,
                           QString::number(win), QString::number(lose),
                           QString::number(draw)));
  } else {
    auto obj = result[0].toObject();
    win += obj["win"].toString().toInt();
    lose += obj["lose"].toString().toInt();
    draw += obj["draw"].toString().toInt();
    ExecSQL(server->getDatabase(),
            updateRate.arg(QString::number(id), general, mode,
                           QString::number(win), QString::number(lose),
                           QString::number(draw)));
  }
}

void Room::gameOver() {
  gameStarted = false;
  runned_players.clear();
  // 清理所有状态不是“在线”的玩家
  foreach (ServerPlayer *p, players) {
    if (p->getState() != Player::Online) {
      p->deleteLater();
    }
  }
  // 旁观者不能在这清除，因为removePlayer逻辑不一样
  // observers.clear();
  // 玩家也不能在这里清除，因为要能返回原来房间继续玩呢
  // players.clear();
  // owner = nullptr;
  clearRequest();
}

void Room::manuallyStart() {
  if (isFull() && !gameStarted) {
    foreach (auto p, players) {
      p->setReady(false);
    }
    start();
  }
}

QString Room::fetchRequest() {
  if (!gameStarted)
    return "";
  request_queue_mutex.lock();
  QString ret = "";
  if (!request_queue.isEmpty()) {
    ret = request_queue.dequeue();
  }
  request_queue_mutex.unlock();
  return ret;
}

void Room::pushRequest(const QString &req) {
  if (!gameStarted)
    return;
  request_queue_mutex.lock();
  request_queue.enqueue(req);
  request_queue_mutex.unlock();
}

void Room::clearRequest() {
  request_queue_mutex.lock();
  request_queue.clear();
  request_queue_mutex.unlock();
}

bool Room::hasRequest() const { return !request_queue.isEmpty(); }

void Room::run() {
  gameStarted = true;

  clearRequest();

  // 此处调用了Lua Room:run()函数
  roomStart();
}
