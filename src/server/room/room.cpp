// SPDX-License-Identifier: GPL-3.0-or-later

#include "server/room/room.h"
#include "server/room/lobby.h"

#ifdef FK_SERVER_ONLY
static void *ClientInstance = nullptr;
#else
#include "client/client.h"
#endif

#include "network/client_socket.h"
#include "server/gamelogic/roomthread.h"
#include "server/server.h"
#include "server/user/serverplayer.h"
#include "core/util.h"
#include "core/c-wrapper.h"

Room::Room(RoomThread *thread) {
  auto server = ServerInstance;
  id = server->nextRoomId;
  server->nextRoomId++;
  this->server = server;

  setParent(thread);
  md5 = thread->getMd5();
  connect(this, &Room::abandoned, thread, &RoomThread::onRoomAbandoned);

  m_abandoned = false;
  owner = nullptr;
  gameStarted = false;
  robot_id = -2; // -1 is reserved in UI logic
  timeout = 15;

  m_ready = true;

  auto lobby = server->lobby();
  connect(this, &Room::playerAdded, server->lobby(), &Lobby::removePlayer);
  connect(this, &Room::playerRemoved, server->lobby(), &Lobby::addPlayer);
}

Room::~Room() {
  // 标记为过期 避免封人
  md5 = "";

  if (gameStarted) {
    gameOver();
  }
  for (auto p : players) {
    if (p->getId() > 0) removePlayer(p);
  }
  for (auto p : observers) {
    removeObserver(p);
  }

  auto server = ServerInstance;
  server->removeRoom(getId());
  server->updateOnlineInfo();
}

int Room::getId() const { return id; }

void Room::setId(int id) { this->id = id; }

QString Room::getName() const { return name; }

void Room::setName(const QString &name) { this->name = name; }

int Room::getCapacity() const { return capacity; }

void Room::setCapacity(int capacity) { this->capacity = capacity; }

bool Room::isFull() const { return players.count() == capacity; }

const QByteArray Room::getSettings() const { return settings; }

const QJsonObject Room::getSettingsObject() const { return settings_obj; }

void Room::setSettings(QByteArray settings) {
  this->settings = settings;
  settings_obj = QJsonDocument::fromJson(settings).object();
}

bool Room::isAbandoned() const {
  if (players.isEmpty())
    return true;

  for (ServerPlayer *p : players) {
    if (p->getState() == Player::Online)
      return false;
  }
  return true;
}

ServerPlayer *Room::getOwner() const { return owner; }

void Room::setOwner(ServerPlayer *owner) {
  this->owner = owner;
  if (!owner) return;
  QCborArray arr { owner->getId() };
  doBroadcastNotify(players, "RoomOwner", arr.toCborValue().toCbor());
}

