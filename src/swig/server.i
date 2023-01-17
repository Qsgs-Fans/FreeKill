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
class Room : public QThread {
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

  ServerPlayer *getOwner() const;
  void setOwner(ServerPlayer *owner);

  void addPlayer(ServerPlayer *player);
  void addRobot(ServerPlayer *player);
  void removePlayer(ServerPlayer *player);
  QList<ServerPlayer *> getPlayers() const;
  ServerPlayer *findPlayer(int id) const;

  int getTimeout() const;

  bool isStarted() const;
  // ====================================}

  void doRequest(const QList<ServerPlayer *> targets, int timeout);
  void doNotify(const QList<ServerPlayer *> targets, int timeout);
  void doBroadcastNotify(
    const QList<ServerPlayer *> targets,
    const QString &command,
    const QString &jsonData
  );
  
  void gameOver();

  LuaFunction startGame;
  QString fetchRequest();
};

%{
void Room::initLua()
{
  lua_getglobal(L, "debug");
  lua_getfield(L, -1, "traceback");
  lua_replace(L, -2);
  lua_getglobal(L, "CreateRoom");
  SWIG_NewPointerObj(L, this, SWIGTYPE_p_Room, 0);
  int error = lua_pcall(L, 1, 0, -2);
  lua_pop(L, 1);
  if (error) {
    const char *error_msg = lua_tostring(L, -1);
    qCritical() << error_msg;
  }
}

void Room::roomStart() {
  Q_ASSERT(startGame);

  lua_getglobal(L, "debug");
  lua_getfield(L, -1, "traceback");
  lua_replace(L, -2);

  lua_rawgeti(L, LUA_REGISTRYINDEX, startGame);
  SWIG_NewPointerObj(L, this, SWIGTYPE_p_Room, 0);

  int error = lua_pcall(L, 1, 0, -3);

  if (error) {
    const char *error_msg = lua_tostring(L, -1);
    qCritical() << error_msg;
    lua_pop(L, 2);
  }
  lua_pop(L, 1);
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
};
