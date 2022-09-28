#ifndef Q_OS_WIN
#include "shell.h"
#include "server.h"
#include "serverplayer.h"
#include <signal.h>

static void sigintHandler(int) {
  fprintf(stderr, "\nfk> ");
  fflush(stdin);
  return;
}

const char *Shell::ColoredText(const char *input, Color color, TextType type) {
  QString str(input);
  str.append("\e[0m");
  QString header = "\e[";
  switch (type) {
  case NoType:
    header.append("0");
    break;
  case Bold:
    header.append("1");
    break;
  case UnderLine:
    header.append("4");
    break;
  }
  header.append(";");
  header.append(QString::number(30 + color));
  header.append("m");
  header.append(str);
  return header.toUtf8().constData();
}

void Shell::helpCommand(QStringList &) {
  qInfo("Frequently used commands:");
  qInfo("%s: Display this help message.", ColoredText("help", Blue));
  qInfo("%s: Shut down the server.", ColoredText("quit", Blue));
  qInfo("%s: List all online players.", ColoredText("lsplayer", Blue));
  qInfo("%s: List all running rooms.", ColoredText("lsroom", Blue));
  qInfo("For more commands, check the documentation.");
}

void Shell::quitCommand(QStringList &) {
  qInfo("Server is shutting down.");
  qApp->quit();
}

void Shell::lspCommand(QStringList &) {
  if (ServerInstance->players.size() == 0) {
    qInfo("No online player.");
    return;
  }
  qInfo("Current %d online player(s) are:", ServerInstance->players.size());
  foreach (auto player, ServerInstance->players) {
    qInfo() << player->getId() << "," << player->getScreenName();
  }
}

void Shell::lsrCommand(QStringList &) {
  if (ServerInstance->rooms.size() == 0) {
    qInfo("No running room.");
    return;
  }
  qInfo("Current %d running rooms are:", ServerInstance->rooms.size());
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
    handlers["quit"] = &Shell::quitCommand;
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
  QFile file;
  file.open(stdin, QIODevice::ReadOnly);
  while (true) {
    printf("\rfk> ");
    auto bytes = file.readLine();
    auto command = QString::fromUtf8(bytes);
    command.remove('\n');
    auto command_list = command.split(' ');
    auto func = handler_map[command_list.first()];
    if (!func) {
      qWarning("Unknown command \"%s\". Type \"help\" for hints.", command_list.first().toUtf8().constData());
    } else {
      command_list.removeFirst();
      (this->*func)(command_list);
    }

    if (file.atEnd()) {
      qInfo("Server is shutting down.");
      qApp->quit();
      return;
    }
  }
}

#endif
