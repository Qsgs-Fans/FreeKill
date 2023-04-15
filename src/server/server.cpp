// SPDX-License-Identifier: GPL-3.0-or-later

#include "server.h"

#include <qjsonarray.h>

#include "client_socket.h"
#include "packman.h"
#include "parser.h"
#include "player.h"
#include "room.h"
#include "router.h"
#include "server_socket.h"
#include "serverplayer.h"
#include "util.h"

Server *ServerInstance;

Server::Server(QObject *parent) : QObject(parent) {
  ServerInstance = this;
  db = OpenDatabase();
  rsa = InitServerRSA();
  QFile file("server/rsa_pub");
  file.open(QIODevice::ReadOnly);
  QTextStream in(&file);
  public_key = in.readAll();
  Parser::parseFkp();
  md5 = calcFileMD5();

  server = new ServerSocket();
  server->setParent(this);
  connect(server, &ServerSocket::new_connection, this,
          &Server::processNewConnection);

  // 创建第一个房间，这个房间作为“大厅房间”
  nextRoomId = 0;
  createRoom(nullptr, "Lobby", INT32_MAX);
  // 大厅只要发生人员变动，就向所有人广播一下房间列表
  connect(lobby(), &Room::playerAdded, this, &Server::updateRoomList);
  connect(lobby(), &Room::playerRemoved, this, &Server::updateRoomList);

  // 启动心跳包线程
  auto heartbeatThread = QThread::create([=]() {
    while (true) {
      foreach (auto p, this->players.values()) {
        if (p->getState() == Player::Online) {
          p->alive = false;
          p->doNotify("Heartbeat", "");
        }
      }

      QThread::sleep(20);

      foreach (auto p, this->players.values()) {
        if (p->getState() == Player::Online && !p->alive) {
          p->kicked();
        }
      }
    }
  });
  heartbeatThread->setObjectName("Heartbeat");
  heartbeatThread->start();
}

Server::~Server() {
  ServerInstance = nullptr;
  m_lobby->deleteLater();
  sqlite3_close(db);
  RSA_free(rsa);
}

bool Server::listen(const QHostAddress &address, ushort port) {
  return server->listen(address, port);
}

void Server::createRoom(ServerPlayer *owner, const QString &name, int capacity,
                        const QByteArray &settings) {
  Room *room;
  if (!idle_rooms.isEmpty()) {
    room = idle_rooms.pop();
    room->setId(nextRoomId);
    nextRoomId++;
    room->setAbandoned(false);
    rooms.insert(room->getId(), room);
  } else {
    room = new Room(this);
    connect(room, &Room::abandoned, this, &Server::onRoomAbandoned);
    if (room->isLobby())
      m_lobby = room;
    else
      rooms.insert(room->getId(), room);
  }

  room->setName(name);
  room->setCapacity(capacity);
  room->setSettings(settings);
  room->addPlayer(owner);
  if (!room->isLobby())
    room->setOwner(owner);
}

Room *Server::findRoom(int id) const { return rooms.value(id); }

Room *Server::lobby() const { return m_lobby; }

ServerPlayer *Server::findPlayer(int id) const { return players.value(id); }

void Server::addPlayer(ServerPlayer *player) {
  int id = player->getId();
  if (players.contains(id))
    players.remove(id);

  players.insert(id, player);
}

void Server::removePlayer(int id) { players.remove(id); }

void Server::updateRoomList() {
  QJsonArray arr;
  foreach (Room *room, rooms) {
    QJsonArray obj;
    obj << room->getId();              // roomId
    obj << room->getName();            // roomName
    obj << "Role";                     // gameMode
    obj << room->getPlayers().count(); // playerNum
    obj << room->getCapacity();        // capacity
    arr << obj;
  }
  auto jsonData = JsonArray2Bytes(arr);
  lobby()->doBroadcastNotify(lobby()->getPlayers(), "UpdateRoomList",
                             QString(jsonData));

  lobby()->doBroadcastNotify(lobby()->getPlayers(), "UpdatePlayerNum",
                             QString(JsonArray2Bytes(QJsonArray({
                                 lobby()->getPlayers().length(),
                                 this->players.count(),
                             }))));
}

