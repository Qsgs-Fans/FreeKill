#ifndef _CLIENTPLAYER_H
#define _CLIENTPLAYER_H

#include "player.h"

class ClientPlayer : public Player {
    Q_OBJECT
public:
    ClientPlayer(uint id, QObject *parent = nullptr);
    ~ClientPlayer();

private:
};

extern ClientPlayer *Self;

#endif // _CLIENTPLAYER_H
