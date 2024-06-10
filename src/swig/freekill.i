// SPDX-License-Identifier: GPL-3.0-or-later

%module fk

%{
#include "client/client.h"
#include "server/server.h"
#include "server/serverplayer.h"
#include "client/clientplayer.h"
#include "server/room.h"
#include "server/roomthread.h"
#include "ui/qmlbackend.h"
#include "core/util.h"

const char *FK_VER = FK_VERSION;
%}

%include "naturalvar.i"
%include "qt.i"
%include "player.i"
%include "client.i"
%include "server.i"

extern char *FK_VER;
QString GetDisabledPacks();
