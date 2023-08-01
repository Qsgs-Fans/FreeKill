// SPDX-License-Identifier: GPL-3.0-or-later

#include "replayer.h"
#include "client.h"

Replayer::Replayer(QObject *parent, const QString &filename) :
  QThread(parent), fileName(filename), roomSettings(""),
  playing(true), killed(false), speed(1.0), uniformRunning(false)
{
  setObjectName("Replayer");

  QFile file("recording/" + filename);
  file.open(QIODevice::ReadOnly);
  QByteArray raw = file.readAll();
  file.close();

  auto data = qUncompress(raw);

  auto doc = QJsonDocument::fromJson(data);
  auto arr = doc.array();
  if (arr.count() < 3) {
    return;
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
}

Replayer::~Replayer() {
  Backend->setReplayer(nullptr);
  foreach (auto e, pairs) {
    delete e;
  }
}

int Replayer::getDuration() const {
  long ret = (pairs.last()->elapsed - pairs.first()->elapsed) / 1000.0;
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
  long last = 0;
  long start = 0;

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

    long delay = pair->elapsed - last;
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
