// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _CLIENTPLAYER_H
#define _CLIENTPLAYER_H

#include "core/player.h"

class ClientPlayer : public Player {
  Q_OBJECT

  Q_PROPERTY(int id READ getId CONSTANT)
  Q_PROPERTY(QString screenName
    READ getScreenName
    WRITE setScreenName
    NOTIFY screenNameChanged
  )
  Q_PROPERTY(QString avatar
    READ getAvatar
    WRITE setAvatar
    NOTIFY avatarChanged
  )

public:
  ClientPlayer(int id, QObject *parent = nullptr);
  ~ClientPlayer();

private:
};

extern ClientPlayer *Self;

#endif // _CLIENTPLAYER_H
