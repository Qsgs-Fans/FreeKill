#include "core/jsonrpc.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonValue>

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

QJsonObject notification(const QString &method, const QJsonArray &params) {
  QJsonObject obj;
  obj["jsonrpc"] = "2.0";
  obj["method"] = method;
  if (!params.isEmpty()) {
    obj["params"] = params;
  }
  return obj;
}

QJsonObject request(const QString &method, const QJsonArray &params, int id) {
  QJsonObject obj = notification(method, params);
  if (id == -1) {
    id = _reqId++;
    if (_reqId > 10000000) _reqId = 1;
  }
  obj["id"] = id;
  return obj;
}

QJsonObject response(const QJsonObject &req, const QJsonValue &result) {
  QJsonObject res;
  res["jsonrpc"] = "2.0";
  if (req.contains("id")) {
    res["id"] = req["id"];
  }
  res["result"] = result;
  return res;
}

QJsonObject responseError(const QJsonObject &req, const std::string &errorName,
                          const QJsonValue &data) {
  auto errorOpt = getErrorObject(errorName);
  if (!errorOpt) {
    errorOpt = getErrorObject("internal_error").value();
  }

  QJsonObject errorObj;
  errorObj["code"] = errorOpt->code;
  errorObj["message"] = errorOpt->message;
  if (errorOpt->data.has_value()) {
    errorObj["data"] = errorOpt->data.value();
  }

  QJsonObject res;
  res["jsonrpc"] = "2.0";
  res["error"] = errorObj;

  if (errorOpt->code == -32700 || errorOpt->code == -32600) {
    // No ID
  } else if (req.contains("id")) {
    res["id"] = req["id"];
  }

  if (!data.isUndefined()) {
    res["data"] = data;
  }

  return res;
}

std::optional<QJsonObject>
handleRequest(const std::map<QString, RpcMethod> &methods,
              const QJsonObject &req) {
  if (!req.contains("jsonrpc") || req["jsonrpc"].toString() != "2.0") {
    return responseError(req, "invalid_request");
  }

  if (!req.contains("method") || !req["method"].isString()) {
    return responseError(req, "invalid_request");
  }

  QString method = req["method"].toString();
  auto it = methods.find(method);
  if (it == methods.end()) {
    return responseError(req, "method_not_found");
  }

  QJsonArray params;
  if (req.contains("params") && req["params"].isArray()) {
    params = req["params"].toArray();
  }

  try {
    auto [success, result] = it->second(params);
    if (!success) {
      // Assume error info is in result
      return responseError(req, "invalid_params", result);
    }
    if (!req.contains("id")) {
      return std::nullopt; // notification
    }
    return response(req, result);
  } catch (const std::exception &e) {
    return responseError(req, "internal_error", e.what());
  }
}

std::optional<QJsonObject>
serverResponse(const std::map<QString, RpcMethod> &methods,
               const QString &request) {
  QJsonParseError parseError;
  QJsonDocument doc = QJsonDocument::fromJson(request.toUtf8(), &parseError);
  if (parseError.error != QJsonParseError::NoError) {
    QJsonObject dummy;
    return responseError(dummy, "parse_error", request);
  }

  QJsonValue reqVal = doc.object();
  if (!reqVal.isObject()) {
    return responseError({}, "invalid_request", request);
  }

  QJsonObject reqObj = reqVal.toObject();
  if (reqObj["jsonrpc"].toString() != "2.0") {
    return responseError({}, "invalid_request", request);
  }

  if (!reqObj.contains("method")) {
    return handleRequest(methods, reqObj);
  }

  auto res = handleRequest(methods, reqObj);
  return res;
}

int getNextFreeId() { return _reqId; }

} // namespace JsonRpc
