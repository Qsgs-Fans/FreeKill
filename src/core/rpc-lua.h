#pragma once

#include "core/c-wrapper.h"
#include "core/jsonrpc.h"

class RpcLua : public LuaInterface {
public:
  explicit RpcLua(const JsonRpc::RpcMethodMap &methodMap);
  ~RpcLua();

  bool dofile(const char *path);
  QVariant call(const QString &func_name, QVariantList params = QVariantList());
  QVariant eval(const QString &lua);

  QString getConnectionInfo() const;

private:
  QIODevice *socket = nullptr;
  QMutex io_lock;
  const JsonRpc::RpcMethodMap &methods;
};
