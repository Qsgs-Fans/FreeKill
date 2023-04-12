// SPDX-License-Identifier: GPL-3.0-or-later

#include "clientplayer.h"

ClientPlayer::ClientPlayer(int id, QObject *parent) : Player(parent) {
  setId(id);
}

ClientPlayer::~ClientPlayer() {}
