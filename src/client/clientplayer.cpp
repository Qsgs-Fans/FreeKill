// SPDX-License-Identifier: GPL-3.0-or-later

#include "client/clientplayer.h"

ClientPlayer::ClientPlayer(int id, QObject *parent) : Player(parent) {
  setId(id);
}

ClientPlayer::~ClientPlayer() {}
