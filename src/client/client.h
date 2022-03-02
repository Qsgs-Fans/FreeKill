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
                   const QString &jsonData, int timeout = -1);
    void replyToServer(const QString &command, const QString &jsonData);
    void notifyServer(const QString &command, const QString &jsonData);

    void callLua(const QString &command, const QString &jsonData);
    LuaFunction callback;

signals:
    void error_message(const QString &msg);

private:
    Router *router;
    QMap<uint, ClientPlayer *> players;

    lua_State *L;
};

extern Client *ClientInstance;

#endif // _CLIENT_H
