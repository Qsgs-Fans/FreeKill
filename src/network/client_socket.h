#ifndef _CLIENT_SOCKET_H
#define _CLIENT_SOCKET_H

#include <QObject>
#include <QAbstractSocket>
#include <QHostAddress>

class QTcpSocket;

class ClientSocket : public QObject {
    Q_OBJECT

public:
    ClientSocket();
    // For server use
    ClientSocket(QTcpSocket *socket);

    void connectToHost(const QHostAddress &address = QHostAddress::LocalHost, ushort port = 9527u);
    void disconnectFromHost();
    void send(const QByteArray& msg);
    bool isConnected() const;
    QString peerName() const;
    QString peerAddress() const;

signals:
    void message_got(const QByteArray& msg);
    void error_message(const QString &msg);
    void disconnected();
    void connected();

private slots:
    void getMessage();
    void raiseError(QAbstractSocket::SocketError error);

private:
    QTcpSocket *socket;
    void init();
};

#endif // _CLIENT_SOCKET_H
