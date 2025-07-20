#pragma once

class Lobby;
class Room;

class ServerPlayer;

class RoomManager {
public:
  explicit RoomManager();
  RoomManager(RoomManager &) = delete;

  /**
    @brief 创建新的房间并加入到房间列表中。

    创建新的房间。

    首先，房间名是用户自定义输入内容，需要先进行内容安全检查；然后创建新房间，
    将新的room添加到rooms表中；然后将参数中指定的各个属性都赋予给新的
    房间，通过addPlayer将房主添加到房间中，并使用setOwner将其设为房主。

    @param owner 创建房间的那名玩家；房主
    @param settings 表示JSON对象的字符串，用作房间配置
    */
  void createRoom(std::shared_ptr<ServerPlayer> owner, const QString &name, int capacity,
                  int timeout = 15, const QByteArray &settings = QByteArrayLiteral("{}"));

  void removeRoom(int id); /// 单纯从表中删除指针 内存由对应thread管理

  auto &getRoom(int id) const { return m_rooms.at(id); }
  auto &lobby() const { return m_lobby; }

  int getRoomId();

private:
  std::unique_ptr<Lobby> m_lobby;
  std::unordered_map<int, std::unique_ptr<Room>> m_rooms; ///< 所有的Room
  int nextRoomId = 1;
};
