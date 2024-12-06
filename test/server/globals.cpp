#include "globals.h"
#include "core/packman.h"
#include "network/router.h"
#include "server/server.h"
#include "server/serverplayer.h"
#include "client/clientplayer.h"

ushort test_port = 39527;
const char *test_name = "test_player";
const char *test_name2 = "test_player2";
const char *test_name3 = "test_player3";

TesterClient::TesterClient(const QString &username, const QString &password): Client() {
  setLoginInfo(username, password);
  /*
  connect(this, &Client::error_message, this, [](auto msg){
    qDebug() << msg;
  });
  connect(this, &Client::notifyUI, this, [=](auto cmd, auto msg){
    qDebug() << this << cmd << msg;
  });
  */
};

void TesterClient::connectToHostAndSendSetup(const QString &server, ushort port) {
  QSignalSpy spy(getRouter(), &Router::notification_got);
  qDebug() << this << getSelf()->getId();
  connectToHost(server, port);
  QVERIFY(spy.wait());
  QCOMPARE(spy[0][0].toString(), "NetworkDelayTest");
  qApp->processEvents();
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
}

TesterClient *ServerThread::getClientById(int id) {
  for (auto client : clients) {
    auto p = client->getSelf();
    if (p && p->getId() == id) {
      return client;
    }
  }
  return nullptr;
}

void ServerThread::kickAllClients() {
  for (auto p : server->getPlayers()) {
    auto client = server_thread->getClientById(p->getId());
    if (client) { // 后面有Bot参战的
      QSignalSpy spy(client, &Client::error_message);
      emit p->kicked();
      QVERIFY(spy.wait());
    }
  }
  qApp->processEvents();
}

#ifdef Q_OS_WIN
#include "applink.c"
#endif

void SetupServerAndClient() {
  auto now = QDateTime::currentMSecsSinceEpoch();
  Pacman = new PackMan;
  server_thread = new ServerThread;
  QSignalSpy spy(server_thread, &ServerThread::listening);
  server_thread->start();
  if (!spy.wait()) {
    qFatal() << "Can not start test server!";
  }
  clients.append(new TesterClient(test_name, "1234"));
  clients.append(new TesterClient(test_name2, "1234"));
  clients.append(new TesterClient(test_name3, "1234"));
}

ServerThread *server_thread;
QList<TesterClient *> clients;
QJsonObject room_config = {
  { "gameMode", "aaa_role_mode" },
  { "enableFreeAssign", true },
  { "enableDeputy", false },
  { "generalNum", 5 },
  { "luckTime", 0 },
  { "password", "" },
  { "disabledPack", QJsonArray() },
  { "disabledGenerals", QJsonArray() },
};
