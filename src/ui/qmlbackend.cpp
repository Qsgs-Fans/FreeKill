// SPDX-License-Identifier: GPL-3.0-or-later

#include "qmlbackend.h"

#ifndef FK_SERVER_ONLY
#include <qaudiooutput.h>
#include <qmediaplayer.h>
#include <qrandom.h>

#include <QClipboard>
#include <QMediaPlayer>
#endif

#include <cstdlib>
#ifndef Q_OS_WASM
#include "server.h"
#endif
#include "client.h"
#include "util.h"

QmlBackend *Backend = nullptr;

QmlBackend::QmlBackend(QObject *parent) : QObject(parent) {
  Backend = this;
#ifndef FK_SERVER_ONLY
  engine = nullptr;
  rsa = RSA_new();
#endif
}

QmlBackend::~QmlBackend() {
  Backend = nullptr;
#ifndef FK_SERVER_ONLY
  RSA_free(rsa);
#endif
}

void QmlBackend::cd(const QString &path) { QDir::setCurrent(path); }

QStringList QmlBackend::ls(const QString &dir) {
  QString d = dir;
#ifdef Q_OS_WIN
  if (d.startsWith("file:///"))
    d.replace(0, 8, "file://");
#endif
  return QDir(QUrl(d).path())
      .entryList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot);
}

QString QmlBackend::pwd() { return QDir::currentPath(); }

bool QmlBackend::exists(const QString &file) {
  QString s = file;
#ifdef Q_OS_WIN
  if (s.startsWith("file:///"))
    s.replace(0, 8, "file://");
#endif
  return QFile::exists(QUrl(s).path());
}

bool QmlBackend::isDir(const QString &file) {
  return QFileInfo(QUrl(file).path()).isDir();
}

#ifndef FK_SERVER_ONLY

QQmlApplicationEngine *QmlBackend::getEngine() const { return engine; }

void QmlBackend::setEngine(QQmlApplicationEngine *engine) {
  this->engine = engine;
}

void QmlBackend::startServer(ushort port) {
#ifndef Q_OS_WASM
  if (!ServerInstance) {
    Server *server = new Server(this);

    if (!server->listen(QHostAddress::Any, port)) {
      server->deleteLater();
      emit notifyUI("ErrorMsg", tr("Cannot start server!"));
    }
  }
#endif
}

void QmlBackend::joinServer(QString address) {
  if (ClientInstance != nullptr)
    return;
  Client *client = new Client(this);
  connect(client, &Client::error_message, this, [=](const QString &msg) {
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

void QmlBackend::quitLobby() {
  if (ClientInstance)
    delete ClientInstance;
  // if (ServerInstance)
  //   delete ServerInstance;
}

void QmlBackend::emitNotifyUI(const QString &command, const QString &jsonData) {
  emit notifyUI(command, jsonData);
}

QString QmlBackend::translate(const QString &src) {
  if (!ClientInstance)
    return src;
  lua_State *L = ClientInstance->getLuaState();
  lua_getglobal(L, "Translate");
  auto bytes = src.toUtf8();
  lua_pushstring(L, bytes.data());

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
  case QMetaType::QString: {
    auto bytes = v.toString().toUtf8();
    lua_pushstring(L, bytes.data());
    break;
  }
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
                                    QVariantList params) {
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
  // 在用公钥加密口令时，也随机生成AES密钥/IV，并随着口令一起加密
  // AES密钥和IV都是固定16字节的，所以可以放在开头
  auto key_bytes = key.toLatin1();
  BIO *keyio = BIO_new_mem_buf(key_bytes.constData(), -1);
  PEM_read_bio_RSAPublicKey(keyio, &rsa, NULL, NULL);
  BIO_free_all(keyio);

  auto data_bytes = data.toUtf8();
  auto rand_generator = QRandomGenerator::securelySeeded();
  QByteArray aes_key_;
  for (int i = 0; i < 2; i++) {
    aes_key_.append(QByteArray::number(rand_generator.generate64(), 16));
  }
  if (aes_key_.length() < 32) {
    aes_key_.append(QByteArray("0").repeated(32 - aes_key_.length()));
  }

  aes_key = aes_key_;

  data_bytes.prepend(aes_key_);

  unsigned char buf[RSA_size(rsa)];
  RSA_public_encrypt(data.length() + 32,
                     (const unsigned char *)data_bytes.constData(), buf, rsa,
                     RSA_PKCS1_PADDING);
  return QByteArray::fromRawData((const char *)buf, RSA_size(rsa)).toBase64();
}

QString QmlBackend::loadConf() {
  QFile conf("freekill.client.config.json");
  if (!conf.exists()) {
    conf.open(QIODevice::WriteOnly);
    static const char *init_conf = "{}";
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

void QmlBackend::replyDelayTest(const QString &screenName,
                                const QString &cipher) {
  auto md5 = calcFileMD5();

  QJsonArray arr;
  arr << screenName << cipher << md5 << FK_VERSION;
  ClientInstance->notifyServer("Setup", JsonArray2Bytes(arr));
}

void QmlBackend::playSound(const QString &name, int index) {
  QString fname(name);
  if (index == -1) {
    int i = 1;
    while (true) {
      if (!QFile::exists(name + QString::number(i) + ".mp3")) {
        i--;
        break;
      }
      i++;
    }

    index = i == 0 ? 0 : (QRandomGenerator::global()->generate()) % i + 1;
  }
  if (index != 0)
    fname = fname + QString::number(index) + ".mp3";
  else
    fname = fname + ".mp3";

  if (!QFile::exists(fname))
    return;

  auto player = new QMediaPlayer;
  auto output = new QAudioOutput;
  player->setAudioOutput(output);
  player->setSource(QUrl::fromLocalFile(fname));
  output->setVolume(m_volume / 100);
  connect(player, &QMediaPlayer::playbackStateChanged, this, [=]() {
    if (player->playbackState() == QMediaPlayer::StoppedState) {
      player->deleteLater();
      output->deleteLater();
    }
  });
  player->play();
}

void QmlBackend::copyToClipboard(const QString &s) {
  QGuiApplication::clipboard()->setText(s);
}

void QmlBackend::setAESKey(const QString &key) { aes_key = key; }

QString QmlBackend::getAESKey() const { return aes_key; }

void QmlBackend::installAESKey() {
  ClientInstance->installAESKey(aes_key.toLatin1());
}

#endif
