#ifndef _ROOMBASE_H
#define _ROOMBASE_H

class Server;
class ServerPlayer;

class RoomBase : public QObject {
 public:
  bool isLobby() const;
  QList<ServerPlayer *> getPlayers() const;
  QList<ServerPlayer *> getOtherPlayers(ServerPlayer *expect) const;
  ServerPlayer *findPlayer(int id) const;

  void doBroadcastNotify(const QList<ServerPlayer *> targets,
                         const QString &command, const QString &jsonData);

 protected:
  Server *server;
  QList<ServerPlayer *> players;
};

#endif // _ROOMBASE_H
