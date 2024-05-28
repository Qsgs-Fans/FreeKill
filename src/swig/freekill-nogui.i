// SPDX-License-Identifier: GPL-3.0-or-later

%module fk

%{
#include "server/server.h"
#include "server/serverplayer.h"
#include "client/clientplayer.h"
#include "server/room.h"
#include "server/roomthread.h"
#include "core/util.h"
#include "ui/qmlbackend.h"
class ClientPlayer *Self = nullptr;
%}

%include "naturalvar.i"
%include "qt.i"
%include "qml-nogui.i"
%include "player.i"
%include "server.i"

QString GetDisabledPacks();
