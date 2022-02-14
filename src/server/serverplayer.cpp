#include "serverplayer.h"

ServerPlayer::ServerPlayer(Room *room)
    : uid(0)
{
    static int m_playerid = 0;
}

ServerPlayer::~ServerPlayer()
{

}

uint ServerPlayer::getUid()
{
    return uid;
}

void ServerPlayer::setSocket(ClientSocket *socket)
{
    this->socket = socket;
}
