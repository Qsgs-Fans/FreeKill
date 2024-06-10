// SPDX-License-Identifier: GPL-3.0-or-later

#include "core/player.h"

Player::Player(QObject *parent)
    : QObject(parent), id(0), state(Player::Invalid), totalGameTime(0), ready(false),
    totalGames(0), winCount(0), runCount(0) {}

Player::~Player() {}

int Player::getId() const { return id; }

void Player::setId(int id) { this->id = id; }

QString Player::getScreenName() const { return screenName; }

void Player::setScreenName(const QString &name) {
  this->screenName = name;
  emit screenNameChanged();
}

QString Player::getAvatar() const { return avatar; }

void Player::setAvatar(const QString &avatar) {
  this->avatar = avatar;
  emit avatarChanged();
}

int Player::getTotalGameTime() const { return totalGameTime; }

void Player::addTotalGameTime(int toAdd) {
  totalGameTime += toAdd;
}

Player::State Player::getState() const { return state; }

QString Player::getStateString() const {
  switch (state) {
  case Online:
    return QStringLiteral("online");
  case Trust:
    return QStringLiteral("trust");
  case Run:
    return QStringLiteral("run");
  case Leave:
    return QStringLiteral("leave");
  case Robot:
    return QStringLiteral("robot");
  case Offline:
    return QStringLiteral("offline");
  default:
    return QStringLiteral("invalid");
  }
}

void Player::setState(Player::State state) {
  this->state = state;
  emit stateChanged();
}

void Player::setStateString(const QString &state) {
  if (state == QStringLiteral("online"))
    setState(Online);
  else if (state == QStringLiteral("trust"))
    setState(Trust);
  else if (state == QStringLiteral("run"))
    setState(Run);
  else if (state == QStringLiteral("robot"))
    setState(Robot);
  else if (state == QStringLiteral("offline"))
    setState(Offline);
  else
    setState(Invalid);
}

bool Player::isReady() const { return ready; }

void Player::setReady(bool ready) {
  this->ready = ready;
  emit readyChanged();
}

QList<int> Player::getGameData() {
  return QList<int>({ totalGames, winCount, runCount });
}

void Player::setGameData(int total, int win, int run) {
  totalGames = total;
  winCount = win;
  runCount = run;
  emit gameDataChanged();
}

QString Player::getLastGameMode() const {
  return lastGameMode;
}

void Player::setLastGameMode(const QString &mode) {
  lastGameMode = mode;
}

bool Player::isDied() const {
  return died;
}

void Player::setDied(bool died) {
  this->died = died;
}
