#include "core/c-wrapper.h"
#include "core/util.h"
#include "core/packman.h"

int main(int argc, char **argv) {
  qputenv("QT_FATAL_CRITICALS", "1"); // TODO: 找个办法在qCritical时候只是失败这个测试而不是把所有全部abort掉了

  Pacman = new PackMan;
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
