#include "clientplayer.h"

ClientPlayer::ClientPlayer(int id, QObject* parent)
    : Player(parent)
{
    setId(id);
}

ClientPlayer::~ClientPlayer()
{
}
