// SPDX-License-Identifier: GPL-3.0-or-later

#include "replayer.h"
#include "client.h"
#include "qmlbackend.h"
#include "util.h"

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

  auto data = qUncompress(raw);

  auto doc = QJsonDocument::fromJson(data);
  auto arr = doc.array();
  if (arr.count() < 10) {
    return;
  }

  auto ver = arr[0].toString();
  if (ver != FK_VERSION) {
    Backend->showToast("Warning: Mismatch version of replay detected, which may cause crashes.");
  }

  roomSettings = arr[2].toString();

  foreach (auto v, arr) {
    if (!v.isArray()) {
      continue;
    }

    auto a = v.toArray();
    Pair *pair = new Pair;
    pair->elapsed = a[0].toInteger();
    pair->isRequest = a[1].toBool();
    pair->cmd = a[2].toString();
    pair->jsonData = a[3].toString();
    pairs << pair;
  }

  connect(this, &Replayer::command_parsed, ClientInstance, &Client::processReplay);

  auto playerInfoRaw = arr[3].toString();
  auto playerInfo = QJsonDocument::fromJson(playerInfoRaw.toUtf8()).array();
  if (playerInfo[0].toInt() != Self->getId()) {
    origPlayerInfo = JsonArray2Bytes({ Self->getId(), Self->getScreenName(), Self->getAvatar() });
    emit command_parsed("Setup", playerInfoRaw);
  }
}

Replayer::~Replayer() {
  if (origPlayerInfo != "") {
    emit command_parsed("Setup", origPlayerInfo);
  }
  Backend->setReplayer(nullptr);
  foreach (auto e, pairs) {
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
    Backend->showToast("Invalid replay file.");
    deleteLater();
    return;
  }

  emit command_parsed("EnterRoom", roomSettings);
  emit command_parsed("StartGame", "");

  emit speed_changed(getSpeed());
  emit duration_set(getDuration());

  foreach (auto pair, pairs) {
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
