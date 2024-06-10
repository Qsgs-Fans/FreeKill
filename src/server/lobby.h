#ifndef _LOBBY_H
#define _LOBBY_H

#include "server/roombase.h"

class Lobby : public RoomBase {
  Q_OBJECT
 public:
  Lobby(Server *server);

  void addPlayer(ServerPlayer *player);
  void removePlayer(ServerPlayer *player);

  void handlePacket(ServerPlayer *sender, const QString &command,
                    const QString &jsonData);
 private:
  // for handle packet
  void updateAvatar(ServerPlayer *, const QString &);
  void updatePassword(ServerPlayer *, const QString &);
  void createRoom(ServerPlayer *, const QString &);
  void getRoomConfig(ServerPlayer *, const QString &);
  void enterRoom(ServerPlayer *, const QString &);
  void observeRoom(ServerPlayer *, const QString &);
  void refreshRoomList(ServerPlayer *, const QString &);
};

#endif // _LOBBY_H
