// SPDX-License-Identifier: GPL-3.0-or-later

#include "ui/qmlbackend.h"
#include <qjsondocument.h>
#include <qjsonobject.h>

#ifndef FK_SERVER_ONLY
#include <QAudioOutput>
#include <QNetworkDatagram>
#include <QDnsLookup>

#include <QClipboard>
#include <QMediaPlayer>
#include <QMessageBox>
#include <QAbstractButton>
#include <QtConcurrent>
#endif

#include <cstdlib>
#include "server/server.h"
#include "client/client.h"
#include "client/clientplayer.h"
#include "client/replayer.h"
#include "core/util.h"
#include "core/c-wrapper.h"
#include "network/router.h"

QmlBackend *Backend = nullptr;

QmlBackend::QmlBackend(QObject *parent) : QObject(parent) {
  Backend = this;
#ifndef FK_SERVER_ONLY
  engine = nullptr;
  replayer = nullptr;
  udpSocket = new QUdpSocket(this);
  udpSocket->bind(0);
  connect(udpSocket, &QUdpSocket::readyRead,
          this, &QmlBackend::readPendingDatagrams);
  connect(this, &QmlBackend::dialog, this, &QmlBackend::showDialog);
#endif
}

QmlBackend::~QmlBackend() {
  Backend = nullptr;
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

QJsonObject QmlBackend::readJsonObjectFromFile(const QString &file) {
  QJsonObject jsonObject;
  QString s = file;

#ifdef Q_OS_WIN
  if (s.startsWith("file:///"))
    s.replace(0, 8, "file://");
#endif

  // Open the file
  QFile jsonFile(QUrl(s).path());
  if (!jsonFile.open(QIODevice::ReadOnly)) {
    qWarning() << "Failed to open file:" << file;
    return jsonObject; // Return empty object on failure
  }

  // Read the file content
  QByteArray jsonData = jsonFile.readAll();
  jsonFile.close();

  // Parse the JSON data
  QJsonParseError parseError;
  QJsonDocument jsonDoc = QJsonDocument::fromJson(jsonData, &parseError);

  if (parseError.error != QJsonParseError::NoError) {
    qWarning() << "Failed to parse JSON:" << parseError.errorString();
    return jsonObject; // Return empty object on parse error
  }

  if (!jsonDoc.isObject()) {
    qWarning() << "JSON document is not an object";
    return jsonObject; // Return empty object if not a JSON object
  }

  return jsonDoc.object();
}

#ifndef FK_SERVER_ONLY

QQmlApplicationEngine *QmlBackend::getEngine() const { return engine; }

void QmlBackend::setEngine(QQmlApplicationEngine *engine) {
  this->engine = engine;
}

void QmlBackend::startServer(ushort port) {
  if (!ServerInstance) {
    Server *server = new Server(nullptr);

    if (!server->listen(QHostAddress::Any, port)) {
      server->deleteLater();
      emit notifyUI("ErrorMsg", tr("Cannot start server!"));
    }
  }
}

static ClientPlayer dummyPlayer(0, nullptr);

void QmlBackend::joinServer(QString address, ushort port) {
  if (ClientInstance != nullptr)
    return;

  auto future = QtConcurrent::run([&] {
    auto ret = new Client;
    ret->moveToThread(qApp->thread());
    return ret;
  });
  QFutureWatcher<Client *> watcher;
  watcher.setFuture(future);

  QEventLoop loop;
  connect(&watcher, &QFutureWatcher<Client *>::finished, &loop, &QEventLoop::quit);
  loop.exec();

  auto client = future.result();
  client->setParent(this);
  connect(client, &Client::notifyUI, this, &QmlBackend::notifyUI);
  engine->rootContext()->setContextProperty("ClientInstance", client);
  engine->rootContext()->setContextProperty("Self", client->getSelf());
  connect(client, &Client::destroyed, this, [=, this] {
    engine->rootContext()->setContextProperty("Self", &dummyPlayer);
    engine->rootContext()->setContextProperty("ClientInstance", nullptr);
  });
  connect(client, &Client::error_message, this, [=, this](const QString &msg) {
    if (replayer) {
      emit replayerShutdown();
    }
    client->deleteLater();
    emit notifyUI("ErrorMsg", msg);
    emit notifyUI("BackToStart", "[]");
  });
  connect(client, &Client::self_changed, this, [=, this] {
    engine->rootContext()->setContextProperty("Self", client->getSelf());
  });
  connect(client, &Client::toast_message, this, &QmlBackend::showToast);

  /*
  QString addr = "127.0.0.1";
  ushort port = 9527u;

  if (address.contains(QChar(':'))) {
    QStringList texts = address.split(QChar(':'));
    addr = texts.value(0);
    port = texts.value(1).toUShort();
  } else {
    addr = address;
    // SRV解析查询
    QDnsLookup *dns = new QDnsLookup(QDnsLookup::SRV, "_freekill._tcp." + addr);
    QEventLoop eventLoop;
    // 阻塞的SRV解析查询回调
    connect(dns, &QDnsLookup::finished,[&eventLoop](void){
        eventLoop.quit();
    });
    dns->lookup();
    eventLoop.exec();
    if (dns->error() == QDnsLookup::NoError) { // SRV解析成功
      const auto records = dns->serviceRecords();
      const QDnsServiceRecord &record = records.first();
      QHostInfo host = QHostInfo::fromName(record.target());
      if (host.error() == QHostInfo::NoError) { // 主机解析成功
          addr = host.addresses().first().toString();
          port = record.port();
      }
    }
  }
  */

  client->connectToHost(address, port);
}

void QmlBackend::quitLobby(bool close) {
  if (ClientInstance)
    delete ClientInstance;
  // if (ServerInstance && close)
  //   ServerInstance->deleteLater();
}

QString QmlBackend::translate(const QString &src) {
  if (!ClientInstance)
    return src;

  auto L = ClientInstance->getLua();
  auto bytes = src.toUtf8();
  return L->call("Translate", { bytes }).toString();
}

QVariant QmlBackend::callLuaFunction(const QString &func_name,
                                    QVariantList params) {
  if (!ClientInstance) return QVariantMap();

  auto L = ClientInstance->getLua();
  return L->call(func_name, params);
}

QVariant QmlBackend::evalLuaExp(const QString &lua) {
  if (!ClientInstance) return QVariantMap();

  auto L = ClientInstance->getLua();
  return L->eval(lua);
}

static QString touchAndRead(const QString &fname, QString init_conf) {
  QFile conf(fname);
  if (!conf.exists()) {
    if (!conf.open(QIODevice::WriteOnly)) return init_conf;
    conf.write(init_conf.toUtf8());
    conf.close();
    return init_conf;
  }
  if (!conf.open(QIODevice::ReadOnly)) return init_conf;
  auto ret = conf.readAll();
  conf.close();
  return ret;
}

QString QmlBackend::getPublicServerList() {
  // TODO: Download new JSON via http
  return touchAndRead("server-list.json", "[]");
}

QString QmlBackend::loadConf() {
  return touchAndRead("freekill.client.config.json", "{}");
}

QString QmlBackend::loadTips() {
  return touchAndRead("waiting_tips.txt", "转啊~ 转啊~");
}

void QmlBackend::saveConf(const QString &conf) {
  QFile c("freekill.client.config.json");
  if (!c.open(QIODevice::WriteOnly)) return;
  c.write(conf.toUtf8());
  c.close();
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

#ifdef Q_OS_ANDROID
  QJniObject::callStaticMethod<void>("org/notify/FreeKill/Helper", "PlaySound",
      "(Ljava/lang/String;F)V", QJniObject::fromString(fname).object<jstring>(),
      (float)(m_volume / 100));
#else
  if (maxConcurrentPlayback < 0) return;
  auto player = new QMediaPlayer;
  auto output = new QAudioOutput;
  maxConcurrentPlayback--;

  // 避免windows掉帧 使用线程池
  auto future = QtConcurrent::run([=, this] {
    player->setAudioOutput(output);
    player->setSource(QUrl::fromLocalFile(fname));
    output->setVolume(m_volume / 100);

    connect(player, &QMediaPlayer::playbackStateChanged, this, [=, this] {
      auto state = player->playbackState();
      if (state != QMediaPlayer::PlayingState) {
        player->deleteLater();
        output->deleteLater();
        maxConcurrentPlayback++;
      }
    });

    player->play();
  });
  Q_UNUSED(future);
#endif
}

void QmlBackend::copyToClipboard(const QString &s) {
  QGuiApplication::clipboard()->setText(s);
}

QString QmlBackend::readClipboard() {
  return QGuiApplication::clipboard()->text();
}

void QmlBackend::detectServer() {
  static const char *ask_str = "fkDetectServer";
  udpSocket->writeDatagram(ask_str,
      strlen(ask_str),
      QHostAddress::Broadcast,
      9527);
}

void QmlBackend::getServerInfo(const QString &address, ushort port) {
  QString addr = address;
  // ushort port = 9527u;
  static const char *ask_str = "fkGetDetail,";

  QByteArray ask(ask_str);
  ask.append(address.toLatin1());
  ask.append(QString(",%1").arg(port).toUtf8());

  if (QHostAddress(addr).isNull()) { // 不是ip？考虑解析域名
    QHostInfo::lookupHost(addr, this, [=, this](const QHostInfo &host) {
      if (host.error() == QHostInfo::NoError) {
        udpSocket->writeDatagram(ask, ask.size(),
            host.addresses().first(), port);
      }
      else if (host.error() == QHostInfo::HostNotFound
        && !address.contains(QChar(':'))){ // 直接解析主机失败，尝试获取其SRV记录
        QDnsLookup* dns = new QDnsLookup(QDnsLookup::SRV, "_freekill._tcp." + addr);
        // SRV解析回调
        connect(dns, &QDnsLookup::finished, this, [=, this]() {
          if (dns->error() != QDnsLookup::NoError) {
            return;
          }
          // SRV解析成功，再次进行解析主机
          const auto records = dns->serviceRecords();
          if (records.isEmpty()) {
            return;
          }
          const QDnsServiceRecord &record = records.first();
          // 获取到真实端口
          QHostInfo::lookupHost(record.target(), [=, this](const QHostInfo &host) {
            if (host.error() == QHostInfo::NoError) {
              // 获取到真实地址
              udpSocket->writeDatagram(ask, ask.size(),
                host.addresses().first(), record.port());
            }
          });
        });
        // SRV解析查询
        dns->lookup();
      }
    });
  } else {
    udpSocket->writeDatagram(ask, ask.size(),
        QHostAddress(addr), port);
  }
}

void QmlBackend::readPendingDatagrams() {
  while (udpSocket->hasPendingDatagrams()) {
    QNetworkDatagram datagram = udpSocket->receiveDatagram();
    if (datagram.isValid()) {
      auto data = datagram.data();
      auto addr = datagram.senderAddress();
      // auto port = datagram.senderPort();

      if (data == "me") {
        emit notifyUI("ServerDetected", addr.toString());
      } else {
        auto arr = QJsonDocument::fromJson(data).array();
        emit notifyUI("GetServerDetail", JsonArray2Bytes(arr));
      }
    }
  }
}

void QmlBackend::showDialog(const QString &type, const QString &text, const QString &orig) {
  //static const QString title = tr("FreeKill") + " v" + FK_VERSION;
  QMessageBox *box = nullptr;
  if (type == "critical") {
    box = new QMessageBox(QMessageBox::Critical, text, text, QMessageBox::Ok);
    connect(box, &QMessageBox::buttonClicked, box, &QObject::deleteLater);
  } else if (type == "info") {
    box = new QMessageBox(QMessageBox::Information, text, text, QMessageBox::Ok);
    connect(box, &QMessageBox::buttonClicked, box, &QObject::deleteLater);
  } else if (type == "warning") {
    box = new QMessageBox(QMessageBox::Warning, text, text, QMessageBox::Ok);
    connect(box, &QMessageBox::buttonClicked, box, &QObject::deleteLater);
  }

  if (box) {
    if (!orig.isEmpty()) {
      auto bytes = orig.toLocal8Bit().prepend("help: ");
      if (tr(bytes) != bytes) box->setInformativeText(tr(bytes));
    }
    box->setWindowModality(Qt::NonModal);
    box->show();
  }
}

void QmlBackend::askFixResource() {
#if defined(Q_OS_ANDROID) || defined(Q_OS_LINUX)
  auto box = new QMessageBox(QMessageBox::Question, tr("fix resource"),
      tr("help: fix resource"), QMessageBox::Ok | QMessageBox::Cancel);
  connect(box, &QMessageBox::accepted, box, []() {
      QFile::remove("fk_ver"); qApp->exit(); });
  connect(box, &QMessageBox::finished, box, &QObject::deleteLater);
  box->setWindowModality(Qt::NonModal);
  box->show();
#endif
}

void QmlBackend::removeRecord(const QString &fname) {
  QFile::remove("recording/" + fname);
}

void QmlBackend::playRecord(const QString &fname) {
  auto replayer = new Replayer(this, fname);
  setReplayer(replayer);
  connect(replayer, &Replayer::destroyed, this, [=, this] {
    setReplayer(nullptr);
  });
  replayer->start();
}

void QmlBackend::playBlobRecord(int id) {
  auto replayer = new Replayer(this, id);
  setReplayer(replayer);
  connect(replayer, &Replayer::destroyed, this, [=, this] {
    setReplayer(nullptr);
  });
  replayer->start();
}

QString QmlBackend::saveBlobRecordToFile(int id) {
  auto result = ClientInstance->database().select(QString(
    "SELECT hex(recording) as r FROM myGameRecordings WHERE id = %1;").arg(id));
  auto raw = QByteArray::fromHex(result[0]["r"].toLatin1());
  auto data = qUncompress(raw);
  auto arr = QCborValue::fromCbor(data).toArray();
  auto fileName = arr[1].toByteArray();
  ClientInstance->saveRecord(data, fileName);
  return fileName;
}

void QmlBackend::reviewGameOverScene(int id) {
  auto result = ClientInstance->database().select(QString(
    "SELECT hex(room_data) as r FROM myGameRoomData WHERE id = %1;").arg(id));
  auto raw = QByteArray::fromHex(result[0]["r"].toLatin1());
  auto data = qUncompress(raw);
  ClientInstance->callLua("Observe", data);
}

Replayer *QmlBackend::getReplayer() const {
  return replayer;
}

void QmlBackend::setReplayer(Replayer *rep) {
  auto r = replayer;
  if (r) {
    r->disconnect(this);
    disconnect(r);
  }
  replayer = rep;
  if (rep) {
    connect(rep, &Replayer::duration_set, this, [this](int sec) {
        this->notifyUI("ReplayerDurationSet", QString::number(sec));
        });
    connect(rep, &Replayer::elasped, this, [this](int sec) {
        this->notifyUI("ReplayerElapsedChange", QString::number(sec));
        });
    connect(rep, &Replayer::speed_changed, this, [this](qreal speed) {
        this->notifyUI("ReplayerSpeedChange", QString::number(speed));
        });
    connect(this, &QmlBackend::replayerToggle, rep, &Replayer::toggle);
    connect(this, &QmlBackend::replayerSlowDown, rep, &Replayer::slowDown);
    connect(this, &QmlBackend::replayerSpeedUp, rep, &Replayer::speedUp);
    connect(this, &QmlBackend::replayerUniform, rep, &Replayer::uniform);
    connect(this, &QmlBackend::replayerShutdown, rep, &Replayer::shutdown);
  }
}

void QmlBackend::controlReplayer(QString type) {
  if (type == "toggle") {
    emit replayerToggle();
  } else if (type == "speedup") {
    emit replayerSpeedUp();
  } else if (type == "slowdown") {
    emit replayerSlowDown();
  } else if (type == "uniform") {
    emit replayerUniform();
  } else if (type == "shutdown") {
    emit replayerShutdown();
  }
}

QJsonObject QmlBackend::getRequestData() const {
  auto obj = QJsonObject();
  auto router = ClientInstance->getRouter();
  obj["id"] = router->getRequestId();
  obj["timeout"] = router->getTimeout();
  auto timestamp = router->getRequestTimestamp();
  // 因为timestamp是服务器发来的时间，如果自己比服务器的时钟快的话，那么就得加上这个差值才行
  timestamp += ClientInstance->getServerLag();
  obj["timestamp"] = timestamp;
  return obj;
}

#endif
