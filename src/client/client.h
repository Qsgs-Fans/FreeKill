#ifndef _CLIENT_H
#define _CLIENT_H

#include <QObject>
#include <lua.hpp>
#include "router.h"
#include "clientplayer.h"
#include "global.h"

class Client : public QObject {
    Q_OBJECT
public:
    Client(QObject *parent = nullptr);
    ~Client();

    void connectToHost(const QHostAddress &server, ushort port);

    // TODO: database of the server
    // void signup
    // void login

    void requestServer(const QString &command,
                   const QString &json_data, int timeout = -1);
    void replyToServer(const QString &command, const QString &json_data);
    void notifyServer(const QString &command, const QString &json_data);

    LuaFunction callback;

private:
    Router *router;
    QMap<uint, ClientPlayer *> players;
    ClientPlayer *self;

    lua_State *L;
};

extern Client *ClientInstance;

#endif // _CLIENT_H
