// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _PCH_H
#define _PCH_H

// core gui qml
#include <QtCore>

// network
#include <QTcpServer>
#include <QTcpSocket>
#include <QUdpSocket>

#define QT_ENABLE_STRICT_MODE_UP_TO 0x060200

// test
#include <QTest>
#include <QSignalSpy>

// other libraries
#define OPENSSL_API_COMPAT 0x10101000L

#include <QCoreApplication>

#endif // _PCH_H
