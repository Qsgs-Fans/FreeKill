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
  void delay(int ms);

  void updatePlayerWinRate(int id, const QString &mode, const QString &role, int result);
  void updateGeneralWinRate(const QString &general, const QString &mode, const QString &role, int result);
  void gameOver();
  void setRequestTimer(int ms);
  void destroyRequestTimer();

  void increaseRefCount();
  void decreaseRefCount();
};

%extend Room {
  QByteArray settings() {
    return $self->getSettings();
  }
}

%nodefaultctor RoomThread;
%nodefaultdtor RoomThread;
class RoomThread : public QThread {
public:
  Room *getRoom(int id);

  // QString fetchRequest();
  // void clearRequest();
  // bool hasRequest();

  // void trySleep(int ms);
  // bool isTerminated() const;

  bool isConsoleStart() const;
  bool isOutdated();
};

%nodefaultctor ServerPlayer;
%nodefaultdtor ServerPlayer;
class ServerPlayer : public Player {
public:
  void doRequest(const QByteArray &command,
           const QByteArray &json_data, int timeout, long long timestamp = -1);
  QString waitForReply(int timeout);
  void doNotify(const QByteArray &command, const QByteArray &json_data);

  bool thinking();
  void setThinking(bool t);
};

%extend ServerPlayer {
  void emitKick() {
    emit $self->kicked();
  }
}