void Room::addPlayer(ServerPlayer *player) {
  if (!player)
    return;

  if (rejected_players.contains(player->getId())) {
    player->doNotify("ErrorMsg", "rejected your demand of joining room");
    return;
  }

  // 如果要加入的房间满员了，或者已经开战了，就不能再加入
  if (isFull() || gameStarted) {
    player->doNotify("ErrorMsg", "Room is full or already started!");
    if (runned_players.contains(player->getId())) {
      player->doNotify("ErrorMsg", "Running away is shameful.");
    }
    // 此时phttps://github.com/fmanlou/qt6printerslayer仍在lobby中，别管就行了
    // emit playerRemoved(player);
    return;
  }

  auto mode = settings_obj["gameMode"].toString();

  // 告诉房里所有玩家有新人进来了
  QCborArray arr {
    player->getId(),
    player->getScreenName(),
    player->getAvatar(),
    player->isReady(),
    player->getTotalGameTime(),
  };
  doBroadcastNotify(getPlayers(), "AddPlayer", arr.toCborValue().toCbor());

  players.append(player);
  player->setRoom(this);
  if (player->getId() > 0)
    emit playerAdded(player);

  // Second, let the player enter room and add other players
  arr = {
    this->capacity,
    this->timeout,
    QCborValue::fromJsonValue(settings_obj),
  };
  player->doNotify("EnterRoom", arr.toCborValue().toCbor());

  for (ServerPlayer *p : getOtherPlayers(player)) {
    arr = {
      p->getId(),
      p->getScreenName(),
      p->getAvatar(),
      p->isReady(),
      p->getTotalGameTime(),
    };
    player->doNotify("AddPlayer", arr.toCborValue().toCbor());

    arr = { p->getId() };
    for (int i : p->getGameData()) {
      arr << i;
    }
    player->doNotify("UpdateGameData", arr.toCborValue().toCbor());
  }

  if (this->owner != nullptr) {
    arr = { this->owner->getId() };
    player->doNotify("RoomOwner", arr.toCborValue().toCbor());
  }

  if (player->getLastGameMode() != mode) {
    player->setLastGameMode(mode);
    updatePlayerGameData(player->getId(), mode);
  } else {
    arr = { player->getId() };
    for (int i : player->getGameData()) {
      arr << i;
    }
    doBroadcastNotify(getPlayers(), "UpdateGameData", arr.toCborValue().toCbor());
  }
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
  robot->setParent(this);
  connect(robot, &QObject::destroyed, this, [&](){ players.removeOne(robot); });
  robot_id--;

  server->addPlayer(robot);

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
      player->setReady(false);
      players.removeOne(player);
    }
    emit playerRemoved(player);

    doBroadcastNotify(getPlayers(), "RemovePlayer", QCborArray({ player->getId() }).toCborValue().toCbor());
  } else {
    // 否则给跑路玩家召唤个AI代打
    // TODO: if the player is died..


    // 首先拿到跑路玩家的socket，然后把玩家的状态设为逃跑，这样自动被机器人接管
    ClientSocket *socket = player->getSocket();
    player->setState(Player::Run);
    player->setParent(this);
    player->removeSocket();

    // 设完state后把房间叫起来
    if (player->thinking()) {
      auto thread = qobject_cast<RoomThread *>(parent());
      thread->wakeUp(getId(), "player_disconnect");
    }

    if (!player->isDied()) {
      runned_players << player->getId();
    }

    // 然后基于跑路玩家的socket，创建一个新ServerPlayer对象用来通信
    ServerPlayer *runner = new ServerPlayer(this);
    runner->setSocket(socket);
    runner->setScreenName(player->getScreenName());
    runner->setAvatar(player->getAvatar());
    runner->setId(player->getId());
    auto gamedata = player->getGameData();
    runner->setGameData(gamedata[0], gamedata[1], gamedata[2]);
    runner->addTotalGameTime(player->getTotalGameTime());

    // 最后向服务器玩家列表中增加这个人
    // 原先的跑路机器人会在游戏结束后自动销毁掉
    server->addPlayer(runner);

    // FIX 控制bug
    runner->doNotify("ChangeSelf", QCborValue(runner->getId()).toCbor());

    // 发出信号，让大厅添加这个人
    emit playerRemoved(runner);

    // 如果走小道的人不是单机启动玩家 且房没过期 那么直接ban
    if (!ClientInstance && !isOutdated() && !player->isDied()) {
      server->temporarilyBan(runner->getId());
    }
  }

  // 如果房间空了，就把房间标为废弃，RoomThread有信号处理函数的
  if (isAbandoned()) {
    bool tmp = m_abandoned;
    m_abandoned = true;
    setOwner(nullptr);
    // 只释放一次信号就行了，他销毁机器人的时候会多次调用removePlayer
    if (!tmp) {
      emit abandoned();
    }
  } else if (player == owner) {
    setOwner(players.first());
  }
}

void Room::addObserver(ServerPlayer *player) {
  // 首先只能旁观在运行的房间，因为旁观是由Lua处理的
  if (!gameStarted) {
    player->doNotify("ErrorMsg", "Can only observe running room.");
    return;
  }

  if (rejected_players.contains(player->getId())) {
    player->doNotify("ErrorMsg", "rejected your demand of joining room");
    return;
  }

  // 向observers中追加player，并从大厅移除player，然后将player的room设为this
  observers.append(player);
  player->setRoom(this);
  emit playerAdded(player);
  auto thread = qobject_cast<RoomThread *>(parent());
  emit thread->addObserver(player->getConnId(), id);
  pushRequest(QString("%1,observe").arg(player->getId()));
}

void Room::removeObserver(ServerPlayer *player) {
  if (observers.contains(player)) {
    observers.removeOne(player);
  }
  emit playerRemoved(player);

  if (player->getState() == Player::Online) {
    QCborArray arr {
      player->getId(),
      player->getScreenName(),
      player->getAvatar(),
    };
    player->doNotify("Setup", arr.toCborValue().toCbor());
  }
  auto thread = qobject_cast<RoomThread *>(parent());
  emit thread->removeObserver(player->getConnId(), id);
  pushRequest(QString("%1,leave").arg(player->getId()));
}

