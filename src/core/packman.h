#ifndef _PACKMAN_H
#define _PACKMAN_H

class PackMan {
public:
  PackMan();
  ~PackMan();
/*
  void readConfig();
  void writeConfig();
  void loadConfString(const QString &conf);
*/
  void downloadNewPack(const QString &url);
  void enablePack(const QString &pack);
  void disablePack(const QString &pack);
  void updatePack(const QString &pack);
private:
  sqlite3 *db;

  int clone(const QString &url);
  int pull(const QString &name);
  int checkout(const QString &name, const QString &hash);
  int status(const QString &name); // return 1 if the workdir is modified
  QString head(const QString &name); // get commit hash of HEAD
};

extern PackMan *Pacman;

#endif
