// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _ROOM_H
#define _ROOM_H

class Server;
class ServerPlayer;
class RoomThread;

class Room : public QObject {
  Q_OBJECT
 public:
  explicit Room(RoomThread *m_thread);
  ~Room();

  // Property reader & setter
  // ==================================={
  Server *getServer() const;
  RoomThread *getThread() const;
  void setThread(RoomThread *t);
  int getId() const;
  void setId(int id);
  bool isLobby() const;
  QString getName() const;
  void setName(const QString &name);
  int getCapacity() const;
  void setCapacity(int capacity);
  bool isFull() const;
  const QByteArray getSettings() const;
  void setSettings(QByteArray settings);
  bool isAbandoned() const;
  void checkAbandoned();
  void setAbandoned(bool a);

  ServerPlayer *getOwner() const;
  void setOwner(ServerPlayer *owner);

  void addPlayer(ServerPlayer *player);
  void addRobot(ServerPlayer *player);
  void removePlayer(ServerPlayer *player);
  QList<ServerPlayer *> getPlayers() const;
  QList<ServerPlayer *> getOtherPlayers(ServerPlayer *expect) const;
  ServerPlayer *findPlayer(int id) const;

  void addObserver(ServerPlayer *player);
  void removeObserver(ServerPlayer *player);
  QList<ServerPlayer *> getObservers() const;
  bool hasObserver(ServerPlayer *player) const;

  int getTimeout() const;
  void setTimeout(int timeout);

  bool isStarted() const;
  // ====================================}

  void doBroadcastNotify(const QList<ServerPlayer *> targets,
                         const QString &command, const QString &jsonData);
  void chat(ServerPlayer *sender, const QString &jsonData);

  void updateWinRate(int id, const QString &general, const QString &mode,
                     int result, bool dead);
  void gameOver();
  void manuallyStart();
  void pushRequest(const QString &req);

  void addRejectId(int id);
  void removeRejectId(int id);

  // router用
  void handlePacket(ServerPlayer *sender, const QString &command,
                    const QString &jsonData);
 signals:
  void abandoned();

  void playerAdded(ServerPlayer *player);
  void playerRemoved(ServerPlayer *player);

 private:
  Server *server;
  RoomThread *m_thread;
  int id;               // Lobby's id is 0
  QString name;         // “阴间大乱斗”
  int capacity;         // by default is 5, max is 8
  QByteArray settings;  // JSON string
  bool m_abandoned;     // If room is empty, delete it

  ServerPlayer *owner;  // who created this room?
  QList<ServerPlayer *> players;
  QList<ServerPlayer *> observers;
  QList<int> runned_players;
  QList<int> rejected_players;
  int robot_id;
  bool gameStarted;
  bool m_ready;

  int timeout;

  void addRunRate(int id, const QString &mode);
  void updatePlayerGameData(int id, const QString &mode);
};

#endif  // _ROOM_H
