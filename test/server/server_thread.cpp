#include "server_thread.h"
#include "server/server.h"
#include "core/packman.h"
static ushort test_port = 39527;

ServerThread::ServerThread() {
  Pacman = new PackMan;
}

void ServerThread::run() {
  server = new Server;
  if (!server->listen(QHostAddress::Any, test_port)) {
    qFatal("cannot listen on port %d!\n", test_port);
    qApp->exit(1);
  }
  emit listening();
  exec();
}

ServerThread::~ServerThread() {
  quit(); wait();
  Pacman->deleteLater();
}
