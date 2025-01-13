// SPDX-License-Identifier: GPL-3.0-or-later

#include "server/shell.h"
#include "core/packman.h"
#include "server/server.h"
#include "server/serverplayer.h"
#include "server/roomthread.h"
#include "core/util.h"
#include "core/c-wrapper.h"
#ifdef FK_USE_READLINE
#include <readline/history.h>
#include <readline/readline.h>
#include <signal.h>
#include <unistd.h>
#include <sys/ioctl.h>
#else
#include <cstdio>
#include <cstring>
#include <iostream>
#endif
#include <QJsonDocument>

Shell *ShellInstance = nullptr;
static const char *prompt = "Fk> ";

void Shell::helpCommand(QStringList &) {
  qInfo("Frequently used commands:");
#define HELP_MSG(a, b)                                                         \
  qInfo((a), Color((b), fkShell::Cyan).toUtf8().constData());

  HELP_MSG("%s: Display this help message.", "help");
  HELP_MSG("%s: Shut down the server.", "quit");
  HELP_MSG("%s: Crash the server. Useful when encounter dead loop.", "crash");
  HELP_MSG("%s: List all online players.", "lsplayer");
  HELP_MSG("%s: List all running rooms, or show player of room by an <id>.", "lsroom");
  HELP_MSG("%s: Reload server config file.", "reloadconf/r");
  HELP_MSG("%s: Kick a player by his <id>.", "kick");
  HELP_MSG("%s: Broadcast message.", "msg/m");
  HELP_MSG("%s: Broadcast message to a room.", "msgroom/mr");
  HELP_MSG("%s: Ban 1 or more accounts, IP, UUID by their <name>.", "ban");
  HELP_MSG("%s: Unban 1 or more accounts by their <name>.", "unban");
  HELP_MSG(
      "%s: Ban 1 or more IP address. "
      "At least 1 <name> required.",
      "banip");
  HELP_MSG(
      "%s: Unban 1 or more IP address. "
      "At least 1 <name> required.",
      "unbanip");
  HELP_MSG(
      "%s: Ban 1 or more UUID. "
      "At least 1 <name> required.",
      "banuuid");
  HELP_MSG(
      "%s: Unban 1 or more UUID. "
      "At least 1 <name> required.",
      "unbanuuid");
  HELP_MSG("%s: reset <name>'s password to 1234.", "resetpassword/rp");
  HELP_MSG("%s: View status of server.", "stat/gc");
  HELP_MSG("%s: View detail information (Lua) of room by an id.", "dumproom");
  HELP_MSG("%s: Kick all players in a room, then abandon it.", "killroom");
  qInfo();
  qInfo("===== Package commands =====");
  HELP_MSG("%s: Install a new package from <url>.", "install");
  HELP_MSG("%s: Remove a package.", "remove");
  HELP_MSG("%s: List all packages.", "pkgs");
  HELP_MSG("%s: Enable a package.", "enable");
  HELP_MSG("%s: Disable a package.", "disable");
  HELP_MSG("%s: Upgrade a package. Leave empty to upgrade all.", "upgrade/u");
  qInfo("For more commands, check the documentation.");

#undef HELP_MSG
}

Shell::~Shell() {
  wait();
#ifdef FK_USE_READLINE
  rl_clear_history();
#endif
}

void Shell::lspCommand(QStringList &) {
  if (ServerInstance->players.size() == 0) {
    qInfo("No online player.");
    return;
  }
  qInfo("Current %lld online player(s) are:", ServerInstance->players.size());
  for (auto player : ServerInstance->players) {
    qInfo() << player->getId() << "," << player->getScreenName();
  }
}

