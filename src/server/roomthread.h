// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _ROOMTHREAD_H
#define _ROOMTHREAD_H

class Room;
class Server;
class Scheduler;

class RoomThread : public QThread {
  Q_OBJECT
 public:
  explicit RoomThread(Server *m_server);
  ~RoomThread();

  Server *getServer() const;
  bool isFull() const;

  int getCapacity() const { return m_capacity; }
  Scheduler *getScheduler() const { return m_scheduler; }
  QString getMd5() const;
  Room *getRoom(int id) const;
  void addRoom(Room *room);
  void removeRoom(Room *room);

  bool isConsoleStart() const;

  bool isOutdated();

 signals:
  void scheduler_ready(); // 测试专用
  void pushRequest(const QString &req);
  void delay(int roomId, int ms);
  void wakeUp(int roomId, const char *);

 protected:
  virtual void run();

 private:
  Server *m_server;
  int m_capacity;
  QString md5;

  Scheduler *m_scheduler;
};

Q_DECLARE_METATYPE(RoomThread *)

#endif // _ROOMTHREAD_H
