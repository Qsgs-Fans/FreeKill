// SPDX-License-Identifier: GPL-3.0-or-later

%module fk

%{
#include "server.h"
#include "serverplayer.h"
#include "clientplayer.h"
#include "room.h"
#include "util.h"
class ClientPlayer *Self = nullptr;
%}

%include "naturalvar.i"
%include "qt.i"
%include "player.i"
%include "server.i"
%include "sqlite3.i"
