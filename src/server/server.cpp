// SPDX-License-Identifier: GPL-3.0-or-later

#include "server.h"

#include <qjsonarray.h>
#include <qjsondocument.h>
#include <qjsonvalue.h>
#include <qobject.h>
#include <qversionnumber.h>

#include <openssl/bn.h>

#include "client_socket.h"
#include "packman.h"
#include "player.h"
#include "room.h"
#include "roomthread.h"
#include "router.h"
#include "server_socket.h"
#include "serverplayer.h"
#include "util.h"

Server *ServerInstance = nullptr;

Server::Server(QObject *parent) : QObject(parent) {
  ServerInstance = this;
  db = OpenDatabase();
  rsa = initServerRSA();
  QFile file("server/rsa_pub");
  file.open(QIODevice::ReadOnly);
  QTextStream in(&file);
  public_key = in.readAll();
  md5 = calcFileMD5();
  readConfig();

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

  threads.append(new RoomThread(this));

  // 启动心跳包线程
  auto heartbeatThread = QThread::create([=]() {
    while (true) {
      foreach (auto p, this->players.values()) {
        if (p->getState() == Player::Online) {
          p->alive = false;
          p->doNotify("Heartbeat", "");
        }
      }

      for (int i = 0; i < 20; i++) {
        if (!this->isListening) {
          return;
        }
        QThread::sleep(1);
      }

      foreach (auto p, this->players.values()) {
        if (p->getState() == Player::Online && !p->alive) {
          emit p->kicked();
        }
      }
    }
  });
  heartbeatThread->setParent(this);
  heartbeatThread->setObjectName("Heartbeat");
  heartbeatThread->start();
}

Server::~Server() {
  isListening = false;
  ServerInstance = nullptr;
  m_lobby->deleteLater();
//  foreach (auto room, idle_rooms) {
//    room->deleteLater();
//  }
  foreach (auto thread, threads) {
    thread->deleteLater();
  }
  sqlite3_close(db);
  RSA_free(rsa);
}

bool Server::listen(const QHostAddress &address, ushort port) {
  bool ret = server->listen(address, port);
  isListening = ret;
  return ret;
}

