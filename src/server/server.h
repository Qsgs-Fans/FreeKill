#ifndef _SERVER_H
#define _SERVER_H

class ServerSocket;
class ClientSocket;
class ServerPlayer;

#include "room.h"

class Server : public QObject {
  Q_OBJECT

public:
  explicit Server(QObject *parent = nullptr);
  ~Server();

  bool listen(const QHostAddress &address = QHostAddress::Any, ushort port = 9527u);

  void createRoom(ServerPlayer *owner, const QString &name, int capacity);
  Room *findRoom(int id) const;
  Room *lobby() const;

  ServerPlayer *findPlayer(int id) const;
  void addPlayer(ServerPlayer *player);
  void removePlayer(int id);

  void updateRoomList();

  sqlite3 *getDatabase();

signals:
  void roomCreated(Room *room);
  void playerAdded(ServerPlayer *player);
  void playerRemoved(ServerPlayer *player);

public slots:
  void processNewConnection(ClientSocket *client);
  void processRequest(const QByteArray &msg);

  void onRoomAbandoned();
  void onUserDisconnected();
  void onUserStateChanged();

private:
  friend class Shell;
  ServerSocket *server;
  Room *m_lobby;
  QMap<int, Room *> rooms;
  QStack<Room *> idle_rooms;
  int nextRoomId;
  friend Room::Room(Server *server);
  QHash<int, ServerPlayer *> players;

  RSA *rsa;
  QString public_key;
  sqlite3 *db;
  QString md5;

  void handleNameAndPassword(ClientSocket *client, const QString &name, const QString &password);
};

extern Server *ServerInstance;

#endif // _SERVER_H
