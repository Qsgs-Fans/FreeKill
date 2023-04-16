// SPDX-License-Identifier: GPL-3.0-or-later

#include "packman.h"
#include "git2.h"
#include "util.h"
#include <qjsondocument.h>

#ifndef FK_SERVER_ONLY
#include "qmlbackend.h"
#else
static void *Backend = nullptr;
#endif

PackMan *Pacman;

PackMan::PackMan(QObject *parent) : QObject(parent) {
  git_libgit2_init();
  db = OpenDatabase("./packages/packages.db", "./packages/init.sql");
#ifdef Q_OS_ANDROID
  git_libgit2_opts(GIT_OPT_SET_SSL_CERT_LOCATIONS, NULL, "./certs");
#endif
}

PackMan::~PackMan() {
  git_libgit2_shutdown();
  sqlite3_close(db);
}

QString PackMan::getPackSummary() {
  return SelectFromDb(
      db, "SELECT name, url, hash FROM packages WHERE enabled = 1;");
}

void PackMan::loadSummary(const QString &jsonData, bool useThread) {
  auto f = [=]() {
    // First, disable all packages
    foreach (auto e, SelectFromDatabase(db, "SELECT name FROM packages;")) {
      disablePack(e.toObject()["name"].toString());
    }

    // Then read conf from string
    auto doc = QJsonDocument::fromJson(jsonData.toUtf8());
    auto arr = doc.array();
    foreach (auto e, arr) {
      auto obj = e.toObject();
      auto name = obj["name"].toString();
      if (SelectFromDatabase(
              db,
              QString("SELECT name FROM packages WHERE name='%1';").arg(name))
              .isEmpty()) {
        downloadNewPack(obj["url"].toString());
      }
      ExecSQL(db, QString("UPDATE packages SET hash='%1' WHERE name='%2'")
                      .arg(obj["hash"].toString())
                      .arg(name));
      enablePack(name);
      updatePack(name);
    }
  };
  if (useThread) {
    auto thread = QThread::create(f);
    thread->start();
    connect(thread, &QThread::finished, [=]() {
      thread->deleteLater();
#ifndef FK_SERVER_ONLY
      Backend->emitNotifyUI("DownloadComplete", "");
#endif
    });
  } else {
    f();
  }
}

void PackMan::downloadNewPack(const QString &url, bool useThread) {
  auto threadFunc = [=]() {
    int error = clone(url);
    if (error < 0)
      return;
    auto u = url;
    while (u.endsWith('/')) {
      u.chop(1);
    }
    QString fileName = QUrl(u).fileName();
    if (fileName.endsWith(".git"))
      fileName.chop(4);

    auto result = SelectFromDatabase(db, QString("SELECT name FROM packages \
    WHERE name = '%1';")
                                             .arg(fileName));
    if (result.isEmpty()) {
      ExecSQL(db, QString("INSERT INTO packages (name,url,hash,enabled) \
      VALUES ('%1','%2','%3',1);")
                      .arg(fileName)
                      .arg(url)
                      .arg(head(fileName)));
    }
  };
  if (useThread) {
    auto thread = QThread::create(threadFunc);
    thread->start();
    connect(thread, &QThread::finished, [=]() {
      thread->deleteLater();
#ifndef FK_SERVER_ONLY
      Backend->emitNotifyUI("DownloadComplete", "");
#endif
    });
  } else {
    threadFunc();
  }
}

void PackMan::enablePack(const QString &pack) {
  ExecSQL(
      db,
      QString("UPDATE packages SET enabled = 1 WHERE name = '%1';").arg(pack));
  QDir d(QString("packages"));
  d.rename(pack + ".disabled", pack);
}

void PackMan::disablePack(const QString &pack) {
  ExecSQL(
      db,
      QString("UPDATE packages SET enabled = 0 WHERE name = '%1';").arg(pack));
  QDir d(QString("packages"));
  d.rename(pack, pack + ".disabled");
}