void Shell::lsrCommand(QStringList &list) {
  if (!list.isEmpty() && !list[0].isEmpty()) {
    auto pid = list[0];
    bool ok;
    int id = pid.toInt(&ok);
    if (!ok) return;

    auto room = ServerInstance->findRoom(id);
    if (!room) {
      qInfo("No such room.");
    } else {
      auto config = QJsonDocument::fromJson(room->getSettings());
      auto pw = config["password"].toString();
      qInfo() << room->getId() << "," << (pw.isEmpty() ? QString("%1").arg(room->getName()) :
          QString("%1 [pw=%2]").arg(room->getName()).arg(pw));
      qInfo("Players in this room:");

      for (auto p : room->getPlayers()) {
        qInfo() << p->getId() << "," << p->getScreenName();
      }
    }

    return;
  }
  if (ServerInstance->rooms.size() == 0) {
    qInfo("No running room.");
    return;
  }
  qInfo("Current %lld running rooms are:", ServerInstance->rooms.size());
  for (auto room : ServerInstance->rooms) {
    auto config = QJsonDocument::fromJson(room->getSettings());
    auto pw = config["password"].toString();
    qInfo() << room->getId() << "," << (pw.isEmpty() ? QString("%1").arg(room->getName()) :
        QString("%1 [pw=%2]").arg(room->getName()).arg(pw));
  }
}

void Shell::installCommand(QStringList &list) {
  if (list.isEmpty()) {
    qWarning("The 'install' command need a URL to install.");
    return;
  }

  auto url = list[0];
  Pacman->downloadNewPack(url);
}

void Shell::removeCommand(QStringList &list) {
  if (list.isEmpty()) {
    qWarning("The 'remove' command need a package name to remove.");
    return;
  }

  auto pack = list[0];
  Pacman->removePack(pack);
}

void Shell::upgradeCommand(QStringList &list) {
  if (list.isEmpty()) {
    // qWarning("The 'upgrade' command need a package name to upgrade.");
    auto arr = QJsonDocument::fromJson(Pacman->listPackages().toUtf8()).array();
    for (auto a : arr) {
      auto obj = a.toObject();
      Pacman->upgradePack(obj["name"].toString());
    }
    ServerInstance->refreshMd5();
    return;
  }

  auto pack = list[0];
  Pacman->upgradePack(pack);
  ServerInstance->refreshMd5();
}

void Shell::enableCommand(QStringList &list) {
  if (list.isEmpty()) {
    qWarning("The 'enable' command need a package name to enable.");
    return;
  }

  auto pack = list[0];
  Pacman->enablePack(pack);
  ServerInstance->refreshMd5();
}

void Shell::disableCommand(QStringList &list) {
  if (list.isEmpty()) {
    qWarning("The 'disable' command need a package name to disable.");
    return;
  }

  auto pack = list[0];
  Pacman->disablePack(pack);
  ServerInstance->refreshMd5();
}

void Shell::lspkgCommand(QStringList &) {
  auto arr = QJsonDocument::fromJson(Pacman->listPackages().toUtf8()).array();
  qInfo("Name\tVersion\t\tEnabled");
  qInfo("------------------------------");
  for (auto a : arr) {
    auto obj = a.toObject();
    auto hash = obj["hash"].toString();
    qInfo() << obj["name"].toString().toUtf8().constData() << "\t"
            << hash.first(8).toUtf8().constData() << "\t"
            << obj["enabled"].toString().toUtf8().constData();
  }
}

void Shell::kickCommand(QStringList &list) {
  if (list.isEmpty()) {
    qWarning("The 'kick' command needs a player id.");
    return;
  }

  auto pid = list[0];
  bool ok;
  int id = pid.toInt(&ok);
  if (!ok)
    return;

  auto p = ServerInstance->findPlayer(id);
  if (p) {
    p->kicked();
  }
}

void Shell::msgCommand(QStringList &list) {
  if (list.isEmpty()) {
    qWarning("The 'msg' command needs message body.");
    return;
  }

  auto msg = list.join(' ');
  ServerInstance->broadcast("ServerMessage", msg.toUtf8());
}

