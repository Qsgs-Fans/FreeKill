// SPDX-License-Identifier: GPL-3.0-or-later

#include "client/client.h"
#include "client/clientplayer.h"
#include "core/c-wrapper.h"
#include "core/util.h"
#include "server/server.h"
#include "network/client_socket.h"
#include "network/router.h"

#include <openssl/aes.h>
#include <openssl/pem.h>

Client *ClientInstance = nullptr;

struct ClientPrivate {
  RSA *rsa;
  ClientPrivate() { rsa = RSA_new(); }
  ~ClientPrivate() { RSA_free(rsa); }
};

Client::Client(QObject *parent) : QObject(parent) {
  ClientInstance = this;
  self = new ClientPlayer(0, this);

  ClientSocket *socket = new ClientSocket;
  connect(socket, &ClientSocket::error_message, this, &Client::error_message);
  router = new Router(this, socket, Router::TYPE_CLIENT);
  connect(router, &Router::notification_got, this, [=](const QString &c, const QString &j) {
    callLua(c, j, false);
  });
  connect(router, &Router::request_got, this, [=](const QString &c, const QString &j) {
    callLua(c, j, true);
  });

  p_ptr = new ClientPrivate;

  L = new Lua;
  if (QFile::exists("packages/freekill-core") &&
      !GetDisabledPacks().contains("freekill-core")) {
    // 危险的cd操作，记得在lua中切回游戏根目录
    QDir::setCurrent("packages/freekill-core");
  }

  L->dofile("lua/freekill.lua");
  L->dofile("lua/client/client.lua");
  L->call("CreateLuaClient", { QVariant::fromValue(this) });
}

Client::~Client() {
  ClientInstance = nullptr;
  delete L;
  delete p_ptr;
  router->getSocket()->disconnectFromHost();
  router->getSocket()->deleteLater();
}

void Client::connectToHost(const QString &server, ushort port) {
  start_connent_timestamp = QDateTime::currentMSecsSinceEpoch();
  router->getSocket()->connectToHost(server, port);
}

QString Client::pubEncrypt(const QString &key, const QString &data) {
  // 在用公钥加密口令时，也随机生成AES密钥/IV，并随着口令一起加密
  // AES密钥和IV都是固定16字节的，所以可以放在开头
  auto key_bytes = key.toLatin1();
  BIO *keyio = BIO_new_mem_buf(key_bytes.constData(), -1);
  RSA_free(p_ptr->rsa);
  p_ptr->rsa = PEM_read_bio_RSAPublicKey(keyio, NULL, NULL, NULL);
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

  unsigned char buf[RSA_size(p_ptr->rsa)];
  RSA_public_encrypt(data.length() + 32,
                     (const unsigned char *)data_bytes.constData(), buf, p_ptr->rsa,
                     RSA_PKCS1_PADDING);
  return QByteArray::fromRawData((const char *)buf, RSA_size(p_ptr->rsa)).toBase64();
}

void Client::sendSetupPacket(const QString &pubkey) {
  auto cipherText = pubEncrypt(pubkey, password);
  auto md5 = calcFileMD5();

  QJsonArray arr;
  arr << screenName << cipherText << md5 << FK_VERSION << GetDeviceUuid();
  notifyServer("Setup", JsonArray2Bytes(arr));
}

void Client::setupServerLag(qint64 server_time) {
  auto now = QDateTime::currentMSecsSinceEpoch();
  auto ping = now - start_connent_timestamp;
  auto lag = now - server_time;
  server_lag = lag - ping / 2;
}

qint64 Client::getServerLag() const { return server_lag; }

void Client::setLoginInfo(const QString &username, const QString &password) {
  screenName = username;
  this->password = password;
}

void Client::replyToServer(const QString &command, const QString &jsonData) {
  int type = Router::TYPE_REPLY | Router::SRC_CLIENT | Router::DEST_SERVER;
  router->reply(type, command, jsonData);
}

void Client::notifyServer(const QString &command, const QString &jsonData) {
  int type =
      Router::TYPE_NOTIFICATION | Router::SRC_CLIENT | Router::DEST_SERVER;
  router->notify(type, command, jsonData);
}

void Client::callLua(const QString& command, const QString& json_data, bool isRequest) {
  L->call("ClientCallback", { QVariant::fromValue(this), command, json_data, isRequest });
}

ClientPlayer *Client::addPlayer(int id, const QString &name,
                                const QString &avatar) {
  ClientPlayer *player = new ClientPlayer(id);
  player->setScreenName(name);
  player->setAvatar(avatar);

  players[id] = player;
  return player;
}

void Client::removePlayer(int id) {
  ClientPlayer *p = players[id];
  p->deleteLater();
  players[id] = nullptr;
}

void Client::clearPlayers() { players.clear(); }

void Client::changeSelf(int id) {
  auto p = players[id];
  self = p ? p : self;
  emit self_changed();
}

Lua *Client::getLua() { return L; }

void Client::installAESKey(const QByteArray &key) {
  startWatchFiles();
  router->getSocket()->installAESKey(key);
}

void Client::saveRecord(const QString &json, const QString &fname) {
  if (!QDir("recording").exists()) {
    QDir(".").mkdir("recording");
  }
  QFile c("recording/" + fname + ".fk.rep");
  c.open(QIODevice::WriteOnly);
  c.write(qCompress(json.toUtf8()));
  c.close();
}

bool Client::isConsoleStart() const {
  if (!ClientInstance || !ServerInstance) {
    return false;
  }

  return router->isConsoleStart();
}

void Client::startWatchFiles() {
  if (!isConsoleStart()) return;
  if (!fsWatcher.files().empty()) return;
  QFile flist("flist.txt");
  if (!flist.open(QIODevice::ReadOnly)) {
    qCritical("Cannot open flist.txt. Won't watch files.");
    fsWatcher.addPath("fk_ver"); // dummy
  }
  auto md5pairs = flist.readAll().split(';');
  for (auto md5 : md5pairs) {
    if (md5.isEmpty()) continue;
    auto fname = md5.split('=')[0];
    if (fname.startsWith("packages") && fname.endsWith(".lua")) {
      fsWatcher.addPath(fname);
    }
  }
  connect(&fsWatcher, &QFileSystemWatcher::fileChanged, this,
      &Client::updateLuaFiles);
}

void Client::updateLuaFiles(const QString &path) {
  if (!isConsoleStart()) return;
  // Backend->showToast(tr("File %1 changed, reloading...").arg(path));
  emit toast_message(tr("File %1 changed, reloading...").arg(path));
  QThread::msleep(100);
  L->call("ReloadPackage", { path });
  notifyServer("PushRequest", QString("reloadpackage,%1").arg(path));

  // according to QT documentation
  if (!fsWatcher.files().contains(path) && QFile::exists(path)) {
    fsWatcher.addPath(path);
  }
}
