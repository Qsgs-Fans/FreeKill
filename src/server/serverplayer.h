// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _SERVERPLAYER_H
#define _SERVERPLAYER_H

#include "core/player.h"

class ClientSocket;
class Router;
class Server;
class Room;
class RoomBase;

class ServerPlayer : public Player {
  Q_OBJECT
public:
  explicit ServerPlayer(RoomBase *room);
  ~ServerPlayer();

  void setSocket(ClientSocket *socket);
  void removeSocket();  // For the running players
  ClientSocket *getSocket() const;

  Server *getServer() const;
  RoomBase *getRoom() const;
  void setRoom(RoomBase *room);

  void speak(const QString &message);

  void doRequest(const QString &command,
           const QString &jsonData, int timeout = -1);
  void abortRequest();
  QString waitForReply(int timeout);
  void doNotify(const QString &command, const QString &jsonData);

  void prepareForRequest(const QString &command,
                        const QString &data);

  volatile bool alive; // For heartbeat
  void kick();
  void reconnect(ClientSocket *socket);

  bool busy() const { return m_busy; }
  void setBusy(bool busy) { m_busy = busy; }

  bool thinking();
  void setThinking(bool t);

  void startGameTimer();
  void pauseGameTimer();
  void resumeGameTimer();
  int getGameTime();

signals:
  void kicked();

public slots:
  void onStateChanged();
  void onDisconnected();

private:
  ClientSocket *socket;   // socket for communicating with client
  Router *router;
  Server *server;
  RoomBase *room;       // Room that player is in, maybe lobby
  bool m_busy; // (Lua专用) 是否有doRequest没处理完？见于神貂蝉这种一控多的
  bool m_thinking; // 是否在烧条？
  QMutex m_thinking_mutex; // 注意setBusy只在Lua使用，所以不需要锁。

  QString requestCommand;
  QString requestData;

  int gameTime; // 在这个房间的有效游戏时长(秒)
  QElapsedTimer gameTimer;
};

#endif // _SERVERPLAYER_H
