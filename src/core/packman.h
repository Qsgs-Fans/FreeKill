// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _PACKMAN_H
#define _PACKMAN_H

class Sqlite3;
struct git_repository;

// 管理拓展包所需的类，本质上是libgit2接口的再封装。
class PackMan : public QObject {
  Q_OBJECT

public:
  PackMan(QObject *parent = nullptr);
  ~PackMan();

  Q_INVOKABLE QString getPackSummary();
  Q_INVOKABLE QStringList getDisabledPacks();
  Q_INVOKABLE void loadSummary(const QString &, bool useThread = false);
  Q_INVOKABLE int downloadNewPack(const QString &url, bool useThread = false);
  Q_INVOKABLE void enablePack(const QString &pack);
  Q_INVOKABLE void disablePack(const QString &pack);
  Q_INVOKABLE int updatePack(const QString &pack, const QString &hash);
  Q_INVOKABLE int upgradePack(const QString &pack);
  Q_INVOKABLE void removePack(const QString &pack);
  Q_INVOKABLE QString listPackages();

  Q_INVOKABLE void forceCheckoutMaster(const QString &pack);

  // 从数据库读取所有包。将repo的实际HEAD写入到db
  // 适用于自己手动git pull包后使用
  void syncCommitHashToDatabase();

  bool shouldUseCore();

private:
  std::unique_ptr<Sqlite3> db;
  QStringList disabled_packs;

  struct GitRepo;
  int open(const QString &name, GitRepo &repo);
  int clone(const QString &url, GitRepo &repo);
  int pull(git_repository *repo);
  int hasCommit(git_repository *repo, const QString &hash);
  int checkout(git_repository *repo, const QString &hash);
  int checkout_branch(git_repository *repo, const QString &branch);
  int status(git_repository *repo); // return 1 if the workdir is modified
  QString head(git_repository *repo); // get commit hash of HEAD
  QString generate_changelog(git_repository *repo, const QString &commit_range);
  void sanitize_package_db(const QString &packname);
  static QString extract_pack_name(const QString &url);
};

extern PackMan *Pacman;

#endif
