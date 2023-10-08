// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _SERVER_H
#define _SERVER_H

#include <openssl/rsa.h>
#include <openssl/pem.h>

#include <qjsonobject.h>
#include <qjsonvalue.h>
class ServerSocket;
class ClientSocket;
class ServerPlayer;
class RoomThread;

#include "room.h"

class Server : public QObject {
  Q_OBJECT

public:
  explicit Server(QObject *parent = nullptr);
  ~Server();

  bool listen(const QHostAddress &address = QHostAddress::Any,
              ushort port = 9527u);

  void createRoom(ServerPlayer *owner, const QString &name, int capacity,
                  int timeout = 15, const QByteArray &settings = "{}");

  Room *findRoom(int id) const;
  Room *lobby() const;

  ServerPlayer *findPlayer(int id) const;
  void addPlayer(ServerPlayer *player);
  void removePlayer(int id);

  void updateRoomList(ServerPlayer *teller);
  void updateOnlineInfo();

  sqlite3 *getDatabase();

  void broadcast(const QString &command, const QString &jsonData);
  bool isListening;

  QJsonValue getConfig(const QString &command);
  bool checkBanWord(const QString &str);
  void temporarilyBan(int playerId);

  void beginTransaction();
  void endTransaction();

signals:
  void roomCreated(Room *room);
  void playerAdded(ServerPlayer *player);
  void playerRemoved(ServerPlayer *player);

public slots:
  void processNewConnection(ClientSocket *client);
  void processRequest(const QByteArray &msg);
  void readPendingDatagrams();

  void onRoomAbandoned();
  void onUserDisconnected();
  void onUserStateChanged();

private:
  friend class Shell;
  ServerSocket *server;
  QUdpSocket *udpSocket;

  Room *m_lobby;
  QMap<int, Room *> rooms;
  QStack<Room *> idle_rooms;
  QList<RoomThread *> threads;
  int nextRoomId;
  friend Room::Room(RoomThread *m_thread);
  QHash<int, ServerPlayer *> players;
  QList<QString> temp_banlist;

  RSA *rsa;
  QString public_key;
  sqlite3 *db;
  QMutex transaction_mutex;
  QString md5;

  static RSA *initServerRSA();

  QJsonObject config;
  void readConfig();

  void handleNameAndPassword(ClientSocket *client, const QString &name,
                             const QString &password, const QString &md5_str, const QString &uuid_str);
  void processDatagram(const QByteArray &msg, const QHostAddress &addr, uint port);
};

extern Server *ServerInstance;

#endif // _SERVER_H
