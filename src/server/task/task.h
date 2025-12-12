#pragma once

class RoomThread;

class Task {
public:
  Task(const QString &type, const QByteArray &data);
  Task(const Task&) = delete;
  Task(Task&&) = delete;
  ~Task();

  int getId() const;
  int getUserConnId() const;
  void setUserConnId(int connId);
  int getExpectedReplyId() const;
  void setExpectedReplyId(int id);

  QString getTaskType() const;
  QByteArray getData() const;

  // 启动并执行
  void start();
  // 继续执行 对应coro.resume
  void resume(const QString &reason);
  // 中途关闭，对应coro.close
  void abort();

  void delay(int ms);
  void saveGlobalState(const QString &key, const QString &jsonData);
  QString getGlobalSaveState(const QString &key);

  int getRefCount();
  void increaseRefCount();
  void decreaseRefCount();

private:
  int id; // 负数
  int userConnId = 0; // 关联的用户，0表示无
  int expectedReplyId = 0; // 正在等待的requestId

  QString taskType;
  QByteArray data = "\xF6"; // 必须是CBOR，默认null

  // 很遗憾，负责执行Lua代码的那个类命名成这样了 导致在这里有点违和
  RoomThread *m_thread;

  int lua_ref_count = 0;
  QMutex lua_ref_mutex;
};
