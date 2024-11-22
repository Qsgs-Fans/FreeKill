#include "core/c-wrapper.h"
#include "core/packman.h"
#include "core/util.h"
#include "server/server.h"

// 由于只要测试单独Server 所以底下也没必要listen了 创个人机房就行
int main(int argc, char **argv) {
  while (!QFile::exists(".git")) QDir::setCurrent("..");
  Pacman = new PackMan;
  auto L = new Lua;
  L->eval("__os = os; __io = io; __package = package"); // 保存一下
  bool using_core = false;
  if (QFile::exists("packages/freekill-core") &&
      !GetDisabledPacks().contains("freekill-core")) {
    QDir::setCurrent("packages/freekill-core");
  }
  L->dofile("lua/freekill.lua");
  L->dofile("lua/server/scheduler.lua");
  if (!L->dofile("test/lua/cpp_run_gamelogic.lua")) {
    return EXIT_FAILURE;
  }

  return EXIT_SUCCESS;
}
