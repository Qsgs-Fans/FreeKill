#ifndef _CLIENTPLAYER_H
#define _CLIENTPLAYER_H

#include "player.h"

class ClientPlayer : public Player {
    Q_OBJECT

    Q_PROPERTY(int id READ getId)
    Q_PROPERTY(QString screenName READ getScreenName WRITE setScreenName)
    Q_PROPERTY(QString avatar READ getAvatar WRITE setAvatar)

public:
    ClientPlayer(int id, QObject *parent = nullptr);
    ~ClientPlayer();

private:
};

extern ClientPlayer *Self;

#endif // _CLIENTPLAYER_H