void Server::createRoom(ServerPlayer *owner, const QString &name, int capacity,
                        int timeout, const QByteArray &settings) {
  if (!checkBanWord(name)) {
    if (owner) {
      owner->doNotify("ErrorMsg", "unk error");
    }
    return;
  }
  Room *room;
  RoomThread *thread = nullptr;

  foreach (auto t, threads) {
    if (!t->isFull()) {
      thread = t;
    }
  }
  if (!thread && nextRoomId != 0) {
    thread = new RoomThread(this);
    threads.append(thread);
  }

  room = new Room(thread);
  connect(room, &Room::abandoned, this, &Server::onRoomAbandoned);
  if (room->isLobby())
    m_lobby = room;
  else
    rooms.insert(room->getId(), room);

  room->setName(name);
  room->setCapacity(capacity);
  room->setTimeout(timeout);
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

void Server::removePlayer(int id) {
  if (players[id]) {
    players.remove(id);
  }
}

void Server::updateRoomList() {
  QJsonArray arr;
  QJsonArray avail_arr;
  foreach (Room *room, rooms) {
    QJsonArray obj;
    auto settings = QJsonDocument::fromJson(room->getSettings());
    auto password = settings["password"].toString();
    auto count = room->getPlayers().count(); // playerNum
    auto cap = room->getCapacity();          // capacity

    obj << room->getId();        // roomId
    obj << room->getName();      // roomName
    obj << settings["gameMode"]; // gameMode
    obj << count;
    obj << cap;
    obj << !password.isEmpty();

    if (count == cap)
      arr << obj;
    else
      avail_arr << obj;
  }
  foreach (auto v, avail_arr) {
    arr.prepend(v);
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

void Server::broadcast(const QString &command, const QString &jsonData) {
  foreach (ServerPlayer *p, players.values()) {
    p->doNotify(command, jsonData);
  }
}

void Server::processNewConnection(ClientSocket *client) {
  auto addr = client->peerAddress();
  qInfo() << addr << "connected";
  auto result = SelectFromDatabase(
      db, QString("SELECT * FROM banip WHERE ip='%1';").arg(addr));
  if (!result.isEmpty()) {
    QJsonArray body;
    body << -2;
    body << (Router::TYPE_NOTIFICATION | Router::SRC_SERVER |
             Router::DEST_CLIENT);
    body << "ErrorMsg";
    body << "you have been banned!";
    client->send(JsonArray2Bytes(body));
    qInfo() << "Refused banned IP:" << addr;
    client->disconnectFromHost();
    return;
  }

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
      valid = (String2Json(doc[3].toString()).array().size() == 4);
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

  auto client_ver = QVersionNumber::fromString(arr[3].toString());
  auto ver = QVersionNumber::fromString(FK_VERSION);
  int cmp = QVersionNumber::compare(ver, client_ver);
  if (cmp != 0) {
    QJsonArray body;
    body << -2;
    body << (Router::TYPE_NOTIFICATION | Router::SRC_SERVER |
             Router::DEST_CLIENT);
    body << "ErrorMsg";
    body
        << (cmp < 0
                ? QString("[\"server is still on version %%2\",\"%1\"]")
                      .arg(FK_VERSION, "1")
                : QString(
                      "[\"server is using version %%2, please update\",\"%1\"]")
                      .arg(FK_VERSION, "1"));

    client->send(JsonArray2Bytes(body));
    client->disconnectFromHost();
    return;
  }

  handleNameAndPassword(client, arr[0].toString(), arr[1].toString(),
                        arr[2].toString());
}

void Server::handleNameAndPassword(ClientSocket *client, const QString &name,
                                   const QString &password,
                                   const QString &md5_str) {
  auto encryted_pw = QByteArray::fromBase64(password.toLatin1());
  unsigned char buf[4096] = {0};
  RSA_private_decrypt(RSA_size(rsa), (const unsigned char *)encryted_pw.data(),
                      buf, rsa, RSA_PKCS1_PADDING);
  auto decrypted_pw =
      QByteArray::fromRawData((const char *)buf, strlen((const char *)buf));

  if (decrypted_pw.length() > 32) {
    auto aes_bytes = decrypted_pw.first(32);

    // tell client to install aes key
    QJsonArray body;
    body << -2;
    body << (Router::TYPE_NOTIFICATION | Router::SRC_SERVER |
             Router::DEST_CLIENT);
    body << "InstallKey";
    body << "";
    client->send(JsonArray2Bytes(body));

    client->installAESKey(aes_bytes);
    decrypted_pw.remove(0, 32);
  } else {
    decrypted_pw = "\xFF";
  }

  if (md5 != md5_str) {
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

  bool passed = false;
  QString error_msg;
  QJsonArray result;
  QJsonObject obj;

  if (CheckSqlString(name) && checkBanWord(name)) {
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
      passed = obj["banned"].toString().toInt() == 0;
      if (!passed) {
        error_msg = "you have been banned!";
      } else if (!players.value(id)) {
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
          player->alive = true;
          client->disconnect(this);
          if (players.count() <= 10) {
            broadcast("ServerMessage", tr("%1 backed").arg(player->getScreenName()));
            if (room->getOwner() == player) {
              auto owner = room->getOwner();
              auto jsonData = QJsonArray();
              jsonData << owner->getId();
              player->doNotify("RoomOwner", JsonArray2Bytes(jsonData));
            }
          }

          if (room && !room->isLobby()) {
            room->pushRequest(QString("%1,reconnect").arg(id));
          } else {
            // 懒得处理掉线玩家在大厅了！踢掉得了
            player->doNotify("ErrorMsg", "Unknown Error");
            player->kicked();
          }

          return;
        } else {
          error_msg = "others logged in with this name";
          passed = false;
        }
      }
    }
  } else {
    error_msg = "invalid user name";
  }

  if (passed) {
    // update lastLoginIp
    auto sql_update =
        QString("UPDATE userinfo SET lastLoginIp='%1' WHERE id=%2;")
            .arg(client->peerAddress())
            .arg(obj["id"].toString().toInt());
    ExecSQL(db, sql_update);

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
    if (players.count() <= 10) {
      broadcast("ServerMessage", tr("%1 logged in").arg(player->getScreenName()));
    }
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
  // 按理说这时候就可以删除了，但是这里肯定比Lua先检测到。
  // 倘若在Lua的Room:gameOver时C++的Room被删除了问题就大了。
  // FIXME: 但是这终归是内存泄漏！以后啥时候再改吧。
  // room->deleteLater();
}

void Server::onUserDisconnected() {
  ServerPlayer *player = qobject_cast<ServerPlayer *>(sender());
  qInfo() << "Player" << player->getId() << "disconnected";
  if (players.count() <= 10) {
    broadcast("ServerMessage", tr("%1 logged out").arg(player->getScreenName()));
  }
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

void Server::onUserStateChanged() {
  ServerPlayer *player = qobject_cast<ServerPlayer *>(sender());
  auto room = player->getRoom();
  if (!room || room->isLobby() || room->isAbandoned()) {
    return;
  }
  room->doBroadcastNotify(room->getPlayers(), "NetStateChanged",
      QString("[%1,\"%2\"]").arg(player->getId()).arg(player->getStateString()));
}

RSA *Server::initServerRSA() {
  RSA *rsa = RSA_new();
  if (!QFile::exists("server/rsa_pub")) {
    BIGNUM *bne = BN_new();
    BN_set_word(bne, RSA_F4);
    RSA_generate_key_ex(rsa, 2048, bne, NULL);

    BIO *bp_pub = BIO_new_file("server/rsa_pub", "w+");
    PEM_write_bio_RSAPublicKey(bp_pub, rsa);
    BIO *bp_pri = BIO_new_file("server/rsa", "w+");
    PEM_write_bio_RSAPrivateKey(bp_pri, rsa, NULL, NULL, 0, NULL, NULL);

    BIO_free_all(bp_pub);
    BIO_free_all(bp_pri);
    QFile("server/rsa")
        .setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    BN_free(bne);
  }
  FILE *keyFile = fopen("server/rsa_pub", "r");
  PEM_read_RSAPublicKey(keyFile, &rsa, NULL, NULL);
  fclose(keyFile);
  keyFile = fopen("server/rsa", "r");
  PEM_read_RSAPrivateKey(keyFile, &rsa, NULL, NULL);
  fclose(keyFile);
  return rsa;
}

void Server::readConfig() {
  QFile file("freekill.server.config.json");
  if (!file.open(QIODevice::ReadOnly)) {
    return;
  }
  auto json = file.readAll();
  config = QJsonDocument::fromJson(json).object();

  // defaults
}

QJsonValue Server::getConfig(const QString &key) { return config.value(key); }

bool Server::checkBanWord(const QString &str) {
  auto arr = getConfig("banwords").toArray();
  if (arr.isEmpty()) {
    return true;
  }
  foreach (auto v, arr) {
    auto s = v.toString();
    if (str.indexOf(s) != -1) {
      return false;
    }
  }
  return true;
}