sqlite3 *Server::getDatabase() { return db; }

void Server::processNewConnection(ClientSocket *client) {
  qInfo() << client->peerAddress() << "connected";
  // version check, file check, ban IP, reconnect, etc

  connect(client, &ClientSocket::disconnected, this,
          [client]() { qInfo() << client->peerAddress() << "disconnected"; });

  // network delay test
  QJsonArray body;
  body << -2;
  body << (Router::TYPE_NOTIFICATION | Router::SRC_SERVER |
           Router::DEST_CLIENT);
  body << "NetworkDelayTest";
  body << public_key;
  client->send(JsonArray2Bytes(body));
  // Note: the client should send a setup string next
  connect(client, &ClientSocket::message_got, this, &Server::processRequest);
  client->timerSignup.start(30000);
}

void Server::processRequest(const QByteArray &msg) {
  ClientSocket *client = qobject_cast<ClientSocket *>(sender());
  client->disconnect(this, SLOT(processRequest(const QByteArray &)));
  client->timerSignup.stop();

  bool valid = true;
  QJsonDocument doc = QJsonDocument::fromJson(msg);
  if (doc.isNull() || !doc.isArray()) {
    valid = false;
  } else {
    if (doc.array().size() != 4 || doc[0] != -2 ||
        doc[1] != (Router::TYPE_NOTIFICATION | Router::SRC_CLIENT |
                   Router::DEST_SERVER) ||
        doc[2] != "Setup")
      valid = false;
    else
      valid = (String2Json(doc[3].toString()).array().size() == 3);
  }

  if (!valid) {
    qWarning() << "Invalid setup string:" << msg;
    QJsonArray body;
    body << -2;
    body << (Router::TYPE_NOTIFICATION | Router::SRC_SERVER |
             Router::DEST_CLIENT);
    body << "ErrorMsg";
    body << "INVALID SETUP STRING";
    client->send(JsonArray2Bytes(body));
    client->disconnectFromHost();
    return;
  }

  QJsonArray arr = String2Json(doc[3].toString()).array();

  if (md5 != arr[2].toString()) {
    QJsonArray body;
    body << -2;
    body << (Router::TYPE_NOTIFICATION | Router::SRC_SERVER |
             Router::DEST_CLIENT);
    body << "ErrorMsg";
    body << "MD5 check failed!";
    client->send(JsonArray2Bytes(body));

    body.removeLast();
    body.removeLast();
    body << "UpdatePackage";
    body << Pacman->getPackSummary();
    client->send(JsonArray2Bytes(body));

    client->disconnectFromHost();
    return;
  }

  handleNameAndPassword(client, arr[0].toString(), arr[1].toString());
}

