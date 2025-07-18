// jsonrpc.h
// 让AI就着jsonrpc.lua改的 懒得优化写法了
#pragma once

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QString>
#include <functional>
#include <map>
#include <optional>
#include <string>

namespace JsonRpc {

using RpcMethod =
    std::function<std::pair<bool, QJsonValue>(const QJsonArray &)>;
using RpcMethodMap = std::map<QString, RpcMethod>;

struct JsonRpcError {
  int code;
  QString message;
  std::optional<QJsonValue> data;
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
QJsonObject notification(const QString &method, const QJsonArray &params = {});

// 构造请求包
QJsonObject request(const QString &method, const QJsonArray &params = {},
                    int id = -1);

// 构造响应包
QJsonObject response(const QJsonObject &req, const QJsonValue &result);

// 构造错误响应包
QJsonObject responseError(const QJsonObject &req, const std::string &errorName,
                          const QJsonValue &data = {});

// 处理单个请求
std::optional<QJsonObject>
handleRequest(const RpcMethodMap &methods, const QJsonObject &req);

// 主处理入口：解析并处理请求
std::optional<QJsonObject>
serverResponse(const RpcMethodMap &methods, const QString &request);

// 获取下一个可用的请求ID
int getNextFreeId();

} // namespace JsonRpc
