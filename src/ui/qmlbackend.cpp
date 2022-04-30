#include "qmlbackend.h"
#include "server.h"
#include "client.h"

QmlBackend *Backend;

QmlBackend::QmlBackend(QObject* parent)
  : QObject(parent)
{
  Backend = this;
  engine = nullptr;
}

QQmlApplicationEngine *QmlBackend::getEngine() const
{
  return engine;
}

void QmlBackend::setEngine(QQmlApplicationEngine *engine)
{
  this->engine = engine;
}

void QmlBackend::startServer(ushort port)
{
  if (!ServerInstance) {
    Server *server = new Server(this);

    if (!server->listen(QHostAddress::Any, port)) {
      server->deleteLater();
      emit notifyUI("ErrorMsg", tr("Cannot start server!"));
    }
  }
}

void QmlBackend::joinServer(QString address)
{
  if (ClientInstance != nullptr) return;
  Client *client = new Client(this);
  connect(client, &Client::error_message, [this, client](const QString &msg){
    client->deleteLater();
    emit notifyUI("ErrorMsg", msg);
    emit notifyUI("BackToStart", "[]");
  });
  QString addr = "127.0.0.1";
  ushort port = 9527u;

  if (address.contains(QChar(':'))) {
    QStringList texts = address.split(QChar(':'));
    addr = texts.value(0);
    port = texts.value(1).toUShort();
  } else {
    addr = address;
  }

  client->connectToHost(QHostAddress(addr), port);
}

void QmlBackend::quitLobby()
{
  delete ClientInstance;
}

void QmlBackend::emitNotifyUI(const QString &command, const QString &jsonData) {
  emit notifyUI(command, jsonData);
}

void QmlBackend::cd(const QString &path) {
  QDir::setCurrent(path);
}

QStringList QmlBackend::ls(const QString &dir) {
  return QDir(dir).entryList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot);
}

QString QmlBackend::pwd() {
  return QDir::currentPath();
}

bool QmlBackend::exists(const QString &file) {
  return QFile::exists(file);
}

bool QmlBackend::isDir(const QString &file) {
  return QFileInfo(file).isDir();
}

QString QmlBackend::translate(const QString &src) {
  lua_State *L = ClientInstance->getLuaState();
  lua_getglobal(L, "Translate");
  lua_pushstring(L, src.toUtf8().data());

  int err = lua_pcall(L, 1, 1, 0);
  const char *result = lua_tostring(L, -1);
  if (err) {
    qDebug() << result;
    lua_pop(L, 1);
    return "";
  }
  lua_pop(L, 1);
  return QString(result);
}

void QmlBackend::pushLuaValue(lua_State *L, QVariant v) {
  QVariantList list;
  switch(v.type()) {
    case QVariant::Bool:
      lua_pushboolean(L, v.toBool());
      break;
    case QVariant::Int:
    case QVariant::UInt:
      lua_pushinteger(L, v.toInt());
      break;
    case QVariant::Double:
      lua_pushnumber(L, v.toDouble());
      break;
    case QVariant::String:
      lua_pushstring(L, v.toString().toUtf8().data());
      break;
    case QVariant::List:
      lua_newtable(L);
      list = v.toList();
      for (int i = 1; i <= list.length(); i++) {
        lua_pushinteger(L, i);
        pushLuaValue(L, list[i - 1]);
        lua_settable(L, -3);
      }
      break;
    default:
      qDebug() << "cannot handle QVariant type" << v.type();
      lua_pushnil(L);
      break;
  }
}

QString QmlBackend::callLuaFunction(const QString &func_name,
                                    QVariantList params)
{
  lua_State *L = ClientInstance->getLuaState();
  lua_getglobal(L, func_name.toLatin1().data());

  foreach (QVariant v, params) {
    pushLuaValue(L, v);
  }

  int err = lua_pcall(L, params.length(), 1, 0);
  const char *result = lua_tostring(L, -1);
  if (err) {
    qDebug() << result;
    lua_pop(L, 1);
    return "";
  }
  lua_pop(L, 1);
  return QString(result);
}
