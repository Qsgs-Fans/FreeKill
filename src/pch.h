#ifndef _PCH_H
#define _PCH_H

// core gui qml
#include <QtCore>
#include <QApplication>
#include <QtQml>

// network
#include <QTcpServer>
#include <QTcpSocket>

// other libraries
typedef int LuaFunction;
#include "lua.hpp"
#include "sqlite3.h"

 // Note: headers of openssl is too big, so they are not provided in git repo
 // Please install openssl's src via Qt Installer, then copy headers
 // (<Qt_root>/Tools/OpenSSL/src/include/openssl) to <Qt6_dir>/mingw_64/include
#include <openssl/rsa.h>
#include <openssl/pem.h>

#endif // _PCH_H
