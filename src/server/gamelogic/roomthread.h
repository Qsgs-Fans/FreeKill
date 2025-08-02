// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _ROOMTHREAD_H
#define _ROOMTHREAD_H

class LuaInterface;
class Room;
class Server;
class ServerPlayer;
class RoomThread;

class Scheduler : public QObject {
  Q_OBJECT
 public:
  explicit Scheduler(RoomThread *m_thread);
  ~Scheduler();

  auto getLua() const { return L; }

 public slots:
  void handleRequest(const QString &req);
  void doDelay(int roomId, int ms);
  bool resumeRoom(int roomId, const char *reason);

  // 只在rpc模式下有效果
  void setPlayerState(const QString &, int roomId);
  void addObserver(const QString &, int roomId);
  void removeObserver(const QString &, int roomId);

 private:
  LuaInterface *L;
};

/**
  @brief RoomThread用来调度多个房间，运行游戏逻辑。

  RoomThread作为新线程运行，线程中运行着事件循环，通过事件机制（信号槽）
  完成对多个房间的调度；在调度房间的过程中，会通过Lua运行实际游戏逻辑。
*/
class RoomThread : public QThread {
  Q_OBJECT
 public:
  explicit RoomThread(Server *m_server);
  ~RoomThread();

  Server *getServer() const;
  bool isFull() const;

  int getCapacity() const { return m_capacity; }
  QString getMd5() const;
  Room *getRoom(int id) const;

  bool isConsoleStart() const;

  bool isOutdated();

  LuaInterface *getLua() const;

 signals:
  void scheduler_ready();
  void pushRequest(const QString &req);
  void delay(int roomId, int ms);
  void wakeUp(int roomId, const char *);

  // 只在rpc模式下有效果
  void setPlayerState(const QString &, int roomId);
  void addObserver(const QString &, int roomId);
  void removeObserver(const QString &, int roomId);

 public slots:
  void onRoomAbandoned();

 protected:
  virtual void run();

 private:
  Server *m_server;
  // Rooms用findChildren<Room *>拿
  int m_capacity;
  QString md5;

  Scheduler *m_scheduler;
};

Q_DECLARE_METATYPE(RoomThread *)

#endif // _ROOMTHREAD_H