void Shell::msgRoomCommand(QStringList &list) {
  if (list.count() < 2) {
    qWarning("The 'msgroom' command needs <roomId> and message body.");
    return;
  }

  auto roomId = list.takeFirst().toInt();
  auto room = ServerInstance->findRoom(roomId);
  if (!room) {
    qInfo("No such room.");
    return;
  }
  auto msg = list.join(' ');
  room->doBroadcastNotify(room->getPlayers(), "ServerMessage", msg.toUtf8());
}



static void banAccount(Sqlite3 *db, const QString &name, bool banned) {
  if (!Sqlite3::checkString(name))
    return;
  QString sql_find = QString("SELECT * FROM userinfo \
        WHERE name='%1';")
                         .arg(name);
  auto result = db->select(sql_find);
  if (result.isEmpty())
    return;
  auto obj = result[0];
  int id = obj["id"].toInt();
  db->exec(QString("UPDATE userinfo SET banned=%2 WHERE id=%1;")
                  .arg(id)
                  .arg(banned ? 1 : 0));

  if (banned) {
    auto p = ServerInstance->findPlayer(id);
    if (p) {
      p->kicked();
    }
    qInfo("Banned %s.", name.toUtf8().constData());
  } else {
    qInfo("Unbanned %s.", name.toUtf8().constData());
  }
}

void Shell::banCommand(QStringList &list) {
  if (list.isEmpty()) {
    qWarning("The 'ban' command needs at least 1 <name>.");
    return;
  }

  auto db = ServerInstance->getDatabase();

  for (auto name : list) {
    banAccount(db, name, true);
  }

  // banipCommand(list);
  // banUuidCommand(list);
}

void Shell::unbanCommand(QStringList &list) {
  if (list.isEmpty()) {
    qWarning("The 'unban' command needs at least 1 <name>.");
    return;
  }

  auto db = ServerInstance->getDatabase();

  for (auto name : list) {
    banAccount(db, name, false);
  }

  // unbanipCommand(list);
  unbanUuidCommand(list);
}

static void banIPByName(Sqlite3 *db, const QString &name, bool banned) {
  if (!Sqlite3::checkString(name))
    return;

  QString sql_find = QString("SELECT * FROM userinfo \
        WHERE name='%1';")
                         .arg(name);
  auto result = db->select(sql_find);
  if (result.isEmpty())
    return;
  auto obj = result[0];
  int id = obj["id"].toInt();
  auto addr = obj["lastLoginIp"];

  if (banned) {
    db->exec(QString("INSERT INTO banip VALUES('%1');").arg(addr));

    auto p = ServerInstance->findPlayer(id);
    if (p) {
      p->kicked();
    }
    qInfo("Banned IP %s.", addr.toUtf8().constData());
  } else {
    db->exec(QString("DELETE FROM banip WHERE ip='%1';").arg(addr));
    qInfo("Unbanned IP %s.", addr.toUtf8().constData());
  }
}

void Shell::banipCommand(QStringList &list) {
  if (list.isEmpty()) {
    qWarning("The 'banip' command needs at least 1 <name>.");
    return;
  }

  auto db = ServerInstance->getDatabase();

  for (auto name : list) {
    banIPByName(db, name, true);
  }
}

void Shell::unbanipCommand(QStringList &list) {
  if (list.isEmpty()) {
    qWarning("The 'unbanip' command needs at least 1 <name>.");
    return;
  }

  auto db = ServerInstance->getDatabase();

  for (auto name : list) {
    banIPByName(db, name, false);
  }
}

static void banUuidByName(Sqlite3 *db, const QString &name, bool banned) {
  if (!Sqlite3::checkString(name))
    return;

  QString sql_find = QString("SELECT * FROM userinfo \
        WHERE name='%1';")
                         .arg(name);
  auto result = db->select(sql_find);
  if (result.isEmpty())
    return;
  auto obj = result[0];
  int id = obj["id"].toInt();

  auto result2 = db->select(QString("SELECT * FROM uuidinfo WHERE id=%1;").arg(id));
  if (result2.isEmpty())
    return;

  auto uuid = result2[0]["uuid"];

  if (banned) {
    db->exec(QString("INSERT INTO banuuid VALUES('%1');").arg(uuid));

    auto p = ServerInstance->findPlayer(id);
    if (p) {
      p->kicked();
    }
    qInfo("Banned UUID %s.", uuid.toUtf8().constData());
  } else {
    db->exec(QString("DELETE FROM banuuid WHERE uuid='%1';").arg(uuid));
    qInfo("Unbanned UUID %s.", uuid.toUtf8().constData());
  }
}

