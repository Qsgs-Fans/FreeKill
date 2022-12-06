#include "qmlbackend.h"
#include "server.h"
#include "client.h"
#include "util.h"

QmlBackend *Backend;

QmlBackend::QmlBackend(QObject* parent)
  : QObject(parent)
{
  Backend = this;
  engine = nullptr;
  rsa = RSA_new();
  parser = fkp_new_parser();
}

QmlBackend::~QmlBackend()
{
  Backend = nullptr;
  RSA_free(rsa);
  fkp_close(parser);
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

  client->connectToHost(addr, port);
}

void QmlBackend::quitLobby()
{
  if (ClientInstance)
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
    qCritical() << result;
    lua_pop(L, 1);
    return "";
  }
  lua_pop(L, 1);
  return QString(result);
}

void QmlBackend::pushLuaValue(lua_State *L, QVariant v) {
  QVariantList list;
  switch (v.typeId()) {
    case QMetaType::Bool:
      lua_pushboolean(L, v.toBool());
      break;
    case QMetaType::Int:
    case QMetaType::UInt:
      lua_pushinteger(L, v.toInt());
      break;
    case QMetaType::Double:
      lua_pushnumber(L, v.toDouble());
      break;
    case QMetaType::QString:
      lua_pushstring(L, v.toString().toUtf8().data());
      break;
    case QMetaType::QVariantList:
      lua_newtable(L);
      list = v.toList();
      for (int i = 1; i <= list.length(); i++) {
        lua_pushinteger(L, i);
        pushLuaValue(L, list[i - 1]);
        lua_settable(L, -3);
      }
      break;
    default:
      qCritical() << "cannot handle QVariant type" << v.typeId();
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
    qCritical() << result;
    lua_pop(L, 1);
    return "";
  }
  lua_pop(L, 1);
  return QString(result);
}

QString QmlBackend::pubEncrypt(const QString &key, const QString &data) {
  BIO *keyio = BIO_new_mem_buf(key.toLatin1().data(), -1);
  PEM_read_bio_RSAPublicKey(keyio, &rsa, NULL, NULL);
  BIO_free_all(keyio);

  unsigned char buf[RSA_size(rsa)];
  RSA_public_encrypt(data.length(), (const unsigned char *)data.toUtf8().data(),
    buf, rsa, RSA_PKCS1_PADDING);
  return QByteArray::fromRawData((const char *)buf, RSA_size(rsa)).toBase64();
}

QString QmlBackend::loadConf() {
  QFile conf("freekill.client.config.json");
  if (!conf.exists()) {
    conf.open(QIODevice::WriteOnly);
    static const char *init_conf = "{\
      \"winWidth\": 960,\
      \"winHeight\": 540,\
      \"lastLoginServer\": \"127.0.0.1\",\
      \"savedPassword\": {\
        \"127.0.0.1\": {\
          \"username\": \"player\",\
          \"password\": \"\",\
          \"shorten_password\": \"\"\
        }\
      }\
    }";
    conf.write(init_conf);
    return init_conf;
  }
  conf.open(QIODevice::ReadOnly);
  return conf.readAll();
}

void QmlBackend::saveConf(const QString &conf) {
  QFile c("freekill.client.config.json");
  c.open(QIODevice::WriteOnly);
  c.write(conf.toUtf8());
}

void QmlBackend::parseFkp(const QString &fileName) {
  if (!QFile::exists(fileName)) {
//    errorEdit->setText(tr("File does not exist!"));
    return;
  }
  QString cwd = QDir::currentPath();

  QStringList strlist = fileName.split('/');
  QString shortFileName = strlist.last();
  strlist.removeLast();
  QString path = strlist.join('/');
  QDir::setCurrent(path);

  bool error = fkp_parse(
    parser,
    shortFileName.toUtf8().data(),
    FKP_QSAN_LUA
  );
/*  setError(error);

  if (error) {
    QStringList tmplist = shortFileName.split('.');
    tmplist.removeLast();
    QString fName = tmplist.join('.') + "-error.txt";
    if (!QFile::exists(fName)) {
      errorEdit->setText(tr("Unknown compile error."));
    } else {
      QFile f(fName);
      f.open(QIODevice::ReadOnly);
      errorEdit->setText(f.readAll());
      f.remove();
    }
  } else {
    errorEdit->setText(tr("Successfully compiled chosen file."));
  }
*/
  QDir::setCurrent(cwd);
}

static void copyFkpHash2QHash(QHash<QString, QString> &dst, fkp_hash *from) {
  dst.clear();
  for (size_t i = 0; i < from->capacity; i++) {
    if (from->entries[i].key != NULL) {
      dst[from->entries[i].key] = QString((const char *)from->entries[i].value);
    }
  }
}

void QmlBackend::readHashFromParser() {
  copyFkpHash2QHash(generals, parser->generals);
  copyFkpHash2QHash(skills, parser->skills);
  copyFkpHash2QHash(marks, parser->marks);
}

QString QmlBackend::calcFileMD5() {
  return ::calcFileMD5();
}

