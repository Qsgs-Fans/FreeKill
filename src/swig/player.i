// SPDX-License-Identifier: GPL-3.0-or-later

%nodefaultctor Player;
%nodefaultdtor Player;
class Player : public QObject {
public:
  enum State{
    Invalid,
    Online,
    Trust,
    Run,
    Robot,  // only for real robot
    Offline
  };

  int getId() const;
  void setId(int id);

  QString getScreenName() const;
  void setScreenName(const QString &name);

  QString getAvatar() const;
  void setAvatar(const QString &avatar);

  State getState() const;
  void setState(State state);
};

%nodefaultctor ClientPlayer;
%nodefaultdtor ClientPlayer;
class ClientPlayer : public Player {
public:
};

extern ClientPlayer *Self;
