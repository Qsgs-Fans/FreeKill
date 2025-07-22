#include "server/gamelogic/rpc-dispatchers.h"
#include "server/server.h"
#include "server/user/serverplayer.h"

// 这何尝不是一种手搓swig。。

using _rpcRet = std::pair<bool, QCborValue>;
using JsonRpc::checkParams;

static QCborValue nullVal;

// part1: stdout相关

static _rpcRet _rpc_qDebug(const QCborArray &params) {
  if (!checkParams(params, QCborValue::ByteArray)) {
    return { false, nullVal };
  }

  qDebug("%s", qUtf8Printable(params[0].toByteArray()));
  return { true, nullVal };
}

static _rpcRet _rpc_qInfo(const QCborArray &params) {
  if (!checkParams(params, QCborValue::ByteArray)) {
    return { false, nullVal };
  }

  qInfo("%s", qUtf8Printable(params[0].toByteArray()));
  return { true, nullVal };
}

static _rpcRet _rpc_qWarning(const QCborArray &params) {
  if (!checkParams(params, QCborValue::ByteArray)) {
    return { false, nullVal };
  }
  if (!params[0].isString()) {
    return { false, nullVal };
  }

  qWarning("%s", qUtf8Printable(params[0].toByteArray()));
  return { true, nullVal };
}

static _rpcRet _rpc_qCritical(const QCborArray &params) {
  if (!checkParams(params, QCborValue::ByteArray)) {
    return { false, nullVal };
  }

  qCritical("%s", qUtf8Printable(params[0].toByteArray()));
  return { true, nullVal };
}

static _rpcRet _rpc_print(const QCborArray &params) {
  QTextStream out(stdout);
  for (auto v : params) {
    out << v.toByteArray() << '\t';
  }
  out << Qt::endl;
  return { true, nullVal };
}

// part2: ServerPlayer相关

static _rpcRet _rpc_ServerPlayer_doRequest(const QCborArray &params) {
  if (!checkParams(params, QCborValue::ByteArray, QCborValue::ByteArray,
                   QCborValue::ByteArray, QCborValue::Integer, QCborValue::Integer)) {
    return { false, nullVal };
  }

  QString connId = params[0].toByteArray();
  QString command = params[1].toByteArray();
  QString jsonData = params[2].toByteArray();
  int timeout = params[3].toInteger(0);
  qint64 timestamp = params[4].toInteger();

  auto player = ServerInstance->findPlayerByConnId(connId);
  if (!player) {
    return { false, "Player not found" };
  }

  player->doRequest(command.toUtf8(), jsonData.toUtf8(), timeout, timestamp);

  return { true, nullVal };
}

static _rpcRet _rpc_ServerPlayer_waitForReply(const QCborArray &params) {
  if (!checkParams(params, QCborValue::ByteArray, QCborValue::Integer)) {
    return { false, nullVal };
  }

  QString connId = params[0].toByteArray();
  int timeout = params[1].toInteger(0);

  auto player = ServerInstance->findPlayerByConnId(connId);
  if (!player) {
    return { false, "Player not found" };
  }

  QString reply = player->waitForReply(timeout);
  return { true, reply };
}

static _rpcRet _rpc_ServerPlayer_doNotify(const QCborArray &params) {
  if (!checkParams(params, QCborValue::ByteArray, QCborValue::ByteArray, QCborValue::ByteArray)) {
    return { false, nullVal };
  }

  QString connId = params[0].toByteArray();
  QString command = params[1].toByteArray();
  QString jsonData = params[2].toByteArray();

  auto player = ServerInstance->findPlayerByConnId(connId);
  if (!player) {
    return { false, "Player not found" };
  }

  player->doNotify(command.toUtf8(), jsonData.toUtf8());

  return { true, nullVal };
}

static _rpcRet _rpc_ServerPlayer_thinking(const QCborArray &params) {
  if (!checkParams(params, QCborValue::ByteArray)) {
    return { false, nullVal };
  }

  QString connId = params[0].toByteArray();
  auto player = ServerInstance->findPlayerByConnId(connId);
  if (!player) {
    return { false, "Player not found" };
  }

  bool isThinking = player->thinking();
  return { true, isThinking };
}

