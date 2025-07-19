// SPDX-License-Identifier: GPL-3.0-or-later

#include <git2.h>
#include <git2/errors.h>
#include "core/packman.h"
#include "core/c-wrapper.h"
#include "core/util.h"
#include "ui/qmlbackend.h"

PackMan *Pacman = nullptr;

PackMan::PackMan(QObject *parent) : QObject(parent) {
  git_libgit2_init();
  db = new Sqlite3("./packages/packages.db", "./packages/init.sql");

  QDir d("packages");

  // For old version
  for (auto e : QmlBackend::ls("packages")) {
    if (e.endsWith(".disabled") && d.exists(e) && !d.exists(e.chopped(9))) {
      d.rename(e, e.chopped(9));
    }
  }

  for (auto obj : db->select("SELECT name, enabled FROM packages;")) {
    auto pack = obj["name"];
    auto enabled = obj["enabled"].toInt() == 1;

    if (!enabled) {
      disabled_packs << pack;
    }
  }

#ifdef Q_OS_ANDROID
  git_libgit2_opts(GIT_OPT_SET_SSL_CERT_LOCATIONS, NULL, "./certs");
#endif
}

PackMan::~PackMan() {
  git_libgit2_shutdown();
  delete db;
}

QStringList PackMan::getDisabledPacks() {
  return disabled_packs;
}

QString PackMan::getPackSummary() {
  return db->selectJson("SELECT name, url, hash FROM packages WHERE enabled = 1;");
}

void PackMan::loadSummary(const QString &jsonData, bool useThread) {
  auto f = [=]() {
    // First, disable all packages
    for (auto e : db->select("SELECT name FROM packages;")) {
      disablePack(e["name"]);
    }

    // Then read conf from string
    auto doc = QJsonDocument::fromJson(jsonData.toUtf8());
    auto arr = doc.array();
    for (auto e : arr) {
      auto obj = e.toObject();
      auto name = obj["name"].toString();
      auto url = obj["url"].toString();
      int err = 0;

#ifndef FK_SERVER_ONLY
      // 应该会有一个拓展包页面，提示页面目前下载哪个包了
      Backend->notifyUI("SetDownloadingPackage", name);
#endif

      if (db->select(
              QString("SELECT name FROM packages WHERE name='%1';").arg(name))
              .isEmpty()) {
        err = downloadNewPack(url);
        if (err != 0) {
#ifndef FK_SERVER_ONLY
          QString msg;
          if (err != 100) {
            auto error = git_error_last();
            msg = QString("Error: %1").arg(error->message);
          } else {
            msg = "Workspace is dirty.";
          }
          Backend->notifyUI("PackageDownloadError", msg);
#endif
          continue;
        }
      }

      enablePack(name);

      if (head(name) != obj["hash"].toString()) {
        err = updatePack(name, obj["hash"].toString());
        if (err != 0) {
#ifndef FK_SERVER_ONLY
          QString msg;
          if (err != 100) {
            auto error = git_error_last();
            msg = QString("Error: %1").arg(error->message);
          } else {
            msg = "Workspace is dirty.";
          }
          Backend->notifyUI("PackageDownloadError", msg);
#endif
          continue;
        }
      }

      db->exec(QString("UPDATE packages SET hash='%1' WHERE name='%2'")
                      .arg(obj["hash"].toString())
                      .arg(name));
    }
  };
  if (useThread) {
    auto thread = QThread::create(f);
    thread->start();
    connect(thread, &QThread::finished, [=]() {
      thread->deleteLater();
#ifndef FK_SERVER_ONLY
      Backend->notifyUI("DownloadComplete", "");
#endif
    });
  } else {
    f();
  }
}

