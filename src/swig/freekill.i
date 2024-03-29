// SPDX-License-Identifier: GPL-3.0-or-later

%module fk

%{
#include "client.h"
#include "server.h"
#include "serverplayer.h"
#include "clientplayer.h"
#include "room.h"
#include "roomthread.h"
#include "qmlbackend.h"
#include "util.h"

const char *FK_VER = FK_VERSION;
%}

%include "naturalvar.i"
%include "qt.i"
%include "player.i"
%include "client.i"
%include "server.i"

extern char *FK_VER;
QString GetDisabledPacks();
