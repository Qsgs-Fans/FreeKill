// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _SERVER_H
#define _SERVER_H

class AuthManager;
class ServerSocket;
class ClientSocket;
class ServerPlayer;
class RoomThread;
class Lobby;

#include "server/room.h"

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
  Lobby *lobby() const;

  RoomThread *createThread();
  void removeThread(RoomThread *thread);

  ServerPlayer *findPlayer(int id) const;
  void addPlayer(ServerPlayer *player);
  void removePlayer(int id);
  auto getPlayers() { return players; }

  void updateRoomList(ServerPlayer *teller);
  void updateOnlineInfo();

  sqlite3 *getDatabase();

  void broadcast(const QString &command, const QString &jsonData);
  void sendEarlyPacket(ClientSocket *client, const QString &type, const QString &msg);
  void setupPlayer(ServerPlayer *player, bool all_info = true);
  bool isListening;

  QJsonValue getConfig(const QString &command);
  bool checkBanWord(const QString &str);
  void temporarilyBan(int playerId);

  void beginTransaction();
  void endTransaction();

  const QString &getMd5() const;
  void refreshMd5();

signals:
  void roomCreated(Room *room);
  void playerAdded(ServerPlayer *player);
  void playerRemoved(ServerPlayer *player);

public slots:
  void processNewConnection(ClientSocket *client);
  void processRequest(const QByteArray &msg);

  void onRoomAbandoned();

private:
  friend class Shell;
  ServerSocket *server;

  Lobby *m_lobby;
  QMap<int, Room *> rooms;
  QStack<Room *> idle_rooms;
  QList<RoomThread *> threads;
  int nextRoomId;
  friend Room::Room(RoomThread *m_thread);
  QHash<int, ServerPlayer *> players;
  QList<QString> temp_banlist;

  AuthManager *auth;
  sqlite3 *db;
  QMutex transaction_mutex;
  QString md5;

  QJsonObject config;
  void readConfig();
};

extern Server *ServerInstance;

#endif // _SERVER_H