void Shell::banUuidCommand(QStringList &list) {
  if (list.isEmpty()) {
    qWarning("The 'banuuid' command needs at least 1 <name>.");
    return;
  }

  auto db = ServerInstance->getDatabase();

  for (auto name : list) {
    banUuidByName(db, name, true);
  }
}

void Shell::unbanUuidCommand(QStringList &list) {
  if (list.isEmpty()) {
    qWarning("The 'unbanuuid' command needs at least 1 <name>.");
    return;
  }

  auto db = ServerInstance->getDatabase();

  for (auto name : list) {
    banUuidByName(db, name, false);
  }
}

void Shell::reloadConfCommand(QStringList &) {
  ServerInstance->readConfig();
  qInfo("Reloaded server config file.");
}

void Shell::resetPasswordCommand(QStringList &list) {
  if (list.isEmpty()) {
    qWarning("The 'resetpassword' command needs at least 1 <name>.");
    return;
  }

  auto db = ServerInstance->getDatabase();
  for (auto name : list) {
    // 重置为1234
    db->exec(QString("UPDATE userinfo SET password=\
          'dbdc2ad3d9625407f55674a00b58904242545bfafedac67485ac398508403ade',\
          salt='00000000' WHERE name='%1';").arg(name));
  }
}

static QString formatMsDuration(qint64 time) {
  QString ret;

  auto ms = time % 1000;
  time /= 1000;
  auto sec = time % 60;
  ret = QString("%1.%2 seconds").arg(sec).arg(ms) + ret;
  time /= 60;
  if (time == 0) return ret;

  auto min = time % 60;
  ret = QString("%1 minutes, ").arg(min) + ret;
  time /= 60;
  if (time == 0) return ret;

  auto hour = time % 24;
  ret = QString("%1 hours, ").arg(hour) + ret;
  time /= 24;
  if (time == 0) return ret;

  ret = QString("%1 days, ").arg(time) + ret;
  return ret;
}

void Shell::statCommand(QStringList &) {
  auto server = ServerInstance;
  auto uptime_ms = server->getUptime();
  qInfo("uptime: %s", formatMsDuration(uptime_ms).toUtf8().constData());

  auto players = server->getPlayers();
  qInfo("Player(s) logged in: %lld", players.count());
  qInfo("Next roomId: %d", server->nextRoomId); // FIXME: friend class

  auto threads = server->findChildren<RoomThread *>();
  static const char *getmem = "return collectgarbage('count') / 1024";
  for (auto thr : threads) {
    auto rooms = thr->findChildren<Room *>();
    auto L = thr->getLua();
    auto mem_mib = L->eval(getmem).toDouble();
    auto outdated = thr->isOutdated();
    if (rooms.count() == 0 && outdated) {
      thr->deleteLater();
    } else {
      qInfo("RoomThread %p | %.2f MiB | %lld room(s) %s", thr, mem_mib, rooms.count(),
            outdated ? "| Outdated" : "");
    }
  }

  qInfo("Database memory usage: %.2f MiB",
        ((double)server->db->getMemUsage()) / 1048576);
}