QList<ServerPlayer *> Room::getObservers() const { return observers; }

bool Room::hasObserver(ServerPlayer *player) const { return observers.contains(player); }

int Room::getTimeout() const { return timeout; }

void Room::setTimeout(int timeout) { this->timeout = timeout; }

void Room::delay(int ms) {
  auto thread = qobject_cast<RoomThread *>(parent());
  thread->delay(id, ms);
}

bool Room::isOutdated() {
  bool ret = md5 != server->getMd5();
  if (ret) md5 = QStringLiteral("");
  return ret;
}

bool Room::isStarted() const { return gameStarted; }

static const QString findPWinRate =
    QString("SELECT win, lose, draw "
            "FROM pWinRate WHERE id = %1 and mode = '%2' and role = '%3';");

static const QString updatePWinRate =
    QString("UPDATE pWinRate "
            "SET win = %4, lose = %5, draw = %6 "
            "WHERE id = %1 and mode = '%2' and role = '%3';");

static const QString insertPWinRate =
    QString("INSERT INTO pWinRate "
            "(id, mode, role, win, lose, draw) "
            "VALUES (%1, '%2', '%3', %4, %5, %6);");

static const QString findGWinRate =
    QString("SELECT win, lose, draw "
            "FROM gWinRate WHERE general = '%1' and mode = '%2' and role = '%3';");

static const QString updateGWinRate =
    QString("UPDATE gWinRate "
            "SET win = %4, lose = %5, draw = %6 "
            "WHERE general = '%1' and mode = '%2' and role = '%3';");

static const QString insertGWinRate =
    QString("INSERT INTO gWinRate "
            "(general, mode, role, win, lose, draw) "
            "VALUES ('%1', '%2', '%3', %4, %5, %6);");

static const QString findRunRate =
  QString("SELECT run "
      "FROM runRate WHERE id = %1 and mode = '%2';");

static const QString updateRunRate =
    QString("UPDATE runRate "
            "SET run = %3 "
            "WHERE id = %1 and mode = '%2';");

static const QString insertRunRate =
    QString("INSERT INTO runRate "
            "(id, mode, run) "
            "VALUES (%1, '%2', %3);");

void Room::updatePlayerWinRate(int id, const QString &mode, const QString &role, int game_result) {
  if (!Sqlite3::checkString(mode))
    return;
  auto db = server->getDatabase();

  int win = 0;
  int lose = 0;
  int draw = 0;
  int run = 0;

  switch (game_result) {
  case 1: win++; break;
  case 2: lose++; break;
  case 3: draw++; break;
  default: break;
  }

  auto result = db->select(findPWinRate.arg(QString::number(id), mode, role));

  if (result.isEmpty()) {
    db->exec(insertPWinRate.arg(QString::number(id), mode, role,
                               QString::number(win), QString::number(lose),
                               QString::number(draw)));
  } else {
    auto obj = result[0];
    win += obj["win"].toInt();
    lose += obj["lose"].toInt();
    draw += obj["draw"].toInt();
    db->exec(updatePWinRate.arg(QString::number(id), mode, role,
                                QString::number(win), QString::number(lose),
                                QString::number(draw)));
  }

  if (runned_players.contains(id)) {
    addRunRate(id, mode);
  }

  auto player = server->findPlayer(id);
  if (players.contains(player)) {
    player->setLastGameMode(mode);
    updatePlayerGameData(id, mode);
  }
}

void Room::updateGeneralWinRate(const QString &general, const QString &mode, const QString &role, int game_result) {
  if (!Sqlite3::checkString(general))
    return;
  if (!Sqlite3::checkString(mode))
    return;
  auto db = server->getDatabase();

  int win = 0;
  int lose = 0;
  int draw = 0;
  int run = 0;

  switch (game_result) {
  case 1: win++; break;
  case 2: lose++; break;
  case 3: draw++; break;
  default: break;
  }

  auto result = db->select(findGWinRate.arg(general, mode, role));

  if (result.isEmpty()) {
    db->exec(insertGWinRate.arg(general, mode, role,
                                QString::number(win), QString::number(lose),
                                QString::number(draw)));
  } else {
    auto obj = result[0];
    win += obj["win"].toInt();
    lose += obj["lose"].toInt();
    draw += obj["draw"].toInt();
    db->exec(updateGWinRate.arg(general, mode, role,
                                QString::number(win), QString::number(lose),
                                QString::number(draw)));
  }
}

