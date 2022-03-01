#ifndef _QMLBACKEND_H
#define _QMLBACKEND_H

#include <QObject>
#include <QJsonDocument>
#include "client.h"

class QmlBackend : public QObject {
    Q_OBJECT
public:
    enum WindowType {
        Server,
        Lobby,
        Room,
        NotStarted
    };

    QmlBackend(QObject *parent = nullptr);

    // For lua use
    void emitNotifyUI(const char *command, const char *json_data) {
        emit notifyUI(command, json_data);
    }

signals:
    void notifyUI(const QString &command, const QString &json_data);

public slots:
    void startServer(ushort port);
    void joinServer(QString address);
    void replyToServer(const QString &command, const QString &json_data);
    void notifyServer(const QString &command, const QString &json_data);

    // Lobby
    void quitLobby();

private:
    WindowType type;
};

extern QmlBackend *Backend;

#endif // _QMLBACKEND_H
