#ifndef _ROOM_H
#define _ROOM_H

class Server;
class ServerPlayer;

class Room : public QThread {
  Q_OBJECT
public:
  explicit Room(Server *m_server);
  ~Room();

  // Property reader & setter
  // ==================================={
  Server *getServer() const;
  int getId() const;
  void setId(int id);
  bool isLobby() const;
  QString getName() const;
  void setName(const QString &name);
  int getCapacity() const;
  void setCapacity(int capacity);
  bool isFull() const;
  const QByteArray getSettings() const;
  void setSettings(QByteArray settings);
  bool isAbandoned() const;
  void setAbandoned(bool abandoned);  // never use this function

  ServerPlayer *getOwner() const;
  void setOwner(ServerPlayer *owner);

  void addPlayer(ServerPlayer *player);
  void addRobot(ServerPlayer *player);
  void removePlayer(ServerPlayer *player);
  QList<ServerPlayer*> getPlayers() const;
  QList<ServerPlayer *> getOtherPlayers(ServerPlayer *expect) const;
  ServerPlayer *findPlayer(int id) const;

  void addObserver(ServerPlayer *player);
  void removeObserver(ServerPlayer *player);
  QList<ServerPlayer*> getObservers() const;

  int getTimeout() const;
  void setTimeout(int timeout);

  bool isStarted() const;
  // ====================================}

  void doBroadcastNotify(
    const QList<ServerPlayer *> targets,
    const QString &command,
    const QString &jsonData
  );
  void chat(ServerPlayer *sender, const QString &jsonData);

  void gameOver();

  void initLua();

  void roomStart();
  LuaFunction startGame;

  QString fetchRequest();
  void pushRequest(const QString &req);
  bool hasRequest() const;

signals:
  void abandoned();

  void playerAdded(ServerPlayer *player);
  void playerRemoved(ServerPlayer *player);

protected:
  virtual void run();

private:
  Server *server;
  int id;     // Lobby's id is 0
  QString name;   // “阴间大乱斗”
  int capacity;   // by default is 5, max is 8
  QByteArray settings;   // JSON string
  bool m_abandoned;   // If room is empty, delete it

  ServerPlayer *owner;  // who created this room?
  QList<ServerPlayer *> players;
  QList<ServerPlayer *> observers;
  QList<int> runned_players;
  int robot_id;
  bool gameStarted;

  int timeout;

  lua_State *L;
  QMutex request_queue_mutex;
  QQueue<QString> request_queue;  // json string
};

#endif // _ROOM_H