void Shell::dumpRoomCommand(QStringList &list) {
  if (list.isEmpty() || list[0].isEmpty()) {
    static const char *code =
      "local _, reqRoom = debug.getupvalue(ResumeRoom, 1)\n"
      "for id, room in pairs(reqRoom.runningRooms) do\n"
      "  fk.qInfo(string.format('<Lua> Room #%d', id))\n"
      "end\n";
    for (auto thr : ServerInstance->findChildren<RoomThread *>()) {
      qInfo("== Lua room info of RoomThread %p ==", thr);
      thr->getLua()->eval(code);
    }
    return;
  }

  auto pid = list[0];
  bool ok;
  int id = pid.toInt(&ok);
  if (!ok) return;

  auto room = ServerInstance->findRoom(id);
  if (!room) {
    qInfo("No such room.");
  } else {
    static auto code = QStringLiteral(
      "(function(id)\n"
      "  local _, reqRoom = debug.getupvalue(ResumeRoom, 1)\n"
      "  local room = reqRoom.runningRooms[id]\n"
      "  if not room then fk.qInfo('<Lua> No such room.'); return end\n"
      "  fk.qInfo(string.format('== <Lua> Data of room %d ==', id))\n"
      "  fk.qInfo(json.encode(room:toJsonObject(room.players[1])))\n"
      "end)\n");
    auto L = qobject_cast<RoomThread *>(room->parent())->getLua();
    L->eval(code + QStringLiteral("(%1)").arg(id));
  }
}

void Shell::killRoomCommand(QStringList &list) {
  if (list.isEmpty() || list[0].isEmpty()) {
    qWarning("Need room id to do this.");
    return;
  }

  auto pid = list[0];
  bool ok;
  int id = pid.toInt(&ok);
  if (!ok) return;

  auto room = ServerInstance->findRoom(id);
  if (!room) {
    qInfo("No such room.");
  } else {
    qInfo("Killing room %d", id);
    for (auto player : room->getPlayers()) {
      if (player->getId() > 0) emit player->kicked();
    }
    emit room->abandoned();
  }
}

#ifdef FK_USE_READLINE
static void sigintHandler(int) {
  rl_reset_line_state();
  rl_replace_line("", 0);
  rl_crlf();
  rl_forced_update_display();
}
static char **fk_completion(const char *text, int start, int end);
static char *null_completion(const char *, int) { return NULL; }
#endif

Shell::Shell() {
  ShellInstance = this;
  setObjectName("Shell");
#ifdef FK_USE_READLINE
  // Setup readline here

  // 别管Ctrl+C了
  //rl_catch_signals = 1;
  //rl_catch_sigwinch = 1;
  //rl_persistent_signal_handlers = 1;
  //rl_set_signals();
  signal(SIGINT, sigintHandler);
  rl_attempted_completion_function = fk_completion;
  rl_completion_entry_function = null_completion;
#endif

  static const QHash<QString, void (Shell::*)(QStringList &)> handlers = {
    {"help", &Shell::helpCommand},
    {"?", &Shell::helpCommand},
    {"lsplayer", &Shell::lspCommand},
    {"lsroom", &Shell::lsrCommand},
    {"install", &Shell::installCommand},
    {"remove", &Shell::removeCommand},
    {"upgrade", &Shell::upgradeCommand},
    {"u", &Shell::upgradeCommand},
    {"pkgs", &Shell::lspkgCommand},
    {"enable", &Shell::enableCommand},
    {"disable", &Shell::disableCommand},
    {"kick", &Shell::kickCommand},
    {"msg", &Shell::msgCommand},
    {"m", &Shell::msgCommand},
    {"msgroom", &Shell::msgRoomCommand},
    {"mr", &Shell::msgRoomCommand},
    {"ban", &Shell::banCommand},
    {"unban", &Shell::unbanCommand},
    {"banip", &Shell::banipCommand},
    {"unbanip", &Shell::unbanipCommand},
    {"banuuid", &Shell::banUuidCommand},
    {"unbanuuid", &Shell::unbanUuidCommand},
    {"reloadconf", &Shell::reloadConfCommand},
    {"r", &Shell::reloadConfCommand},
    {"resetpassword", &Shell::resetPasswordCommand},
    {"rp", &Shell::resetPasswordCommand},
    {"stat", &Shell::statCommand},
    {"gc", &Shell::statCommand},
    {"dumproom", &Shell::dumpRoomCommand},
    {"killroom", &Shell::killRoomCommand},
    // special command
    {"quit", &Shell::helpCommand},
    {"crash", &Shell::helpCommand},
  };
  handler_map = handlers;
}