int PackMan::downloadNewPack(const QString &url, bool useThread) {
  static auto sql_select = QString("SELECT name FROM packages \
    WHERE name = '%1';");
  static auto sql_update = QString("INSERT INTO packages (name,url,hash,enabled) \
      VALUES ('%1','%2','%3',1);");

  auto threadFunc = [=]() -> int {
    int err = clone(url);
    if (err < 0)
      return err;

    auto u = url;
    while (u.endsWith('/')) {
      u.chop(1);
    }
    QString fileName = QUrl(u).fileName();
    if (fileName.endsWith(".git"))
      fileName.chop(4);

    auto result = db->select(sql_select.arg(fileName));
    if (result.isEmpty()) {
      db->exec(sql_update.arg(fileName).arg(url)
                      .arg(err < 0 ? "XXXXXXXX" : head(fileName)));
    }

    return err;
  };
  if (useThread) {
    auto thread = QThread::create(threadFunc);
    thread->start();
    connect(thread, &QThread::finished, [=]() {
      thread->deleteLater();
#ifndef FK_SERVER_ONLY
      Backend->notifyUI("DownloadComplete", "");
#endif
    });
    return 0;
  } else {
    return threadFunc();
  }
}

void PackMan::enablePack(const QString &pack) {
  db->exec(
      QString("UPDATE packages SET enabled = 1 WHERE name = '%1';").arg(pack));

  disabled_packs.removeOne(pack);
}

void PackMan::disablePack(const QString &pack) {
  db->exec(
    QString("UPDATE packages SET enabled = 0 WHERE name = '%1';").arg(pack));

  if (!disabled_packs.contains(pack))
    disabled_packs << pack;
}

int PackMan::updatePack(const QString &pack, const QString &hash) {
  int err;
  // 先status 检查dirty 后面全是带--force的操作
  err = status(pack);
  if (err != 0)
    return err;
  err = pull(pack);
  if (err < 0)
    return err;
  err = checkout(pack, hash);
  if (err < 0)
    return err;
  return 0;
}

int PackMan::upgradePack(const QString &pack) {
  int err;
  // 先status 检查dirty 后面全是带--force的操作
  err = status(pack);
  if (err != 0)
    return err;
  err = pull(pack);
  if (err < 0)
    return err;
  // 至此upgrade命令把包升到了FETCH_HEAD的commit
  // 我们稍微操作一下，让HEAD指向最新的master
  // 这样以后就能开新分支干活了
  err = checkout_branch(pack, "master");
  if (err < 0)
    return err;

  db->exec(QString("UPDATE packages SET hash = '%1' WHERE name = '%2';")
                  .arg(head(pack))
                  .arg(pack));
  return 0;
}

void PackMan::removePack(const QString &pack) {
  auto result = db->select(QString("SELECT enabled FROM packages \
  WHERE name = '%1';")
                                           .arg(pack));
  if (result.isEmpty())
    return;

  bool enabled = result[0]["enabled"].toInt() == 1;
  db->exec(QString("DELETE FROM packages WHERE name = '%1';").arg(pack));
  QDir d(QString("packages/%1").arg(pack));
  d.removeRecursively();
}

QString PackMan::listPackages() {
  return db->selectJson("SELECT * FROM packages;");
}

void PackMan::forceCheckoutMaster(const QString &pack) {
  checkout_branch(pack, "master");
}

void PackMan::syncCommitHashToDatabase() {
  for (auto e : db->select("SELECT name FROM packages;")) {
    auto pack = e["name"];
    db->exec(QString("UPDATE packages SET hash = '%1' WHERE name = '%2';")
             .arg(head(pack))
             .arg(pack));
  }
}

#define GIT_FAIL                                                               \
  const git_error *e = git_error_last();                                       \
  qCritical("Error %d/%d: %s\n", err, e->klass, e->message)

#define GIT_CHK_CLEAN  \
  if (err < 0) {     \
    GIT_FAIL;          \
    goto clean;        \
  }

