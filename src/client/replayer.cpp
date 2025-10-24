// SPDX-License-Identifier: GPL-3.0-or-later

#include "client/replayer.h"
#include "client/client.h"
#include "client/clientplayer.h"
#include "core/util.h"
#include "core/c-wrapper.h"

Replayer::Replayer(QObject *parent, const QString &filename) :
  QThread(parent), fileName(filename), roomSettings(""), origPlayerInfo(""),
  playing(true), killed(false), speed(1.0), uniformRunning(false)
{
  setObjectName("Replayer");

  auto s = filename;
#ifdef Q_OS_WIN
  if (s.startsWith("file:///"))
    s.replace(0, 8, "file://");
#endif
  QFile file(QUrl(s).path());
  file.open(QIODevice::ReadOnly);
  QByteArray raw = file.readAll();
  file.close();
  loadRawData(raw);
}

Replayer::Replayer(QObject *parent, int id) :
  QThread(parent), fileName(""), roomSettings(""), origPlayerInfo(""),
  playing(true), killed(false), speed(1.0), uniformRunning(false)
{
  setObjectName("Replayer");
  auto result = ClientInstance->database().select(QString(
    "SELECT hex(recording) as r FROM myGameRecordings WHERE id = %1;").arg(id));
  auto raw = QByteArray::fromHex(result[0]["r"].toLatin1());
  loadRawData(raw);
}

void Replayer::loadRawData(const QByteArray &raw) {
  auto data = qUncompress(raw);

  auto doc = QCborValue::fromCbor(data);
  auto arr = doc.toArray();
  if (arr.size() < 10) {
    return;
  }

  auto ver = arr[0].toByteArray();
  if (ver != FK_VERSION) {
    emit ClientInstance->toast_message(
      "Warning: Mismatch version of replay detected, which may cause crashes.");
  }

  roomSettings = arr[2].toByteArray();
  recordType = arr[5].toByteArray();

  for (auto v : arr) {
    if (!v.isArray()) {
      continue;
    }

    auto a = v.toArray();
    Pair *pair = new Pair;
    pair->elapsed = a[0].toInteger();
    pair->isRequest = a[1].toBool();
    pair->cmd = a[2].toByteArray();
    pair->jsonData = a[3].toByteArray();
    pairs << pair;
  }

  connect(this, &Replayer::command_parsed, this, [](const QByteArray &c, const QByteArray &j) {
    ClientInstance->callLua(c, j);
  });

  auto playerInfoRaw = arr[3].toByteArray();
  auto playerInfo = QCborValue::fromCbor(playerInfoRaw).toArray();
  auto self = ClientInstance->getSelf();
  origPlayerInfo = QCborArray({
    self->getId(), self->getScreenName(), self->getAvatar()
  }).toCborValue().toCbor();
  emit command_parsed("Setup", playerInfoRaw);
}

Replayer::~Replayer() {
  if (origPlayerInfo != "") {
    emit command_parsed("Setup", origPlayerInfo);
  }
  for (auto e : pairs) {
    delete e;
  }
}

int Replayer::getDuration() const {
  qint64 ret = (pairs.last()->elapsed - pairs.first()->elapsed) / 1000.0;
  return (int)ret;
}

qreal Replayer::getSpeed() {
  qreal speed;
  mutex.lock();
  speed = this->speed;
  mutex.unlock();
  return speed;
}

void Replayer::uniform() {
  mutex.lock();

  uniformRunning = !uniformRunning;

  mutex.unlock();
}

void Replayer::speedUp() {
  mutex.lock();

  if (speed < 16.0) {
    qreal inc = speed >= 2.0 ? 1.0 : 0.5;
    speed += inc;
    emit speed_changed(speed);
  }

  mutex.unlock();
}

void Replayer::slowDown() {
  mutex.lock();

  if (speed >= 1.0) {
    qreal dec = speed > 2.0 ? 1.0 : 0.5;
    speed -= dec;
    emit speed_changed(speed);
  }

  mutex.unlock();
}

void Replayer::toggle() {
  playing = !playing;
  if (playing)
    play_sem.release();
}

void Replayer::shutdown() {
  killed = true;
}

void Replayer::run() {
  qint64 last = 0;
  qint64 start = 0;

  if (roomSettings == "") {
    emit ClientInstance->toast_message("Invalid replay file.");
    deleteLater();
    return;
  }

  if (recordType == "normal") {
    auto connType = qApp->thread() == QThread::currentThread()
      ? Qt::DirectConnection : Qt::BlockingQueuedConnection;
    QMetaObject::invokeMethod(qApp, [&]() {
      emit command_parsed("EnterRoom", roomSettings);
    }, connType);

    emit command_parsed("StartGame", "\x40");
  }

  emit speed_changed(getSpeed());
  emit duration_set(getDuration());

  for (auto pair : pairs) {
    if (killed) {
      break;
    }

    if (pair->isRequest) {
      continue;
    }

    qint64 delay = pair->elapsed - last;
    if (uniformRunning) {
      delay = qMin(delay, 2000);
      if (delay > 500)
        delay = 2000;
    } else if (last == 0) {
      delay = 100;
    }
    last = pair->elapsed;
    if (start == 0) start = last;

    bool delayed = true;

    if (!pair->isRequest) {
      delay /= getSpeed();

      msleep(delay);
      emit elasped((pair->elapsed - start) / 1000);

      emit command_parsed(pair->cmd, pair->jsonData);

      if (!playing)
        play_sem.acquire();
    }
  }

  deleteLater();
}
