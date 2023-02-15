#include "packman.h"
#include "util.h"
#include "qmlbackend.h"
#include "git2.h"

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
/*
void PackMan::readConfig() {
  QFile f("packages/packages.txt");
  if (!f.exists())
    return;

  if (!f.open(QIODevice::ReadOnly)) {
    qFatal("cannot open packages.txt. Quit now.");
    qApp->exit(1);
  }

  while (true) {
    auto data = f.readLine();
    if (data.isEmpty())
      break;
    auto data_list = data.split(' ');
    pack_list << data_list[0];
    pack_url_list << data_list[1];
    hash_list << data_list[2];
    enabled_list << data_list[3].toInt();
  }
  f.close();
}

void PackMan::writeConfig() {
  QFile f("packages/packages.txt");
  if (!f.open(QIODevice::ReadWrite | QIODevice::Truncate)) {
    qFatal("Cannot open packages.txt for write. Quitting.");
  }

  for (int i = 0; i < pack_list.length(); i++) {
    QStringList l;
    l << pack_list[i];
    l << pack_url_list[i];
    l << hash_list[i];
    l << QString::number(enabled_list[i]);
    f.write(l.join(" ").toUtf8() + '\n');
  }
  f.close();
}

void PackMan::loadConfString(const QString &conf) {
  auto lines = conf.split('\n');
  foreach (QString s, lines) {
    auto data_list = s.split(' ');
    int idx = pack_list.indexOf(data_list[0]);
    if (idx == -1) {
      pack_list << data_list[0];
      pack_url_list << data_list[1];
      hash_list << data_list[2];
      enabled_list << data_list[3].toInt();
    } else {
      pack_url_list[idx] = data_list[1];
      hash_list[idx] = data_list[2];
      enabled_list[idx] = data_list[3].toInt();
    }
  }
}
*/
void PackMan::downloadNewPack(const QString &url, bool useThread) {
  auto threadFunc = [=](){
    int error = clone(url);
    if (error < 0) return;
    QString fileName = QUrl(url).fileName();
    if (fileName.endsWith(".git"))
      fileName.chop(4);

    auto result = SelectFromDatabase(db, QString("SELECT name FROM packages \
    WHERE name = '%1';").arg(fileName));
    if (result.isEmpty()) {
      ExecSQL(db, QString("INSERT INTO packages (name,url,hash,enabled) \
      VALUES ('%1','%2','%3',1);").arg(fileName).arg(url).arg(head(fileName)));
    }
  };
  if (useThread) {
    auto thread = QThread::create(threadFunc);
    thread->start();
    connect(thread, &QThread::finished, [=](){
      thread->deleteLater();
      Backend->emitNotifyUI("DownloadComplete", "");
    });
  } else {
    threadFunc();
  }
}

void PackMan::enablePack(const QString &pack) {
  ExecSQL(db, QString("UPDATE packages SET enabled = 1 WHERE name = '%1';").arg(pack));
  QDir d(QString("packages"));
  d.rename(pack + ".disabled", pack);
}

void PackMan::disablePack(const QString &pack) {
  ExecSQL(db, QString("UPDATE packages SET enabled = 0 WHERE name = '%1';").arg(pack));
  QDir d(QString("packages"));
  d.rename(pack, pack + ".disabled");
}

void PackMan::updatePack(const QString &pack) {
  auto result = SelectFromDatabase(db, QString("SELECT hash FROM packages \
  WHERE name = '%1';").arg(pack));
  if (result.isEmpty()) return;
  int error;
  error = pull(pack);
  if (error < 0) return;
  error = checkout(pack, result[0].toObject()["hash"].toString());
  if (error < 0) return;
}

void PackMan::upgradePack(const QString &pack) {
  int error;
  error = checkout_branch(pack, "master");
  if (error < 0) return;
  error = pull(pack);
  if (error < 0) return;
  ExecSQL(db, QString("UPDATE packages SET hash = '%1' WHERE name = '%2';").arg(head(pack)).arg(pack));
}

