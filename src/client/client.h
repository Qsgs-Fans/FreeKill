// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _CLIENT_H
#define _CLIENT_H

#include "network/router.h"
#include "client/clientplayer.h"

#ifndef FK_SERVER_ONLY
#include "ui/qmlbackend.h"
#endif

class Client : public QObject {
  Q_OBJECT
public:
  Client(QObject *parent = nullptr);
  ~Client();

  void connectToHost(const QString &server, ushort port);

  Q_INVOKABLE void replyToServer(const QString &command, const QString &jsonData);
  Q_INVOKABLE void notifyServer(const QString &command, const QString &jsonData);

  Q_INVOKABLE void callLua(const QString &command, const QString &jsonData, bool isRequest = false);
  LuaFunction callback;

  ClientPlayer *addPlayer(int id, const QString &name, const QString &avatar);
  void removePlayer(int id);
  Q_INVOKABLE void clearPlayers();
  void changeSelf(int id);

  lua_State *getLuaState();
  void installAESKey(const QByteArray &key);

  void saveRecord(const QString &json, const QString &fname);

  bool isConsoleStart() const;
  void startWatchFiles();
signals:
  void error_message(const QString &msg);

public slots:
  void processReplay(const QString &, const QString &);

private slots:
  void updateLuaFiles(const QString &path);

private:
  Router *router;
  QMap<int, ClientPlayer *> players;
  ClientPlayer *self;

  lua_State *L;
  QFileSystemWatcher fsWatcher;
};

extern Client *ClientInstance;

#endif // _CLIENT_H
