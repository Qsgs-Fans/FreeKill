#ifndef _QMLBACKEND_H
#define _QMLBACKEND_H

#include <QObject>
#include <QJsonDocument>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "client.h"

class QmlBackend : public QObject {
    Q_OBJECT
public:
    QmlBackend(QObject *parent = nullptr);

    QQmlApplicationEngine *getEngine() const;
    void setEngine(QQmlApplicationEngine *engine);

    Q_INVOKABLE void startServer(ushort port);
    Q_INVOKABLE void joinServer(QString address);

    // Lobby
    Q_INVOKABLE void quitLobby();

    // lua --> qml
    void emitNotifyUI(const QString &command, const QString &jsonData);

signals:
    void notifyUI(const QString &command, const QString &jsonData);

private:
    QQmlApplicationEngine *engine;
};

extern QmlBackend *Backend;

#endif // _QMLBACKEND_H
