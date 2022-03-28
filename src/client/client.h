#ifndef _CLIENT_H
#define _CLIENT_H

#include "router.h"
#include "clientplayer.h"

class Client : public QObject {
    Q_OBJECT
public:
    Client(QObject *parent = nullptr);
    ~Client();

    void connectToHost(const QHostAddress &server, ushort port);

    Q_INVOKABLE void replyToServer(const QString &command, const QString &jsonData);
    Q_INVOKABLE void notifyServer(const QString &command, const QString &jsonData);

    Q_INVOKABLE void callLua(const QString &command, const QString &jsonData);
    LuaFunction callback;

    ClientPlayer *addPlayer(int id, const QString &name, const QString &avatar);
    void removePlayer(int id);
    Q_INVOKABLE void clearPlayers();

signals:
    void error_message(const QString &msg);

private:
    Router *router;
    QMap<int, ClientPlayer *> players;

    lua_State *L;
};

extern Client *ClientInstance;

#endif // _CLIENT_H
