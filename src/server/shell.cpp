#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
#include "shell.h"
#include "server.h"
#include "serverplayer.h"
#include <signal.h>
#include <readline/readline.h>
#include <readline/history.h>

static void sigintHandler(int) {
  fprintf(stderr, "\n");
  rl_reset_line_state();
  rl_replace_line("", 0);
  rl_crlf();
  rl_redisplay();
}

void Shell::helpCommand(QStringList &) {
  qInfo("Frequently used commands:");
  qInfo("%s: Display this help message.", "help");
  qInfo("%s: Shut down the server.", "quit");
  qInfo("%s: List all online players.", "lsplayer");
  qInfo("%s: List all running rooms.", "lsroom");
  qInfo("For more commands, check the documentation.");
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
    qInfo() << room->getId() << "," << room->getName();
  }
}

Shell::Shell() {
  setObjectName("Shell");
  signal(SIGINT, sigintHandler);

  static QHash<QString, void (Shell::*)(QStringList &)> handlers;
  if (handlers.size() == 0) {
    handlers["help"] = &Shell::helpCommand;
    handlers["?"] = &Shell::helpCommand;
    handlers["lsplayer"] = &Shell::lspCommand;
    handlers["lsroom"] = &Shell::lsrCommand;
  }
  handler_map = handlers;
}

void Shell::run() {
  printf("\rFreeKill, Copyright (C) 2022, GNU GPL'd, by Notify et al.\n");
  printf("This program comes with ABSOLUTELY NO WARRANTY.\n");
  printf("This is free software, and you are welcome to redistribute it under\n");
  printf("certain conditions; For more information visit http://www.gnu.org/licenses.\n\n");
  printf("This is server cli. Enter \"help\" for usage hints.\n");

  while (true) {
    char *bytes = readline("fk> ");
    if (!bytes || !strcmp(bytes, "quit")) {
      qInfo("Server is shutting down.");
      qApp->quit();
      return;
    }

    if (*bytes)
      add_history(bytes);

    auto command = QString(bytes);
    auto command_list = command.split(' ');
    auto func = handler_map[command_list.first()];
    if (!func) {
      auto bytes = command_list.first().toUtf8();
      qWarning("Unknown command \"%s\". Type \"help\" for hints.", bytes.constData());
    } else {
      command_list.removeFirst();
      (this->*func)(command_list);
    }

    free(bytes);
  }
}

#endif
