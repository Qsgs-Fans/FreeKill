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
        Client,
        NotStarted
    };

    Q_INVOKABLE void startServer(ushort port);
    Q_INVOKABLE void joinServer(QString address);
signals:
    void callback(QString func_name, QString json_data);
private:
    WindowType type;
};

extern QmlBackend *Backend;

#endif // _QMLBACKEND_H
