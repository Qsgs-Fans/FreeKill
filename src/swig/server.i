// SPDX-License-Identifier: GPL-3.0-or-later

%nodefaultctor Server;
%nodefaultdtor Server;
class Server : public QObject {
public:
  Room *lobby() const;
  void createRoom(ServerPlayer *owner, const QString &name, int capacity);
  Room *findRoom(int id) const;
  ServerPlayer *findPlayer(int id) const;

  sqlite3 *getDatabase();
};

extern Server *ServerInstance;

%nodefaultctor Room;
%nodefaultdtor Room;
class Room : public QObject {
public:
  // Property reader & setter
  // ==================================={
  Server *getServer() const;
  int getId() const;
  bool isLobby() const;
  QString getName() const;
  void setName(const QString &name);
  int getCapacity() const;
  void setCapacity(int capacity);
  bool isFull() const;
  bool isAbandoned() const;
  bool isReady() const;

  ServerPlayer *getOwner() const;
  void setOwner(ServerPlayer *owner);

  void addPlayer(ServerPlayer *player);
  void addRobot(ServerPlayer *player);
  void removePlayer(ServerPlayer *player);
  QList<ServerPlayer *> getPlayers() const;
  ServerPlayer *findPlayer(int id) const;

  QList<ServerPlayer *> getObservers() const;
  int getTimeout() const;

  bool isStarted() const;
  // ====================================}

  void doBroadcastNotify(
    const QList<ServerPlayer *> targets,
    const QString &command,
    const QString &jsonData
  );

  void updateWinRate(int id, const QString &general, const QString &mode,
                     int result);
  void gameOver();
};

%extend Room {
  QString settings() {
    return $self->getSettings();
  }
}

%nodefaultctor RoomThread;
%nodefaultdtor RoomThread;
class RoomThread : public QThread {
public:
  Room *getRoom(int id);

  QString fetchRequest();
  void clearRequest();
  bool hasRequest();

  void trySleep(int ms);
};

%{
void RoomThread::run()
{
  lua_getglobal(L, "debug");
  lua_getfield(L, -1, "traceback");
  lua_replace(L, -2);
  lua_getglobal(L, "InitScheduler");
  SWIG_NewPointerObj(L, this, SWIGTYPE_p_RoomThread, 0);
  int error = lua_pcall(L, 1, 0, -2);
  lua_pop(L, 1);
  if (error) {
    const char *error_msg = lua_tostring(L, -1);
    qCritical() << error_msg;
  }
}
%}

%nodefaultctor ServerPlayer;
%nodefaultdtor ServerPlayer;
class ServerPlayer : public Player {
public:
  Server *getServer() const;
  Room *getRoom() const;
  void setRoom(Room *room);

  void speak(const QString &message);

  void doRequest(const QString &command,
           const QString &json_data, int timeout);
  QString waitForReply(int timeout);
  void doNotify(const QString &command, const QString &json_data);

  void prepareForRequest(const QString &command, const QString &data);

  bool busy() const;
  void setBusy(bool busy);

  bool thinking() const;
  void setThinking(bool t);
};