void Room::addRunRate(int id, const QString &mode) {
  int run = 1;
  auto db = server->getDatabase();
  auto result =db->select(findRunRate.arg(QString::number(id), mode));

  if (result.isEmpty()) {
    db->exec(insertRunRate.arg(QString::number(id), mode,
                               QString::number(run)));
  } else {
    auto obj = result[0];
    run += obj["run"].toInt();
    db->exec(updateRunRate.arg(QString::number(id), mode,
                               QString::number(run)));
  }
}

void Room::updatePlayerGameData(int id, const QString &mode) {
  static const QString findModeRate = QString("SELECT win, total FROM pWinRateView "
            "WHERE id = %1 and mode = '%2';");

  if (id < 0) return;
  auto player = server->findPlayer(id);
  if (player->getState() == Player::Robot || !player->getRoom()) {
    return;
  }

  int total = 0;
  int win = 0;
  int run = 0;
  auto db = server->getDatabase();

  auto result = db->select(findRunRate.arg(QString::number(id), mode));

  if (!result.isEmpty()) {
    run = result[0]["run"].toInt();
  }

  result = db->select(findModeRate.arg(QString::number(id), mode));

  if (!result.isEmpty()) {
    total = result[0]["total"].toInt();
    win = result[0]["win"].toInt();
  }

  auto room = player->getRoom();
  player->setGameData(total, win, run);
  QCborArray data_arr { player->getId(), total, win, run };
  room->doBroadcastNotify(room->getPlayers(), "UpdateGameData", data_arr.toCborValue().toCbor());
}

void Room::gameOver() {
  if (!gameStarted) return;
  insideGameOver = true;
  gameStarted = false;
  runned_players.clear();
  // 清理所有状态不是“在线”的玩家，增加逃率、游戏时长
  auto mode = settings_obj["gameMode"].toString();
  QList<ServerPlayer *> to_delete;

  // 首先只写数据库，这个过程不能向主线程提交申请(doNotify) 否则会死锁
  server->beginTransaction();
  for (auto p : players) {
    auto pid = p->getId();

    if (pid > 0) {
      int time = p->getGameTime();

      // 将游戏时间更新到数据库中
      auto info_update = QString("UPDATE usergameinfo SET totalGameTime = "
      "IIF(totalGameTime IS NULL, %2, totalGameTime + %2) WHERE id = %1;").arg(pid).arg(time);
      server->getDatabase()->exec(info_update);
    }

    if (p->getState() == Player::Offline) {
      addRunRate(pid, mode);
    }
  }
  server->endTransaction();

  for (auto p : players) {
    auto pid = p->getId();

    if (pid > 0) {
      int time = p->getGameTime();
      auto bytes = QCborArray { pid, time }.toCborValue().toCbor();
      doBroadcastNotify(getOtherPlayers(p), "AddTotalGameTime", bytes);

      // 考虑到阵亡已离开啥的，时间得给真实玩家增加
      auto realPlayer = server->findPlayer(pid);
      if (realPlayer) {
        realPlayer->addTotalGameTime(time);
        realPlayer->doNotify("AddTotalGameTime", bytes);
      }
    }

    if (p->getState() != Player::Online) {
      if (p->getState() == Player::Offline) {
        if (!isOutdated()) {
          server->temporarilyBan(pid);
        } else {
          emit p->kicked();
        }
      }
      to_delete.append(p);
    }
  }

  for (auto p : to_delete) {
    players.removeOne(p);
    delete p;
  }

  insideGameOver = false;
}

