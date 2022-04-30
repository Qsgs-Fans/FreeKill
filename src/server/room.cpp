#include "room.h"
#include "serverplayer.h"
#include "server.h"
#include "util.h"

Room::Room(Server* server)
{
  id = server->nextRoomId;
  server->nextRoomId++;
  this->server = server;
  setParent(server);
  owner = nullptr;
  gameStarted = false;
  robot_id = -1;
  timeout = 15;
  if (!isLobby()) {
    connect(this, &Room::playerAdded, server->lobby(), &Room::removePlayer);
    connect(this, &Room::playerRemoved, server->lobby(), &Room::addPlayer);
  }

  L = CreateLuaState();
  DoLuaScript(L, "lua/freekill.lua");
  if (isLobby()) {
    DoLuaScript(L, "lua/server/lobby.lua");
  } else {
    DoLuaScript(L, "lua/server/room.lua");
  }
  initLua();
}

Room::~Room()
{
  // TODO
  if (isRunning()) {
    callLua("RoomDeleted", "");
    unlockLua(__FUNCTION__);
    wait();
  }
  lua_close(L);
}

Server *Room::getServer() const
{
  return server;
}

int Room::getId() const
{
  return id;
}

bool Room::isLobby() const
{
  return id == 0;
}

QString Room::getName() const
{
  return name;
}

void Room::setName(const QString &name)
{
  this->name = name;
}

int Room::getCapacity() const
{
  return capacity;
}

void Room::setCapacity(int capacity)
{
  this->capacity = capacity;
}

bool Room::isFull() const
{
  return players.count() == capacity;
}

bool Room::isAbandoned() const
{
  if (players.isEmpty())
    return true;

  foreach (ServerPlayer *p, players) {
    if (p->getState() == Player::Online)
      return false;
  }
  return true;
}

ServerPlayer *Room::getOwner() const
{
  return owner;
}

void Room::setOwner(ServerPlayer *owner)
{
  this->owner = owner;
  QJsonArray jsonData;
  jsonData << owner->getId();
  doBroadcastNotify(players, "RoomOwner", QJsonDocument(jsonData).toJson());
}

void Room::addPlayer(ServerPlayer *player)
{
  if (!player) return;

  if (isFull() || gameStarted) {
    player->doNotify("ErrorMsg", "Room is full or already started!");
    if (runned_players.contains(player->getId())) {
      player->doNotify("ErrorMsg", "Running away is shameful.");
    }
    return;
  }

  QJsonArray jsonData;

  // First, notify other players the new player is entering
  if (!isLobby()) {
    jsonData << player->getId();
    jsonData << player->getScreenName();
    jsonData << player->getAvatar();
    doBroadcastNotify(getPlayers(), "AddPlayer", QJsonDocument(jsonData).toJson());
  }

  players.append(player);
  player->setRoom(this);
  if (isLobby()) {
    player->doNotify("EnterLobby", "[]");
  } else {
    // Second, let the player enter room and add other players
    jsonData = QJsonArray();
    jsonData << this->capacity;
    jsonData << this->timeout;
    player->doNotify("EnterRoom", QJsonDocument(jsonData).toJson());

    foreach (ServerPlayer *p, getOtherPlayers(player)) {
      jsonData = QJsonArray();
      jsonData << p->getId();
      jsonData << p->getScreenName();
      jsonData << p->getAvatar();
      player->doNotify("AddPlayer", QJsonDocument(jsonData).toJson());
    }

    if (this->owner != nullptr) {
      jsonData = QJsonArray();
      jsonData << this->owner->getId();
      player->doNotify("RoomOwner", QJsonDocument(jsonData).toJson());
    }

    if (isFull() && !gameStarted)
      start();
  }
  emit playerAdded(player);
}

void Room::addRobot(ServerPlayer *player)
{
  if (player != owner || isFull()) return;

  ServerPlayer *robot = new ServerPlayer(this);
  robot->setState(Player::Robot);
  robot->setId(robot_id);
  robot->setAvatar("guanyu");
  robot->setScreenName(QString("COMP-%1").arg(robot_id));
  robot_id--;

  addPlayer(robot);
}

void Room::removePlayer(ServerPlayer *player)
{
  players.removeOne(player);
  emit playerRemoved(player);

  if (isLobby()) return;

  if (gameStarted) {
    // TODO: if the player is died..

    // create robot first
    ServerPlayer *robot = new ServerPlayer(this);
    robot->setState(Player::Robot);
    robot->setId(robot_id);
    robot->setAvatar(player->getAvatar());
    robot->setScreenName(QString("COMP-%1").arg(robot_id));
    robot_id--;

    players.append(robot);

    // tell lua & clients
    QJsonArray jsonData;
    jsonData << player->getId();
    jsonData << robot->getId();
    callLua("PlayerRunned", QJsonDocument(jsonData).toJson());
    doBroadcastNotify(getPlayers(), "PlayerRunned", QJsonDocument(jsonData).toJson());
    runned_players << player->getId();

    // FIXME: abortRequest here will result crash
    // but if dont abort and room is abandoned, the main thread will wait until replyed
    // player->abortRequest();
  } else {
    QJsonArray jsonData;
    jsonData << player->getId();
    doBroadcastNotify(getPlayers(), "RemovePlayer", QJsonDocument(jsonData).toJson());
  }

  if (isAbandoned()) {
    // FIXME: do not delete room here
    // create a new thread and delete the room
    emit abandoned();
  } else if (player == owner) {
    setOwner(players.first());
  }
}

QList<ServerPlayer *> Room::getPlayers() const
{
  return players;
}

QList<ServerPlayer *> Room::getOtherPlayers(ServerPlayer* expect) const
{
  QList<ServerPlayer *> others = getPlayers();
  others.removeOne(expect);
  return others;
}

ServerPlayer *Room::findPlayer(int id) const
{
  foreach (ServerPlayer *p, players) {
    if (p->getId() == id)
      return p;
  }
  return nullptr;
}

int Room::getTimeout() const
{
  return timeout;
}

void Room::setTimeout(int timeout)
{
  this->timeout = timeout;
}

bool Room::isStarted() const
{
  return gameStarted;
}

void Room::doRequest(const QList<ServerPlayer *> targets, int timeout)
{
  // TODO
}

void Room::doNotify(const QList<ServerPlayer *> targets, int timeout)
{
  // TODO
}

void Room::doBroadcastNotify(const QList<ServerPlayer *> targets,
               const QString& command, const QString& jsonData)
{
  foreach (ServerPlayer *p, targets) {
    p->doNotify(command, jsonData);
  }
}

void Room::gameOver()
{
  gameStarted = false;
  runned_players.clear();
  // clean not online players
  foreach (ServerPlayer *p, players) {
    if (p->getState() != Player::Online) {
      p->deleteLater();
    }
  }
}

void Room::lockLua(const QString &caller)
{
  if (!gameStarted) return;
  lua_mutex.lock();
#ifdef QT_DEBUG
  //qDebug() << caller << "=> room->L is locked.";
#endif
}

void Room::unlockLua(const QString &caller)
{
  if (!gameStarted) return;
  lua_mutex.unlock();
#ifdef QT_DEBUG
  //qDebug() << caller << "=> room->L is unlocked.";
#endif
}

void Room::run()
{
  gameStarted = true;
  lockLua(__FUNCTION__);
  roomStart();
  unlockLua(__FUNCTION__);
}
