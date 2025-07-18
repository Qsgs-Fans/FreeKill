#include "server/roomthread-rpc.h"
#include "server/server.h"
#include "server/serverplayer.h"

// 这何尝不是一种手搓swig。。

using _rpcRet = std::pair<bool, QJsonValue>;

static QJsonValue nullVal;

static _rpcRet _rpc_qDebug(const QJsonArray &params) {
  if (!params[0].isString()) {
    return { false, nullVal };
  }

  qDebug("%ls", qUtf16Printable(params[0].toString()));
  return { true, nullVal };
}

static _rpcRet _rpc_qInfo(const QJsonArray &params) {
  if (!params[0].isString()) {
    return { false, nullVal };
  }

  qInfo("%ls", qUtf16Printable(params[0].toString()));
  return { true, nullVal };
}

static _rpcRet _rpc_qWarning(const QJsonArray &params) {
  if (!params[0].isString()) {
    return { false, nullVal };
  }

  qWarning("%ls", qUtf16Printable(params[0].toString()));
  return { true, nullVal };
}

static _rpcRet _rpc_qCritical(const QJsonArray &params) {
  if (!params[0].isString()) {
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

static QJsonObject getPlayerObject(ServerPlayer *p) {
  return {};
}

static _rpcRet _rpc_RoomThread_getRoom(const QJsonArray &params) {
  int id = params.at(0).toInt(-1);
  if (id <= 0) {
    return { false, nullVal };
  }

  auto room = ServerInstance->findRoom(id);
  if (!room) {
    return { false, "Room not found" };
  }

  QJsonObject ret {
    { "id", room->getId() },
    // players
    { "ownerId", room->getOwner()->getId() },
    { "timeout", room->getTimeout() },

    { "_settings", room->getSettings().constData() },
  };
  return { true, ret };
}

const JsonRpc::RpcMethodMap ServerRpcMethods {
  { "qDebug", _rpc_qDebug },
  { "qInfo", _rpc_qInfo },
  { "qWarning", _rpc_qWarning },
  { "qCritical", _rpc_qCritical },
  { "print", _rpc_print },

  { "RoomThread_getRoom", _rpc_RoomThread_getRoom },
};
