// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _CLIENT_H
#define _CLIENT_H

#include "network/router.h"
#include "client/clientplayer.h"

class Lua;

#ifndef FK_SERVER_ONLY
#include "ui/qmlbackend.h"
#endif

class Client : public QObject {
  Q_OBJECT
public:
  Client(QObject *parent = nullptr);
  ~Client();

  void connectToHost(const QString &server, ushort port);
  void setupServerLag(qint64 server_time);
  qint64 getServerLag() const;

  Q_INVOKABLE void replyToServer(const QString &command, const QString &jsonData);
  Q_INVOKABLE void notifyServer(const QString &command, const QString &jsonData);

  Q_INVOKABLE void callLua(const QString &command, const QString &jsonData, bool isRequest = false);

  ClientPlayer *addPlayer(int id, const QString &name, const QString &avatar);
  void removePlayer(int id);
  Q_INVOKABLE void clearPlayers();
  void changeSelf(int id);

  Lua *getLua();
  void installAESKey(const QByteArray &key);

  void saveRecord(const QString &json, const QString &fname);

  bool isConsoleStart() const;
  void startWatchFiles();

  Router *getRouter() const { return router; }
signals:
  void notifyUI(const QString &command, const QVariant &jsonData);
  void error_message(const QString &msg);

public slots:
  void processReplay(const QString &, const QString &);

private slots:
  void updateLuaFiles(const QString &path);

private:
  Router *router;
  QMap<int, ClientPlayer *> players;
  ClientPlayer *self;
  qint64 start_connent_timestamp; // 连接时的时间戳 单位毫秒
  qint64 server_lag = 0; // 与服务器时差，单位毫秒，正数表示自己快了 负数表示慢了

  // 仅在登录时使用
  QString screenName;
  QString password;

  Lua *L;
  QFileSystemWatcher fsWatcher;
};

extern Client *ClientInstance;

Q_DECLARE_METATYPE(Client *);

#endif // _CLIENT_H
