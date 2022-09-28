#include "shell.h"

Shell::Shell() {
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
    printf("fk> ");
    auto bytes = file.readLine();
  }
}
