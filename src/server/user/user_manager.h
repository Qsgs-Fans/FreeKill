#pragma once

class ServerPlayer;
class AuthManager;

class UserManager {
public:
  explicit UserManager();
  UserManager(UserManager &) = delete;
  ~UserManager();

  /// 获取对应connId的玩家
  auto &getPlayer(const QString &connId) const;
  /// 获取对应id的玩家
  auto &getPlayerById(int id) const;

  /// 将玩家加入表中
  void addPlayer(std::shared_ptr<ServerPlayer> player);
  /// 从表中删除对应connid的玩家
  void removePlayer(const QString &connid);
  /// 从表中删除对应id的玩家
  void removePlayerById(int id);
  /// 获取players表
  std::unordered_map<int, std::shared_ptr<ServerPlayer>> getPlayers();

private:
  // 此表保存所有连接到服务器的玩家，包括机器人
  std::unordered_map<QString, std::shared_ptr<ServerPlayer>> playerConnIdMap;
  // 此表也保存所有玩家，但是不包括逃跑状态的玩家
  // 因为逃跑会导致服务器创建新ServerPlayer对象放入大厅，导致id重复
  std::unordered_map<int, std::shared_ptr<ServerPlayer>> playerIdMap;

  std::vector<QString> temp_banlist; ///< 被tempban的ip列表
  std::unique_ptr<AuthManager> auth;
};
