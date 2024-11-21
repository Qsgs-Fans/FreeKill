// 本文件不采用Qt test
// 基于luaunit进行测试
#include "core/c-wrapper.h"
#include "core/packman.h"
#include "core/util.h"

int main(int argc, char **argv) {
  while (!QFile::exists(".git")) QDir::setCurrent("..");
  Pacman = new PackMan;
  auto L = new Lua;
  L->eval("__os = os; __io = io; __package = package"); // 保存一下
  bool using_core = false;
  if (QFile::exists("packages/freekill-core") &&
      !GetDisabledPacks().contains("freekill-core")) {
    using_core = true;
    QDir::setCurrent("packages/freekill-core");
  }
  L->dofile("lua/freekill.lua");
  if (using_core) {
    QDir::setCurrent("../..");
  }
  // 以上加载了Fk，可以跑lua测试了，我们直接
  if (!L->dofile("test/lua/cpp_run.lua")) {
    return EXIT_FAILURE;
  }

  return EXIT_SUCCESS;
}
