#include "packman.h"
#include "git2.h"

PackMan *Pacman;

PackMan::PackMan() {
  git_libgit2_init();
  readConfig();
}

PackMan::~PackMan() {
  git_libgit2_shutdown();
  writeConfig();
}

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

void PackMan::downloadNewPack(const QString &url) {
  clone(url);
  QString fileName = QUrl(url).fileName();
  if (fileName.endsWith(".git"))
    fileName.chop(4);

  QString hash = head(fileName);
  pack_list << fileName;
  pack_url_list << url;
  hash_list << hash;
  enabled_list << 1;
}

void PackMan::enablePack(const QString &pack) {
  int idx = pack_list.indexOf(pack);
  if (idx < 0)
    return;
  enabled_list[idx] = 1;
  QDir d(QString("packages/%1"));
  d.rename(pack + ".disabled", pack);
}

void PackMan::disablePack(const QString &pack) {
  int idx = pack_list.indexOf(pack);
  if (idx < 0)
    return;
  enabled_list[idx] = 0;
  QDir d(QString("packages/%1"));
  d.rename(pack, pack + ".disabled");
}

void PackMan::updatePack(const QString &pack) {
  int idx = pack_list.indexOf(pack);
  if (idx < 0)
    return;
  pull(pack);
  checkout(pack, hash_list[idx]);
}

#define GIT_FAIL                                                               \
  const git_error *e = git_error_last();                                       \
  qCritical("Error %d/%d: %s\n", error, e->klass, e->message)

int PackMan::clone(const QString &url) {
  git_repository *repo = NULL;
  const char *u = url.toUtf8().constData();
  QString fileName = QUrl(url).fileName();
  if (fileName.endsWith(".git"))
    fileName.chop(4);
  fileName = "packages/" + fileName;
  const char *path = fileName.toUtf8().constData();

  int error = git_clone(&repo, u, path, NULL);
  if (error < 0) {
    GIT_FAIL;
  }
  git_repository_free(repo);
  return error;
}

int PackMan::pull(const QString &name) {
  git_repository *repo = NULL;
  int error;
  git_remote *remote = NULL;
  const char *path = QString("packages/%1").arg(name).toUtf8().constData();
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
  error = git_remote_fetch(remote, NULL, NULL, "pull");
  if (error < 0) {
    GIT_FAIL;
    goto clean;
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
  git_revwalk *walker = NULL;
  git_oid oid = {0};
  const char *path = QString("packages/%1").arg(name).toUtf8().constData();
  error = git_repository_open(&repo, path);
  if (error < 0) {
    GIT_FAIL;
    return QString();
  }
  error = git_revwalk_new(&walker, repo);
  if (error < 0) {
    GIT_FAIL;
    return QString();
  }
  error = git_revwalk_push_range(walker, "HEAD^..HEAD");
  if (error < 0) {
    GIT_FAIL;
    return QString();
  }
  git_revwalk_next(&oid, walker);

  char buf[42];
  git_oid_tostr(buf, 41, &oid);
  return QString(buf);
}

#undef GIT_FAIL
