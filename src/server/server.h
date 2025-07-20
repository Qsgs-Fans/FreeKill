// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

class Sqlite3;
class ServerSocket;
class ClientSocket;
class ServerPlayer;

class UserManager;
class RoomManager;
class RoomThreadManager;

#include "server/room/room.h"

/**
  @brief Server类负责管理游戏服务端的运行。

  该类用于服务端程序运行。当客户端使用单机启动时，Server类也会被实例化。
  Server的具体运行逻辑依托于Qt的事件循环与信号槽机制：当Server被创建后，
  调用listen方法即可完成监听，然后程序进入事件循环，通过触发Server的槽函数
  以实现各种功能。

  ### 配置信息

  ### 用户管理

  ### 内存管理

  在服务器监听的过程中，会有如下三种对象被动态创建：

  - ServerPlayer对象：当用户登录成功后创建
  - Room对象：当创建房间时创建
  - RoomThread对象：当Room创建后，必须为其指派RoomThread，若无则创建

  Room对象与相关RoomThread直接绑定，因此其内存交给RoomThread管理；而ServerPlayer
  自由度更高，可能出现在不同的Room中，需要Server进行管理。不过人机由相关Room管理。
 */
class Server : public QObject {
  Q_OBJECT

public:
  /// 构造Server对象。见于main函数
  explicit Server(QObject *parent = nullptr);
  ~Server();

  /// 监听端口
  bool listen(const QHostAddress &address = QHostAddress::Any,
              ushort port = 9527u);

  void updateRoomList(ServerPlayer *teller);
  void updateOnlineInfo();

  auto &getUserManager() const { return user_manager; }
  auto &getRoomManager() const { return room_manager; }
  auto &getThreadManager() const { return thread_manager; }
  auto &getDatabase() const { return db; }

  void broadcast(const QByteArray &command, const QByteArray &jsonData);
  void sendEarlyPacket(ClientSocket *client, const QByteArray &type, const QByteArray &msg);
  void createNewPlayer(ClientSocket *client, const QString &name, const QString &avatar, int id, const QString &uuid_str);
  void setupPlayer(ServerPlayer *player, bool all_info = true);
  bool isListening;

  QJsonValue getConfig(const QString &command);
  bool checkBanWord(const QString &str);
  void temporarilyBan(int playerId);

  void beginTransaction();
  void endTransaction();

  const QString &getMd5() const;
  void refreshMd5();

  qint64 getUptime() const;

  bool nameIsInWhiteList(const QString &name) const;

  void enableRpc() { useRpc = true; }
  bool isRpcEnabled() const { return useRpc; }

signals:
  void roomCreated(Room *room);
  void playerAdded(ServerPlayer *player);
  void playerRemoved(ServerPlayer *player);

public slots:
  void processNewConnection(ClientSocket *client);

private:
  std::unique_ptr<UserManager> user_manager;
  std::unique_ptr<RoomManager> room_manager;
  std::unique_ptr<RoomThreadManager> thread_manager;

  std::unique_ptr<Sqlite3> db; ///< sqlite数据库连接实例

  friend class Shell;
  ServerSocket *server;

  QMutex transaction_mutex; ///< 可能有多线程同时对数据库请求，需要加锁
  QString md5; ///< 服务端当前允许用户登录的MD5值

  QElapsedTimer uptime_counter;

  /**
    读取配置文件。配置文件的路径是`<pwd>/freekill.server.config.json`。

    若读取失败（包含文件不存在、有语法错误等情况），则使用一个空JSON对象；
    否则使用从文件读取并解析后的JSON对象。最后为一些必须存在而实际为空值的key设置默认值。
    */
  void readConfig();
  QJsonObject config; ///< 配置文件其实就是一个JSON对象

  bool hasWhitelist = false;
  QVariantList whitelist;

  bool useRpc = false;
};

extern Server *ServerInstance; ///< 全局Server对象
