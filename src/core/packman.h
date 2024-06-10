// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _PACKMAN_H
#define _PACKMAN_H

// 管理拓展包所需的类，本质上是libgit2接口的再封装。
class PackMan : public QObject {
  Q_OBJECT

public:
  PackMan(QObject *parent = nullptr);
  ~PackMan();

  QString getPackSummary();
  Q_INVOKABLE QStringList getDisabledPacks();
  Q_INVOKABLE void loadSummary(const QString &, bool useThread = false);
  Q_INVOKABLE void downloadNewPack(const QString &url, bool useThread = false);
  Q_INVOKABLE void enablePack(const QString &pack);
  Q_INVOKABLE void disablePack(const QString &pack);
  Q_INVOKABLE void updatePack(const QString &pack);
  Q_INVOKABLE void upgradePack(const QString &pack);
  Q_INVOKABLE void removePack(const QString &pack);
  Q_INVOKABLE QString listPackages();

private:
  sqlite3 *db;

  int clone(const QString &url);
  int pull(const QString &name);
  int checkout(const QString &name, const QString &hash);
  int checkout_branch(const QString &name, const QString &branch);
  int status(const QString &name); // return 1 if the workdir is modified
  QString head(const QString &name); // get commit hash of HEAD
  QStringList disabled_packs;
};

extern PackMan *Pacman;

#endif
