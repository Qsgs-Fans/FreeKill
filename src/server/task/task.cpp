#include "server/task/task.h"
#include "server/task/task_manager.h"
#include "server/server.h"
#include "server/gamelogic/roomthread.h"

Task::Task(const QString &type, const QByteArray &data)
    : taskType { type }, data { data }, m_thread { ServerInstance->getAvailableThread() }
{
  static int nextId = -1000;
  id = nextId--;
  if (nextId < -10000000)
    nextId = -1000;

  m_thread->increaseRefCount();
}

Task::~Task() {
  abort();
  m_thread->decreaseRefCount();
}

int Task::getId() const {
  return id;
}

int Task::getUserConnId() const {
  return userConnId;
}

void Task::setUserConnId(int uid) {
  userConnId = uid;
}

int Task::getExpectedReplyId() const {
  return expectedReplyId;
}

void Task::setExpectedReplyId(int rid) {
  expectedReplyId = rid;
}

QString Task::getTaskType() const {
  return taskType;
}

QByteArray Task::getData() const {
  return data;
}

void Task::start() {
  m_thread->pushRequest(QString("-1,%1,newtask").arg(QString::number(id)));
  increaseRefCount();
}

void Task::resume(const QString &reason) {
  m_thread->wakeUp(id, reason.toUtf8());
}

void Task::abort() {
  m_thread->wakeUp(id, "abort");
}

void Task::delay(int ms) {
  m_thread->delay(id, ms);
}

int Task::getRefCount() {
  QMutexLocker locker(&lua_ref_mutex);
  return lua_ref_count;
}

void Task::increaseRefCount() {
  QMutexLocker locker(&lua_ref_mutex);
  lua_ref_count++;
}

void Task::decreaseRefCount() {
  {
    QMutexLocker locker(&lua_ref_mutex);
    lua_ref_count--;
  }

  if (lua_ref_count == 0) {
    // 主线程执行
    QMetaObject::invokeMethod(ServerInstance, [id = this->id] {
      auto &tm = ServerInstance->task_manager();
      tm.removeTask(id);
    });
  }
}
