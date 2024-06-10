// SPDX-License-Identifier: GPL-3.0-or-later

#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
#include "server/shell.h"
#include "core/packman.h"
#include "server/server.h"
#include "server/serverplayer.h"
#include "core/util.h"
#include <readline/history.h>
#include <readline/readline.h>
#include <signal.h>
#include <QJsonDocument>

static void sigintHandler(int) {
  fprintf(stderr, "\n");
  rl_reset_line_state();
  rl_replace_line("", 0);
  rl_crlf();
  rl_redisplay();
}

void Shell::helpCommand(QStringList &) {
  qInfo("Frequently used commands:");
#define HELP_MSG(a, b)                                                         \
  qInfo((a), Color((b), fkShell::Cyan).toUtf8().constData());

  HELP_MSG("%s: Display this help message.", "help");
  HELP_MSG("%s: Shut down the server.", "quit");
  HELP_MSG("%s: Crash the server. Useful when encounter dead loop.", "crash");
  HELP_MSG("%s: List all online players.", "lsplayer");
  HELP_MSG("%s: List all running rooms.", "lsroom");
  HELP_MSG("%s: Reload server config file.", "reloadconf/r");
  HELP_MSG("%s: Kick a player by his <id>.", "kick");
  HELP_MSG("%s: Broadcast message.", "msg/m");
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
  qInfo();
  qInfo("===== Package commands =====");
  HELP_MSG("%s: Install a new package from <url>.", "install");
  HELP_MSG("%s: Remove a package.", "remove");
  HELP_MSG("%s: List all packages.", "lspkg");
  HELP_MSG("%s: Enable a package.", "enable");
  HELP_MSG("%s: Disable a package.", "disable");
  HELP_MSG("%s: Upgrade a package. Leave empty to upgrade all.", "upgrade/u");
  qInfo("For more commands, check the documentation.");

#undef HELP_MSG
}

void Shell::lspCommand(QStringList &) {
  if (ServerInstance->players.size() == 0) {
    qInfo("No online player.");
    return;
  }
  qInfo("Current %lld online player(s) are:", ServerInstance->players.size());
  foreach (auto player, ServerInstance->players) {
    qInfo() << player->getId() << "," << player->getScreenName();
  }
}