static _rpcRet _rpc_ServerPlayer_setThinking(const QCborArray &params) {
  if (!checkParams(params, QCborValue::ByteArray, QCborValue::SimpleType)) {
    return { false, nullVal };
  }

  QString connId = params[0].toByteArray();
  bool thinking = params[1].toBool();

  auto player = ServerInstance->findPlayerByConnId(connId);
  if (!player) {
    return { false, "Player not found" };
  }

  player->setThinking(thinking);
  return { true, nullVal };
}

static _rpcRet _rpc_ServerPlayer_setDied(const QCborArray &params) {
  if (!checkParams(params, QCborValue::ByteArray, QCborValue::SimpleType)) {
    return { false, nullVal };
  }

  QString connId = params[0].toByteArray();
  bool died = params[1].toBool();

  auto player = ServerInstance->findPlayerByConnId(connId);
  if (!player) {
    return { false, "Player not found" };
  }

  player->setDied(died);
  return { true, nullVal };
}

static _rpcRet _rpc_ServerPlayer_emitKick(const QCborArray &params) {
  if (!checkParams(params, QCborValue::ByteArray)) {
    return { false, nullVal };
  }

  QString connId = params[0].toByteArray();
  auto player = ServerInstance->findPlayerByConnId(connId);
  if (!player) {
    return { false, "Player not found" };
  }

  emit player->kicked();
  return { true, nullVal };
}

// part3: Room相关

static _rpcRet _rpc_Room_delay(const QCborArray &params) {
  if (!checkParams(params, QCborValue::Integer, QCborValue::Integer)) {
    return { false, nullVal };
  }
  int id = params[0].toInteger(-1);
  int ms = params[1].toInteger(0);
  if (ms <= 0) {
    return { false, nullVal };
  }
  auto room = ServerInstance->findRoom(id);
  if (!room) {
    return { false, "Room not found" };
  }

  room->delay(ms);

  return { true, nullVal };
}

static _rpcRet _rpc_Room_updatePlayerWinRate(const QCborArray &params) {
  if (!checkParams(params, QCborValue::Integer, QCborValue::Integer,
                   QCborValue::ByteArray, QCborValue::ByteArray, QCborValue::Integer)) {
    return { false, nullVal };
  }

  int roomId = params[0].toInteger(-1);
  int playerId = params[1].toInteger(-1);
  QString mode = params[2].toByteArray();
  QString role = params[3].toByteArray();
  int result = params[4].toInteger(0);

  auto room = ServerInstance->findRoom(roomId);
  if (!room) {
    return { false, "Room not found" };
  }

  room->updatePlayerWinRate(playerId, mode, role, result);

  return { true, nullVal };
}

static _rpcRet _rpc_Room_updateGeneralWinRate(const QCborArray &params) {
  if (!checkParams(params, QCborValue::Integer, QCborValue::ByteArray,
                   QCborValue::ByteArray, QCborValue::ByteArray, QCborValue::Integer)) {
    return { false, nullVal };
  }

  int roomId = params[0].toInteger(-1);
  QString general = params[1].toByteArray();
  QString mode = params[2].toByteArray();
  QString role = params[3].toByteArray();
  int result = params[4].toInteger(0);

  auto room = ServerInstance->findRoom(roomId);
  if (!room) {
    return { false, "Room not found" };
  }

  room->updateGeneralWinRate(general, mode, role, result);

  return { true, nullVal };
}

static _rpcRet _rpc_Room_gameOver(const QCborArray &params) {
  if (!checkParams(params, QCborValue::Integer)) {
    return { false, nullVal };
  }

  int roomId = params[0].toInteger(-1);
  auto room = ServerInstance->findRoom(roomId);
  if (!room) {
    return { false, "Room not found" };
  }

  room->gameOver();

  return { true, nullVal };
}

static _rpcRet _rpc_Room_setRequestTimer(const QCborArray &params) {
  if (!checkParams(params, QCborValue::Integer, QCborValue::Integer)) {
    return { false, nullVal };
  }

  int roomId = params[0].toInteger(-1);
  int ms = params[1].toInteger(0);
  if (ms <= 0) {
    return { false, nullVal };
  }

  auto room = ServerInstance->findRoom(roomId);
  if (!room) {
    return { false, "Room not found" };
  }

  room->setRequestTimer(ms);

  return { true, nullVal };
}

