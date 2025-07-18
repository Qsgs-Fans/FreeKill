#include "core/rpc-lua.h"
#include "core/jsonrpc.h"
#include "core/packman.h"
#include "core/util.h"

RpcLua::RpcLua(const JsonRpc::RpcMethodMap &methodMap) : methods(methodMap) {
  auto process = new QProcess();
  socket = process;

  auto env = QProcessEnvironment::systemEnvironment();

  QJsonArray arr;
  for (auto pkg : Pacman->getDisabledPacks()) {
    arr << pkg;
  }
  env.insert("FK_DISABLED_PACKS", QJsonDocument(arr).toJson(QJsonDocument::Compact));
  process->setProcessEnvironment(env);
  if (QFile::exists("packages/freekill-core") &&
    !Pacman->getDisabledPacks().contains("freekill-core")) {
    process->setWorkingDirectory("packages/freekill-core");
  }
  process->start("lua5.4", { "lua/server/rpc/entry.lua" });

  // 默认等待30s 实际上加载一次差不多3000ms左右 很慢了 可能需要加大
  if (process->waitForReadyRead()) {
    // 把hello world的notification读了，或者可以加更严的判定
    auto msg = process->readLine();
    qDebug("Me <-- %ls", qUtf16Printable(Color("Hello, world!", fkShell::Blue)));
  } else {
    // TODO: throw, then retry
    qCritical("Lua5.4 closed too early.");
    qCritical("  stderr: %s", qUtf8Printable(process->readAllStandardError()));
    qCritical("  stdout: %s", qUtf8Printable(process->readAllStandardOutput()));
  }
}

RpcLua::~RpcLua() {
  // SIGKILL!!
  delete socket;
}

bool RpcLua::dofile(const char *path) {
  return call("dofile", { path }).toBool();
}

static QJsonObject dummyObj;

QVariant RpcLua::call(const QString &func_name, QVariantList params) {
  // 如同Lua中callRpc那样
  QJsonArray arr;
  for (auto v : params) arr << QJsonValue::fromVariant(v);
  auto req = JsonRpc::request(func_name, arr);
  auto id = req["id"].toInt();
  socket->write(QJsonDocument(req).toJson(QJsonDocument::Compact) + '\n');
  qDebug("Me --> %ls: %ls %s",
         qUtf16Printable(Color("request", fkShell::Green, fkShell::Bold)),
         qUtf16Printable(func_name),
         qUtf8Printable(QJsonDocument(arr).toJson(QJsonDocument::Compact)));

  while (socket->waitForReadyRead(15000)) {
    auto msg = socket->readLine();
    if (msg.isNull()) {
      break;
    }

    QJsonParseError err;
    auto doc = QJsonDocument::fromJson(msg, &err);
    if (doc.isNull()) {
      qDebug("  Me <-- %s", qUtf8Printable(msg.trimmed()));
      auto req = JsonRpc::responseError(dummyObj, "parse error", err.errorString());
      socket->write(QJsonDocument(req).toJson(QJsonDocument::Compact) + '\n');
      qDebug("  Me --> %ls: parse error",
             qUtf16Printable(Color("response", fkShell::Red, fkShell::Bold)));
      continue;
    }

    auto packet = doc.object();
    if (packet["jsonrpc"] == "2.0" && packet["id"] == id && packet["method"].isNull()) {
      qDebug("Me <-- %ls: %s",
             qUtf16Printable(Color("response", fkShell::Green, fkShell::Bold)),
             qUtf8Printable(QJsonDocument({ packet["result"] }).toJson(QJsonDocument::Compact)));
      return packet["result"].toVariant();
    } else {
      qDebug("  Me <-- %ls: %ls %s",
             qUtf16Printable(Color("request", fkShell::Green, fkShell::Bold)),
             qUtf16Printable(packet["method"].toString()),
             qUtf8Printable(QJsonDocument(packet["params"].toArray()).toJson(QJsonDocument::Compact)));
      auto res = JsonRpc::serverResponse(methods, msg);
      if (res) {
        socket->write(QJsonDocument(*res).toJson(QJsonDocument::Compact) + '\n');
        if (!res->value("error").isObject()) {
          qDebug("  Me --> %ls: %s",
                 qUtf16Printable(Color("response", fkShell::Green, fkShell::Bold)),
                 qUtf8Printable(QJsonDocument({ res->value("result") }).toJson(QJsonDocument::Compact)));
        } else {
          qDebug("  Me --> %ls: %ls",
                 qUtf16Printable(Color("response", fkShell::Red, fkShell::Bold)),
                 qUtf8Printable(QJsonDocument(*res).toJson(QJsonDocument::Compact)));
        }
      }
    }
  }

  return QVariant();
}

QVariant RpcLua::eval(const QString &lua) {
  // TODO; 当然可能根本不会去做
  return QVariant();
}
