#include "server.h"
#include "server_socket.h"
#include "client_socket.h"
#include "room.h"
#include "serverplayer.h"
#include "global.h"
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegExp>
#include <QCryptographicHash>

Server *ServerInstance;

Server::Server(QObject* parent)
    : QObject(parent)
{
    ServerInstance = this;
    server = new ServerSocket();
    server->setParent(this);
    connect(server, &ServerSocket::new_connection,
            this, &Server::processNewConnection);

    // create lobby
    createRoom(NULL, "Lobby", UINT32_MAX);
    connect(lobby(), &Room::playerAdded, this, &Server::updateRoomList);

    L = CreateLuaState();
    DoLuaScript(L, "lua/freekill.lua");
    DoLuaScript(L, "lua/server/server.lua");

    db = OpenDatabase();
}

Server::~Server()
{
    ServerInstance = nullptr;
    m_lobby->deleteLater();
    lua_close(L);
    sqlite3_close(db);
}

bool Server::listen(const QHostAddress& address, ushort port)
{
    return server->listen(address, port);
}

void Server::createRoom(ServerPlayer* owner, const QString &name, uint capacity)
{
    Room *room = new Room(this);
    connect(room, &Room::abandoned, this, &Server::onRoomAbandoned);
    room->setName(name);
    room->setCapacity(capacity);
    room->setOwner(owner);
    room->addPlayer(owner);
    if (room->isLobby())
        m_lobby = room;
    else
        rooms.insert(room->getId(), room);
}

Room *Server::findRoom(uint id) const
{
    return rooms.value(id);
}

Room *Server::lobby() const
{
    return m_lobby;
}

ServerPlayer *Server::findPlayer(uint id) const
{
    return players.value(id);
}

void Server::updateRoomList()
{
    QJsonArray arr;
    foreach (Room *room, rooms) {
        QJsonArray obj;
        obj << (int)room->getId();  // roomId
        obj << room->getName();     // roomName
        obj << "Role";              // gameMode
        obj << room->getPlayers().count();  // playerNum
        obj << (int)room->getCapacity();    // capacity
        arr << obj;
    }
    lobby()->doBroadcastNotify(
        lobby()->getPlayers(),
        "UpdateRoomList",
        QJsonDocument(arr).toJson()
    );
}

void Server::processNewConnection(ClientSocket* client)
{
    qDebug() << client->peerAddress() << "connected";
    // version check, file check, ban IP, reconnect, etc

    connect(client, &ClientSocket::disconnected, this, [client](){
        qDebug() << client->peerAddress() << "disconnected";
    });

    // network delay test
    QJsonArray body;
    body << -2;
    body << (Router::TYPE_NOTIFICATION | Router::SRC_SERVER | Router::DEST_CLIENT);
    body << "NetworkDelayTest";
    body << "[]";
    client->send(QJsonDocument(body).toJson(QJsonDocument::Compact));
    // Note: the client should send a setup string next
    connect(client, &ClientSocket::message_got, this, &Server::processRequest);
    client->timerSignup.start(30000);
}

void Server::processRequest(const QByteArray& msg)
{
    ClientSocket *client = qobject_cast<ClientSocket *>(sender());
    client->disconnect(this, SLOT(processRequest(const QByteArray &)));
    client->timerSignup.stop();

    bool valid = true;
    QJsonDocument doc = QJsonDocument::fromJson(msg);
    if (doc.isNull() || !doc.isArray()) {
        valid = false;
    } else {
        if (doc.array().size() != 4
            || doc[0] != -2
            || doc[1] != (Router::TYPE_NOTIFICATION | Router::SRC_CLIENT | Router::DEST_SERVER)
            || doc[2] != "Setup"
        )
            valid = false;
        else
            valid = (QJsonDocument::fromJson(doc[3].toString().toUtf8()).array().size() == 2);
    }

    if (!valid) {
        qDebug() << "Invalid setup string:" << msg;
        QJsonArray body;
        body << -2;
        body << (Router::TYPE_NOTIFICATION | Router::SRC_SERVER | Router::DEST_CLIENT);
        body << "ErrorMsg";
        body << "INVALID SETUP STRING";
        client->send(QJsonDocument(body).toJson(QJsonDocument::Compact));
        client->disconnectFromHost();
        return;
    }

    QJsonArray arr = QJsonDocument::fromJson(doc[3].toString().toUtf8()).array();
    handleNameAndPassword(client, arr[0].toString(), arr[1].toString());
}

void Server::handleNameAndPassword(ClientSocket *client, const QString& name, const QString& password)
{
    // First check the name and password
    // Matches a string that does not contain special characters
    QRegExp nameExp("[^\\0000-\\0057\\0072-\\0100\\0133-\\0140\\0173-\\0177]+");
    QByteArray passwordHash = QCryptographicHash::hash(password.toLatin1(), QCryptographicHash::Sha256).toHex();
    bool passed = false;
    QJsonObject result;
    if (nameExp.exactMatch(name)) {
        // Then we check the database,
        QString sql_find = QString("SELECT * FROM userinfo \
        WHERE name='%1';").arg(name);
        result = SelectFromDatabase(db, sql_find);
        QJsonArray arr = result["password"].toArray();
        if (arr.isEmpty()) {
            // not present in database, register
            QString sql_reg = QString("INSERT INTO userinfo (name,password,\
            avatar,lastLoginIp,banned) VALUES ('%1','%2','%3','%4',%5);")
            .arg(name)
            .arg(QString(passwordHash))
            .arg("liubei")
            .arg(client->peerAddress())
            .arg("FALSE");
            ExecSQL(db, sql_reg);
            result = SelectFromDatabase(db, sql_find);  // refresh result
            passed = true;
        } else {
            // check if password is the same
            passed = (passwordHash == arr[0].toString());
        }
    }

    if (passed) {
        ServerPlayer *player = new ServerPlayer(lobby());
        player->setSocket(client);
        client->disconnect(this);
        connect(client, &ClientSocket::disconnected, this, [player](){
            qDebug() << "Player" << player->getId() << "disconnected";
        });
        player->setScreenName(name);
        player->setAvatar(result["avatar"].toArray()[0].toString());
        player->setId(result["id"].toArray()[0].toInt());
        players.insert(player->getId(), player);
        lobby()->addPlayer(player);
    } else {
        qDebug() << client->peerAddress() << "entered wrong password";
        QJsonArray body;
        body << -2;
        body << (Router::TYPE_NOTIFICATION | Router::SRC_SERVER | Router::DEST_CLIENT);
        body << "ErrorMsg";
        body << "username or password error";
        client->send(QJsonDocument(body).toJson(QJsonDocument::Compact));
        client->disconnectFromHost();
        return;
    }
}

void Server::onRoomAbandoned()
{
    Room *room = qobject_cast<Room *>(sender());
    rooms.remove(room->getId());
    updateRoomList();
    room->deleteLater();
}

void Server::onUserDisconnected()
{
    qobject_cast<ServerPlayer *>(sender())->setStateString("offline");
}

void Server::onUserStateChanged()
{
    // TODO
}
