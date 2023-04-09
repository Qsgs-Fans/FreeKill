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

  State getState() const;
  QString getStateString() const;
  void setState(State state);
  void setStateString(const QString &state);

  bool isReady() const;
  void setReady(bool ready);

signals:
  void screenNameChanged();
  void avatarChanged();
  void stateChanged();
  void readyChanged();

private:
  int id;
  QString screenName;   // screenName should not be same.
  QString avatar;
  State state;
  bool ready;
};

#endif // _PLAYER_H
