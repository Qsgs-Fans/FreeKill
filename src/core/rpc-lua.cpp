#include "core/rpc-lua.h"
#include "core/jsonrpc.h"
#include "core/packman.h"
#include "core/util.h"

#ifdef Q_OS_LINUX
#include <unistd.h>
#endif

#ifdef RPC_DEBUG
constexpr bool _EnableRpcDebug = true;
#else
constexpr bool _EnableRpcDebug = false;
#endif

template <typename... Args>
void rpc_debug(const char *fmt, Args... args) {
  if constexpr (_EnableRpcDebug) {
    qDebug(fmt, args...);
  }
}

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
    rpc_debug("Me <-- %ls", qUtf16Printable(Color("Hello, world!", fkShell::Blue)));
  } else {
    // TODO: throw, then retry
    qCritical("Lua5.4 closed too early.");
    qCritical("  stderr: %s", qUtf8Printable(process->readAllStandardError()));
    qCritical("  stdout: %s", qUtf8Printable(process->readAllStandardOutput()));
  }
}

RpcLua::~RpcLua() {
  socket->write(R"({"jsonrpc":"2.0","id":9999999,"method":"bye"})""\n");
  rpc_debug("Me --> %ls", qUtf16Printable(Color("Say goodbye", fkShell::Blue)));
  if (socket->waitForReadyRead(15000)) {
    auto msg = socket->readLine();
    rpc_debug("Me <-- %ls", qUtf16Printable(Color("Byebye", fkShell::Blue)));

    auto process = dynamic_cast<QProcess *>(socket);
    if (process) process->waitForFinished();
  } else {
    // 不管他了，杀了
  }

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
  rpc_debug("Me --> %ls: %ls %s",
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
      rpc_debug("  Me <-- %s", qUtf8Printable(msg.trimmed()));
      auto req = JsonRpc::responseError(dummyObj, "parse error", err.errorString());
      socket->write(QJsonDocument(req).toJson(QJsonDocument::Compact) + '\n');
      rpc_debug("  Me --> %ls: parse error",
             qUtf16Printable(Color("response", fkShell::Red, fkShell::Bold)));
      continue;
    }

    auto packet = doc.object();
    if (packet["jsonrpc"] == "2.0" && packet["id"] == id && packet["method"].isNull()) {
      if (packet.value("error").isObject()) {
        rpc_debug("Me <-- %ls: %s",
                  qUtf16Printable(Color("response (error)", fkShell::Red, fkShell::Bold)),
                  qUtf8Printable(QJsonDocument(packet).toJson(QJsonDocument::Compact)));
      } else {
        rpc_debug("Me <-- %ls: %s",
                  qUtf16Printable(Color("response", fkShell::Green, fkShell::Bold)),
                  qUtf8Printable(QJsonDocument({ packet["result"] }).toJson(QJsonDocument::Compact)));
      }
      return packet["result"].toVariant();
    } else {
      rpc_debug("  Me <-- %ls: %ls %s",
             qUtf16Printable(Color("request", fkShell::Green, fkShell::Bold)),
             qUtf16Printable(packet["method"].toString()),
             qUtf8Printable(QJsonDocument(packet["params"].toArray()).toJson(QJsonDocument::Compact)));
      auto res = JsonRpc::serverResponse(methods, msg);
      if (res) {
        socket->write(QJsonDocument(*res).toJson(QJsonDocument::Compact) + '\n');
        if (!res->value("error").isObject()) {
          rpc_debug("  Me --> %ls: %s",
                 qUtf16Printable(Color("response", fkShell::Green, fkShell::Bold)),
                 qUtf8Printable(QJsonDocument({ res->value("result") }).toJson(QJsonDocument::Compact)));
        } else {
          rpc_debug("  Me --> %ls: %s",
                 qUtf16Printable(Color("response (error)", fkShell::Red, fkShell::Bold)),
                 qUtf8Printable(QJsonDocument(*res).toJson(QJsonDocument::Compact)));
        }
      }
    }
  }

  return QVariant();
}

QVariant RpcLua::eval(const QString &lua) {
  // TODO; 可能根本不会去做
  return QVariant();
}

QString RpcLua::getConnectionInfo() const {
  auto process = dynamic_cast<QProcess *>(socket);

  if (process) {
    auto pid = process->processId();
    auto ret = QString("PID %1").arg(pid);

#ifdef Q_OS_LINUX
    // 若为Linux，附送RSS信息
    QFile f(QString("/proc/%1/statm").arg(pid));
    if (f.open(QIODevice::ReadOnly)) {
      const QList<QByteArray> parts = f.readAll().split(' ');
      const long pageSize = sysconf(_SC_PAGESIZE);
      auto mem_mib = (parts[1].toLongLong() * pageSize) / (1024.0 * 1024.0);
      ret += QString::asprintf(" (RSS = %.2f MiB)", mem_mib);
    }
#endif

    return ret;
  } else {
    return "unknown";
  }
}
