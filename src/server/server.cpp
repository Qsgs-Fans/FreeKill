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
    createRoom(nullptr, "Lobby", INT32_MAX);
    connect(lobby(), &Room::playerAdded, this, &Server::updateRoomList);
    connect(lobby(), &Room::playerRemoved, this, &Server::updateRoomList);

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

void Server::createRoom(ServerPlayer* owner, const QString &name, int capacity)
{
    Room *room = new Room(this);
    connect(room, &Room::abandoned, this, &Server::onRoomAbandoned);
    if (room->isLobby())
        m_lobby = room;
    else
        rooms.insert(room->getId(), room);

    room->setName(name);
    room->setCapacity(capacity);
    room->addPlayer(owner);
    if (!room->isLobby()) room->setOwner(owner);
}

Room *Server::findRoom(int id) const
{
    return rooms.value(id);
}

Room *Server::lobby() const
{
    return m_lobby;
}

ServerPlayer *Server::findPlayer(int id) const
{
    return players.value(id);
}

void Server::removePlayer(int id) {
    players.remove(id);
}

void Server::updateRoomList()
{
    QJsonArray arr;
    foreach (Room *room, rooms) {
        QJsonArray obj;
        obj << room->getId();  // roomId
        obj << room->getName();     // roomName
        obj << "Role";              // gameMode
        obj << room->getPlayers().count();  // playerNum
        obj << room->getCapacity();    // capacity
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
    QString error_msg;
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
            // check if this username already login
            int id = result["id"].toArray()[0].toString().toInt();
            if (!players.value(id))
                // check if password is the same
                passed = (passwordHash == arr[0].toString());
                if (!passed) error_msg = "username or password error";
            else {
                // TODO: reconnect here
                error_msg = "others logged in with this name";
            }
        }
    }

    if (passed) {
        // create new ServerPlayer and setup
        ServerPlayer *player = new ServerPlayer(lobby());
        player->setSocket(client);
        client->disconnect(this);
        connect(player, &ServerPlayer::disconnected, this, &Server::onUserDisconnected);
        connect(player, &Player::stateChanged, this, &Server::onUserStateChanged);
        player->setScreenName(name);
        player->setAvatar(result["avatar"].toArray()[0].toString());
        player->setId(result["id"].toArray()[0].toString().toInt());
        players.insert(player->getId(), player);

        // tell the lobby player's basic property
        QJsonArray arr;
        arr << player->getId();
        arr << player->getScreenName();
        arr << player->getAvatar();
        player->doNotify("Setup", QJsonDocument(arr).toJson());

        lobby()->addPlayer(player);
    } else {
        qDebug() << client->peerAddress() << "lost connection:" << error_msg;
        QJsonArray body;
        body << -2;
        body << (Router::TYPE_NOTIFICATION | Router::SRC_SERVER | Router::DEST_CLIENT);
        body << "ErrorMsg";
        body << error_msg;
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
    ServerPlayer *player = qobject_cast<ServerPlayer *>(sender());
    qDebug() << "Player" << player->getId() << "disconnected";
    Room *room = player->getRoom();
    if (room->isStarted()) {
        player->setState(Player::Offline);
    } else {
        player->deleteLater();
    }
}

void Server::onUserStateChanged()
{
    Player *player = qobject_cast<Player *>(sender());
    QJsonArray arr;
    arr << player->getId();
    arr << player->getStateString();
    callLua("PlayerStateChanged", QJsonDocument(arr).toJson());
}
