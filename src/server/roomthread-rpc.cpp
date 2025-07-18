#include "server/roomthread-rpc.h"
#include "server/server.h"
#include "server/serverplayer.h"

// 这何尝不是一种手搓swig。。

using _rpcRet = std::pair<bool, QJsonValue>;
using JsonRpc::checkParams;

static QJsonValue nullVal;

// part1: stdout相关

static _rpcRet _rpc_qDebug(const QJsonArray &params) {
  if (!checkParams(params, QJsonValue::String)) {
    return { false, nullVal };
  }

  qDebug("%ls", qUtf16Printable(params[0].toString()));
  return { true, nullVal };
}

static _rpcRet _rpc_qInfo(const QJsonArray &params) {
  if (!checkParams(params, QJsonValue::String)) {
    return { false, nullVal };
  }

  qInfo("%ls", qUtf16Printable(params[0].toString()));
  return { true, nullVal };
}

static _rpcRet _rpc_qWarning(const QJsonArray &params) {
  if (!checkParams(params, QJsonValue::String)) {
    return { false, nullVal };
  }
  if (!params[0].isString()) {
    return { false, nullVal };
  }

  qWarning("%ls", qUtf16Printable(params[0].toString()));
  return { true, nullVal };
}

static _rpcRet _rpc_qCritical(const QJsonArray &params) {
  if (!checkParams(params, QJsonValue::String)) {
    return { false, nullVal };
  }

  qCritical("%ls", qUtf16Printable(params[0].toString()));
  return { true, nullVal };
}

static _rpcRet _rpc_print(const QJsonArray &params) {
  QTextStream out(stdout);
  for (auto v : params) {
    out << v.toString() << '\t';
  }
  out << Qt::endl;
  return { true, nullVal };
}

// part2: ServerPlayer相关

static _rpcRet _rpc_ServerPlayer_doRequest(const QJsonArray &params) {
  if (!checkParams(params, QJsonValue::String, QJsonValue::String,
                   QJsonValue::String, QJsonValue::Double, QJsonValue::Double)) {
    return { false, nullVal };
  }

  QString connId = params[0].toString();
  QString command = params[1].toString();
  QString jsonData = params[2].toString();
  int timeout = params[3].toInt(0);
  qint64 timestamp = params[4].toInteger();

  auto player = ServerInstance->findPlayerByConnId(connId);
  if (!player) {
    return { false, "Player not found" };
  }

  player->doRequest(command.toUtf8(), jsonData.toUtf8(), timeout, timestamp);

  return { true, nullVal };
}

static _rpcRet _rpc_ServerPlayer_waitForReply(const QJsonArray &params) {
  if (!checkParams(params, QJsonValue::String, QJsonValue::Double)) {
    return { false, nullVal };
  }

  QString connId = params[0].toString();
  int timeout = params[1].toInt(0);

  auto player = ServerInstance->findPlayerByConnId(connId);
  if (!player) {
    return { false, "Player not found" };
  }

  QString reply = player->waitForReply(timeout);
  return { true, reply };
}

static _rpcRet _rpc_ServerPlayer_doNotify(const QJsonArray &params) {
  if (!checkParams(params, QJsonValue::String, QJsonValue::String, QJsonValue::String)) {
    return { false, nullVal };
  }

  QString connId = params[0].toString();
  QString command = params[1].toString();
  QString jsonData = params[2].toString();

  auto player = ServerInstance->findPlayerByConnId(connId);
  if (!player) {
    return { false, "Player not found" };
  }

  player->doNotify(command.toUtf8(), jsonData.toUtf8());

  return { true, nullVal };
}

static _rpcRet _rpc_ServerPlayer_thinking(const QJsonArray &params) {
  if (!checkParams(params, QJsonValue::String)) {
    return { false, nullVal };
  }

  QString connId = params[0].toString();
  auto player = ServerInstance->findPlayerByConnId(connId);
  if (!player) {
    return { false, "Player not found" };
  }

  bool isThinking = player->thinking();
  return { true, isThinking };
}

static _rpcRet _rpc_ServerPlayer_setThinking(const QJsonArray &params) {
  if (!checkParams(params, QJsonValue::String, QJsonValue::Bool)) {
    return { false, nullVal };
  }

  QString connId = params[0].toString();
  bool thinking = params[1].toBool();

  auto player = ServerInstance->findPlayerByConnId(connId);
  if (!player) {
    return { false, "Player not found" };
  }

  player->setThinking(thinking);
  return { true, nullVal };
}

static _rpcRet _rpc_ServerPlayer_setDied(const QJsonArray &params) {
  if (!checkParams(params, QJsonValue::String, QJsonValue::Bool)) {
    return { false, nullVal };
  }

  QString connId = params[0].toString();
  bool died = params[1].toBool();

  auto player = ServerInstance->findPlayerByConnId(connId);
  if (!player) {
    return { false, "Player not found" };
  }

  player->setDied(died);
  return { true, nullVal };
}

