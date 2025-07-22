#include "server/rpc-lua/jsonrpc.h"
#include <QDebug>
#include <QCborValue>

static int _reqId = 1;

namespace JsonRpc {

std::map<std::string, JsonRpcError> errorObjects = {
    {"parse_error", {-32700, "Parse error"}},
    {"invalid_request", {-32600, "Invalid request"}},
    {"method_not_found", {-32601, "Method not found"}},
    {"invalid_params", {-32602, "Invalid params"}},
    {"internal_error", {-32603, "Internal error"}},
    {"server_error", {-32000, "Server error"}},
};

bool isStdError(const std::string &errorName) {
  return errorName == "parse_error" || errorName == "invalid_request" ||
         errorName == "method_not_found" || errorName == "invalid_params" ||
         errorName == "internal_error" || errorName == "server_error";
}

std::optional<JsonRpcError> getErrorObject(const std::string &errorName) {
  auto it = errorObjects.find(errorName);
  if (it != errorObjects.end()) {
    return it->second;
  }
  return std::nullopt;
}

bool addErrorObject(const std::string &errorName, const JsonRpcError &error) {
  if (isStdError(errorName)) {
    return false;
  }
  if (error.code < -32099 || error.code > -32000) {
    return false;
  }

  for (const auto &[name, obj] : errorObjects) {
    if (obj.code == error.code) {
      return false; // code already used
    }
  }

  errorObjects[errorName] = error;
  return true;
}

bool removeErrorObject(const std::string &errorName) {
  if (isStdError(errorName))
    return false;
  auto it = errorObjects.find(errorName);
  if (it != errorObjects.end()) {
    errorObjects.erase(it);
    return true;
  }
  return false;
}

QCborMap notification(const QString &method, const QCborArray &params) {
  QCborMap obj;
  obj[JsonRpc] = "2.0";
  obj[Method] = method;
  if (!params.isEmpty()) {
    obj[Params] = params;
  }
  return obj;
}

QCborMap request(const QString &method, const QCborArray &params, int id) {
  QCborMap obj = notification(method, params);
  if (id == -1) {
    id = _reqId++;
    if (_reqId > 10000000) _reqId = 1;
  }
  obj[Id] = id;
  return obj;
}

QCborMap response(const QCborMap &req, const QCborValue &result) {
  QCborMap res;
  res[JsonRpc] = "2.0";
  if (req.contains(Id)) {
    res[Id] = req[Id];
  }
  res[Result] = result;
  return res;
}

QCborMap responseError(const QCborMap &req, const std::string &errorName,
                          const QCborValue &data) {
  auto errorOpt = getErrorObject(errorName);
  if (!errorOpt) {
    errorOpt = getErrorObject("internal_error").value();
  }

  QCborMap errorObj;
  errorObj[ErrorCode] = errorOpt->code;
  errorObj[ErrorMessage] = errorOpt->message;
  if (errorOpt->data.has_value()) {
    errorObj[ErrorData] = errorOpt->data.value();
  }

  QCborMap res;
  res[JsonRpc] = "2.0";
  res[Error] = errorObj;

  if (errorOpt->code == -32700 || errorOpt->code == -32600) {
    // No ID
  } else if (req.contains(Id) && req[Id].isInteger()) {
    res[Id] = req[Id];
  }

  if (!data.isUndefined()) {
    errorObj[ErrorData] = data;
  }

  return res;
}

std::optional<QCborMap>
handleRequest(const std::map<QString, RpcMethod> &methods,
              const QCborMap &req) {
  if (!req.contains(JsonRpc) || req[JsonRpc].toByteArray() != "2.0") {
    return responseError(req, "invalid_request");
  }

  if (!req.contains(Method) || !req[Method].isByteArray()) {
    return responseError(req, "invalid_request");
  }

  QString method = req[Method].toByteArray();
  auto it = methods.find(method);
  if (it == methods.end()) {
    return responseError(req, "method_not_found");
  }

  QCborArray params;
  if (req.contains(Params) && req[Params].isArray()) {
    params = req[Params].toArray();
  }

  try {
    auto [success, result] = it->second(params);
    if (!success) {
      // Assume error info is in result
      return responseError(req, "invalid_params", result);
    }
    if (!req.contains(Id) || !req[Id].isInteger()) {
      return std::nullopt; // notification
    }
    return response(req, result);
  } catch (const std::exception &e) {
    return responseError(req, "internal_error", e.what());
  }
}

std::optional<QCborMap>
serverResponse(const std::map<QString, RpcMethod> &methods,
               const QCborValue &reqVal) {
  if (!reqVal.isMap()) {
    return responseError({}, "invalid_request", reqVal);
  }

  QCborMap reqObj = reqVal.toMap();
  if (reqObj[JsonRpc].toByteArray() != "2.0") {
    return responseError({}, "invalid_request", reqVal);
  }

  if (!reqObj.contains(Method)) {
    return handleRequest(methods, reqObj);
  }

  auto res = handleRequest(methods, reqObj);
  return res;
}

int getNextFreeId() { return _reqId; }

} // namespace JsonRpc
