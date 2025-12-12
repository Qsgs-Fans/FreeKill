#include "server/task/task_manager.h"
#include "server/task/task.h"
// #include "server/server.h"
// #include "server/gamelogic/roomthread.h"

TaskManager::TaskManager() {}

Task &TaskManager::createTask(const QString &type, const QByteArray &data) {
  auto task = std::make_unique<Task>(type, data);
  auto id = task->getId();
  task_map[id] = std::move(task);
  return *task_map[id];
}

void TaskManager::removeTask(int id) {
  auto it = task_map.find(id);
  if (it == task_map.end())
    return;

  auto &task = it->second;

  if (task->getExpectedReplyId() > 0)
    task_request_id_map.erase(task->getExpectedReplyId());

  if (task->getUserConnId() > 0) {
    auto &vec = task_conn_id_map[task->getUserConnId()];
    vec.erase(std::remove(vec.begin(), vec.end(), id), vec.end());
    if (vec.empty())
      task_conn_id_map.erase(task->getUserConnId());
  }

  task_map.erase(it);
}

Task *TaskManager::getTask(int id) const {
  auto it = task_map.find(id);
  return it == task_map.end() ? nullptr : it->second.get();
}

Task *TaskManager::getTaskByRequestId(int reqId) const {
  auto it = task_request_id_map.find(reqId);
  if (it == task_request_id_map.end())
    return nullptr;

  return getTask(it->second);
}

std::vector<int> TaskManager::getTaskIdsByUser(int connId) const {
  auto it = task_conn_id_map.find(connId);
  if (it == task_conn_id_map.end())
    return {};

  return it->second;
}

void TaskManager::removeAllTasksByUser(int connId) {
  auto it = task_conn_id_map.find(connId);
  if (it == task_conn_id_map.end())
    return;

  // 拷贝一份，因为 removeTask() 会修改 task_conn_id_map
  std::vector<int> tasks = it->second;

  for (int taskId : tasks) removeTask(taskId);
}

void TaskManager::attachTaskToUser(int taskId, int connId) {
  if (connId <= 0) return;
  Task* task = getTask(taskId);
  if (!task)
    return;

  int oldConn = task->getUserConnId();

  if (oldConn > 0) {
    qWarning("cannot attach task to different user");
    return;
  }

  task->setUserConnId(connId);

  auto& vec = task_conn_id_map[connId];
  if (std::find(vec.begin(), vec.end(), taskId) == vec.end())
    vec.push_back(taskId);
}

void TaskManager::setTaskExpectedReplyId(int taskId, int reqId) {
  Task* task = getTask(taskId);
  if (!task)
    return;

  int oldReq = task->getExpectedReplyId();

  if (oldReq > 0)
    task_request_id_map.erase(oldReq);

  task->setExpectedReplyId(reqId);

  if (reqId == 0)
    return;

  task_request_id_map[reqId] = taskId;
}

// void TaskManager::trigger(const char *event) {
//   auto thread = ServerInstance->getAvailableThread();
//   emit thread->triggerTask(event);
// }