void Shell::lsrCommand(QStringList &) {
  if (ServerInstance->rooms.size() == 0) {
    qInfo("No running room.");
    return;
  }
  qInfo("Current %lld running rooms are:", ServerInstance->rooms.size());
  foreach (auto room, ServerInstance->rooms) {
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
    foreach (auto a, arr) {
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
  foreach (auto a, arr) {
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
  ServerInstance->broadcast("ServerMessage", msg);
}

static void banAccount(sqlite3 *db, const QString &name, bool banned) {
  if (!CheckSqlString(name))
    return;
  QString sql_find = QString("SELECT * FROM userinfo \
        WHERE name='%1';")
                         .arg(name);
  auto result = SelectFromDatabase(db, sql_find);
  if (result.isEmpty())
    return;
  auto obj = result[0].toObject();
  int id = obj["id"].toString().toInt();
  ExecSQL(db, QString("UPDATE userinfo SET banned=%2 WHERE id=%1;")
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

  foreach (auto name, list) {
    banAccount(db, name, true);
  }

  // banipCommand(list);
  banUuidCommand(list);
}

void Shell::unbanCommand(QStringList &list) {
  if (list.isEmpty()) {
    qWarning("The 'unban' command needs at least 1 <name>.");
    return;
  }

  auto db = ServerInstance->getDatabase();

  foreach (auto name, list) {
    banAccount(db, name, false);
  }

  // unbanipCommand(list);
  unbanUuidCommand(list);
}

static void banIPByName(sqlite3 *db, const QString &name, bool banned) {
  if (!CheckSqlString(name))
    return;

  QString sql_find = QString("SELECT * FROM userinfo \
        WHERE name='%1';")
                         .arg(name);
  auto result = SelectFromDatabase(db, sql_find);
  if (result.isEmpty())
    return;
  auto obj = result[0].toObject();
  int id = obj["id"].toString().toInt();
  auto addr = obj["lastLoginIp"].toString();

  if (banned) {
    ExecSQL(db, QString("INSERT INTO banip VALUES('%1');").arg(addr));

    auto p = ServerInstance->findPlayer(id);
    if (p) {
      p->kicked();
    }
    qInfo("Banned IP %s.", addr.toUtf8().constData());
  } else {
    ExecSQL(db, QString("DELETE FROM banip WHERE ip='%1';").arg(addr));
    qInfo("Unbanned IP %s.", addr.toUtf8().constData());
  }
}

void Shell::banipCommand(QStringList &list) {
  if (list.isEmpty()) {
    qWarning("The 'banip' command needs at least 1 <name>.");
    return;
  }

  auto db = ServerInstance->getDatabase();

  foreach (auto name, list) {
    banIPByName(db, name, true);
  }
}

void Shell::unbanipCommand(QStringList &list) {
  if (list.isEmpty()) {
    qWarning("The 'unbanip' command needs at least 1 <name>.");
    return;
  }

  auto db = ServerInstance->getDatabase();

  foreach (auto name, list) {
    banIPByName(db, name, false);
  }
}

static void banUuidByName(sqlite3 *db, const QString &name, bool banned) {
  if (!CheckSqlString(name))
    return;

  QString sql_find = QString("SELECT * FROM userinfo \
        WHERE name='%1';")
                         .arg(name);
  auto result = SelectFromDatabase(db, sql_find);
  if (result.isEmpty())
    return;
  auto obj = result[0].toObject();
  int id = obj["id"].toString().toInt();

  auto result2 = SelectFromDatabase(db, QString("SELECT * FROM uuidinfo WHERE id=%1;").arg(id));
  if (result2.isEmpty())
    return;

  auto uuid = result2[0].toObject()["uuid"].toString();

  if (banned) {
    ExecSQL(db, QString("INSERT INTO banuuid VALUES('%1');").arg(uuid));

    auto p = ServerInstance->findPlayer(id);
    if (p) {
      p->kicked();
    }
    qInfo("Banned UUID %s.", uuid.toUtf8().constData());
  } else {
    ExecSQL(db, QString("DELETE FROM banuuid WHERE uuid='%1';").arg(uuid));
    qInfo("Unbanned UUID %s.", uuid.toUtf8().constData());
  }
}

void Shell::banUuidCommand(QStringList &list) {
  if (list.isEmpty()) {
    qWarning("The 'banuuid' command needs at least 1 <name>.");
    return;
  }

  auto db = ServerInstance->getDatabase();

  foreach (auto name, list) {
    banUuidByName(db, name, true);
  }
}

void Shell::unbanUuidCommand(QStringList &list) {
  if (list.isEmpty()) {
    qWarning("The 'unbanuuid' command needs at least 1 <name>.");
    return;
  }

  auto db = ServerInstance->getDatabase();

  foreach (auto name, list) {
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
  foreach (auto name, list) {
    // 重置为1234
    ExecSQL(db, QString("UPDATE userinfo SET password=\
          'dbdc2ad3d9625407f55674a00b58904242545bfafedac67485ac398508403ade',\
          salt='00000000' WHERE name='%1';").arg(name));
  }
}

Shell::Shell() {
  setObjectName("Shell");
  signal(SIGINT, sigintHandler);

  static const QHash<QString, void (Shell::*)(QStringList &)> handlers = {
    {"help", &Shell::helpCommand},
    {"?", &Shell::helpCommand},
    {"lsplayer", &Shell::lspCommand},
    {"lsroom", &Shell::lsrCommand},
    {"install", &Shell::installCommand},
    {"remove", &Shell::removeCommand},
    {"upgrade", &Shell::upgradeCommand},
    {"u", &Shell::upgradeCommand},
    {"lspkg", &Shell::lspkgCommand},
    {"enable", &Shell::enableCommand},
    {"disable", &Shell::disableCommand},
    {"kick", &Shell::kickCommand},
    {"msg", &Shell::msgCommand},
    {"m", &Shell::msgCommand},
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
  };
  handler_map = handlers;
}

void Shell::run() {
  printf("\rFreeKill, Copyright (C) 2022-2023, GNU GPL'd, by Notify et al.\n");
  printf("This program comes with ABSOLUTELY NO WARRANTY.\n");
  printf(
      "This is free software, and you are welcome to redistribute it under\n");
  printf("certain conditions; For more information visit "
         "http://www.gnu.org/licenses.\n\n");

  printf("[v%s] This is server cli. Enter \"help\" for usage hints.\n", FK_VERSION);

  while (true) {
    char *bytes = readline("fk> ");
    if (!bytes || !strcmp(bytes, "quit")) {
      qInfo("Server is shutting down.");
      qApp->quit();
      return;
    }

    qInfo("Running command: \"%s\"", bytes);

    if (!strcmp(bytes, "crash")) {
      qFatal("Crashing."); // should dump core
      return;
    }

    if (*bytes)
      add_history(bytes);

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
}

#endif
