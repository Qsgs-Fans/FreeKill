#include "qmlbackend.h"
#include "server.h"
#include "client.h"

Server *ServerInstance;
Client *ClientInstance;

void QmlBackend::startServer(ushort port)
{
    ServerInstance = new class Server(this);
    ServerInstance->listen(QHostAddress::Any, port);
}

void QmlBackend::joinServer(QString address)
{
    ClientInstance = new class Client(this);
    QString addr = "127.0.0.1";
    ushort port = 9527u;

    if (address.contains(QChar(':'))) {
        QStringList texts = address.split(QChar(':'));
        addr = texts.value(0);
        port = texts.value(1).toUShort();
    } else {
        addr = address;
    }

    ClientInstance->connectToHost(QHostAddress(addr), port);
}
