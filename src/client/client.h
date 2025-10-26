// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _CLIENT_H
#define _CLIENT_H

struct ClientPrivate;

class Lua;
class Sqlite3;
class ClientPlayer;
class Router;

class Client : public QObject {
  Q_OBJECT
public:
  Client(QObject *parent = nullptr);
  ~Client();

  void connectToHost(const QString &server, ushort port);
  void sendSetupPacket(const QString &pubkey);
  void setupServerLag(qint64 server_time);
  qint64 getServerLag() const;

  Q_INVOKABLE void setLoginInfo(const QString &username, const QString &password);
  Q_INVOKABLE void replyToServer(const QString &command, const QVariant &jsonData);
  Q_INVOKABLE void notifyServer(const QString &command, const QVariant &jsonData);

  Q_INVOKABLE void callLua(const QByteArray &command, const QByteArray &jsonData, bool isRequest = false);

  ClientPlayer *addPlayer(int id, const QString &name, const QString &avatar);
  void removePlayer(int id);
  Q_INVOKABLE void clearPlayers();
  ClientPlayer *getSelf() const { return self; }
  void changeSelf(int id);

  Lua *getLua();
  Sqlite3 &database();
  QString getAESKey() const { return aes_key; }
  void installAESKey(const QByteArray &key);

  Q_INVOKABLE bool checkSqlString(const QString &s);
  Q_INVOKABLE QVariantList execSql(const QString &sql);
  Q_INVOKABLE QString peerAddress();
  Q_INVOKABLE QVariantList getMyGameData();
  void saveRecord(const QByteArray &json, const QString &fname);
  void saveGameData(const QString &mode, const QString &general, const QString &deputy,
                    const QString &role, int result, const QString &replay,
                    const QByteArray &room_data, const QByteArray &record);

  Router *getRouter() const { return router; }
signals:
  void notifyUI(const QString &command, const QVariant &jsonData);
  void error_message(const QString &msg);
  void toast_message(const QString &msg);
  void self_changed();

private:
  Router *router;
  QMap<int, ClientPlayer *> players;
  ClientPlayer *self;
  qint64 start_connent_timestamp; // 连接时的时间戳 单位毫秒
  qint64 server_lag = 0; // 与服务器时差，单位毫秒，正数表示自己快了 负数表示慢了

  // 仅在登录时使用
  QString screenName;
  QString password;
  ClientPrivate *p_ptr;
  QString aes_key;
  QByteArray pubEncrypt(const QByteArray &key, const QByteArray &data);

  Lua *L;
  std::unique_ptr<Sqlite3> db;
  QFileSystemWatcher fsWatcher;
};

extern Client *ClientInstance;

Q_DECLARE_METATYPE(Client *);

#endif // _CLIENT_H