static _rpcRet _rpc_ServerPlayer_emitKick(const QJsonArray &params) {
  if (!checkParams(params, QJsonValue::String)) {
    return { false, nullVal };
  }

  QString connId = params[0].toString();
  auto player = ServerInstance->findPlayerByConnId(connId);
  if (!player) {
    return { false, "Player not found" };
  }

  emit player->kicked();
  return { true, nullVal };
}

// part3: Room相关

static _rpcRet _rpc_Room_delay(const QJsonArray &params) {
  if (!checkParams(params, QJsonValue::Double, QJsonValue::Double)) {
    return { false, nullVal };
  }
  int id = params[0].toInt(-1);
  int ms = params[1].toInt(0);
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

static _rpcRet _rpc_Room_updatePlayerWinRate(const QJsonArray &params) {
  if (!checkParams(params, QJsonValue::Double, QJsonValue::Double, 
                   QJsonValue::String, QJsonValue::String, QJsonValue::Double)) {
    return { false, nullVal };
  }

  int roomId = params[0].toInt(-1);
  int playerId = params[1].toInt(-1);
  QString mode = params[2].toString();
  QString role = params[3].toString();
  int result = params[4].toInt(0);

  auto room = ServerInstance->findRoom(roomId);
  if (!room) {
    return { false, "Room not found" };
  }

  room->updatePlayerWinRate(playerId, mode, role, result);

  return { true, nullVal };
}

static _rpcRet _rpc_Room_updateGeneralWinRate(const QJsonArray &params) {
  if (!checkParams(params, QJsonValue::Double, QJsonValue::String,
                   QJsonValue::String, QJsonValue::String, QJsonValue::Double)) {
    return { false, nullVal };
  }

  int roomId = params[0].toInt(-1);
  QString general = params[1].toString();
  QString mode = params[2].toString();
  QString role = params[3].toString();
  int result = params[4].toInt(0);

  auto room = ServerInstance->findRoom(roomId);
  if (!room) {
    return { false, "Room not found" };
  }

  room->updateGeneralWinRate(general, mode, role, result);

  return { true, nullVal };
}

static _rpcRet _rpc_Room_gameOver(const QJsonArray &params) {
  if (!checkParams(params, QJsonValue::Double)) {
    return { false, nullVal };
  }

  int roomId = params[0].toInt(-1);
  auto room = ServerInstance->findRoom(roomId);
  if (!room) {
    return { false, "Room not found" };
  }

  room->gameOver();

  return { true, nullVal };
}

static _rpcRet _rpc_Room_setRequestTimer(const QJsonArray &params) {
  if (!checkParams(params, QJsonValue::Double, QJsonValue::Double)) {
    return { false, nullVal };
  }

  int roomId = params[0].toInt(-1);
  int ms = params[1].toInt(0);
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

static _rpcRet _rpc_Room_destroyRequestTimer(const QJsonArray &params) {
  if (!checkParams(params, QJsonValue::Double)) {
    return { false, nullVal };
  }

  int roomId = params[0].toInt(-1);
  auto room = ServerInstance->findRoom(roomId);
  if (!room) {
    return { false, "Room not found" };
  }

  room->destroyRequestTimer();

  return { true, nullVal };
}

static _rpcRet _rpc_Room_increaseRefCount(const QJsonArray &params) {
  if (!checkParams(params, QJsonValue::Double)) {
    return { false, nullVal };
  }

  int roomId = params[0].toInt(-1);
  auto room = ServerInstance->findRoom(roomId);
  if (!room) {
    return { false, "Room not found" };
  }

  room->increaseRefCount();

  return { true, nullVal };
}

static _rpcRet _rpc_Room_decreaseRefCount(const QJsonArray &params) {
  if (!checkParams(params, QJsonValue::Double)) {
    return { false, nullVal };
  }

  int roomId = params[0].toInt(-1);
  auto room = ServerInstance->findRoom(roomId);
  if (!room) {
    return { false, "Room not found" };
  }

  room->decreaseRefCount();

  return { true, nullVal };
}

// 收官：getRoom

static QJsonObject getPlayerObject(ServerPlayer *p) {
  QJsonArray gameData;
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

static _rpcRet _rpc_RoomThread_getRoom(const QJsonArray &params) {
  if (!checkParams(params, QJsonValue::Double)) {
    return { false, nullVal };
  }
  int id = params[0].toInt(-1);
  if (id <= 0) {
    return { false, nullVal };
  }

  auto room = ServerInstance->findRoom(id);
  if (!room) {
    return { false, "Room not found" };
  }

  QJsonArray players;
  for (auto p : room->getPlayers()) {
    players << getPlayerObject(p);
  }

  QJsonObject ret {
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
