#include "qmlbackend.h"
#include "server.h"
#include "client.h"

QmlBackend *Backend;

QmlBackend::QmlBackend(QObject* parent)
    : QObject(parent)
{
    Backend = this;
}


void QmlBackend::startServer(ushort port)
{
    if (!ServerInstance) {
        class Server *server = new class Server(this);

        if (!server->listen(QHostAddress::Any, port)) {
            server->deleteLater();
            emit notifyUI("ErrorMsg", tr("Cannot start server!"));
        }
    }
}

void QmlBackend::joinServer(QString address)
{
    class Client *client = new class Client(this);
    connect(client, &Client::error_message, [this, client](const QString &msg){
        client->deleteLater();
        emit notifyUI("ErrorMsg", msg);
    });
    QString addr = "127.0.0.1";
    ushort port = 9527u;

    if (address.contains(QChar(':'))) {
        QStringList texts = address.split(QChar(':'));
        addr = texts.value(0);
        port = texts.value(1).toUShort();
    } else {
        addr = address;
    }

    client->connectToHost(QHostAddress(addr), port);
}

void QmlBackend::replyToServer(const QString& command, const QString& jsonData)
{
    ClientInstance->replyToServer(command, jsonData);
}

void QmlBackend::notifyServer(const QString& command, const QString& jsonData)
{
    ClientInstance->notifyServer(command, jsonData);
}

void QmlBackend::quitLobby()
{
    delete ClientInstance;
}
