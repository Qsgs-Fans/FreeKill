%module freekill

%{
#include "client.h"
#include "server.h"
#include "serverplayer.h"
#include "clientplayer.h"
#include "room.h"
#include "qmlbackend.h"
%}

%include "naturalvar.i"
%include "qt.i"
%include "player.i"
%include "client.i"
%include "server.i"
%include "sqlite3.i"
