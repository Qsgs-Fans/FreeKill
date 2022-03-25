#ifndef _QMLBACKEND_H
#define _QMLBACKEND_H

#include <QObject>
#include <QJsonDocument>
#include "client.h"

class QmlBackend : public QObject {
    Q_OBJECT
public:
    QmlBackend(QObject *parent = nullptr);

    Q_INVOKABLE void startServer(ushort port);
    Q_INVOKABLE void joinServer(QString address);
    Q_INVOKABLE void replyToServer(const QString &command, const QString &jsonData);
    Q_INVOKABLE void notifyServer(const QString &command, const QString &jsonData);

    // Lobby
    Q_INVOKABLE void quitLobby();

    // For interacting between lua and qml
    // lua --> qml
    void emitNotifyUI(const QString &command, const QString &jsonData);

    // qml --> lua
    Q_INVOKABLE void callLua(const QString &command, const QString &jsonData);

signals:
    void notifyUI(const QString &command, const QString &jsonData);
};

extern QmlBackend *Backend;

#endif // _QMLBACKEND_H