void Shell::handleLine(char *bytes) {
  if (!bytes || !strncmp(bytes, "quit", 4)) {
    qInfo("Server is shutting down.");
    qApp->quit();
    done = true;
    return;
  }

  qInfo("Running command: \"%s\"", bytes);

  if (!strncmp(bytes, "crash", 5)) {
    qFatal("Crashing."); // should dump core
    return;
  }

#ifdef FK_USE_READLINE
  add_history(bytes);
#endif

  auto command = QString(bytes);
  auto command_list = command.split(' ');
  auto func = handler_map[command_list.first()];
  if (!func) {
    auto bytes = command_list.first().toUtf8();
    qWarning("Unknown command \"%s\". Type \"help\" for hints.",
        bytes.constData());
  } else {
    command_list.removeFirst();
    (this->*func)(command_list);
  }

  free(bytes);
}

#ifdef FK_USE_READLINE
void Shell::redisplay() {
  QString tmp = syntaxHighlight(rl_line_buffer);
  rl_clear_visible_line();
  rl_forced_update_display();

  //moveCursorToStart();
  //printf("\r%s%s", prompt, tmp.toUtf8().constData());
}

void Shell::moveCursorToStart() {
  winsize sz;
  ioctl(STDOUT_FILENO, TIOCGWINSZ, &sz);
  int lines = (rl_end + strlen(prompt) - 1) / sz.ws_col;
  printf("\e[%d;%dH", sz.ws_row - lines, 0);
}

void Shell::clearLine() {
  rl_clear_visible_line();
}

bool Shell::lineDone() const {
  return (bool)rl_done;
}

// 最简单的语法高亮，若命令可执行就涂绿，否则涂红
QString Shell::syntaxHighlight(char *bytes) {
  QString ret(bytes);
  auto command = ret.split(' ').first();
  auto func = handler_map[command];
  auto colored_command = command;
  if (!func) {
    colored_command = Color(command, fkShell::Red, fkShell::Bold);
  } else {
    colored_command = Color(command, fkShell::Green);
  }
  ret.replace(0, command.length(), colored_command);
  return ret;
}

static void linehandler(char *bytes) {
  ShellInstance->handleLine(bytes);
}

char *Shell::generateCommand(const char *text, int state) {
  static int list_index, len;
  static auto keys = handler_map.keys();
  const char *name;

  if (state == 0) {
    list_index = 0;
    len = strlen(text);
  }

  while (list_index < keys.length()) {
    name = keys[list_index].toUtf8().constData();
    ++list_index;
    if (strncmp(name, text, len) == 0) {
      return strdup(name);
    }
  }

  return NULL;
}

static char *command_generator(const char *text, int state) {
  return ShellInstance->generateCommand(text, state);
}

static char *repo_generator(const char *text, int state) {
  static QStringList recommend_repos = {
    "https://gitee.com/Qsgs-Fans/standard_ex",
    "https://gitee.com/Qsgs-Fans/shzl",
    "https://gitee.com/Qsgs-Fans/sp",
    "https://gitee.com/Qsgs-Fans/yj",
    "https://gitee.com/Qsgs-Fans/ol",
    "https://gitee.com/Qsgs-Fans/mougong",
    "https://gitee.com/Qsgs-Fans/mobile",
    "https://gitee.com/Qsgs-Fans/tenyear",
    "https://gitee.com/Qsgs-Fans/overseas",
    "https://gitee.com/Qsgs-Fans/jsrg",
    "https://gitee.com/Qsgs-Fans/qsgs",
    "https://gitee.com/Qsgs-Fans/mini",
    "https://gitee.com/Qsgs-Fans/gamemode",
    "https://gitee.com/Qsgs-Fans/utility",
    "https://gitee.com/Qsgs-Fans/freekill-core",
    "https://gitee.com/Qsgs-Fans/offline",
    "https://gitee.com/Qsgs-Fans/hegemony",
    "https://gitee.com/Qsgs-Fans/lunar",
  };
  static int list_index, len;
  const char *name;

  if (state == 0) {
    list_index = 0;
    len = strlen(text);
  }

  while (list_index < recommend_repos.count()) {
    name = recommend_repos[list_index].toUtf8().constData();
    ++list_index;
    if (strncmp(name, text, len) == 0) {
      return strdup(name);
    }
  }

  return NULL;
}

