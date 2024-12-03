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
  Pacman = new PackMan;
  for (auto obj : QJsonDocument::fromJson(Pacman->listPackages().toUtf8()).array()) {
    auto pack = obj.toObject()["name"].toString();
    if (pack != "freekill-core")
      Pacman->disablePack(pack);
  }
  L = new Lua;
  L->eval("__os = os; __io = io; __package = package"); // 保存一下
  bool using_core = false;
  if (QFile::exists("packages/freekill-core") &&
      !GetDisabledPacks().contains("freekill-core")) {
    using_core = true;
    QDir::setCurrent("packages/freekill-core");
  }
  QVERIFY(L->dofile("lua/freekill.lua"));
  if (using_core) QDir::setCurrent("../..");
}

void TestLuaCore::testCase() {
  QVERIFY(L->dofile("test/lua/cpp_run.lua"));
  QVERIFY(L->eval("return lu.LuaUnit.run()").toInt() == 0);
}

void TestLuaCore::cleanupTestCase() {
}

QTEST_GUILESS_MAIN(TestLuaCore)
#include "lua_core_test.moc"
