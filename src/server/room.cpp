#include "room.h"
#include "serverplayer.h"
#include "server.h"

Room::Room(Server* server)
{
    static uint roomId = 0;
    id = roomId;
    roomId++;
    this->server = server;
    if (!isLobby()) {
        connect(this, &Room::playerAdded, server->lobby(), &Room::removePlayer);
        connect(this, &Room::playerRemoved, server->lobby(), &Room::addPlayer);
    }
}

Room::~Room()
{
    // TODO
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
    players.append(player);
    player->setRoom(this);
    if (isLobby()) {
        player->doNotify("EnterLobby", "[]");
    } else {
        player->doNotify("EnterRoom", "[]");
    }
    qDebug() << "Player #" << player->getUid() << " entered room";
    emit playerAdded(player);
}

void Room::removePlayer(ServerPlayer *player)
{
    players.removeOne(player);
    emit playerRemoved(player);

    if (isLobby()) return;

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

ServerPlayer *Room::findPlayer(uint id) const
{
    foreach (ServerPlayer *p, players) {
        if (p->getId() == id)
            return p;
    }
    return nullptr;
}

void Room::setGameLogic(GameLogic *logic)
{
    this->logic = logic;
}

GameLogic *Room::getGameLogic() const
{
    return logic;
}

void Room::startGame()
{
    // TODO
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


void Room::run()
{
    // TODO
}

