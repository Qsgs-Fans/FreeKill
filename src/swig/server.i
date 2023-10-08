// SPDX-License-Identifier: GPL-3.0-or-later

%nodefaultctor Room;
%nodefaultdtor Room;
class Room : public QObject {
public:
  // Property reader & setter
  // ==================================={
  int getId() const;

  QList<ServerPlayer *> getPlayers() const;
  ServerPlayer *getOwner() const;

  QList<ServerPlayer *> getObservers() const;
  bool hasObserver(ServerPlayer *player) const;
  int getTimeout() const;
  void checkAbandoned();

  void updateWinRate(int id, const QString &general, const QString &mode,
                     int result, bool dead);
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
  bool isTerminated() const;
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
  void doRequest(const QString &command,
           const QString &json_data, int timeout);
  QString waitForReply(int timeout);
  void doNotify(const QString &command, const QString &json_data);

  bool busy() const;
  void setBusy(bool busy);

  bool thinking();
  void setThinking(bool t);
};

%extend ServerPlayer {
  void emitKick() {
    emit $self->kicked();
  }
}
