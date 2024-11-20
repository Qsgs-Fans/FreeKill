// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _SERVER_H
#define _SERVER_H

class Sqlite3;
class AuthManager;
class ServerSocket;
class ClientSocket;
class ServerPlayer;
class RoomThread;
class Lobby;

#include "server/room.h"

/**
  @brief Server类负责管理游戏服务端的运行。

  该类用于服务端程序运行。当客户端使用单机启动时，Server类也会被实例化。
  Server的具体运行逻辑依托于Qt的事件循环与信号槽机制：当Server被创建后，
  调用listen方法即可完成监听，然后程序进入事件循环，通过触发Server的槽函数
  以实现各种功能。

  ### 配置信息

  ### 用户管理

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

  /**
    @brief 创建新的房间并加入到房间列表中。

    创建新的房间。

    首先，房间名是用户自定义输入内容，需要先进行内容安全检查；然后创建新房间，
    将新的room添加到rooms表中；然后将参数中指定的各个属性都赋予给新的
    房间，通过addPlayer将房主添加到房间中，并使用setOwner将其设为房主。

    @param owner 创建房间的那名玩家；房主
    @param settings 表示JSON对象的字符串，用作房间配置
    */
  void createRoom(ServerPlayer *owner, const QString &name, int capacity,
                  int timeout = 15, const QByteArray &settings = "{}");

  Room *findRoom(int id) const; /// 获取对应id的房间
  Lobby *lobby() const; /// 获取大厅对象

  RoomThread *createThread(); /// 创建新的RoomThread，并加入列表
  void removeThread(RoomThread *thread); /// 从列表中移除thread

  ServerPlayer *findPlayer(int id) const; /// 获取对应id的玩家
  void addPlayer(ServerPlayer *player); /// 将玩家加入表中，若重复则覆盖旧的
  void removePlayer(int id); /// 从表中删除对应id的玩家
  auto getPlayers() { return players; } /// 获取players表

  void updateRoomList(ServerPlayer *teller);
  void updateOnlineInfo();

  Sqlite3 *getDatabase();

  void broadcast(const QString &command, const QString &jsonData);
  void sendEarlyPacket(ClientSocket *client, const QString &type, const QString &msg);
  void setupPlayer(ServerPlayer *player, bool all_info = true);
  bool isListening;

  QJsonValue getConfig(const QString &command);
  bool checkBanWord(const QString &str);
  void temporarilyBan(int playerId);

  void beginTransaction();
  void endTransaction();

  const QString &getMd5() const;
  void refreshMd5();

signals:
  void roomCreated(Room *room);
  void playerAdded(ServerPlayer *player);
  void playerRemoved(ServerPlayer *player);

public slots:
  void processNewConnection(ClientSocket *client);
  void processRequest(const QByteArray &msg);

  void onRoomAbandoned();

private:
  friend class Shell;
  ServerSocket *server;

  Lobby *m_lobby;
  QMap<int, Room *> rooms;
  QList<RoomThread *> threads;
  int nextRoomId;
  friend Room::Room(RoomThread *m_thread);
  QHash<int, ServerPlayer *> players;
  QList<QString> temp_banlist;

  AuthManager *auth;
  Sqlite3 *db; ///< sqlite数据库连接实例
  QMutex transaction_mutex; ///< 可能有多线程同时对数据库请求，需要加锁
  QString md5; ///< 服务端当前允许用户登录的MD5值

  /**
    读取配置文件。配置文件的路径是`<pwd>/freekill.server.config.json`。

    若读取失败（包含文件不存在、有语法错误等情况），则使用一个空JSON对象；
    否则使用从文件读取并解析后的JSON对象。最后为一些必须存在而实际为空值的key设置默认值。
    */
  void readConfig();
  QJsonObject config; ///< 配置文件其实就是一个JSON对象
};

extern Server *ServerInstance; ///< 全局Server对象

#endif // _SERVER_H
