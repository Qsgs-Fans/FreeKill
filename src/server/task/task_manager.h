#pragma once

class Task;

class TaskManager {
public:
  explicit TaskManager();
  TaskManager(TaskManager &) = delete;
  TaskManager(TaskManager &&) = delete;

  Task &createTask(const QString &type, const QByteArray &data);
  void removeTask(int id);
  Task *getTask(int id) const;
  Task *getTaskByRequestId(int reqId) const;
  std::vector<int> getTaskIdsByUser(int connId) const;
  void removeAllTasksByUser(int connId);

  void attachTaskToUser(int taskId, int connId);
  void setTaskExpectedReplyId(int taskId, int reqId);

  void trigger(const char *event);

private:

  // id --> task
  std::unordered_map<int, std::unique_ptr<Task>> task_map;

  // reqId --> taskId
  std::unordered_map<int, int> task_request_id_map;

  // userConnId --> taskId[]
  std::unordered_map<int, std::vector<int>> task_conn_id_map;
};
