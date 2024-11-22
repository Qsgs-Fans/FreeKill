// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _PCH_H
#define _PCH_H

// core gui qml
#include <QtCore>

// network
#include <QTcpServer>
#include <QTcpSocket>
#include <QUdpSocket>

// other libraries
#define OPENSSL_API_COMPAT 0x10101000L

#define QT_ENABLE_STRICT_MODE_UP_TO 0x060200

#if !defined (Q_OS_ANDROID)
#define DESKTOP_BUILD
#endif

#if defined (Q_OS_LINUX) && !defined (Q_OS_ANDROID)
#define FK_USE_READLINE
#endif

// You may define FK_SERVER_ONLY with cmake .. -D...
#ifndef FK_SERVER_ONLY
#include <QApplication>
#include <QtQml>
#endif

#endif // _PCH_H
