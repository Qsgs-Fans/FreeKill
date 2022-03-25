#include "room.h"
#include "serverplayer.h"
#include "server.h"
#include <QJsonArray>
#include <QJsonDocument>

Room::Room(Server* server)
{
    static uint roomId = 0;
    id = roomId;
    roomId++;
    this->server = server;
    gameStarted = false;
    if (!isLobby()) {
        connect(this, &Room::playerAdded, server->lobby(), &Room::removePlayer);
        connect(this, &Room::playerRemoved, server->lobby(), &Room::addPlayer);
    }
}

Room::~Room()
{
    // TODO
    disconnect();
}

Server *Room::getServer() const
{
    return server;
}

uint Room::getId() const
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

uint Room::getCapacity() const
{
    return capacity;
}

void Room::setCapacity(uint capacity)
{
    this->capacity = capacity;
}

bool Room::isFull() const
{
    return players.count() == capacity;
}

bool Room::isAbandoned() const
{
    return players.isEmpty();
}

ServerPlayer *Room::getOwner() const
{
    return owner;
}

void Room::setOwner(ServerPlayer *owner)
{
    this->owner = owner;
}

void Room::addPlayer(ServerPlayer *player)
{
    if (!player) return;

    QJsonArray jsonData;

    // First, notify other players the new player is entering
    if (!isLobby()) {
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
        jsonData << (int)this->capacity;
        player->doNotify("EnterRoom", QJsonDocument(jsonData).toJson());

        foreach (ServerPlayer *p, getOtherPlayers(player)) {
            jsonData = QJsonArray();
            jsonData << p->getScreenName();
            jsonData << p->getAvatar();
            player->doNotify("AddPlayer", QJsonDocument(jsonData).toJson());
        }

        if (isFull())
            start();
    }
    emit playerAdded(player);
}

void Room::removePlayer(ServerPlayer *player)
{
    players.removeOne(player);
    emit playerRemoved(player);

    if (isLobby()) return;

    // player->doNotify("QuitRoom", "[]");
    QJsonArray jsonData;
    jsonData << player->getScreenName();
    doBroadcastNotify(getPlayers(), "RemovePlayer", QJsonDocument(jsonData).toJson());

    if (isAbandoned()) {
        emit abandoned();
    } else if (player == owner) {
        setOwner(players.first());
        owner->doNotify("RoomOwner", "[]");
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

ServerPlayer *Room::findPlayer(uint id) const
{
    foreach (ServerPlayer *p, players) {
        if (p->getId() == id)
            return p;
    }
    return nullptr;
}

bool Room::isStarted() const
{
    return gameStarted;
}

void Room::setGameLogic(GameLogic *logic)
{
    this->logic = logic;
}

GameLogic *Room::getGameLogic() const
{
    return logic;
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
    // clean offline players
    foreach (ServerPlayer *p, players) {
        if (p->getState() == Player::Offline) {
            p->deleteLater();
        }
    }
}

void Room::run()
{
    gameStarted = true;
    getServer()->roomStart(this);
}