void PackMan::updatePack(const QString &pack) {
  auto result = SelectFromDatabase(db, QString("SELECT hash FROM packages \
  WHERE name = '%1';")
                                           .arg(pack));
  if (result.isEmpty())
    return;
  int error;
  error = status(pack);
  if (error != 0) {
    qCritical("Workspace is dirty, or some error occured.");
    return;
  }
  error = pull(pack);
  if (error < 0)
    return;
  error = checkout(pack, result[0].toObject()["hash"].toString());
  if (error < 0)
    return;
}

void PackMan::upgradePack(const QString &pack) {
  int error;
  error = checkout_branch(pack, "master");
  if (error < 0)
    return;
  error = status(pack);
  if (error != 0) {
    qCritical("Workspace is dirty, or some error occured.");
    return;
  }
  error = pull(pack);
  if (error < 0)
    return;
  ExecSQL(db, QString("UPDATE packages SET hash = '%1' WHERE name = '%2';")
                  .arg(head(pack))
                  .arg(pack));
}

void PackMan::removePack(const QString &pack) {
  auto result = SelectFromDatabase(db, QString("SELECT enabled FROM packages \
  WHERE name = '%1';")
                                           .arg(pack));
  if (result.isEmpty())
    return;
  bool enabled = result[0].toObject()["enabled"].toString().toInt() == 1;
  ExecSQL(db, QString("DELETE FROM packages WHERE name = '%1';").arg(pack));
  QDir d(QString("packages/%1%2").arg(pack).arg(enabled ? "" : ".disabled"));
  d.removeRecursively();
}

QString PackMan::listPackages() {
  auto obj = SelectFromDatabase(db, QString("SELECT * FROM packages;"));
  return QJsonDocument(obj).toJson();
}

#define GIT_FAIL                                                               \
  const git_error *e = git_error_last();                                       \
  qCritical("Error %d/%d: %s\n", error, e->klass, e->message)

