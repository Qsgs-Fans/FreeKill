// SPDX-License-Identifier: GPL-3.0-or-later

// 为了写测试而特意给程序本身单独分出一个main.cpp 顺便包含项目文档（这样真的好吗）
#include "freekill.h"
int main(int argc, char **argv) {
  return freekill_main(argc, argv);
}

/** \mainpage 新月杀文档 - Cpp代码部分

  本文档专门针对新月杀的C++代码部分，采用Doxygen生成。
  关于项目的主文档请参见新月之书： https://fkbook-all-in-one.readthedocs.io/

  > 单独分出一个Doxygen页面而不是合并在新月之书中，
    完全因为懒得给新月之书拖一个新的submodule =.=
*/