static int transfer_progress_cb(const git_indexer_progress *stats,
                                void *payload) {
  if (Backend == nullptr) {
    Q_UNUSED(payload);
    if (stats->received_objects == stats->total_objects) {
      printf("Resolving deltas %u/%u\r", stats->indexed_deltas,
             stats->total_deltas);
    } else if (stats->total_objects > 0) {
      printf("Received %u/%u objects (%u) in %zu bytes\r",
             stats->received_objects, stats->total_objects,
             stats->indexed_objects, stats->received_bytes);
    }
  } else {
#ifndef FK_SERVER_ONLY
    Backend->notifyUI("PackageTransferProgress", QJsonObject {
      { "received_objects", qint64(stats->received_objects) },
      { "total_objects", qint64(stats->total_objects) },
      { "indexed_objects", qint64(stats->indexed_objects) },
      { "received_bytes", qint64(stats->received_bytes) },
      { "indexed_deltas", qint64(stats->indexed_deltas) },
      { "total_deltas", qint64(stats->total_deltas) },
    });

    // if (stats->received_objects == stats->total_objects) {
    //   auto msg = QString("Resolving deltas %1/%2")
    //                  .arg(stats->indexed_deltas)
    //                  .arg(stats->total_deltas);
    //   Backend->notifyUI("UpdateBusyText", msg);
    // } else if (stats->total_objects > 0) {
    //   auto msg = QString("Received %1/%2 objects (%3) in %4 KiB")
    //                  .arg(stats->received_objects)
    //                  .arg(stats->total_objects)
    //                  .arg(stats->indexed_objects)
    //                  .arg(stats->received_bytes / 1024);
    //   Backend->notifyUI("UpdateBusyText", msg);
    // }
#endif
  }

  return 0;
}

int PackMan::clone(const QString &u) {
  git_repository *repo = NULL;
  auto url = u;
  while (url.endsWith('/')) {
    url.chop(1);
  }
  QString fileName = QUrl(url).fileName();
  if (fileName.endsWith(".git"))
    fileName.chop(4);
  fileName = QStringLiteral("packages/") + fileName;

  git_clone_options opt = GIT_CLONE_OPTIONS_INIT;
  opt.fetch_opts.callbacks.transfer_progress = transfer_progress_cb;
  int err = git_clone(&repo, url.toUtf8(), fileName.toUtf8(), &opt);
  if (err < 0) {
    GIT_FAIL;
    // QDir(fileName).removeRecursively();
    // QDir(".").rmdir(fileName);
  } else {
    if (Backend == nullptr)
      printf("\n");
  }
  git_repository_free(repo);
  return err;
}

// git fetch && git checkout FETCH_HEAD -f
int PackMan::pull(const QString &name) {
  git_repository *repo = NULL;
  int err;
  git_remote *remote = NULL;
  auto path = QString("packages/%1").arg(name).toUtf8();
  git_fetch_options opt;
  git_fetch_init_options(&opt, GIT_FETCH_OPTIONS_VERSION);
  opt.proxy_opts.version = 1;
  opt.callbacks.transfer_progress = transfer_progress_cb;

  git_checkout_options opt2 = GIT_CHECKOUT_OPTIONS_INIT;
  opt2.checkout_strategy = GIT_CHECKOUT_FORCE;

  err = git_repository_open(&repo, path);
  GIT_CHK_CLEAN;

  // first git fetch origin
  err = git_remote_lookup(&remote, repo, "origin");
  GIT_CHK_CLEAN;

  err = git_remote_fetch(remote, NULL, &opt, NULL);
  GIT_CHK_CLEAN;

  // then git checkout FETCH_HEAD
  err = git_repository_set_head(repo, "FETCH_HEAD");
  GIT_CHK_CLEAN;

  err = git_checkout_head(repo, &opt2);
  GIT_CHK_CLEAN;

  if (Backend == nullptr)
    printf("\n");

clean:
  git_remote_free(remote);
  git_repository_free(repo);
  return err;
}

int PackMan::checkout(const QString &name, const QString &hash) {
  git_repository *repo = NULL;
  int err;
  git_oid oid = {0};
  git_checkout_options opt = GIT_CHECKOUT_OPTIONS_INIT;
  opt.checkout_strategy = GIT_CHECKOUT_FORCE;
  auto path = QString("packages/%1").arg(name).toUtf8();
  auto sha = hash.toLatin1();
  err = git_repository_open(&repo, path);
  GIT_CHK_CLEAN;
  err = git_oid_fromstr(&oid, sha);
  GIT_CHK_CLEAN;
  err = git_repository_set_head_detached(repo, &oid);
  GIT_CHK_CLEAN;
  err = git_checkout_head(repo, &opt);
  GIT_CHK_CLEAN;

clean:
  git_repository_free(repo);
  return err;
}

