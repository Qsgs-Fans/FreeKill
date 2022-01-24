#include "clientplayer.h"

ClientPlayer::ClientPlayer(uint id, QObject* parent)
    : Player(parent)
{
    setId(id);
}

ClientPlayer::~ClientPlayer()
{
}
