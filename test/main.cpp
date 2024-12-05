#include "server/globals.h"
#include "server/test_login.h"

#include "core/packman.h"

#define EXEC_QTEST(o) do {\
  auto tc = new (o); \
  status |= QTest::qExec(tc, argc, argv); \
  tc->deleteLater(); \
} while (0)

static bool setupGlobalData() {
  qDebug() << "Setting up test environment";
  auto now = QDateTime::currentMSecsSinceEpoch();
  Pacman = new PackMan;
  server_thread = new ServerThread;
  qDebug() << "Adding listening spy";
  QSignalSpy spy(server_thread, &ServerThread::listening);
  server_thread->start();
  if (!spy.wait()) {
    qDebug() << "Spy isn't waiting...";
    return false;
  }
  qDebug() << "Adding TesterClient";
  clients.append(new TesterClient(test_name, "1234"));
  clients.append(new TesterClient(test_name2, "1234"));
  clients.append(new TesterClient(test_name3, "1234"));
  qDebug() << QString("Created server and clients, %1ms").arg(QDateTime::currentMSecsSinceEpoch() - now);
  return true;
}

int main(int argc, char **argv) {
  QCoreApplication app(argc, argv);
  qputenv("QT_FATAL_CRITICALS", "1"); // TODO: 找个办法在qCritical时候只是失败这个测试而不是把所有全部abort掉了
  int status = 0;

  if (!setupGlobalData()) {
    return EXIT_FAILURE;
  }

  // EXEC_QTEST(TestSocket);
  // EXEC_QTEST(TestLogin);
  // EXEC_QTEST(TestRoom);
  // EXEC_QTEST(TestScheduler);

  return status;
}
