#ifndef _SERVERPLAYER_H
#define _SERVERPLAYER_H

#include "player.h"
#include <QVariant>
class ClientSocket;
class Server;
class Room;

class ServerPlayer : public Player {
    Q_OBJECT
public:
    explicit ServerPlayer(Server *server);
    ~ServerPlayer();

    uint getUid();

    void setSocket(ClientSocket *socket);

    Server *getServer() const;
    Room *getRoom() const;
    void setRoom(Room *room);

    void speak(const QString &message);

    void doRequest(const QString &command,
                   const QVariant &data = QVariant(), int timeout = -1);
    void doReply(const QString &command, const QVariant &data = QVariant());
    void doNotify(const QString &command, const QVariant &data = QVariant());

    void prepareForRequest(const QString &command,
                           const QVariant &data = QVariant());
private:
    uint uid;
    ClientSocket *socket;   // socket for communicating with client
    Server *server;
    Room *room;             // Room that player is in, maybe lobby

    QString requestCommand;
    QVariant requestData;
};

#endif // _SERVERPLAYER_H