// git checkout -B branch origin/branch --force
int PackMan::checkout_branch(const QString &name, const QString &branch) {
  git_repository *repo = NULL;
  git_oid oid = {0};
  int err;
  git_object *obj = NULL;
  git_reference *branch_ref = NULL;
  git_reference *remote_ref = NULL;
  git_reference *new_branch_ref = NULL;
  git_checkout_options checkout_opts = GIT_CHECKOUT_OPTIONS_INIT;
  checkout_opts.checkout_strategy = GIT_CHECKOUT_FORCE;

  QString local_branch;
  QString remote_branch;

  // 打开仓库
  auto path = QString("packages/%1").arg(name).toUtf8();
  err = git_repository_open(&repo, path);
  GIT_CHK_CLEAN;

  // 查找远程分支的引用 (refs/remotes/origin/branch)
  remote_branch = QString("refs/remotes/origin/%1").arg(branch);
  err = git_reference_lookup(&remote_ref, repo, remote_branch.toUtf8());
  GIT_CHK_CLEAN;

  // 获取远程分支指向的对象
  err = git_reference_peel(&obj, remote_ref, GIT_OBJECT_COMMIT);
  GIT_CHK_CLEAN;

  // 获取commit的OID
  git_oid_cpy(&oid, git_object_id(obj));

   // 查找本地分支的引用
  local_branch = QString("refs/heads/%1").arg(branch);
  err = git_reference_lookup(&branch_ref, repo, local_branch.toUtf8());
  if (err == 0) {
    // 分支存在，强制重置
    err = git_reference_set_target(&new_branch_ref, branch_ref, &oid, "reset: moving to remote branch");
    GIT_CHK_CLEAN;
  } else {
    // 分支不存在，创建新分支
    err = git_branch_create(&new_branch_ref, repo, branch.toUtf8(),
        (git_commit*)obj, 0);
    GIT_CHK_CLEAN;
  }

  // 设HEAD到分支
  err = git_repository_set_head(repo, git_reference_name(new_branch_ref));
  GIT_CHK_CLEAN;

  // 强制检出到HEAD
  err = git_checkout_head(repo, &checkout_opts);
  GIT_CHK_CLEAN;

clean:
  git_reference_free(new_branch_ref);
  git_reference_free(branch_ref);
  git_reference_free(remote_ref);
  git_object_free(obj);
  git_repository_free(repo);

  return err;
}

int PackMan::status(const QString &name) {
  git_repository *repo = NULL;
  int err;
  git_status_list *status_list = NULL;
  size_t i, maxi;
  const git_status_entry *s;
  auto path = QString("packages/%1").arg(name).toUtf8();
  err = git_repository_open(&repo, path);
  GIT_CHK_CLEAN;
  err = git_status_list_new(&status_list, repo, NULL);
  GIT_CHK_CLEAN;
  maxi = git_status_list_entrycount(status_list);
  for (i = 0; i < maxi; ++i) {
    char *istatus = NULL;
    s = git_status_byindex(status_list, i);
    if (s->status != GIT_STATUS_CURRENT && s->status != GIT_STATUS_IGNORED) {
      git_status_list_free(status_list);
      git_repository_free(repo);
      qCritical("Workspace is dirty.");
      return 100;
    }
  }

clean:
  git_status_list_free(status_list);
  git_repository_free(repo);
  return err;
}

QString PackMan::head(const QString &name) {
  git_repository *repo = NULL;
  int err;
  git_object *obj = NULL;
  const git_oid *oid;
  char buf[42] = {0};
  auto path = QString("packages/%1").arg(name).toUtf8();
  err = git_repository_open(&repo, path);
  GIT_CHK_CLEAN;
  err = git_revparse_single(&obj, repo, "HEAD");
  GIT_CHK_CLEAN;

  oid = git_object_id(obj);
  git_oid_tostr(buf, 41, oid);
  git_object_free(obj);
  git_repository_free(repo);
  return QString(buf);

clean:
  git_object_free(obj);
  git_repository_free(repo);
  return QString("0000000000000000000000000000000000000000");
}

#undef GIT_FAIL
#undef GIT_CHK_CLEAN