static int transfer_progress_cb(const git_indexer_progress *stats,
                                void *payload) {
  (void)payload;

  if (Backend == nullptr) {
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
    if (stats->received_objects == stats->total_objects) {
      auto msg = QString("Resolving deltas %1/%2")
                     .arg(stats->indexed_deltas)
                     .arg(stats->total_deltas);
      Backend->emitNotifyUI("UpdateBusyText", msg);
    } else if (stats->total_objects > 0) {
      auto msg = QString("Received %1/%2 objects (%3) in %4 KiB")
                     .arg(stats->received_objects)
                     .arg(stats->total_objects)
                     .arg(stats->indexed_objects)
                     .arg(stats->received_bytes / 1024);
      Backend->emitNotifyUI("UpdateBusyText", msg);
    }
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
  fileName = "packages/" + fileName;

  git_clone_options opt = GIT_CLONE_OPTIONS_INIT;
  opt.fetch_opts.callbacks.transfer_progress = transfer_progress_cb;
  int error = git_clone(&repo, url.toUtf8(), fileName.toUtf8(), &opt);
  if (error < 0) {
    GIT_FAIL;
    // QDir(fileName).removeRecursively();
    // QDir(".").rmdir(fileName);
  } else {
    if (Backend == nullptr)
      printf("\n");
  }
  git_repository_free(repo);
  return error;
}

int PackMan::pull(const QString &name) {
  git_repository *repo = NULL;
  int error;
  git_remote *remote = NULL;
  auto path = QString("packages/%1").arg(name).toUtf8();
  git_fetch_options opt = GIT_FETCH_OPTIONS_INIT;
  opt.callbacks.transfer_progress = transfer_progress_cb;
  git_checkout_options opt2 = GIT_CHECKOUT_OPTIONS_INIT;
  opt2.checkout_strategy = GIT_CHECKOUT_FORCE;

  error = git_repository_open(&repo, path);
  if (error < 0) {
    GIT_FAIL;
    goto clean;
  }

  // first git fetch origin
  error = git_remote_lookup(&remote, repo, "origin");
  if (error < 0) {
    GIT_FAIL;
    goto clean;
  }
  error = git_remote_fetch(remote, NULL, &opt, NULL);
  if (error < 0) {
    GIT_FAIL;
    goto clean;
  }

  // then git checkout FETCH_HEAD
  error = git_repository_set_head(repo, "FETCH_HEAD");
  if (error < 0) {
    GIT_FAIL;
    goto clean;
  }
  error = git_checkout_head(repo, &opt2);
  if (error < 0) {
    GIT_FAIL;
    goto clean;
  } else {
    if (Backend == nullptr)
      printf("\n");
  }

clean:
  git_remote_free(remote);
  git_repository_free(repo);
  return error;
}

int PackMan::checkout(const QString &name, const QString &hash) {
  git_repository *repo = NULL;
  int error;
  git_oid oid = {0};
  git_checkout_options opt = GIT_CHECKOUT_OPTIONS_INIT;
  opt.checkout_strategy = GIT_CHECKOUT_FORCE;
  auto path = QString("packages/%1").arg(name).toUtf8();
  auto sha = hash.toLatin1();
  error = git_repository_open(&repo, path);
  if (error < 0) {
    GIT_FAIL;
    goto clean;
  }
  error = git_oid_fromstr(&oid, sha);
  if (error < 0) {
    GIT_FAIL;
    goto clean;
  }
  error = git_repository_set_head_detached(repo, &oid);
  if (error < 0) {
    GIT_FAIL;
    goto clean;
  }
  error = git_checkout_head(repo, &opt);
  if (error < 0) {
    GIT_FAIL;
    goto clean;
  }

clean:
  git_repository_free(repo);
  return error;
}

int PackMan::checkout_branch(const QString &name, const QString &branch) {
  git_repository *repo = NULL;
  git_oid oid = {0};
  int error;
  git_object *obj = NULL;
  auto path = QString("packages/%1").arg(name).toUtf8();
  error = git_repository_open(&repo, path);
  if (error < 0) {
    GIT_FAIL;
    goto clean;
  }
  error = git_revparse_single(&obj, repo, branch.toUtf8());
  if (error < 0) {
    GIT_FAIL;
    goto clean;
  }
  error = git_checkout_tree(repo, obj, NULL);
  if (error < 0) {
    GIT_FAIL;
    goto clean;
  }

clean:
  git_object_free(obj);
  git_repository_free(repo);
  return error;
}

int PackMan::status(const QString &name) {
  git_repository *repo = NULL;
  int error;
  git_status_list *status_list;
  size_t i, maxi;
  const git_status_entry *s;
  auto path = QString("packages/%1").arg(name).toUtf8();
  error = git_repository_open(&repo, path);
  if (error < 0) {
    GIT_FAIL;
    goto clean;
  }
  error = git_status_list_new(&status_list, repo, NULL);
  if (error < 0) {
    GIT_FAIL;
    goto clean;
  }
  maxi = git_status_list_entrycount(status_list);
  for (i = 0; i < maxi; ++i) {
    char *istatus = NULL;
    s = git_status_byindex(status_list, i);
    if (s->status != GIT_STATUS_CURRENT && s->status != GIT_STATUS_IGNORED)
      return 1;
  }

clean:
  git_status_list_free(status_list);
  git_repository_free(repo);
  return error;
}

QString PackMan::head(const QString &name) {
  git_repository *repo = NULL;
  int error;
  git_object *obj = NULL;
  auto path = QString("packages/%1").arg(name).toUtf8();
  error = git_repository_open(&repo, path);
  if (error < 0) {
    GIT_FAIL;
    git_object_free(obj);
    git_repository_free(repo);
    return QString();
  }
  error = git_revparse_single(&obj, repo, "HEAD");
  if (error < 0) {
    GIT_FAIL;
    git_object_free(obj);
    git_repository_free(repo);
    return QString();
  }

  const git_oid *oid = git_object_id(obj);
  char buf[42];
  git_oid_tostr(buf, 41, oid);
  git_object_free(obj);
  git_repository_free(repo);
  return QString(buf);
}

#undef GIT_FAIL
