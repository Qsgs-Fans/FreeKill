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
    Leave,
    Robot,  // only for real robot
    Offline
  };

  int getId() const;
  void setId(int id);

  QString getScreenName() const;
  void setScreenName(const QString &name);

  QString getAvatar() const;
  void setAvatar(const QString &avatar);

  int getTotalGameTime() const;
  void addTotalGameTime(int toAdd);

  State getState() const;
  void setState(State state);

  QList<int> getGameData();
  void setGameData(int total, int win, int run);

  bool isDied() const;
  void setDied(bool died);
};

%nodefaultctor ClientPlayer;
%nodefaultdtor ClientPlayer;
class ClientPlayer : public Player {
public:
};

extern ClientPlayer *Self;
