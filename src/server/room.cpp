#include "room.h"
#include "serverplayer.h"
#include "server.h"
#include "util.h"
#include <qjsonarray.h>
#include <qjsondocument.h>

Room::Room(Server* server)
{
  setObjectName("Room");
  id = server->nextRoomId;
  server->nextRoomId++;
  this->server = server;
  setParent(server);
  m_abandoned = false;
  owner = nullptr;
  gameStarted = false;
  robot_id = -2;  // -1 is reserved in UI logic
  timeout = 15;
  L = NULL;
  if (!isLobby()) {
    connect(this, &Room::playerAdded, server->lobby(), &Room::removePlayer);
    connect(this, &Room::playerRemoved, server->lobby(), &Room::addPlayer);

    L = CreateLuaState();
    DoLuaScript(L, "lua/freekill.lua");
    DoLuaScript(L, "lua/server/room.lua");
    initLua();
  }
}

Room::~Room()
{
  if (isRunning()) {
    wait();
  }
  if (L) lua_close(L);
}

Server *Room::getServer() const
{
  return server;
}

int Room::getId() const
{
  return id;
}

void Room::setId(int id)
{
  this->id = id;
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

const QByteArray Room::getSettings() const {
  return settings;
}

void Room::setSettings(QByteArray settings) {
  this->settings = settings;
}

bool Room::isAbandoned() const
{
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

void Room::setAbandoned(bool abandoned) {
  m_abandoned = abandoned;
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
  doBroadcastNotify(players, "RoomOwner", JsonArray2Bytes(jsonData));
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
    doBroadcastNotify(getPlayers(), "AddPlayer", JsonArray2Bytes(jsonData));
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
    jsonData << QJsonDocument::fromJson(this->settings).object();
    player->doNotify("EnterRoom", JsonArray2Bytes(jsonData));

    foreach (ServerPlayer *p, getOtherPlayers(player)) {
      jsonData = QJsonArray();
      jsonData << p->getId();
      jsonData << p->getScreenName();
      jsonData << p->getAvatar();
      player->doNotify("AddPlayer", JsonArray2Bytes(jsonData));
    }

    if (this->owner != nullptr) {
      jsonData = QJsonArray();
      jsonData << this->owner->getId();
      player->doNotify("RoomOwner", JsonArray2Bytes(jsonData));
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
  if (observers.contains(player)) {
    removeObserver(player);
    return;
  }

  if (!gameStarted) {
    if (players.contains(player)) {
      players.removeOne(player);
    }
    emit playerRemoved(player);

    QJsonArray jsonData;
    jsonData << player->getId();
    doBroadcastNotify(getPlayers(), "RemovePlayer", JsonArray2Bytes(jsonData));

    if (isLobby()) return;
  } else {
    // TODO: if the player is died..

    // change the socket and state to runned player
    ClientSocket *socket = player->getSocket();
    player->setState(Player::Run);

    // and then create a new ServerPlayer for the runner
    ServerPlayer *runner = new ServerPlayer(this);
    runner->setSocket(socket);
    connect(runner, &ServerPlayer::disconnected, server, &Server::onUserDisconnected);
    connect(runner, &Player::stateChanged, server, &Server::onUserStateChanged);
    runner->setScreenName(player->getScreenName());
    runner->setAvatar(player->getAvatar());
    runner->setId(player->getId());

    // finally update Server's player list and clean
    server->addPlayer(runner);

    emit playerRemoved(runner);
    player->abortRequest();
  }

  if (isAbandoned() && !m_abandoned) {
    m_abandoned = true;
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

void Room::addObserver(ServerPlayer *player) {
  if (!gameStarted) {
    player->doNotify("ErrorMsg", "Can only observe running room.");
    return;
  }
  observers.append(player);
  player->setRoom(this);
  pushRequest(QString("%1,observe").arg(player->getId()));
}

void Room::removeObserver(ServerPlayer *player) {
  observers.removeOne(player);
  player->setRoom(server->lobby());
  if (player->getState() == Player::Online) {
    QJsonArray arr;
    arr << player->getId();
    arr << player->getScreenName();
    arr << player->getAvatar();
    player->doNotify("Setup", JsonArray2Bytes(arr));
    player->doNotify("EnterLobby", "");
  }
  pushRequest(QString("%1,leave").arg(player->getId()));
}

QList<ServerPlayer *> Room::getObservers() const {
  return observers;
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

void Room::doBroadcastNotify(const QList<ServerPlayer *> targets,
               const QString& command, const QString& jsonData)
{
  foreach (ServerPlayer *p, targets) {
    p->doNotify(command, jsonData);
  }
}

void Room::chat(ServerPlayer *sender, const QString &jsonData) {
  auto doc = String2Json(jsonData).object();
  auto type = doc["type"].toInt();
  doc["type"] = sender->getId();
  if (type == 1) {
    // TODO: server chatting
  } else {
    auto json = QJsonDocument(doc).toJson(QJsonDocument::Compact);
    doBroadcastNotify(players, "Chat", json);
    doBroadcastNotify(observers, "Chat", json);
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
  players.clear();
  owner = nullptr;
}

QString Room::fetchRequest() {
  request_queue_mutex.lock();
  QString ret = "";
  if (!request_queue.isEmpty()) {
    ret = request_queue.dequeue();
  }
  request_queue_mutex.unlock();
  return ret;
}

void Room::pushRequest(const QString &req) {
  request_queue_mutex.lock();
  request_queue.enqueue(req);
  request_queue_mutex.unlock();
}

bool Room::hasRequest() const {
  return !request_queue.isEmpty();
}

void Room::run()
{
  gameStarted = true;
  roomStart();
}
