// SPDX-License-Identifier: GPL-3.0-or-later

// 为了写测试而特意给程序本身单独分出一个main.cpp 顺便包含项目文档（这样真的好吗）
#include "freekill.h"
int main(int argc, char **argv) {
  return freekill_main(argc, argv);
}

/** @mainpage 新月杀文档 - Cpp代码部分

  本文档专门针对新月杀的C++代码部分，采用Doxygen生成。
  关于项目的主文档请参见新月之书： https://fkbook-all-in-one.readthedocs.io/

  > 单独分出一个Doxygen页面而不是合并在新月之书中，
    完全因为懒得给新月之书拖一个新的submodule =.=

  C++的代码位于src/文件夹下，其覆盖的功能为：

  - freekill.cpp: 程序入口，Linux与Android环境下提前部署环境等
  - swig/: 基于SWIG的Lua-cpp接口。需要测试的是里面的函数定义（而非函数声明）。
  - ui/: Qml-cpp接口，以及一些Lua-cpp接口，借此实现lua和qml之间的交互
  - core/: 主要是拓展包管理，以及对于用户（玩家）的定义，以及一些第三方库的封装
  - client/: 主要负责录像，以及加载client侧的Lua，功能其实不多
  - network/: 对Qt Network模块封装，加密/压缩传输，基于JSON通信协议
  - server/: 登录，大厅，房间管理，房间调度，管理员shell

  比较复杂的主要是服务端代码。具体可以查看每个类的文档

  @note 为了详细说明程序运行原理，private成员也将会在文档中呈现。
*/

/** @page page_network 网络连接

  相关类：

  @ref ServerSocket
  @ref ClientSocket
  @ref Router
*/