void Room::manuallyStart() {
  if (isFull() && !gameStarted) {
    qInfo("[GameStart] Room %d started", getId());
    QMap<QString, QStringList> uuidList, ipList;
    for (auto p : players) {
      p->setReady(false);
      p->setDied(false);
      p->startGameTimer();

      if (p->getId() < 0) continue;
      auto uuid = p->getUuid();
      auto ip = p->getPeerAddress();
      auto pname = p->getScreenName();
      if (!uuid.isEmpty()) {
        uuidList[uuid].append(pname);
      }
      if (!ip.isEmpty()) {
        ipList[ip].append(pname);
      }
    }

    for (auto i = ipList.cbegin(); i != ipList.cend(); i++) {
      if (i.value().length() <= 1) continue;
      auto warn = QString("*WARN* Same IP address: [%1]").arg(i.value().join(", "));
      auto warnUtf8 = warn.toUtf8();
      doBroadcastNotify(getPlayers(), "ServerMessage", warnUtf8);
      qInfo("%s", warnUtf8.constData());
    }

    for (auto i = uuidList.cbegin(); i != uuidList.cend(); i++) {
      if (i.value().length() <= 1) continue;
      auto warn = QString("*WARN* Same device id: [%1]").arg(i.value().join(", "));
      auto warnUtf8 = warn.toUtf8();
      doBroadcastNotify(getPlayers(), "ServerMessage", warnUtf8);
      qInfo("%s", warnUtf8.constData());
    }

    gameStarted = true;
    auto thread = qobject_cast<RoomThread *>(parent());
    thread->pushRequest(QString("-1,%1,newroom").arg(QString::number(id)));
  }
}

void Room::pushRequest(const QString &req) {
  auto thread = qobject_cast<RoomThread *>(parent());
  thread->pushRequest(QString("%1,%2").arg(QString::number(id), req));
}

void Room::addRejectId(int id) {
  rejected_players << id;
}

void Room::removeRejectId(int id) {
  rejected_players.removeOne(id);
}

// ------------------------------------------------
void Room::quitRoom(ServerPlayer *player, const QString &) {
  removePlayer(player);
  if (isOutdated()) {
    auto p = server->findPlayer(player->getId());
    if (p) emit p->kicked();
  }
}

void Room::addRobotRequest(ServerPlayer *player, const QString &) {
  if (ServerInstance->getConfig("enableBots").toBool())
    addRobot(player);
}

void Room::kickPlayer(ServerPlayer *player, const QString &jsonData) {
  int i = jsonData.toInt();
  auto p = findPlayer(i);
  if (p && !isStarted()) {
    removePlayer(p);
    addRejectId(i);
    QTimer::singleShot(30000, this, [=]() {
        removeRejectId(i);
        });
  }
}

void Room::ready(ServerPlayer *player, const QString &) {
  player->setReady(!player->isReady());
}

void Room::startGame(ServerPlayer *player, const QString &) {
  if (isOutdated()) {
    for (auto p : getPlayers()) {
      p->doNotify("ErrorMsg", "room is outdated");
      emit p->kicked();
    }
  } else {
    manuallyStart();
  }
}

typedef void (Room::*room_cb)(ServerPlayer *, const QString &);

void Room::handlePacket(ServerPlayer *sender, const QString &command,
                        const QString &jsonData) {
  static const QMap<QString, room_cb> room_actions = {
    {"QuitRoom", &Room::quitRoom},
    {"AddRobot", &Room::addRobotRequest},
    {"KickPlayer", &Room::kickPlayer},
    {"Ready", &Room::ready},
    {"StartGame", &Room::startGame},
    {"Chat", &Room::chat},
  };

  if (command == "PushRequest") {
    pushRequest(QString("%1,").arg(sender->getId()) + jsonData);
    return;
  }

  auto func = room_actions[command];
  if (func) (this->*func)(sender, jsonData);
}

// Lua用：request之前设置计时器防止等到死。
void Room::setRequestTimer(int ms) {
  request_timer = new QTimer();
  request_timer->setSingleShot(true);
  request_timer->setInterval(ms);
  connect(request_timer, &QTimer::timeout, this, [=](){
      auto thread = qobject_cast<RoomThread *>(parent());
      thread->wakeUp(id, "request_timer");
      });
  request_timer->start();
}

// Lua用：当request完成后手动销毁计时器。
void Room::destroyRequestTimer() {
  if (!request_timer) return;
  request_timer->stop();
  delete request_timer;
  request_timer = nullptr;
}

int Room::getRefCount() {
  QMutexLocker locker(&lua_ref_mutex);
  return lua_ref_count;
}

void Room::increaseRefCount() {
  QMutexLocker locker(&lua_ref_mutex);
  lua_ref_count++;
}

void Room::decreaseRefCount() {
  QMutexLocker locker(&lua_ref_mutex);
  lua_ref_count--;
  if (lua_ref_count == 0 && m_abandoned)
    deleteLater();
}