void PackMan::removePack(const QString &pack) {
  auto result = SelectFromDatabase(db, QString("SELECT enabled FROM packages \
  WHERE name = '%1';").arg(pack));
  if (result.isEmpty()) return;
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

static int transfer_progress_cb(const git_indexer_progress *stats, void *payload)
{
  (void)payload;

  if (Backend == nullptr) {
    if (stats->received_objects == stats->total_objects) {
      printf("Resolving deltas %u/%u\r",
            stats->indexed_deltas, stats->total_deltas);
    } else if (stats->total_objects > 0) {
      printf("Received %u/%u objects (%u) in %zu bytes\r",
            stats->received_objects, stats->total_objects,
            stats->indexed_objects, stats->received_bytes);
    }
  } else {
    if (stats->received_objects == stats->total_objects) {
      auto msg = QString("Resolving deltas %1/%2")
            .arg(stats->indexed_deltas).arg(stats->total_deltas);
      Backend->emitNotifyUI("UpdateBusyText", msg);
    } else if (stats->total_objects > 0) {
      auto msg = QString("Received %1/%2 objects (%3) in %4 KiB")
            .arg(stats->received_objects).arg(stats->total_objects)
            .arg(stats->indexed_objects).arg(stats->received_bytes / 1024);
      Backend->emitNotifyUI("UpdateBusyText", msg);
    }
  }

  return 0;
}

int PackMan::clone(const QString &url) {
  git_repository *repo = NULL;
  const char *u = url.toUtf8().constData();
  QString fileName = QUrl(url).fileName();
  if (fileName.endsWith(".git"))
    fileName.chop(4);
  fileName = "packages/" + fileName;
  const char *path = fileName.toUtf8().constData();

  git_clone_options opt = GIT_CLONE_OPTIONS_INIT;
  opt.fetch_opts.callbacks.transfer_progress = transfer_progress_cb;
  int error = git_clone(&repo, u, path, &opt);
  if (error < 0) {
    GIT_FAIL;
    QDir(fileName).removeRecursively();
    QDir(".").rmdir(fileName);
  } else {
    if (Backend == nullptr)
      printf("\n");
    else
      qWarning("Completed.");
  }
  git_repository_free(repo);
  return error;
}

int PackMan::pull(const QString &name) {
  git_repository *repo = NULL;
  int error;
  git_remote *remote = NULL;
  const char *path = QString("packages/%1").arg(name).toUtf8().constData();
  git_fetch_options opt = GIT_FETCH_OPTIONS_INIT;
  opt.callbacks.transfer_progress = transfer_progress_cb;
  error = git_repository_open(&repo, path);
  if (error < 0) {
    GIT_FAIL;
    goto clean;
  }
  error = git_remote_lookup(&remote, repo, "origin");
  if (error < 0) {
    GIT_FAIL;
    goto clean;
  }
  error = git_remote_fetch(remote, NULL, &opt, "pull");
  if (error < 0) {
    GIT_FAIL;
    goto clean;
  } else {
    if (Backend == nullptr)
      printf("\n");
    else
      qWarning("Completed.");
  }

clean:
  git_remote_free(remote);
  git_repository_free(repo);
  return error;
}

int PackMan::checkout(const QString &name, const QString &hash) {
  git_repository *repo = NULL;
  git_oid oid = {0};
  int error;
  git_commit *commit = NULL;
  const char *path = QString("packages/%1").arg(name).toUtf8().constData();
  const char *sha = hash.toLatin1().constData();
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
  error = git_commit_lookup(&commit, repo, &oid);
  if (error < 0) {
    GIT_FAIL;
    goto clean;
  }
  error = git_checkout_tree(repo, (git_object *)commit, NULL);
  if (error < 0) {
    GIT_FAIL;
    goto clean;
  }

clean:
  git_commit_free(commit);
  git_repository_free(repo);
  return error;
}

int PackMan::checkout_branch(const QString &name, const QString &branch) {
  git_repository *repo = NULL;
  git_oid oid = {0};
  int error;
  git_object *obj = NULL;
  const char *path = QString("packages/%1").arg(name).toUtf8().constData();
  error = git_repository_open(&repo, path);
  if (error < 0) {
    GIT_FAIL;
    goto clean;
  }
  error = git_revparse_single(&obj, repo, branch.toUtf8().constData());
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
  const char *path = QString("packages/%1").arg(name).toUtf8().constData();
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
  const char *path = QString("packages/%1").arg(name).toUtf8().constData();
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
