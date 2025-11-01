#ifndef _ROOMBASE_H
#define _ROOMBASE_H

class Server;
class ServerPlayer;

class RoomBase : public QObject {
 public:
  ~RoomBase();

  Server *getServer() const;
  bool isLobby() const;
  QList<ServerPlayer *> getPlayers() const;
  QList<ServerPlayer *> getOtherPlayers(ServerPlayer *expect) const;
  ServerPlayer *findPlayer(int id) const;

  void doBroadcastNotify(const QList<ServerPlayer *> targets,
                         const QByteArray &command, const QByteArray &jsonData);

  void chat(ServerPlayer *sender, const QByteArray &jsonData);

  virtual void addPlayer(ServerPlayer *player) = 0;
  virtual void removePlayer(ServerPlayer *player) = 0;
  virtual void handlePacket(ServerPlayer *sender, const QByteArray &command,
      const QByteArray &jsonData) = 0;
 protected:
  Server *server;
  QList<ServerPlayer *> players;
  QList<ServerPlayer *> observers;
};

#endif // _ROOMBASE_H
