// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _PLAYER_H
#define _PLAYER_H

// Common part of ServerPlayer and ClientPlayer
// dont initialize it directly
class Player : public QObject {
  Q_OBJECT

public:
  enum State{
    Invalid,
    Online,
    Trust,
    Run,
    Leave,
    Robot,  // only for real robot
    Offline
  };

  explicit Player(QObject *parent = nullptr);
  ~Player();

  int getId() const;
  void setId(int id);

  QString getScreenName() const;
  void setScreenName(const QString &name);

  QString getAvatar() const;
  void setAvatar(const QString &avatar);

  int getTotalGameTime() const;
  void addTotalGameTime(int toAdd);

  State getState() const;
  QString getStateString() const;
  void setState(State state);
  void setStateString(const QString &state);

  bool isReady() const;
  void setReady(bool ready);

  QList<int> getGameData();
  void setGameData(int total, int win, int run);
  QString getLastGameMode() const;
  void setLastGameMode(const QString &mode);

  bool isDied() const;
  void setDied(bool died);

signals:
  void screenNameChanged();
  void avatarChanged();
  void stateChanged();
  void readyChanged();
  void gameDataChanged();

private:
  int id;
  QString screenName;   // screenName should not be same.
  QString avatar;
  int totalGameTime;
  State state;
  bool ready;
  bool died;

  QString lastGameMode;
  int totalGames;
  int winCount;
  int runCount;
};

#endif // _PLAYER_H
