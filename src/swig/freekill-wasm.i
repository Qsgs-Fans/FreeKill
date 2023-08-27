// SPDX-License-Identifier: GPL-3.0-or-later

%module fk

%{
#include "client.h"
#include "serverplayer.h"
#include "clientplayer.h"
#include "room.h"
#include "qmlbackend.h"
#include "util.h"
%}

%include "naturalvar.i"
%include "qt.i"
%include "player.i"
%include "client.i"

QString GetDisabledPacks();