static char *package_generator(const char *text, int state) {
  static QJsonArray arr;
  static int list_index, len;
  const char *name;

  if (state == 0) {
    arr = QJsonDocument::fromJson(Pacman->listPackages().toUtf8()).array();
    list_index = 0;
    len = strlen(text);
  }

  while (list_index < arr.count()) {
    name = arr[list_index].toObject().value("name").toString().toUtf8().constData();
    ++list_index;
    if (strncmp(name, text, len) == 0) {
      return strdup(name);
    }
  }

  return NULL;
}

static char *user_generator(const char *text, int state) {
  // TODO: userinfo表需要一个cache机制
  static Sqlite3::QueryResult arr;
  static int list_index, len;
  const char *name;

  if (state == 0) {
    arr = ServerInstance->getDatabase()->select("SELECT name FROM userinfo;");
    list_index = 0;
    len = strlen(text);
  }

  while (list_index < arr.count()) {
    name = arr[list_index]["name"].toUtf8().constData();
    ++list_index;
    if (strncmp(name, text, len) == 0) {
      return strdup(name);
    }
  }

  return NULL;
};

static char *banned_user_generator(const char *text, int state) {
  // TODO: userinfo表需要一个cache机制
  static Sqlite3::QueryResult arr;
  static int list_index, len;
  const char *name;
  auto db = ServerInstance->getDatabase();

  if (state == 0) {
    arr = db->select("SELECT name FROM userinfo WHERE banned = 1;");
    list_index = 0;
    len = strlen(text);
  }

  while (list_index < arr.count()) {
    name = arr[list_index]["name"].toUtf8().constData();
    ++list_index;
    if (strncmp(name, text, len) == 0) {
      return strdup(name);
    }
  }

  return NULL;
};

static char **fk_completion(const char* text, int start, int end) {
  char **matches = NULL;
  if (start == 0) {
    matches = rl_completion_matches(text, command_generator);
  } else {
    auto command_list = QString(rl_line_buffer).split(' ');
    if (command_list.length() > 2) return NULL;
    auto command = command_list[0];
    if (command == "install") {
      matches = rl_completion_matches(text, repo_generator);
    } else if (command == "remove" || command == "upgrade"
        || command == "enable" || command == "disable") {
      matches = rl_completion_matches(text, package_generator);
    } else if (command.startsWith("ban") || command == "resetpassword" || command == "rp") {
      matches = rl_completion_matches(text, user_generator);
    } else if (command.startsWith("unban")) {
      matches = rl_completion_matches(text, banned_user_generator);
    }
  }

  return matches;
}
#endif

void Shell::run() {
  printf("\rFreeKill, Copyright (C) 2022-2024, GNU GPL'd, by Notify et al.\n");
  printf("This program comes with ABSOLUTELY NO WARRANTY.\n");
  printf(
      "This is free software, and you are welcome to redistribute it under\n");
  printf("certain conditions; For more information visit "
         "http://www.gnu.org/licenses.\n\n");

  printf("[v%s] Welcome to CLI. Enter \"help\" for usage hints.\n", FK_VERSION);

  while (true) {
#ifdef FK_USE_READLINE
    char *bytes = readline(prompt);
#else
    char *bytes;
    printf("\rfk> ");
    fflush(stdin);
    std::string str;
    std::getline(std::cin, str);
    if (std::cin.fail()) {
      bytes = NULL;
    } else {
      bytes = strdup(str.c_str());
    }
#endif
    handleLine(bytes);
    if (done) break;
  }
}
