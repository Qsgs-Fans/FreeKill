#include "server/rpc-lua/rpc-lua.h"
#include "server/rpc-lua/jsonrpc.h"
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
static void rpc_debug(const char *fmt, Args... args) {
  if constexpr (_EnableRpcDebug) {
    qDebug(fmt, args...);
  }
}

static QJsonValue decodeBase64Strings(const QJsonValue &val) {
  if (val.isString()) {
    QByteArray decoded = QByteArray::fromBase64(val.toString().toUtf8());
    QString decodedStr = QString::fromUtf8(decoded);
    return QJsonValue(decodedStr);
  } else if (val.isObject()) {
    QJsonObject obj = val.toObject();
    for (auto it = obj.begin(); it != obj.end(); ++it) {
      it.value() = decodeBase64Strings(it.value());
    }
    return obj;
  } else if (val.isArray()) {
    QJsonArray arr = val.toArray();
    for (int i = 0; i < arr.size(); ++i) {
      arr[i] = decodeBase64Strings(arr[i]);
    }
    return arr;
  } else {
    return val;
  }
}

static QByteArray mapToJson(const QCborValue &val, bool decode) {
  auto obj = val.toJsonValue().toObject();
  if (decode) {
    obj = decodeBase64Strings(obj).toObject();
  }
  return QJsonDocument(obj).toJson(QJsonDocument::Compact);
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
  env.insert("FK_RPC_MODE", "cbor");
  process->setProcessEnvironment(env);
  if (QFile::exists("packages/freekill-core") &&
    !Pacman->getDisabledPacks().contains("freekill-core")) {
    process->setWorkingDirectory("packages/freekill-core");
  }
  process->start("lua5.4", { "lua/server/rpc/entry.lua" });

  // 默认等待30s 实际上加载一次差不多3000ms左右 很慢了 可能需要加大
  // 把hello world的notification读了，或者可以加更严的判定
  process->waitForReadyRead();
  QCborStreamReader reader(process);
  auto msg = QCborValue::fromCbor(reader); //process->readLine();
  if (msg.isMap()) {
    rpc_debug("Me <-- %s", qUtf8Printable(mapToJson(msg.toMap(), true)));
    //qUtf16Printable(Color("Hello, world!", fkShell::Blue)));
  } else {
    // TODO: throw, then retry
    qCritical("Lua5.4 closed too early.");
    qCritical("  stderr: %s", qUtf8Printable(process->readAllStandardError()));
    qCritical("  stdout: %s", qUtf8Printable(process->readAllStandardOutput()));
  }
}

RpcLua::~RpcLua() {
  call("bye");
  rpc_debug("Me --> %ls", qUtf16Printable(Color("Say goodbye", fkShell::Blue)));
  if (socket->waitForReadyRead(15000)) {
    auto msg = socket->readLine();
    rpc_debug("Me <-- %s", qUtf8Printable(msg));
    //qUtf16Printable(Color("Byebye", fkShell::Blue)));

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

static QCborMap dummyObj;

QVariant RpcLua::call(const QString &func_name, QVariantList params) {
  QMutexLocker locker(&io_lock);

  // 如同Lua中callRpc那样
  QCborArray arr;
  for (auto v : params) arr << QCborValue::fromVariant(v);
  auto req = JsonRpc::request(func_name, arr);
  auto id = req[JsonRpc::Id].toInteger();
  socket->write(req.toCborValue().toCbor());
  socket->waitForBytesWritten(15000);
  rpc_debug("Me --> %s", qUtf8Printable(mapToJson(req, false)));

  while (socket->bytesAvailable() > 0 || socket->waitForReadyRead(15000)) {
    if (!socket->isOpen()) break;

    auto bytes = socket->readAll();
    QCborValue doc;
    do {
      QCborStreamReader reader(bytes);
      doc = QCborValue::fromCbor(reader);
      auto err = reader.lastError();
      // rpc_debug("  *DBG* Me <-- %ls {%s}", qUtf16Printable(err.toString()), qUtf8Printable(bytes.toHex()));
      if (err == QCborError::EndOfFile) {
        socket->waitForReadyRead(100);
        bytes += socket->readAll();
        reader.clear(); reader.addData(bytes);
        continue;
      } else if (err == QCborError::NoError) {
        break;
      } else {
        rpc_debug("Me <-- Unrecoverable reader error: %ls", qUtf16Printable(err.toString()));
        return QVariant();
      }
    } while (true);

    auto packet = doc.toMap();
    if (packet[JsonRpc::JsonRpc].toByteArray() == "2.0" && packet[JsonRpc::Id] == id && !packet[JsonRpc::Method].isByteArray()) {
      rpc_debug("Me <-- %s", qUtf8Printable(mapToJson(packet, true)));
      return packet[JsonRpc::Result].toVariant();
    } else {
      rpc_debug("  Me <-- %s", qUtf8Printable(mapToJson(packet, true)));
      auto res = JsonRpc::serverResponse(methods, packet);
      if (res) {
        socket->write(res->toCborValue().toCbor());
        socket->waitForBytesWritten(15000);
        rpc_debug("  Me --> %s", qUtf8Printable(mapToJson(*res, false)));
      }
    }
  }

  rpc_debug("Me <-- IO read timeout. Is Lua process died?");
  qDebug() << dynamic_cast<QProcess *>(socket)->readAllStandardError();
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
