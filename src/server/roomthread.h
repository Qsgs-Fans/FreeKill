// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _ROOMTHREAD_H
#define _ROOMTHREAD_H

#include <qsemaphore.h>
class Room;
class Server;

class RoomThread : public QThread {
  Q_OBJECT
 public:
  explicit RoomThread(Server *m_server);
  ~RoomThread();

  Server *getServer() const;
  bool isFull() const;

  QString getMd5() const;
  Room *getRoom(int id) const;
  void addRoom(Room *room);
  void removeRoom(Room *room);

  QString fetchRequest();
  void pushRequest(const QString &req);
  void clearRequest();
  bool hasRequest();

  void trySleep(int ms);
  void wakeUp();

  void tryTerminate();
  bool isTerminated() const;

  bool isConsoleStart() const;

  bool isOutdated();

 protected:
  virtual void run();

 private:
  Server *m_server;
  // QList<Room *> room_list;
  int m_capacity;
  QString md5;

  lua_State *L;
  QMutex request_queue_mutex;
  QQueue<QString> request_queue;  // json string
  QSemaphore sema_wake;
  volatile bool terminated;
};

#endif // _ROOMTHREAD_H
