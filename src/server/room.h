// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _ROOM_H
#define _ROOM_H

#include "server/roombase.h"

class Server;
class ServerPlayer;
class RoomThread;

/**
  @brief Server类负责管理游戏服务端的运行。

  该类负责表示游戏房间，与大厅进行交互以调整玩家
*/
class Room : public RoomBase {
  Q_OBJECT
 public:
  explicit Room(RoomThread *m_thread);
  ~Room();

  // Property reader & setter
  // ==================================={
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

  void updatePlayerWinRate(int id, const QString &mode, const QString &role, int result);
  void updateGeneralWinRate(const QString &general, const QString &mode, const QString &role, int result);

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

  // Lua专用
  int getRefCount();
  void increaseRefCount();
  void decreaseRefCount();

 signals:
  void abandoned();

  void playerAdded(ServerPlayer *player);
  void playerRemoved(ServerPlayer *player);

 private:
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

  int lua_ref_count = 0; ///< Lua引用计数，当Room为abandon时，只要lua中还有计数，就不可删除
  QMutex lua_ref_mutex;

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
