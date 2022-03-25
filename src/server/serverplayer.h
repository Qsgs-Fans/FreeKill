#ifndef _SERVERPLAYER_H
#define _SERVERPLAYER_H

#include "player.h"
#include "router.h"
#include <QVariant>
class ClientSocket;
class Server;
class Room;

class ServerPlayer : public Player {
    Q_OBJECT
public:
    explicit ServerPlayer(Room *room);
    ~ServerPlayer();

    void setSocket(ClientSocket *socket);

    Server *getServer() const;
    Room *getRoom() const;
    void setRoom(Room *room);

    void speak(const QString &message);

    void doRequest(const QString &command,
                   const QString &jsonData, int timeout = -1);
    void doReply(const QString &command, const QString &jsonData);
    void doNotify(const QString &command, const QString &jsonData);

    void prepareForRequest(const QString &command,
                           const QVariant &data = QVariant());

signals:
    void disconnected();
                            
private:
    ClientSocket *socket;   // socket for communicating with client
    Router *router;
    Server *server;
    Room *room;             // Room that player is in, maybe lobby

    QString requestCommand;
    QVariant requestData;
};

#endif // _SERVERPLAYER_H
