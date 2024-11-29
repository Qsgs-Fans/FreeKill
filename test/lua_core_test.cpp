#include "core/c-wrapper.h"
#include "core/util.h"
#include "core/packman.h"

class TestLuaCore : public QObject {
  Q_OBJECT
private slots:
  void initTestCase();
  void testCase();
  void cleanupTestCase();
private:
  Lua *L;
};

void TestLuaCore::initTestCase() {
  qputenv("QT_FATAL_CRITICALS", "1"); // TODO: 找个办法在qCritical时候只是失败这个测试而不是把所有全部abort掉了

  Pacman = new PackMan;
  for (auto obj : QJsonDocument::fromJson(Pacman->listPackages().toUtf8()).array()) {
    auto pack = obj.toObject()["name"].toString();
    if (pack != "freekill-core")
      Pacman->disablePack(pack);
  }
  L = new Lua;
  L->eval("__os = os; __io = io; __package = package"); // 保存一下
  if (QFile::exists("packages/freekill-core") &&
      !GetDisabledPacks().contains("freekill-core")) {
    QDir::setCurrent("packages/freekill-core");
  }
  QVERIFY(L->dofile("lua/freekill.lua"));
  QVERIFY(L->dofile("lua/server/scheduler.lua"));
}

void TestLuaCore::testCase() {
  QVERIFY(L->dofile("test/lua/cpp_run.lua"));
}

void TestLuaCore::cleanupTestCase() {
}

QTEST_GUILESS_MAIN(TestLuaCore)
#include "lua_core_test.moc"
