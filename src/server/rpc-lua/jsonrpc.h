// jsonrpc.h
// 让AI就着jsonrpc.lua改的 懒得优化写法了
// 由于性能出现重大瓶颈，改为CBOR格式，反正这个也是Qt自带支持
#pragma once

#include <QCborArray>
#include <QCborMap>
#include <QString>
#include <functional>
#include <map>
#include <optional>
#include <string>

namespace JsonRpc {

enum JsonKeys {
  // jsonrpc
  JsonRpc = 100,
  Method,
  Params,
  Error,
  Id,
  Result,

  // jsonrpc.error
  ErrorCode = 200,
  ErrorMessage,
  ErrorData,
};

using RpcMethod =
    std::function<std::pair<bool, QCborValue>(const QCborArray &)>;
using RpcMethodMap = std::map<QString, RpcMethod>;

// 检查params参数列表
template<typename... Types>
bool checkParams(const QCborArray &params, Types... expectedTypes) {
  const QCborValue::Type types[] = {static_cast<QCborValue::Type>(expectedTypes)...};
  constexpr size_t typeCount = sizeof...(Types);

  if (params.size() != static_cast<int>(typeCount)) {
    return false;
  }

  for (size_t i = 0; i < typeCount; ++i) {
    if (params[i].type() & types[i] != types[i]) {
      return false;
    }
  }

  return true;
}

struct JsonRpcError {
  int code;
  QString message;
  std::optional<QCborValue> data;
};

// 错误对象集合
extern std::map<std::string, JsonRpcError> errorObjects;

// 判断是否是标准错误
bool isStdError(const std::string &errorName);

// 获取错误对象
std::optional<JsonRpcError> getErrorObject(const std::string &errorName);

// 添加错误对象（用户自定义）
bool addErrorObject(const std::string &errorName, const JsonRpcError &error);

// 删除错误对象
bool removeErrorObject(const std::string &errorName);

// 构造通知包
QCborMap notification(const QString &method, const QCborArray &params = {});

// 构造请求包
QCborMap request(const QString &method, const QCborArray &params = {},
                    int id = -1);

// 构造响应包
QCborMap response(const QCborMap &req, const QCborValue &result);

// 构造错误响应包
QCborMap responseError(const QCborMap &req, const std::string &errorName,
                          const QCborValue &data = {});

// 处理单个请求
std::optional<QCborMap>
handleRequest(const RpcMethodMap &methods, const QCborMap &req);

// 主处理入口：解析并处理请求
std::optional<QCborMap>
serverResponse(const RpcMethodMap &methods, const QCborValue &request);

// 获取下一个可用的请求ID
int getNextFreeId();

} // namespace JsonRpc
