// SPDX-License-Identifier: GPL-3.0-or-later

#include <git2.h>
#include <git2/errors.h>
#include <algorithm>
#include "core/packman.h"
#include "core/c-wrapper.h"
#include "core/util.h"
#include "ui/qmlbackend.h"

PackMan *Pacman = nullptr;

PackMan::PackMan(QObject *parent) : QObject(parent) {
  git_libgit2_init();
  db = std::make_unique<Sqlite3>("./packages/packages.db", "./packages/init.sql");

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
}

// RAII wrapper for libgit2 git_repository
struct PackMan::GitRepo {
  git_repository *repo = nullptr;

  GitRepo() noexcept = default;
  GitRepo(GitRepo &) = delete;
  GitRepo(GitRepo &&) = delete;
  ~GitRepo() { if (repo) git_repository_free(repo); }
};

QStringList PackMan::getDisabledPacks() {
  return disabled_packs;
}

QString PackMan::getPackSummary() {
  return db->selectJson("SELECT name, url, hash FROM packages WHERE enabled = 1;");
}

void PackMan::loadSummary(const QString &jsonData, bool useThread) {
  auto f = [=, this] {
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

      GitRepo head_repo;
      if (open(name, head_repo) == 0 && head(head_repo.repo) != obj["hash"].toString()) {
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

  auto threadFunc = [=, this] {
    GitRepo raii_repo;
    int err = clone(url, raii_repo);
    if (err < 0) {
      return err;
    }

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
                      .arg(head(raii_repo.repo)));
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
  if (pack == "freekill-core") {
    qWarning("Package 'freekill-core' cannot be disabled.");
    return;
  }

  db->exec(
    QString("UPDATE packages SET enabled = 0 WHERE name = '%1';").arg(pack));

  if (!disabled_packs.contains(pack))
    disabled_packs << pack;
}

int PackMan::updatePack(const QString &pack, const QString &hash) {
  GitRepo raii_repo;
  int err = open(pack, raii_repo);
  if (err < 0)
    return err;
  auto repo = raii_repo.repo;

  // 先status 检查dirty 后面全是带--force的操作
  err = status(repo);
  if (err != 0)
    return err;

  // 检测一下是否已经存在该commit hash，不存在就pull
  err = hasCommit(repo, hash);
  if (err != 0) {
    err = pull(repo);
    if (err < 0)
      return err;
  }
  err = checkout(repo, hash);
  if (err < 0)
    return err;
  return 0;
}

int PackMan::upgradePack(const QString &pack) {
  GitRepo raii_repo;
  int err = open(pack, raii_repo);
  if (err < 0)
    return err;
  auto repo = raii_repo.repo;

  // 先status 检查dirty 后面全是带--force的操作
  err = status(repo);
  if (err != 0)
    return err;

  auto old_hash = head(repo);

  err = pull(repo);
  if (err < 0)
    return err;
  // 至此upgrade命令把包升到了FETCH_HEAD的commit
  // 我们稍微操作一下，让HEAD指向最新的master
  // 这样以后就能开新分支干活了
  err = checkout_branch(repo, "master");
  if (err < 0)
    return err;

  auto hash = head(repo);
  auto commit_range = QString("%1..%2").arg(old_hash, hash);
  generate_changelog(repo, commit_range);

  db->exec(QString("UPDATE packages SET hash = '%1' WHERE name = '%2';")
                  .arg(head(repo))
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
  GitRepo repo;
  int err = open(pack, repo);
  if (err < 0)
    return;
  checkout_branch(repo.repo, "master");
}

void PackMan::syncCommitHashToDatabase() {
  for (auto e : db->select("SELECT name FROM packages;")) {
    auto pack = e["name"];
    GitRepo repo;
    int err = open(pack, repo);
    if (err < 0)
      continue;
    db->exec(QString("UPDATE packages SET hash = '%1' WHERE name = '%2';")
             .arg(head(repo.repo))
             .arg(pack));
  }
}

static bool is_head_newer_than_commit(const char *repo_path, const char *commit_hash) {
  git_repository *repo = NULL;
  git_commit *given_commit = NULL;
  git_commit *head_commit = NULL;
  bool result = false;

  // 初始化 libgit2
  git_libgit2_init();

  // 打开仓库
  if (git_repository_open(&repo, repo_path) != 0) {
    // fprintf(stderr, "Could not open repository: %s\n", repo_path);
    goto cleanup;
  }

  // 解析给定的 commit
  git_oid given_oid;
  if (git_oid_fromstr(&given_oid, commit_hash) != 0) {
    // fprintf(stderr, "Invalid commit hash: %s\n", commit_hash);
    goto cleanup;
  }

  // 检查给定的 commit 是否存在
  if (git_commit_lookup(&given_commit, repo, &given_oid) != 0) {
    // fprintf(stderr, "Commit not found: %s\n", commit_hash);
    goto cleanup;
  }

  // 获取 HEAD 指向的 commit
  git_oid head_oid;
  if (git_reference_name_to_id(&head_oid, repo, "HEAD") != 0) {
    // fprintf(stderr, "Could not get HEAD\n");
    goto cleanup;
  }

  if (git_commit_lookup(&head_commit, repo, &head_oid) != 0) {
    // fprintf(stderr, "Could not lookup HEAD commit\n");
    goto cleanup;
  }

  // 比较两个 commit 的先后关系
  if (git_graph_descendant_of(repo, &head_oid, &given_oid) == 1) {
    result = true;
  }

  // 补：相同的话也可以
  if (strncmp((char*)head_oid.id, (char*)given_oid.id, 20) == 0) {
    result = true;
  }

cleanup:
  git_commit_free(given_commit);
  git_commit_free(head_commit);
  git_repository_free(repo);
  git_libgit2_shutdown();

  return result;
}

// 写死一个freekill-core的commit（一般是发布时freekill-core的版本）
// 达到强制加载高版本脚本的效果 防止老core爆炸
static const char *min_commit = "b57d89fa4c1a1ae5a0711b97598747b8cbc7428e";

bool PackMan::shouldUseCore() {
  if (!QFile::exists("packages/freekill-core")) return false;
  if (disabled_packs.contains("freekill-core")) return false;
  bool ret = is_head_newer_than_commit("packages/freekill-core", min_commit);
  return ret;
}

#define GIT_FAIL                                                               \
  const git_error *e = git_error_last();                                       \
  qCritical("Error %d/%d: %s\n", err, e->klass, e->message)

#define GIT_CHK_CLEAN  \
  if (err < 0) {     \
    GIT_FAIL;          \
    goto clean;        \
  }

int PackMan::open(const QString &name, GitRepo &repo) {
  git_repository *raw = nullptr;
  auto path = QString("packages/%1").arg(name).toUtf8();
  int err = git_repository_open(&raw, path);
  if (err < 0) {
    GIT_FAIL;
    return err;
  }
  repo.repo = raw;
  return 0;
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

int PackMan::clone(const QString &u, GitRepo &repo) {
  auto url = u;
  while (url.endsWith('/')) {
    url.chop(1);
  }
  QString fileName = QUrl(url).fileName();
  if (fileName.endsWith(".git"))
    fileName.chop(4);
  QString clonePath = QString("packages/%1").arg(fileName);

  git_repository *raw = nullptr;
  git_clone_options opt;
  git_clone_init_options(&opt, GIT_CLONE_OPTIONS_VERSION);
  opt.fetch_opts.proxy_opts.version = 1;
  opt.fetch_opts.callbacks.transfer_progress = transfer_progress_cb;
  int err = git_clone(&raw, url.toUtf8(), clonePath.toUtf8(), &opt);
  if (err < 0) {
    QDir(clonePath).removeRecursively();
    GIT_FAIL;
  } else {
    repo.repo = raw;
    if (Backend == nullptr)
      printf("\n");
  }
  return err;
}

// git fetch && git checkout FETCH_HEAD -f
int PackMan::pull(git_repository *repo) {
  int err;
  git_remote *remote = NULL;
  git_fetch_options opt;
  git_fetch_init_options(&opt, GIT_FETCH_OPTIONS_VERSION);
  opt.proxy_opts.version = 1;
  opt.callbacks.transfer_progress = transfer_progress_cb;

  git_checkout_options opt2 = GIT_CHECKOUT_OPTIONS_INIT;
  opt2.checkout_strategy = GIT_CHECKOUT_FORCE;

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
  return err;
}

int PackMan::hasCommit(git_repository *repo, const QString &hash) {
  int err;
  git_oid oid = {0};
  git_commit *commit = NULL;

  auto sha = hash.toLatin1();
  err = git_oid_fromstr(&oid, sha);
  GIT_CHK_CLEAN;
  err = git_commit_lookup(&commit, repo, &oid);
  // 这里就没必要弹窗了
  // GIT_CHK_CLEAN;

clean:
  git_commit_free(commit);
  return err;
}

int PackMan::checkout(git_repository *repo, const QString &hash) {
  int err;
  git_oid oid = {0};
  git_checkout_options opt = GIT_CHECKOUT_OPTIONS_INIT;
  opt.checkout_strategy = GIT_CHECKOUT_FORCE;
  auto sha = hash.toLatin1();
  err = git_oid_fromstr(&oid, sha);
  GIT_CHK_CLEAN;
  err = git_repository_set_head_detached(repo, &oid);
  GIT_CHK_CLEAN;
  err = git_checkout_head(repo, &opt);
  GIT_CHK_CLEAN;

clean:
  return err;
}

// git checkout -B branch origin/branch --force
int PackMan::checkout_branch(git_repository *repo, const QString &branch) {
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

  return err;
}

int PackMan::status(git_repository *repo) {
  int err;
  git_status_list *status_list = NULL;
  size_t i, maxi;
  const git_status_entry *s;
  err = git_status_list_new(&status_list, repo, NULL);
  GIT_CHK_CLEAN;
  maxi = git_status_list_entrycount(status_list);
  for (i = 0; i < maxi; ++i) {
    char *istatus = NULL;
    s = git_status_byindex(status_list, i);
    if (s->status != GIT_STATUS_CURRENT && s->status != GIT_STATUS_IGNORED) {
      git_status_list_free(status_list);
      qCritical("Workspace is dirty.");
      return 100;
    }
  }

clean:
  git_status_list_free(status_list);
  return err;
}

QString PackMan::head(git_repository *repo) {
  int err;
  git_object *obj = NULL;
  const git_oid *oid;
  char buf[42] = {0};
  err = git_revparse_single(&obj, repo, "HEAD");
  GIT_CHK_CLEAN;

  oid = git_object_id(obj);
  git_oid_tostr(buf, 41, oid);
  git_object_free(obj);
  return QString(buf);

clean:
  git_object_free(obj);
  return QString("0000000000000000000000000000000000000000");
}

struct ConvCommit {
  QString raw_message_head;
  enum { Feat, Fix } type;
  bool breaking = false;
  QString subtype;
  QString message_title;
};

// 根据Conventional Commit规范，对于给定commit_range生成摘要
// 但是实际上是简化版方法，只检测feat: 和 fix:，以及他俩携带括号的版本和携带感叹号的版本
// 比如feat(foo)!: message title\n\n  LONG MESSAGE BODY
// 这单独一条显示为 - **破坏性!** (foo) message title
QString PackMan::generate_changelog(git_repository *repo, const QString &commit_range) {
  int err;
  git_revwalk *walk = NULL;
  git_oid oid;
  QList<ConvCommit> feats;
  QList<ConvCommit> fixes;
  QString result;

  err = git_revwalk_new(&walk, repo);
  GIT_CHK_CLEAN;

  err = git_revwalk_push_range(walk, commit_range.toUtf8());
  GIT_CHK_CLEAN;

  while (!git_revwalk_next(&oid, walk)) {
    git_commit *commit = NULL;
    err = git_commit_lookup(&commit, repo, &oid);
    if (err < 0) continue;

    const char *msg = git_commit_message(commit);
    QString msg_str(msg);
    auto first_line = msg_str.left(msg_str.indexOf('\n'));
    if (first_line.isEmpty())
      first_line = msg_str;

    ConvCommit cc;
    cc.raw_message_head = first_line;

    int pos = 0;
    if (first_line.startsWith("feat")) {
      cc.type = ConvCommit::Feat;
      pos = 4;
    } else if (first_line.startsWith("fix")) {
      cc.type = ConvCommit::Fix;
      pos = 3;
    } else {
      git_commit_free(commit);
      continue;
    }

    if (pos < first_line.size() && first_line[pos] == '(') {
      int end = first_line.indexOf(')', pos);
      if (end != -1) {
        cc.subtype = first_line.mid(pos + 1, end - pos - 1);
        pos = end + 1;
      }
    }

    if (pos < first_line.size() && first_line[pos] == '!') {
      cc.breaking = true;
      pos++;
    }

    if (pos < first_line.size() && first_line[pos] == ':') {
      pos++;
      if (pos < first_line.size() && first_line[pos] == ' ') {
        pos++;
      }
    }

    cc.message_title = first_line.mid(pos);

    if (cc.type == ConvCommit::Feat) {
      feats.append(cc);
    } else {
      fixes.append(cc);
    }

    git_commit_free(commit);
  }

  std::reverse(feats.begin(), feats.end());
  std::reverse(fixes.begin(), fixes.end());

  if (!feats.isEmpty()) {
    result += "## Feature(s)\n\n";
    for (const auto &c : feats) {
      result += "- ";
      if (c.breaking) {
        result += "**BREAKING!** ";
      }
      if (!c.subtype.isEmpty()) {
        result += "(" + c.subtype + ") ";
      }
      result += c.message_title + "\n";
    }
    result += "\n";
  }

  if (!fixes.isEmpty()) {
    result += "## Fix(es)\n\n";
    for (const auto &c : fixes) {
      result += "- ";
      if (c.breaking) {
        result += "**BREAKING!** ";
      }
      if (!c.subtype.isEmpty()) {
        result += "(" + c.subtype + ") ";
      }
      result += c.message_title + "\n";
    }
    result += "\n";
  }

clean:
  git_revwalk_free(walk);
  return result;
}

#undef GIT_FAIL
#undef GIT_CHK_CLEAN