static _rpcRet _rpc_Room_destroyRequestTimer(const QCborArray &params) {
  if (!checkParams(params, QCborValue::Integer)) {
    return { false, nullVal };
  }

  int roomId = params[0].toInteger(-1);
  auto room = ServerInstance->findRoom(roomId);
  if (!room) {
    return { false, "Room not found" };
  }

  room->destroyRequestTimer();

  return { true, nullVal };
}

static _rpcRet _rpc_Room_increaseRefCount(const QCborArray &params) {
  if (!checkParams(params, QCborValue::Integer)) {
    return { false, nullVal };
  }

  int roomId = params[0].toInteger(-1);
  auto room = ServerInstance->findRoom(roomId);
  if (!room) {
    return { false, "Room not found" };
  }

  room->increaseRefCount();

  return { true, nullVal };
}

static _rpcRet _rpc_Room_decreaseRefCount(const QCborArray &params) {
  if (!checkParams(params, QCborValue::Integer)) {
    return { false, nullVal };
  }

  int roomId = params[0].toInteger(-1);
  auto room = ServerInstance->findRoom(roomId);
  if (!room) {
    return { false, "Room not found" };
  }

  room->decreaseRefCount();

  return { true, nullVal };
}

// 收官：getRoom

static QCborMap getPlayerObject(ServerPlayer *p) {
  QCborArray gameData;
  for (auto i : p->getGameData()) gameData << i;

  return {
    { "connId", p->getConnId() },
    { "id", p->getId() },
    { "screenName", p->getScreenName() },
    { "avatar", p->getAvatar() },
    { "totalGameTime", p->getTotalGameTime() },

    { "state", p->getState() },

    { "gameData", gameData },
  };
}

static _rpcRet _rpc_RoomThread_getRoom(const QCborArray &params) {
  if (!checkParams(params, QCborValue::Integer)) {
    return { false, nullVal };
  }
  int id = params[0].toInteger(-1);
  if (id <= 0) {
    return { false, nullVal };
  }

  auto room = ServerInstance->findRoom(id);
  if (!room) {
    return { false, "Room not found" };
  }

  QCborArray players;
  for (auto p : room->getPlayers()) {
    players << getPlayerObject(p);
  }

  QCborMap ret {
    { "id", room->getId() },
    { "players", players },
    { "ownerId", room->getOwner()->getId() },
    { "timeout", room->getTimeout() },

    { "settings", room->getSettings().constData() },
  };
  return { true, ret };
}

const JsonRpc::RpcMethodMap ServerRpcMethods {
  { "qDebug", _rpc_qDebug },
  { "qInfo", _rpc_qInfo },
  { "qWarning", _rpc_qWarning },
  { "qCritical", _rpc_qCritical },
  { "print", _rpc_print },

  { "ServerPlayer_doRequest", _rpc_ServerPlayer_doRequest },
  { "ServerPlayer_waitForReply", _rpc_ServerPlayer_waitForReply },
  { "ServerPlayer_doNotify", _rpc_ServerPlayer_doNotify },
  { "ServerPlayer_thinking", _rpc_ServerPlayer_thinking },
  { "ServerPlayer_setThinking", _rpc_ServerPlayer_setThinking },
  { "ServerPlayer_setDied", _rpc_ServerPlayer_setDied },
  { "ServerPlayer_emitKick", _rpc_ServerPlayer_emitKick },

  { "Room_delay", _rpc_Room_delay },
  { "Room_updatePlayerWinRate", _rpc_Room_updatePlayerWinRate },
  { "Room_updateGeneralWinRate", _rpc_Room_updateGeneralWinRate },
  { "Room_gameOver", _rpc_Room_gameOver },
  { "Room_setRequestTimer", _rpc_Room_setRequestTimer },
  { "Room_destroyRequestTimer", _rpc_Room_destroyRequestTimer },
  { "Room_increaseRefCount", _rpc_Room_increaseRefCount },
  { "Room_decreaseRefCount", _rpc_Room_decreaseRefCount },

  { "RoomThread_getRoom", _rpc_RoomThread_getRoom },
};
