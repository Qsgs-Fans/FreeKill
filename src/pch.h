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

#include <openssl/rsa.h>
#include <openssl/pem.h>

#if !defined (Q_OS_ANDROID) && !defined (Q_OS_WASM)
#define DESKTOP_BUILD
#endif

#endif // _PCH_H
