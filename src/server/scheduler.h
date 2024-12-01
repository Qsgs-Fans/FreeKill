// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _SCHEDULER_H
#define _SCHEDULER_H

class RoomThread;
class Lua;

/**
  用于在RoomThread线程中被创建，这样信号槽才能跨线程

  详见RoomThread文档
*/
class Scheduler : public QObject {
  Q_OBJECT
 public:
  explicit Scheduler(RoomThread *m_thread);
  ~Scheduler();

 public slots:
  void handleRequest(const QString &req);
  void doDelay(int roomId, int ms);
  bool resumeRoom(int roomId, const char *reason);

 private:
  Lua *L;
};

#endif // _ROOMTHREAD_H
