#ifndef _LOBBY_H
#define _LOBBY_H

#include "server/room/roombase.h"

class Lobby : public RoomBase {
  Q_OBJECT
 public:
  Lobby(Server *server);

  void addPlayer(ServerPlayer *player);
  void removePlayer(ServerPlayer *player);

  void handlePacket(ServerPlayer *sender, const QByteArray &command,
                    const QByteArray &jsonData);
 private:
  // for handle packet
  void updateAvatar(ServerPlayer *, const QByteArray &);
  void updatePassword(ServerPlayer *, const QByteArray &);
  void createRoom(ServerPlayer *, const QByteArray &);
  void getRoomConfig(ServerPlayer *, const QByteArray &);
  void enterRoom(ServerPlayer *, const QByteArray &);
  void observeRoom(ServerPlayer *, const QByteArray &);
  void refreshRoomList(ServerPlayer *, const QByteArray &);
};

#endif // _LOBBY_H
