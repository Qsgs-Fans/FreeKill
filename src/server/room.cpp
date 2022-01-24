#include "room.h"
#include "serverplayer.h"
#include "server.h"

Room::Room(Server* server)
{
    static uint roomId = 0;
    id = roomId;
    roomId++;
    this->server = server;
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
    players.insert(player->getId(), player);
    emit playerAdded(player);
}

void Room::removePlayer(ServerPlayer *player)
{
    players.remove(player->getId());
    emit playerRemoved(player);
}

QHash<uint, ServerPlayer *> Room::getPlayers() const
{
    return players;
}

ServerPlayer *Room::findPlayer(uint id) const
{
    return players.value(id);
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

void Room::run()
{
    // TODO
}

