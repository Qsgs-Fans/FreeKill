#include "qmlbackend.h"
#include "server.h"
#include "client.h"

void QmlBackend::startServer(ushort port)
{
    class Server *server = new class Server(this);
    server->listen(QHostAddress::Any, port);
}

void QmlBackend::joinServer(QString address)
{
    class Client *client = new class Client(this);
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
