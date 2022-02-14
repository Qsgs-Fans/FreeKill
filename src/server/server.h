#ifndef _SERVER_H
#define _SERVER_H

#include <QObject>
#include <QHash>
#include <QHostAddress>

class ServerSocket;
class ClientSocket;
class Room;
class ServerPlayer;

class Server : public QObject {
    Q_OBJECT

public:
    explicit Server(QObject *parent = nullptr);
    ~Server();

    bool listen(const QHostAddress &address = QHostAddress::Any, ushort port = 9527u);

    void createRoom(ServerPlayer *owner, const QString &name, uint capacity);
    Room *findRoom(uint id) const;
    Room *lobby() const;

    ServerPlayer *findPlayer(uint id) const;

    void updateRoomList(ServerPlayer *user);

signals:
    void roomCreated(Room *room);
    void playerAdded(ServerPlayer *player);
    void playerRemoved(ServerPlayer *player);

public slots:
    void processNewConnection(ClientSocket *client);

    void onRoomAbandoned();
    void onUserDisconnected();
    void onUserStateChanged();

private:
    ServerSocket *server;
    QHash<uint, Room *> rooms;
    QHash<uint, ServerPlayer *> players;
};

#endif // _SERVER_H
