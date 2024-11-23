#include "core/c-wrapper.h"
#include "core/util.h"
#include "network/test_socket.h"
#include "server/globals.h"
#include "server/test_login.h"
#include "server/test_create_room.h"
#include "server/test_scheduler.h"

#include "core/packman.h"
#include "client/client.h"

#define EXEC_QTEST(o) do {\
  auto tc = new (o); \
  status |= QTest::qExec(tc, argc, argv); \
  tc->deleteLater(); \
} while (0)

static int run_lua_tests() {
  Lua L;
  L.eval("__os = os; __io = io; __package = package"); // 保存一下
  bool using_core = false;
  if (QFile::exists("packages/freekill-core") &&
      !GetDisabledPacks().contains("freekill-core")) {
    QDir::setCurrent("packages/freekill-core");
  }
  L.dofile("lua/freekill.lua");
  L.dofile("lua/server/scheduler.lua");
  if (!L.dofile("test/lua/cpp_run.lua")) {
    return EXIT_FAILURE;
  }

  return EXIT_SUCCESS;
}

static bool setupGlobalData() {
  qDebug() << "Setting up test environment";
  auto now = QDateTime::currentMSecsSinceEpoch();
  Pacman = new PackMan;
  server_thread = new ServerThread;
  QSignalSpy spy(server_thread, &ServerThread::listening);
  server_thread->start();
  if (!spy.wait()) {
    return false;
  }
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

  EXEC_QTEST(TestSocket);
  EXEC_QTEST(TestLogin);
  EXEC_QTEST(TestRoom);
  EXEC_QTEST(TestScheduler);

  status |= run_lua_tests();

  return status;
}
