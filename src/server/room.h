// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _ROOM_H
#define _ROOM_H

#include "server/roombase.h"

class Server;
class ServerPlayer;
class RoomThread;

class Room : public RoomBase {
  Q_OBJECT
 public:
  explicit Room(RoomThread *m_thread);
  ~Room();

  // Property reader & setter
  // ==================================={
  RoomThread *getThread() const;
  void setThread(RoomThread *t);

  int getId() const;
  void setId(int id);
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

  void addObserver(ServerPlayer *player);
  void removeObserver(ServerPlayer *player);
  QList<ServerPlayer *> getObservers() const;
  bool hasObserver(ServerPlayer *player) const;

  int getTimeout() const;
  void setTimeout(int timeout);
  void delay(int ms);

  bool isOutdated();

  bool isStarted() const;
  // ====================================}

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

  void setRequestTimer(int ms);
  void destroyRequestTimer();

  // FIXME
  volatile bool insideGameOver = false;

 signals:
  void abandoned();

  void playerAdded(ServerPlayer *player);
  void playerRemoved(ServerPlayer *player);

 private:
  RoomThread *m_thread = nullptr;
  int id;               // Lobby's id is 0
  QString name;         // “阴间大乱斗”
  int capacity;         // by default is 5, max is 8
  QByteArray settings;  // JSON string
  bool m_abandoned;     // If room is empty, delete it

  ServerPlayer *owner;  // who created this room?
  QList<int> runned_players;
  QList<int> rejected_players;
  int robot_id;
  bool gameStarted;
  bool m_ready;

  int timeout;
  QString md5;

  QTimer *request_timer = nullptr;

  void addRunRate(int id, const QString &mode);
  void updatePlayerGameData(int id, const QString &mode);

  // handle packet
  void quitRoom(ServerPlayer *, const QString &);
  void addRobotRequest(ServerPlayer *, const QString &);
  void kickPlayer(ServerPlayer *, const QString &);
  void ready(ServerPlayer *, const QString &);
  void startGame(ServerPlayer *, const QString &);
};

#endif  // _ROOM_H