void Server::handleNameAndPassword(ClientSocket *client, const QString &name,
                                   const QString &password) {
  // First check the name and password
  // Matches a string that does not contain special characters
  static QRegularExpression nameExp("['\";#]+|(--)|(/\\*)|(\\*/)|(--\\+)");

  auto encryted_pw = QByteArray::fromBase64(password.toLatin1());
  unsigned char buf[4096] = {0};
  RSA_private_decrypt(RSA_size(rsa), (const unsigned char *)encryted_pw.data(),
                      buf, rsa, RSA_PKCS1_PADDING);
  auto decrypted_pw =
      QByteArray::fromRawData((const char *)buf, strlen((const char *)buf));

  if (decrypted_pw.length() > 32) {
    auto aes_bytes = decrypted_pw.first(32);
    client->installAESKey(aes_bytes);
    decrypted_pw.remove(0, 32);
  } else {
    decrypted_pw = "\xFF";
  }

  bool passed = false;
  QString error_msg;
  QJsonArray result;
  QJsonObject obj;

  if (!nameExp.match(name).hasMatch() && !name.isEmpty()) {
    // Then we check the database,
    QString sql_find = QString("SELECT * FROM userinfo \
    WHERE name='%1';")
                           .arg(name);
    result = SelectFromDatabase(db, sql_find);
    if (result.isEmpty()) {
      auto salt_gen = QRandomGenerator::securelySeeded();
      auto salt = QByteArray::number(salt_gen(), 16);
      decrypted_pw.append(salt);
      auto passwordHash =
          QCryptographicHash::hash(decrypted_pw, QCryptographicHash::Sha256)
              .toHex();
      // not present in database, register
      QString sql_reg = QString("INSERT INTO userinfo (name,password,salt,\
      avatar,lastLoginIp,banned) VALUES ('%1','%2','%3','%4','%5',%6);")
                            .arg(name)
                            .arg(QString(passwordHash))
                            .arg(salt)
                            .arg("liubei")
                            .arg(client->peerAddress())
                            .arg("FALSE");
      ExecSQL(db, sql_reg);
      result = SelectFromDatabase(db, sql_find); // refresh result
      obj = result[0].toObject();
      passed = true;
    } else {
      obj = result[0].toObject();
      // check if this username already login
      int id = obj["id"].toString().toInt();
      if (!players.value(id)) {
        // check if password is the same
        auto salt = obj["salt"].toString().toLatin1();
        decrypted_pw.append(salt);
        auto passwordHash =
            QCryptographicHash::hash(decrypted_pw, QCryptographicHash::Sha256)
                .toHex();
        passed = (passwordHash == obj["password"].toString());
        if (!passed)
          error_msg = "username or password error";
      } else {
        auto player = players.value(id);
        if (player->getState() == Player::Offline) {
          auto room = player->getRoom();
          player->setSocket(client);
          client->disconnect(this);
          room->pushRequest(QString("%1,reconnect").arg(id));
          return;
        } else {
          error_msg = "others logged in with this name";
        }
      }
    }
  } else {
    error_msg = "invalid user name";
  }

  if (passed) {
    // create new ServerPlayer and setup
    ServerPlayer *player = new ServerPlayer(lobby());
    player->setSocket(client);
    client->disconnect(this);
    connect(player, &ServerPlayer::disconnected, this,
            &Server::onUserDisconnected);
    connect(player, &Player::stateChanged, this, &Server::onUserStateChanged);
    player->setScreenName(name);
    player->setAvatar(obj["avatar"].toString());
    player->setId(obj["id"].toString().toInt());
    players.insert(player->getId(), player);

    // tell the lobby player's basic property
    QJsonArray arr;
    arr << player->getId();
    arr << player->getScreenName();
    arr << player->getAvatar();
    player->doNotify("Setup", JsonArray2Bytes(arr));

    lobby()->addPlayer(player);
  } else {
    qInfo() << client->peerAddress() << "lost connection:" << error_msg;
    QJsonArray body;
    body << -2;
    body << (Router::TYPE_NOTIFICATION | Router::SRC_SERVER |
             Router::DEST_CLIENT);
    body << "ErrorMsg";
    body << error_msg;
    client->send(JsonArray2Bytes(body));
    client->disconnectFromHost();
    return;
  }
}

void Server::onRoomAbandoned() {
  Room *room = qobject_cast<Room *>(sender());
  room->gameOver();
  rooms.remove(room->getId());
  updateRoomList();
  // room->deleteLater();
  if (room->isRunning()) {
    room->wait();
  }
  idle_rooms.push(room);
#ifdef QT_DEBUG
  qDebug() << rooms.size() << "running room(s)," << idle_rooms.size()
           << "idle room(s).";
#endif
}

void Server::onUserDisconnected() {
  ServerPlayer *player = qobject_cast<ServerPlayer *>(sender());
  qInfo() << "Player" << player->getId() << "disconnected";
  Room *room = player->getRoom();
  if (room->isStarted()) {
    if (room->getObservers().contains(player)) {
      room->removeObserver(player);
      player->deleteLater();
      return;
    }
    player->setState(Player::Offline);
    player->setSocket(nullptr);
    // TODO: add a robot
  } else {
    player->deleteLater();
  }
}

void Server::onUserStateChanged() {}
